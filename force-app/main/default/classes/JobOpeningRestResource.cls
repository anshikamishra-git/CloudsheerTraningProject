@RestResource(urlMapping='/JobOpeningService/*')
global with sharing class JobOpeningRestResource {

    @HttpGet
    global static void getJobStatus() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        res.addHeader('Content-Type', 'application/json');

        // Request URL path se External ID String extract kar rahe hain
        String jobIdStr = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);

        try {
            // String ko trim kar rahe hain extra spaces removal ke liye
            jobIdStr = jobIdStr.trim();
            Decimal jobIdDec = Decimal.valueOf(jobIdStr);

            // Database me matching Job Opening query kar rahe hain
            Job_Opening__c job = [SELECT Id, Name, Job_Opening_External_ID__c, Status__c 
                                  FROM Job_Opening__c 
                                  WHERE Job_Opening_External_ID__c = :jobIdDec 
                                  LIMIT 1];

            // Successful 200 OK status code set kar rahe hain
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'jobId' => String.valueOf(job.Job_Opening_External_ID__c),
                'status' => job.Status__c,
                'jobTitle' => job.Name
            }));
        } catch (QueryException e) {
            // Record na milne par 404 Status Code set kar rahe hain
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'error' => 'Job Opening Not Found',
                'message' => 'No job record found for External ID: ' + jobIdStr
            }));
        } catch (Exception e) {
            // Conversion/Type Exception aane par clean 400 error return karein
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'error' => 'Bad Request',
                'message' => e.getMessage()
            }));
        }
    }
}