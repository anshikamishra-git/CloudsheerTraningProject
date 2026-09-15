public class hiringSyncService {

    // Overloaded method to handle numeric External IDs (Job_Opening_External_ID__c is Number(18,0))
    public static void makeGetCallout(Decimal externalId) {
        if (externalId != null) {
            makeGetCallout(String.valueOf(externalId.longValue()));
        }
    }

    public static void makeGetCallout(String externalId) {
        String correlationId = UUID.randomUUID().toString();
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:AcademyNamedCredential/courses/' + externalId);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');

        Integer maxAttempts = 3;
        
        // Loop 1 to 3 explicit execution (1 Main Call + 2 Retries)
        for (Integer attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                HttpResponse response = http.send(request);
                Integer statusCode = response.getStatusCode();

                // 2xx Success: Log attempt and exit loop
                if (statusCode >= 200 && statusCode < 300) {
                    hiringDTO dto = hiringDTO.parse(response.getBody());
                    logAttempt(attempt, statusCode, 'Success: ' + response.getBody(), correlationId);
                    break;
                } 
                // 4xx Client Error: Log attempt once and stop (No Retry)
                else if (statusCode >= 400 && statusCode < 500) {
                    logAttempt(attempt, statusCode, 'Client Error (No Retry): ' + response.getBody(), correlationId);
                    break;
                } 
                // 5xx Server Error: Always Log attempt (Total 3 attempts will log)
                else if (statusCode >= 500) {
                    logAttempt(attempt, statusCode, 'Server Error (Attempt ' + attempt + '): ' + response.getBody(), correlationId);
                    if (attempt < maxAttempts && !Test.isRunningTest()) {
                        sleep(1000 * attempt);
                    }
                }
            } catch (Exception e) {
                logAttempt(attempt, 0, 'Exception occurred: ' + e.getMessage(), correlationId);
                break;
            }
        }
    }

    private static void logAttempt(Integer attempt, Integer statusCode, String message, String correlationId) {
        Integration_Log__c log = new Integration_Log__c();
        log.Attempt_Number__c = attempt;
        log.Status_Code__c = statusCode;
        log.Message__c = message;
        log.Correlation_Id__c = correlationId;
        insert log;
    }

    private static void sleep(Integer milliseconds) {
        Long startTime = DateTime.now().getTime();
        while (DateTime.now().getTime() < startTime + milliseconds) {
            // Processing wait loop
        }
    }
}

/*public class hiringSyncService {

    public static void makeGetCallout(String externalId) {
        String correlationId = UUID.randomUUID().toString();
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:AcademyNamedCredential/courses/' + externalId);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');

        Integer maxAttempts = 3;
        
        // Loop 1 se 3 tak explicit chalega (1 Main Call + 2 Retries)
        for (Integer attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                HttpResponse response = http.send(request);
                Integer statusCode = response.getStatusCode();

                // 2xx Success: Log attempt and exit loop
                if (statusCode >= 200 && statusCode < 300) {
                    hiringDTO dto = hiringDTO.parse(response.getBody());
                    logAttempt(attempt, statusCode, 'Success: ' + response.getBody(), correlationId);
                    break;
                } 
                // 4xx Client Error: Log attempt once and stop (No Retry)
                else if (statusCode >= 400 && statusCode < 500) {
                    logAttempt(attempt, statusCode, 'Client Error (No Retry): ' + response.getBody(), correlationId);
                    break;
                } 
                // 5xx Server Error: Always Log attempt (Total 3 attempts will log)
                else if (statusCode >= 500) {
                    logAttempt(attempt, statusCode, 'Server Error (Attempt ' + attempt + '): ' + response.getBody(), correlationId);
                    if (attempt < maxAttempts && !Test.isRunningTest()) {
                        sleep(1000 * attempt);
                    }
                }
            } catch (Exception e) {
                logAttempt(attempt, 0, 'Exception occurred: ' + e.getMessage(), correlationId);
                break;
            }
        }
    }

    private static void logAttempt(Integer attempt, Integer statusCode, String message, String correlationId) {
        Integration_Log__c log = new Integration_Log__c();
        log.Attempt_Number__c = attempt;
        log.Status_Code__c = statusCode;
        log.Message__c = message;
        log.Correlation_Id__c = correlationId;
        insert log;
    }

    private static void sleep(Integer milliseconds) {
        Long startTime = DateTime.now().getTime();
        while (DateTime.now().getTime() < startTime + milliseconds) {
            // Processing wait loop
        }
    }
}
*/