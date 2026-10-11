#if canImport(UIKit)
  import SwiftUI
  import AVFoundation
  import StudentCore

  struct QRScanner: UIViewControllerRepresentable {
    let onResult: (Result<String, Error>) -> Void
    func makeUIViewController(context: Context) -> CameraController {
      CameraController(onResult: onResult)
    }
    func updateUIViewController(_ controller: CameraController, context: Context) {}
    static func dismantleUIViewController(_ controller: CameraController, coordinator: ()) {
      controller.stop()
    }
  }
  final class CameraController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "de.campuszeit.qr-camera")
    private let onResult: (Result<String, Error>) -> Void
    private var preview: AVCaptureVideoPreviewLayer?
    private var finished = false
    init(onResult: @escaping (Result<String, Error>) -> Void) {
      self.onResult = onResult
      super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .black
      let close = UIButton(type: .system)
      close.setTitle("Abbrechen", for: .normal)
      close.tintColor = .white
      close.backgroundColor = UIColor.black.withAlphaComponent(0.65)
      close.layer.cornerRadius = 8
      close.translatesAutoresizingMaskIntoConstraints = false
      close.addTarget(self, action: #selector(cancel), for: .touchUpInside)
      view.addSubview(close)
      NSLayoutConstraint.activate([
        close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
        close.trailingAnchor.constraint(
          equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        close.widthAnchor.constraint(equalToConstant: 112),
        close.heightAnchor.constraint(equalToConstant: 44),
      ])
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized: configure()
      case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
          DispatchQueue.main.async { if allowed { self?.configure() } else { self?.denied() } }
        }
      default: denied()
      }
    }
    private func denied() {
      finish(
        .failure(
          StudentError.service(
            "Kein Kamerazugriff. Aktiviere die Kamera in den iPhone-Einstellungen oder melde dich mit Zugangsdaten an."
          )))
    }
    private func configure() {
      guard !finished else { return }
      do {
        guard let device = AVCaptureDevice.default(for: .video) else {
          throw StudentError.service("Keine Kamera verfügbar. Bitte Zugangsdaten verwenden.")
        }
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureMetadataOutput()
        session.beginConfiguration()
        guard session.canAddInput(input), session.canAddOutput(output) else {
          session.commitConfiguration()
          throw StudentError.service("Die Kamera konnte nicht gestartet werden.")
        }
        session.addInput(input)
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        preview = layer
        queue.async { [session] in session.startRunning() }
      } catch { finish(.failure(error)) }
    }
    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      preview?.frame = view.bounds
    }
    override func viewDidDisappear(_ animated: Bool) {
      super.viewDidDisappear(animated)
      stop()
    }
    func stop() { queue.async { [session] in if session.isRunning { session.stopRunning() } } }
    @objc private func cancel() {
      finished = true
      stop()
      dismiss(animated: true)
    }
    private func finish(_ result: Result<String, Error>) {
      guard !finished else { return }
      finished = true
      stop()
      onResult(result)
    }
    func metadataOutput(
      _ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject],
      from connection: AVCaptureConnection
    ) {
      if let qr = objects.first as? AVMetadataMachineReadableCodeObject, let value = qr.stringValue
      {
        finish(.success(value))
      }
    }
  }
#endif
