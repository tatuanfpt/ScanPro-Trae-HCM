import Foundation
import UIKit

struct ScannedDocument: Codable, Identifiable {
    let id: UUID
    let scannedText: String
    let imageData: Data
    let confidence: Double
    let scanDate: Date
    let processingTime: Double
    
    init(id: UUID = UUID(), scannedText: String, image: UIImage, confidence: Double, processingTime: Double) {
        self.id = id
        self.scannedText = scannedText
        self.imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        self.confidence = confidence
        self.scanDate = Date()
        self.processingTime = processingTime
    }
    
    var image: UIImage? {
        return UIImage(data: imageData)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: scanDate)
    }
    
    var confidencePercentage: String {
        return String(format: "%.1f%%", confidence * 100)
    }
}

enum ScanningState {
    case idle
    case capturing
    case processing
    case completed(ScannedDocument)
    case error(String)
}

enum DocumentType {
    case receipt
    case businessCard
    case document
    case unknown
    
    var iconName: String {
        switch self {
        case .receipt: return "receipt"
        case .businessCard: return "person.text.rectangle"
        case .document: return "doc.text"
        case .unknown: return "doc"
        }
    }
    
    var description: String {
        switch self {
        case .receipt: return "Receipt"
        case .businessCard: return "Business Card"
        case .document: return "Document"
        case .unknown: return "Document"
        }
    }
}