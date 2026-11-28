import SwiftUI

/// The Play tab (CODESPEC 3.1): the date and the moon, the title, the Continue card, the
/// five levels and saved imports. Import is the round button beside the tab bar.
struct HomeView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme
    @ObservedObject var viewModel: MainMenuViewModel
    let onContinue: (Difficulty) -> Void
    let onNew: (Difficulty) -> Void
    let onOpenImport: (ImportedGame) -> Void
    @State private var deleting: ImportedGame?
    @State private var replacing: Difficulty?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHead(title: "Sudoku Masters", line: viewModel.dateLine())
                Group {
                    if let notice = controller.resetNotice {
                        resetNotice(notice)
                    }
                    if let notice = controller.saveFailureNotice {
                        noticeBox(notice).accessibilityIdentifier("saveFailureNotice")
                    }
                    if let game = viewModel.continueGame {
                        continueCard(game)
                    }
                    groupLabel("New puzzle")
                    levels
                    savedImports
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .overlay { confirmation }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeView")
    }

    /// A group's label: 15 pt, 600, ink2, 24 pt above and 8 below (CODESPEC 3.1).
    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .psFont(15, weight: .semibold)
            .foregroundStyle(theme.ink2)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 4)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    // MARK: Reset notice (CODESPEC 8)

    /// A card with an outline, shown until dismissed.
    private func resetNotice(_ text: String) -> some View {
        noticeBox(text) {
            Button("OK") {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { controller.dismissResetNotice() }
            }
            .buttonStyle(PSButtonStyle(theme: theme, kind: .ghost, height: 36))
            .accessibilityIdentifier("resetNoticeDismiss")
        }
        .accessibilityIdentifier("resetNotice")
    }

    /// The reset notice's box. The save-failure notice has no button: it goes once the saves work.
    private func noticeBox(_ text: String, @ViewBuilder action: () -> some View = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .psFont(15)
                .foregroundStyle(theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            action()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .psCard(theme, radius: 26)
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(theme.hair, lineWidth: 1))
        .padding(.bottom, 16)
        .transition(.opacity)
        .accessibilityElement(children: .contain)
    }

    // MARK: Continue

    /// A 72 pt progress ring with the filled count, the level and time, and a Resume pill (CODESPEC 3.1).
    /// The whole card resumes the game.
    private func continueCard(_ game: GameState) -> some View {
        let filled = game.cells.filter { $0.value != nil }.count
        return Button { onContinue(game.puzzle.difficulty) } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(theme.line, lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: CGFloat(filled) / 81)
                        .stroke(theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(filled)")
                        .font(PSFont.fixed(22, weight: .heavy).monospacedDigit())
                        .foregroundStyle(theme.ink)
                }
                .padding(3.5)
                .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Continue").psFont(13, weight: .medium).foregroundStyle(theme.ink2)
                    Text(game.puzzle.difficulty.displayName)
                        .psFont(24, weight: .heavy, design: .serif).foregroundStyle(theme.ink)
                    Text("\(GameView.timeString(game.elapsedSeconds)) · \(filled) of 81")
                        .psFont(15, monospacedDigit: true).foregroundStyle(theme.ink2)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("Resume")
                    .psFont(16, weight: .bold)
                    .foregroundStyle(theme.btnInk)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(Capsule().fill(theme.btnBg))
                    .overlay(Capsule().strokeBorder(theme.btnEdge, lineWidth: 1.5))
                    .fixedSize()
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .psCard(theme, radius: 26)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Continue \(game.puzzle.difficulty.displayName), \(filled) of 81 filled")
        .accessibilityHint("Resume")
        .accessibilityIdentifier("continueCard")
    }

    // MARK: Levels

    /// One grouped list: name (`row`) over its hardest techniques (`label`, ink2), and a chevron.
    private var levels: some View {
        VStack(spacing: 0) {
            ForEach(Array(Difficulty.allCases.enumerated()), id: \.element) { index, level in
                Button {
                    // A level starts a new puzzle; an unfinished game there is never replaced silently.
                    if viewModel.hasUnfinishedEntries(at: level) { replacing = level } else { onNew(level) }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(level.displayName).psFont(19, weight: .heavy, design: .serif).foregroundStyle(theme.ink)
                            Text(level.techniqueSummary).psFont(13).foregroundStyle(theme.ink2)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(minHeight: 60)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { if index > 0 { theme.line.frame(height: 1) } }
                .accessibilityIdentifier("difficulty_\(level.rawValue)")
            }
        }
        .psCard(theme, radius: 26)
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }

    // MARK: Saved imports (BYOS: "return to them later")

    @ViewBuilder
    private var savedImports: some View {
        let saved = controller.savedImports
        if !saved.isEmpty {
            groupLabel("Saved imports")
            VStack(spacing: 0) {
                ForEach(Array(saved.enumerated()), id: \.element.id) { index, imported in
                    HStack(spacing: 4) {
                        Button { onOpenImport(imported) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(imported.gameState.puzzle.difficulty.displayName)
                                        .psFont(19, weight: .heavy, design: .serif).foregroundStyle(theme.ink)
                                    Text(imported.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .psFont(13).foregroundStyle(theme.ink2)
                                }
                                Spacer()
                                Text("\(imported.gameState.cells.filter { $0.value != nil }.count) of 81")
                                    .psFont(13, monospacedDigit: true).foregroundStyle(theme.ink2)
                            }
                            .frame(minHeight: 60)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("savedImport_\(imported.id)")
                        // A custom confirmation, not a system context menu, which could render light at night.
                        HeaderIconButton(theme: theme, symbol: "trash", label: "Delete import") { deleting = imported }
                            .accessibilityIdentifier("deleteImport_\(imported.id)")
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 4)
                    .overlay(alignment: .top) { if index > 0 { theme.line.frame(height: 1) } }
                }
            }
            .psCard(theme, radius: 26)
        }
    }

    @ViewBuilder
    private var confirmation: some View {
        if let imported = deleting {
            ConfirmPanel(theme: theme, title: "Delete this import?", message: "Its progress and photo are removed from this iPhone.",
                         cancel: "Cancel", confirm: "Delete", onCancel: { deleting = nil }, onDismiss: { deleting = nil }, onConfirm: {
                controller.deleteImportedGame(id: imported.id)
                deleting = nil
            })
        } else if let level = replacing {
            ConfirmPanel(theme: theme, title: "Replace your unfinished \(level.displayName) game?",
                         message: "A new puzzle takes its place. Continue to finish it first.",
                         cancel: "Continue", confirm: "New", cancelID: "confirm_continue",
                         onCancel: { replacing = nil; onContinue(level) }, onDismiss: { replacing = nil }, onConfirm: {
                replacing = nil
                onNew(level)
            })
        }
    }
}

