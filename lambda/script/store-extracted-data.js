const AWS = require('aws-sdk');

const dynamodb = new AWS.DynamoDB.DocumentClient();
const s3 = new AWS.S3();
const sns = new AWS.SNS();

exports.handler = async (event) => {
    console.log('Store Extracted Data Lambda triggered:', JSON.stringify(event, null, 2));
    
    try {
        const { extractedData, sourceFile, sourceBucket } = event;
        
        if (!extractedData) {
            throw new Error('No extracted data provided');
        }
        
        // Generate unique invoice ID
        const invoiceId = extractedData.invoiceData.invoiceNumber || `AUTO-${Date.now()}`;
        const customerId = extractInvoiceCustomerId(extractedData);
        
        // Prepare invoice record for DynamoDB
        const invoiceRecord = {
            customerId: customerId,
            invoiceNumber: parseInt(Date.now()), // Using timestamp as numeric invoice number
            invoiceId: invoiceId,
            originalFileName: sourceFile,
            sourceBucket: sourceBucket,
            extractedAt: extractedData.extractedAt,
            processedAt: new Date().toISOString(),
            
            // Invoice details from Textract
            invoiceDate: extractedData.invoiceData.invoiceDate,
            dueDate: extractedData.invoiceData.dueDate,
            totalAmount: extractedData.invoiceData.totalAmount,
            vendorName: extractedData.invoiceData.vendorName,
            vendorAddress: extractedData.invoiceData.vendorAddress,
            
            // Raw extracted data
            rawText: extractedData.rawText,
            keyValuePairs: extractedData.keyValuePairs,
            
            // Processing status
            status: 'processed',
            processingMethod: 'textract-automated'
        };
        
        // Store in DynamoDB
        const dynamoParams = {
            TableName: process.env.DYNAMODB_TABLE_NAME || 'lambda_invoice_dynamoDB',
            Item: invoiceRecord,
            ConditionExpression: 'attribute_not_exists(invoiceId)'
        };
        
        await dynamodb.put(dynamoParams).promise();
        console.log('Invoice stored in DynamoDB successfully:', invoiceId);
        
        // Store processed data in S3
        const processedData = {
            ...invoiceRecord,
            fullExtractedData: extractedData
        };
        
        const s3Key = `processed/${new Date().getFullYear()}/${new Date().getMonth() + 1}/${invoiceId}.json`;
        const s3Params = {
            Bucket: process.env.PROCESSED_BUCKET_NAME,
            Key: s3Key,
            Body: JSON.stringify(processedData, null, 2),
            ContentType: 'application/json',
            ServerSideEncryption: 'AES256'
        };
        
        await s3.putObject(s3Params).promise();
        console.log('Processed data stored in S3:', s3Key);
        
        // Send success notification
        await sendNotification('storage_success', 'Invoice data stored successfully', {
            invoiceId: invoiceId,
            customerId: customerId,
            amount: extractedData.invoiceData.totalAmount,
            vendor: extractedData.invoiceData.vendorName,
            s3Location: s3Key
        });
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Invoice data stored successfully',
                invoiceId: invoiceId,
                customerId: customerId,
                s3Location: s3Key
            })
        };
        
    } catch (error) {
        console.error('Error storing extracted data:', error);
        
        // Handle duplicate invoice
        if (error.code === 'ConditionalCheckFailedException') {
            console.log('Duplicate invoice detected');
            await sendNotification('duplicate', 'Duplicate invoice detected', {
                sourceFile: event.sourceFile,
                error: 'Invoice already exists in database'
            });
            
            return {
                statusCode: 409,
                body: JSON.stringify({
                    message: 'Duplicate invoice detected',
                    error: 'Invoice already exists in database'
                })
            };
        }
        
        // Send error notification
        await sendNotification('storage_error', error.message, {
            sourceFile: event.sourceFile,
            error: error.message
        });
        
        return {
            statusCode: 500,
            body: JSON.stringify({
                message: 'Error storing invoice data',
                error: error.message
            })
        };
    }
};

function extractInvoiceCustomerId(extractedData) {
    // Try to extract customer ID from various sources
    const keyValuePairs = extractedData.keyValuePairs || {};
    
    // Look for customer ID in key-value pairs
    const customerKeys = ['customer id', 'customer number', 'client id', 'account number'];
    for (const key of customerKeys) {
        for (const [extractedKey, value] of Object.entries(keyValuePairs)) {
            if (extractedKey.toLowerCase().includes(key)) {
                return value;
            }
        }
    }
    
    // Try to extract from raw text
    const customerIdPatterns = [
        /customer\s*id\s*:?\s*([a-zA-Z0-9\-]+)/i,
        /client\s*id\s*:?\s*([a-zA-Z0-9\-]+)/i,
        /account\s*#?\s*:?\s*([a-zA-Z0-9\-]+)/i
    ];
    
    for (const pattern of customerIdPatterns) {
        const match = extractedData.rawText.match(pattern);
        if (match) {
            return match[1];
        }
    }
    
    // Generate a customer ID based on vendor name if available
    if (extractedData.invoiceData.vendorName) {
        const vendorName = extractedData.invoiceData.vendorName.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
        return `CUST-${vendorName.substring(0, 6)}-${Date.now().toString().slice(-4)}`;
    }
    
    // Fallback to generated customer ID
    return `CUST-AUTO-${Date.now().toString().slice(-6)}`;
}

async function sendNotification(type, message, data) {
    try {
        const snsParams = {
            TopicArn: process.env.SNS_TOPIC_ARN,
            Subject: `Invoice Storage ${type.toUpperCase()}`,
            Message: JSON.stringify({
                type: type,
                message: message,
                timestamp: new Date().toISOString(),
                data: data
            }, null, 2)
        };
        
        await sns.publish(snsParams).promise();
        console.log(`SNS notification sent: ${type}`);
    } catch (error) {
        console.error('Error sending SNS notification:', error);
    }
}
