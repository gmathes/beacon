import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Last updated: November 18, 2025")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("We respect your privacy. This app does not collect, store, or share any of your personal data, including your location data. All location processing is done on your device.")
                        .font(.body)

                    Text("Terms of Service")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 40)

                    Text("By using this app, you agree to the following terms and conditions. This app is provided 'as is' without any warranties. The developer is not liable for any damages or losses related to your use of the app. You are responsible for your own safety while using the app for navigation.")
                        .font(.body)
                }
                .padding()
            }
            .navigationTitle("Privacy & Terms")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
