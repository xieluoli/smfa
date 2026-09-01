import AVFoundation
import SMFACore
import SwiftUI

/// 扫码添加账号。
///
/// 这里只负责把相机识别到的字符串取出来，解析与校验全部交给 SMFACore 的 OTPAuthURI，
/// 所以「扫到非法二维码怎么办」这类行为在没有摄像头的环境下也能被测到。
struct ScannerView: View {

    let onAdd: (MFAAccount) throws -> Void
    let onManualAdd: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var authorizationDenied = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Group {
                if authorizationDenied {
                    permissionDeniedView
                } else {
                    scannerBody
                }
            }
            .navigationTitle("扫码添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                authorizationDenied = false
            case .notDetermined:
                authorizationDenied = await !AVCaptureDevice.requestAccess(for: .video)
            default:
                authorizationDenied = true
            }
        }
    }

    private var scannerBody: some View {
        ZStack(alignment: .bottom) {
            QRCodeCameraView(onScan: handleScan)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 12) {
                if let message {
                    Text(message)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: .capsule)
                }
                Text("将站点提供的二维码放入取景框")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.bottom, 32)
            }
        }
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("无法使用相机", systemImage: "camera.fill")
        } description: {
            Text("请在「设置 → 隐私与安全性 → 相机」中允许 S-MFA 使用相机，或改用手动添加。")
        } actions: {
            Button("前往设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("手动添加") {
                dismiss()
                onManualAdd()
            }
        }
    }

    /// 返回 true 表示已成功添加，相机可以停止扫描。
    private func handleScan(_ scanned: String) -> Bool {
        do {
            try onAdd(OTPAuthURI.parse(scanned))
            dismiss()
            return true
        } catch AccountListError.duplicate {
            message = "该账号已存在，无需重复添加。"
        } catch is OTPAuthURIError {
            message = "无法识别这个二维码，请确认是站点的 MFA 二维码。"
        } catch {
            message = "保存失败：\(error.localizedDescription)"
        }
        return false
    }
}

/// AVFoundation 取景视图。识别成功由回调决定是否收工，识别失败则继续扫描。
private struct QRCodeCameraView: UIViewControllerRepresentable {

    let onScan: (String) -> Bool

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

// 委托回调已通过 setMetadataObjectsDelegate(_:queue: .main) 固定在主线程，
// 但 AVFoundation 的协议本身未标注隔离，这里显式声明以通过 Swift 6 并发检查。
final class ScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {

    var onScan: ((String) -> Bool)?

    // AVCaptureSession 自身线程安全，但未标注 Sendable；start/stop 是阻塞调用，
    // 必须挪出主线程，因此显式声明可跨线程使用并固定在一条串行队列上。
    nonisolated(unsafe) private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "cn.smfa.camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    /// 同一个二维码会被连续回调多次，处理期间先关掉入口避免重复添加。
    private var isHandling = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSessionIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    private func startSessionIfNeeded() {
        guard !session.isRunning else { return }
        nonisolated(unsafe) let session = session
        sessionQueue.async { session.startRunning() }
    }

    private func stopSession() {
        guard session.isRunning else { return }
        nonisolated(unsafe) let session = session
        sessionQueue.async { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !isHandling,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }

        isHandling = true
        let handled = onScan?(value) ?? false
        if handled {
            stopSession()
        } else {
            // 无效码不退出扫码页，隔一小会儿继续扫，避免同一张码刷屏提示。
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                self.isHandling = false
            }
        }
    }
}
