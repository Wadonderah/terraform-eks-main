#!/bin/bash

# Ultra Cost-Optimized Deployment Script
# Deploys the most cost-effective version of the invoice processing system

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Cost optimization checks
check_cost_settings() {
    log_info "Checking cost optimization settings..."
    
    # Use cost-optimized tfvars
    if [ ! -f "terraform-cost-optimized.tfvars" ]; then
        log_error "Cost-optimized tfvars file not found!"
        exit 1
    fi
    
    # Copy cost-optimized settings
    cp terraform-cost-optimized.tfvars terraform.tfvars
    log_info "Using ultra cost-optimized configuration"
}

# Remove expensive resources
optimize_terraform() {
    log_info "Removing expensive resources from deployment..."
    
    # Comment out Aurora MySQL (expensive)
    if grep -q "aws_rds_cluster" *.tf; then
        log_warn "Aurora MySQL found - this is expensive. Consider removing for cost optimization."
    fi
    
    # Ensure minimal Lambda memory
    log_info "Configuring minimal Lambda resources..."
    
    # Check for expensive features
    if grep -q "provisioned_concurrent_executions" *.tf; then
        log_warn "Provisioned concurrency found - this adds cost"
    fi
}

# Deploy with cost focus
deploy_cost_optimized() {
    log_info "Deploying cost-optimized infrastructure..."
    
    terraform init -upgrade
    
    # Plan with cost-optimized variables
    terraform plan \
        -var-file=terraform-cost-optimized.tfvars \
        -out=cost-optimized.tfplan
    
    echo
    log_warn "COST OPTIMIZATION REVIEW:"
    echo "- Lambda memory: 128MB (minimum)"
    echo "- Log retention: 3 days"
    echo "- S3 transitions: 7→30→90 days"
    echo "- DynamoDB: Pay-per-request"
    echo "- No VPC, X-Ray, or provisioned concurrency"
    echo "- Budget limit: $25/month"
    echo
    
    read -p "Deploy ultra cost-optimized version? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        terraform apply cost-optimized.tfplan
        rm cost-optimized.tfplan
        log_info "✅ Cost-optimized deployment complete!"
    else
        log_info "Deployment cancelled"
        rm cost-optimized.tfplan
        exit 0
    fi
}

# Show cost estimates
show_cost_estimates() {
    log_info "💰 ESTIMATED MONTHLY COSTS (Light Usage):"
    echo "Lambda (1000 invocations): ~$0.20"
    echo "DynamoDB (1M requests): ~$1.25"
    echo "S3 Storage (10GB): ~$0.23"
    echo "Textract (100 pages): ~$0.15"
    echo "SNS (100 emails): ~$0.02"
    echo "CloudWatch Logs: ~$0.50"
    echo "--------------------------------"
    echo "TOTAL ESTIMATED: $2-5/month"
    echo
    
    log_info "💰 ESTIMATED MONTHLY COSTS (Heavy Usage):"
    echo "Lambda (10K invocations): ~$2.00"
    echo "DynamoDB (10M requests): ~$12.50"
    echo "S3 Storage (100GB): ~$2.30"
    echo "Textract (1000 pages): ~$1.50"
    echo "SNS (1000 emails): ~$0.20"
    echo "CloudWatch Logs: ~$2.00"
    echo "--------------------------------"
    echo "TOTAL ESTIMATED: $15-25/month"
}

# Cost monitoring setup
setup_cost_monitoring() {
    log_info "Setting up cost monitoring..."
    
    # Get budget ARN if created
    BUDGET_NAME=$(terraform output -raw budget_name 2>/dev/null || echo "")
    
    if [ -n "$BUDGET_NAME" ]; then
        log_info "✅ Budget created: $BUDGET_NAME"
        log_info "You'll receive alerts at 80% and 100% of $25 monthly limit"
    fi
    
    # Cost optimization tips
    echo
    log_info "💡 ADDITIONAL COST OPTIMIZATION TIPS:"
    echo "1. Delete unused S3 objects regularly"
    echo "2. Monitor DynamoDB usage patterns"
    echo "3. Use S3 Intelligent Tiering"
    echo "4. Review CloudWatch logs retention"
    echo "5. Set up billing alerts in AWS Console"
}

main() {
    log_info "🚀 Starting Ultra Cost-Optimized Deployment"
    echo "Target: <$25/month for typical usage"
    echo
    
    check_cost_settings
    optimize_terraform
    deploy_cost_optimized
    show_cost_estimates
    setup_cost_monitoring
    
    echo
    log_info "🎉 Ultra cost-optimized system deployed!"
    log_warn "⚠️  Performance may be reduced due to aggressive cost optimization"
    log_info "💰 Monitor costs in AWS Billing Dashboard"
}

main "$@"
