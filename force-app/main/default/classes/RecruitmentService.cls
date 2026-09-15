public class RecruitmentService {

    // Step 1: Guaranteed MIXED DML Exception Cause karne ke liye
    public static void causeMixedDMLError(Id courseId) {
        UserRole ur = new UserRole(Name = 'Test Role ' + System.currentTimeMillis());
        insert ur;

        Job_Opening__c c = [SELECT Id, Name FROM Job_Opening__c WHERE Id = :courseId LIMIT 1];
        c.Name = c.Name + ' Test';
        update c;
    }

    // Step 3: Fixed Version using @future method
    public static void fixMixedDML(Id courseId) {
        UserRole ur = new UserRole(Name = 'Test Role ' + System.currentTimeMillis());
        insert ur;

        UserAccountHandler.stampRiskAsync(new Set<Id>{courseId});
    }

    // Step 7: Trigger Handler Routing logic
    public static void handleCourseRiskRouting(List<Job_Opening__c> newCourses) {
        // FIX: Agar pehle se Future ya Batch execution me hain, toh dobara Future Callout mat karo!
        if (System.isFuture() || System.isBatch()) {
            System.debug('Already in Async Context. Skipping re-enqueuing.');
            return;
        }

        Set<Id> highRiskCourseIds = new Set<Id>();
        
        for (Job_Opening__c c : newCourses) {
            if (c.Priority__c == 'High') {
                highRiskCourseIds.add(c.Id);
            }
        }

        // Empty Set Guard
        if (highRiskCourseIds.isEmpty()) return;

        // Trigger context me ho toh Future method se async stamp hoga
        if (Trigger.isExecuting) {
            UserAccountHandler.stampRiskAsync(highRiskCourseIds);
        } else {
            // Anonymous Apex Context (Direct Path)
            List<Job_Opening__c> directUpdate = [SELECT Id, Risk_Stamped__c FROM Job_Opening__c WHERE Id IN :highRiskCourseIds];
            for (Job_Opening__c c : directUpdate) {
                if (c.Risk_Stamped__c != true) {
                    c.Risk_Stamped__c = true;
                }
            }
            if (!directUpdate.isEmpty()) {
                update directUpdate;
            }
        }
    }
}



//===========================================================
/*public class RecruitmentService {

    // Step 1: Guaranteed MIXED DML Exception Cause karne ke liye
    public static void causeMixedDMLError(Id courseId) {
        UserRole ur = new UserRole(Name = 'Test Role ' + System.currentTimeMillis());
        insert ur;

        Job_Opening__c c = [SELECT Id, Name FROM Job_Opening__c WHERE Id = :courseId LIMIT 1];
        c.Name = c.Name + ' Test';
        update c;
    }

    // Step 3: Fixed Version using @future method
    public static void fixMixedDML(Id courseId) {
        UserRole ur = new UserRole(Name = 'Test Role ' + System.currentTimeMillis());
        insert ur;

        UserAccountHandler.stampRiskAsync(new Set<Id>{courseId});
    }

    // Step 7: Trigger Handler Routing logic
    public static void handleCourseRiskRouting(List<Job_Opening__c> newCourses) {
        Set<Id> highRiskCourseIds = new Set<Id>();
        
        for (Job_Opening__c c : newCourses) {
            if (c.Priority__c == 'High') {
                highRiskCourseIds.add(c.Id);
            }
        }

        if (highRiskCourseIds.isEmpty()) return;

        // Trigger context me ho toh Future method se async stamp hoga
        if (Trigger.isExecuting) {
            UserAccountHandler.stampRiskAsync(highRiskCourseIds);
        } else {
            // Anonymous Apex Context (Direct Path)
            List<Job_Opening__c> directUpdate = [SELECT Id, Risk_Stamped__c FROM Job_Opening__c WHERE Id IN :highRiskCourseIds];
            for (Job_Opening__c c : directUpdate) {
                if (c.Risk_Stamped__c != true) {
                    c.Risk_Stamped__c = true;
                }
            }
            update directUpdate;
        }
    }
}*/