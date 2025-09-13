public with sharing class GLW_OrderItemTriggerHandler {
    // Guard to avoid redundant rollups in rare re-entrancy scenarios
    private static Boolean isRollingUp = false;

    // BEFORE: No-op because GLW_Total__c is a formula
    public static void handleBefore(List<GLW_OrderItem__c> newList, Map<Id, GLW_OrderItem__c> oldMap) {
        // Intentionally left blank. When GLW_Total__c is a formula, it is read-only
        // and computed by the platform based on GLW_Quantity__c and GLW_UnitPrice__c.
    }

    // AFTER: Roll up totals to parent Order on DML changes
    public static void handleAfterInsert(List<GLW_OrderItem__c> newList) {
        rollupToOrders(collectOrderIds(newList, null));
    }

    public static void handleAfterUpdate(Map<Id, GLW_OrderItem__c> newMap, Map<Id, GLW_OrderItem__c> oldMap) {
        // Only roll up for records where relevant fields or parent changed
        Set<Id> orderIds = new Set<Id>();
        for (Id id : newMap.keySet()) {
            GLW_OrderItem__c n = newMap.get(id);
            GLW_OrderItem__c o = oldMap.get(id);
            if (n == null || o == null) continue;
            if (n.GLW_Order__c != o.GLW_Order__c
                || n.GLW_Quantity__c != o.GLW_Quantity__c
                || n.GLW_UnitPrice__c != o.GLW_UnitPrice__c) {
                if (n.GLW_Order__c != null) orderIds.add(n.GLW_Order__c);
                if (o.GLW_Order__c != null) orderIds.add(o.GLW_Order__c);
            }
        }
        rollupToOrders(orderIds);
    }

    public static void handleAfterDelete(List<GLW_OrderItem__c> oldList) {
        rollupToOrders(collectOrderIds(null, oldList));
    }

    public static void handleAfterUndelete(List<GLW_OrderItem__c> newList) {
        rollupToOrders(collectOrderIds(newList, null));
    }

    // Helper: collect unique parent Order Ids from new/old lists
    private static Set<Id> collectOrderIds(List<GLW_OrderItem__c> newList, List<GLW_OrderItem__c> oldList) {
        Set<Id> orderIds = new Set<Id>();
        if (newList != null) {
            for (GLW_OrderItem__c r : newList) if (r.GLW_Order__c != null) orderIds.add(r.GLW_Order__c);
        }
        if (oldList != null) {
            for (GLW_OrderItem__c r : oldList) if (r.GLW_Order__c != null) orderIds.add(r.GLW_Order__c);
        }
        return orderIds;
    }

    // Perform aggregate rollup and update parent Orders' total
    public static void rollupToOrders(Set<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) return;
        if (isRollingUp) return; // prevent accidental re-entrancy
        isRollingUp = true;
        try {
            // Initialize totals with 0 for all affected orders
            Map<Id, Decimal> totalsByOrder = new Map<Id, Decimal>();
            for (Id oid : orderIds) totalsByOrder.put(oid, 0);

            // Aggregate sum of item totals per order
            for (AggregateResult ar : [
                SELECT GLW_Order__c oid, SUM(GLW_Total__c) sumTotal
                FROM GLW_OrderItem__c
                WHERE GLW_Order__c IN :orderIds
                GROUP BY GLW_Order__c
            ]) {
                Id oid = (Id) ar.get('oid');
                Decimal sumTotal = (Decimal) ar.get('sumTotal');
                totalsByOrder.put(oid, sumTotal == null ? 0 : sumTotal);
            }

            // Update parent Orders with new totals, only if field is updateable
            Boolean canUpdateOrderTotal = Schema.sObjectType.GLW_Order__c.fields.GLW_Total__c.isUpdateable();
            if (canUpdateOrderTotal) {
                List<GLW_Order__c> ordersToUpdate = new List<GLW_Order__c>();
                for (Id oid : totalsByOrder.keySet()) {
                    ordersToUpdate.add(new GLW_Order__c(
                        Id = oid,
                        GLW_Total__c = totalsByOrder.get(oid)
                    ));
                }
                if (!ordersToUpdate.isEmpty()) {
                    update ordersToUpdate;
                }
            }
        } finally {
            isRollingUp = false;
        }
    }
}
