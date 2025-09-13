public with sharing class GLW_OrderWeatherFuture {
    // Guard checked by GLW_OrderTrigger to avoid async re-entry
    public static Boolean skipTrigger = false;
    @future(callout=true)
    public static void updateOrdersWeather(List<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) return;

        List<GLW_Order__c> orders = [
            SELECT Id,
                   GLW_Customer__c,
                   GLW_Customer__r.GLW_Street__c,
                   GLW_Customer__r.GLW_City__c,
                   GLW_Customer__r.GLW_State__c,
                   GLW_Customer__r.GLW_PostalCode__c,
                   GLW_Customer__r.GLW_Country__c
            FROM GLW_Order__c
            WHERE Id IN :orderIds
        ];

        // Cache per unique address to reduce callouts and stay within limits
        Map<String, GLW_WeatherService.WeatherInfo> cacheByAddress = new Map<String, GLW_WeatherService.WeatherInfo>();
        List<GLW_Order__c> toUpdate = new List<GLW_Order__c>();
        for (GLW_Order__c o : orders) {
            String address = GLW_WeatherService.buildAddress(o.GLW_Customer__r);
            if (String.isBlank(address)) {
                continue;
            }
            GLW_WeatherService.WeatherInfo info;
            if (cacheByAddress.containsKey(address)) {
                info = cacheByAddress.get(address);
            } else {
                if (Limits.getCallouts() + 1 > Limits.getLimitCallouts()) {
                    System.debug(LoggingLevel.WARN, 'OpenWeather callout limit reached in future; remaining orders skipped.');
                    break;
                }
                info = GLW_WeatherService.fetchWeatherByAddress(address);
                cacheByAddress.put(address, info);
            }
            if (info != null) {
                GLW_Order__c upd = new GLW_Order__c(
                    Id = o.Id
                );
                // The following fields should exist on GLW_Order__c
                if (Schema.sObjectType.GLW_Order__c.fields.getMap().containsKey('GLW_WeatherDescription__c')) {
                    upd.put('GLW_WeatherDescription__c', info.description);
                }
                if (Schema.sObjectType.GLW_Order__c.fields.getMap().containsKey('GLW_WeatherTemperature__c')) {
                    upd.put('GLW_WeatherTemperature__c', info.temperatureC);
                }
                if (Schema.sObjectType.GLW_Order__c.fields.getMap().containsKey('GLW_WeatherCity__c')) {
                    upd.put('GLW_WeatherCity__c', info.city);
                }
                if (Schema.sObjectType.GLW_Order__c.fields.getMap().containsKey('GLW_WeatherLastUpdated__c')) {
                    upd.put('GLW_WeatherLastUpdated__c', System.now());
                }
                toUpdate.add(upd);
            }
        }

        if (!toUpdate.isEmpty()) {
            try {
                skipTrigger = true;
                update toUpdate;
            } finally {
                skipTrigger = false;
            }
        }
    }
}
