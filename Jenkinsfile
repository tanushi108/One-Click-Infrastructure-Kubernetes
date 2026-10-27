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
            description: 'Desired NGINX replicas for CREATE_REPLICAS (1-50)'
        )

        string(
            name: 'DELETE_COUNT',
            defaultValue: '1',
            description: 'Number of NGINX replicas to delete (1-50)'
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
                    if (params.ACTION == 'CREATE_REPLICAS') {
                        echo "Requested replicas: ${params.REPLICA_COUNT}"
                    }

                    if (params.ACTION == 'DELETE_REPLICAS') {
                        echo "Requested replicas to delete: ${params.DELETE_COUNT}"
                    }
                }
            }
        }

        stage('Validate Replica Count') {
            when {
                expression { params.ACTION == 'CREATE_REPLICAS' }
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

        stage('Validate Delete Count') {
            when {
                expression { params.ACTION == 'DELETE_REPLICAS' }
            }
            steps {
                script {
                    if (!(params.DELETE_COUNT ==~ /^[1-9][0-9]*$/)) {
                        error('DELETE_COUNT must be a positive whole number.')
                    }

                    if (params.DELETE_COUNT.toInteger() > 50) {
                        error('Maximum allowed delete count is 50.')
                    }
                }
            }
        }

        stage('Validate Tools') {
            when {
                expression {
                    params.ACTION == 'CREATE_REPLICAS' ||
                    params.ACTION == 'DELETE_REPLICAS'
                }
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
                        echo "===== Applying Terraform Plan ====="
                        terraform apply -input=false apply.tfplan

                        echo "===== Terraform Managed Resources ====="
                        terraform state list
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
                expression { params.ACTION == 'CREATE_REPLICAS' }
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
                expression { params.ACTION == 'CREATE_REPLICAS' }
            }
            steps {
                sh '''
                    set -eu

                    aws eks update-kubeconfig \
                      --region "$AWS_REGION" \
                      --name "$EKS_CLUSTER_NAME"

                    echo "===== Deployment Status ====="
                    kubectl rollout status deployment/nginx --timeout=300s
                    kubectl get deployment nginx

                    echo "===== All Kubernetes Pods ====="
                    kubectl get pods

                    echo "===== NGINX Pods and Node Placement ====="
                    kubectl get pods -l app=nginx -o wide

                    echo "===== Kubernetes Services ====="
                    kubectl get services
                '''
            }
        }

        stage('Delete NGINX Application') {
            when {
                expression { params.ACTION == 'DELETE_REPLICAS' }
            }
            steps {
                sh '''
                    set -eu

                    aws eks update-kubeconfig \
                      --region "$AWS_REGION" \
                      --name "$EKS_CLUSTER_NAME"

                    echo "===== Checking Current NGINX Replicas ====="

                    CURRENT=$(kubectl get deployment nginx \
                      --namespace default \
                      -o jsonpath='{.spec.replicas}' 2>/dev/null) || {
                        echo "ERROR: NGINX Deployment does not exist."
                        exit 1
                    }

                    CURRENT=${CURRENT:-0}
                    DELETE="${DELETE_COUNT}"

                    echo "Current desired replicas: $CURRENT"
                    echo "Requested replicas to delete: $DELETE"

                    if [ "$DELETE" -gt "$CURRENT" ]; then
                        echo "ERROR: Cannot delete $DELETE replicas."
                        echo "Only $CURRENT replicas are configured."
                        echo "No changes have been made."
                        exit 1
                    fi

                    REMAINING=$((CURRENT - DELETE))

                    echo "===== Scaling NGINX Deployment ====="
                    echo "Replicas after deletion: $REMAINING"

                    kubectl scale deployment/nginx \
                      --namespace default \
                      --replicas="$REMAINING"

                    echo "===== Waiting for Scaling ====="
                    kubectl rollout status deployment/nginx --timeout=300s \
                      || {
                        echo "WARNING: Rollout did not complete successfully."
                        kubectl get pods -l app=nginx -o wide
                        exit 1
                      }

                    echo "===== Deployment After Scaling ====="
                    kubectl get deployment nginx

                    echo "===== All Kubernetes Pods ====="
                    kubectl get pods

                    echo "===== Remaining NGINX Pods ====="
                    kubectl get pods -l app=nginx -o wide

                    echo "EKS infrastructure and Kubernetes Service are unchanged."
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

                        echo "===== Review Full Infrastructure Destroy Plan ====="
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
                                description: 'Choose YES only after reviewing the Terraform destroy plan.'
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
                        echo "===== Destroying Terraform Infrastructure ====="
                        terraform apply -input=false destroy.tfplan

                        echo "===== Terraform State After Destroy ====="
                        terraform state list
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
