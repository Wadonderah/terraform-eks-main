const AWS = require('aws-sdk');
const AWSXRay = require('aws-xray-sdk-core');

// Wrap AWS SDK with X-Ray for tracing
const textract = AWSXRay.captureAWSClient(new AWS.Textract());
const s3 = AWSXRay.captureAWSClient(new AWS.S3());
const sns = AWSXRay.captureAWSClient(new AWS.SNS());
const lambda = AWSXRay.captureAWSClient(new AWS.Lambda());
const cloudwatch = AWSXRay.captureAWSClient(new AWS.CloudWatch());

// Configuration
const CONFIG = {
    MAX_RETRIES: 3,
    RETRY_DELAY: 1000,
    SUPPORTED_FORMATS: ['.pdf', '.png', '.jpg', '.jpeg', '.tiff', '.tif'],
    MAX_FILE_SIZE: 10 * 1024 * 1024, // 10MB
    TEXTRACT_TIMEOUT: 30000, // 30 seconds
};

exports.handler = async (event, context) => {
    // Set up structured logging
    const logger = createLogger(context);
    logger.info('Textract Processor Lambda triggered', { event });
    
    // Create custom metrics
    const metrics = new CustomMetrics();
    
    try {
        // Validate event structure
        if (!event.Records || event.Records.length === 0) {
            throw new Error('No S3 records found in event');
        }

        const results = [];
        
        // Process each record
        for (const record of event.Records) {
            const result = await processRecord(record, logger, metrics);
            results.push(result);
        }

        // Send success metrics
        await metrics.putMetric('ProcessingSuccess', 1, 'Count');
        
        logger.info('All records processed successfully', { results });
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'All invoices processed successfully',
                results: results
            })
        };
        
    } catch (error) {
        logger.error('Error processing invoices', { error: error.message, stack: error.stack });
        
        // Send error metrics
        await metrics.putMetric('ProcessingError', 1, 'Count');
        
        // Send error notification
        await sendNotification('error', error.message, 'batch-processing');
        
        return {
            statusCode: 500,
            body: JSON.stringify({
                message: 'Error processing invoices',
                error: error.message
            })
        };
    }
};

async function processRecord(record, logger, metrics) {
    const startTime = Date.now();
    
    try {
        // Parse S3 event
        const s3Event = record.s3;
        const bucketName = s3Event.bucket.name;
        const objectKey = decodeURIComponent(s3Event.object.key.replace(/\+/g, ' '));
        
        logger.info('Processing file', { bucketName, objectKey });
        
        // Validate file
        await validateFile(bucketName, objectKey, logger);
        
        // Process with Textract
        const extractedData = await processWithTextract(bucketName, objectKey, logger);
        
        // Store data
        await storeExtractedData(extractedData, objectKey, bucketName, logger);
        
        // Send success notification
        await sendNotification('success', 'Invoice processed successfully', objectKey, extractedData);
        
        // Record processing time
        const processingTime = Date.now() - startTime;
        await metrics.putMetric('ProcessingDuration', processingTime, 'Milliseconds');
        
        logger.info('File processed successfully', { 
            objectKey, 
            processingTime,
            extractedDataSize: JSON.stringify(extractedData).length 
        });
        
        return {
            objectKey,
            status: 'success',
            processingTime,
            extractedData: {
                invoiceNumber: extractedData.invoiceData.invoiceNumber,
                totalAmount: extractedData.invoiceData.totalAmount,
                vendorName: extractedData.invoiceData.vendorName
            }
        };
        
    } catch (error) {
        logger.error('Error processing record', { 
            objectKey: record.s3?.object?.key,
            error: error.message 
        });
        
        await sendNotification('error', error.message, record.s3?.object?.key || 'unknown');
        
        return {
            objectKey: record.s3?.object?.key || 'unknown',
            status: 'error',
            error: error.message
        };
    }
}

async function validateFile(bucketName, objectKey, logger) {
    // Check file extension
    const fileExtension = objectKey.toLowerCase().substring(objectKey.lastIndexOf('.'));
    
    if (!CONFIG.SUPPORTED_FORMATS.includes(fileExtension)) {
        throw new Error(`Unsupported file format: ${fileExtension}`);
    }
    
    // Check file size
    try {
        const headResult = await s3.headObject({
            Bucket: bucketName,
            Key: objectKey
        }).promise();
        
        if (headResult.ContentLength > CONFIG.MAX_FILE_SIZE) {
            throw new Error(`File too large: ${headResult.ContentLength} bytes (max: ${CONFIG.MAX_FILE_SIZE})`);
        }
        
        logger.info('File validation passed', { 
            fileSize: headResult.ContentLength,
            fileExtension 
        });
        
    } catch (error) {
        if (error.code === 'NotFound') {
            throw new Error(`File not found: ${objectKey}`);
        }
        throw error;
    }
}

