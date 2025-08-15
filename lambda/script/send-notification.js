const AWS = require('aws-sdk');
const ses = new AWS.SES();

exports.handler = async (event) => {
    console.log('Notification Lambda triggered:', JSON.stringify(event, null, 2));
    
    try {
        const invoice = event.invoice;
        const notificationType = event.notificationType || 'success';
        
        // Simulate notification sending (replace with actual email/SMS service)
        const notification = {
            to: invoice.customerEmail || 'customer@example.com',
            subject: `Invoice ${invoice.invoiceNumber || invoice.invoiceId} - ${notificationType.toUpperCase()}`,
            body: generateNotificationBody(invoice, notificationType),
            sentAt: new Date().toISOString()
        };
        
        // In a real implementation, you would send actual notifications here
        // For now, we'll just log and return success
        console.log('Notification prepared:', notification);
        
        // Simulate processing delay
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        return {
            statusCode: 200,
            message: `${notificationType} notification sent successfully`,
            notification: notification,
            invoice: invoice
        };
        
    } catch (error) {
        console.error('Error sending notification:', error);
        
        return {
            statusCode: 500,
            error: 'Failed to send notification',
            details: error.message,
            invoice: event.invoice
        };
    }
};

function generateNotificationBody(invoice, type) {
    switch (type) {
        case 'success':
            return `Your invoice ${invoice.invoiceNumber || invoice.invoiceId} has been processed successfully. Amount: $${invoice.amount}. Due date: ${invoice.dueDate}.`;
        case 'error':
            return `There was an error processing your invoice ${invoice.invoiceId}. Please contact support.`;
        case 'validation_failed':
            return `Your invoice ${invoice.invoiceId} failed validation. Please review and resubmit.`;
        default:
            return `Invoice ${invoice.invoiceId} status update: ${type}`;
    }
}
