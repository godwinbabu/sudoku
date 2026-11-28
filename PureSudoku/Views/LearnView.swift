import SwiftUI
import UIKit

/// The curriculum (CODESPEC 12.5): the Up next card, then every technique in five tiers, each
/// a grouped list. A plain stack, not a List: List rows add system chevrons, which stay grey at night.
struct LearnView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHead(title: "Learn", line: "\(Lesson.techniques.count) techniques in \(LearnTier.allCases.count) tiers")
                Group {
                    if let next = upNext { upNextCard(next) }
                    ForEach(LearnTier.allCases) { tier in
                        Text(tier.displayName)
                            .psFont(15, weight: .semibold)
                            .foregroundStyle(theme.ink2)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.horizontal, 4)
                            .padding(.top, 24)
                            .padding(.bottom, 8)
                            .accessibilityIdentifier("learn_tier_\(tier.displayName.lowercased())")
                        VStack(spacing: 0) {
                            ForEach(Array(Lesson.techniques.filter { $0.learnTier == tier }.enumerated()), id: \.element) {
                                row($0.element, divider: $0.offset > 0)
                            }
                        }
                        .psCard(theme, radius: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("learnView")
    }

    /// Mastered techniques only: half-learned ones are not yet "in your hands".
    static func inHandCount(_ level: (Technique) -> TechniqueProgress.Level) -> Int {
        Lesson.techniques.filter { level($0) == .mastered }.count
    }

    /// The first technique in curriculum order that isn't mastered yet.
    private var upNext: Technique? {
        Lesson.techniques.first { controller.progress(for: $0).level != .mastered }
    }

    /// Tier, name, its one-sentence definition and a primary Start lesson (CODESPEC 12.5).
    private func upNextCard(_ technique: Technique) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Up next · \(technique.learnTier.displayName)").psFont(13, weight: .medium).foregroundStyle(theme.ink2)
            Text(technique.displayName).psFont(24, weight: .heavy, design: .serif).foregroundStyle(theme.ink)
            Text(technique.definition).psFont(15).foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink { LessonView(technique: technique) } label: {
                Text("Start lesson").frame(maxWidth: .infinity)
            }
            .buttonStyle(PSButtonStyle(theme: theme))
            .padding(.top, 14)
            .accessibilityIdentifier("learn_upNext")
        }
        .padding(16)
        .psCard(theme, radius: 26)
        .accessibilityElement(children: .contain)
    }

    /// Name (`row`), then its status — Mastered with a check, Learning, Up next or New — and a chevron.
    private func row(_ technique: Technique, divider: Bool) -> some View {
        let level = controller.progress(for: technique).level
        let status = technique == upNext ? "Up next" : Self.levelName(level)
        return NavigationLink { LessonView(technique: technique) } label: {
            HStack(spacing: 10) {
                Text(technique.displayName)
                    .psFont(19, weight: .heavy, design: .serif)
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(status).psFont(15).foregroundStyle(theme.ink2)
                Image(systemName: level == .mastered ? "checkmark" : "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(level == .mastered ? theme.accent : theme.ink2)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { if divider { theme.line.frame(height: 1) } }
        .accessibilityElement(children: .combine)
        .accessibilityValue(status)
        .accessibilityIdentifier("learn_\(technique.rawValue)")
    }

    /// "1 unaided use", "12 unaided uses".
    static func creditsLabel(_ credits: Int, otherwise: String) -> String {
        guard credits > 0 else { return otherwise }
        return credits == 1 ? "1 unaided use" : "\(credits) unaided uses"
    }

    static func levelName(_ level: TechniqueProgress.Level) -> String {
        switch level {
        case .new: return "New"
        case .learning: return "Learning"
        case .mastered: return "Mastered"
        }
    }
}

/// One lesson (CODESPEC 12.5): a board you step through, then Practise. Pushed, never a sheet.
struct LessonView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let technique: Technique
    @State private var lesson: Lesson?
    @State private var loaded = false
    @State private var index = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(technique.displayName)
                        .psFont(33, weight: .heavy, design: .serif)
                        .foregroundStyle(theme.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("lesson_title")
                        .padding(.top, 4)
                    Text(technique.definition)
                        .psFont(15).foregroundStyle(theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                    content.padding(.top, 10)
                }
                .padding(.horizontal, 16)
            }
            if let lesson { footer(lesson) }
        }
        .background(theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(controller.isNight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lessonView")
        .task {
            let technique = technique, names = controller.settings.notation
            lesson = await Task.detached(priority: .userInitiated) { Lesson.make(for: technique, names: names) }.value
            loaded = true
        }
    }

    /// Round glass Back and "Tier · lesson N of M" (CODESPEC 12.5).
    private var header: some View {
        HStack(spacing: 0) {
            HeaderIconButton(theme: theme, symbol: "chevron.left", label: "Back", round: true) { dismiss() }
                .accessibilityIdentifier("lesson_back")
            Text("\(technique.learnTier.displayName) · lesson \(lessonNumber) of \(Lesson.techniques.count)")
                .psFont(15, weight: .medium).foregroundStyle(theme.ink2)
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
    }

    private var lessonNumber: Int { (Lesson.techniques.firstIndex(of: technique) ?? 0) + 1 }

    /// The board (screen width − 12) and a step card; only the cells that matter are at full strength.
    @ViewBuilder
    private var content: some View {
        if let lesson {
            let step = lesson.steps[index]
            SudokuGridView(cells: lesson.cells, selectedCellID: nil, theme: theme, highlight: step.highlight) { _ in }
                .padding(.horizontal, -10)
                .allowsHitTesting(false)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("lessonBoard")
            VStack(alignment: .leading, spacing: 4) {
                Text("Step \(index + 1) of \(lesson.steps.count)")
                    .psFont(13, weight: .medium).foregroundStyle(theme.ink2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("lesson_progress")
                Text(step.text)
                    .psFont(15).lineSpacing(2).foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                    .id(index)
                    .transition(.opacity)
                    .accessibilityIdentifier("lesson_stepText")
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
            .psCard(theme)
            .padding(.top, 10)
        } else if loaded {
            Text("No example puzzle for this technique yet.").psFont(15).foregroundStyle(theme.ink2)
        } else {
            ProgressView().tint(theme.ink2).frame(maxWidth: .infinity, minHeight: 342)
        }
    }

    /// Back (secondary) and Next (primary), which becomes Practise on the last step; before that a text
    /// button, "Practise on a real puzzle" (CODESPEC 12.5).
    private func footer(_ lesson: Lesson) -> some View {
        let last = index == lesson.steps.count - 1
        return VStack(spacing: 4) {
            HStack(spacing: 8) {
                Button("Back") { go(to: index - 1) }
                    .buttonStyle(PSButtonStyle(theme: theme, kind: .ghost, height: 48))
                    .frame(width: 104)
                    .disabled(index == 0)
                    .accessibilityLabel("Previous step")
                    .accessibilityIdentifier("lesson_previous")
                if !last {
                    Button { go(to: index + 1) } label: { Text("Next").frame(maxWidth: .infinity) }
                        .buttonStyle(PSButtonStyle(theme: theme, height: 48))
                        .accessibilityIdentifier("lesson_next")
                } else if let entry = lesson.practice.first {
                    practiseLink(entry) { Text("Practise").frame(maxWidth: .infinity) }
                        .buttonStyle(PSButtonStyle(theme: theme, height: 48))
                        .accessibilityIdentifier("lesson_practise")
                }
            }
            if !last, let entry = lesson.practice.first {
                practiseLink(entry) { Text("Practise on a real puzzle").psFont(15, weight: .semibold).foregroundStyle(theme.accent) }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("lesson_practiseLink")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func practiseLink(_ entry: BundledPuzzles.Entry, @ViewBuilder label: () -> some View) -> some View {
        NavigationLink {
            GameView(viewModel: controller.makePracticeGameViewModel(entry, number: 1), difficulty: entry.difficulty)
        } label: { label() }
    }

    /// Steps fade, never slide (CODESPEC 11.4).
    private func go(to step: Int) {
        guard let lesson, lesson.steps.indices.contains(step) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { index = step }
        UIAccessibility.post(notification: .announcement, argument: lesson.steps[step].text)
    }
}
