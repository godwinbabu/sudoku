import SwiftUI
import UIKit

/// The curriculum (CODESPEC 13.5): Up next, then every technique in five tiers with its mastery dot.
/// A plain stack, not a List: List rows add system chevrons, which stay grey at night (CODESPEC 12.7).
struct LearnView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHead(title: "Learn")
                Text("\(inHand) of \(Lesson.techniques.count) techniques in your hands")
                    .font(.system(size: 14))
                    .foregroundColor(theme.ink3)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)
                if let next = upNext { upNextCard(next) }
                ForEach(LearnTier.allCases) { tier in
                    SectionLabel(theme: theme, title: tier.displayName)
                        .accessibilityIdentifier("learn_tier_\(tier.displayName.lowercased())")
                    VStack(spacing: 0) {
                        ForEach(Lesson.techniques.filter { $0.learnTier == tier }) { row($0) }
                    }
                    .overlay(alignment: .top) { theme.hair.frame(height: 1) }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 22)
                }
            }
            .padding(.bottom, 24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("learnView")
    }

    /// Techniques the player has used or met in a hint.
    private var inHand: Int {
        Lesson.techniques.filter { controller.progress(for: $0).level != .new }.count
    }

    /// The first technique in curriculum order that isn't mastered yet.
    private var upNext: Technique? {
        Lesson.techniques.first { controller.progress(for: $0).level != .mastered }
    }

    private func upNextCard(_ technique: Technique) -> some View {
        let progress = controller.progress(for: technique)
        var reason = "Needed for \(technique.level.displayName) puzzles."
        if progress.credits > 0 {
            reason += " \(progress.credits) of \(TechniqueProgress.creditsNeeded) unaided uses so far."
        } else if progress.hintsSeen > 0 {
            reason += " You’ve met it in \(progress.hintsSeen) hint\(progress.hintsSeen == 1 ? "" : "s") so far."
        }
        return NavigationLink { LessonView(technique: technique) } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UP NEXT · \(Lesson.stepCount(for: technique)) STEPS")
                        .font(.system(size: 12, weight: .semibold)).tracking(0.96).foregroundColor(theme.ink3)
                    Text(technique.displayName)
                        .font(.system(size: 24, weight: .medium, design: .serif)).foregroundColor(theme.ink)
                    Text(reason).font(.system(size: 14)).foregroundColor(theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Chevron(color: theme.accent)
            }
            .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Night: no lit fill behind text, only the hairline (CODESPEC 7.2).
        .background(RoundedRectangle(cornerRadius: 18).fill(theme.isNight ? .clear : theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(theme.hair, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("learn_upNext")
    }

    private func row(_ technique: Technique) -> some View {
        let progress = controller.progress(for: technique)
        let trailing = progress.credits > 0 ? "\(progress.credits)×" : LessonScript.all[technique] != nil ? "Lesson" : ""
        return NavigationLink { LessonView(technique: technique) } label: {
            HStack(spacing: 14) {
                StatusDot(level: progress.level, theme: theme)
                VStack(alignment: .leading, spacing: 2) {
                    Text(technique.displayName).font(.system(size: 16)).foregroundColor(theme.ink)
                    Text(technique.definition).font(.system(size: 13)).foregroundColor(theme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(trailing).font(.system(size: 12).monospacedDigit()).foregroundColor(theme.ink3)
                    .accessibilityLabel(Self.creditsLabel(progress.credits, otherwise: trailing))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { theme.hair.frame(height: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Self.levelName(progress.level))
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

/// 12 pt status dot. The shape carries the meaning, not the hue: mastered is filled, learning is
/// half filled, new is an empty ring.
struct StatusDot: View {
    let level: TechniqueProgress.Level
    let theme: PSPalette

    var body: some View {
        ZStack {
            switch level {
            case .mastered: Circle().fill(theme.accent)
            case .learning:
                Circle().strokeBorder(theme.accent, lineWidth: 1.5)
                Circle().fill(theme.accent).mask(HStack(spacing: 0) { Rectangle(); Color.clear })
            case .new: Circle().strokeBorder(theme.ink3, lineWidth: 1.5)
            }
        }
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
    }
}

/// A disclosure chevron drawn in palette colours; the system one stays grey at night.
struct Chevron: View {
    let color: Color

    var body: some View {
        Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(color)
            .accessibilityHidden(true)
    }
}

/// One lesson (CODESPEC 13.5): a board you step through, then Practise. Pushed, never a sheet.
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
                        .font(.system(size: 34, weight: .medium, design: .serif))
                        .foregroundColor(theme.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("lesson_title")
                    Text(lesson?.intro ?? technique.definition)
                        .font(.system(size: 15)).lineSpacing(3).foregroundColor(theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                    content.padding(.top, 14)
                }
                .padding(.horizontal, 24)
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

    private var header: some View {
        HStack(spacing: 0) {
            HeaderIconButton(theme: theme, symbol: "chevron.left", label: "Back") { dismiss() }
                .accessibilityIdentifier("lesson_back")
            Text("\(technique.learnTier.displayName) · Lesson".uppercased())
                .font(.system(size: 12, weight: .semibold)).tracking(0.96).foregroundColor(theme.ink3)
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
    }

    @ViewBuilder
    private var content: some View {
        if let lesson {
            let step = lesson.steps[index]
            SudokuGridView(cells: lesson.cells, selectedCellID: nil, theme: theme, highlight: step.highlight) { _ in }
                .frame(maxWidth: 342)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("lessonBoard")
            Text(step.text)
                .font(.system(size: 17)).lineSpacing(4).foregroundColor(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                .padding(.top, 18)
                .id(index)
                .transition(.opacity)
                .accessibilityIdentifier("lesson_stepText")
        } else if loaded {
            Text("No example puzzle for this technique yet.").font(.system(size: 15)).foregroundColor(theme.ink2)
        } else {
            ProgressView().tint(theme.ink3).frame(maxWidth: .infinity, minHeight: 342)
        }
    }

    /// Back circle, step pills, then Next, which becomes Practise on the last step.
    private func footer(_ lesson: Lesson) -> some View {
        let last = index == lesson.steps.count - 1
        return HStack(spacing: 10) {
            Button { go(to: index - 1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .medium)).foregroundColor(theme.ink2)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(theme.hair, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(index == 0)
            .opacity(index == 0 ? 0.3 : 1)
            .accessibilityLabel("Previous step")
            .accessibilityIdentifier("lesson_previous")
            HStack(spacing: 5) {
                ForEach(lesson.steps.indices, id: \.self) { step in
                    Capsule().fill(step <= index ? theme.accent : theme.hair).frame(width: step == index ? 16 : 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement()
            .accessibilityLabel("Step \(index + 1) of \(lesson.steps.count)")
            .accessibilityIdentifier("lesson_progress")
            if !last {
                Button("Next") { go(to: index + 1) }
                    .buttonStyle(PSButtonStyle(theme: theme))
                    .accessibilityIdentifier("lesson_next")
            } else if let entry = lesson.practice.first {
                NavigationLink {
                    GameView(viewModel: controller.makePracticeGameViewModel(entry, number: 1), difficulty: entry.difficulty)
                } label: { Text("Practise") }
                    .buttonStyle(PSButtonStyle(theme: theme))
                    .accessibilityIdentifier("lesson_practise")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    /// Steps fade, never slide (CODESPEC 12.4).
    private func go(to step: Int) {
        guard let lesson, lesson.steps.indices.contains(step) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { index = step }
        UIAccessibility.post(notification: .announcement, argument: lesson.steps[step].text)
    }
}