async function processWithTextract(bucketName, objectKey, logger) {
    const textractParams = {
        Document: {
            S3Object: {
                Bucket: bucketName,
                Name: objectKey
            }
        },
        FeatureTypes: ['TABLES', 'FORMS', 'SIGNATURES']
    };
    
    logger.info('Starting Textract analysis', { textractParams });
    
    // Implement retry logic for Textract
    let lastError;
    for (let attempt = 1; attempt <= CONFIG.MAX_RETRIES; attempt++) {
        try {
            const textractResult = await Promise.race([
                textract.analyzeDocument(textractParams).promise(),
                new Promise((_, reject) => 
                    setTimeout(() => reject(new Error('Textract timeout')), CONFIG.TEXTRACT_TIMEOUT)
                )
            ]);
            
            logger.info('Textract analysis completed', { 
                attempt,
                blocksCount: textractResult.Blocks?.length || 0 
            });
            
            return parseTextractResult(textractResult, objectKey, logger);
            
        } catch (error) {
            lastError = error;
            logger.warn('Textract attempt failed', { 
                attempt, 
                error: error.message,
                willRetry: attempt < CONFIG.MAX_RETRIES 
            });
            
            if (attempt < CONFIG.MAX_RETRIES) {
                await sleep(CONFIG.RETRY_DELAY * attempt);
            }
        }
    }
    
    throw new Error(`Textract failed after ${CONFIG.MAX_RETRIES} attempts: ${lastError.message}`);
}

function parseTextractResult(textractResult, fileName, logger) {
    const blocks = textractResult.Blocks || [];
    const extractedData = {
        fileName: fileName,
        extractedAt: new Date().toISOString(),
        rawText: '',
        keyValuePairs: {},
        tables: [],
        confidence: {
            overall: 0,
            invoiceNumber: 0,
            totalAmount: 0,
            vendorName: 0
        },
        invoiceData: {
            invoiceNumber: null,
            invoiceDate: null,
            totalAmount: null,
            vendorName: null,
            vendorAddress: null,
            dueDate: null,
            currency: 'USD'
        }
    };
    
    // Extract raw text with confidence scores
    const textBlocks = blocks.filter(block => block.BlockType === 'LINE');
    extractedData.rawText = textBlocks.map(block => block.Text).join('\n');
    
    // Calculate overall confidence
    const confidenceScores = textBlocks
        .map(block => block.Confidence || 0)
        .filter(conf => conf > 0);
    
    if (confidenceScores.length > 0) {
        extractedData.confidence.overall = 
            confidenceScores.reduce((sum, conf) => sum + conf, 0) / confidenceScores.length;
    }
    
    // Extract key-value pairs with confidence
    extractKeyValuePairs(blocks, extractedData, logger);
    
    // Extract tables
    extractTables(blocks, extractedData, logger);
    
    // Extract invoice-specific data with enhanced patterns
    extractInvoiceDataEnhanced(extractedData, logger);
    
    logger.info('Text extraction completed', {
        textLength: extractedData.rawText.length,
        keyValuePairs: Object.keys(extractedData.keyValuePairs).length,
        tablesCount: extractedData.tables.length,
        overallConfidence: extractedData.confidence.overall,
        invoiceNumber: extractedData.invoiceData.invoiceNumber
    });
    
    return extractedData;
}

function extractKeyValuePairs(blocks, extractedData, logger) {
    const keyValueBlocks = blocks.filter(block => block.BlockType === 'KEY_VALUE_SET');
    
    keyValueBlocks.forEach(block => {
        if (block.EntityTypes && block.EntityTypes.includes('KEY')) {
            const keyText = getTextFromBlock(block, blocks);
            const valueBlock = findValueBlock(block, blocks);
            
            if (valueBlock && keyText) {
                const valueText = getTextFromBlock(valueBlock, blocks);
                extractedData.keyValuePairs[keyText.toLowerCase().trim()] = {
                    value: valueText,
                    confidence: Math.min(block.Confidence || 0, valueBlock.Confidence || 0)
                };
            }
        }
    });
}

function extractTables(blocks, extractedData, logger) {
    const tableBlocks = blocks.filter(block => block.BlockType === 'TABLE');
    
    tableBlocks.forEach((table, index) => {
        const tableData = {
            tableIndex: index,
            rows: [],
            confidence: table.Confidence || 0
        };
        
        // Extract table structure (simplified)
        if (table.Relationships) {
            const cellRelationship = table.Relationships.find(rel => rel.Type === 'CHILD');
            if (cellRelationship) {
                // Process table cells (implementation would be more complex in real scenario)
                tableData.cellCount = cellRelationship.Ids.length;
            }
        }
        
        extractedData.tables.push(tableData);
    });
}

