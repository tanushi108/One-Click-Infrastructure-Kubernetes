pipeline {
    agent any

    parameters {
        string(
            name: 'REPLICA_COUNT',
            defaultValue: '2',
            description: 'Enter the number of NGINX replicas to create'
        )
    }

    environment {
        AWS_REGION = 'ap-south-1'
        EKS_CLUSTER_NAME = 'eks-cluster'
    }

    stages {
        stage('Show Configuration') {
            steps {
                echo "AWS Region: ${AWS_REGION}"
                echo "EKS Cluster: ${EKS_CLUSTER_NAME}"
                echo "Requested replicas: ${params.REPLICA_COUNT}"
            }
        }

        stage('Validate Replica Count') {
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
            steps {
                sh '''
                    set -e
                    aws --version
                    kubectl version --client
                    ansible --version
                '''
            }
        }

        stage('Deploy NGINX with Ansible') {
            steps {
                sh '''
                    set -e
                    ansible-playbook ansible/playbooks/deploy-app.yml \
                      -e "replica_count=${REPLICA_COUNT}"
                '''
            }
        }

        stage('Verify Pods') {
            steps {
                sh '''
                    set -e
                    kubectl get deployment nginx
                    kubectl get pods -l app=nginx -o wide
                '''
            }
        }
    }
}
