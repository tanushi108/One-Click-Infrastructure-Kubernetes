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
                'DESTROY_INFRA'
            ],
            description: 'Choose the operation to perform on EKS Cluster & Node Group'
        )
    }

    environment {
        AWS_REGION = 'ap-south-1'
        TF_DIR = 'terraform'
    }

    stages {
        stage('Show Configuration') {
            steps {
                echo "Action: ${params.ACTION}"
                echo "AWS Region: ${AWS_REGION}"
            }
        }

        stage('Validate Tools') {
            steps {
                sh '''
                    set -eu
                    aws --version
                    terraform version
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
                expression { params.ACTION == 'DESTROY_INFRA' }
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

                            echo "===== Terraform State After Destroy ====="
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