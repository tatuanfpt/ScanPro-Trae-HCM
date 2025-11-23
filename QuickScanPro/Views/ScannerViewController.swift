import UIKit
import AVFoundation
import Combine
import SnapKit

final class ScannerViewController: UIViewController {
    
    private let viewModel: ScannerViewModelProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    
    private let cameraPreview = UIView()
    private let captureButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let confidenceLabel = UILabel()
    private let processingIndicator = UIActivityIndicatorView(style: .large)
    private let recentScansButton = UIButton(type: .system)
    
    private var scannedDocuments: [ScannedDocument] = []
    
    init(viewModel: ScannerViewModelProtocol = ScannerViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
        bindViewModel()
        setupNavigation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCameraSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCameraSession()
    }
    
    private func setupNavigation() {
        title = "QuickScan Pro"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.tintColor = .systemBlue
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        cameraPreview.backgroundColor = .black
        cameraPreview.layer.cornerRadius = 20
        cameraPreview.clipsToBounds = true
        view.addSubview(cameraPreview)
        
        captureButton.setImage(UIImage(systemName: "circle.fill"), for: .normal)
        captureButton.tintColor = .systemBlue
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        captureButton.layer.shadowColor = UIColor.black.cgColor
        captureButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        captureButton.layer.shadowOpacity = 0.2
        captureButton.layer.shadowRadius = 4
        view.addSubview(captureButton)
        
        statusLabel.text = "Point camera at document"
        statusLabel.textAlignment = .center
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textColor = .secondaryLabel
        view.addSubview(statusLabel)
        
        confidenceLabel.text = ""
        confidenceLabel.textAlignment = .center
        confidenceLabel.font = .preferredFont(forTextStyle: .caption1)
        confidenceLabel.textColor = .systemGreen
        view.addSubview(confidenceLabel)
        
        processingIndicator.hidesWhenStopped = true
        processingIndicator.color = .systemBlue
        view.addSubview(processingIndicator)
        
        recentScansButton.setImage(UIImage(systemName: "doc.text.fill"), for: .normal)
        recentScansButton.tintColor = .systemBlue
        recentScansButton.addTarget(self, action: #selector(recentScansTapped), for: .touchUpInside)
        view.addSubview(recentScansButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        cameraPreview.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(cameraPreview.snp.width).multipliedBy(1.3)
        }
        
        captureButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-40)
            make.width.height.equalTo(70)
        }
        
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(cameraPreview.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        confidenceLabel.snp.makeConstraints { make in
            make.top.equalTo(statusLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        processingIndicator.snp.makeConstraints { make in
            make.center.equalTo(cameraPreview)
        }
        
        recentScansButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalTo(captureButton.snp.top).offset(-30)
            make.width.height.equalTo(44)
        }
    }
    
    private func setupCamera() {
        #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
        statusLabel.text = "Simulator detected – pick an image from Photos"
        captureButton.setImage(UIImage(systemName: "photo.fill.on.rectangle.fill"), for: .normal)
        #else
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        captureSession = session
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                DispatchQueue.main.async { self.showCameraError() }
                return
            }
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(self.output) {
                session.addOutput(self.output)
            }
            
            DispatchQueue.main.async {
                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.frame = self.cameraPreview.bounds
                previewLayer.videoGravity = .resizeAspectFill
                self.cameraPreview.layer.addSublayer(previewLayer)
                self.previewLayer = previewLayer
            }
        }
        #endif
    }
    
    private func startCameraSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func stopCameraSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    private func bindViewModel() {
        viewModel.scanningState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(for: state)
            }
            .store(in: &cancellables)
        
        viewModel.scannedDocuments
            .receive(on: DispatchQueue.main)
            .sink { [weak self] documents in
                self?.scannedDocuments = documents
            }
            .store(in: &cancellables)
    }
    
    private func updateUI(for state: ScanningState) {
        switch state {
        case .idle:
            statusLabel.text = "Point camera at document"
            confidenceLabel.text = ""
            processingIndicator.stopAnimating()
            captureButton.isEnabled = true
            
        case .capturing:
            statusLabel.text = "Capturing..."
            captureButton.isEnabled = false
            
        case .processing:
            statusLabel.text = "Processing text..."
            processingIndicator.startAnimating()
            captureButton.isEnabled = false
            
        case .completed(let document):
            statusLabel.text = "Text extracted successfully!"
            confidenceLabel.text = "Confidence: \(document.confidencePercentage)"
            processingIndicator.stopAnimating()
            captureButton.isEnabled = true
            showResultAlert(for: document)
            
        case .error(let message):
            statusLabel.text = "Error: \(message)"
            confidenceLabel.text = ""
            processingIndicator.stopAnimating()
            captureButton.isEnabled = true
            showErrorAlert(message: message)
        }
    }
    
    @objc private func captureButtonTapped() {
        #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
        openPhotoLibrary()
        #else
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        output.capturePhoto(with: settings, delegate: self)
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
    
    @objc private func recentScansTapped() {
        let documentsVC = DocumentsViewController(viewModel: viewModel)
        navigationController?.pushViewController(documentsVC, animated: true)
    }
    
    private func showResultAlert(for document: ScannedDocument) {
        let alert = UIAlertController(
            title: "Text Extracted!",
            message: "Found \(document.scannedText.count) characters with \(document.confidencePercentage) confidence",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "View", style: .default) { _ in
            let detailVC = DocumentDetailViewController(document: document, viewModel: self.viewModel)
            self.navigationController?.pushViewController(detailVC, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showCameraError() {
        let alert = UIAlertController(
            title: "Camera Error",
            message: "Unable to access camera. Please check your device settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func openPhotoLibrary() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }
}

extension ScannerViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            updateUI(for: .error(error.localizedDescription))
            return
        }
        
        guard let photoData = photo.fileDataRepresentation(),
              let image = UIImage(data: photoData) else {
            updateUI(for: .error("Failed to process photo"))
            return
        }
        
        viewModel.processCapturedImage(image)
    }
}

extension ScannerViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            viewModel.processCapturedImage(image)
        }
    }
}
