public class FillRecalcQueueable implements Queueable {
    private Integer currentDepth;
    private Integer maxDepth;
    private Boolean forceException;

    // Constructor with depth guard
    public FillRecalcQueueable(Integer currentDepth, Integer maxDepth, Boolean forceException) {
        this.currentDepth = currentDepth;
        this.maxDepth = maxDepth;
        this.forceException = forceException;
    }

    public void execute(QueueableContext context) {
        // Transaction Finalizer attach karo
        System.attachFinalizer(new QueueableFinalizer());

        System.debug('Executing FillRecalcQueueable at depth: ' + currentDepth);

        // Forced exception test case
        if (forceException) {
            throw new CustomException('Forced Uncaught Exception for Finalizer Demo');
        }

        // Chaining logic with Max-Depth Guard
        if (currentDepth < maxDepth) {
            System.debug('Chaining next job for depth: ' + (currentDepth + 1));
            System.enqueueJob(new FillRecalcQueueable(currentDepth + 1, maxDepth, false));
        } else {
            System.debug('Max depth reached (' + maxDepth + '). Stopping chain.');
        }
    }

    public class CustomException extends Exception {}
}