trigger GLW_OrderItemTrigger on GLW_OrderItem__c (
    before insert,
    before update,
    after insert,
    after update,
    after delete,
    after undelete
) {
    // Delegate to handler to keep trigger logic lean and testable
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            GLW_OrderItemTriggerHandler.handleBefore(Trigger.new, Trigger.oldMap);
        }
    }
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            GLW_OrderItemTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            GLW_OrderItemTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            GLW_OrderItemTriggerHandler.handleAfterDelete(Trigger.old);
        } else if (Trigger.isUndelete) {
            GLW_OrderItemTriggerHandler.handleAfterUndelete(Trigger.new);
        }
    }
}

