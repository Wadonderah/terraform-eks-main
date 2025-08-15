# Complete Automated Invoice Processing System

This repository contains a comprehensive AWS-based invoice processing system that automatically extracts data from invoice documents using Amazon Textract, processes the data through Lambda functions, stores it in DynamoDB, and sends notifications via SNS.

## 🏗️ Architecture Overview

```
PDF/Image Upload → S3 (Raw) → Textract → Lambda → DynamoDB
                                ↓
                            Step Functions ← Manual Processing
                                ↓
                            Notifications (SNS)
                                ↓
                            S3 (Processed)
```

## 📁 Project Structure

```
lambda/
├── textract-infrastructure/          # NEW: Modular Terraform structure
│   ├── main.tf                      # Main configuration
│   ├── variables.tf                 # Input variables
│   ├── outputs.tf                   # Output values
│   └── modules/                     # Terraform modules
│       ├── s3/                      # S3 bucket configurations
│       ├── dynamodb/                # DynamoDB table setup
│       ├── sns/                     # SNS topic and subscriptions
│       ├── lambda/                  # Lambda function definitions
│       └── step-functions/          # Step Functions workflow
├── script/                          # Lambda function code
│   ├── textract-processor.js       # NEW: Textract processing
│   ├── store-extracted-data.js     # NEW: Data storage
│   ├── validate-invoice.js         # Invoice validation
│   ├── process-invoice.js          # Invoice processing
│   └── send-notification.js        # Notification handling
├── 01-providers.tf                  # AWS provider configuration
├── 02-variables.tf                  # Variables (updated)
├── 04-lambda.tf                     # Lambda functions (updated)
├── 05-output.tf                     # Outputs (updated)
├── 06-s3.tf                         # S3 buckets (updated)
├── 07-dynamodb.tf                   # DynamoDB table
├── 09-step.tf                       # Step Functions
├── 10-sns.tf                        # NEW: SNS configuration
├── test-complete-system.js          # NEW: Complete system testing
└── COMPLETE_SYSTEM_README.md        # This documentation
```

## 🆕 New Components Added

### 1. **Amazon Textract Integration**
- **textract-processor.js**: Automatically processes uploaded PDFs/images
- Extracts text, tables, and key-value pairs
- Identifies invoice-specific data (number, date, amount, vendor)

### 2. **Dual S3 Bucket Architecture**
- **Raw Bucket**: `invoice-uploads-{suffix}` - For original document uploads
- **Processed Bucket**: `processed-invoices-{suffix}` - For processed JSON data
- Automatic S3 event triggers for Textract processing

### 3. **Enhanced Data Storage**
- **store-extracted-data.js**: Stores Textract results in DynamoDB
- Generates unique invoice IDs and customer IDs
- Handles duplicate detection
- Stores both structured data and raw text

### 4. **SNS Notification System**
- Email notifications for processing status
- Success, error, and duplicate notifications
- Configurable notification endpoints

### 5. **Modular Terraform Structure**
- Organized into reusable modules
- Better separation of concerns
- Easier maintenance and scaling

## 🚀 Deployment Instructions

### Prerequisites
1. **AWS CLI configured** with valid credentials
2. **Terraform installed** (version >= 1.0)
3. **Node.js** (for testing scripts)

### Step 1: Deploy the Infrastructure

```bash
# Navigate to the lambda directory
cd /mnt/c/Users/Wadonderah/terraform-eks-main/lambda

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

### Step 2: Deploy Modular Structure (Optional)

```bash
# Navigate to the modular structure
cd textract-infrastructure

# Initialize and deploy modular version
terraform init
terraform plan -var="notification_email=your-email@example.com"
terraform apply -var="notification_email=your-email@example.com"
```

### Step 3: Note Important Outputs

After deployment, save these important values:
- S3 bucket names
- Lambda function ARNs
- Step Functions ARN
- SNS topic ARN
- DynamoDB table name

## 🧪 Testing the System

### Method 1: Complete System Test

```bash
# Update configuration in test-complete-system.js
node test-complete-system.js
```

### Method 2: Manual Testing

1. **Upload a test invoice**:
```bash
aws s3 cp test-invoice.pdf s3://invoice-uploads-XXXXXXXX/
```

2. **Monitor processing**:
```bash
# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/textract"

# Check DynamoDB
aws dynamodb scan --table-name lambda_invoice_dynamoDB --limit 5
```

3. **Test Step Functions**:
```bash
aws stepfunctions start-execution \
  --state-machine-arn "arn:aws:states:region:account:stateMachine:invoice-automation-workflow" \
  --input '{"invoice":{"invoiceId":"TEST-001","customerId":"CUST-001","amount":1000,"dueDate":"2024-12-31"}}'
