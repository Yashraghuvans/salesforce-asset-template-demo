public class AssetTriggerHandler {
    
    public static void handleAfterUpdate(List<Asset> newAssets, Map<Id, Asset> oldAssetMap) {
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        
        // Get the email template
        EmailTemplate template = [
            SELECT Id, Subject, Body 
            FROM EmailTemplate 
            WHERE DeveloperName = 'Asset_Overdue_Maintenance_Alert' 
            LIMIT 1
        ];
        
        // Get OrgWideEmailAddress if configured
        List<OrgWideEmailAddress> orgWideAddresses = [
            SELECT Id, Address 
            FROM OrgWideEmailAddress 
            WHERE Address LIKE '%maintenance%' OR Address LIKE '%asset%'
            LIMIT 1
        ];
        
        for (Asset newAsset : newAssets) {
            Asset oldAsset = oldAssetMap.get(newAsset.Id);
            
            // Check if Maintenance_Status__c just changed to 'Overdue'
            if (newAsset.Maintenance_Status__c == 'Overdue' && 
                oldAsset.Maintenance_Status__c != 'Overdue') {
                
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                
                // Set the template
                email.setTemplateId(template.Id);
                
                // Set the target object (recipient) - Asset Owner
                email.setTargetObjectId(newAsset.OwnerId);
                
                // Set the What ID (Asset record for merge fields)
                email.setWhatId(newAsset.Id);
                
                // Add additional recipients (maintenance team)
                email.setToAddresses(new List<String>{'maintenance-team@company.com'});
                
                // Set org-wide email address if available
                if (!orgWideAddresses.isEmpty()) {
                    email.setOrgWideEmailAddressId(orgWideAddresses[0].Id);
                }
                
                // Save as activity on the Asset record
                email.setSaveAsActivity(true);
                
                // Add to list for bulk send
                emailsToSend.add(email);
            }
        }
        
        // Send all emails in bulk (outside the loop)
        if (!emailsToSend.isEmpty()) {
            try {
                Messaging.sendEmail(emailsToSend);
                System.debug('Successfully sent ' + emailsToSend.size() + ' overdue maintenance alerts.');
            } catch (Exception e) {
                System.debug('Error sending emails: ' + e.getMessage());
            }
        }
    }
}
