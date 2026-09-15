trigger JobOpeningTrigger on Job_Opening__c (before insert, after insert, after update ) {
    
    //===================================
     // ye day 10 ke task ka trigger h 

    if (Trigger.isBefore && Trigger.isInsert) {
        // Naye records insert ho rahe hain - duplicate check ke liye handler call kiya
        JobOpeningTriggerHandler.handleBeforeInsert(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        // Records update ho rahe hain - interview round complete karne ke liye
        JobOpeningTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
    
    //=====================================
        // ye day 11 ke task ka triiger h 
        if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        RecruitmentService.handleCourseRiskRouting(Trigger.new);
    }
}