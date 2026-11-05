import SwiftUI
import AVFoundation
import VisionKit

/// Extracts a playlist link from a scanned QR payload.
public enum PlaylistQRPayload {
    /// Accepts a bare URL, `URL:` / `URLTO:` prefixed payloads, or text that contains a link.
    public static func playlistURL(from payload: String) -> URL? {
        var text = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["URLTO:", "URL:"] where text.uppercased().hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
            break
        }
        for rawToken in text.components(separatedBy: .whitespacesAndNewlines) {
            let token = rawToken.trimmingCharacters(in: CharacterSet(charactersIn: ";,\"'<>()"))
            guard let url = URL(string: token),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  let host = url.host, !host.isEmpty else { continue }
            return url
        }
        return nil
    }
}

/// Scans a QR code with the camera and imports the playlist it points to via `PlaylistStore`.
public struct PlaylistQRImportView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable {
        case scanning
        case importing(URL)
        case imported(title: String, channels: Int)
        case failed(String)
    }

    @State private var phase: Phase = .scanning
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var manualLink = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                scannerArea
                    .frame(maxWidth: .infinity)
                    .frame(height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.dcAccent, lineWidth: 2))

                statusView

                HStack {
                    TextField("…or paste a playlist link", text: $manualLink)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("qrManualLinkField")
                    Button("Import") { handle(payload: manualLink) }
                        .disabled(manualLink.trimmingCharacters(in: .whitespaces).isEmpty || isImporting)
                }
                Spacer()
            }
            .padding(16)
            .navigationTitle("Scan Playlist QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if cameraStatus == .notDetermined {
                    _ = await AVCaptureDevice.requestAccess(for: .video)
                    cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                }
            }
        }
    }

    private var isImporting: Bool {
        if case .importing = phase { return true }
        return false
    }

    @ViewBuilder
    private var scannerArea: some View {
        if cameraStatus == .authorized, phase == .scanning {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerQRView { handle(payload: $0) }
            } else if AVCaptureDevice.default(for: .video) != nil {
                AVCaptureQRView { handle(payload: $0) }
            } else {
                placeholder(icon: "camera.fill", text: "No camera available on this device.")
            }
        } else if cameraStatus == .denied || cameraStatus == .restricted {
            VStack(spacing: 12) {
                placeholder(icon: "camera.fill", text: "Camera access is off. Enable it in Settings to scan QR codes.")
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                }
            }
        } else if phase == .scanning {
            placeholder(icon: "qrcode.viewfinder", text: "Waiting for camera…")
        } else {
            placeholder(icon: "qrcode", text: "")
        }
    }

    private func placeholder(icon: String, text: String) -> some View {
        ZStack {
            Color.dcSurface
            VStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 44)).foregroundStyle(Color.dcTextTertiary)
                if !text.isEmpty {
                    Text(text).font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch phase {
        case .scanning:
            Text("Point the camera at a QR code with an M3U / M3U8 playlist link.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .importing(let url):
            HStack(spacing: 8) {
                ProgressView()
                Text("Importing \(url.host ?? url.absoluteString)…").font(.footnote)
            }
        case let .imported(title, channels):
            VStack(spacing: 8) {
                Label("Added \"\(title)\" (\(channels) channels)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("qrImportSuccess")
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
        case .failed(let message):
            VStack(spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                Button("Scan Again") { phase = .scanning }.buttonStyle(.bordered)
            }
        }
    }

    private func handle(payload: String) {
        guard !isImporting else { return }
        guard let url = PlaylistQRPayload.playlistURL(from: payload) else {
            phase = .failed("That QR code doesn't contain a playlist link.")
            return
        }
        phase = .importing(url)
        Task { @MainActor in
            do {
                let playlist = try await PlaylistStore.shared.importPlaylist(from: url.absoluteString)
                manualLink = ""
                phase = .imported(title: playlist.title, channels: playlist.channels.count)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - VisionKit scanner (iOS 16+, A12+ devices)

struct DataScannerQRView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                                   qualityLevel: .balanced,
                                                   recognizesMultipleItems: false,
                                                   isHighFrameRateTrackingEnabled: false,
                                                   isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
        if !controller.isScanning {
            try? controller.startScanning()
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void
        private var didReport = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !didReport else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    didReport = true
                    dataScanner.stopScanning()
                    onCode(payload)
                    return
                }
            }
        }
    }
}

// MARK: - AVFoundation fallback scanner

struct AVCaptureQRView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> QRCaptureViewController {
        let controller = QRCaptureViewController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ controller: QRCaptureViewController, context: Context) {
        controller.onCode = onCode
    }
}

final class QRCaptureViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didReport = false
    private let sessionQueue = DispatchQueue(label: "com.xanderco.dashcast.qrcapture")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(output) else { return }
        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        if output.availableMetadataObjectTypes.contains(.qr) {
            output.metadataObjectTypes = [.qr]
        }

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let session = captureSession
        sessionQueue.async {
            if !session.isRunning { session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = captureSession
        sessionQueue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                                    didOutput metadataObjects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        guard let payload = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        // Delegate queue is `.main`, so we are already on the main actor.
        MainActor.assumeIsolated {
            self.report(payload)
        }
    }

    private func report(_ payload: String) {
        guard !didReport else { return }
        didReport = true
        onCode?(payload)
    }
}
