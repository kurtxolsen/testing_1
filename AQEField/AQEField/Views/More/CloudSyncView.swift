import SwiftUI

/// Cloud Sync settings: paste the Supabase project URL + anon key once,
/// create/sign in to an account, then sync manually or let the app sync on
/// launch. The app works 100% offline without any of this.
struct CloudSyncView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var sync
    @State private var password = ""
    @State private var emailDraft = ""

    var body: some View {
        @Bindable var sync = sync
        Form {
            Section {
                Text("Backs up your knocks, leads, intel, and storms — and pulls in teammates on the same project for the live leaderboard.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Supabase Project") {
                TextField("Project URL (https://xyz.supabase.co)", text: $sync.config.urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Anon (public) key", text: $sync.config.anonKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if sync.isSignedIn {
                Section("Account") {
                    LabeledContent("Signed in", value: sync.config.email)
                    Button("Sync Now") {
                        Task { await sync.syncNow(store: store) }
                    }
                    .disabled(sync.isSyncing)
                    if sync.isSyncing { ProgressView() }
                    if let lastSyncAt = sync.lastSyncAt {
                        LabeledContent("Last sync",
                                       value: lastSyncAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    Button("Sign Out", role: .destructive) { sync.signOut() }
                }
            } else {
                Section("Account") {
                    TextField("Email", text: $emailDraft)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                    HStack {
                        Button("Sign In") {
                            Task {
                                await sync.signIn(email: emailDraft, password: password)
                                await sync.syncNow(store: store)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Create Account") {
                            Task { await sync.signUp(email: emailDraft, password: password) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .disabled(!sync.isConfigured || emailDraft.isEmpty || password.count < 6)
                }
            }
            if let error = sync.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(AQETheme.statusRed)
                }
            }
            Section("Where to find these") {
                Text("Lovable project “AQE Office Hub” → backend/database settings → API. Copy the Project URL and the anon public key. Never paste the service_role key here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Cloud Sync")
        .onAppear { emailDraft = sync.config.email }
    }
}
