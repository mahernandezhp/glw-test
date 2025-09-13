public with sharing class GLW_OrderController {
    @AuraEnabled(cacheable=true)
    public static List<GLW_Order__c> getOrders(Integer limitSize) {
        Integer lim = (limitSize == null || limitSize <= 0 || limitSize > 200) ? 50 : limitSize;
        return [
            SELECT Id, Name, CreatedDate,
                   GLW_OrderDate__c, GLW_Total__c, GLW_FlagOverdue__c,
                   GLW_WeatherDescription__c, GLW_WeatherTemperature__c, GLW_WeatherCity__c, GLW_WeatherLastUpdated__c,
                   GLW_Customer__c,
                   GLW_Customer__r.GLW_FirstName__c,
                   GLW_Customer__r.GLW_LastName__c,
                   GLW_Customer__r.GLW_City__c,
                   GLW_Customer__r.GLW_State__c,
                   GLW_Customer__r.GLW_Country__c
            FROM GLW_Order__c
            ORDER BY CreatedDate DESC
            LIMIT :lim
        ];
    }

    public class PageResult {
        @AuraEnabled public List<GLW_Order__c> records;
        @AuraEnabled public Integer total;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
    }

    public class OrderItemRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal total;
    }

    public class OrderDetail {
        @AuraEnabled public Id orderId;
        @AuraEnabled public String orderName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Date orderDate;
        @AuraEnabled public Decimal total;
        @AuraEnabled public Boolean overdue;
        @AuraEnabled public String weather;
        @AuraEnabled public Decimal weatherTemp;
        @AuraEnabled public String weatherCity;
        @AuraEnabled public Datetime weatherUpdated;
        @AuraEnabled public Id customerId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerFirstName;
        @AuraEnabled public String customerLastName;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;
        @AuraEnabled public List<OrderItemRow> items;
    }

    public class OrderItemsPage {
        @AuraEnabled public List<OrderItemRow> records;
        @AuraEnabled public Integer total;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
    }

    @AuraEnabled(cacheable=true)
    public static OrderDetail getOrderDetail(Id orderId) {
        if (orderId == null) return null;

        GLW_Order__c o = [
            SELECT Id, Name, CreatedDate,
                   GLW_OrderDate__c, GLW_Total__c, GLW_FlagOverdue__c,
                   GLW_WeatherDescription__c, GLW_WeatherTemperature__c, GLW_WeatherCity__c, GLW_WeatherLastUpdated__c,
                   GLW_Customer__c,
                   GLW_Customer__r.Name,
                   GLW_Customer__r.GLW_FirstName__c,
                   GLW_Customer__r.GLW_LastName__c,
                   GLW_Customer__r.GLW_Street__c,
                   GLW_Customer__r.GLW_City__c,
                   GLW_Customer__r.GLW_State__c,
                   GLW_Customer__r.GLW_PostalCode__c,
                   GLW_Customer__r.GLW_Country__c
            FROM GLW_Order__c
            WHERE Id = :orderId
            LIMIT 1
        ];

        List<GLW_OrderItem__c> items = [
            SELECT Id, GLW_Product__r.Name, GLW_Quantity__c, GLW_UnitPrice__c, GLW_Total__c
            FROM GLW_OrderItem__c
            WHERE GLW_Order__c = :orderId
            ORDER BY CreatedDate ASC
        ];

        OrderDetail d = new OrderDetail();
        d.orderId = o.Id;
        d.orderName = o.Name;
        d.createdDate = o.CreatedDate;
        d.orderDate = o.GLW_OrderDate__c;
        d.total = o.GLW_Total__c;
        d.overdue = o.GLW_FlagOverdue__c;
        d.weather = o.GLW_WeatherDescription__c;
        d.weatherTemp = o.GLW_WeatherTemperature__c;
        d.weatherCity = o.GLW_WeatherCity__c;
        d.weatherUpdated = o.GLW_WeatherLastUpdated__c;
        d.customerId = o.GLW_Customer__c;
        d.customerName = (o.GLW_Customer__r == null) ? null : o.GLW_Customer__r.Name;
        d.customerFirstName = (o.GLW_Customer__r == null) ? null : o.GLW_Customer__r.GLW_FirstName__c;
        d.customerLastName = (o.GLW_Customer__r == null) ? null : o.GLW_Customer__r.GLW_LastName__c;
        d.street = (o.GLW_Customer__r == null) ? null : o.GLW_Customer__r.GLW_Street__c;
        d.city = (o.GLW_Customer__r == null) ? null : o.GLW_Customer__r.GLW_City__c;
        d.state = (o.GLW_Customer__r == null) ? null : o.GLW_Customer__r.GLW_State__c;
        d.postalCode = (o.GLW_Customer__r == null) ? null : o.GLW_Customer__r.GLW_PostalCode__c;
        d.country = (o.GLW_Customer__r == null) ? null : o.GLW_Customer__r.GLW_Country__c;

        d.items = new List<OrderItemRow>();
        for (GLW_OrderItem__c it : items) {
            OrderItemRow r = new OrderItemRow();
            r.id = it.Id;
            r.productName = (it.GLW_Product__r == null) ? null : it.GLW_Product__r.Name;
            r.quantity = it.GLW_Quantity__c;
            r.unitPrice = it.GLW_UnitPrice__c;
            r.total = it.GLW_Total__c;
            d.items.add(r);
        }
        return d;
    }

    @AuraEnabled
    public static void requestOrderWeather(Id orderId) {
        if (orderId == null) return;
        // Enqueue async weather update using existing future method
        GLW_OrderWeatherFuture.updateOrdersWeather(new List<Id>{ orderId });
    }

    @AuraEnabled(cacheable=true)
    public static OrderItemsPage getOrderItemsPage(Id orderId, Integer pageSize, Integer pageNumber) {
        if (orderId == null) return null;
        Integer size = (pageSize == null || pageSize <= 0 || pageSize > 100) ? 10 : pageSize;
        Integer page = (pageNumber == null || pageNumber < 1) ? 1 : pageNumber;
        Integer offsetVal = (page - 1) * size;

        Integer totalRows = [SELECT COUNT() FROM GLW_OrderItem__c WHERE GLW_Order__c = :orderId];

        if (offsetVal > 2000) {
            offsetVal = 2000;
            page = (Integer) Math.floor(offsetVal / size) + 1;
        }

        List<GLW_OrderItem__c> items = [
            SELECT Id, GLW_Product__r.Name, GLW_Quantity__c, GLW_UnitPrice__c, GLW_Total__c
            FROM GLW_OrderItem__c
            WHERE GLW_Order__c = :orderId
            ORDER BY CreatedDate ASC
            LIMIT :size OFFSET :offsetVal
        ];

        OrderItemsPage pr = new OrderItemsPage();
        pr.records = new List<OrderItemRow>();
        for (GLW_OrderItem__c it : items) {
            OrderItemRow r = new OrderItemRow();
            r.id = it.Id;
            r.productName = (it.GLW_Product__r == null) ? null : it.GLW_Product__r.Name;
            r.quantity = it.GLW_Quantity__c;
            r.unitPrice = it.GLW_UnitPrice__c;
            r.total = it.GLW_Total__c;
            pr.records.add(r);
        }
        pr.total = totalRows;
        pr.pageNumber = page;
        pr.pageSize = size;
        return pr;
    }

    @AuraEnabled(cacheable=true)
    public static PageResult getOrderPage(Integer pageSize, Integer pageNumber, String searchTerm) {
        Integer size = (pageSize == null || pageSize <= 0 || pageSize > 100) ? 15 : pageSize;
        Integer page = (pageNumber == null || pageNumber < 1) ? 1 : pageNumber;
        Integer offsetVal = (page - 1) * size;

        // Build optional filter
        // Simple contains filter; bind variable prevents injection
        String term = String.isBlank(searchTerm) ? null : '%' + searchTerm + '%';

        // Total count
        Integer totalRows;
        if (term == null) {
            totalRows = [SELECT COUNT() FROM GLW_Order__c];
        } else {
            totalRows = [
                SELECT COUNT() FROM GLW_Order__c
                WHERE Name LIKE :term
                OR GLW_Customer__r.Name LIKE :term
                OR GLW_Customer__r.GLW_FirstName__c LIKE :term
                OR GLW_Customer__r.GLW_LastName__c LIKE :term
            ];
        }

        // Clamp offset within OFFSET limit (2000 rows)
        if (offsetVal > 2000) {
            offsetVal = 2000;
            page = (Integer) Math.floor(offsetVal / size) + 1;
        }

        List<GLW_Order__c> rows;
        if (term == null) {
            rows = [
                SELECT Id, Name, CreatedDate,
                       GLW_OrderDate__c, GLW_Total__c, GLW_FlagOverdue__c,
                       GLW_WeatherDescription__c, GLW_WeatherTemperature__c, GLW_WeatherCity__c, GLW_WeatherLastUpdated__c,
                       GLW_Customer__c,
                       GLW_Customer__r.Name,
                       GLW_Customer__r.GLW_FirstName__c,
                       GLW_Customer__r.GLW_LastName__c,
                       GLW_Customer__r.GLW_City__c,
                       GLW_Customer__r.GLW_State__c,
                       GLW_Customer__r.GLW_Country__c
                FROM GLW_Order__c
                ORDER BY CreatedDate DESC
                LIMIT :size OFFSET :offsetVal
            ];
        } else {
            rows = [
                SELECT Id, Name, CreatedDate,
                       GLW_OrderDate__c, GLW_Total__c, GLW_FlagOverdue__c,
                       GLW_WeatherDescription__c, GLW_WeatherTemperature__c, GLW_WeatherCity__c, GLW_WeatherLastUpdated__c,
                       GLW_Customer__c,
                       GLW_Customer__r.Name,
                       GLW_Customer__r.GLW_FirstName__c,
                       GLW_Customer__r.GLW_LastName__c,
                       GLW_Customer__r.GLW_City__c,
                       GLW_Customer__r.GLW_State__c,
                       GLW_Customer__r.GLW_Country__c
                FROM GLW_Order__c
                WHERE Name LIKE :term
                   OR GLW_Customer__r.Name LIKE :term
                   OR GLW_Customer__r.GLW_FirstName__c LIKE :term
                   OR GLW_Customer__r.GLW_LastName__c LIKE :term
                ORDER BY CreatedDate DESC
                LIMIT :size OFFSET :offsetVal
            ];
        }

        PageResult pr = new PageResult();
        pr.records = rows;
        pr.total = totalRows;
        pr.pageNumber = page;
        pr.pageSize = size;
        return pr;
    }
}
