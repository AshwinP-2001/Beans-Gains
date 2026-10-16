import Foundation

enum CreatorConfiguration {
    static let clientID = "1000.J3WSWHYKG0Z8CP43RJMKPZJ6EB62RG"
    static let accountsBaseURL = URL(string: "https://accounts.zoho.com")!
    static let apiBaseURL = URL(string: "https://www.zohoapis.com")!
    static let accountOwner = "ashwinpaulrajt0_zohotest"
    static let appLinkName = "supplement-tracker"
    static let reportLinkName = "Daily_Supplement_Report"
    
    // Change this if your actual form link name in Zoho Creator is different
    static let formLinkName = "Daily_Supplement"
    
    static let redirectURI = "com.ashwinppersonalteam.UntitledProject://oauth"
    
    // Updated scope to allow both reading reports and creating form records
    static let requestedScopes = "ZohoCreator.report.READ ZohoCreator.form.CREATE"
    
    static let dateTimeField = "Date_Time"
}
