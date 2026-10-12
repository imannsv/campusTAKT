#if canImport(UIKit)
  import SwiftUI
  import StudentCore

  struct StudentLogin: View {
    @ObservedObject var store: StudentStore
    @State private var server = ""
    @State private var code = ""
    @State private var password = ""
    @State private var scanning = false
    @State private var scanned: LoginQR?
    @State private var confirmQR = false
    @State private var manualLogin = false
    private let blue = Color(red: 33 / 255, green: 75 / 255, blue: 118 / 255)
    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(spacing: 32) {
            // The original logo asset includes a wide empty margin on the right.
            Image("Logo", bundle: .module).resizable().scaledToFit().frame(width: 720)
              .frame(width: 230, alignment: .leading).clipped()
              .accessibilityLabel("CampusZeit").padding(.top, 32)
            VStack(spacing: 20) {
              Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 64, weight: .light)).foregroundStyle(blue)
                .frame(width: 120, height: 120)
                .background(blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
                .accessibilityHidden(true)
              Text("Anmelden").font(.title.bold())
              Text("Scanne den QR-Code deiner Verwaltung.")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(.vertical, 16)
            VStack(spacing: 12) {
              Button {
                scanning = true
              } label: {
                HStack(spacing: 12) {
                  if store.busy { ProgressView().tint(.white) }
                  Label(store.busy ? "Anmelden …" : "QR-Code scannen", systemImage: "qrcode")
                }.font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                  .foregroundStyle(.white).background(blue, in: RoundedRectangle(cornerRadius: 12))
              }.buttonStyle(.plain).disabled(store.busy)
              Button("Mit Zugangsdaten anmelden") { manualLogin = true }
                .font(.body.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48)
                .buttonStyle(.plain).foregroundStyle(.primary).disabled(store.busy)
              errorMessage
            }
          }.frame(maxWidth: 420).padding(.horizontal, 24).padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemBackground))
          .sheet(isPresented: $manualLogin) {
            NavigationStack {
              Form {
                Section {
                  Text("Die Zugangsdaten erhältst du von deiner Verwaltung.")
                    .foregroundStyle(.secondary)
                }
                Section("Einrichtung") {
                  TextField("Serveradresse (https://…)", text: $server).keyboardType(.URL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityLabel(
                      "Serveradresse")
                }
                Section("Gruppenzugang") {
                  TextField("Zugangscode", text: $code).textInputAutocapitalization(.never)
                    .autocorrectionDisabled().accessibilityLabel("Zugangscode")
                  SecureField("Passwort", text: $password).textContentType(.password)
                }
                Section {
                  Button("Anmelden") {
                    Task {
                      await store.login(server: server, code: code, password: password)
                      password = ""
                      if store.credential != nil { manualLogin = false }
                    }
                  }.font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(.white).listRowBackground(blue)
                    .disabled(store.busy || server.isEmpty || code.isEmpty || password.isEmpty)
                  if store.busy { ProgressView("Anmelden …") }
                  errorMessage
                }
              }.disabled(store.busy)
                .navigationTitle("Zugangsdaten").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                  ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { manualLogin = false }.disabled(store.busy)
                  }
                }
            }.interactiveDismissDisabled(store.busy)
          }
          .sheet(isPresented: $scanning) {
            QRScanner { result in
              scanning = false
              switch result {
              case .success(let text):
                do {
                  scanned = try LoginQR.parse(text)
                  confirmQR = true
                } catch { store.error = error.localizedDescription }
              case .failure(let error): store.error = error.localizedDescription
              }
            }
          }
          .alert("Mit diesem Server verbinden?", isPresented: $confirmQR) {
            Button("Abbrechen", role: .cancel) { scanned = nil }
            Button("Verbinden") {
              if let qr = scanned {
                Task { await store.login(server: qr.server, code: "", password: "", qr: qr) }
              }
              scanned = nil
            }
          } message: {
            Text(scanned?.server ?? "")
          }
      }
    }
    @ViewBuilder private var errorMessage: some View {
      if let error = store.error {
        Label(error, systemImage: "exclamationmark.circle")
          .font(.callout).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently)
      }
    }
  }
#endif
