public class ZoomMeetingCreator implements Queueable, Database.AllowsCallouts {

    private Set<Id> eventIds;

    public ZoomMeetingCreator(Set<Id> eventIds) {
        this.eventIds = eventIds;
    }

    // =========================================================
    // Get Zoom Access Token using Server-to-Server OAuth
    // =========================================================
    private static String getZoomToken() {

        Zoom_Integration_Setting__mdt config = [
            SELECT Account_Id__c
            FROM Zoom_Integration_Setting__mdt
            WHERE DeveloperName = 'Zoom_Integration'
            LIMIT 1
        ];

        if (
            config == null ||
            String.isBlank(config.Account_Id__c)
        ) {
            throw new CalloutException(
                'Zoom Account ID is missing in Custom Metadata.'
            );
        }

        HttpRequest req = new HttpRequest();

        req.setEndpoint(
            'callout:Zoom_Token_Cred/oauth/token'
        );

        req.setMethod('POST');

        req.setHeader(
            'Content-Type',
            'application/x-www-form-urlencoded'
        );

        req.setTimeout(60000);

        req.setBody(
            'grant_type=account_credentials' +
            '&account_id=' +
            EncodingUtil.urlEncode(
                config.Account_Id__c.trim(),
                'UTF-8'
            )
        );

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {

            System.debug(
                LoggingLevel.ERROR,
                'Zoom Token Request Failed - HTTP ' +
                res.getStatusCode() +
                ': ' +
                res.getBody()
            );

            throw new CalloutException(
                'Unable to obtain Zoom access token. HTTP ' +
                res.getStatusCode()
            );
        }

        Map<String, Object> tokenResponse =
            (Map<String, Object>)
            JSON.deserializeUntyped(
                res.getBody()
            );

        String accessToken =
            (String) tokenResponse.get('access_token');

        if (String.isBlank(accessToken)) {
            throw new CalloutException(
                'Zoom access token was not returned.'
            );
        }

        return accessToken;
    }


