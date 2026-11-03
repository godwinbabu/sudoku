import SwiftUI

/// The curriculum (CODESPEC 13.5): every technique by tier, with the player's level and strength.
struct LearnView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var palette

    var body: some View {
        let theme = palette
        VStack(spacing: 0) {
            ScreenHead(title: "Learn")
            list(theme: theme)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("learnView")
    }

    private func list(theme: PSPalette) -> some View {
        List {
            ForEach([TechniqueTier.basic, .intermediate, .advanced, .expert], id: \.self) { tier in
                Section {
                    ForEach(Lesson.techniques.filter { $0.tier == tier }, id: \.self) { technique in
                        NavigationLink {
                            LessonView(technique: technique)
                        } label: {
                            row(technique, theme: theme)
                        }
                        .accessibilityIdentifier("learn_\(technique.rawValue)")
                    }
                } header: {
                    // System headers and separators are grey, brighter than ink at night.
                    SectionLabel(theme: theme, title: tier.displayName).padding(.horizontal, -22).padding(.bottom, -8)
                }
                // Night: no fill behind text, only hairlines (CODESPEC 12.7).
                .listRowBackground(theme.isNight ? Color.clear : theme.surface)
                .listRowSeparatorTint(theme.hair)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.bg.ignoresSafeArea())
    }

    private func row(_ technique: Technique, theme: PSPalette) -> some View {
        let progress = controller.progress(for: technique)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(technique.displayName).font(.body.weight(.semibold)).foregroundColor(theme.ink)
                Spacer()
                Text(Self.levelName(progress.level))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .overlay(Capsule().stroke(theme.accent, lineWidth: progress.level == .mastered ? 2 : 1))
                    .foregroundColor(theme.accent)
            }
            Text(technique.definition).font(.footnote).foregroundColor(theme.ink2)
            if progress.level != .new {
                // Drawn from the palette: the system track is grey, brighter than ink at night.
                let strength = progress.strength(at: Date())
                GeometryReader { proxy in
                    Capsule().fill(theme.hair).overlay(alignment: .leading) {
                        Capsule().fill(theme.accentDim).frame(width: proxy.size.width * strength)
                    }
                }
                .frame(height: 3)
                .accessibilityElement()
                .accessibilityLabel("Strength")
                .accessibilityValue("\(Int(strength * 100)) percent")
            }
        }
        .padding(.vertical, 4)
    }

    static func levelName(_ level: TechniqueProgress.Level) -> String {
        switch level {
        case .new: return "New"
        case .learning: return "Learning"
        case .mastered: return "Mastered"
        }
    }
}

/// One technique: a single worked example on a real board, then three practice puzzles.
struct LessonView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var palette
    let technique: Technique
    @State private var lesson: Lesson?
    @State private var showsResult = false
    @State private var loaded = false

    var body: some View {
        let theme = palette
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(technique.definition).font(.body).foregroundColor(theme.ink)
                if let lesson {
                    SudokuGridView(cells: lesson.cells, selectedCellID: nil, theme: theme, highlight: shownHighlight(lesson)) { _ in }
                        .aspectRatio(1, contentMode: .fit)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("lessonBoard")
                    Text(lesson.step.reason(controller.settings.notation))
                        .foregroundColor(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if showsResult {
                        Text(lesson.step.resultText(controller.settings.notation))
                            .font(.body.weight(.semibold))
                            .foregroundColor(theme.accent)
                    } else {
                        Button { showsResult = true } label: {
                            Text("Show the result").foregroundColor(theme.accent)
                        }
                        .accessibilityIdentifier("lesson_showResult")
                    }
                    Text("Practice").font(.headline).foregroundColor(theme.ink).padding(.top, 8)
                    ForEach(Array(lesson.practice.enumerated()), id: \.offset) { index, entry in
                        NavigationLink {
                            GameView(viewModel: controller.makePracticeGameViewModel(entry, number: index + 1), difficulty: entry.difficulty)
                        } label: {
                            Text("Practice puzzle \(index + 1) · \(entry.difficulty.displayName)")
                                .foregroundColor(theme.accent)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(theme.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityIdentifier("lesson_practice\(index + 1)")
                    }
                } else if loaded {
                    Text("No example puzzle for this technique yet.").foregroundColor(theme.ink2)
                } else {
                    ProgressView()
                }
            }
            .padding(20)
        }
        .background(theme.bg.ignoresSafeArea())
        .tint(theme.accent)
        .themedTitle(technique.displayName)
        .statusBarHidden(controller.isNight)
        .task {
            let technique = technique
            lesson = await Task.detached(priority: .userInitiated) { Lesson.make(for: technique) }.value
            loaded = true
        }
    }

    /// Pattern first; the removals and placements appear with the result.
    private func shownHighlight(_ lesson: Lesson) -> HintHighlight {
        var highlight = lesson.highlight
        if !showsResult {
            highlight.struckDigits = [:]
            highlight.ghostDigits = [:]
        }
        return highlight
    }
}
