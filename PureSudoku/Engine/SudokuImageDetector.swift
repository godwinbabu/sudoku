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
        /// Cells whose digit was read with low confidence, or where text was seen but no digit could be
        /// read (left blank). Both are ringed on Check the grid.
        var unsure: Set<Int>
    }

    /// What one cell gave: a digit, text Vision saw but that isn't a usable digit, or nothing.
    enum CellReading: Equatable {
        case digit(Int, unsure: Bool)
        case rejected
        case empty
    }

    static func grid(from readings: [CellReading]) -> DetectedGrid {
        var grid = DetectedGrid(values: Array(repeating: nil, count: 81), unsure: [])
        for (index, reading) in readings.enumerated() {
            switch reading {
            case let .digit(digit, unsure):
                grid.values[index] = digit
                if unsure { grid.unsure.insert(index) }
            case .rejected:
                grid.unsure.insert(index)
            case .empty:
                break
            }
        }
        return grid
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
        let cells = zip(splitIntoCells(image: warped), splitIntoCells(image: warped, inset: 0.18)).map { ($0, $1) }
        return try await recognizeDigits(in: cells) { progress(ReadProgress(corners: corners, cellsChecked: $0)) }
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

    /// `inset` is the share of the cell trimmed from each side, to drop the grid lines.
    private func splitIntoCells(image: UIImage, inset: Double = 0.08) -> [UIImage] {
        guard let cgImage = image.cgImage else { return [] }
        let width = cgImage.width
        let height = cgImage.height
        let cellWidth = width / 9
        let cellHeight = height / 9
        let insetX = Int(Double(cellWidth) * inset)
        let insetY = Int(Double(cellHeight) * inset)
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

    private func recognizeDigits(in cells: [(cell: UIImage, inner: UIImage)], checked: (Int) -> Void) async throws -> DetectedGrid {
        var readings: [CellReading] = []
        for (index, cell) in cells.enumerated() {
            try Task.checkCancellation()
            readings.append(try await read(cell: cell.cell, inner: cell.inner))
            checked(index + 1)
        }
        return Self.grid(from: readings)
    }

    /// Fast recognition first. A cell where text was seen but not read, or that has ink, is read again
    /// from its inner area on a plain margin: digits beside a thick line (the edge column when the
    /// detected rectangle includes the border) and thin 1s that fast mode reads as "I" (issue 66).
    private func read(cell: UIImage, inner: UIImage) async throws -> CellReading {
        var passes = [try await recognizeDigit(in: cell, level: .fast)]
        guard Self.settle(passes) == .rejected || (Self.settle(passes) == .empty && Self.hasInk(inner)) else {
            return Self.settle(passes)
        }
        let padded = Self.padded(inner)
        for level in [VNRequestTextRecognitionLevel.fast, .accurate] {
            passes.append(try await recognizeDigit(in: padded, level: level))
            if case .digit = passes.last { break }
        }
        return Self.settle(passes)
    }

    /// The first digit any pass read; else rejected if any pass saw text, so it is ringed, never dropped.
    static func settle(_ passes: [CellReading]) -> CellReading {
        if let digit = passes.first(where: { if case .digit = $0 { return true } else { return false } }) { return digit }
        return passes.contains(.rejected) ? .rejected : .empty
    }

    /// True when some pixels are much darker than the paper (median brightness).
    static func hasInk(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return false }
        let paper = Double(pixels.sorted()[pixels.count / 2])
        let dark = pixels.filter { Double($0) < paper * 0.55 }.count
        return dark * 100 >= pixels.count * 3
    }

    /// The image on a white margin of 40% of its width, so Vision sees a lone character.
    private static func padded(_ image: UIImage) -> UIImage {
        let margin = image.size.width * 0.4
        let size = CGSize(width: image.size.width + margin * 2, height: image.size.height + margin * 2)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(at: CGPoint(x: margin, y: margin))
        }
    }

    private func recognizeDigit(in image: UIImage, level: VNRequestTextRecognitionLevel) async throws -> CellReading {
        guard let cgImage = image.cgImage else { return .empty }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: .empty)
                    return
                }
                let sorted = observations.sorted { $0.confidence > $1.confidence }
                guard let bestObservation = sorted.first,
                      let best = bestObservation.topCandidates(1).first else {
                    continuation.resume(returning: .empty)
                    return
                }
                let box = bestObservation.boundingBox
                let area = box.width * box.height
                let centerDistance = abs(box.midX - 0.5) + abs(box.midY - 0.5)
                // The candidate's own score: the observation's can be high while this read is not.
                guard area >= 0.06, centerDistance <= 0.5,
                      let read = Self.reading(text: best.string, confidence: best.confidence) else {
                    // One central character may be a missed digit ("I" for a thin 1). Longer text ("ll") or
                    // text near the edge is grid lines or a neighbour's mark.
                    let central = abs(box.midX - 0.5) <= 0.2 && abs(box.midY - 0.5) <= 0.2
                    let single = best.string.trimmingCharacters(in: .whitespacesAndNewlines).count == 1
                    continuation.resume(returning: central && single ? .rejected : .empty)
                    return
                }
                continuation.resume(returning: .digit(read.digit, unsure: read.unsure))
            }
            request.recognitionLevel = level
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
