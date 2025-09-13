global with sharing class GLW_OverdueOrderScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Kick off the batch with a reasonable scope size
        Database.executeBatch(new GLW_OverdueOrderBatch(), GLW_OverdueOrderBatch.DEFAULT_SCOPE_SIZE);
    }

    // Convenience: returns a cron expression for a daily run at given hour/minute (org time)
    public static String dailyCron(Integer hour24, Integer minute) {
        Integer h = Math.max(0, Math.min(23, hour24 == null ? 2 : hour24));
        Integer m = Math.max(0, Math.min(59, minute == null ? 0 : minute));
        return String.format('0 {0} {1} * * ? *', new List<Object>{ m, h });
    }

    // Example helper to schedule programmatically
    public static void scheduleDaily(String jobName, Integer hour24, Integer minute) {
        System.schedule(jobName, dailyCron(hour24, minute), new GLW_OverdueOrderScheduler());
    }
}

