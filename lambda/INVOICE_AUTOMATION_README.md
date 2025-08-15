# Invoice Automation with AWS Step Functions and Lambda

This system provides a complete invoice automation workflow using AWS Step Functions, Lambda, and DynamoDB.

## Architecture Overview

```
Invoice Input → Step Functions → Lambda Functions → DynamoDB/Notifications
```

### Components:

1. **Step Functions State Machine**: Orchestrates the entire workflow
2. **Lambda Functions**:
   - `validate-invoice`: Validates invoice data
   - `process-invoice`: Processes and stores invoices in DynamoDB
   - `send-notification`: Sends notifications based on processing results
3. **DynamoDB Table**: Stores processed invoices
4. **CloudWatch Logs**: Monitors and logs all activities

## Workflow Steps

1. **Invoice Validation**
   - Checks required fields (invoiceId, customerId, amount, dueDate)
   - Validates amount is positive
   - Ensures due date is in the future

2. **Invoice Processing**
   - Generates unique invoice number
   - Stores invoice in DynamoDB
   - Handles duplicate detection

3. **Notification Handling**
   - Sends success notifications for processed invoices
   - Sends error notifications for failed validations/processing
   - Handles duplicate invoice notifications

## Deployment Instructions

1. **Prerequisites**:
   ```bash
   # Ensure AWS credentials are configured
   aws configure
   
   # Verify credentials
   aws sts get-caller-identity
   ```

2. **Deploy Infrastructure**:
   ```bash
   cd /mnt/c/Users/Wadonderah/terraform-eks-main/lambda
   terraform init
   terraform plan
   terraform apply
   ```

3. **Note the Outputs**:
   After deployment, note the Step Functions ARN and other resource ARNs from the output.

## Testing the System

### Method 1: Using the Test Script

1. Update the `stateMachineArn` in `test-invoice-automation.js` with your actual ARN
2. Install dependencies: `npm install aws-sdk`
3. Run: `node test-invoice-automation.js`

### Method 2: Using AWS CLI

```bash
# Replace YOUR_ACCOUNT_ID with your actual AWS account ID
STATE_MACHINE_ARN="arn:aws:states:us-west-2:YOUR_ACCOUNT_ID:stateMachine:invoice-automation-workflow"

# Test with valid invoice
aws stepfunctions start-execution \
  --state-machine-arn "$STATE_MACHINE_ARN" \
  --name "test-valid-$(date +%s)" \
  --input '{
    "invoice": {
      "invoiceId": "INV-001",
      "customerId": "CUST-123",
      "customerEmail": "customer@example.com",
      "amount": 1500.00,
      "dueDate": "2024-12-31",
      "description": "Professional services"
    }
  }'

# Test with invalid invoice
aws stepfunctions start-execution \
  --state-machine-arn "$STATE_MACHINE_ARN" \
  --name "test-invalid-$(date +%s)" \
  --input '{
    "invoice": {
      "invoiceId": "INV-002",
      "customerId": "CUST-456"
    }
  }'
```

### Method 3: Using AWS Console

1. Go to AWS Step Functions Console
2. Select "invoice-automation-workflow"
3. Click "Start execution"
4. Paste sample JSON input:

```json
{
  "invoice": {
    "invoiceId": "INV-TEST-001",
    "customerId": "CUST-123",
    "customerEmail": "test@example.com",
    "amount": 1000.00,
    "dueDate": "2024-12-31",
    "description": "Test invoice for automation"
  }
}
```

## Sample Invoice Formats

### Valid Invoice
```json
{
  "invoice": {
    "invoiceId": "INV-001",
    "customerId": "CUST-123",
    "customerEmail": "customer@example.com",
    "amount": 1500.00,
    "dueDate": "2024-12-31",
    "description": "Professional services for Q4 2024",
    "items": [
      {
        "description": "Consulting hours",
        "quantity": 50,
        "rate": 30.00
      }
    ]
  }
}
```

### Invalid Invoice (Missing Fields)
```json
{
  "invoice": {
    "invoiceId": "INV-002",
    "customerId": "CUST-456"
  }
}
```

## Monitoring and Troubleshooting

### CloudWatch Logs
- Step Functions logs: `/aws/stepfunctions/invoice-automation`
- Lambda logs: `/aws/lambda/validate-invoice`, `/aws/lambda/process-invoice`, `/aws/lambda/send-notification`

### Common Issues

1. **InvalidClientTokenId Error**
   - Solution: Update AWS credentials using `aws configure`

2. **Lambda Function Not Found**
   - Solution: Ensure all Lambda functions are deployed successfully

3. **DynamoDB Access Denied**
   - Solution: Check IAM permissions for Lambda execution role

4. **Step Functions Execution Failed**
   - Solution: Check CloudWatch logs for detailed error messages

## Customization

### Adding New Validation Rules
Edit `validate-invoice.js` to add custom validation logic:

```javascript
// Add custom validation
if (invoice.amount > 10000) {
    return {
        statusCode: 400,
        isValid: false,
        error: 'Invoice amount exceeds maximum limit'
    };
}
```

### Adding New Processing Steps
Modify the Step Functions definition in `09-step.tf` to add new states:

```json
"NewProcessingStep": {
  "Type": "Task",
  "Resource": "arn:aws:lambda:region:account:function:new-function",
  "Next": "NextStep"
}
```

### Integrating with External Systems
Update Lambda functions to integrate with:
- Email services (SES, SendGrid)
- SMS services (SNS)
- ERP systems
- Payment gateways

## Security Considerations

1. **IAM Roles**: Use least privilege principle
2. **Encryption**: Enable encryption for DynamoDB and Lambda environment variables
3. **VPC**: Deploy Lambda functions in VPC for network isolation
4. **Secrets**: Use AWS Secrets Manager for sensitive data

## Cost Optimization

1. **Lambda**: Use appropriate memory allocation
2. **Step Functions**: Use Express workflows for high-volume, short-duration workflows
3. **DynamoDB**: Use on-demand billing for variable workloads
4. **CloudWatch**: Set appropriate log retention periods

## Next Steps

1. **Replace ANS**: Update notification logic to use your preferred notification service
2. **Add Authentication**: Implement API Gateway with authentication
3. **Add Monitoring**: Set up CloudWatch alarms and dashboards
4. **Add Testing**: Implement automated testing with AWS SAM or Serverless Framework
5. **Add CI/CD**: Set up deployment pipeline with AWS CodePipeline

## Support

For issues or questions:
1. Check CloudWatch logs for detailed error messages
2. Review AWS documentation for Step Functions and Lambda
3. Test individual Lambda functions before running the full workflow
