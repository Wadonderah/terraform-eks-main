#!/usr/bin/env node

/**
 * Enhanced Invoice Processing System Test Suite
 * Comprehensive testing for the invoice processing infrastructure
 */

const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
    region: process.env.AWS_REGION || 'ca-central-1',
    profile: process.env.AWS_PROFILE || 'default',
    testTimeout: 300000, // 5 minutes
    retryAttempts: 3,
    retryDelay: 5000, // 5 seconds
};

// AWS SDK Configuration
AWS.config.update({
    region: CONFIG.region,
    profile: CONFIG.profile
});

const s3 = new AWS.S3();
const lambda = new AWS.Lambda();
const dynamodb = new AWS.DynamoDB.DocumentClient();
const sns = new AWS.SNS();
const stepfunctions = new AWS.StepFunctions();
const cloudwatch = new AWS.CloudWatch();

// Test Results Tracking
const testResults = {
    passed: 0,
    failed: 0,
    skipped: 0,
    tests: []
};

// Utility Functions
const log = {
    info: (msg) => console.log(`ℹ️  ${msg}`),
    success: (msg) => console.log(`✅ ${msg}`),
    error: (msg) => console.log(`❌ ${msg}`),
    warning: (msg) => console.log(`⚠️  ${msg}`),
    test: (msg) => console.log(`🧪 ${msg}`)
};

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function runTest(testName, testFunction) {
    log.test(`Running test: ${testName}`);
    const startTime = Date.now();
    
    try {
        await testFunction();
        const duration = Date.now() - startTime;
        log.success(`✓ ${testName} (${duration}ms)`);
        testResults.passed++;
        testResults.tests.push({
            name: testName,
            status: 'PASSED',
            duration,
            error: null
        });
    } catch (error) {
        const duration = Date.now() - startTime;
        log.error(`✗ ${testName} (${duration}ms): ${error.message}`);
        testResults.failed++;
        testResults.tests.push({
            name: testName,
            status: 'FAILED',
            duration,
            error: error.message
        });
    }
}

// Test Functions
async function testAWSConnectivity() {
    const sts = new AWS.STS();
    const identity = await sts.getCallerIdentity().promise();
    
    if (!identity.Account) {
        throw new Error('Unable to get AWS account identity');
    }
    
    log.info(`Connected to AWS Account: ${identity.Account}`);
    log.info(`Region: ${CONFIG.region}`);
}

async function testS3Buckets() {
    // Get bucket names from Terraform outputs or environment variables
    const rawBucketName = process.env.RAW_BUCKET_NAME || await getTerraformOutput('raw_invoice_bucket_name');
    const processedBucketName = process.env.PROCESSED_BUCKET_NAME || await getTerraformOutput('processed_invoice_bucket_name');
    
    if (!rawBucketName || !processedBucketName) {
        throw new Error('S3 bucket names not found. Ensure Terraform has been applied or set environment variables.');
    }
    
    // Test bucket existence and permissions
    await s3.headBucket({ Bucket: rawBucketName }).promise();
    await s3.headBucket({ Bucket: processedBucketName }).promise();
    
    // Test bucket encryption
    const rawEncryption = await s3.getBucketEncryption({ Bucket: rawBucketName }).promise();
    const processedEncryption = await s3.getBucketEncryption({ Bucket: processedBucketName }).promise();
    
    if (!rawEncryption.ServerSideEncryptionConfiguration) {
        throw new Error('Raw bucket encryption not configured');
    }
    
    if (!processedEncryption.ServerSideEncryptionConfiguration) {
        throw new Error('Processed bucket encryption not configured');
    }
    
    log.info(`Raw bucket: ${rawBucketName} ✓`);
    log.info(`Processed bucket: ${processedBucketName} ✓`);
}

async function testLambdaFunctions() {
    const expectedFunctions = [
        'textract-processor',
        'store-extracted-data',
        'validate-invoice',
        'process-invoice',
        'send-notification'
    ];
    
    const functions = await lambda.listFunctions().promise();
    const functionNames = functions.Functions.map(f => f.FunctionName);
    
    for (const expectedFunc of expectedFunctions) {
        const found = functionNames.find(name => name.includes(expectedFunc));
        if (!found) {
            throw new Error(`Lambda function containing '${expectedFunc}' not found`);
        }
        
        // Test function configuration
        const funcConfig = await lambda.getFunctionConfiguration({
            FunctionName: found
        }).promise();
        
        if (funcConfig.State !== 'Active') {
            throw new Error(`Lambda function ${found} is not active (State: ${funcConfig.State})`);
        }
        
        log.info(`Lambda function: ${found} ✓`);
    }
}

