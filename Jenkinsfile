
pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: [
                'CREATE_REPLICAS',
                'DELETE_REPLICAS',
                'TERRAFORM_APPLY',
                'DESTROY_INFRA'
            ],
            description: 'Choose the operation to perform'
        )

        string(
            name: 'REPLICA_COUNT',
            defaultValue: '2',
            description: 'Number of NGINX replicas for DEPLOY (1-50)'
        )
    }

    environment {
        AWS_REGION = 'ap-south-1'
        EKS_CLUSTER_NAME = 'eks-cluster'
        TF_DIR = 'terraform'
    }

    stages {
        stage('Show Configuration') {
            steps {
                echo "Action: ${params.ACTION}"
                echo "AWS Region: ${AWS_REGION}"
                echo "EKS Cluster: ${EKS_CLUSTER_NAME}"

                script {
                    if (params.ACTION == 'DEPLOY') {
                        echo "Requested replicas: ${params.REPLICA_COUNT}"
                    }
                }
            }
        }

        stage('Validate Replica Count') {
            when {
                expression { params.ACTION == 'DEPLOY' }
            }
            steps {
                script {
                    if (!(params.REPLICA_COUNT ==~ /^[1-9][0-9]*$/)) {
                        error('Enter a positive whole number for replicas.')
                    }

                    if (params.REPLICA_COUNT.toInteger() > 50) {
                        error('Maximum allowed replicas is 50.')
                    }
                }
            }
        }

        stage('Validate Tools') {
            when {
                expression { params.ACTION == 'DEPLOY' ||
                             params.ACTION == 'DELETE_PODS' }
            }
            steps {
                sh '''
                    set -eu
                    aws --version
                    kubectl version --client
                    ansible --version
                '''
            }
        }

        stage('Plan Terraform Infrastructure') {
            when {
                expression { params.ACTION == 'TERRAFORM_APPLY' }
            }
            steps {
                dir("${TF_DIR}") {
                    sh '''
                        set -eu
                        terraform init -input=false
                        terraform validate
                        terraform plan -input=false -out=apply.tfplan
                        terraform show -no-color apply.tfplan
                    '''
                }
            }
        }

        stage('Approve Terraform Apply') {
            when {
                expression { params.ACTION == 'TERRAFORM_APPLY' }
            }
            steps {
                script {
                    input(
                        message: 'Review the Terraform plan. Do you want to apply these infrastructure changes?',
                        ok: 'Approve Apply'
                    )
                }
            }
        }

        stage('Apply Terraform Infrastructure') {
            when {
                expression { params.ACTION == 'TERRAFORM_APPLY' }
            }
            steps {
                dir("${TF_DIR}") {
                    sh '''
                        set -eu
                        terraform apply -input=false apply.tfplan
                    '''
                }
            }
            post {
                always {
                    dir("${TF_DIR}") {
                        sh 'rm -f apply.tfplan'
                    }
                }
            }
        }

        stage('Deploy NGINX with Ansible') {
            when {
                expression { params.ACTION == 'DEPLOY' }
            }
            steps {
                withEnv(["SELECTED_REPLICAS=${params.REPLICA_COUNT}"]) {
                    sh '''
                        set -eu
                        ansible-playbook ansible/playbooks/deploy-app.yml \
                          -e "replica_count=${SELECTED_REPLICAS}"
                    '''
                }
            }
        }

        stage('Verify NGINX Deployment') {
            when {
                expression { params.ACTION == 'DEPLOY' }
            }
            steps {
                sh '''
                    set -eu
                    aws eks update-kubeconfig \
                      --region "$AWS_REGION" \
                      --name "$EKS_CLUSTER_NAME"

                    kubectl rollout status deployment/nginx --timeout=300s
                    kubectl get deployment nginx
                    kubectl get pods -l app=nginx -o wide
                '''
            }
        }

        stage('Delete NGINX Application') {
            when {
                expression { params.ACTION == 'DELETE_PODS' }
            }
            steps {
                sh '''
                    set -eu

                    aws eks update-kubeconfig \
                      --region "$AWS_REGION" \
                      --name "$EKS_CLUSTER_NAME"

                    kubectl delete deployment nginx \
                      --namespace default --ignore-not-found=true

                    kubectl delete service nginx-service \
                      --namespace default --ignore-not-found=true

                    echo "NGINX Deployment and Service deleted."
                    echo "EKS infrastructure has not been destroyed."
                '''
            }
        }

        stage('Initialize Terraform for Destroy') {
            when {
                expression { params.ACTION == 'DESTROY_INFRA' }
            }
            steps {
                dir("${TF_DIR}") {
                    sh '''
                        set -eu
                        terraform init -input=false
                        terraform validate
                    '''
                }
            }
        }

        stage('Plan Infrastructure Destroy') {
            when {
                expression { params.ACTION == 'DESTROY_INFRA' }
            }
            steps {
                dir("${TF_DIR}") {
                    sh '''
                        set -eu
                        terraform plan \
                          -destroy \
                          -input=false \
                          -out=destroy.tfplan

                        terraform show -no-color destroy.tfplan
                    '''
                }
            }
        }

        stage('Confirm Whole Infrastructure Deletion') {
            when {
                expression { params.ACTION == 'DESTROY_INFRA' }
            }
            steps {
                script {
                    def confirmation = input(
                        message: 'Are you sure you want to delete the whole infrastructure?',
                        ok: 'Submit confirmation',
                        parameters: [
                            choice(
                                name: 'CONFIRM_DESTROY',
                                choices: ['NO', 'YES'],
                                description: 'Review the Terraform destroy plan before choosing YES.'
                            )
                        ]
                    )

                    if (confirmation != 'YES') {
                        error('Infrastructure destroy cancelled. Terraform destroy was not executed.')
                    }
                }
            }
        }

        stage('Destroy Terraform Infrastructure') {
            when {
                expression { params.ACTION == 'DESTROY_INFRA' }
            }
            steps {
                dir("${TF_DIR}") {
                    sh '''
                        set -eu
                        terraform apply -input=false destroy.tfplan
                    '''
                }
            }
            post {
                always {
                    dir("${TF_DIR}") {
                        sh 'rm -f destroy.tfplan'
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Action ${params.ACTION} completed successfully."
        }
        failure {
            echo "Action ${params.ACTION} failed or was cancelled. Check the console log."
        }
    }
}
