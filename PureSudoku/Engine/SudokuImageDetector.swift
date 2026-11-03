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

    struct DetectedGrid: Equatable {
        var values: [Int?]
        /// Cells whose digit was read with low confidence (ringed on Check the grid).
        var unsure: Set<Int>
    }

    /// Where reading is: the grid's corners (normalised, origin bottom left, on the upright image)
    /// and how many of the 81 cells have been read.
    struct ReadProgress: Equatable {
        var corners: [CGPoint]
        var cellsChecked: Int
    }

    /// Below this Vision confidence a read digit counts as unsure.
    /// shortcut: untuned guess from simulator screenshots only; tune with real newspaper photos.
    static let unsureConfidence: Float = 0.6

    /// A recognised candidate's digit, and whether its own confidence (`VNRecognizedText.confidence`,
    /// not the observation's) is too low to trust. Nil when the text is not one digit 1...9.
    static func reading(text: String, confidence: Float) -> (digit: Int, unsure: Bool)? {
        guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)), (1...9).contains(value) else { return nil }
        return (value, confidence < unsureConfidence)
    }

    func detectGrid(from image: UIImage, progress: @escaping (ReadProgress) -> Void = { _ in }) async throws -> DetectedGrid {
        // Camera photos are stored sideways with a rotation flag that `cgImage` ignores.
        guard let cgImage = Self.upright(image).cgImage else {
            throw DetectionError.invalidImage
        }

        let gridObservation = try await detectGridObservation(in: cgImage)
        let corners = [gridObservation.topLeft, gridObservation.topRight, gridObservation.bottomRight, gridObservation.bottomLeft]
        progress(ReadProgress(corners: corners, cellsChecked: 0))
        let warped = try warpGrid(from: cgImage, observation: gridObservation)
        let cellImages = splitIntoCells(image: warped)
        return try await recognizeDigits(in: cellImages) { progress(ReadProgress(corners: corners, cellsChecked: $0)) }
    }

    /// Redraws the image so its pixels are upright (orientation `.up`, mirroring applied).
    static func upright(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
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

    private func recognizeDigits(in cells: [UIImage], checked: (Int) -> Void) async throws -> DetectedGrid {
        var grid = DetectedGrid(values: Array(repeating: nil, count: 81), unsure: [])
        for (index, image) in cells.enumerated() {
            try Task.checkCancellation()
            if let read = try await recognizeDigit(in: image) {
                grid.values[index] = read.digit
                if read.unsure { grid.unsure.insert(index) }
            }
            checked(index + 1)
        }
        return grid
    }

    private func recognizeDigit(in image: UIImage) async throws -> (digit: Int, unsure: Bool)? {
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
                // The candidate's own score: the observation's can be high while this read is not.
                continuation.resume(returning: Self.reading(text: best.string, confidence: best.confidence))
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
