public class ZoomEventTriggerHandler {

    // ---------------------------------------------------------
    // Recursion guard.
    // Prevents this trigger's logic from enqueueing duplicate
    // Queueable jobs if something else in the SAME transaction
    // (a workflow, a process, another trigger, or this class
    // itself being called again) causes Event DML to happen
    // more than once before the transaction commits.
    // A static variable resets automatically for every new
    // transaction, so it never blocks legitimate future updates.
    // ---------------------------------------------------------
    private static Boolean alreadyProcessedInThisTransaction = false;

    // Called from ZoomEventTrigger.
    public static void syncZoomMeetings(Set<Id> eventIds) {

        if (eventIds == null || eventIds.isEmpty()) {
            return;
        }

        if (alreadyProcessedInThisTransaction) {
            System.debug(
                'ZoomEventTriggerHandler: already enqueued a sync job in this transaction, skipping to avoid recursion.'
            );
            return;
        }

        alreadyProcessedInThisTransaction = true;

        // We cannot make a callout directly here (we're inside a
        // trigger, which is itself inside a DML transaction), so we
        // hand off to a Queueable, exactly like ZoomWebhookReceiver
        // does for ZoomMeetingDetails.
        System.enqueueJob(new ZoomMeetingCreator(eventIds));
    }
}