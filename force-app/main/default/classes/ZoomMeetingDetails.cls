// Queueable class is used to run the Zoom API call asynchronously.
// Database.AllowsCallouts allows this Queueable class to make HTTP callouts.
public class ZoomMeetingDetails implements Queueable, Database.AllowsCallouts {

    // Stores the Id of the Zoom Webhook Log record
    // (used only to update Status__c / Error__c / Retry_Count__c).
    private Id logId;

    // Stores the Id of the Zoom_Meeting__c record
    // (used to read Meeting_Id__c for the Zoom API callout).
    private Id meetingRecordId;


    // Constructor
    public ZoomMeetingDetails(Id logId, Id meetingRecordId) {
        this.logId = logId;
        this.meetingRecordId = meetingRecordId;
    }


    // execute() method is automatically called
    // when the Queueable job starts running.
    public void execute(QueueableContext ctx) {

        System.debug('Zoom_Webhook_Log__c Id received: ' + logId);
        System.debug('Zoom_Meeting__c Id received: ' + meetingRecordId);

        // Get a fresh reference to the log row so we can update it
        // from ANYWHERE in this method, including the catch block.
        Zoom_Webhook_Log__c logRow;

        // =====================================================
        // EVERYTHING is inside try now, so ANY failure
        // (query failure, missing field, callout error,
        // parsing error, DML error) is caught and saved
        // to Zoom_Webhook_Log__c instead of failing silently.
        // =====================================================
        try {

            // ---------------------------------------------------
            // Load the webhook log row (only for status tracking now).
            // ---------------------------------------------------
            List<Zoom_Webhook_Log__c> logList = [
                SELECT Id,
                       Event_Type__c,
                       Status__c,
                       Error__c,
                       Retry_Count__c
                FROM Zoom_Webhook_Log__c
                WHERE Id = :logId
                LIMIT 1
            ];

            if (logList.isEmpty()) {
                System.debug(
                    LoggingLevel.ERROR,
                    'ZoomMeetingDetails: No Zoom_Webhook_Log__c found for Id ' + logId
                );
                return;
            }

            logRow = logList[0];
            System.debug('Webhook Log loaded. Event Type = ' + logRow.Event_Type__c);


            // ---------------------------------------------------
            // Load the Zoom_Meeting__c record to get Meeting_Id__c
            // (this now replaces reading Meeting_Id__c from the log).
            // ---------------------------------------------------
            if (meetingRecordId == null) {
                System.debug(LoggingLevel.ERROR, 'Zoom_Meeting__c Id was not provided.');

                logRow.Status__c = 'Failed';
                logRow.Error__c = 'Zoom_Meeting__c record Id is missing.';
                update logRow;
                return;
            }

            List<Zoom_Meeting__c> meetingList = [
                SELECT Id, Meeting_Id__c
                FROM Zoom_Meeting__c
                WHERE Id = :meetingRecordId
                LIMIT 1
            ];

            if (meetingList.isEmpty()) {
                System.debug(LoggingLevel.ERROR, 'No Zoom_Meeting__c found for Id ' + meetingRecordId);

                logRow.Status__c = 'Failed';
                logRow.Error__c = 'Zoom_Meeting__c record not found for Id ' + meetingRecordId;
                update logRow;
                return;
            }

            String meetingId = meetingList[0].Meeting_Id__c;

            // Check whether Meeting ID is available.
            if (String.isBlank(meetingId)) {
                System.debug(LoggingLevel.ERROR, 'Meeting Id missing on Zoom_Meeting__c record.');

                logRow.Status__c = 'Failed';
                logRow.Error__c = 'Meeting ID is missing on Zoom_Meeting__c record.';
                update logRow;
                return;
            }


            // =====================================================
            // ZOOM API CALLOUT
            // =====================================================
            HttpRequest req = new HttpRequest();

            req.setEndpoint(
                'callout:Zoom_OAuth_Cred/v2/meetings/' +
                EncodingUtil.urlEncode(meetingId, 'UTF-8')
            );
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(60000);
            System.debug('Calling Zoom API: ' + req.getEndpoint());

            HttpResponse res = new Http().send(req);

            // HTTP 200 means success. Anything else = failure.
            if (res.getStatusCode() != 200) {
                logRow.Status__c = 'Failed';
                logRow.Error__c =
                    'Zoom API HTTP ' +
                    res.getStatusCode() +
                    ': ' +
                    res.getBody();
                update logRow;
                return;
            }


            // =====================================================
            // PARSE ZOOM RESPONSE
            // =====================================================
            Map<String, Object> m =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            Zoom_Meeting__c zm = new Zoom_Meeting__c();

            zm.Meeting_Id__c = String.valueOf(m.get('id'));
            zm.Meeting_UUID__c = (String) m.get('uuid');
            zm.Topic__c = (String) m.get('topic');
            zm.Invite_Link__c = (String) m.get('join_url');
            zm.Passcode__c = (String) m.get('password');

            if (m.get('start_time') != null) {
                String startTimeStr = (String) m.get('start_time');
                zm.Time__c = (DateTime) JSON.deserialize(
                    '"' + startTimeStr + '"',
                    DateTime.class
                );
            }

            Map<String, Object> settings =
                (Map<String, Object>) m.get('settings');

            if (settings != null && settings.containsKey('meeting_invitees')) {
                List<Object> invitees =
                    (List<Object>) settings.get('meeting_invitees');

                List<String> emails = new List<String>();

                for (Object o : invitees) {
                    Map<String, Object> inv = (Map<String, Object>) o;
                    if (inv.get('email') != null) {
                        emails.add((String) inv.get('email'));
                    }
                }

                if (!emails.isEmpty()) {
                    zm.Invitees__c = String.join(emails, ', ');
                }
            }


            // =====================================================
            // SAVE ZOOM MEETING RECORD (success path)
            // upsert on Meeting_Id__c so this updates the SAME
            // record that ZoomWebhookReceiver already created.
            // =====================================================
            upsert zm Meeting_Id__c;


            // =====================================================
            // UPDATE WEBHOOK LOG (success path)
            // =====================================================
            logRow.Status__c = 'Processed';
            logRow.Error__c = null;   // clear any stale error from a previous retry
            update logRow;


        } catch (Exception e) {

            // =====================================================
            // ERROR HANDLING - covers query errors, callout errors,
            // JSON parsing errors, DML errors - literally anything
            // above. This guarantees the webhook log always gets
            // an error saved on failure.
            // =====================================================
            System.debug(
                LoggingLevel.ERROR,
                'ZoomMeetingDetails failed: Line ' + e.getLineNumber() + ' - ' + e.getMessage()
            );

            // If we never even loaded the log row (e.g. the SOQL
            // query itself threw), re-query it here so we can
            // still save the error instead of losing it silently.
            if (logRow == null && logId != null) {
                List<Zoom_Webhook_Log__c> fallback = [
                    SELECT Id, Status__c, Error__c, Retry_Count__c
                    FROM Zoom_Webhook_Log__c
                    WHERE Id = :logId
                    LIMIT 1
                ];
                if (!fallback.isEmpty()) {
                    logRow = fallback[0];
                }
            }

            if (logRow != null) {
                logRow.Status__c = 'Failed';
                logRow.Error__c = 'Line ' + e.getLineNumber() + ': ' + e.getMessage();
                logRow.Retry_Count__c =
                    (logRow.Retry_Count__c == null)
                    ? 1
                    : logRow.Retry_Count__c + 1;
                update logRow;
            }
        }
    }
}