import Foundation
import Vision
import UIKit

enum TextRecognitionError: LocalizedError {
    case noTextFound
    case processingFailed
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text could be recognized in the image"
        case .processingFailed:
            return "Text recognition processing failed"
        case .invalidImage:
            return "The provided image is invalid"
        }
    }
}

final class TextRecognizer {
    private let textRecognitionQueue = DispatchQueue(label: "com.hackathon.textrecognition", qos: .userInitiated)
    
    func recognizeText(from image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(TextRecognitionError.invalidImage))
            return
        }
        
        textRecognitionQueue.async { [weak self] in
            self?.performTextRecognition(cgImage: cgImage, completion: completion)
        }
    }
    
    private func performTextRecognition(cgImage: CGImage, completion: @escaping (Result<String, Error>) -> Void) {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(TextRecognitionError.processingFailed))
                return
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            if recognizedText.isEmpty {
                completion(.failure(TextRecognitionError.noTextFound))
            } else {
                completion(.success(recognizedText))
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        
        do {
            try requestHandler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }
}