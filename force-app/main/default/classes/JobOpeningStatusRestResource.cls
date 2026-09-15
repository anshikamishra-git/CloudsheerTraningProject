@RestResource(urlMapping='/JobOpeningStatus/*')
global with sharing class JobOpeningStatusRestResource {

    // External systems ko HTTP GET request ke zariye Course Status return karega
    @HttpGet
    global static void getCourseStatus() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        // Request URI se External ID extract ki ja rahi hai
        String externalIdStr = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);

        try {
            Decimal extId = Decimal.valueOf(externalIdStr);
            
            // Org ke Job_Opening__c object se Record fetch ho raha hai using Course_External__c
            Job_Opening__c course = [SELECT Id, Name, Job_Opening_External_ID__c, Status__c 
                                FROM Job_Opening__c 
                                WHERE Job_Opening_External_ID__c = :extId LIMIT 1];

            // 200 OK Response prepare ho raha hai DTO format me
            hiringDTO dto = new hiringDTO();
            dto.courseId = String.valueOf(course.Job_Opening_External_ID__c);
            dto.courseName = course.Name;
            dto.status = course.Status__c;

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(dto));

        } catch (QueryException qe) {
            // Record not found case: Clean 404 JSON body set ho raha hai
            res.statusCode = 404;
            Map<String, String> errMap = new Map<String, String>{
                'error' => 'Not Found',
                'message' => 'No course found with External ID: ' + externalIdStr
            };
            res.responseBody = Blob.valueOf(JSON.serialize(errMap));
        } catch (Exception e) {
            // Bad request/parsing error case: 400 set ho raha hai
            res.statusCode = 400;
            Map<String, String> errMap = new Map<String, String>{
                'error' => 'Bad Request',
                'message' => e.getMessage()
            };
            res.responseBody = Blob.valueOf(JSON.serialize(errMap));
        }
    }
}