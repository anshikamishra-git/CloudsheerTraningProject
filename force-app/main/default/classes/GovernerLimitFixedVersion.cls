public class GovernerLimitFixedVersion {
      public static void testCode(){ 
        //SQL Query limit Code Fix ====================================================================================================================== 
        System.debug('Checking governor limits using bad code'); 
        System.debug('Before Queries: ' + Limits.getQueries()); 
        
        // Get 300+ Course module records 
        List<Interview_Round__c> ir = [ SELECT Job_Opening__c, Due_Date__c, Planned_Hours__c, Interview_Round_External_ID__c FROM Interview_Round__c]; 
        
        // Salesforce Best Practice: Collect IDs to avoid SOQL inside the loop 
        Set<Id> jobIds = new Set<Id>();
        for (Interview_Round__c round : ir) { 
            if (round.Job_Opening__c != null) {
                jobIds.add(round.Job_Opening__c);
            }
        }
        
        // Fetch all related Course records in a single query outside the loop
        Map<Id, Job_Opening__c> courseMap = new Map<Id, Job_Opening__c>([
            SELECT Id,
                       Job_Opening_External_ID__c,
                       Status__c,
                       Account__c,
                       Job_Types__c
                FROM Job_Opening__c
            WHERE Id IN :jobIds
        ]);
        
        // Process data using the Map in memory
        for (Interview_Round__c round : ir) { 
            if (courseMap.containsKey(round.Job_Opening__c)) {
                Job_Opening__c Ca = courseMap.get(round.Job_Opening__c);
            }
        } 
        
        System.debug('After Queries: ' + Limits.getQueries()); 
        
        // DML Statement code Fix ======================================================================================================================
        System.debug('LEGACY VERSION START'); 
        
        // Fetch up to 155 Course Module records to process in bulk
        List<Interview_Round__c> cdList = [SELECT Id, Name, Planned_Hours__c FROM Interview_Round__c LIMIT 155]; 
        
        if (cdList.size() > 0) { 
            // Salesforce Best Practice: Create a list to hold records for bulk DML
            List<Interview_Round__c> recordsToUpdate = new List<Interview_Round__c>();
            
            for (Integer i = 0; i < cdList.size(); i++) { 
                Interview_Round__c cm = cdList[i];
                cm.Planned_Hours__c = 8 + i; 
                
                // Add the record to the collection instead of updating inside the loop
                recordsToUpdate.add(cm);
                System.debug('DML Execution' + i); 
            } 
            
            // Execute a single DML statement outside the loop
            update recordsToUpdate;
        } else { 
            System.debug('Error: Please create at least one Interview_Round__c record first.'); 
        } 
        System.debug(' LEGACY VERSION END'); 
        
        //CPU time limit code Fix ======================================================================================================================
        System.debug('Checking DML exception governor limits using bad code:--- System.LimitException: Too many DML statements: 151'); 
        
        // CPU limit exception Fix: Replaced the infinite while(true) loop with a safe, bounded loop
        String Text = 'A'; 
        Integer loopcount = 0; 
        
        // Set a strict finite limit (e.g., 100 iterations) to complete processing without hogging CPU time
        while (loopcount < 100){ 
            Text = Text + String.valueof(loopcount) + 'B'; 
            Text = Text.reverse().toUpperCase(); 
            
            if (Math.mod(loopcount, 5000) == 0 ){ 
                system.debug('CPU exceed Cycle' + loopcount ); 
            } 
            loopcount++;
        } 
       } 

        
    }