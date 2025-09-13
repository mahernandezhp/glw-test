trigger GLW_OrderTrigger on GLW_Order__c (after insert, after update) {
    // Prevent async re-entry from our own future DML
    if (GLW_OrderWeatherFuture.skipTrigger) {
        return;
    }

    Set<Id> toProcess = new Set<Id>();

    for (GLW_Order__c o : Trigger.new) if (o.GLW_Customer__c != null) toProcess.add(o.Id);
    

    if (!toProcess.isEmpty()) {
        // Chunk to avoid exceeding callout limits in a single future
        List<Id> batch = new List<Id>();
        Integer CHUNK_SIZE = 50; // stay well under 100 callout limit
        for (Id oid : toProcess) {
            batch.add(oid);
            if (batch.size() == CHUNK_SIZE) {
                GLW_OrderWeatherFuture.updateOrdersWeather(batch);
                batch = new List<Id>();
            }
        }
        if (!batch.isEmpty()) {
            GLW_OrderWeatherFuture.updateOrdersWeather(batch);
        }
    }
}
