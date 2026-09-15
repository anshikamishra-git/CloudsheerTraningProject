public class ZoomSummaryProcessor
    implements Queueable, Database.AllowsCallouts {

    private Id logId;

    public ZoomSummaryProcessor(Id logId) {
        this.logId = logId;
    }

    public void execute(QueueableContext context) {

        System.debug('================ SUMMARY PROCESSOR START ================');
        System.debug('Log Id: ' + logId);

        Zoom_Webhook_Log__c logRow;

        try {

            // ---------------------------------------------------------
            // 1. Get webhook log
            // ---------------------------------------------------------
            logRow = [
                SELECT Id,
                       Payload__c,
                       Event_Type__c,
                       Meeting_Id__c,
                       Meeting_UUID__c,
                       Status__c,
                       Error__c,
                       Retry_Count__c
                FROM Zoom_Webhook_Log__c
                WHERE Id = :logId
                LIMIT 1
            ];

            System.debug('Webhook Log Found: ' + logRow);

            // ---------------------------------------------------------
            // 2. Read payload
            // ---------------------------------------------------------
            if (String.isBlank(logRow.Payload__c)) {

                System.debug('ERROR: Payload is empty');

                logRow.Status__c = 'Failed';
                logRow.Error__c = 'Payload is empty';

                update logRow;
                return;
            }

            Map<String, Object> evt =
                (Map<String, Object>)
                JSON.deserializeUntyped(logRow.Payload__c);

            System.debug('Parsed Event: ' + evt);

            // ---------------------------------------------------------
            // 3. Get payload/object
            // ---------------------------------------------------------
            Map<String, Object> payload =
                (Map<String, Object>) evt.get('payload');

            if (payload == null) {

                System.debug('ERROR: Payload object missing');

                logRow.Status__c = 'Failed';
                logRow.Error__c = 'Payload object missing';

                update logRow;
                return;
            }

            Map<String, Object> objectData =
                (Map<String, Object>) payload.get('object');

            if (objectData == null) {

                System.debug('ERROR: Payload.object missing');

                logRow.Status__c = 'Failed';
                logRow.Error__c = 'Payload.object missing';

                update logRow;
                return;
            }

            System.debug('Object Data: ' + objectData);

            // ---------------------------------------------------------
            // 4. Get Meeting ID
            // ---------------------------------------------------------
            String meetingId = logRow.Meeting_Id__c;

            if (String.isBlank(meetingId) &&
                objectData.containsKey('meeting_id')) {

                meetingId =
                    String.valueOf(objectData.get('meeting_id'));
            }

            if (String.isBlank(meetingId) &&
                objectData.containsKey('id')) {

                meetingId =
                    String.valueOf(objectData.get('id'));
            }

            // ---------------------------------------------------------
            // 5. Get Meeting UUID
            // ---------------------------------------------------------
            String meetingUuid = logRow.Meeting_UUID__c;

            if (String.isBlank(meetingUuid) &&
                objectData.containsKey('meeting_uuid')) {

                meetingUuid =
                    String.valueOf(objectData.get('meeting_uuid'));
            }

            if (String.isBlank(meetingUuid) &&
                objectData.containsKey('uuid')) {

                meetingUuid =
                    String.valueOf(objectData.get('uuid'));
            }

            System.debug('Meeting ID: ' + meetingId);
            System.debug('Meeting UUID: ' + meetingUuid);

            if (String.isBlank(meetingId)) {

                System.debug('ERROR: Meeting ID not found');

                logRow.Status__c = 'Failed';
                logRow.Error__c = 'Meeting ID not found';

                update logRow;
                return;
            }

            // ---------------------------------------------------------
            // 6. Call Zoom Meeting Summary API
            //
            // Endpoint:
            // GET /v2/meetings/{meetingId}/meeting_summary
            //
            // Zoom officially supports this endpoint.
            // ---------------------------------------------------------

            HttpRequest request = new HttpRequest();

            String endpoint =
                'callout:Zoom_API/v2/meetings/' +
                EncodingUtil.urlEncode(meetingId, 'UTF-8') +
                '/meeting_summary';

            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setHeader('Content-Type', 'application/json');
            request.setTimeout(60000);

            System.debug('Zoom Summary Endpoint: ' + endpoint);

            Http http = new Http();

            HttpResponse response =
                http.send(request);

            System.debug('Zoom API Status Code: ' +
                         response.getStatusCode());

            System.debug('Zoom API Response: ' +
                         response.getBody());

            // ---------------------------------------------------------
            // 7. Check Zoom API response
            // ---------------------------------------------------------
            if (response.getStatusCode() != 200) {

                String errorMessage =
                    'Zoom API Error. Status: ' +
                    response.getStatusCode() +
                    ' Body: ' +
                    response.getBody();

                System.debug(errorMessage);

                logRow.Status__c = 'Failed';
                logRow.Error__c = errorMessage;

                update logRow;
                return;
            }

            // ---------------------------------------------------------
            // 8. Parse summary response
            // ---------------------------------------------------------
            Map<String, Object> summaryResponse =
                (Map<String, Object>)
                JSON.deserializeUntyped(response.getBody());

            System.debug('Summary Response Parsed: ' +
                         summaryResponse);

            String summaryTitle = '';
            String summaryOverview = '';
            String summaryContent = '';
            String summaryDocUrl = '';

            // New Zoom field
            if (summaryResponse.containsKey('summary_content') &&
                summaryResponse.get('summary_content') != null) {

                summaryContent =
                    String.valueOf(
                        summaryResponse.get('summary_content')
                    );
            }

            // Summary title
            if (summaryResponse.containsKey('summary_title') &&
                summaryResponse.get('summary_title') != null) {

                summaryTitle =
                    String.valueOf(
                        summaryResponse.get('summary_title')
                    );
            }

            // Summary overview
            if (summaryResponse.containsKey('summary_overview') &&
                summaryResponse.get('summary_overview') != null) {

                summaryOverview =
                    String.valueOf(
                        summaryResponse.get('summary_overview')
                    );
            }

            // Summary document URL
            if (summaryResponse.containsKey('summary_doc_url') &&
                summaryResponse.get('summary_doc_url') != null) {

                summaryDocUrl =
                    String.valueOf(
                        summaryResponse.get('summary_doc_url')
                    );
            }

            System.debug('Summary Title: ' + summaryTitle);
            System.debug('Summary Overview: ' + summaryOverview);
            System.debug('Summary Content: ' + summaryContent);
            System.debug('Summary Doc URL: ' + summaryDocUrl);

            // ---------------------------------------------------------
            // 9. Find Salesforce Event
            // ---------------------------------------------------------
            List<Event> events = [
                SELECT Id,
                       Subject,
                       Zoom_Meeting_Id__c,
                       AI_Summary__c
                FROM Event
                WHERE Zoom_Meeting_Id__c = :meetingId
                LIMIT 2
            ];

            System.debug(
                'Matching Salesforce Events Found: ' +
                events.size()
            );

            // ---------------------------------------------------------
            // 10. No matching Event
            // ---------------------------------------------------------
            if (events.isEmpty()) {

                System.debug(
                    'WARNING: No Salesforce Event found for Meeting ID: ' +
                    meetingId
                );

                logRow.Status__c = 'Unmatched';
                logRow.Error__c =
                    'No Salesforce Event found for Zoom Meeting ID: ' +
                    meetingId;

                update logRow;
                return;
            }

            // ---------------------------------------------------------
            // 11. Update Salesforce Event
            // ---------------------------------------------------------
            List<Event> eventsToUpdate =
                new List<Event>();

            for (Event ev : events) {

                System.debug(
                    'Updating Salesforce Event: ' +
                    ev.Id
                );

                String finalSummary = '';

                if (!String.isBlank(summaryContent)) {
                    finalSummary = summaryContent;
                } else if (!String.isBlank(summaryOverview)) {
                    finalSummary = summaryOverview;
                } else if (!String.isBlank(summaryTitle)) {
                    finalSummary = summaryTitle;
                }

                ev.AI_Summary__c = finalSummary;

                eventsToUpdate.add(ev);
            }

            if (!eventsToUpdate.isEmpty()) {

                update eventsToUpdate;

                System.debug(
                    'Salesforce Event updated successfully'
                );
            }

            // ---------------------------------------------------------
            // 12. Mark webhook log as processed
            // ---------------------------------------------------------
            logRow.Status__c = 'Processed';
            logRow.Error__c = null;

            update logRow;

            System.debug(
                'Webhook Log marked as Processed'
            );

            System.debug('================ SUMMARY PROCESSOR END ================');

        } catch (Exception e) {

            System.debug('================ PROCESSOR ERROR ================');
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Error Line: ' + e.getLineNumber());
            System.debug('Stack Trace: ' + e.getStackTraceString());

            // ---------------------------------------------------------
            // Save error in webhook log
            // ---------------------------------------------------------
            if (logRow != null) {

                logRow.Status__c = 'Failed';

                logRow.Error__c =
                    'Line ' +
                    e.getLineNumber() +
                    ': ' +
                    e.getMessage();

                if (logRow.Retry_Count__c == null) {
                    logRow.Retry_Count__c = 1;
                } else {
                    logRow.Retry_Count__c++;
                }

                update logRow;
            }
        }
    }
}