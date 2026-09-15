public class NightlyHiringScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        // Check for in-flight running/queued jobs to prevent overlap
        List<AsyncApexJob> inFlightJobs = [
            SELECT Id, Status, ApexClass.Name 
            FROM AsyncApexJob 
            WHERE ApexClass.Name = 'FillRecalcQueueable' 
            AND Status IN ('Queued', 'Processing', 'Preparing')
        ];

        if (!inFlightJobs.isEmpty()) {
            System.debug('SKIP: Previous FillRecalcQueueable run is still in-flight. Skipping execution.');
            return;
        }

        // Agar koi run in-flight nahi hai, toh Queueable job enqueue karo
        System.enqueueJob(new FillRecalcQueueable(1, 3, false));
        System.debug('Enqueued FillRecalcQueueable successfully.');
    }
}