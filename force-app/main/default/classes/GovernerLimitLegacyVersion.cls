public class GovernerLimitLegacyVersion {
    public static void testBadCode(){
      /* system.debug('checking governer limits by writing bad code');
       system.debug('before:' +Limits.getQueries());
        
        //getting job opening using soql but putting it inside the loop
        list<Job_Opening__c> job = [SELECT Job_Opening_External_ID__c, Status__c,
                                    Account__c, Job_Types__c FROM Job_Opening__c ];
        
        for (Job_Opening__c jobs : job){
            list<Interview_Round__c> IR = [SELECT Job_Opening__c, Due_Date__c, Planned_Hours__c, Interview_Round_External_ID__c FROM Interview_Round__c ];
            
        }*/
         System.debug('Checking governor limits using bad code :---- System.LimitException: Too many SOQL queries: 101');

        System.debug('Before Queries: ' + Limits.getQueries());

        // Getting  Interview Round records
        List<Interview_Round__c> rounds = [
            SELECT Id,
                   Job_Opening__c,
                   Due_Date__c,
                   Planned_Hours__c,
                   Interview_Round_External_ID__c
            FROM Interview_Round__c
        ];

        //  incorrect code : SOQL inside the loop
        for (Interview_Round__c round : rounds) {
            
                Job_Opening__c job = [
                    SELECT Id,
                       Job_Opening_External_ID__c,
                       Status__c,
                       Account__c,
                       Job_Types__c
                FROM Job_Opening__c
                WHERE Id = :round.Job_Opening__c
                LIMIT 1
            ];
          

        }

        System.debug('After Queries: ' + Limits.getQueries());
        
      //=========================================================================================================================
      
        System.debug('Checking DML exception governor limits using bad code:--- System.LimitException: Too many DML statements: 151'); 
        
        // 1. Fetch one real Course Module record to update
        List<Interview_Round__c> irList = [SELECT Id, Name FROM Interview_Round__c LIMIT 1];
        if (irList.size() > 0) {
            Interview_Round__c ir = irList[0];
            
            // 2. add 155 record to hit the governor limit
            for (Integer i = 0; i < 155; i++) { 
                ir.Planned_Hours__c = 8 + i;
                // This DML statement runs 155 times, triggering the limit exception
                update ir; 
                System.debug('DML Execution' + i); 
            }
        }
        else {
            System.debug('Error: Please create at least one Interview_Round__c record first.');
        }
        System.debug(' LEGACY VERSION END');
        
        //=========================================================================================================================================
        
        System.debug('Checking CPU governor limits using bad code:--- System.LimitException: Apex CPU time limit exceeded'); 
        
        // CPU limit exception
        string Text = 'A';
        Integer loopcount = 0;
        while (true){
            //calculating the length  of cpu cycle 
            Text = Text +  String.valueof(loopcount) + 'B';
            Text = Text.reverse().toUpperCase();
            
            //
            if (Math.mod(loopcount, 5000) == 0 ){
                system.debug('CPU exceed Cycle' +loopcount );
                
            }
        }
        
    }
}