public class OpeningRiskBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    // Stateful Counters across all chunks
    public Integer totalProcessed = 0;
    public Integer totalSucceeded = 0;
    public Integer totalFailed = 0;
    public List<String> errorLogsSummary = new List<String>();

    // 1. start() Method: Query Locator over open Job Openings
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Fetching records with valid active status values from your org
        return Database.getQueryLocator([
            SELECT Id, Name, Notes__c, Status__c 
            FROM Job_Opening__c 
            WHERE Status__c IN ('Intern', 'Fresher', 'Developer', 'Experienced')
        ]);
    }

    // 2. execute() Method: Processing & Partial Failure Handling
    public void execute(Database.BatchableContext bc, List<Job_Opening__c> scope) {
        List<Job_Opening__c> recordsToUpdate = new List<Job_Opening__c>();
        
        for (Job_Opening__c job : scope) {
            // Stamping note based on whether it is a poisoned record or clean record
            if (job.Name != null && job.Name.contains('POISON')) {
                job.Notes__c = 'FAIL_TEST - Batch Processed at ' + String.valueOf(System.now());
            } else {
                job.Notes__c = 'Processed cleanly at ' + String.valueOf(System.now());
            }
            recordsToUpdate.add(job);
        }

        if (!recordsToUpdate.isEmpty()) {
            // Partial Failure handling using allOrNone = false
            Database.SaveResult[] results = Database.update(recordsToUpdate, false);
            
            List<Flow_Error_Log__c> errorLogRecords = new List<Flow_Error_Log__c>();
            
            for (Integer i = 0; i < results.size(); i++) {
                Database.SaveResult sr = results[i];
                Job_Opening__c originalRecord = recordsToUpdate[i];
                
                if (sr.isSuccess()) {
                    totalSucceeded++;
                } else {
                    totalFailed++;
                    for (Database.Error err : sr.getErrors()) {
                        // Insert error details directly into your Flow Error Log object
                        Flow_Error_Log__c log = new Flow_Error_Log__c();
                        log.Record_Id__c = String.valueOf(originalRecord.Id);
                        log.Message__c = err.getMessage();
                        errorLogRecords.add(log);
                        
                        errorLogsSummary.add('Record ID: ' + originalRecord.Id + ' | Error: ' + err.getMessage());
                    }
                }
            }
            
            if (!errorLogRecords.isEmpty()) {
                insert errorLogRecords;
            }
        }
        
        totalProcessed += scope.size();
    }

    // 3. finish() Method: Run Summary & Enqueue Queueable Apex
    public void finish(Database.BatchableContext bc) {
        System.debug('=== BATCH RUN SUMMARY ===');
        System.debug('Total Processed: ' + totalProcessed);
        System.debug('Total Succeeded: ' + totalSucceeded);
        System.debug('Total Failed: ' + totalFailed);
        
        // Enqueueing Queueable Apex job right after batch completion
        System.enqueueJob(new OpeningRiskQueueable());
    }
}