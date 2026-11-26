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

/// Maps camera authorization, scanning phase, and hardware availability into a display state.
public enum PlaylistQRCameraDisplayState: Equatable, Sendable {
    case liveScanner
    case noCamera
    case permissionDenied
    case waiting
    case inactive
}

public enum PlaylistQRCameraStatusHelper {
    public static func displayState(
        authorizationStatus: AVAuthorizationStatus,
        isScanning: Bool,
        hasVideoDevice: Bool
    ) -> PlaylistQRCameraDisplayState {
        guard isScanning else { return .inactive }
        switch authorizationStatus {
        case .authorized:
            return hasVideoDevice ? .liveScanner : .noCamera
        case .denied, .restricted:
            return .permissionDenied
        case .notDetermined:
            return .waiting
        @unknown default:
            return .waiting
        }
    }

    public static func shouldRequestAccess(for authorizationStatus: AVAuthorizationStatus) -> Bool {
        authorizationStatus == .notDetermined
    }
}

/// Scans a QR code with the camera and imports the playlist it points to via `PlaylistStore`.
public struct PlaylistQRImportView: View {
    @Environment(\.dismiss) private var dismiss

    private enum FailureReason: Equatable {
        case invalidPayload
        case importError(String)
    }

    private enum Phase: Equatable {
        case scanning
        case importing(URL)
        case imported(title: String, channels: Int)
        case failed(FailureReason)
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
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.dashYellow, lineWidth: 2))

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
            .onAppear {
                refreshCameraStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                refreshCameraStatus()
            }
            .task {
                refreshCameraStatus()
                if PlaylistQRCameraStatusHelper.shouldRequestAccess(for: cameraStatus) {
                    _ = await AVCaptureDevice.requestAccess(for: .video)
                    refreshCameraStatus()
                }
            }
        }
    }

    private func refreshCameraStatus() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private var isImporting: Bool {
        if case .importing = phase { return true }
        return false
    }

    private var hasScannerHardware: Bool {
        (DataScannerViewController.isSupported && DataScannerViewController.isAvailable)
            || AVCaptureDevice.default(for: .video) != nil
    }

    @ViewBuilder
    private var scannerArea: some View {
        switch PlaylistQRCameraStatusHelper.displayState(
            authorizationStatus: cameraStatus,
            isScanning: phase == .scanning,
            hasVideoDevice: hasScannerHardware
        ) {
        case .liveScanner:
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerQRView { handle(payload: $0) }
            } else {
                AVCaptureQRView { handle(payload: $0) }
            }
        case .noCamera:
            placeholder(icon: "camera.fill", text: "No camera available on this device.")
        case .permissionDenied:
            VStack(spacing: 12) {
                placeholder(icon: "camera.fill", text: "Camera access is off. Enable it in Settings to scan QR codes.")
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                }
            }
        case .waiting:
            placeholder(icon: "qrcode.viewfinder", text: "Waiting for camera…")
        case .inactive:
            placeholder(icon: "qrcode", text: nil)
        }
    }

    private func placeholder(icon: String, text: LocalizedStringKey?) -> some View {
        ZStack {
            Color.dashSurface
            VStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 44)).foregroundStyle(Color.dashTextMuted)
                if let text {
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
        case .failed(let reason):
            VStack(spacing: 8) {
                Group {
                    switch reason {
                    case .invalidPayload:
                        Label("That QR code doesn't contain a playlist link.", systemImage: "exclamationmark.triangle.fill")
                    case .importError(let message):
                        Label {
                            Text(verbatim: message)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                    }
                }
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                Button("Scan Again") { phase = .scanning }.buttonStyle(.bordered)
            }
        }
    }

    private func handle(payload: String) {
        guard !isImporting else { return }
        guard let url = PlaylistQRPayload.playlistURL(from: payload) else {
            phase = .failed(.invalidPayload)
            return
        }
        phase = .importing(url)
        Task { @MainActor in
            do {
                let playlist = try await PlaylistStore.shared.importPlaylist(from: url.absoluteString)
                manualLink = ""
                phase = .imported(title: playlist.title, channels: playlist.channels.count)
            } catch {
                phase = .failed(.importError(error.localizedDescription))
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
