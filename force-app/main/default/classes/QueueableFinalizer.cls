public class QueueableFinalizer implements Finalizer {
    public void execute(FinalizerContext context) {
        String jobId = String.valueOf(context.getAsyncApexJobId());
        
        if (context.getResult() == ParentJobResult.SUCCESS) {
            System.debug('Job ' + jobId + ' executed successfully.');
        } else {
            // Uncaught Exception aane par outcome record create karo
            System.debug('Job ' + jobId + ' failed with error: ' + context.getException().getMessage());
            
            // Record save karne ka example:
            /*
            Error_Log__c log = new Error_Log__c();
            log.Job_ID__c = jobId;
            log.Message__c = context.getException().getMessage();
            insert log;
            */
        }
    }
}