import UIKit
import SnapKit

final class DocumentDetailViewController: UIViewController {
    
    private let document: ScannedDocument
    private let viewModel: ScannerViewModelProtocol
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let imageView = UIImageView()
    private let textView = UITextView()
    private let metadataLabel = UILabel()
    private let shareButton = UIButton(type: .system)
    private let copyButton = UIButton(type: .system)
    
    init(document: ScannedDocument, viewModel: ScannerViewModelProtocol) {
        self.document = document
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureWithDocument()
        setupNavigation()
    }
    
    private func setupNavigation() {
        title = "Document Details"
        navigationItem.largeTitleDisplayMode = .never
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareButtonTapped)
        )
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)
        
        scrollView.addSubview(contentView)
        
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemBackground
        contentView.addSubview(imageView)
        
        textView.isEditable = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .label
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        contentView.addSubview(textView)
        
        metadataLabel.font = .preferredFont(forTextStyle: .caption1)
        metadataLabel.textColor = .secondaryLabel
        metadataLabel.numberOfLines = 0
        contentView.addSubview(metadataLabel)
        
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        contentView.addSubview(buttonStack)
        
        shareButton.setTitle("Share", for: .normal)
        shareButton.backgroundColor = .systemBlue
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.layer.cornerRadius = 8
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        buttonStack.addArrangedSubview(shareButton)
        
        copyButton.setTitle("Copy Text", for: .normal)
        copyButton.backgroundColor = .systemGray5
        copyButton.setTitleColor(.label, for: .normal)
        copyButton.layer.cornerRadius = 8
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        buttonStack.addArrangedSubview(copyButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }
        
        imageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(300)
        }
        
        textView.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(200)
        }
        
        metadataLabel.snp.makeConstraints { make in
            make.top.equalTo(textView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        let buttonStack = contentView.subviews.last!
        buttonStack.snp.makeConstraints { make in
            make.top.equalTo(metadataLabel.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(50)
            make.bottom.equalToSuperview().offset(-20)
        }
    }
    
    private func configureWithDocument() {
        imageView.image = document.image
        textView.text = document.scannedText
        
        let metadata = """
        Scanned: \(document.formattedDate)
        Processing Time: \(String(format: "%.2f seconds", document.processingTime))
        Confidence: \(document.confidencePercentage)
        Character Count: \(document.scannedText.count)
        """
        
        metadataLabel.text = metadata
    }
    
    @objc private func shareButtonTapped() {
        viewModel.shareDocument(document)
    }
    
    @objc private func copyButtonTapped() {
        UIPasteboard.general.string = document.scannedText
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        let alert = UIAlertController(
            title: "Copied!",
            message: "Text copied to clipboard",
            preferredStyle: .alert
        )
        present(alert, animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                alert.dismiss(animated: true)
            }
        }
    }
}