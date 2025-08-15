# AWS Invoice Processing System

A complete automated invoice processing system built with AWS services including Textract, Lambda, Step Functions, S3, DynamoDB, and SNS.

## 🏗️ Architecture

```
PDF/Image Upload → S3 → Textract → Lambda → DynamoDB
                           ↓
                    Step Functions ← Manual Processing
                           ↓
                    Notifications (SNS)
```

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Node.js (for testing)

### Deployment

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/terraform-eks-main.git
   cd terraform-eks-main/lambda
   ```

2. **Configure variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Deploy infrastructure:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Test the system:**
   ```bash
   # Update test configuration with your resource ARNs
   node test-complete-system.js
   ```

## 📁 Project Structure

```
├── lambda/                          # Main invoice processing system
│   ├── script/                      # Lambda function code
│   ├── textract-infrastructure/     # Modular Terraform structure
│   ├── *.tf                        # Terraform configuration files
│   └── test-*.js                   # Testing scripts
├── using-modules/                   # EKS with modules
├── without-modules/                 # EKS without modules
└── README.md                       # This file
```

## 🔧 Configuration

### Required Variables

Create a `terraform.tfvars` file:

```hcl
tf_region = "ca-central-1"
notification_email = "your-email@domain.com"
raw_invoice_bucket_name = "your-invoice-uploads"
processed_invoice_bucket_name = "your-processed-invoices"
```

### AWS Permissions Required

The deployment requires permissions for:
- S3 (bucket creation and management)
- Lambda (function creation and execution)
- DynamoDB (table creation and management)
- Textract (document analysis)
- Step Functions (state machine creation)
- SNS (topic and subscription management)
- IAM (role and policy creation)
- CloudWatch (logging)

## 🧪 Testing

### Automated Testing
```bash
node test-complete-system.js
```

### Manual Testing
1. Upload a PDF invoice to the raw S3 bucket
2. Monitor CloudWatch logs for processing
3. Check DynamoDB for extracted data
4. Verify email notifications

## 📊 Features

- ✅ **Automatic PDF/Image Processing** with Amazon Textract
- ✅ **Dual Processing Modes**: Automatic (Textract) + Manual (Step Functions)
- ✅ **Data Storage** in DynamoDB with structured schema
- ✅ **Email Notifications** via SNS
- ✅ **Error Handling** with retries and fallbacks
- ✅ **Security** with least-privilege IAM roles
- ✅ **Monitoring** with CloudWatch integration

## 🔐 Security

- All S3 buckets have public access blocked
- IAM roles follow least-privilege principle
- Server-side encryption enabled
- No hardcoded credentials in code

## 💰 Cost Estimation

Estimated monthly costs for moderate usage:
- Lambda: $5-15
- S3: $2-10
- DynamoDB: $5-20
- Textract: $10-50 (depends on document volume)
- Other services: $5-10

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- Check [Issues](https://github.com/YOUR_USERNAME/terraform-eks-main/issues) for common problems
- Review CloudWatch logs for debugging
- Consult AWS documentation for service-specific issues

## 🔄 Changelog

### v1.0.0
- Initial release with complete invoice processing system
- Textract integration for automatic document processing
- Step Functions workflow for manual processing
- SNS notifications and comprehensive testing

---

**⚠️ Important**: Never commit sensitive files like `terraform.tfstate`, `*.tfvars`, or AWS credentials to version control.