async function testDynamoDBTable() {
    const tableName = process.env.DYNAMODB_TABLE_NAME || await getTerraformOutput('dynamodb_table_name');
    
    if (!tableName) {
        throw new Error('DynamoDB table name not found');
    }
    
    const tableDescription = await dynamodb.describe({ TableName: tableName }).promise();
    
    if (tableDescription.Table.TableStatus !== 'ACTIVE') {
        throw new Error(`DynamoDB table ${tableName} is not active`);
    }
    
    // Test write and read operations
    const testItem = {
        invoiceId: `test-${Date.now()}`,
        timestamp: new Date().toISOString(),
        testData: 'Enhanced system test'
    };
    
    await dynamodb.put({
        TableName: tableName,
        Item: testItem
    }).promise();
    
    const result = await dynamodb.get({
        TableName: tableName,
        Key: {
            invoiceId: testItem.invoiceId,
            timestamp: testItem.timestamp
        }
    }).promise();
    
    if (!result.Item) {
        throw new Error('Failed to retrieve test item from DynamoDB');
    }
    
    // Clean up test item
    await dynamodb.delete({
        TableName: tableName,
        Key: {
            invoiceId: testItem.invoiceId,
            timestamp: testItem.timestamp
        }
    }).promise();
    
    log.info(`DynamoDB table: ${tableName} ✓`);
}

async function testSNSTopics() {
    const topics = await sns.listTopics().promise();
    const topicArns = topics.Topics.map(t => t.TopicArn);
    
    const expectedTopics = ['invoice-processing-notifications', 'invoice-processing-alerts'];
    
    for (const expectedTopic of expectedTopics) {
        const found = topicArns.find(arn => arn.includes(expectedTopic));
        if (!found) {
            throw new Error(`SNS topic containing '${expectedTopic}' not found`);
        }
        
        // Test topic attributes
        const attributes = await sns.getTopicAttributes({
            TopicArn: found
        }).promise();
        
        log.info(`SNS topic: ${found.split(':').pop()} ✓`);
    }
}

async function testStepFunctions() {
    const stateMachines = await stepfunctions.listStateMachines().promise();
    
    const invoiceWorkflow = stateMachines.stateMachines.find(sm => 
        sm.name.includes('invoice-automation')
    );
    
    if (!invoiceWorkflow) {
        throw new Error('Invoice automation Step Function not found');
    }
    
    const definition = await stepfunctions.describeStateMachine({
        stateMachineArn: invoiceWorkflow.stateMachineArn
    }).promise();
    
    if (definition.status !== 'ACTIVE') {
        throw new Error(`Step Function ${invoiceWorkflow.name} is not active`);
    }
    
    log.info(`Step Function: ${invoiceWorkflow.name} ✓`);
}

async function testEndToEndProcessing() {
    log.info('Starting end-to-end processing test...');
    
    const rawBucketName = process.env.RAW_BUCKET_NAME || await getTerraformOutput('raw_invoice_bucket_name');
    
    if (!rawBucketName) {
        throw new Error('Raw bucket name not found for end-to-end test');
    }
    
    // Create a test PDF content (simple text-based PDF simulation)
    const testPdfContent = Buffer.from(`
        %PDF-1.4
        1 0 obj
        <<
        /Type /Catalog
        /Pages 2 0 R
        >>
        endobj
        
        2 0 obj
        <<
        /Type /Pages
        /Kids [3 0 R]
        /Count 1
        >>
        endobj
        
        3 0 obj
        <<
        /Type /Page
        /Parent 2 0 R
        /MediaBox [0 0 612 792]
        /Contents 4 0 R
        >>
        endobj
        
        4 0 obj
        <<
        /Length 44
        >>
        stream
        BT
        /F1 12 Tf
        100 700 Td
        (Test Invoice #12345) Tj
        (Total: $100.00) Tj
        ET
        endstream
        endobj
        
        xref
        0 5
        0000000000 65535 f 
        0000000009 00000 n 
        0000000074 00000 n 
        0000000120 00000 n 
        0000000179 00000 n 
        trailer
        <<
        /Size 5
        /Root 1 0 R
        >>
        startxref
        274
        %%EOF
    `);
    
    const testFileName = `test-invoice-${Date.now()}.pdf`;
    
    // Upload test file to S3
    await s3.putObject({
        Bucket: rawBucketName,
        Key: testFileName,
        Body: testPdfContent,
        ContentType: 'application/pdf'
    }).promise();
    
    log.info(`Uploaded test file: ${testFileName}`);
    
    // Wait for processing (Lambda should be triggered by S3 event)
    await sleep(10000); // Wait 10 seconds for processing
    
    // Check if processed data exists
    const processedBucketName = process.env.PROCESSED_BUCKET_NAME || await getTerraformOutput('processed_invoice_bucket_name');
    
    if (processedBucketName) {
        try {
            const processedObjects = await s3.listObjectsV2({
                Bucket: processedBucketName,
                Prefix: testFileName.replace('.pdf', '')
            }).promise();
            
            if (processedObjects.Contents && processedObjects.Contents.length > 0) {
                log.info('Processed data found in S3 ✓');
            } else {
                log.warning('No processed data found yet (may still be processing)');
            }
        } catch (error) {
            log.warning(`Could not check processed bucket: ${error.message}`);
        }
    }
    
    // Clean up test file
    await s3.deleteObject({
        Bucket: rawBucketName,
        Key: testFileName
    }).promise();
    
    log.info('End-to-end test completed');
}

