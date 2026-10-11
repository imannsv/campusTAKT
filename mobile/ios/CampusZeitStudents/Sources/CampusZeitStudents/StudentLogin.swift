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
    var body: some View {
      NavigationStack {
        Form {
          Section {
            Image("Logo", bundle: .module).resizable().scaledToFit().frame(maxWidth: 230)
              .accessibilityLabel("CampusZeit")
            Text("Stundenplan, Prüfungen und Mitteilungen für deine Gruppe.")
          }
          Section {
            Button {
              scanning = true
            } label: {
              Label("QR-Code scannen", systemImage: "qrcode.viewfinder").frame(minHeight: 44)
            }.disabled(store.busy)
          } footer: {
            Text("Den QR-Code oder die Zugangsdaten erhältst du von deiner Verwaltung.")
          }
          Section("Mit Zugangsdaten anmelden") {
            TextField("Serveradresse (https://…)", text: $server).keyboardType(.URL)
              .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityLabel(
                "Serveradresse")
            TextField("Zugangscode", text: $code).textInputAutocapitalization(.never)
              .autocorrectionDisabled().accessibilityLabel("Zugangscode")
            SecureField("Passwort", text: $password).textContentType(.password)
            Button("Anmelden") {
              Task {
                await store.login(server: server, code: code, password: password)
                password = ""
              }
            }.disabled(store.busy || server.isEmpty || code.isEmpty || password.isEmpty)
          }
          if store.busy { ProgressView("Anmelden …") }
          if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
        }
        .navigationTitle("Anmelden")
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
  }
#endif
