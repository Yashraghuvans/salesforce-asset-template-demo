// Create Location records for telecom sites
List<String> siteNames = new List<String>{
    'New York Metro Hub',
    'Los Angeles Data Center',
    'Chicago Network Operations',
    'Dallas Switching Station',
    'Miami Coastal Hub',
    'Seattle Pacific Gateway',
    'Boston Northeast Hub',
    'Atlanta Southeast Hub',
    'Denver Mountain Hub',
    'Phoenix Southwest Hub',
    'San Francisco Bay Hub',
    'Houston Gulf Hub'
};

// Check if locations already exist
Map<String, Id> locationMap = new Map<String, Id>();
List<Schema.Location> existingLocations = [SELECT Id, Name FROM Location WHERE Name IN :siteNames];
for (Schema.Location loc : existingLocations) {
    locationMap.put(loc.Name, loc.Id);
}

// Create missing locations
List<Schema.Location> locationsToInsert = new List<Schema.Location>();
for (String siteName : siteNames) {
    if (!locationMap.containsKey(siteName)) {
        Schema.Location loc = new Schema.Location(
            Name = siteName,
            LocationType = 'Site'
        );
        locationsToInsert.add(loc);
    }
}

if (!locationsToInsert.isEmpty()) {
    insert locationsToInsert;
    System.debug('Created ' + locationsToInsert.size() + ' new locations');
    
    // Add newly created locations to map
    for (Schema.Location loc : locationsToInsert) {
        locationMap.put(loc.Name, loc.Id);
    }
}

// Update assets with site information
List<Asset> assets = [SELECT Id, Name, Site__c FROM Asset WHERE Site__c = null LIMIT 1000];
System.debug('Found ' + assets.size() + ' assets without site');

Integer siteIndex = 0;
List<Id> locationIds = new List<Id>(locationMap.values());

for (Asset asset : assets) {
    asset.Site__c = locationIds[Math.mod(siteIndex, locationIds.size())];
    siteIndex++;
}

try {
    update assets;
    System.debug('Successfully updated ' + assets.size() + ' assets with site information');
} catch (Exception e) {
    System.debug('Error updating assets: ' + e.getMessage());
}
