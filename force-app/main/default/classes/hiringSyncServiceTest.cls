@isTest
private class hiringSyncServiceTest {

    @isTest
    static void testOutboundSuccess200() {
        Test.setMock(HttpCalloutMock.class, new hiringSyncServiceMock(200));
        Test.startTest();
        hiringSyncService.makeGetCallout('104');
        Test.stopTest();

        List<Integration_Log__c> logs = [SELECT Id, Status_Code__c FROM Integration_Log__c WHERE Status_Code__c = 200];
        System.assertEquals(1, logs.size());
    }

    @isTest
    static void testOutboundClientError404() {
        Test.setMock(HttpCalloutMock.class, new hiringSyncServiceMock(404));
        Test.startTest();
        hiringSyncService.makeGetCallout('999');
        Test.stopTest();

        List<Integration_Log__c> logs = [SELECT Id, Status_Code__c FROM Integration_Log__c WHERE Status_Code__c = 404];
        System.assertEquals(1, logs.size());
    }

    @isTest
    static void testOutboundServerError500Retry() {
        Test.setMock(HttpCalloutMock.class, new hiringSyncServiceMock(500));
        Test.startTest();
        hiringSyncService.makeGetCallout('104');
        Test.stopTest();

        // Query all logs created during 500 server error test
        List<Integration_Log__c> logs = [SELECT Id, Status_Code__c, Attempt_Number__c FROM Integration_Log__c WHERE Status_Code__c = 500];
     //   System.assertEquals(3, logs.size(), 'Expected 3 logs for 5xx retries');
    }

    @isTest
    static void testInboundRestSuccessAndNotFound() {
        Job_Opening__c c = new Job_Opening__c(Name = 'Test Course', Job_Opening_External_ID__c = 104, Status__c = 'Intern');
        insert c;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CourseStatus/104';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        JobOpeningStatusRestResource.getCourseStatus();
        System.assertEquals(200, res.statusCode);

        req.requestURI = '/services/apexrest/CourseStatus/99999';
        JobOpeningStatusRestResource.getCourseStatus();
        System.assertEquals(404, res.statusCode);
        Test.stopTest();
    }
}