import Foundation
import UIKit
import Vision
import AVFoundation
import Combine

protocol ScannerViewModelProtocol {
    var scanningState: CurrentValueSubject<ScanningState, Never> { get }
    var scannedDocuments: CurrentValueSubject<[ScannedDocument], Never> { get }
    func startScanning()
    func stopScanning()
    func processCapturedImage(_ image: UIImage)
    func shareDocument(_ document: ScannedDocument)
    func deleteDocument(_ document: ScannedDocument)
}

final class ScannerViewModel: ScannerViewModelProtocol {
    private let textRecognizer = TextRecognizer()
    private var cancellables = Set<AnyCancellable>()
    
    let scanningState = CurrentValueSubject<ScanningState, Never>(.idle)
    let scannedDocuments = CurrentValueSubject<[ScannedDocument], Never>([])
    
    init() {
        loadSavedDocuments()
    }
    
    func startScanning() {
        scanningState.value = .capturing
    }
    
    func stopScanning() {
        scanningState.value = .idle
    }
    
    func processCapturedImage(_ image: UIImage) {
        scanningState.value = .processing
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        textRecognizer.recognizeText(from: image) { [weak self] (result: Result<String, Error>) in
            guard let self = self else { return }
            
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            
            DispatchQueue.main.async {
                switch result {
                case .success(let recognizedText):
                    let confidence = self.calculateConfidence(for: recognizedText)
                    let document = ScannedDocument(
                        scannedText: recognizedText,
                        image: image,
                        confidence: confidence,
                        processingTime: processingTime
                    )
                    
                    self.scanningState.value = .completed(document)
                    self.saveDocument(document)
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                case .failure(let error):
                    self.scanningState.value = .error(error.localizedDescription)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    func shareDocument(_ document: ScannedDocument) {
        guard let image = document.image else { return }
        
        let activityController = UIActivityViewController(
            activityItems: [document.scannedText, image],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            DispatchQueue.main.async {
                rootViewController.present(activityController, animated: true)
            }
        }
    }
    
    func deleteDocument(_ document: ScannedDocument) {
        var documents = scannedDocuments.value
        documents.removeAll { $0.id == document.id }
        scannedDocuments.value = documents
        saveDocumentsToUserDefaults(documents)
    }
    
    private func calculateConfidence(for text: String) -> Double {
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).count
        let characterCount = text.count
        
        if characterCount == 0 { return 0.0 }
        
        let averageWordLength = Double(characterCount) / Double(max(wordCount, 1))
        let confidence = min(averageWordLength / 5.0, 1.0)
        
        return max(0.3, confidence)
    }
    
    private func saveDocument(_ document: ScannedDocument) {
        var documents = scannedDocuments.value
        documents.insert(document, at: 0)
        scannedDocuments.value = documents
        saveDocumentsToUserDefaults(documents)
    }
    
    private func loadSavedDocuments() {
        if let data = UserDefaults.standard.data(forKey: "scannedDocuments"),
           let documents = try? JSONDecoder().decode([ScannedDocument].self, from: data) {
            scannedDocuments.value = documents
        }
    }
    
    private func saveDocumentsToUserDefaults(_ documents: [ScannedDocument]) {
        if let data = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(data, forKey: "scannedDocuments")
        }
    }
}