```

## 📋 Supported File Formats

The system supports the following invoice formats:
- **PDF** documents
- **PNG** images
- **JPEG/JPG** images
- **TIFF/TIF** images

## 🔄 Processing Workflow

### Automatic Processing (Textract)
1. **Upload**: Document uploaded to raw S3 bucket
2. **Trigger**: S3 event triggers Textract processor Lambda
3. **Extract**: Textract analyzes document and extracts data
4. **Store**: Extracted data stored in DynamoDB and processed S3 bucket
5. **Notify**: Success/error notifications sent via SNS

### Manual Processing (Step Functions)
1. **Input**: JSON invoice data provided manually
2. **Validate**: Invoice validation Lambda checks data integrity
3. **Process**: Invoice processing Lambda stores data in DynamoDB
4. **Notify**: Notification Lambda sends status updates

## 📊 Data Schema

### DynamoDB Table Structure
```json
{
  "customerId": "CUST-123",           // Partition key
  "invoiceNumber": 1234567890,       // Sort key (numeric)
  "invoiceId": "INV-001",            // Business invoice ID
  "originalFileName": "invoice.pdf",
  "extractedAt": "2024-01-01T12:00:00Z",
  "processedAt": "2024-01-01T12:01:00Z",
  "invoiceDate": "2024-01-01",
  "dueDate": "2024-01-31",
  "totalAmount": 1500.00,
  "vendorName": "ABC Company",
  "status": "processed",
  "rawText": "Full extracted text...",
  "keyValuePairs": {...}
}
```

### S3 Processed Data Structure
```json
{
  "fileName": "invoice.pdf",
  "extractedAt": "2024-01-01T12:00:00Z",
  "invoiceData": {
    "invoiceNumber": "INV-001",
    "invoiceDate": "2024-01-01",
    "totalAmount": 1500.00,
    "vendorName": "ABC Company"
  },
  "rawText": "Full extracted text...",
  "keyValuePairs": {...}
}
```

## 🔧 Configuration

### Environment Variables
- `DYNAMODB_TABLE_NAME`: DynamoDB table name
- `SNS_TOPIC_ARN`: SNS topic for notifications
- `PROCESSED_BUCKET_NAME`: S3 bucket for processed data
- `STORAGE_LAMBDA_NAME`: Name of data storage Lambda

### Terraform Variables
- `raw_invoice_bucket_name`: Raw uploads bucket name
- `processed_invoice_bucket_name`: Processed data bucket name
- `sns_topic_name`: SNS topic name
- `notification_email`: Email for notifications
- `textract_lambda_timeout`: Lambda timeout (seconds)

## 🔐 Security Features

1. **IAM Roles**: Least privilege access for all services
2. **S3 Encryption**: Server-side encryption enabled
3. **VPC**: Optional VPC deployment for network isolation
4. **Bucket Policies**: Public access blocked
5. **Resource Tagging**: Comprehensive tagging for governance

## 📈 Monitoring and Logging

### CloudWatch Logs
- `/aws/lambda/textract-processor`
- `/aws/lambda/store-extracted-data`
- `/aws/lambda/validate-invoice`
- `/aws/lambda/process-invoice`
- `/aws/stepfunctions/invoice-automation`

### Metrics to Monitor
- Lambda execution duration and errors
- S3 upload/download metrics
- DynamoDB read/write capacity
- Step Functions execution success rate
- SNS message delivery rate

## 🛠️ Troubleshooting

### Common Issues

1. **Textract Processing Fails**
   - Check file format is supported
   - Verify S3 permissions
   - Check Lambda timeout settings

2. **DynamoDB Access Denied**
   - Verify IAM role permissions
   - Check table name configuration

3. **SNS Notifications Not Received**
   - Confirm email subscription
   - Check SNS topic permissions
   - Verify email address format

4. **Step Functions Execution Fails**
   - Check Lambda function permissions
   - Verify input JSON format
   - Review CloudWatch logs

### Debug Commands

```bash
# Check Lambda logs
aws logs tail /aws/lambda/textract-processor --follow

# List S3 objects
aws s3 ls s3://invoice-uploads-XXXXXXXX/ --recursive

# Check DynamoDB items
aws dynamodb scan --table-name lambda_invoice_dynamoDB

# List Step Functions executions
aws stepfunctions list-executions --state-machine-arn "arn:aws:states:..."
```

## 🔄 Customization

### Adding New File Formats
Update `textract-processor.js`:
```javascript
const supportedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.tiff', '.tif', '.bmp'];
```

### Custom Validation Rules
Modify `validate-invoice.js`:
```javascript
// Add custom validation
if (invoice.amount > 10000) {
    return { isValid: false, error: 'Amount exceeds limit' };
}
```

### Additional Notification Channels
Update `send-notification.js` to integrate with:
- Slack webhooks
- Microsoft Teams
- Custom APIs
- SMS via SNS

## 💰 Cost Optimization

1. **Lambda**: Right-size memory allocation
2. **S3**: Use Intelligent Tiering for long-term storage
3. **DynamoDB**: Use on-demand billing for variable workloads
4. **Textract**: Batch process documents when possible
5. **CloudWatch**: Set appropriate log retention periods

## 🔮 Future Enhancements

1. **API Gateway**: REST API for external integrations
2. **Machine Learning**: Custom models for better extraction
3. **Batch Processing**: Handle multiple documents simultaneously
4. **Data Analytics**: QuickSight dashboards for insights
5. **Approval Workflow**: Human review for high-value invoices

## 📞 Support

For issues or questions:
1. Check CloudWatch logs for detailed error messages
2. Review AWS service documentation
3. Test individual components before full workflow
4. Use the provided testing scripts for debugging

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Note**: Remember to replace placeholder values (XXXXXXXX, account IDs, etc.) with your actual AWS resource identifiers after deployment.
