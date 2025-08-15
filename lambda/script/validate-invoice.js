const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    console.log('Invoice Validation Lambda triggered:', JSON.stringify(event, null, 2));
    
    try {
        const invoice = event.invoice;
        
        // Validate required fields
        const requiredFields = ['invoiceId', 'customerId', 'amount', 'dueDate'];
        const missingFields = requiredFields.filter(field => !invoice[field]);
        
        if (missingFields.length > 0) {
            return {
                statusCode: 400,
                isValid: false,
                error: `Missing required fields: ${missingFields.join(', ')}`,
                invoice: invoice
            };
        }
        
        // Validate amount is positive
        if (invoice.amount <= 0) {
            return {
                statusCode: 400,
                isValid: false,
                error: 'Invoice amount must be positive',
                invoice: invoice
            };
        }
        
        // Validate due date is in the future
        const dueDate = new Date(invoice.dueDate);
        const today = new Date();
        
        if (dueDate <= today) {
            return {
                statusCode: 400,
                isValid: false,
                error: 'Due date must be in the future',
                invoice: invoice
            };
        }
        
        console.log('Invoice validation successful');
        
        return {
            statusCode: 200,
            isValid: true,
            message: 'Invoice validation successful',
            invoice: {
                ...invoice,
                validatedAt: new Date().toISOString(),
                status: 'validated'
            }
        };
        
    } catch (error) {
        console.error('Error validating invoice:', error);
        
        return {
            statusCode: 500,
            isValid: false,
            error: 'Internal server error during validation',
            details: error.message
        };
    }
};
