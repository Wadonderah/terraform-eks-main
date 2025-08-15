const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    console.log('Invoice Processing Lambda triggered:', JSON.stringify(event, null, 2));
    
    try {
        const invoice = event.invoice;
        const tableName = process.env.DYNAMODB_TABLE_NAME || 'lambda_invoice_dynamoDB';
        
        // Calculate processing details
        const processingDate = new Date().toISOString();
        const invoiceNumber = `INV-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
        
        // Prepare invoice for storage
        const processedInvoice = {
            ...invoice,
            invoiceNumber: invoiceNumber,
            processedAt: processingDate,
            status: 'processed',
            createdAt: processingDate,
            updatedAt: processingDate
        };
        
        // Store in DynamoDB
        const params = {
            TableName: tableName,
            Item: processedInvoice,
            ConditionExpression: 'attribute_not_exists(invoiceId)'
        };
        
        await dynamodb.put(params).promise();
        
        console.log('Invoice processed and stored successfully:', invoiceNumber);
        
        return {
            statusCode: 200,
            message: 'Invoice processed successfully',
            invoice: processedInvoice,
            invoiceNumber: invoiceNumber
        };
        
    } catch (error) {
        console.error('Error processing invoice:', error);
        
        if (error.code === 'ConditionalCheckFailedException') {
            return {
                statusCode: 409,
                error: 'Invoice with this ID already exists',
                invoice: event.invoice
            };
        }
        
        return {
            statusCode: 500,
            error: 'Internal server error during processing',
            details: error.message,
            invoice: event.invoice
        };
    }
};
