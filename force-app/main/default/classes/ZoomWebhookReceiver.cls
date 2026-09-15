@RestResource(urlMapping='/zoom/summary/*')
global without sharing class ZoomWebhookReceiver {

    @HttpPost
    global static void handlePost() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        System.debug('================ ZOOM WEBHOOK START ================');

        try {

            // ---------------------------------------------------------
            // 1. Read request body
            // ---------------------------------------------------------
            String body = req.requestBody == null
                ? ''
                : req.requestBody.toString();

            System.debug('Zoom Webhook Body: ' + body);

            if (String.isBlank(body)) {
                System.debug('ERROR: Empty request body');
                res.statusCode = 400;
                return;
            }

            // ---------------------------------------------------------
            // 2. Get Secret Token from Custom Metadata
            // ---------------------------------------------------------
            Zoom_Integration_Setting__mdt setting =
                Zoom_Integration_Setting__mdt.getInstance('Zoom_Integration');

            if (setting == null) {
                System.debug('ERROR: Zoom_Integration custom metadata record not found');
                res.statusCode = 500;
                return;
            }

            String secret = setting.Secret_Token__c;

            if (String.isBlank(secret)) {
                System.debug('ERROR: Secret Token is blank in Custom Metadata');
                res.statusCode = 500;
                return;
            }

            System.debug('Secret Token found successfully');

            // ---------------------------------------------------------
            // 3. Convert JSON into Map
            // ---------------------------------------------------------
            Map<String, Object> evt =
                (Map<String, Object>) JSON.deserializeUntyped(body);

            String eventType = (String) evt.get('event');

            System.debug('Event Type: ' + eventType);

            // ---------------------------------------------------------
            // 4. Zoom Endpoint URL Validation
            // ---------------------------------------------------------
            if (eventType == 'endpoint.url_validation') {

                System.debug('Processing Zoom URL validation challenge');

                Map<String, Object> payload =
                    (Map<String, Object>) evt.get('payload');

                String plainToken =
                    payload == null
                    ? null
                    : (String) payload.get('plainToken');

                if (String.isBlank(plainToken)) {
                    System.debug('ERROR: plainToken missing');
                    res.statusCode = 400;
                    return;
                }

                String encryptedToken =
                    EncodingUtil.convertToHex(
                        Crypto.generateMac(
                            'HmacSHA256',
                            Blob.valueOf(plainToken),
                            Blob.valueOf(secret)
                        )
                    );

                Map<String, String> responseMap =
                    new Map<String, String>{
                        'plainToken' => plainToken,
                        'encryptedToken' => encryptedToken
                    };

                res.statusCode = 200;
                res.addHeader('Content-Type', 'application/json');
                res.responseBody =
                    Blob.valueOf(JSON.serialize(responseMap));

                System.debug('URL validation successful');
                return;
            }

            // ---------------------------------------------------------
            // 5. Verify Zoom Signature
            // ---------------------------------------------------------
            String timestamp =
                req.headers.get('x-zm-request-timestamp');

            String receivedSignature =
                req.headers.get('x-zm-signature');

            System.debug('Zoom Timestamp: ' + timestamp);
            System.debug('Received Signature: ' + receivedSignature);

            if (String.isBlank(timestamp) ||
                String.isBlank(receivedSignature)) {

                System.debug('ERROR: Zoom signature headers missing');
                res.statusCode = 401;
                return;
            }

            Long timestampLong;

            try {
                timestampLong = Long.valueOf(timestamp);
            } catch (Exception e) {

                System.debug('ERROR: Invalid timestamp: ' + timestamp);

                res.statusCode = 401;
                return;
            }

            String message =
                'v0:' + timestamp + ':' + body;

            String hash =
                EncodingUtil.convertToHex(
                    Crypto.generateMac(
                        'HmacSHA256',
                        Blob.valueOf(message),
                        Blob.valueOf(secret)
                    )
                );

            String expectedSignature = 'v0=' + hash;

            System.debug('Expected Signature: ' + expectedSignature);

            // ---------------------------------------------------------
            // 6. Check timestamp - prevent replay attacks
            // ---------------------------------------------------------
            Long currentTime =
                DateTime.now().getTime() / 1000;

            Long difference =
                Math.abs(currentTime - timestampLong);

            System.debug('Timestamp Difference: ' + difference);

            if (difference > 300) {

                System.debug('ERROR: Zoom webhook timestamp expired');

                res.statusCode = 401;
                return;
            }

            if (!expectedSignature.equals(receivedSignature)) {

                System.debug('ERROR: Invalid Zoom signature');

                res.statusCode = 401;
                return;
            }

            System.debug('Zoom signature verified successfully');

            // ---------------------------------------------------------
            // 7. Extract payload/object
            // ---------------------------------------------------------
            Map<String, Object> payload =
                (Map<String, Object>) evt.get('payload');

            Map<String, Object> objectData =
                payload == null
                ? null
                : (Map<String, Object>) payload.get('object');

            System.debug('Payload: ' + payload);
            System.debug('Object Data: ' + objectData);

            // ---------------------------------------------------------
            // 8. IMPORTANT:
            // meeting.started uses:
            //      id
            //      uuid
            //
            // meeting.summary_completed uses:
            //      meeting_id
            //      meeting_uuid
            //
            // So we support BOTH formats.
            // ---------------------------------------------------------

            String meetingId = null;
            String meetingUuid = null;
            String meetingTopic = null;
            DateTime meetingStartTime = null;
            String meetingPasscode = null;
            String meetingInvitees = null;
            String meetingInviteLink = null;

            if (objectData != null) {

                // For meeting.started / meeting.ended etc.
                if (objectData.containsKey('id')) {
                    meetingId =
                        String.valueOf(objectData.get('id'));
                }

                if (objectData.containsKey('uuid')) {
                    meetingUuid =
                        String.valueOf(objectData.get('uuid'));
                }

                // For meeting.summary_completed
                if (String.isBlank(meetingId) &&
                    objectData.containsKey('meeting_id')) {

                    meetingId =
                        String.valueOf(objectData.get('meeting_id'));
                }

                if (String.isBlank(meetingUuid) &&
                    objectData.containsKey('meeting_uuid')) {

                    meetingUuid =
                        String.valueOf(objectData.get('meeting_uuid'));
                }

                // ---------------------------------------------------
                // Topic - directly available in the webhook payload.
                // ---------------------------------------------------
                if (objectData.containsKey('topic')) {
                    meetingTopic = String.valueOf(objectData.get('topic'));
                }

                // ---------------------------------------------------
                // Start Time - directly available in the webhook payload.
                // ---------------------------------------------------
                if (objectData.get('start_time') != null) {
                    String startTimeStr = String.valueOf(objectData.get('start_time'));
                    meetingStartTime = (DateTime) JSON.deserialize(
                        '"' + startTimeStr + '"',
                        DateTime.class
                    );
                }
                //Invite link directly available in payload
                if(objectData.containsKey('join_url')){
                    meetingInviteLink = String.valueOf(objectData.get('join_url'));
                }
                // ---------------------------------------------------
                // Passcode - only present on some event types.
                // Zoom sends it either as "password" directly on the
                // object, or nested under "settings".
                // ---------------------------------------------------
                if (objectData.containsKey('password')) {
                    meetingPasscode = String.valueOf(objectData.get('password'));
                }

                Map<String, Object> objSettings =
                    (Map<String, Object>) objectData.get('settings');

                if (meetingPasscode == null &&
                    objSettings != null &&
                    objSettings.containsKey('password')) {
                    meetingPasscode = String.valueOf(objSettings.get('password'));
                }

                // ---------------------------------------------------
                // Invitees - only present on some event types,
                // nested under settings.meeting_invitees.
                // ---------------------------------------------------
                if (objSettings != null && objSettings.containsKey('meeting_invitees')) {
                    List<Object> invitees = (List<Object>) objSettings.get('meeting_invitees');
                    List<String> emails = new List<String>();

                    for (Object o : invitees) {
                        Map<String, Object> inv = (Map<String, Object>) o;
                        if (inv.get('email') != null) {
                            emails.add((String) inv.get('email'));
                        }
                    }

                    if (!emails.isEmpty()) {
                        meetingInvitees = String.join(emails, ', ');
                    }
                }
            }

            System.debug('FINAL Meeting ID: ' + meetingId);
            System.debug('FINAL Meeting UUID: ' + meetingUuid);
            System.debug('FINAL Meeting Topic: ' + meetingTopic);
            System.debug('FINAL Meeting Start Time: ' + meetingStartTime);
            System.debug('FINAL Meeting Passcode present: ' + (meetingPasscode != null));
            System.debug('FINAL Meeting Invitees: ' + meetingInvitees);
            System.debug('FINAL Meeting Link:' + meetingInviteLink);

            // ---------------------------------------------------------
            // 9. Create Zoom Webhook Log
            // Only these 4 fields go on the log record now.
            // ---------------------------------------------------------
            Zoom_Webhook_Log__c logRow =
                new Zoom_Webhook_Log__c();

            logRow.Event_Type__c = eventType;
            logRow.Payload__c = body;
            logRow.Status__c = 'Received';
            logRow.Retry_Count__c = 0;

            System.debug('Log Row Before Insert: ' + logRow);

            insert logRow;

            System.debug('Zoom Webhook Log Created: ' + logRow.Id);

            // ---------------------------------------------------------
            // 9b. Meeting Id / UUID now go on Zoom_Meeting__c directly,
            // instead of on the webhook log.
            // upsert on Meeting_Id__c (external id) so that when
            // ZoomMeetingDetails runs later, it updates this SAME
            // record instead of creating a duplicate.
            // ---------------------------------------------------------
            Id meetingRecordId = null;

            if (!String.isBlank(meetingId)) {

                Zoom_Meeting__c zm = new Zoom_Meeting__c();
                zm.Meeting_Id__c = meetingId;

                if (!String.isBlank(meetingUuid)) {
                    zm.Meeting_UUID__c = meetingUuid;
                }

                if (!String.isBlank(meetingTopic)) {
                    zm.Topic__c = meetingTopic;
                }

                if (meetingStartTime != null) {
                    zm.Time__c = meetingStartTime;
                }

                if (!String.isBlank(meetingPasscode)) {
                    zm.Passcode__c = meetingPasscode;
                }

                if (!String.isBlank(meetingInvitees)) {
                    zm.Invitees__c = meetingInvitees;
                }
                if(!String.isBlank(meetinginviteLink)){
                    zm.Invite_Link__c = meetingInviteLink;
                }

                System.debug('Zoom Meeting Row Before Upsert: ' + zm);

                upsert zm Meeting_Id__c;

                meetingRecordId = zm.Id;

                System.debug('Zoom Meeting Upserted: ' + zm.Id);
            }

            // ---------------------------------------------------------
            // 10. Process summary asynchronously
            // ---------------------------------------------------------
            /*if (eventType == 'meeting.summary_completed') {

                System.debug(
                    'Summary completed event received. ' +
                    'Starting Queueable processor.'
                );

                System.enqueueJob(
                    new ZoomSummaryProcessor(logRow.Id)
                );
            }*/
            if (
    meetingRecordId != null &&
    (eventType == 'meeting.created' ||
    eventType == 'meeting.updated' ||
    eventType == 'meeting.started' ||
    eventType == 'meeting.ended')
) {

    System.debug(
        'Meeting event received: ' + eventType
    );

    System.debug(
        'Starting ZoomMeetingDetails Queueable'
    );

    System.enqueueJob(
        new ZoomMeetingDetails(logRow.Id, meetingRecordId)
    );
}

            // ---------------------------------------------------------
            // 11. Send success response to Zoom
            // ---------------------------------------------------------
            res.statusCode = 200;

            System.debug('================ ZOOM WEBHOOK END ================');

        } catch (Exception e) {

            System.debug('================ ZOOM WEBHOOK ERROR ================');
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Error Line: ' + e.getLineNumber());
            System.debug('Stack Trace: ' + e.getStackTraceString());

            res.statusCode = 500;
        }
    }
}