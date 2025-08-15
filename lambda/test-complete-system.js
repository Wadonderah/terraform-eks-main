#!/usr/bin/env node

/**
 * Complete Invoice Processing System Test Script
 * 
 * This script tests the entire invoice processing pipeline:
 * 1. Upload test files to S3
 * 2. Monitor Textract processing
 * 3. Verify data storage in DynamoDB
 * 4. Test Step Functions workflow
 * 5. Check notifications
 */

const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');

// Configure AWS SDK
const s3 = new AWS.S3();
const dynamodb = new AWS.DynamoDB.DocumentClient();
const stepfunctions = new AWS.StepFunctions();
const sns = new AWS.SNS();

// Configuration (update these after deployment)
const CONFIG = {
    region: 'us-west-2', // Update with your region
    rawBucketName: 'invoice-uploads-XXXXXXXX', // Update with actual bucket name
    processedBucketName: 'processed-invoices-XXXXXXXX', // Update with actual bucket name
    dynamoTableName: 'lambda_invoice_dynamoDB', // Update with actual table name
    stepFunctionArn: 'arn:aws:states:us-west-2:ACCOUNT:stateMachine:invoice-automation-workflow',
    snsTopicArn: 'arn:aws:sns:us-west-2:ACCOUNT:invoice-processing-notifications'
};

// Test data
const TEST_INVOICES = [
    {
        name: 'test-invoice-1.json',
        content: JSON.stringify({
            invoice: {
                invoiceId: 'TEST-001',
                customerId: 'CUST-TEST-001',
                customerEmail: 'test@example.com',
                amount: 1500.00,
                dueDate: '2024-12-31',
                description: 'Test invoice for automated processing',
                items: [
                    { description: 'Consulting services', quantity: 10, rate: 150.00 }
                ]
            }
        }, null, 2)
    },
    {
        name: 'test-invoice-2.json',
        content: JSON.stringify({
            invoice: {
                invoiceId: 'TEST-002',
                customerId: 'CUST-TEST-002',
                customerEmail: 'test2@example.com',
                amount: 2500.00,
                dueDate: '2024-11-30',
                description: 'Another test invoice',
                items: [
                    { description: 'Development work', quantity: 25, rate: 100.00 }
                ]
            }
        }, null, 2)
    }
];

class InvoiceProcessingTester {
    constructor() {
        this.testResults = {
            s3Upload: [],
            textractProcessing: [],
            dynamoStorage: [],
            stepFunctions: [],
            notifications: []
        };
    }

    async runAllTests() {
        console.log('🚀 Starting Complete Invoice Processing System Tests\n');
        console.log('Configuration:', CONFIG);
        console.log('\n' + '='.repeat(60) + '\n');

        try {
            // Test 1: S3 Upload
            await this.testS3Upload();
            
            // Test 2: Wait and check Textract processing
            await this.testTextractProcessing();
            
            // Test 3: Verify DynamoDB storage
            await this.testDynamoStorage();
            
            // Test 4: Test Step Functions workflow
            await this.testStepFunctions();
            
            // Test 5: Check notifications
            await this.testNotifications();
            
            // Generate report
            this.generateReport();
            
        } catch (error) {
            console.error('❌ Test suite failed:', error);
        }
    }

    async testS3Upload() {
        console.log('📤 Testing S3 Upload...');
        
        for (const testFile of TEST_INVOICES) {
            try {
                const params = {
                    Bucket: CONFIG.rawBucketName,
                    Key: `test-uploads/${testFile.name}`,
                    Body: testFile.content,
                    ContentType: 'application/json'
                };
                
                const result = await s3.upload(params).promise();
                console.log(`✅ Uploaded: ${testFile.name} to ${result.Location}`);
                
                this.testResults.s3Upload.push({
                    file: testFile.name,
                    status: 'success',
                    location: result.Location
                });
                
            } catch (error) {
                console.error(`❌ Failed to upload ${testFile.name}:`, error.message);
                this.testResults.s3Upload.push({
                    file: testFile.name,
                    status: 'failed',
                    error: error.message
                });
            }
        }
        
        console.log('\n');
    }

    async testTextractProcessing() {
        console.log('🔍 Testing Textract Processing (waiting 30 seconds for processing)...');
        
        // Wait for processing
        await this.sleep(30000);
        
        try {
            // Check processed bucket for results
            const params = {
                Bucket: CONFIG.processedBucketName,
                Prefix: 'processed/'
            };
            
            const result = await s3.listObjectsV2(params).promise();
            
            if (result.Contents && result.Contents.length > 0) {
                console.log(`✅ Found ${result.Contents.length} processed files`);
                result.Contents.forEach(obj => {
                    console.log(`   - ${obj.Key} (${obj.Size} bytes)`);
                });
                
                this.testResults.textractProcessing.push({
                    status: 'success',
                    processedFiles: result.Contents.length
                });
            } else {
                console.log('⚠️  No processed files found yet');
                this.testResults.textractProcessing.push({
                    status: 'pending',
                    message: 'No processed files found'
                });
            }
            
        } catch (error) {
            console.error('❌ Error checking processed files:', error.message);
            this.testResults.textractProcessing.push({
                status: 'failed',
                error: error.message
            });
        }
        
        console.log('\n');
    }

