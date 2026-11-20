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
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // A lone thin stroke can only be a 1 in a grid of digits: fast mode reads a sans-serif 1 as "I" (issue 98).
        if ["I", "l", "|"].contains(text) { text = "1" }
        guard let value = Int(text), (1...9).contains(value) else { return nil }
        return (value, confidence < unsureConfidence)
    }

    func detectGrid(from image: UIImage, progress: @escaping @Sendable (ReadProgress) -> Void = { _ in }) async throws -> DetectedGrid {
        // Camera photos are stored sideways with a rotation flag that `cgImage` ignores.
        guard let cgImage = Self.upright(image).cgImage else {
            throw DetectionError.invalidImage
        }

        let corners: [CGPoint]
        let gridImage: CGImage
        if let found = try await detectGridCorners(in: cgImage) {
            corners = found
            gridImage = try warpGrid(from: cgImage, corners: corners)
        } else if let box = Self.contentBox(in: cgImage), let cropped = cgImage.cropping(to: box) {
            // A screenshot cropped to the grid: its border touches, or is cut by, the image edge.
            let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
            let (left, right) = (box.minX / width, box.maxX / width)
            let (top, bottom) = (1 - box.minY / height, 1 - box.maxY / height)
            corners = [CGPoint(x: left, y: top), CGPoint(x: right, y: top), CGPoint(x: right, y: bottom), CGPoint(x: left, y: bottom)]
            gridImage = cropped
        } else {
            throw DetectionError.gridNotFound
        }
        progress(ReadProgress(corners: corners, cellsChecked: 0))
        return try await readGrid(gridImage) { progress(ReadProgress(corners: corners, cellsChecked: $0)) }
    }

    /// Reads the digits of an image cut to the grid (perhaps with a frame or margin, or a cut-off edge).
    func readGrid(_ gridImage: CGImage, checked: (Int) -> Void = { _ in }) async throws -> DetectedGrid {
        let lines = Self.gridLines(of: gridImage)
        let cells = zip(splitIntoCells(image: gridImage, lines: lines),
                        splitIntoCells(image: gridImage, lines: lines, inset: 0.18)).map { ($0, $1) }
        return try await recognizeDigits(in: cells, checked: checked)
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

    /// The best rectangle's corners: top left, top right, bottom right, bottom left (plain points, so
    /// nothing non-Sendable leaves Vision's callback). Nil when there is none.
    private func detectGridCorners(in cgImage: CGImage) async throws -> [CGPoint]? {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let results = request.results as? [VNRectangleObservation] ?? []
                guard let best = results.max(by: { $0.confidence < $1.confidence }) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: [best.topLeft, best.topRight, best.bottomRight, best.bottomLeft])
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

    /// The box around everything that differs from the page (the median colour of the image's outer
    /// ring of pixels), in pixels from the top left. Nil when nothing stands out or the box is not
    /// roughly square, so a photo with no grid still says so.
    static func contentBox(in cgImage: CGImage) -> CGRect? {
        let width = cgImage.width, height = cgImage.height
        guard let pixels = grayPixels(of: cgImage, width: width, height: height) else { return nil }
        let ring = (0..<width).flatMap { [pixels[$0], pixels[(height - 1) * width + $0]] }
            + (0..<height).flatMap { [pixels[$0 * width], pixels[$0 * width + width - 1]] }
        let page = Int(ring.sorted()[ring.count / 2])
        var rows = [Int](repeating: 0, count: height), cols = [Int](repeating: 0, count: width)
        for row in 0..<height {
            for col in 0..<width where abs(Int(pixels[row * width + col]) - page) > 48 {
                rows[row] += 1
                cols[col] += 1
            }
        }
        // A line counts once 2% of it stands out, so specks of noise do not widen the box.
        guard let top = rows.firstIndex(where: { $0 * 50 > width }), let bottom = rows.lastIndex(where: { $0 * 50 > width }),
              let left = cols.firstIndex(where: { $0 * 50 > height }), let right = cols.lastIndex(where: { $0 * 50 > height })
        else { return nil }
        let box = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
        return (0.8...1.25).contains(box.width / box.height) ? box : nil
    }

    private func warpGrid(from cgImage: CGImage, corners: [CGPoint]) throws -> CGImage {
        let image = CIImage(cgImage: cgImage)
        let size = image.extent.size
        let pixels = corners.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let (topLeft, topRight, bottomRight, bottomLeft) = (pixels[0], pixels[1], pixels[2], pixels[3])

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
        return corrected
    }

    /// Where the 10 evenly spaced grid lines along one axis best fit `profile` (how much each pixel line
    /// stands out): the first line and the spacing. The first line may sit a little outside the image
    /// (a frame around the grid) and the last may be cut off (a tight crop).
    static func gridLines(in profile: [Double]) -> GridLines {
        let length = Double(profile.count)
        // Each pixel takes its neighbours' peak, fading with distance, so a line rounded a pixel off the
        // fitted spacing still counts while an exact fit still scores highest.
        let reach = max(1, profile.count / 300)
        let peaks = profile.indices.map { index in
            (-reach...reach).reduce(0.0) { peak, offset in
                guard profile.indices.contains(index + offset) else { return peak }
                return max(peak, profile[index + offset] * (1 - Double(abs(offset)) / Double(reach + 1)))
            }
        }
        // How much stands out across a box line's width. Box lines are thicker than cell lines, so with
        // the outer lines cut off (or hidden in a frame), this tells the true fit from one shifted a cell.
        let half = max(1, profile.count / 150)
        let widths = profile.indices.map { index in
            profile[max(0, index - half)...min(profile.count - 1, index + half)].reduce(0, +) / Double(half * 2 + 1)
        }
        var best = (score: -1.0, start: 0.0, step: length / 9)
        for step in stride(from: length / 9 * 0.85, through: length / 9 * 1.1, by: 0.25) {
            for start in stride(from: -0.05 * length, through: 0.12 * length, by: 1) {
                let score = (0...9).reduce(0.0) { sum, line in
                    let index = Int((start + Double(line) * step).rounded())
                    guard peaks.indices.contains(index) else { return sum }
                    return sum + peaks[index] + (line == 3 || line == 6 ? widths[index] : 0)
                }
                if score > best.score { best = (score, start, step) }
            }
        }
        return (best.start, best.step)
    }

    typealias GridLines = (start: Double, step: Double)

    /// The fitted grid lines of the grid image, columns then rows, so a frame or margin around the grid
    /// does not shift the edge rows and columns onto the border (issue 98).
    static func gridLines(of cgImage: CGImage) -> (cols: GridLines, rows: GridLines) {
        let width = cgImage.width, height = cgImage.height
        guard let pixels = grayPixels(of: cgImage, width: width, height: height) else {
            return ((0, Double(width) / 9), (0, Double(height) / 9))
        }
        var rowMeans = [Double](repeating: 0, count: height), colMeans = [Double](repeating: 0, count: width)
        for row in 0..<height {
            for col in 0..<width {
                let value = Double(pixels[row * width + col])
                rowMeans[row] += value / Double(width)
                colMeans[col] += value / Double(height)
            }
        }
        // A grid line is a whole row (or column) of one colour, far from the typical row's mean.
        func standOut(_ means: [Double]) -> [Double] {
            let typical = means.sorted()[means.count / 2]
            return means.map { abs($0 - typical) }
        }
        return (gridLines(in: standOut(colMeans)), gridLines(in: standOut(rowMeans)))
    }

    /// `inset` is the share of the cell trimmed from each side, to drop the grid lines.
    private func splitIntoCells(image cgImage: CGImage, lines: (cols: GridLines, rows: GridLines), inset: Double = 0.08) -> [UIImage] {
        let (cols, rows) = lines
        var cells: [UIImage] = []
        cells.reserveCapacity(81)
        for row in 0..<9 {
            for col in 0..<9 {
                let rect = CGRect(
                    x: cols.start + (Double(col) + inset) * cols.step,
                    y: rows.start + (Double(row) + inset) * rows.step,
                    width: cols.step * (1 - inset * 2),
                    height: rows.step * (1 - inset * 2)
                ).integral
                if let cropped = cgImage.cropping(to: rect) {
                    cells.append(Self.normalized(UIImage(cgImage: cropped)))
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
    /// An unsure digit is read again too, and a sure read wins (issue 98).
    private func read(cell: UIImage, inner: UIImage) async throws -> CellReading {
        var passes = [try await recognizeDigit(in: cell, level: .fast, cellSize: cell.size)]
        let first = Self.settle(passes)
        var unsure = false
        if case .digit(_, unsure: true) = first { unsure = true }
        guard unsure || first == .rejected || (first == .empty && Self.hasInk(inner)) else { return first }
        let padded = Self.padded(inner)
        for level in [VNRequestTextRecognitionLevel.fast, .accurate] {
            passes.append(try await recognizeDigit(in: padded, level: level, cellSize: cell.size))
            if case .digit(_, unsure: false) = passes.last { break }
        }
        return Self.settle(passes)
    }

    /// The first digit any pass read; else rejected if any pass saw text, so it is ringed, never dropped.
    /// Unsure reads that agree, with none that differ, are sure: fast mode scores most clear digits 0.5,
    /// and the accurate pass can miss a thin 1 (issue 103).
    static func settle(_ passes: [CellReading]) -> CellReading {
        if let sure = passes.first(where: { if case .digit(_, unsure: false) = $0 { return true } else { return false } }) { return sure }
        let digits = passes.compactMap { if case let .digit(digit, _) = $0 { return digit } else { return nil } }
        if let first = digits.first { return .digit(first, unsure: digits.count < 2 || Set(digits).count > 1) }
        return passes.contains(.rejected) ? .rejected : .empty
    }

    /// The image's brightness, one byte per pixel, scaled to `width` by `height`.
    static func grayPixels(of cgImage: CGImage, width: Int, height: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? pixels : nil
    }

    /// The cell in grey with dark ink on light paper. Light ink (white digits on a dark or coloured
    /// fill, as in dark mode) is inverted: it lies further above the paper (median) than any ink below it.
    static func normalized(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage,
              var pixels = grayPixels(of: cgImage, width: cgImage.width, height: cgImage.height) else { return image }
        let sorted = pixels.sorted()
        let paper = Int(sorted[sorted.count / 2]), darkest = Int(sorted[sorted.count / 100])
        let lightest = Int(sorted[sorted.count * 99 / 100])
        if lightest - paper > paper - darkest {
            for index in pixels.indices { pixels[index] = 255 - pixels[index] }
        }
        let gray = pixels.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8,
                      bytesPerRow: cgImage.width, space: CGColorSpaceCreateDeviceGray(),
                      bitmapInfo: CGImageAlphaInfo.none.rawValue)?.makeImage()
        }
        return gray.map { UIImage(cgImage: $0) } ?? image
    }

    /// True when some pixels are much darker than the paper (median brightness).
    static func hasInk(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage, let pixels = grayPixels(of: cgImage, width: 32, height: 32) else { return false }
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

    /// `cellSize` is the whole cell in points, so a padded inner crop is held to the same size limits.
    private func recognizeDigit(in image: UIImage, level: VNRequestTextRecognitionLevel,
                                cellSize: CGSize) async throws -> CellReading {
        guard let cgImage = image.cgImage else { return .empty }
        let imageSize = image.size
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
                // A given fills about half the cell; a pencil-mark note about a fifth (issue 98).
                guard box.height * imageSize.height >= cellSize.height * 0.36 else {
                    continuation.resume(returning: .empty)
                    return
                }
                // Share of the cell, not of the image: a padded crop is larger, and a thin 1 in it fell under (issue 103).
                let area = box.width * imageSize.width * box.height * imageSize.height / (cellSize.width * cellSize.height)
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