    // =========================================================
    // Queueable Execute
    // =========================================================
    public void execute(QueueableContext ctx) {

        // Get fresh Zoom access token
        String zoomToken = getZoomToken();

        // ---------------------------------------------------------
        // Load Events
        // ---------------------------------------------------------
        List<Event> events = [
            SELECT Id,
                   Subject,
                   Description,
                   StartDateTime,
                   EndDateTime,
                   Zoom_Meeting__c,
                   Zoom_Meeting__r.Meeting_Id__c
            FROM Event
            WHERE Id IN :eventIds
        ];

        if (events.isEmpty()) {
            System.debug(
                LoggingLevel.ERROR,
                'ZoomMeetingCreator: No Event records found for given Ids.'
            );
            return;
        }

        // ---------------------------------------------------------
        // Records to Insert / Update
        // ---------------------------------------------------------
        List<Zoom_Meeting__c> meetingsToInsert =
            new List<Zoom_Meeting__c>();

        List<Zoom_Meeting__c> meetingsToUpdate =
            new List<Zoom_Meeting__c>();

        Map<Integer, Id> insertIndexToEventId =
            new Map<Integer, Id>();


        // =========================================================
        // Process Events
        // =========================================================
        for (Event ev : events) {

            try {

                if (
                    ev.StartDateTime == null ||
                    ev.EndDateTime == null
                ) {
                    System.debug(
                        LoggingLevel.ERROR,
                        'Skipping Event ' + ev.Id +
                        ' - missing StartDateTime/EndDateTime.'
                    );

                    continue;
                }

                Integer durationMinutes = (Integer)(
                    (
                        ev.EndDateTime.getTime() -
                        ev.StartDateTime.getTime()
                    ) / 60000
                );

                if (durationMinutes <= 0) {
                    durationMinutes = 30;
                }

                String topic =
                    String.isBlank(ev.Subject)
                    ? 'Salesforce Meeting'
                    : ev.Subject;

                String startTimeGmt =
                    ev.StartDateTime.formatGmt(
                        'yyyy-MM-dd\'T\'HH:mm:ss\'Z\''
                    );

                Boolean hasExistingMeeting =
                    ev.Zoom_Meeting__c != null &&
                    ev.Zoom_Meeting__r != null &&
                    !String.isBlank(
                        ev.Zoom_Meeting__r.Meeting_Id__c
                    );


                // =================================================
                // UPDATE EXISTING ZOOM MEETING
                // =================================================
                if (hasExistingMeeting) {

                    Map<String, Object> requestBody =
                        new Map<String, Object>();

                    requestBody.put('topic', topic);
                    requestBody.put('start_time', startTimeGmt);
                    requestBody.put('duration', durationMinutes);
                    requestBody.put('timezone', 'UTC');

                    HttpRequest req = new HttpRequest();

                    req.setEndpoint(
                        'callout:Zoom_Cred/v2/meetings/' +
                        EncodingUtil.urlEncode(
                            ev.Zoom_Meeting__r.Meeting_Id__c,
                            'UTF-8'
                        )
                    );

                    req.setMethod('PATCH');

                    req.setHeader(
                        'Content-Type',
                        'application/json'
                    );

                    req.setHeader(
                        'Authorization',
                        'Bearer ' + zoomToken
                    );

                    req.setTimeout(60000);

                    req.setBody(
                        JSON.serialize(requestBody)
                    );

                    HttpResponse res =
                        new Http().send(req);

                    if (res.getStatusCode() != 204) {

                        System.debug(
                            LoggingLevel.ERROR,
                            'Zoom Update Meeting failed for Event ' +
                            ev.Id +
                            ' - HTTP ' +
                            res.getStatusCode() +
                            ': ' +
                            res.getBody()
                        );

                        continue;
                    }

                    Zoom_Meeting__c existing =
                        new Zoom_Meeting__c(
                            Id = ev.Zoom_Meeting__c
                        );

                    existing.Topic__c = topic;
                    existing.Time__c = ev.StartDateTime;

                    meetingsToUpdate.add(existing);
                }


                // =================================================
                // CREATE NEW ZOOM MEETING
                // =================================================
                else {

                    Map<String, Object> requestBody =
                        new Map<String, Object>();

                    requestBody.put('topic', topic);
                    requestBody.put('type', 2);
                    requestBody.put('start_time', startTimeGmt);
                    requestBody.put('duration', durationMinutes);
                    requestBody.put('timezone', 'UTC');

                    Map<String, Object> settings =
                        new Map<String, Object>();

                    settings.put('join_before_host', true);
                    settings.put('waiting_room', false);

                    requestBody.put('settings', settings);

                    HttpRequest req = new HttpRequest();

                    req.setEndpoint(
                        'callout:Zoom_Cred/v2/users/me/meetings'
                    );

                    req.setMethod('POST');

                    req.setHeader(
                        'Content-Type',
                        'application/json'
                    );

                    req.setHeader(
                        'Authorization',
                        'Bearer ' + zoomToken
                    );

                    req.setTimeout(60000);

                    req.setBody(
                        JSON.serialize(requestBody)
                    );

                    HttpResponse res =
                        new Http().send(req);

                    if (
                        res.getStatusCode() != 201 &&
                        res.getStatusCode() != 200
                    ) {

                        System.debug(
                            LoggingLevel.ERROR,
                            'Zoom Create Meeting failed for Event ' +
                            ev.Id +
                            ' - HTTP ' +
                            res.getStatusCode() +
                            ': ' +
                            res.getBody()
                        );

                        continue;
                    }

                    Map<String, Object> m =
                        (Map<String, Object>)
                        JSON.deserializeUntyped(
                            res.getBody()
                        );

                    Zoom_Meeting__c zm =
                        new Zoom_Meeting__c();

                    if (m.get('id') != null) {
                        zm.Meeting_Id__c =
                            String.valueOf(m.get('id'));
                    }

                    if (m.get('uuid') != null) {
                        zm.Meeting_UUID__c =
                            (String)m.get('uuid');
                    }

                    if (m.get('topic') != null) {
                        zm.Topic__c =
                            (String)m.get('topic');
                    }

                    if (m.get('join_url') != null) {
                        zm.Invite_Link__c =
                            (String)m.get('join_url');
                    }

                    if (m.get('password') != null) {
                        zm.Passcode__c =
                            (String)m.get('password');
                    }

                    if (m.get('start_time') != null) {

                        String startTimeStr =
                            (String)m.get('start_time');

                        zm.Time__c =
                            (DateTime)JSON.deserialize(
                                '"' +
                                startTimeStr +
                                '"',
                                DateTime.class
                            );
                    }

                    meetingsToInsert.add(zm);

                    insertIndexToEventId.put(
                        meetingsToInsert.size() - 1,
                        ev.Id
                    );
                }

            } catch (Exception e) {

                System.debug(
                    LoggingLevel.ERROR,
                    'ZoomMeetingCreator failed for Event ' +
                    ev.Id +
                    ' - Line ' +
                    e.getLineNumber() +
                    ': ' +
                    e.getMessage()
                );
            }
        }


        // =========================================================
        // INSERT NEW ZOOM MEETING RECORDS
        // =========================================================
        if (!meetingsToInsert.isEmpty()) {
            insert meetingsToInsert;
        }


        // =========================================================
        // UPDATE EXISTING ZOOM MEETING RECORDS
        // =========================================================
        if (!meetingsToUpdate.isEmpty()) {
            update meetingsToUpdate;
        }


        // =========================================================
        // Link Event -> Zoom Meeting
        // =========================================================
        if (!meetingsToInsert.isEmpty()) {

            List<Event> eventsToUpdate =
                new List<Event>();

            for (
                Integer i = 0;
                i < meetingsToInsert.size();
                i++
            ) {

                Id relatedEventId =
                    insertIndexToEventId.get(i);

                Id newMeetingId =
                    meetingsToInsert[i].Id;

                if (
                    relatedEventId != null &&
                    newMeetingId != null
                ) {

                    eventsToUpdate.add(
                        new Event(
                            Id = relatedEventId,
                            Zoom_Meeting__c = newMeetingId
                        )
                    );
                }
            }

            if (!eventsToUpdate.isEmpty()) {
                update eventsToUpdate;
            }
        }
    }
}