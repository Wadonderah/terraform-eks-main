#!/bin/bash

# Invoice Processing System Deployment Script
# This script automates the deployment of the enhanced invoice processing system

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_VERSION="1.0"
AWS_CLI_VERSION="2.0"
REGION=${AWS_DEFAULT_REGION:-"ca-central-1"}
ENVIRONMENT=${ENVIRONMENT:-"production"}

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install AWS CLI v${AWS_CLI_VERSION} or later."
        exit 1
    fi
    
    # Check AWS CLI version
    AWS_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
    log_info "AWS CLI version: $AWS_VERSION"
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform v${TERRAFORM_VERSION} or later."
        exit 1
    fi
    
    # Check Terraform version
    TERRAFORM_VER=$(terraform version -json | jq -r '.terraform_version')
    log_info "Terraform version: $TERRAFORM_VER"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' or set environment variables."
        exit 1
    fi
    
    # Get AWS account info
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    CURRENT_REGION=$(aws configure get region)
    log_info "AWS Account ID: $ACCOUNT_ID"
    log_info "AWS Region: $CURRENT_REGION"
    
    log_success "Prerequisites check completed"
}

validate_terraform_files() {
    log_info "Validating Terraform configuration..."
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        log_warning "terraform.tfvars not found. Creating from example..."
        if [ -f "terraform.tfvars.example" ]; then
            cp terraform.tfvars.example terraform.tfvars
            log_warning "Please edit terraform.tfvars with your specific values before continuing."
            read -p "Press Enter to continue after editing terraform.tfvars..."
        else
            log_error "terraform.tfvars.example not found. Cannot create configuration file."
            exit 1
        fi
    fi
    
    # Validate Terraform syntax
    terraform fmt -check=true -diff=true || {
        log_warning "Terraform files need formatting. Running terraform fmt..."
        terraform fmt
    }
    
    terraform validate
    log_success "Terraform validation completed"
}

create_lambda_packages() {
    log_info "Creating Lambda deployment packages..."
    
    # Create script directory if it doesn't exist
    mkdir -p script
    
    # Check if Lambda functions exist
    LAMBDA_FUNCTIONS=(
        "textract-processor.js"
        "store-extracted-data.js"
        "validate-invoice.js"
        "process-invoice.js"
        "send-notification.js"
    )
    
    for func in "${LAMBDA_FUNCTIONS[@]}"; do
        if [ ! -f "script/$func" ]; then
            log_warning "Lambda function script/$func not found"
        else
            log_info "Found script/$func"
        fi
    done
    
    # Install Node.js dependencies if package.json exists
    if [ -f "script/package.json" ]; then
        log_info "Installing Node.js dependencies..."
        cd script
        npm install --production
        cd ..
    fi
    
    log_success "Lambda packages prepared"
}

deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init -upgrade
    
    # Create Terraform plan
    log_info "Creating Terraform plan..."
    terraform plan -out=tfplan -var-file=terraform.tfvars
    
    # Ask for confirmation
    echo
    log_warning "Review the Terraform plan above."
    read -p "Do you want to apply these changes? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Deployment cancelled by user"
        exit 0
    fi
    
    # Apply Terraform plan
    log_info "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Clean up plan file
    rm -f tfplan
    
    log_success "Infrastructure deployment completed"
}

test_deployment() {
    log_info "Testing deployment..."
    
    # Get outputs from Terraform
    RAW_BUCKET=$(terraform output -raw raw_invoice_bucket_name 2>/dev/null || echo "")
    PROCESSED_BUCKET=$(terraform output -raw processed_invoice_bucket_name 2>/dev/null || echo "")
    
    if [ -n "$RAW_BUCKET" ]; then
        log_info "Raw invoice bucket: $RAW_BUCKET"
        
        # Test S3 bucket access
        if aws s3 ls "s3://$RAW_BUCKET" &> /dev/null; then
            log_success "S3 bucket access test passed"
        else
            log_error "S3 bucket access test failed"
        fi
    fi
    
    # Test Lambda functions
    LAMBDA_FUNCTIONS=$(aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `textract-processor`)].FunctionName' --output text)
    
    if [ -n "$LAMBDA_FUNCTIONS" ]; then
        log_success "Lambda functions deployed successfully"
    else
        log_warning "No Lambda functions found with expected naming pattern"
    fi
    
    # Run comprehensive test if test script exists
    if [ -f "test-complete-system.js" ]; then
        log_info "Running comprehensive system test..."
        if command -v node &> /dev/null; then
            node test-complete-system.js
        else
            log_warning "Node.js not found. Skipping comprehensive test."
        fi
    fi
    
    log_success "Deployment testing completed"
}

show_outputs() {
    log_info "Deployment outputs:"
    echo
    terraform output
    echo
    
    log_info "Important URLs and ARNs:"
    
    # Get key outputs
    RAW_BUCKET=$(terraform output -raw raw_invoice_bucket_name 2>/dev/null || echo "Not available")
    PROCESSED_BUCKET=$(terraform output -raw processed_invoice_bucket_name 2>/dev/null || echo "Not available")
    DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null || echo "Not available")
    
    echo "Raw Invoice Bucket: $RAW_BUCKET"
    echo "Processed Invoice Bucket: $PROCESSED_BUCKET"
    echo "DynamoDB Table: $DYNAMODB_TABLE"
    echo
    
    log_info "CloudWatch Dashboard: https://${CURRENT_REGION}.console.aws.amazon.com/cloudwatch/home?region=${CURRENT_REGION}#dashboards:name=InvoiceProcessingSystem"
    log_info "Lambda Functions: https://${CURRENT_REGION}.console.aws.amazon.com/lambda/home?region=${CURRENT_REGION}#/functions"
    log_info "S3 Buckets: https://s3.console.aws.amazon.com/s3/home?region=${CURRENT_REGION}"
}

cleanup_on_error() {
    log_error "Deployment failed. Cleaning up..."
    
    # Remove Terraform plan file if it exists
    rm -f tfplan
    
    # Optionally destroy resources (uncomment if needed)
    # terraform destroy -auto-approve -var-file=terraform.tfvars
    
    exit 1
}

main() {
    log_info "Starting Invoice Processing System deployment..."
    log_info "Environment: $ENVIRONMENT"
    log_info "Region: $REGION"
    echo
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Run deployment steps
    check_prerequisites
    validate_terraform_files
    create_lambda_packages
    deploy_infrastructure
    test_deployment
    show_outputs
    
    echo
    log_success "🎉 Invoice Processing System deployed successfully!"
    log_info "You can now upload invoice documents to the raw S3 bucket to test the system."
    log_info "Monitor the system using the CloudWatch dashboard and check your email for notifications."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment|-e)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --region|-r)
            REGION="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -e, --environment    Environment (dev, staging, production)"
            echo "  -r, --region         AWS region"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main
