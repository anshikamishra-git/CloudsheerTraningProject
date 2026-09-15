public class UserAccountHandler {

    // Step 5: @future method with Idempotency Guard
    @future
    public static void stampRiskAsync(Set<Id> courseIds) {
        if (courseIds == null || courseIds.isEmpty()) return;
        
        List<Job_Opening__c> coursesToUpdate = new List<Job_Opening__c>();
        
        for (Job_Opening__c c : [SELECT Id, Risk_Stamped__c FROM Job_Opening__c WHERE Id IN :courseIds]) {
            // IDEMPOTENCY GUARD: Check karo ki pehle se stamped toh nahi hai?
            if (c.Risk_Stamped__c != true) {
                c.Risk_Stamped__c = true;
                coursesToUpdate.add(c);
            }
        }
        
        if (!coursesToUpdate.isEmpty()) {
            update coursesToUpdate;
            System.debug('Idempotency Check Passed: Stamp Applied.');
        } else {
            System.debug('Idempotency Guard Activated: Already Stamped! Skipped DML.');
        }
    }
}