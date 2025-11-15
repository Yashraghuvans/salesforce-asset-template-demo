/**
 * Controller for Asset Management Dashboard LWC
 * Provides aggregated data for charts and metrics
 */
public with sharing class AssetDashboardController {
    
    /**
     * Get asset counts grouped by status
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getAssetsByStatus() {
        Map<String, Integer> statusMap = new Map<String, Integer>();
        
        for (AggregateResult ar : [
            SELECT Status, COUNT(Id) cnt
            FROM Asset
            GROUP BY Status
        ]) {
            String status = (String) ar.get('Status');
            Integer count = (Integer) ar.get('cnt');
            statusMap.put(status != null ? status : 'Unknown', count);
        }
        
        return statusMap;
    }
    
    /**
     * Get asset counts grouped by criticality
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getAssetsByCriticality() {
        Map<String, Integer> criticalityMap = new Map<String, Integer>();
        
        for (AggregateResult ar : [
            SELECT Criticality__c, COUNT(Id) cnt
            FROM Asset
            GROUP BY Criticality__c
        ]) {
            String criticality = (String) ar.get('Criticality__c');
            Integer count = (Integer) ar.get('cnt');
            criticalityMap.put(criticality != null ? criticality : 'Not Set', count);
        }
        
        return criticalityMap;
    }
    
    /**
     * Get asset counts grouped by version status
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getAssetsByVersionStatus() {
        Map<String, Integer> versionMap = new Map<String, Integer>();
        
        for (AggregateResult ar : [
            SELECT Version_Status__c, COUNT(Id) cnt
            FROM Asset
            GROUP BY Version_Status__c
        ]) {
            String versionStatus = (String) ar.get('Version_Status__c');
            Integer count = (Integer) ar.get('cnt');
            versionMap.put(versionStatus != null ? versionStatus : 'Not Set', count);
        }
        
        return versionMap;
    }
    
    /**
     * Get asset counts grouped by maintenance status
     * Note: Since Maintenance_Status__c is a formula field, we calculate it manually
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getAssetsByMaintenanceStatus() {
        Map<String, Integer> maintenanceMap = new Map<String, Integer>{
            'Current' => 0,
            'Due Soon' => 0,
            'Overdue' => 0,
            'Not Set' => 0
        };
        
        // Query all active assets with maintenance fields
        List<Asset> assets = [
            SELECT Id, Next_Maintenance_Due__c, Maintenance_Interval_Days__c
            FROM Asset
            WHERE Status = 'Active'
        ];
        
        Date today = Date.today();
        
        for (Asset asset : assets) {
            String status = 'Not Set';
            
            if (asset.Next_Maintenance_Due__c != null) {
                Integer daysUntil = today.daysBetween(asset.Next_Maintenance_Due__c);
                
                if (daysUntil < 0) {
                    status = 'Overdue';
                } else if (daysUntil <= 7) {
                    status = 'Due Soon';
                } else {
                    status = 'Current';
                }
            }
            
            maintenanceMap.put(status, maintenanceMap.get(status) + 1);
        }
        
        return maintenanceMap;
    }
    
    /**
     * Get total asset value grouped by criticality
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getAssetValueByCriticality() {
        Map<String, Decimal> valueMap = new Map<String, Decimal>();
        
        for (AggregateResult ar : [
            SELECT Criticality__c, SUM(Purchase_Cost__c) totalValue
            FROM Asset
            WHERE Purchase_Cost__c != null
            GROUP BY Criticality__c
        ]) {
            String criticality = (String) ar.get('Criticality__c');
            Decimal value = (Decimal) ar.get('totalValue');
            valueMap.put(criticality != null ? criticality : 'Not Set', value);
        }
        
        return valueMap;
    }
    
    /**
     * Get key metrics for the dashboard
     */
    @AuraEnabled(cacheable=true)
    public static DashboardMetrics getDashboardMetrics() {
        DashboardMetrics metrics = new DashboardMetrics();
        
        // Total assets
        metrics.totalAssets = [SELECT COUNT() FROM Asset];
        
        // Active assets
        metrics.activeAssets = [SELECT COUNT() FROM Asset WHERE Status = 'Active'];
        
        // Overdue maintenance (calculate manually since it's a formula field)
        metrics.overdueAssets = [
            SELECT COUNT() 
            FROM Asset 
            WHERE Next_Maintenance_Due__c < TODAY AND Status = 'Active'
        ];
        
        // Critical assets
        metrics.criticalAssets = [
            SELECT COUNT() 
            FROM Asset 
            WHERE Criticality__c = 'Critical' AND Status = 'Active'
        ];
        
        // Total asset value
        AggregateResult ar = [
            SELECT SUM(Purchase_Cost__c) total 
            FROM Asset 
            WHERE Purchase_Cost__c != null
        ];
        metrics.totalValue = (Decimal) ar.get('total');
        if (metrics.totalValue == null) {
            metrics.totalValue = 0;
        }
        
        return metrics;
    }
    
    /**
     * Get maintenance status grouped by site (for stacked bar chart)
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Map<String, Integer>> getMaintenanceStatusBySite() {
        Map<String, Map<String, Integer>> siteMap = new Map<String, Map<String, Integer>>();
        
        List<Asset> assets = [
            SELECT Id, Site__r.Name, Next_Maintenance_Due__c
            FROM Asset
            WHERE Status = 'Active' AND Site__c != null
        ];
        
        Date today = Date.today();
        
        for (Asset asset : assets) {
            String siteName = asset.Site__r.Name;
            if (!siteMap.containsKey(siteName)) {
                siteMap.put(siteName, new Map<String, Integer>{
                    'Current' => 0,
                    'Due Soon' => 0,
                    'Overdue' => 0
                });
            }
            
            String status = 'Current';
            if (asset.Next_Maintenance_Due__c != null) {
                Integer daysUntil = today.daysBetween(asset.Next_Maintenance_Due__c);
                if (daysUntil < 0) {
                    status = 'Overdue';
                } else if (daysUntil <= 7) {
                    status = 'Due Soon';
                }
            }
            
            siteMap.get(siteName).put(status, siteMap.get(siteName).get(status) + 1);
        }
        
        return siteMap;
    }
    
    /**
     * Get asset counts grouped by condition
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getAssetsByCondition() {
        Map<String, Integer> conditionMap = new Map<String, Integer>();
        
        for (AggregateResult ar : [
            SELECT Condition__c, COUNT(Id) cnt
            FROM Asset
            WHERE Condition__c != null
            GROUP BY Condition__c
        ]) {
            String condition = (String) ar.get('Condition__c');
            Integer count = (Integer) ar.get('cnt');
            conditionMap.put(condition, count);
        }
        
        return conditionMap;
    }
    
    /**
     * Get top 10 most expensive assets
     */
    @AuraEnabled(cacheable=true)
    public static List<AssetValue> getTop10ExpensiveAssets() {
        List<AssetValue> assetValues = new List<AssetValue>();
        
        for (Asset asset : [
            SELECT Id, Name, Purchase_Cost__c
            FROM Asset
            WHERE Purchase_Cost__c != null
            ORDER BY Purchase_Cost__c DESC
            LIMIT 10
        ]) {
            AssetValue av = new AssetValue();
            av.id = asset.Id;
            av.name = asset.Name;
            av.value = asset.Purchase_Cost__c;
            assetValues.add(av);
        }
        
        return assetValues;
    }
    
    /**
     * Get assets needing maintenance schedule
     */
    @AuraEnabled(cacheable=true)
    public static List<MaintenanceAsset> getAssetsNeedingMaintenance() {
        List<MaintenanceAsset> maintenanceAssets = new List<MaintenanceAsset>();
        
        for (Asset asset : [
            SELECT Id, Name, Site__r.Name, Next_Maintenance_Due__c, Maintenance_Interval_Days__c
            FROM Asset
            WHERE Status = 'Active' 
            AND (Next_Maintenance_Due__c = null OR Next_Maintenance_Due__c <= NEXT_N_DAYS:30)
            ORDER BY Next_Maintenance_Due__c ASC NULLS FIRST
            LIMIT 10
        ]) {
            MaintenanceAsset ma = new MaintenanceAsset();
            ma.id = asset.Id;
            ma.name = asset.Name;
            ma.site = asset.Site__r != null ? asset.Site__r.Name : '';
            ma.nextMaintenanceDue = asset.Next_Maintenance_Due__c;
            ma.maintenanceInterval = asset.Maintenance_Interval_Days__c;
            
            if (asset.Next_Maintenance_Due__c != null) {
                Integer daysUntil = Date.today().daysBetween(asset.Next_Maintenance_Due__c);
                if (daysUntil < 0) {
                    ma.status = 'Overdue';
                } else if (daysUntil <= 7) {
                    ma.status = 'Due Soon';
                } else {
                    ma.status = 'Upcoming';
                }
            } else {
                ma.status = 'Not Scheduled';
            }
            
            maintenanceAssets.add(ma);
        }
        
        return maintenanceAssets;
    }
    
    /**
     * Get asset value by site (purchase cost vs current value)
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, SiteValue> getAssetValueBySite() {
        Map<String, SiteValue> siteValueMap = new Map<String, SiteValue>();
        
        // First get site IDs and their names
        Map<Id, String> siteIdToName = new Map<Id, String>();
        for (Schema.Location loc : [SELECT Id, Name FROM Location]) {
            siteIdToName.put(loc.Id, loc.Name);
        }
        
        for (AggregateResult ar : [
            SELECT Site__c, SUM(Purchase_Cost__c) purchaseCost, SUM(Current_Value__c) currentValue
            FROM Asset
            WHERE Site__c != null AND (Purchase_Cost__c != null OR Current_Value__c != null)
            GROUP BY Site__c
        ]) {
            Id siteId = (Id) ar.get('Site__c');
            String siteName = siteIdToName.get(siteId);
            
            if (siteName != null) {
                SiteValue sv = new SiteValue();
                sv.purchaseCost = (Decimal) ar.get('purchaseCost');
                sv.currentValue = (Decimal) ar.get('currentValue');
                if (sv.purchaseCost == null) sv.purchaseCost = 0;
                if (sv.currentValue == null) sv.currentValue = 0;
                siteValueMap.put(siteName, sv);
            }
        }
        
        return siteValueMap;
    }
    
    /**
     * Wrapper class for dashboard metrics
     */
    public class DashboardMetrics {
        @AuraEnabled public Integer totalAssets { get; set; }
        @AuraEnabled public Integer activeAssets { get; set; }
        @AuraEnabled public Integer overdueAssets { get; set; }
        @AuraEnabled public Integer criticalAssets { get; set; }
        @AuraEnabled public Decimal totalValue { get; set; }
    }
    
    /**
     * Wrapper class for asset value
     */
    public class AssetValue {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal value { get; set; }
    }
    
    /**
     * Wrapper class for maintenance asset
     */
    public class MaintenanceAsset {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String site { get; set; }
        @AuraEnabled public Date nextMaintenanceDue { get; set; }
        @AuraEnabled public Decimal maintenanceInterval { get; set; }
        @AuraEnabled public String status { get; set; }
    }
    
    /**
     * Wrapper class for site value
     */
    public class SiteValue {
        @AuraEnabled public Decimal purchaseCost { get; set; }
        @AuraEnabled public Decimal currentValue { get; set; }
    }
}
