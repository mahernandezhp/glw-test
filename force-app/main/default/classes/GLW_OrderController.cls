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
