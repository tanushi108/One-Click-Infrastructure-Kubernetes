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
        EKS_CLUSTER_NAME = 'eks-cluster'
        TF_DIR = 'terraform'
    }

    stages {
        stage('Show Configuration') {
            steps {
                echo "Action: ${params.ACTION}"
                echo "AWS Region: ${AWS_REGION}"
                echo "EKS Cluster: ${EKS_CLUSTER_NAME}"
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

        // stage('Plan Terraform Infrastructure') {
        //     when {
        //         expression { params.ACTION == 'TERRAFORM_APPLY' }
        //     }
        //     steps {
        //         dir("${TF_DIR}") {
        //             sh '''
        //                 set -eu
        //                 terraform init 
        //                 terraform validate
                        
        //                 # Sirf EKS Cluster aur Node Group ko target karne ke liye -target flag
        //                 terraform plan  \
        //                     -target=aws_eks_cluster.${EKS_CLUSTER_NAME} \
        //                     -target=aws_eks_node_group.node_groups \
        //                     -out=apply.tfplan
                            
        //                 terraform show -no-color apply.tfplan
        //             '''
        //         }
        //     }
        // }

        stage('Approve Terraform Apply') {
            when {
                expression { params.ACTION == 'TERRAFORM_APPLY' }
            }
            steps {
                script {
                    input(
                        message: 'Review the Terraform plan for EKS Cluster & Node Group. Do you want to approve and apply these changes?',
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
                        echo "===== Applying Terraform Plan for EKS & Node Group ====="
                        terraform apply -input=false apply.tfplan

                        echo "===== Terraform State List ====="
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

        // ==================== TERRAFORM DESTROY FLOW ====================

        // stage('Initialize Terraform for Destroy') {
        //     when {
        //         expression { params.ACTION == 'DESTROY_INFRA' }
        //     }
        //     steps {
        //         dir("${TF_DIR}") {
        //             sh '''
        //                 set -eu
        //                 terraform init -input=false
        //                 terraform validate
        //             '''
        //         }
        //     }
        // }

        // stage('Plan Infrastructure Destroy') {
        //     when {
        //         expression { params.ACTION == 'DESTROY_INFRA' }
        //     }
        //     steps {
        //         dir("${TF_DIR}") {
        //             sh '''
        //                 set -eu
                        
        //                 # Destroy plan with targets for EKS Node Group and Cluster
        //                 terraform plan \
        //                     -destroy \
        //                     -input=false \
        //                     -target=aws_eks_node_group.node_groups \
        //                     -target=aws_eks_cluster.${EKS_CLUSTER_NAME} \
        //                     -out=destroy.tfplan

        //                 echo "===== Review EKS Destroy Plan ====="
        //                 terraform show -no-color destroy.tfplan
        //             '''
        //         }
        //     }
        // }

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
                                description: 'Choose YES only after reviewing the destroy plan.'
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
                    sh '''
                        set -eu
                        echo "===== Destroying EKS Cluster & Node Group ====="
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