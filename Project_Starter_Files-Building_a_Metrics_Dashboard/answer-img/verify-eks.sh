#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="my-eks-cluster"
VPC_ID="vpc-7aa76207"
REGION=$(aws configure get region)

echo -e "${YELLOW}Starting EKS Cluster Verification...${NC}\n"

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
        if [ "$2" = "critical" ]; then
            echo "Critical check failed. Exiting..."
            exit 1
        fi
    fi
}

# Check AWS CLI installation
echo "Checking AWS CLI installation..."
aws --version
check_status "AWS CLI is installed"

# Check kubectl installation
echo -e "\nChecking kubectl installation..."
kubectl version --client
check_status "kubectl is installed"

# Check AWS credentials
echo -e "\nChecking AWS credentials..."
aws sts get-caller-identity
check_status "AWS credentials are configured" "critical"

# Verify VPC exists
echo -e "\nVerifying VPC..."
aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $REGION
check_status "VPC exists and is accessible" "critical"

# Check VPC subnets
echo -e "\nChecking VPC subnets..."
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION
check_status "Subnets are configured"

# Verify EKS cluster
echo -e "\nVerifying EKS cluster..."
aws eks describe-cluster --name $CLUSTER_NAME --region $REGION
check_status "EKS cluster exists and is accessible" "critical"

# Update kubeconfig
echo -e "\nUpdating kubeconfig..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
check_status "kubeconfig updated"

# Check node groups
echo -e "\nChecking EKS node groups..."
aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION
check_status "Node groups are configured"

# Check cluster connectivity
echo -e "\nChecking cluster connectivity..."
kubectl get nodes
check_status "Can connect to cluster nodes"

# Verify pods in kube-system namespace
echo -e "\nVerifying system pods..."
kubectl get pods -n kube-system
check_status "System pods are running"

# Check security groups
echo -e "\nChecking security groups..."
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION
check_status "Security groups are configured"

# Service accessibility check function
check_service_endpoint() {
    local port=$1
    echo -e "\nChecking access for port $port..."

    # Get LoadBalancer endpoint for the service
    LB_ENDPOINT=$(kubectl get svc -A --field-selector metadata.name=service-${port} \
        -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

    if [ ! -z "$LB_ENDPOINT" ]; then
        echo -e "Testing connection to LoadBalancer endpoint: $LB_ENDPOINT"
        nc -zv -w 5 $LB_ENDPOINT $port 2>&1
        check_status "Service port $port is accessible through LoadBalancer"
    else
        # Check if service exists
        SVC_EXISTS=$(kubectl get svc -A --field-selector metadata.name=service-${port} -o name)
        if [ -z "$SVC_EXISTS" ]; then
            echo -e "${YELLOW}⚠ No LoadBalancer service found for port $port${NC}"
            echo -e "To create a service for this port, run:"
            echo -e "kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: service-${port}
spec:
  type: LoadBalancer
  ports:
    - port: ${port}
      targetPort: ${port}
  selector:
    app: your-app-${port}
EOF"
        else
            echo -e "${YELLOW}⚠ Service exists but LoadBalancer endpoint not yet available${NC}"
        fi
    fi
}

# Function to create LoadBalancer service
create_lb_service() {
    local port=$1
    echo -e "\nCreating LoadBalancer service for port $port..."

    kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: service-${port}
spec:
  type: LoadBalancer
  ports:
    - port: ${port}
      targetPort: ${port}
  selector:
    app: your-app-${port}
EOF

    check_status "Service created for port $port"
}

# Set CREATE_SERVICES to "y" by default or accept from command line
CREATE_SERVICES=${1:-"y"}

echo -e "\nAutomatic service creation is set to: $CREATE_SERVICES"

# Check all configured ports
declare -a PORTS=(80 8080 9090 3000 3030 16686 8888 8000 6443)
for port in "${PORTS[@]}"; do
    check_service_endpoint $port

    # If service doesn't exist and CREATE_SERVICES is "y", create it
    if [ "$CREATE_SERVICES" = "y" ]; then
        SVC_EXISTS=$(kubectl get svc -A --field-selector metadata.name=service-${port} -o name)
        if [ -z "$SVC_EXISTS" ]; then
            create_lb_service $port
        fi
    fi
done

# Check route tables
echo -e "\nChecking route tables..."
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION
check_status "Route tables are configured"

# Final status summary
echo -e "\n${YELLOW}Verification Summary:${NC}"
echo "================================================"
echo "VPC ID: $VPC_ID"
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"

# Get cluster status
CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text)
echo "Cluster Status: $CLUSTER_STATUS"

# Get node count
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo "Number of Nodes: $NODE_COUNT"

# Get pod count
POD_COUNT=$(kubectl get pods --all-namespaces --no-headers | wc -l)
echo "Total Running Pods: $POD_COUNT"

echo -e "\n${GREEN}Verification Complete!${NC}"