import SwiftUI

/// The Play tab (CODESPEC 3.1, Design/v2/README.md "Play tab"): the Continue card, the five levels,
/// the Import row and saved imports.
struct HomeView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme
    @ObservedObject var viewModel: MainMenuViewModel
    let onContinue: (Difficulty) -> Void
    let onNew: (Difficulty) -> Void
    let onImport: () -> Void
    let onOpenImport: (ImportedGame) -> Void
    @State private var deleting: ImportedGame?
    @State private var replacing: Difficulty?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHead(title: "Pure Sudoku")
                Text(viewModel.subLine())
                    .font(.system(size: 14))
                    .foregroundColor(theme.ink3)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                if let game = viewModel.continueGame {
                    continueCard(game)
                }
                SectionLabel(theme: theme, title: "New puzzle")
                levels
                importRow
                savedImports
            }
            .padding(.bottom, 24)
        }
        .overlay { confirmation }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeView")
    }

    // MARK: Continue

    private func continueCard(_ game: GameState) -> some View {
        let filled = game.cells.filter { $0.value != nil }.count
        return Button { onContinue(game.puzzle.difficulty) } label: {
            HStack(spacing: 16) {
                MiniBoard(cells: game.cells, theme: theme).frame(width: 112, height: 112)
                VStack(alignment: .leading, spacing: 6) {
                    Text("CONTINUE").font(.system(size: 12, weight: .semibold)).tracking(0.96).foregroundColor(theme.ink2)
                    Text(game.puzzle.difficulty.displayName)
                        .font(.system(size: 24, weight: .medium, design: .serif)).foregroundColor(theme.ink)
                    Text("\(GameView.timeString(game.elapsedSeconds)) · \(filled) of 81")
                        .font(.system(size: 14).monospacedDigit()).foregroundColor(theme.ink2)
                    GeometryReader { proxy in
                        Capsule().fill(theme.hair)
                            .overlay(alignment: .leading) {
                                Capsule().fill(theme.accentDim).frame(width: proxy.size.width * CGFloat(filled) / 81)
                            }
                    }
                    .frame(height: 3)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 18).fill(theme.isNight ? .clear : theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(theme.hair, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 26)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Continue \(game.puzzle.difficulty.displayName), \(filled) of 81 filled")
        .accessibilityIdentifier("continueCard")
    }

    // MARK: Levels

    private var levels: some View {
        VStack(spacing: 0) {
            ForEach(Difficulty.allCases) { level in
                Button {
                    // A level starts a new puzzle; an unfinished game there is never replaced silently.
                    if viewModel.hasUnfinishedEntries(at: level) { replacing = level } else { onNew(level) }
                } label: {
                    HStack(spacing: 14) {
                        TierGlyph(lit: level.rank, theme: theme)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.displayName).font(.system(size: 17, weight: .medium)).foregroundColor(theme.ink)
                            Text(level.techniqueSummary).font(.system(size: 13)).foregroundColor(theme.ink3)
                        }
                        Spacer()
                        if let best = viewModel.stats.bestTime(for: level) {
                            Text("Best \(GameView.timeString(best))")
                                .font(.system(size: 13).monospacedDigit()).foregroundColor(theme.ink3)
                        }
                        Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(theme.ink3)
                    }
                    .padding(.horizontal, 6)
                    .frame(height: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) { theme.hair.frame(height: 1) }
                .accessibilityIdentifier("difficulty_\(level.rawValue)")
            }
        }
        .overlay(alignment: .top) { theme.hair.frame(height: 1) }
        .padding(.horizontal, 16)
    }

    private var importRow: some View {
        Button(action: onImport) {
            HStack(spacing: 10) {
                Image(systemName: "camera").font(.system(size: 20))
                Text("Import a puzzle from a photo").font(.system(size: 15))
            }
            .foregroundColor(theme.ink2)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .accessibilityIdentifier("importPuzzleButton")
    }

    // MARK: Saved imports (BYOS: "return to them later")

    @ViewBuilder
    private var savedImports: some View {
        let saved = controller.savedImports
        if !saved.isEmpty {
            SectionLabel(theme: theme, title: "Saved imports").padding(.top, 22)
            VStack(spacing: 0) {
                ForEach(saved) { imported in
                    HStack(spacing: 4) {
                        Button { onOpenImport(imported) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(imported.gameState.puzzle.difficulty.displayName)
                                        .font(.system(size: 16)).foregroundColor(theme.ink)
                                    Text(imported.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 13)).foregroundColor(theme.ink3)
                                }
                                Spacer()
                                Text("\(imported.gameState.cells.filter { $0.value != nil }.count) of 81")
                                    .font(.system(size: 13).monospacedDigit()).foregroundColor(theme.ink3)
                            }
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("savedImport_\(imported.id)")
                        // A custom confirmation, not a system context menu, which could render light at night.
                        HeaderIconButton(theme: theme, symbol: "trash", label: "Delete import") { deleting = imported }
                            .accessibilityIdentifier("deleteImport_\(imported.id)")
                    }
                    .padding(.leading, 6)
                    .overlay(alignment: .bottom) { theme.hair.frame(height: 1) }
                }
            }
            .overlay(alignment: .top) { theme.hair.frame(height: 1) }
            .padding(.horizontal, 16)
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
/// night (CODESPEC 12.4). Tapping the backdrop dismisses it.
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message).font(.system(size: 15)).foregroundColor(theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Spacer()
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
            .frame(maxWidth: 320)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
            .accessibilitySortPriority(-1)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, onDismiss)
            .accessibilityIdentifier("confirmDialog")
        }
    }
}

/// Five bars 3 pt wide, rising; the first `lit` are `accent`, the rest `hair`. The level name beside
/// it carries the meaning, so hue is never alone.
struct TierGlyph: View {
    let lit: Int
    let theme: PSPalette

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1...5, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1)
                    .fill(bar <= lit ? theme.accent : theme.hair)
                    .frame(width: 3, height: 4 + CGFloat(bar) * 2.6)
            }
        }
        .frame(width: 26, alignment: .leading)
        .accessibilityHidden(true)
    }
}

/// A small non-interactive board for the Continue card: lines and digits only, no cell fills.
struct MiniBoard: View {
    let cells: [SudokuCell]
    let theme: PSPalette

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height), cell = side / 9
            for index in 0...9 {
                let offset = CGFloat(index) * cell
                let major = index % 3 == 0
                var path = Path()
                path.move(to: CGPoint(x: offset, y: 0)); path.addLine(to: CGPoint(x: offset, y: side))
                path.move(to: CGPoint(x: 0, y: offset)); path.addLine(to: CGPoint(x: side, y: offset))
                context.stroke(path, with: .color(major ? theme.lineMajor : theme.line), lineWidth: major ? 1 : 0.5)
            }
            for item in cells {
                guard let value = item.value else { continue }
                let text = Text("\(value)")
                    .font(.system(size: cell * 0.62, weight: item.given ? .semibold : .regular))
                    .foregroundColor(item.given ? theme.ink : theme.accent)
                context.draw(text, at: CGPoint(x: (CGFloat(item.col) + 0.5) * cell, y: (CGFloat(item.row) + 0.5) * cell))
            }
        }
        .accessibilityHidden(true)
    }
}
