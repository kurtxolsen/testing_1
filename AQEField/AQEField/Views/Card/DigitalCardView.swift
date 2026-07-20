import SwiftUI
import CoreImage.CIFilterBuiltins

/// The consultant's digital business card: branded card face, scannable QR
/// (encodes a vCard — homeowner scans it and taps "add contact"), and a
/// share sheet for text/AirDrop. Everything is generated on-device.
struct DigitalCardView: View {
    @Environment(AppStore.self) private var store
    @State private var showEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                cardFace
                qrPanel
                shareButton
            }
            .padding()
        }
        .background(AQETheme.screenBackground)
        .navigationTitle("Digital Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) { ProfileEditorSheet() }
    }

    private var cardFace: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.profile.name)
                .font(.system(.title, design: .rounded, weight: .heavy))
            Text(store.profile.title)
                .font(.headline)
                .foregroundStyle(AQETheme.coral)
            Text(store.profile.company)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Divider().overlay(.white.opacity(0.3)).padding(.vertical, 4)
            if !store.profile.phone.isEmpty {
                Label(store.profile.phone, systemImage: "phone.fill").font(.subheadline)
            }
            if !store.profile.email.isEmpty {
                Label(store.profile.email, systemImage: "envelope.fill").font(.subheadline)
            }
            if !store.profile.website.isEmpty {
                Label(store.profile.website, systemImage: "globe").font(.subheadline)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(AQETheme.navy, in: RoundedRectangle(cornerRadius: 22))
    }

    private var qrPanel: some View {
        VStack(spacing: 10) {
            if let qr = Self.qrImage(from: store.profile.vCard) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
            }
            Text("Homeowner scans → your contact card pops up")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AQETheme.cardBackground, in: RoundedRectangle(cornerRadius: 22))
    }

    private var shareButton: some View {
        ShareLink(item: store.profile.vCard,
                  subject: Text("\(store.profile.name) — \(store.profile.company)"),
                  message: Text("Save my contact info")) {
            Label("Share Card", systemImage: "square.and.arrow.up")
                .font(.bigButton)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(AQETheme.coral, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    /// vCard text → QR code, rendered sharp at display size.
    static func qrImage(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct ProfileEditorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = RepProfile()

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $draft.name)
                    TextField("Title", text: $draft.title)
                    TextField("Company", text: $draft.company)
                }
                Section("Contact") {
                    TextField("Phone", text: $draft.phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $draft.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Website", text: $draft.website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.profile = draft
                        dismiss()
                    }
                    .font(.headline)
                }
            }
            .onAppear { draft = store.profile }
        }
    }
}
