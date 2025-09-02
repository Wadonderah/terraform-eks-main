const AWS = require('aws-sdk');

// Minimal AWS SDK initialization (no X-Ray)
const textract = new AWS.Textract();
const s3 = new AWS.S3();
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    const startTime = Date.now();
    
    try {
        const record = event.Records[0];
        const bucketName = record.s3.bucket.name;
        const objectKey = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
        
        // Quick file validation
        const ext = objectKey.toLowerCase().split('.').pop();
        if (!['pdf', 'png', 'jpg', 'jpeg'].includes(ext)) {
            return { statusCode: 400, body: 'Unsupported format' };
        }
        
        // Minimal Textract call
        const textractResult = await textract.analyzeDocument({
            Document: { S3Object: { Bucket: bucketName, Name: objectKey } },
            FeatureTypes: ['FORMS']  // Only forms, no tables to reduce cost
        }).promise();
        
        // Extract minimal data
        const extractedData = {
            fileName: objectKey,
            timestamp: new Date().toISOString(),
            invoiceNumber: extractInvoiceNumber(textractResult),
            totalAmount: extractTotalAmount(textractResult),
            processingTime: Date.now() - startTime
        };
        
        // Store in DynamoDB
        await dynamodb.put({
            TableName: process.env.DYNAMODB_TABLE || 'lambda_invoice_dynamoDB',
            Item: {
                invoiceId: extractedData.invoiceNumber || `inv-${Date.now()}`,
                timestamp: extractedData.timestamp,
                ...extractedData
            }
        }).promise();
        
        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Processed', data: extractedData })
        };
        
    } catch (error) {
        console.error('Error:', error.message);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: error.message })
        };
    }
};

function extractInvoiceNumber(result) {
    const text = result.Blocks
        .filter(b => b.BlockType === 'LINE')
        .map(b => b.Text)
        .join(' ');
    
    const match = text.match(/invoice\s*#?\s*:?\s*([a-zA-Z0-9\-]+)/i);
    return match ? match[1] : null;
}

function extractTotalAmount(result) {
    const text = result.Blocks
        .filter(b => b.BlockType === 'LINE')
        .map(b => b.Text)
        .join(' ');
    
    const match = text.match(/total\s*:?\s*\$?([0-9,]+\.?[0-9]*)/i);
    return match ? parseFloat(match[1].replace(/,/g, '')) : null;
}
