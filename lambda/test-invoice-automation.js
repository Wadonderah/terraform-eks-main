// Test script for Invoice Automation Step Functions
// This script demonstrates how to trigger the invoice automation workflow

const AWS = require('aws-sdk');

// Configure AWS SDK (make sure your credentials are set up)
const stepfunctions = new AWS.StepFunctions({
    region: 'us-west-2' // Update with your region
});

// Sample invoice data for testing
const sampleInvoices = [
    // Valid invoice
    {
        invoiceId: 'INV-001',
        customerId: 'CUST-123',
        customerEmail: 'customer@example.com',
        amount: 1500.00,
        dueDate: '2024-12-31',
        description: 'Professional services for Q4 2024',
        items: [
            { description: 'Consulting hours', quantity: 50, rate: 30.00 }
        ]
    },
    // Invalid invoice (missing required fields)
    {
        invoiceId: 'INV-002',
        customerId: 'CUST-456',
        // Missing amount and dueDate
        description: 'This invoice should fail validation'
    },
    // Invalid invoice (negative amount)
    {
        invoiceId: 'INV-003',
        customerId: 'CUST-789',
        customerEmail: 'customer2@example.com',
        amount: -100.00,
        dueDate: '2024-12-31',
        description: 'This invoice has negative amount'
    }
];

async function testInvoiceAutomation() {
    console.log('🚀 Starting Invoice Automation Tests...\n');
    
    // Replace with your actual Step Functions ARN after deployment
    const stateMachineArn = 'arn:aws:states:us-west-2:YOUR_ACCOUNT_ID:stateMachine:invoice-automation-workflow';
    
    for (let i = 0; i < sampleInvoices.length; i++) {
        const invoice = sampleInvoices[i];
        console.log(`📋 Testing Invoice ${i + 1}: ${invoice.invoiceId}`);
        
        try {
            const params = {
                stateMachineArn: stateMachineArn,
                name: `test-execution-${invoice.invoiceId}-${Date.now()}`,
                input: JSON.stringify({
                    invoice: invoice
                })
            };
            
            const result = await stepfunctions.startExecution(params).promise();
            console.log(`✅ Execution started: ${result.executionArn}`);
            console.log(`   Execution Name: ${params.name}\n`);
            
            // Wait a moment between executions
            await new Promise(resolve => setTimeout(resolve, 2000));
            
        } catch (error) {
            console.error(`❌ Error starting execution for ${invoice.invoiceId}:`, error.message);
        }
    }
    
    console.log('🏁 All test executions started. Check AWS Console for results.');
    console.log('\n📊 To monitor executions:');
    console.log('1. Go to AWS Step Functions Console');
    console.log('2. Select "invoice-automation-workflow"');
    console.log('3. View execution history and logs');
}

// AWS CLI commands to test (alternative to Node.js script)
function printAWSCLICommands() {
    console.log('\n🔧 Alternative: Use AWS CLI to test:');
    console.log('\n# Start execution with valid invoice:');
    console.log(`aws stepfunctions start-execution \\
    --state-machine-arn "arn:aws:states:us-west-2:YOUR_ACCOUNT_ID:stateMachine:invoice-automation-workflow" \\
    --name "test-valid-invoice-$(date +%s)" \\
    --input '${JSON.stringify({
        invoice: sampleInvoices[0]
    })}'`);
    
    console.log('\n# Start execution with invalid invoice:');
    console.log(`aws stepfunctions start-execution \\
    --state-machine-arn "arn:aws:states:us-west-2:YOUR_ACCOUNT_ID:stateMachine:invoice-automation-workflow" \\
    --name "test-invalid-invoice-$(date +%s)" \\
    --input '${JSON.stringify({
        invoice: sampleInvoices[1]
    })}'`);
}

// Run the test if this script is executed directly
if (require.main === module) {
    testInvoiceAutomation().catch(console.error);
    printAWSCLICommands();
}

module.exports = {
    testInvoiceAutomation,
    sampleInvoices
};
