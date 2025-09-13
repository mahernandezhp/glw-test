trigger GLW_OrderTrigger on GLW_Order__c (after insert, after update) {
    Set<Id> toProcess = new Set<Id>();
    if (Trigger.isInsert) {
        for (GLW_Order__c o : Trigger.new) if (o.GLW_Customer__c != null) toProcess.add(o.Id);
    } else if (Trigger.isUpdate) {
        for (Integer i = 0; i < Trigger.new.size(); i++) {
            GLW_Order__c n = Trigger.new[i];
            GLW_Order__c o = Trigger.old[i];
            if (n.GLW_Customer__c != null && (n.GLW_Customer__c != o.GLW_Customer__c)) {
                toProcess.add(n.Id);
            }
        }
    }
    if (!toProcess.isEmpty()) {
        GLW_OrderWeatherFuture.updateOrdersWeather(new List<Id>(toProcess));
    }
}

