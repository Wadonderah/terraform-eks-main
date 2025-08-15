const AWS = require('aws-sdk');

const textract = new AWS.Textract();
const s3 = new AWS.S3();
const sns = new AWS.SNS();
const lambda = new AWS.Lambda();

exports.handler = async (event) => {
    console.log('Textract Processor Lambda triggered:', JSON.stringify(event, null, 2));
    
    try {
        // Parse S3 event
        const s3Event = event.Records[0].s3;
        const bucketName = s3Event.bucket.name;
        const objectKey = decodeURIComponent(s3Event.object.key.replace(/\+/g, ' '));
        
        console.log(`Processing file: ${objectKey} from bucket: ${bucketName}`);
        
        // Check if file is a supported format
        const supportedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.tiff', '.tif'];
        const fileExtension = objectKey.toLowerCase().substring(objectKey.lastIndexOf('.'));
        
        if (!supportedFormats.includes(fileExtension)) {
            console.log(`Unsupported file format: ${fileExtension}`);
            await sendNotification('error', `Unsupported file format: ${fileExtension}`, objectKey);
            return {
                statusCode: 400,
                body: JSON.stringify({ message: 'Unsupported file format' })
            };
        }
        
        // Start Textract document analysis
        const textractParams = {
            Document: {
                S3Object: {
                    Bucket: bucketName,
                    Name: objectKey
                }
            },
            FeatureTypes: ['TABLES', 'FORMS']
        };
        
        console.log('Starting Textract analysis...');
        const textractResult = await textract.analyzeDocument(textractParams).promise();
        
        // Extract text and key-value pairs
        const extractedData = parseTextractResult(textractResult, objectKey);
        
        // Invoke data storage Lambda
        const storageParams = {
            FunctionName: process.env.STORAGE_LAMBDA_NAME || 'store-extracted-data',
            InvocationType: 'Event',
            Payload: JSON.stringify({
                extractedData: extractedData,
                sourceFile: objectKey,
                sourceBucket: bucketName
            })
        };
        
        await lambda.invoke(storageParams).promise();
        console.log('Invoked storage Lambda successfully');
        
        // Send success notification
        await sendNotification('success', 'Invoice processed successfully', objectKey, extractedData);
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Invoice processed successfully',
                extractedData: extractedData
            })
        };
        
    } catch (error) {
        console.error('Error processing invoice:', error);
        
        // Send error notification
        await sendNotification('error', error.message, event.Records?.[0]?.s3?.object?.key || 'unknown');
        
        return {
            statusCode: 500,
            body: JSON.stringify({
                message: 'Error processing invoice',
                error: error.message
            })
        };
    }
};

function parseTextractResult(textractResult, fileName) {
    const blocks = textractResult.Blocks;
    const extractedData = {
        fileName: fileName,
        extractedAt: new Date().toISOString(),
        rawText: '',
        keyValuePairs: {},
        tables: [],
        invoiceData: {
            invoiceNumber: null,
            invoiceDate: null,
            totalAmount: null,
            vendorName: null,
            vendorAddress: null,
            dueDate: null
        }
    };
    
    // Extract raw text
    const textBlocks = blocks.filter(block => block.BlockType === 'LINE');
    extractedData.rawText = textBlocks.map(block => block.Text).join('\n');
    
    // Extract key-value pairs
    const keyValueBlocks = blocks.filter(block => block.BlockType === 'KEY_VALUE_SET');
    keyValueBlocks.forEach(block => {
        if (block.EntityTypes && block.EntityTypes.includes('KEY')) {
            const keyText = getTextFromBlock(block, blocks);
            const valueBlock = findValueBlock(block, blocks);
            if (valueBlock) {
                const valueText = getTextFromBlock(valueBlock, blocks);
                extractedData.keyValuePairs[keyText] = valueText;
            }
        }
    });
    
    // Extract invoice-specific data using patterns
    extractInvoiceData(extractedData);
    
    return extractedData;
}

function getTextFromBlock(block, allBlocks) {
    if (!block.Relationships) return '';
    
    const childRelationship = block.Relationships.find(rel => rel.Type === 'CHILD');
    if (!childRelationship) return '';
    
    return childRelationship.Ids
        .map(id => allBlocks.find(b => b.Id === id))
        .filter(b => b && b.BlockType === 'WORD')
        .map(b => b.Text)
        .join(' ');
}

function findValueBlock(keyBlock, allBlocks) {
    if (!keyBlock.Relationships) return null;
    
    const valueRelationship = keyBlock.Relationships.find(rel => rel.Type === 'VALUE');
    if (!valueRelationship) return null;
    
    return allBlocks.find(block => block.Id === valueRelationship.Ids[0]);
}

function extractInvoiceData(extractedData) {
    const text = extractedData.rawText.toLowerCase();
    const keyValuePairs = extractedData.keyValuePairs;
    
    // Extract invoice number
    const invoiceNumberPatterns = [
        /invoice\s*#?\s*:?\s*([a-zA-Z0-9\-]+)/i,
        /inv\s*#?\s*:?\s*([a-zA-Z0-9\-]+)/i,
        /invoice\s*number\s*:?\s*([a-zA-Z0-9\-]+)/i
    ];
    
    for (const pattern of invoiceNumberPatterns) {
        const match = extractedData.rawText.match(pattern);
        if (match) {
            extractedData.invoiceData.invoiceNumber = match[1];
            break;
        }
    }
    
    // Extract total amount
    const amountPatterns = [
        /total\s*:?\s*\$?([0-9,]+\.?[0-9]*)/i,
        /amount\s*due\s*:?\s*\$?([0-9,]+\.?[0-9]*)/i,
        /balance\s*due\s*:?\s*\$?([0-9,]+\.?[0-9]*)/i
    ];
    
    for (const pattern of amountPatterns) {
        const match = extractedData.rawText.match(pattern);
        if (match) {
            extractedData.invoiceData.totalAmount = parseFloat(match[1].replace(/,/g, ''));
            break;
        }
    }
    
    // Extract dates
    const datePattern = /(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})/g;
    const dates = extractedData.rawText.match(datePattern);
    if (dates && dates.length > 0) {
        extractedData.invoiceData.invoiceDate = dates[0];
        if (dates.length > 1) {
            extractedData.invoiceData.dueDate = dates[1];
        }
    }
    
    // Try to extract vendor name (usually at the top of the document)
    const lines = extractedData.rawText.split('\n');
    if (lines.length > 0) {
        extractedData.invoiceData.vendorName = lines[0].trim();
    }
}

async function sendNotification(type, message, fileName, data = null) {
    try {
        const snsParams = {
            TopicArn: process.env.SNS_TOPIC_ARN,
            Subject: `Invoice Processing ${type.toUpperCase()}: ${fileName}`,
            Message: JSON.stringify({
                type: type,
                message: message,
                fileName: fileName,
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
