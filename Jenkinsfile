pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['TERRAFORM_APPLY', 'CREATE_REPLICAS', 'DELETE_REPLICAS', 'DESTROY_INFRA'],
            description: 'Choose the operation to perform'
        )

        string(name: 'REPLICA_COUNT', defaultValue: '2',
               description: 'Desired NGINX replicas for CREATE_REPLICAS (1-50)')
        string(name: 'DELETE_COUNT', defaultValue: '1',
               description: 'Number of NGINX replicas to remove (1-50)')
    }

    environment {
        AWS_REGION = 'ap-south-1'
        EKS_CLUSTER_NAME = 'eks-cluster'
        TF_DIR = 'terraform'
    }

    stages {
        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'TERRAFORM_APPLY' }
            }
            steps {
                dir("${TF_DIR}") {
                    sh '''
                        set -eu
                        terraform init -input=false
                        terraform validate

                        if [ ! -f terraform.tfvars ]; then
                            echo "ERROR: terraform.tfvars not found in ${TF_DIR}."
                            exit 1
                        fi

                        terraform plan -input=false \
                          -var-file=terraform.tfvars \
                          -out=apply.tfplan

                        echo "===== Terraform Apply Plan ====="
                        terraform show -no-color apply.tfplan
                    '''
                }

                script {
                    def approval = input(
                        message: 'Review the Terraform plan in the console. Apply these changes?',
                        ok: 'Approve Apply',
                        parameters: [
                            choice(name: 'CONFIRM_APPLY', choices: ['NO', 'YES'],
                                   description: 'Choose YES to apply the displayed plan.')
                        ]
                    )
                    if (approval != 'YES') {
                        error('Terraform apply cancelled by user.')
                    }
                }

                dir("${TF_DIR}") {
                    sh '''
                        set -eu
                        echo "===== Applying Terraform Plan ====="
                        terraform apply -input=false apply.tfplan

                        echo "===== Terraform Outputs ====="
                        terraform output || true

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

        stage('Manage Replicas') {
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

                    aws eks update-kubeconfig \
                      --region "$AWS_REGION" \
                      --name "$EKS_CLUSTER_NAME"

                    echo "===== Current NGINX Deployment ====="
                    kubectl get deployment nginx -o wide
                    kubectl get pods -l app=nginx -o wide
                '''

                script {
                    if (params.ACTION == 'CREATE_REPLICAS') {
                        if (!(params.REPLICA_COUNT ==~ /^[1-9][0-9]*$/) ||
                            params.REPLICA_COUNT.toInteger() > 50) {
                            error('REPLICA_COUNT must be a whole number from 1 to 50.')
                        }

                        withEnv(["SELECTED_REPLICAS=${params.REPLICA_COUNT}"]) {
                            sh '''
                                set -eu
                                echo "===== Deploy/Scale NGINX to ${SELECTED_REPLICAS} replicas ====="
                                ansible-playbook ansible/playbooks/deploy-app.yml \
                                  -e "replica_count=${SELECTED_REPLICAS}"

                                echo "===== Wait for NGINX rollout ====="
                                kubectl rollout status deployment/nginx --timeout=300s
                            '''
                        }
                    } else {
                        if (!(params.DELETE_COUNT ==~ /^[1-9][0-9]*$/) ||
                            params.DELETE_COUNT.toInteger() > 50) {
                            error('DELETE_COUNT must be a whole number from 1 to 50.')
                        }

                        withEnv(["REQUESTED_DELETE=${params.DELETE_COUNT}"]) {
                            sh '''
                                set -eu
                                CURRENT=$(kubectl get deployment nginx \
                                  -o jsonpath='{.spec.replicas}')

                                CURRENT=${CURRENT:-0}
                                echo "Current replicas: $CURRENT"
                                echo "Replicas requested to remove: $REQUESTED_DELETE"

                                if [ "$REQUESTED_DELETE" -gt "$CURRENT" ]; then
                                    echo "ERROR: Cannot remove more replicas than currently configured."
                                    exit 1
                                fi

                                REMAINING=$((CURRENT - REQUESTED_DELETE))
                                echo "Scaling NGINX to $REMAINING replicas."

                                kubectl scale deployment/nginx --replicas="$REMAINING"
                                kubectl rollout status deployment/nginx --timeout=300s
                            '''
                        }
                    }
                }

                sh '''
                    set -eu
                    echo "===== Final NGINX Deployment ====="
                    kubectl get deployment nginx -o wide
                    echo "===== Pods and Node Placement ====="
                    kubectl get pods -o wide
                    echo "===== NGINX Pods ====="
                    kubectl get pods -l app=nginx -o wide
                    echo "===== Kubernetes Services ====="
                    kubectl get services
                    echo "===== Kubernetes Nodes ====="
                    kubectl get nodes -o wide
                '''
            }
        }

 