function extractInvoiceDataEnhanced(extractedData, logger) {
    const text = extractedData.rawText;
    const keyValuePairs = extractedData.keyValuePairs;
    
    // Enhanced invoice number extraction
    const invoiceNumberPatterns = [
        /invoice\s*#?\s*:?\s*([a-zA-Z0-9\-\/]+)/i,
        /inv\s*#?\s*:?\s*([a-zA-Z0-9\-\/]+)/i,
        /invoice\s*number\s*:?\s*([a-zA-Z0-9\-\/]+)/i,
        /bill\s*#?\s*:?\s*([a-zA-Z0-9\-\/]+)/i
    ];
    
    for (const pattern of invoiceNumberPatterns) {
        const match = text.match(pattern);
        if (match && match[1].length >= 3) {
            extractedData.invoiceData.invoiceNumber = match[1].trim();
            extractedData.confidence.invoiceNumber = 85; // Base confidence
            break;
        }
    }
    
    // Enhanced amount extraction with currency detection
    const amountPatterns = [
        /total\s*:?\s*([A-Z]{3})?\s*\$?([0-9,]+\.?[0-9]*)/i,
        /amount\s*due\s*:?\s*([A-Z]{3})?\s*\$?([0-9,]+\.?[0-9]*)/i,
        /balance\s*due\s*:?\s*([A-Z]{3})?\s*\$?([0-9,]+\.?[0-9]*)/i,
        /grand\s*total\s*:?\s*([A-Z]{3})?\s*\$?([0-9,]+\.?[0-9]*)/i
    ];
    
    for (const pattern of amountPatterns) {
        const match = text.match(pattern);
        if (match) {
            if (match[1]) extractedData.invoiceData.currency = match[1];
            extractedData.invoiceData.totalAmount = parseFloat(match[2].replace(/,/g, ''));
            extractedData.confidence.totalAmount = 80;
            break;
        }
    }
    
    // Enhanced date extraction
    const datePatterns = [
        /(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})/g,
        /(\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2})/g,
        /(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2},?\s+\d{4}/gi
    ];
    
    for (const pattern of datePatterns) {
        const matches = text.match(pattern);
        if (matches && matches.length > 0) {
            extractedData.invoiceData.invoiceDate = matches[0];
            if (matches.length > 1) {
                extractedData.invoiceData.dueDate = matches[1];
            }
            break;
        }
    }
    
    // Enhanced vendor name extraction
    const lines = text.split('\n').filter(line => line.trim().length > 0);
    if (lines.length > 0) {
        // Usually vendor name is in the first few lines
        for (let i = 0; i < Math.min(3, lines.length); i++) {
            const line = lines[i].trim();
            if (line.length > 3 && !line.match(/invoice|bill|statement/i)) {
                extractedData.invoiceData.vendorName = line;
                extractedData.confidence.vendorName = 70;
                break;
            }
        }
    }
    
    logger.info('Invoice data extraction completed', {
        invoiceNumber: extractedData.invoiceData.invoiceNumber,
        totalAmount: extractedData.invoiceData.totalAmount,
        currency: extractedData.invoiceData.currency,
        vendorName: extractedData.invoiceData.vendorName,
        confidenceScores: extractedData.confidence
    });
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

async function storeExtractedData(extractedData, objectKey, bucketName, logger) {
    const storageParams = {
        FunctionName: process.env.STORAGE_LAMBDA_NAME || 'store-extracted-data',
        InvocationType: 'Event',
        Payload: JSON.stringify({
            extractedData: extractedData,
            sourceFile: objectKey,
            sourceBucket: bucketName,
            timestamp: new Date().toISOString()
        })
    };
    
    try {
        await lambda.invoke(storageParams).promise();
        logger.info('Storage Lambda invoked successfully', { objectKey });
    } catch (error) {
        logger.error('Failed to invoke storage Lambda', { error: error.message, objectKey });
        throw new Error(`Storage invocation failed: ${error.message}`);
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
                data: data,
                environment: process.env.ENVIRONMENT || 'unknown'
            }, null, 2)
        };
        
        await sns.publish(snsParams).promise();
        console.log(`SNS notification sent: ${type} for ${fileName}`);
    } catch (error) {
        console.error('Error sending SNS notification:', error);
        // Don't throw here to avoid cascading failures
    }
}

function createLogger(context) {
    return {
        info: (message, data = {}) => {
            console.log(JSON.stringify({
                level: 'INFO',
                message,
                requestId: context.awsRequestId,
                timestamp: new Date().toISOString(),
                ...data
            }));
        },
        warn: (message, data = {}) => {
            console.warn(JSON.stringify({
                level: 'WARN',
                message,
                requestId: context.awsRequestId,
                timestamp: new Date().toISOString(),
                ...data
            }));
        },
        error: (message, data = {}) => {
            console.error(JSON.stringify({
                level: 'ERROR',
                message,
                requestId: context.awsRequestId,
                timestamp: new Date().toISOString(),
                ...data
            }));
        }
    };
}

class CustomMetrics {
    async putMetric(metricName, value, unit = 'Count') {
        try {
            const params = {
                Namespace: 'InvoiceProcessing',
                MetricData: [{
                    MetricName: metricName,
                    Value: value,
                    Unit: unit,
                    Timestamp: new Date()
                }]
            };
            
            await cloudwatch.putMetricData(params).promise();
        } catch (error) {
            console.error('Failed to put custom metric:', error);
        }
    }
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}
