import UIKit
import Combine
import SnapKit

final class DocumentsViewController: UIViewController {
    
    private let viewModel: ScannerViewModelProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private let tableView = UITableView()
    private var documents: [ScannedDocument] = []
    
    init(viewModel: ScannerViewModelProtocol) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        setupNavigation()
    }
    
    private func setupNavigation() {
        title = "Recent Scans"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DocumentCell.self, forCellReuseIdentifier: "DocumentCell")
        tableView.rowHeight = 80
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        view.addSubview(tableView)
        
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if documents.isEmpty {
            showEmptyState()
        }
    }
    
    private func showEmptyState() {
        let emptyView = UIView()
        emptyView.isHidden = !documents.isEmpty
        view.addSubview(emptyView)
        
        let iconImageView = UIImageView(image: UIImage(systemName: "doc.text"))
        iconImageView.tintColor = .systemGray3
        iconImageView.contentMode = .scaleAspectFit
        emptyView.addSubview(iconImageView)
        
        let titleLabel = UILabel()
        titleLabel.text = "No scans yet"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        emptyView.addSubview(titleLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Start scanning documents to see them here"
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .tertiaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        emptyView.addSubview(subtitleLabel)
        
        emptyView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(60)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    private func bindViewModel() {
        viewModel.scannedDocuments
            .receive(on: DispatchQueue.main)
            .sink { [weak self] documents in
                self?.documents = documents
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }
}

extension DocumentsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return documents.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DocumentCell", for: indexPath) as! DocumentCell
        let document = documents[indexPath.row]
        cell.configure(with: document)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let document = documents[indexPath.row]
        let detailVC = DocumentDetailViewController(document: document, viewModel: viewModel)
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self = self else { return }
            let document = self.documents[indexPath.row]
            self.viewModel.deleteDocument(document)
            completion(true)
        }
        
        let shareAction = UIContextualAction(style: .normal, title: "Share") { [weak self] _, _, completion in
            guard let self = self else { return }
            let document = self.documents[indexPath.row]
            self.viewModel.shareDocument(document)
            completion(true)
        }
        shareAction.backgroundColor = .systemBlue
        
        return UISwipeActionsConfiguration(actions: [deleteAction, shareAction])
    }
}

final class DocumentCell: UITableViewCell {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let confidenceLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemBlue
        contentView.addSubview(iconImageView)
        
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        contentView.addSubview(titleLabel)
        
        dateLabel.font = .preferredFont(forTextStyle: .caption1)
        dateLabel.textColor = .secondaryLabel
        contentView.addSubview(dateLabel)
        
        confidenceLabel.font = .preferredFont(forTextStyle: .caption2)
        confidenceLabel.textColor = .systemGreen
        contentView.addSubview(confidenceLabel)
        
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel)
        }
        
        confidenceLabel.snp.makeConstraints { make in
            make.top.equalTo(dateLabel.snp.bottom).offset(2)
            make.leading.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-12)
        }
    }
    
    func configure(with document: ScannedDocument) {
        iconImageView.image = UIImage(systemName: "doc.text")
        titleLabel.text = String(document.scannedText.prefix(60)) + (document.scannedText.count > 60 ? "..." : "")
        dateLabel.text = document.formattedDate
        confidenceLabel.text = "Confidence: \(document.confidencePercentage)"
    }
}