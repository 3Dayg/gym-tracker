import SwiftUI

/// On-device privacy policy. Gym Tracker never sends data off the phone.
struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section {
                Text("Gym Tracker does not use an account, iCloud, or the internet. Nothing you log is uploaded, sold, or shared.")
            }

            Section("What stays on this iPhone") {
                Text("Workouts, plans, custom exercises, units, rest-timer preference, and optional height and body weight. Deleting the app or using Delete All Data in Profile deletes this data. Export a JSON or CSV backup from Profile if you want a copy.")
            }

            Section("Notifications") {
                Text("If you allow notifications, they only fire on this iPhone when a work round or rest period ends. They are not sent to a server.")
            }

            Section("What we do not collect") {
                Text("No location, contacts, photos, Health app access, analytics, advertising identifiers, or crash reports.")
            }

            Section("Your choices") {
                Text("Height and body weight are optional. You can skip them on first launch and add or remove them later in Profile. You can export a JSON or CSV backup, or delete all data, from Profile. You can turn off notifications in iOS Settings.")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("privacyPolicyScreen")
    }
}
