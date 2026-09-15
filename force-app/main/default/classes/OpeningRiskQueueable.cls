public class OpeningRiskQueueable implements Queueable {
    public void execute(QueueableContext context) {
        System.debug('Queueable Job Executed Successfully after Batch Completion.');
    }
}