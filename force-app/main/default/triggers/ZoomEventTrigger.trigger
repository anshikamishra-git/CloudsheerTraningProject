trigger ZoomEventTrigger on Event (after insert) {

    // Keep trigger thin - just collect the new Event Ids
    // and hand off to the handler class.
    if (Trigger.isAfter && Trigger.isInsert) {

        Set<Id> newEventIds = new Set<Id>();

        for (Event ev : Trigger.new) {
            newEventIds.add(ev.Id);
        }

        ZoomEventTriggerHandler.syncZoomMeetings(newEventIds);
    }
}