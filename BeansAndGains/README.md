# Temporary Creator fetch test

This is a standalone test screen. It does not modify ContentView or RefreshSupplementRemindersIntent.

1. Add the five Swift files to the app target.
2. In CreatorConfiguration.swift, set your Client ID locally.
3. Ensure the Xcode URL Scheme is `com.ashwinppersonalteam.UntitledProject`.
4. Build and run.
5. Temporarily show `CreatorFetchTestView()` as the root view (for example, change `WindowGroup { ContentView() }` to `WindowGroup { CreatorFetchTestView() }`). Save a copy of the current MyApp.swift first. This does not edit ContentView or the reminder intent.
6. Tap Connect to Zoho & Fetch Records. Authorize the report.READ scope.
7. Share only the success/error text shown in the app. Redact record values or personal data before sharing.

This first test fetches up to 10 records from Daily_Supplement_Report and asks Creator to return only Date_Time. It intentionally does not apply date criteria yet; first verify OAuth, report endpoint, permission, and response structure. Do not share tokens or client secrets.