stage('Terraform Destroy') {
    when {
        expression { params.ACTION == 'DESTROY_INFRA' }
    }

    steps {
        dir("${TF_DIR}") {
            sh '''
                set -eu

                echo "===== Initializing Terraform ====="
                terraform init -input=false
                terraform validate

                if [ ! -f terraform.tfvars ]; then
                    echo "ERROR: terraform.tfvars not found."
                    exit 1
                fi

                echo "===== Checking Terraform VPC ====="

                VPC_ADDRESS=$(terraform state list \
                    | grep -E '^aws_vpc\\.' \
                    | head -n 1 || true)

                if [ -n "$VPC_ADDRESS" ]; then
                    VPC_ID=$(terraform state show "$VPC_ADDRESS" \
                        | awk '/^[[:space:]]*id[[:space:]]*=/ {
                            gsub(/"/, "", $3)
                            print $3
                            exit
                        }')

                    if [ -n "$VPC_ID" ]; then
                        echo "VPC found: $VPC_ID"
                        echo "===== Checking ENI Dependencies ====="

                        aws ec2 describe-network-interfaces \
                            --region "$AWS_REGION" \
                            --filters "Name=vpc-id,Values=$VPC_ID" \
                            --query 'NetworkInterfaces[].{ENI:NetworkInterfaceId,Status:Status,Description:Description,Type:InterfaceType,Instance:Attachment.InstanceId,PublicIP:Association.PublicIp}' \
                            --output table
                    else
                        echo "WARNING: VPC ID could not be read."
                    fi
                else
                    echo "No aws_vpc resource found in Terraform state."
                fi

                echo "===== Creating Destroy Plan ====="

                terraform plan -destroy \
                    -input=false \
                    -var-file=terraform.tfvars \
                    -out=destroy.tfplan

                echo "===== Review Full Infrastructure Destroy Plan ====="
                terraform show -no-color destroy.tfplan
            '''
        }

        script {
            def confirmation = input(
                message: 'Review the plan. This can delete infrastructure managed by this Terraform state.',
                ok: 'Confirm Decision',
                parameters: [
                    choice(
                        name: 'CONFIRM_DESTROY',
                        choices: ['NO', 'YES'],
                        description: 'Choose YES only if you intend to destroy all resources in this plan.'
                    )
                ]
            )

            if (confirmation != 'YES') {
                error('Infrastructure destroy cancelled. No destroy apply was run.')
            }
        }

        dir("${TF_DIR}") {
            sh '''
                set -eu

                echo "===== Destroying Infrastructure ====="
                terraform apply -input=false destroy.tfplan

                echo "===== Terraform Outputs After Destroy ====="
                terraform output || true

                echo "===== Terraform State After Destroy ====="
                terraform state list || true

                echo "===== Destroy Stage Completed ====="
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

    post {
        success {
            echo "Action ${params.ACTION} completed successfully."
        }
        failure {
            echo "Action ${params.ACTION} failed or was cancelled. Check the console log."
        }
    }
}
}