    async testDynamoStorage() {
        console.log('🗄️  Testing DynamoDB Storage...');
        
        try {
            const params = {
                TableName: CONFIG.dynamoTableName,
                Limit: 10
            };
            
            const result = await dynamodb.scan(params).promise();
            
            console.log(`✅ Found ${result.Items.length} items in DynamoDB`);
            
            if (result.Items.length > 0) {
                console.log('Recent items:');
                result.Items.slice(0, 3).forEach(item => {
                    console.log(`   - Invoice: ${item.invoiceId || item.invoiceNumber}, Customer: ${item.customerId}`);
                });
            }
            
            this.testResults.dynamoStorage.push({
                status: 'success',
                itemCount: result.Items.length
            });
            
        } catch (error) {
            console.error('❌ Error checking DynamoDB:', error.message);
            this.testResults.dynamoStorage.push({
                status: 'failed',
                error: error.message
            });
        }
        
        console.log('\n');
    }

    async testStepFunctions() {
        console.log('⚙️  Testing Step Functions Workflow...');
        
        const testInvoice = {
            invoice: {
                invoiceId: 'STEP-TEST-001',
                customerId: 'CUST-STEP-001',
                customerEmail: 'steptest@example.com',
                amount: 999.99,
                dueDate: '2024-12-15',
                description: 'Step Functions test invoice'
            }
        };
        
        try {
            const params = {
                stateMachineArn: CONFIG.stepFunctionArn,
                name: `test-execution-${Date.now()}`,
                input: JSON.stringify(testInvoice)
            };
            
            const result = await stepfunctions.startExecution(params).promise();
            console.log(`✅ Step Functions execution started: ${result.executionArn}`);
            
            // Wait a bit and check status
            await this.sleep(10000);
            
            const statusParams = {
                executionArn: result.executionArn
            };
            
            const status = await stepfunctions.describeExecution(statusParams).promise();
            console.log(`   Status: ${status.status}`);
            
            this.testResults.stepFunctions.push({
                status: 'success',
                executionArn: result.executionArn,
                executionStatus: status.status
            });
            
        } catch (error) {
            console.error('❌ Error testing Step Functions:', error.message);
            this.testResults.stepFunctions.push({
                status: 'failed',
                error: error.message
            });
        }
        
        console.log('\n');
    }

    async testNotifications() {
        console.log('📧 Testing SNS Notifications...');
        
        try {
            const params = {
                TopicArn: CONFIG.snsTopicArn,
                Subject: 'Test Notification from Invoice Processing System',
                Message: JSON.stringify({
                    type: 'test',
                    message: 'This is a test notification from the invoice processing system',
                    timestamp: new Date().toISOString(),
                    testId: `test-${Date.now()}`
                }, null, 2)
            };
            
            const result = await sns.publish(params).promise();
            console.log(`✅ Test notification sent: ${result.MessageId}`);
            
            this.testResults.notifications.push({
                status: 'success',
                messageId: result.MessageId
            });
            
        } catch (error) {
            console.error('❌ Error sending test notification:', error.message);
            this.testResults.notifications.push({
                status: 'failed',
                error: error.message
            });
        }
        
        console.log('\n');
    }

    generateReport() {
        console.log('📊 TEST RESULTS SUMMARY');
        console.log('='.repeat(60));
        
        const categories = [
            { name: 'S3 Upload', results: this.testResults.s3Upload },
            { name: 'Textract Processing', results: this.testResults.textractProcessing },
            { name: 'DynamoDB Storage', results: this.testResults.dynamoStorage },
            { name: 'Step Functions', results: this.testResults.stepFunctions },
            { name: 'Notifications', results: this.testResults.notifications }
        ];
        
        categories.forEach(category => {
            console.log(`\n${category.name}:`);
            if (category.results.length === 0) {
                console.log('  No tests run');
            } else {
                category.results.forEach(result => {
                    const status = result.status === 'success' ? '✅' : 
                                 result.status === 'failed' ? '❌' : '⚠️';
                    console.log(`  ${status} ${result.status.toUpperCase()}`);
                    if (result.error) {
                        console.log(`     Error: ${result.error}`);
                    }
                });
            }
        });
        
        console.log('\n' + '='.repeat(60));
        console.log('🏁 Testing complete! Check AWS Console for detailed logs and results.');
        
        // Instructions
        console.log('\n📋 NEXT STEPS:');
        console.log('1. Check CloudWatch Logs for Lambda function execution details');
        console.log('2. Monitor Step Functions console for workflow executions');
        console.log('3. Verify email notifications were received');
        console.log('4. Check DynamoDB table for stored invoice data');
        console.log('5. Review S3 buckets for uploaded and processed files');
    }

    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

// CLI usage
if (require.main === module) {
    const tester = new InvoiceProcessingTester();
    tester.runAllTests().catch(console.error);
}

module.exports = InvoiceProcessingTester;
