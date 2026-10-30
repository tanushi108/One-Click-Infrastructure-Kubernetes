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
                'TERRAFORM_APPLY',
                'DESTROY_INFRA',
                'CREATE_REPLICAS',
                'DELETE_REPLICAS'
            ],
            description: 'Choose the operation to perform (EKS Infra or NGINX Replicas)'
        )

        string(
            name: 'REPLICA_COUNT',
            defaultValue: '2',
            description: 'Number of NGINX replicas for CREATE_REPLICAS (1-50)'
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
                }
            }
        }

        stage('Validate Tools') {
            steps {
                sh '''
                    set -eu
                    aws --version
                    terraform version
                    ansible --version
                    kubectl version --client
                '''
            }
        }

        // ==================== TERRAFORM APPLY FLOW ====================

        stage('Approve Terraform Apply') {
            when {
                expression { params.ACTION == 'TERRAFORM_APPLY' }
            }
            steps {
                script {
                    input(
                        message: 'Do you want to approve and apply changes for EKS Cluster & Node Group?',
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
                    withCredentials([
                        string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            set -eu
                            echo "===== Initializing Terraform with -reconfigure ====="
                            terraform init -input=false -reconfigure

                            echo "===== Applying Terraform for EKS & Node Group ====="
                            terraform apply -auto-approve -input=false \
                                -target=aws_eks_cluster.main \
                                -target=aws_eks_node_group.main

                            echo "===== Terraform State List ====="
                            terraform state list
                        '''
                    }
                }
            }
        }

        // ==================== CREATE REPLICAS FLOW (ANSIBLE) ====================

        stage('Create / Scale NGINX Replicas') {
            when {
                expression { params.ACTION == 'CREATE_REPLICAS' || params.ACTION == 'TERRAFORM_APPLY' }
            }
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    withEnv(["SELECTED_REPLICAS=${params.REPLICA_COUNT}"]) {
                        sh '''
                            set -eu
                            echo "===== Updating Kubeconfig ====="
                            aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"

                            echo "===== Deploying/Scaling NGINX with Ansible (Replicas: ${SELECTED_REPLICAS}) ====="
                            ansible-playbook ansible/playbooks/deploy-app.yml \
                              -e "replica_count=${SELECTED_REPLICAS}"

                            echo "===== Verifying Pods Status ====="
                            kubectl get pods -l app=nginx -o wide
                        '''
                    }
                }
            }
        }

        // ==================== DELETE REPLICAS FLOW ====================

        stage('Delete NGINX Replicas') {
            when {
                expression { params.ACTION == 'DELETE_REPLICAS' }
            }
            steps {
                script {
                    def confirmation = input(
                        message: 'Are you sure you want to delete the NGINX deployment and services from the cluster?',
                        ok: 'Approve Delete',
                        parameters: [
                            choice(
                                name: 'CONFIRM_DELETE',
                                choices: ['NO', 'YES'],
                                description: 'Choose YES only if you want to remove NGINX pods.'
                            )
                        ]
                    )

                    if (confirmation != 'YES') {
                        error('Deletion of NGINX replicas was cancelled by user.')
                    }
                }
                
                withCredentials([
                    string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        set -eu
                        echo "===== Updating Kubeconfig ====="
                        aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"

                        echo "===== Deleting NGINX Deployment & Service ====="
                        kubectl get pods -o name | head -n 2 | xargs kubectl delete

                        echo "===== Remaining Pods ====="
                        kubectl get pods
                    '''
                }
            }
        }

        // ==================== TERRAFORM DESTROY FLOW ====================

        stage('Approve Terraform Destroy') {
            when {
                expression { params.ACTION == 'DESTROY_INFRA' }
            }
            steps {
                script {
                    def confirmation = input(
                        message: 'Are you sure you want to destroy the EKS Cluster and Node Group?',
                        ok: 'Approve Destroy',
                        parameters: [
                            choice(
                                name: 'CONFIRM_DESTROY',
                                choices: ['NO', 'YES'],
                                description: 'Choose YES only if you are sure.'
                            )
                        ]
                    )

                    if (confirmation != 'YES') {
                        error('Terraform destroy was cancelled by user.')
                    }
                }
            }
        }

        stage('Destroy Terraform Infrastructure') {
            when {
                expression { env.ACTION == 'DESTROY_INFRA' || params.ACTION == 'DESTROY_INFRA' } // Note: keeping logic aligned
            }
            steps {
                dir("${TF_DIR}") {
                    withCredentials([
                        string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            set -eu
                            echo "===== Initializing Terraform with -reconfigure ====="
                            terraform init -input=false -reconfigure

                            echo "===== Destroying EKS Cluster & Node Group ====="
                            terraform destroy -auto-approve -input=false \
                                -target=aws_eks_node_group.main \
                                -target=aws_eks_cluster.main

                            echo "===== Terraform State List ====="
                            terraform state list
                        '''
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
