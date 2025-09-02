// Minimal Cost Backup Function
const AWS = require('aws-sdk');

const s3 = new AWS.S3();

exports.handler = async (event) => {
    console.log('Starting minimal backup process');
    
    const sourceBucket = process.env.RAW_INVOICE_BUCKET;
    const backupBucket = process.env.BACKUP_BUCKET;
    const backupRegion = process.env.BACKUP_REGION || 'us-east-1';
    
    try {
        // Only backup files from last 7 days to minimize costs
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - 7);
        
        // List recent objects
        const listParams = {
            Bucket: sourceBucket,
            MaxKeys: 100 // Limit to reduce API costs
        };
        
        const objects = await s3.listObjectsV2(listParams).promise();
        
        let backupCount = 0;
        const maxBackups = 10; // Limit backups to control costs
        
        for (const obj of objects.Contents || []) {
            if (backupCount >= maxBackups) break;
            
            // Only backup recent files
            if (obj.LastModified >= cutoffDate) {
                const copyParams = {
                    Bucket: backupBucket,
                    CopySource: `${sourceBucket}/${obj.Key}`,
                    Key: `backup/${new Date().toISOString().split('T')[0]}/${obj.Key}`,
                    StorageClass: 'GLACIER' // Immediate Glacier for cost savings
                };
                
                await s3.copyObject(copyParams).promise();
                backupCount++;
                
                console.log(`Backed up: ${obj.Key}`);
            }
        }
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: `Minimal backup completed: ${backupCount} files`,
                backupCount,
                cost: 'Optimized for minimal cost'
            })
        };
        
    } catch (error) {
        console.error('Backup error:', error);
        
        // Send minimal error notification
        const sns = new AWS.SNS();
        await sns.publish({
            TopicArn: process.env.SNS_TOPIC_ARN,
            Subject: 'Minimal Backup Failed',
            Message: `Backup failed: ${error.message}`
        }).promise();
        
        throw error;
    }
};
