
pipeline {
    agent any

    parameters {
        choice(
            name: 'REPLICA_COUNT',
            choices: ['1', '2', '3', '4', '5'],
            description: 'Select the number of NGINX pod replicas'
        )
    }

    environment {
        AWS_REGION = 'ap-south-1'
        EKS_CLUSTER_NAME = 'assignment4-eks-cluster'
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Project code is available in the workspace.'
            }
        }

        stage('Show Configuration') {
            steps {
                echo "AWS Region: ${AWS_REGION}"
                echo "EKS Cluster: ${EKS_CLUSTER_NAME}"
                echo "Selected replicas: ${params.REPLICA_COUNT}"
            }
        }

        stage('Validate Tools') {
            steps {
                sh '''
                    aws --version
                    kubectl version --client
                    ansible --version
                '''
            }
        }
    }
}