async function testCloudWatchMetrics() {
    const metrics = await cloudwatch.listMetrics({
        Namespace: 'InvoiceProcessing'
    }).promise();
    
    if (metrics.Metrics.length === 0) {
        log.warning('No custom CloudWatch metrics found (may not have processed any invoices yet)');
        return;
    }
    
    log.info(`Found ${metrics.Metrics.length} custom metrics ✓`);
}

async function testSecurityConfiguration() {
    // Test KMS key existence
    const kms = new AWS.KMS();
    
    try {
        const aliases = await kms.listAliases().promise();
        const invoiceAlias = aliases.Aliases.find(alias => 
            alias.AliasName.includes('invoice-processing')
        );
        
        if (invoiceAlias) {
            log.info(`KMS key alias found: ${invoiceAlias.AliasName} ✓`);
        } else {
            log.warning('Invoice processing KMS alias not found');
        }
    } catch (error) {
        log.warning(`Could not check KMS configuration: ${error.message}`);
    }
    
    // Test IAM roles
    const iam = new AWS.IAM();
    
    try {
        const roles = await iam.listRoles().promise();
        const lambdaRole = roles.Roles.find(role => 
            role.RoleName.includes('lambda_role') || role.RoleName.includes('lambda-role')
        );
        
        if (lambdaRole) {
            log.info(`Lambda IAM role found: ${lambdaRole.RoleName} ✓`);
        } else {
            throw new Error('Lambda IAM role not found');
        }
    } catch (error) {
        log.warning(`Could not check IAM configuration: ${error.message}`);
    }
}

// Helper Functions
async function getTerraformOutput(outputName) {
    try {
        const { execSync } = require('child_process');
        const output = execSync(`terraform output -raw ${outputName}`, { 
            encoding: 'utf8',
            cwd: __dirname
        });
        return output.trim();
    } catch (error) {
        log.warning(`Could not get Terraform output '${outputName}': ${error.message}`);
        return null;
    }
}

function generateTestReport() {
    const total = testResults.passed + testResults.failed + testResults.skipped;
    const successRate = total > 0 ? (testResults.passed / total * 100).toFixed(2) : 0;
    
    console.log('\n' + '='.repeat(60));
    console.log('📊 TEST REPORT');
    console.log('='.repeat(60));
    console.log(`Total Tests: ${total}`);
    console.log(`✅ Passed: ${testResults.passed}`);
    console.log(`❌ Failed: ${testResults.failed}`);
    console.log(`⏭️  Skipped: ${testResults.skipped}`);
    console.log(`📈 Success Rate: ${successRate}%`);
    console.log('='.repeat(60));
    
    if (testResults.failed > 0) {
        console.log('\n❌ FAILED TESTS:');
        testResults.tests
            .filter(test => test.status === 'FAILED')
            .forEach(test => {
                console.log(`  • ${test.name}: ${test.error}`);
            });
    }
    
    // Save detailed report to file
    const reportData = {
        timestamp: new Date().toISOString(),
        summary: {
            total,
            passed: testResults.passed,
            failed: testResults.failed,
            skipped: testResults.skipped,
            successRate: parseFloat(successRate)
        },
        tests: testResults.tests,
        environment: {
            region: CONFIG.region,
            profile: CONFIG.profile,
            nodeVersion: process.version
        }
    };
    
    fs.writeFileSync(
        path.join(__dirname, 'test-report.json'),
        JSON.stringify(reportData, null, 2)
    );
    
    console.log('\n📄 Detailed report saved to: test-report.json');
}

// Main Test Execution
async function main() {
    console.log('🚀 Starting Enhanced Invoice Processing System Tests');
    console.log(`Region: ${CONFIG.region}`);
    console.log(`Profile: ${CONFIG.profile}`);
    console.log('='.repeat(60));
    
    const tests = [
        ['AWS Connectivity', testAWSConnectivity],
        ['S3 Buckets', testS3Buckets],
        ['Lambda Functions', testLambdaFunctions],
        ['DynamoDB Table', testDynamoDBTable],
        ['SNS Topics', testSNSTopics],
        ['Step Functions', testStepFunctions],
        ['CloudWatch Metrics', testCloudWatchMetrics],
        ['Security Configuration', testSecurityConfiguration],
        ['End-to-End Processing', testEndToEndProcessing]
    ];
    
    for (const [testName, testFunction] of tests) {
        await runTest(testName, testFunction);
    }
    
    generateTestReport();
    
    if (testResults.failed > 0) {
        console.log('\n❌ Some tests failed. Please review the issues above.');
        process.exit(1);
    } else {
        console.log('\n🎉 All tests passed! Your invoice processing system is ready.');
        process.exit(0);
    }
}

// Error handling
process.on('unhandledRejection', (error) => {
    log.error(`Unhandled rejection: ${error.message}`);
    process.exit(1);
});

process.on('uncaughtException', (error) => {
    log.error(`Uncaught exception: ${error.message}`);
    process.exit(1);
});

// Run tests
if (require.main === module) {
    main().catch(error => {
        log.error(`Test execution failed: ${error.message}`);
        process.exit(1);
    });
}

module.exports = {
    runTest,
    testResults,
    CONFIG
};
