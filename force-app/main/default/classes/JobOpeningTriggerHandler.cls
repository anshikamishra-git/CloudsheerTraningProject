public class JobOpeningTriggerHandler {
    
    // Static variable for Recursion Guard
    public static Boolean hasRun = false;

    // BEFORE INSERT
    public static void handleBeforeInsert(List<Job_Opening__c> newJobOpenings) {

        // 1. Check Bypass Custom Permission
        if (FeatureManagement.checkPermission('Bypass_Job_Opening_Trigger')) {
            return;
        }

        // 2. In-Batch Duplicate Check
        Set<String> namesToQuery = new Set<String>();
        Set<String> seenNamesInBatch = new Set<String>();

        for (Job_Opening__c job : newJobOpenings) {
            if (job.Name == null) continue;

            // In-batch duplicate check
            if (seenNamesInBatch.contains(job.Name)) {
                job.addError('Duplicate Job Opening name in the same batch: ' + job.Name);
            } else {
                seenNamesInBatch.add(job.Name);
                namesToQuery.add(job.Name);
            }
        }

        // 3. Database Duplicate Check (Single SOQL)
        if (!namesToQuery.isEmpty()) {
            Map<String, Job_Opening__c> existingJobsMap = new Map<String, Job_Opening__c>();
            for (Job_Opening__c existingJob : [SELECT Id, Name FROM Job_Opening__c WHERE Name IN :namesToQuery]) {
                existingJobsMap.put(existingJob.Name, existingJob);
            }

            for (Job_Opening__c newJob : newJobOpenings) {
                if (existingJobsMap.containsKey(newJob.Name)) {
                    newJob.addError('A Job Opening with this name already exists in Database: ' + newJob.Name);
                }
            }
        }
    }

    // AFTER UPDATE
    public static void handleAfterUpdate(List<Job_Opening__c> newJobOpenings, Map<Id, Job_Opening__c> oldMap) {

        // 1. Check Bypass Custom Permission
        if (FeatureManagement.checkPermission('Bypass_Job_Opening_Trigger')) {
            return;
        }

        // 2. Recursion Guard Check
        if (hasRun) {
            return;
        }
        hasRun = true;

        // 3. Collect Completed Job Opening IDs
        Set<Id> completedIds = new Set<Id>();
        for (Job_Opening__c job : newJobOpenings) {
            Job_Opening__c oldJob = oldMap.get(job.Id);

            // Corrected status check to 'Experienced'
            if (job.Status__c == 'Experienced' && oldJob.Status__c != 'Experienced') {
                completedIds.add(job.Id);
            }
        }

        if (completedIds.isEmpty()) return;

        // 4. Query & Update Open Interview Rounds
        List<Interview_Round__c> roundsToUpdate = [
            SELECT Id, Completed__c 
            FROM Interview_Round__c 
            WHERE Job_Opening__c IN :completedIds 
            AND Completed__c = false
        ];

        for (Interview_Round__c round : roundsToUpdate) {
            round.Completed__c = true;
        }

        if (!roundsToUpdate.isEmpty()) {
            update roundsToUpdate;
        }
    }
}