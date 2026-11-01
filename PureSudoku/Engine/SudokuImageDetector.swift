import Foundation
import UIKit
import Vision
import CoreImage

struct SudokuImageDetector {
    enum DetectionError: Error {
        case invalidImage
        case gridNotFound
        case processingFailed
    }

    func detectGrid(from image: UIImage) async throws -> [Int?] {
        guard let cgImage = image.cgImage else {
            throw DetectionError.invalidImage
        }

        let gridObservation = try await detectGridObservation(in: cgImage)
        let warped = try warpGrid(from: cgImage, observation: gridObservation)
        let cellImages = splitIntoCells(image: warped)
        return try await recognizeDigits(in: cellImages)
    }

    private func detectGridObservation(in cgImage: CGImage) async throws -> VNRectangleObservation {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let results = request.results as? [VNRectangleObservation] else {
                    continuation.resume(throwing: DetectionError.gridNotFound)
                    return
                }
                let sorted = results.sorted { $0.confidence > $1.confidence }
                guard let best = sorted.first else {
                    continuation.resume(throwing: DetectionError.gridNotFound)
                    return
                }
                continuation.resume(returning: best)
            }
            request.maximumObservations = 1
            request.minimumConfidence = 0.6
            request.minimumAspectRatio = 0.8
            request.maximumAspectRatio = 1.2
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func warpGrid(from cgImage: CGImage, observation: VNRectangleObservation) throws -> UIImage {
        let image = CIImage(cgImage: cgImage)
        let size = image.extent.size
        let topLeft = CGPoint(x: observation.topLeft.x * size.width, y: observation.topLeft.y * size.height)
        let topRight = CGPoint(x: observation.topRight.x * size.width, y: observation.topRight.y * size.height)
        let bottomLeft = CGPoint(x: observation.bottomLeft.x * size.width, y: observation.bottomLeft.y * size.height)
        let bottomRight = CGPoint(x: observation.bottomRight.x * size.width, y: observation.bottomRight.y * size.height)

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            throw DetectionError.processingFailed
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")

        guard let output = filter.outputImage else {
            throw DetectionError.processingFailed
        }

        let context = CIContext()
        guard let corrected = context.createCGImage(output, from: output.extent) else {
            throw DetectionError.processingFailed
        }
        return UIImage(cgImage: corrected)
    }

    private func splitIntoCells(image: UIImage) -> [UIImage] {
        guard let cgImage = image.cgImage else { return [] }
        let width = cgImage.width
        let height = cgImage.height
        let cellWidth = width / 9
        let cellHeight = height / 9
        let insetX = Int(Double(cellWidth) * 0.08)
        let insetY = Int(Double(cellHeight) * 0.08)
        var cells: [UIImage] = []
        cells.reserveCapacity(81)
        for row in 0..<9 {
            for col in 0..<9 {
                let rect = CGRect(
                    x: col * cellWidth + insetX,
                    y: row * cellHeight + insetY,
                    width: cellWidth - insetX * 2,
                    height: cellHeight - insetY * 2
                )
                if let cropped = cgImage.cropping(to: rect) {
                    cells.append(UIImage(cgImage: cropped))
                } else {
                    cells.append(UIImage())
                }
            }
        }
        return cells
    }

    private func recognizeDigits(in cells: [UIImage]) async throws -> [Int?] {
        var results: [Int?] = Array(repeating: nil, count: 81)
        let requests = cells.enumerated().map { index, image in
            return (index, image)
        }

        for (index, image) in requests {
            let digit = try await recognizeDigit(in: image)
            results[index] = digit
        }
        return results
    }

    private func recognizeDigit(in image: UIImage) async throws -> Int? {
        guard let cgImage = image.cgImage else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                let sorted = observations.sorted { $0.confidence > $1.confidence }
                guard let bestObservation = sorted.first,
                      let best = bestObservation.topCandidates(1).first else {
                    continuation.resume(returning: nil)
                    return
                }
                let box = bestObservation.boundingBox
                let area = box.width * box.height
                let centerDistance = abs(box.midX - 0.5) + abs(box.midY - 0.5)
                if area < 0.06 || centerDistance > 0.5 {
                    continuation.resume(returning: nil)
                    return
                }
                let text = best.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if let value = Int(text), (1...9).contains(value) {
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.2
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