/// A custom confirmation over a dimmed screen, never a system alert, which could render light at
/// night (CODESPEC 11.4). Tapping the backdrop dismisses it.
struct ConfirmPanel: View {
    let theme: PSPalette
    let title: String
    let message: String
    let cancel: String
    let confirm: String
    var cancelID = "confirm_cancel"
    let onCancel: () -> Void
    let onDismiss: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            // Near-black at night, so the screen behind does not show around the card.
            Color.black.opacity(theme.isNight ? 0.92 : 0.18)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            PopoverCard(theme: theme) {
                // Scrolls only when the text is too tall for the screen (CODESPEC 9).
                ViewThatFits(in: .vertical) {
                    content
                    ScrollView { content }
                }
            }
            .frame(maxWidth: 320)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .accessibilityElement(children: .contain)
            // Needed here too: this wrapper is its own container (see PopoverCard).
            .accessibilitySortPriority(-1)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, onDismiss)
            .accessibilityIdentifier("confirmDialog")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).psFont(17, weight: .semibold).foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(message).psFont(15).foregroundStyle(theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            PSButtonRow {
                Button(cancel, action: onCancel)
                    .buttonStyle(PSButtonStyle(theme: theme, kind: .ghost))
                    .accessibilityIdentifier(cancelID)
                Button(confirm, action: onConfirm)
                    .buttonStyle(PSButtonStyle(theme: theme))
                    .accessibilityIdentifier("confirm_action")
            }
            .padding(.top, 10)
        }
        .padding(16)
    }
}
