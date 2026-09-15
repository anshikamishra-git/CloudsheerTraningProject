@isTest
private class JobOpeningTriggerHandlerTest {

    // 1. BULK INSERT TEST (251 Records - 2 Trigger Batches: 200 + 51)
    @isTest
    static void testBulkInsert251Records() {
        List<Job_Opening__c> jobList = new List<Job_Opening__c>();
        for (Integer i = 1; i <= 251; i++) {
            jobList.add(new Job_Opening__c(Name = 'Unique Job Opening ' + i));
        }

        Test.startTest();
        Database.SaveResult[] results = Database.insert(jobList, false);
        Test.stopTest();

        // Verify all 251 records are saved successfully
        Integer successCount = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            }
        }
        System.assertEquals(251, successCount, 'All 251 records should be successfully inserted.');
    }

    // 2. IN-BATCH DUPLICATE & DATABASE DUPLICATE TEST
    @isTest
    static void testInBatchAndDbDuplicates() {
        // Pre-insert a record in DB
        Job_Opening__c existingJob = new Job_Opening__c(Name = 'Existing Developer Role');
        insert existingJob;

        List<Job_Opening__c> batchJobs = new List<Job_Opening__c>{
            new Job_Opening__c(Name = 'Existing Developer Role'), // DB Duplicate
            new Job_Opening__c(Name = 'New QA Role'),             // Valid Unique
            new Job_Opening__c(Name = 'New QA Role')              // In-Batch Duplicate
        };

        Test.startTest();
        Database.SaveResult[] results = Database.insert(batchJobs, false);
        Test.stopTest();

        // 1st record fails (DB Duplicate), 2nd succeeds, 3rd fails (In-Batch Duplicate)
        System.assertEquals(false, results[0].isSuccess(), 'Database duplicate should be rejected.');
        System.assertEquals(true, results[1].isSuccess(), 'Unique record should be inserted.');
        System.assertEquals(false, results[2].isSuccess(), 'In-batch duplicate should be rejected.');
    }

    // 3. AFTER UPDATE INTERVIEW ROUNDS AUTO-COMPLETE TEST
    @isTest
    static void testAfterUpdateCompleteRounds() {
        Job_Opening__c job = new Job_Opening__c(Name = 'Salesforce Admin', Status__c = 'Intern');
        insert job;

        List<Interview_Round__c> rounds = new List<Interview_Round__c>{
            new Interview_Round__c(Job_Opening__c = job.Id, Completed__c = false),
            new Interview_Round__c(Job_Opening__c = job.Id, Completed__c = false)
        };
        insert rounds;

        Test.startTest();
        job.Status__c = 'Experienced';
        update job;
        Test.stopTest();

        // Verify related interview rounds were updated to Completed = true
        List<Interview_Round__c> updatedRounds = [
            SELECT Completed__c 
            FROM Interview_Round__c 
            WHERE Job_Opening__c = :job.Id
        ];
        for (Interview_Round__c round : updatedRounds) {
            System.assertEquals(true, round.Completed__c, 'Interview rounds should be marked complete.');
        }
    }

    // 4. BYPASS PERMISSION (KILL SWITCH) TEST
    @isTest
    static void testBypassTriggerLogic() {
        // Create duplicate records list
        List<Job_Opening__c> duplicateJobs = new List<Job_Opening__c>{
            new Job_Opening__c(Name = 'Bypass Job Role'),
            new Job_Opening__c(Name = 'Bypass Job Role')
        };

        // Create a test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'bypuser',
            Email = 'bypassuser@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'BypassTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'bypassuser' + DateTime.now().getTime() + '@testorg.com'
        );
        insert testUser;

        // Assign Custom Permission to user
        PermissionSet ps = new PermissionSet(
            Name = 'Bypass_PS',
            Label = 'Bypass Permission Set'
        );
        insert ps;

        SetupEntityAccess sea = new SetupEntityAccess(
            ParentId = ps.Id,
            SetupEntityId = [SELECT Id FROM CustomPermission WHERE DeveloperName = 'Bypass_Job_Opening_Trigger' LIMIT 1].Id
        );
        insert sea;

        insert new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = ps.Id
        );

        // Run as bypass user -> Trigger logic should be bypassed (both duplicates insert successfully)
        System.runAs(testUser) {
            Test.startTest();
            Database.SaveResult[] results = Database.insert(duplicateJobs, false);
            Test.stopTest();

            System.assertEquals(true, results[0].isSuccess(), 'Bypassed insert should succeed.');
            System.assertEquals(true, results[1].isSuccess(), 'Bypassed duplicate insert should succeed.');
        }
    }
}