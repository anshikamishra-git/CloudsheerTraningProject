@isTest
private class HiringServiceTestClass {

    // This runs once before all test methods, and builds shared data.
    @TestSetup
    static void setup() {
        HiringServiceTestData.createTestData();
    }

    // Test 1: happy path for getExperiencedOpenings
    @isTest
    static void testGetExperiencedOpenings() {
        List<Job_Opening__c> result = HiringService.getExperiencedOpenings();
        System.assertEquals(2, result.size(), 'There should be 2 Experienced openings.');
    }

    // Test 2: happy path for statusBreakdown
    @isTest
    static void testStatusBreakdown() {
        List<AggregateResult> results = HiringService.statusBreakdown();
        System.assert(results.size() > 0, 'statusBreakdown should return some grouped results.');
    }

    // Test 3: happy path for completeInterviewRounds
    @isTest
    static void testCompleteInterviewRounds() {
        List<Interview_Round__c> rounds = [SELECT Id FROM Interview_Round__c LIMIT 2];
        Set<Id> roundIds = new Set<Id>();
        for (Interview_Round__c r : rounds) {
            roundIds.add(r.Id);
        }

        HiringService.completeInterviewRounds(roundIds);

        List<Interview_Round__c> updatedRounds = [SELECT Completed__c  FROM Interview_Round__c WHERE Id IN :roundIds];
        for (Interview_Round__c r : updatedRounds) {
            System.assertEquals(true, r.Completed__c, 'This round should be marked Completed.');
        }
    }

    // Test 4 (negative test): empty set should throw our custom exception
    @isTest
    static void testCompleteInterviewRounds_emptySet() {
        Boolean errorHappened = false;

        try {
            HiringService.completeInterviewRounds(new Set<Id>());
        } catch (HiringServiceException e) {
            errorHappened = true;
            System.assertEquals('Please provide at least one Interview Round Id.', e.getMessage(),
                'Error message should match exactly.');
        }

        System.assert(errorHappened, 'An error should have happened for empty input.');
    }

    // Test 5 (negative test): null should also throw our custom exception
    @isTest
    static void testCompleteInterviewRounds_nullInput() {
        Boolean errorHappened = false;

        try {
            HiringService.completeInterviewRounds(null);
        } catch (HiringServiceException e) {
            errorHappened = true;
        }

        System.assert(errorHappened, 'An error should have happened for null input.');
    }

    // Test 6: System.runAs test, proving the Consultant user only sees what they should see
    @isTest
    static void testRunAsConsultant() {
        // This assumes the restricted Consultant user/profile was already
        // set up on Day 03.
        //User consultantUser = [SELECT Id FROM User WHERE Profile.Name = 'Consultant'];
        User consultantUser = [SELECT Id FROM User WHERE Username = 'consultantuser@cloudsheer.com' LIMIT 1];

        System.runAs(consultantUser) {
            List<Job_Opening__c> visibleOpenings = HiringService.getExperiencedOpenings();
            System.assert(visibleOpenings.size() <= 2,
                'Consultant should not see more At Risk openings than actually exist.');
        }
    }
}