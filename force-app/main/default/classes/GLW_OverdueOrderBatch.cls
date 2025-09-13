public with sharing class GLW_OverdueOrderBatch implements Database.Batchable<SObject> {
    public static final Integer DEFAULT_SCOPE_SIZE = 200;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Only select records that actually need a change to minimize DML
        String soql = 'SELECT Id, GLW_OrderDate__c, GLW_FlagOverdue__c ' +
            'FROM GLW_Order__c ' +
            'WHERE GLW_OrderDate__c != NULL ' +
            'AND ( (GLW_OrderDate__c < TODAY AND (GLW_FlagOverdue__c = FALSE OR GLW_FlagOverdue__c = NULL)) )' +
            '   OR (GLW_OrderDate__c >= TODAY AND GLW_FlagOverdue__c = TRUE) )';
        return Database.getQueryLocator(soql);
    }

    public void execute(Database.BatchableContext bc, List<GLW_Order__c> scope) {
        if (scope == null || scope.isEmpty()) return;
        List<GLW_Order__c> toUpdate = new List<GLW_Order__c>();
        Date today = Date.today();
        for (GLW_Order__c o : scope) {
            Boolean overdue = (o.GLW_OrderDate__c != null && o.GLW_OrderDate__c < today);
            if (o.GLW_FlagOverdue__c != overdue) {
                toUpdate.add(new GLW_Order__c(Id = o.Id, GLW_FlagOverdue__c = overdue));
            }
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {
    }

    // Helper to execute immediately with default scope size
    public static Id runNow(Integer scopeSize) {
        Integer size = (scopeSize == null || scopeSize <= 0) ? DEFAULT_SCOPE_SIZE : scopeSize;
        return Database.executeBatch(new GLW_OverdueOrderBatch(), size);
    }
}

