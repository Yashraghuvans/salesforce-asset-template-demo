public class DailyOverdueDigest implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        sendDailyDigest();
    }
    
    public static void sendDailyDigest() {
        // Query all overdue assets
        List<Asset> overdueAssets = [
            SELECT Id, Name, SerialNumber, Maintenance_Status__c, 
                   Criticality__c, Days_Until_Maintenance__c, 
                   Next_Maintenance_Due__c, Last_Maintenance_Date__c,
                   Site__c, Owner.Name, Owner.Email
            FROM Asset
            WHERE Status = 'Active' 
            AND Maintenance_Status__c = 'Overdue'
            ORDER BY Criticality__c DESC NULLS LAST, Days_Until_Maintenance__c ASC
            LIMIT 1000
        ];
        
        if (overdueAssets.isEmpty()) {
            System.debug('No overdue assets found. Skipping daily digest.');
            return;
        }
        
        // Count critical assets
        Integer criticalCount = 0;
        for (Asset a : overdueAssets) {
            if (a.Criticality__c == 'Critical' || a.Criticality__c == 'High') {
                criticalCount++;
            }
        }
        
        // Build HTML email body
        String emailBody = buildDigestEmailBody(overdueAssets, criticalCount);
        
        // Send email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{'maintenance-manager@company.com'});
        email.setSubject('Daily Overdue Maintenance Digest - ' + Date.today().format());
        email.setHtmlBody(emailBody);
        
        // Set org-wide email address if available
        List<OrgWideEmailAddress> orgWideAddresses = [
            SELECT Id FROM OrgWideEmailAddress 
            WHERE Address LIKE '%maintenance%' OR Address LIKE '%asset%'
            LIMIT 1
        ];
        if (!orgWideAddresses.isEmpty()) {
            email.setOrgWideEmailAddressId(orgWideAddresses[0].Id);
        }
        
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
            System.debug('Daily overdue digest sent successfully.');
        } catch (Exception e) {
            System.debug('Error sending daily digest: ' + e.getMessage());
        }
    }
    
    private static String buildDigestEmailBody(List<Asset> overdueAssets, Integer criticalCount) {
        String orgUrl = URL.getOrgDomainUrl().toExternalForm();
        String listViewUrl = orgUrl + '/lightning/o/Asset/list?filterName=Overdue_Maintenance';
        
        String html = '<!DOCTYPE html><html><head><style>';
        html += 'body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }';
        html += '.container { max-width: 800px; margin: 0 auto; padding: 20px; }';
        html += '.header { background-color: #0070d2; color: white; padding: 20px; text-align: center; }';
        html += '.summary { background-color: #f4f6f9; padding: 20px; margin: 20px 0; border-radius: 5px; }';
        html += '.stat-box { display: inline-block; background: white; padding: 15px 30px; margin: 10px; border-radius: 5px; text-align: center; }';
        html += '.stat-number { font-size: 32px; font-weight: bold; color: #d9534f; }';
        html += '.stat-label { font-size: 14px; color: #666; }';
        html += 'table { width: 100%; border-collapse: collapse; margin: 20px 0; background: white; }';
        html += 'th { background-color: #0070d2; color: white; padding: 12px; text-align: left; }';
        html += 'td { padding: 10px; border-bottom: 1px solid #ddd; }';
        html += 'tr:hover { background-color: #f5f5f5; }';
        html += '.critical { color: #d9534f; font-weight: bold; }';
        html += '.button { display: inline-block; padding: 12px 24px; background-color: #0070d2; color: white; text-decoration: none; border-radius: 4px; margin: 15px 0; }';
        html += '.footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }';
        html += '</style></head><body>';
        
        html += '<div class="container">';
        html += '<div class="header"><h1>📊 Daily Overdue Maintenance Report</h1>';
        html += '<p>' + Date.today().format() + '</p></div>';
        
        html += '<div class="summary">';
        html += '<div class="stat-box"><div class="stat-number">' + overdueAssets.size() + '</div>';
        html += '<div class="stat-label">Total Overdue</div></div>';
        html += '<div class="stat-box"><div class="stat-number">' + criticalCount + '</div>';
        html += '<div class="stat-label">Critical/High Priority</div></div>';
        html += '</div>';
        
        html += '<h2>Top Overdue Assets</h2>';
        html += '<table><thead><tr>';
        html += '<th>Asset Name</th><th>Serial Number</th><th>Criticality</th>';
        html += '<th>Days Overdue</th><th>Site</th><th>Owner</th>';
        html += '</tr></thead><tbody>';
        
        Integer displayCount = Math.min(overdueAssets.size(), 20);
        for (Integer i = 0; i < displayCount; i++) {
            Asset a = overdueAssets[i];
            String criticalityClass = (a.Criticality__c == 'Critical' || a.Criticality__c == 'High') ? ' class="critical"' : '';
            html += '<tr>';
            html += '<td><a href="' + orgUrl + '/' + a.Id + '">' + a.Name + '</a></td>';
            html += '<td>' + (a.SerialNumber != null ? a.SerialNumber : '') + '</td>';
            html += '<td' + criticalityClass + '>' + (a.Criticality__c != null ? a.Criticality__c : '') + '</td>';
            html += '<td>' + (a.Days_Until_Maintenance__c != null ? String.valueOf(Math.abs(a.Days_Until_Maintenance__c.intValue())) : '') + '</td>';
            html += '<td>' + (a.Site__c != null ? a.Site__c : '') + '</td>';
            html += '<td>' + (a.Owner.Name != null ? a.Owner.Name : '') + '</td>';
            html += '</tr>';
        }
        
        html += '</tbody></table>';
        
        if (overdueAssets.size() > displayCount) {
            html += '<p><em>Showing top ' + displayCount + ' of ' + overdueAssets.size() + ' overdue assets.</em></p>';
        }
        
        html += '<p style="text-align: center;">';
        html += '<a href="' + listViewUrl + '" class="button">View All Overdue Assets</a>';
        html += '</p>';
        
        html += '<div class="footer">';
        html += '<p>This is an automated daily digest from the Asset Management System.</p>';
        html += '<p>Generated on ' + Datetime.now().format('yyyy-MM-dd HH:mm:ss') + '</p>';
        html += '</div>';
        
        html += '</div></body></html>';
        
        return html;
    }
}
