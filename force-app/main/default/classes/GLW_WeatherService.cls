public with sharing class GLW_WeatherService {
    public class WeatherInfo {
        public String description;
        public Decimal temperatureC;
        public String city;
        public String country;
    }

    // Customize these as needed
    private static final String NAMED_CREDENTIAL = 'OpenWeather';

    // Builds a single-line address string from GLW_Customer__c address parts
    public static String buildAddress(GLW_Customer__c cust) {
        if (cust == null) return null;
        List<String> parts = new List<String>();
        if (!String.isBlank(cust.GLW_Street__c)) parts.add(cust.GLW_Street__c.trim());
        List<String> cityStatePostal = new List<String>();
        if (!String.isBlank(cust.GLW_City__c)) cityStatePostal.add(cust.GLW_City__c.trim());
        // Combine state and postal together when both present
        List<String> statePostal = new List<String>();
        if (!String.isBlank(cust.GLW_State__c)) statePostal.add(cust.GLW_State__c.trim());
        if (!String.isBlank(cust.GLW_PostalCode__c)) statePostal.add(cust.GLW_PostalCode__c.trim());
        if (!statePostal.isEmpty()) cityStatePostal.add(String.join(statePostal, ' '));
        if (!cityStatePostal.isEmpty()) parts.add(String.join(cityStatePostal, ', '));
        if (!String.isBlank(cust.GLW_Country__c)) parts.add(cust.GLW_Country__c.trim());
        return parts.isEmpty() ? null : String.join(parts, ', ');
    }

    @TestVisible
    static String buildEndpoint(String address, String apiKey, String units) {
        String encoded = EncodingUtil.urlEncode(address == null ? '' : address, 'UTF-8');
        String u = String.isBlank(units) ? 'metric' : units;
        // Using Named Credential for the host
        return 'callout:' + NAMED_CREDENTIAL + '/data/2.5/weather?q=' + encoded + '&appid=' + apiKey + '&units=' + u;
    }

    public static WeatherInfo fetchWeatherByAddress(String address) {
        if (String.isBlank(address)) {
            return null;
        }
        String apiKey = System.Label.GLW_OpenWeatherApiKey;
        if (String.isBlank(apiKey)) {
            // No API key configured; skip callout
            return null;
        }
        String endpoint = buildEndpoint(address, apiKey, 'metric');

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);
        req.setTimeout(15000);
        req.setHeader('Accept', 'application/json');
        req.setHeader('User-Agent', 'GLW-WeatherService/1.0 (Salesforce Apex)');

        Http http = new Http();
        HTTPResponse res = http.send(req);

        if (res == null) return null;
        Integer status = res.getStatusCode();
        if (status == 200) {
            return parseWeather(res.getBody());
        } else {
            // Optionally log non-200 responses for troubleshooting
            System.debug(LoggingLevel.WARN, 'OpenWeather call failed: ' + status + ' body=' + res.getBody());
            return null;
        }
    }

    @TestVisible
    static WeatherInfo parseWeather(String body) {
        if (String.isBlank(body)) return null;
        try {
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(body);
            WeatherInfo info = new WeatherInfo();
            if (m.containsKey('weather')) {
                List<Object> w = (List<Object>) m.get('weather');
                if (!w.isEmpty()) {
                    Map<String, Object> w0 = (Map<String, Object>) w[0];
                    info.description = (String) w0.get('description');
                }
            }
            if (m.containsKey('main')) {
                Map<String, Object> main = (Map<String, Object>) m.get('main');
                Object t = main.get('temp');
                if (t instanceof Decimal) info.temperatureC = (Decimal) t;
                else if (t instanceof Integer) info.temperatureC = Decimal.valueOf((Integer) t);
                else if (t != null) info.temperatureC = Decimal.valueOf(String.valueOf(t));
            }
            info.city = (String) m.get('name');
            if (m.containsKey('sys')) {
                Map<String, Object> sys = (Map<String, Object>) m.get('sys');
                info.country = (String) sys.get('country');
            }
            return info;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to parse OpenWeather JSON: ' + e.getMessage());
            return null;
        }
    }
}
