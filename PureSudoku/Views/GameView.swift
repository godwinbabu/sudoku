import SwiftUI

/// The game screen (CODESPEC 3.2): header, board, hint slot, four tools and the 1×9 keypad.
struct GameView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.popToRoot) private var popToRoot
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.psPalette) private var basePalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel: GameViewModel
    @State private var showsMenu = false
    @State private var isHushed = false
    @State private var pausedForHush = false
    @State private var pausedForFirstNight = false
    @State private var isGoodnight = false
    @State private var lessonTechnique: Technique?
    @State private var techniqueLine: String?
    @StateObject private var drift = DriftController()
    private let difficulty: Difficulty

    init(viewModel: GameViewModel, difficulty: Difficulty) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.difficulty = difficulty
    }

    /// The screen's palette, with this session's Drift offset at night (CODESPEC 12.3).
    private var palette: PSPalette {
        guard drift.steps > 0 else { return basePalette }
        return DriftController.apply(steps: drift.steps, to: controller.settings).palette(isNight: true)
    }

    private var driftIsActive: Bool { basePalette.isNight && controller.settings.drift }

    private func updateDrift() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { drift.update(active: driftIsActive) }
        if controller.driftSteps != drift.steps { controller.driftSteps = drift.steps } // the backlight drifts too
    }

    /// Header, board top gap, hint slot, tools and keypad (everything but the board).
    private static let chromeHeight: CGFloat = 48 + 6 + 12 + 124 + 54 + 6 + 64 + 4

    var body: some View {
        let theme = palette
        let isDone = viewModel.state.isCompleted
        GeometryReader { geometry in
            let side = min(geometry.size.width - 24, geometry.size.height - Self.chromeHeight, 440)
            VStack(spacing: 0) {
                // The header, board, tools and keypad must fit one screen (CODESPEC 9): the board,
                // tools and keys keep a fixed size and show the Large Content Viewer instead.
                header(theme: theme)
                boardArea(theme: theme, side: max(side, 200))
                    .padding(.top, 6)
                // The hint card fills this slot; the tools and keypad below keep their place.
                Group {
                    if let coach = viewModel.coach, !isDone {
                        coachCard(coach, theme: theme)
                    } else if let session = viewModel.hint, !isDone {
                        hintCard(session, theme: theme)
                    } else {
                        hintSlot(theme: theme)
                    }
                }
                // At accessibility sizes the slot also takes the free room above the tools.
                .frame(minHeight: 124, maxHeight: dynamicTypeSize.isAccessibilitySize ? .infinity : 124)
                .padding([.top, .horizontal], 12)
                Spacer(minLength: 0)
                tools(theme: theme)
                    .padding(.horizontal, 18)
                    .opacity(isDone ? 0.3 : 1)
                NumberPadView(theme: theme, remaining: viewModel.remaining,
                              isNotesMode: viewModel.inputMode == .candidate) { digit in
                    viewModel.setDigit(digit)
                    if let message = viewModel.placedAnnouncement(digit) {
                        UIAccessibility.post(notification: .announcement, argument: message)
                    }
                }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .opacity(isDone || viewModel.isPaused ? 0.3 : 1) // disabled while paused, so it looks it
                    .disabled(isDone || viewModel.isPaused)
            }
            .frame(width: geometry.size.width)
        }
        .background(theme.bg.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { menu(theme: theme) }
        .overlay { confirmation(theme: theme) }
        .overlay {
            Group {
                if isHushed {
                    BlackoutView(theme: theme, text: "Tap anywhere to return", onTap: endHush)
                        .accessibilityIdentifier("hushView")
                } else if isGoodnight {
                    BlackoutView(theme: theme, text: "Sleep well.", serif: true) { popToRoot() }
                        .accessibilityIdentifier("goodnightView")
                }
            }
            // A blackout still fading out must not take the next tap (issue #67).
            .allowsHitTesting(isHushed || isGoodnight)
        }
        .background(TwoFingerTapCatcher(action: hush))
        .environment(\.psPalette, theme)
        // Drift is checked every 10 s; it only steps every 90 s. The loop ends with the screen.
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
                updateDrift()
            }
        }
        .onChange(of: driftIsActive) { _ in updateDrift() }
        .onChange(of: controller.showsFirstNight, perform: firstNightChanged)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: showsMenu)
        .animation(reduceMotion ? nil : .easeInOut(duration: Self.hushFade), value: isHushed)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isGoodnight)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(isHushed || isGoodnight || (theme.isNight && controller.settings.hideStatusBarInGames))
        .onChange(of: theme.isNight || isHushed || isGoodnight) { controller.hidesHomeIndicator = $0 }
        .onAppear {
            controller.hidesHomeIndicator = theme.isNight || isHushed || isGoodnight
            viewModel.apply(settings: controller.settings)
            viewModel.handleSceneDidAppear()
            updateDrift()
        }
        .onDisappear {
            controller.hidesHomeIndicator = false
            viewModel.handleSceneDidDisappear()
            drift.update(active: false)
            controller.driftSteps = 0
        }
        .onChange(of: controller.settings) { viewModel.apply(settings: $0) }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                viewModel.resumeFromBackground()
                updateDrift()
            } else {
                viewModel.pauseForBackground()
            }
        }
        // Pushed, not a system sheet, so it can't render light at night (CODESPEC 12.7).
        .navigationDestination(isPresented: Binding(get: { lessonTechnique != nil }, set: { if !$0 { lessonTechnique = nil } })) {
            let technique = lessonTechnique ?? .fullHouse
            LessonView(technique: technique == .hiddenSingleLine ? .hiddenSingleBox : technique)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gameView")
    }

    // MARK: - Header

    private func header(theme: PSPalette) -> some View {
        HStack(spacing: 4) {
            HeaderIconButton(theme: theme, symbol: "chevron.left", label: "Back") { dismiss() }
                .accessibilityIdentifier("backButton")
            TimerButton(clock: viewModel.clock, title: difficulty.displayName, theme: theme, showsTimer: viewModel.showTimer,
                        isPaused: viewModel.isPaused, isCompleted: viewModel.state.isCompleted, action: togglePause)
            HeaderIconButton(theme: theme, symbol: theme.isNight ? "moon.fill" : "moon", label: "Night") {
                showsMenu = false
                controller.showsNightSheet = true
            }
            .accessibilityIdentifier("nightButton")
            HeaderIconButton(theme: theme, symbol: "ellipsis", label: "More") { showsMenu.toggle() }
                .accessibilityIdentifier("moreButton")
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
    }

    // MARK: - Board

    @ViewBuilder
    private func boardArea(theme: PSPalette, side: CGFloat) -> some View {
        let isDone = viewModel.state.isCompleted
        ZStack {
            if viewModel.isPaused && !isDone {
                VStack(spacing: 14) {
                    Text("Paused")
                        .psFont(28, weight: .medium, design: .serif)
                        .foregroundColor(theme.ink)
                    Button("Resume") { viewModel.resumeTimer() }
                        .buttonStyle(PSButtonStyle(theme: theme))
                }
                .frame(width: side, height: side)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.hair, lineWidth: 1))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("pauseOverlay")
            } else {
                SudokuGridView(
                    cells: viewModel.state.cells,
                    selectedCellID: viewModel.hint == nil ? viewModel.selectedCellID : nil,
                    theme: theme,
                    highlight: viewModel.hintHighlight
                ) { viewModel.select(cell: $0) }
                    .frame(width: side, height: side)
                    // Faint enough that the Solved summary on top reads cleanly, Day and Night (QA #45).
                    .opacity(isDone ? 0.1 : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: isDone)
                    .allowsHitTesting(!isDone)
            }
            if isDone {
                SolvedPanel(theme: theme, summary: solvedSummary, note: solvedNote,
                            techniques: techniqueLine, onAnother: another, onGoodnight: { isGoodnight = true })
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge) // it sits on the board, so it must fit there
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: isDone) {
            techniqueLine = nil
            guard isDone else { return }
            let counts = await viewModel.techniquesNeeded()
            guard !Task.isCancelled, !counts.isEmpty else { return }
            techniqueLine = "This grid took " + counts.map { "\($0.name) ×\($0.count)" }.joined(separator: ", ") + "."
        }
    }

    private var solvedSummary: String {
        let hints = viewModel.state.hints
        let hintText = hints == 0 ? "" : " · \(hints) hint\(hints == 1 ? "" : "s")"
        return "\(difficulty.displayName) · \(Self.timeString(viewModel.state.elapsedSeconds))\(hintText)"
    }

    /// What this solve counts for (Stats.recordCompletion; practice records nothing).
    private var solvedNote: String? {
        if viewModel.isPractice { return "Practice · not counted in stats" }
        if viewModel.state.usedReveal { return "Revealed · not counted in stats" }
        if viewModel.state.assisted { return "Assisted · counts for your streak, not best times" }
        return nil
    }

    /// A new puzzle at this level; imports and practice have none, so they go back.
    private func another() {
        if viewModel.state.puzzle.source == .imported || viewModel.isPractice {
            dismiss()
        } else {
            viewModel.handle(pendingAction: .newPuzzle)
        }
    }

    // MARK: - Below the board

    @ViewBuilder
    private func hintSlot(theme: PSPalette) -> some View {
        // At accessibility sizes the messages can outgrow the slot (small phone, several at once):
        // they scroll rather than clip. Not ViewThatFits: it hung layout in this slot.
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView { slotMessages(theme: theme).frame(maxWidth: .infinity).padding(.vertical, 4) }
        } else {
            slotMessages(theme: theme).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func slotMessages(theme: PSPalette) -> some View {
        VStack(spacing: 6) {
            if viewModel.state.hasContradiction && !viewModel.state.isCompleted && controller.settings.mistakes != .never {
                Text("Two of the same digit share a row, column or box.")
                    .foregroundColor(theme.err)
                    .accessibilityIdentifier("contradictionWarning")
            }
            if let message = viewModel.checkMessage {
                Text(message).foregroundColor(theme.ink2).accessibilityIdentifier("checkMessage")
                    .id(message) // a new result is a new view, so it is announced again
                    .onAppear { UIAccessibility.post(notification: .announcement, argument: message) }
            } else if viewModel.inputMode == .candidate && !viewModel.state.isCompleted {
                Text("Notes on — digits go in as pencil marks").foregroundColor(theme.ink3)
            }
            if viewModel.isStuck {
                Text("Stuck? Tap Coach to see the patterns on your board.")
                    .foregroundColor(theme.ink2)
                    .accessibilityIdentifier("stuckNote")
            }
        }
        .psFont(13)
        .multilineTextAlignment(.center)
    }

    private func tools(theme: PSPalette) -> some View {
        let notesOn = viewModel.inputMode == .candidate
        return HStack(spacing: 0) {
            ToolButton(theme: theme, symbol: "arrow.uturn.backward", label: "Undo") { viewModel.undo() }
                .disabled(!viewModel.canUndo)
                .accessibilityIdentifier("tool_undo")
            ToolButton(theme: theme, symbol: "eraser", label: "Erase") { viewModel.clearSelectedCell() }
                .accessibilityIdentifier("tool_erase")
            ToolButton(theme: theme, symbol: "pencil", label: "Notes", isActive: notesOn, badge: notesOn ? "ON" : "OFF") {
                viewModel.inputMode = notesOn ? .normal : .candidate
            }
            .accessibilityIdentifier("tool_notes")
            .accessibilityValue(notesOn ? "On" : "Off")
            ToolButton(theme: theme, symbol: "lightbulb", label: hintToolLabel,
                       isActive: viewModel.hint != nil || viewModel.coach != nil || viewModel.isStuck) { viewModel.hintTool() }
                .accessibilityIdentifier("tool_hint")
        }
        .disabled(viewModel.state.isCompleted || viewModel.isPaused)
    }

    /// Hint; Next step while a hint is open; Show me / Apply in the coach; Coach once stuck.
    private var hintToolLabel: String {
        if let coach = viewModel.coach { return coach.revealed ? "Apply" : "Show me" }
        if viewModel.hint != nil { return "Next step" }
        return viewModel.isStuck ? "Coach" : "Hint"
    }

    private func coachCard(_ session: CoachSession, theme: PSPalette) -> some View {
        CoachCardView(
            session: session,
            names: controller.settings.notation,
            theme: theme,
            onBack: viewModel.coachBack,
            onForward: viewModel.coachForward,
            onDefinition: viewModel.coachToggleDefinition,
            onReveal: viewModel.coachReveal,
            onApply: viewModel.applyCoach,
            onLesson: { lessonTechnique = $0 },
            onClose: { viewModel.endHint() }
        )
        .disabled(viewModel.isPaused)
    }

    private func hintCard(_ session: HintSession, theme: PSPalette) -> some View {
        HintCardView(
            session: session,
            names: controller.settings.notation,
            theme: theme,
            onNext: viewModel.hintNext,
            onApply: viewModel.applyHint,
            onUndo: viewModel.canUndo ? { viewModel.undo() } : nil,
            onLesson: { lessonTechnique = $0 },
            onCoach: { viewModel.openCoach() },
            onClose: { viewModel.endHint() }
        )
        .disabled(viewModel.isPaused)
    }

    // MARK: - More menu, confirmation, Hush

    @ViewBuilder
    private func menu(theme: PSPalette) -> some View {
        if showsMenu {
            let isDone = viewModel.state.isCompleted
            ZStack(alignment: .topTrailing) {
                Color.clear.contentShape(Rectangle()).ignoresSafeArea().onTapGesture { showsMenu = false }
                PopoverCard(theme: theme) {
                    // With mistakes set to Never, Check would mark nothing, so it is not offered.
                    let offersCheck = controller.settings.mistakes != .never
                    if offersCheck {
                        MenuRow(theme: theme, title: "Check puzzle", showsDivider: false) { closeMenu(viewModel.checkPuzzle) }
                            .disabled(isDone || viewModel.isPaused)
                            .accessibilityIdentifier("menu_check")
                    }
                    MenuRow(theme: theme, title: "Fill all notes", showsDivider: offersCheck) { closeMenu(viewModel.fillAllNotes) }
                        .disabled(isDone || viewModel.isPaused)
                        .accessibilityIdentifier("menu_fillNotes")
                    MenuRow(theme: theme, title: "Restart puzzle") { closeMenu { viewModel.pendingAction = .reset } }
                        .disabled(viewModel.isPaused)
                        .accessibilityIdentifier("menu_restart")
                    MenuRow(theme: theme, title: "Hush screen", detail: "2-finger tap") { closeMenu(hush) }
                        .accessibilityIdentifier("menu_hush")
                }
                .frame(width: dynamicTypeSize.isAccessibilitySize ? 300 : 230)
                .accessibilityAction(.escape) { showsMenu = false }
                .padding(.top, 50)
                .padding(.trailing, 12)
            }
            .transition(.opacity)
        }
    }

    private func closeMenu(_ action: () -> Void) {
        showsMenu = false
        action()
    }

    @ViewBuilder
    private func confirmation(theme: PSPalette) -> some View {
        if let action = viewModel.pendingAction {
            ConfirmPanel(theme: theme, title: action.title, message: action.message,
                         cancel: "Cancel", confirm: action.confirmLabel,
                         onCancel: { viewModel.pendingAction = nil }, onDismiss: { viewModel.pendingAction = nil },
                         onConfirm: { viewModel.handle(pendingAction: action) })
            .transition(.opacity)
        }
    }

    /// Hush: pause and go black. A two-finger tap anywhere, or the More menu.
    private func hush() {
        // The recognizer is on the window, so it also fires on the pushed lesson.
        // Not behind the Night sheet, a confirmation or the first-night screen, which sit above the game.
        guard !isHushed, !isGoodnight, lessonTechnique == nil, !controller.showsNightSheet,
              !controller.showsFirstNight, viewModel.pendingAction == nil else { return }
        showsMenu = false
        pausedForHush = !viewModel.isPaused && !viewModel.state.isCompleted
        if pausedForHush { viewModel.pauseTimer() }
        isHushed = true
    }

    /// The first-night screen covers the game: close the menu and the lesson, and hold the timer.
    private func firstNightChanged(_ shows: Bool) {
        if shows {
            showsMenu = false
            lessonTechnique = nil
            pausedForFirstNight = !viewModel.isPaused && !viewModel.state.isCompleted
            if pausedForFirstNight { viewModel.pauseTimer() }
        } else if pausedForFirstNight {
            pausedForFirstNight = false
            viewModel.resumeTimer()
        }
    }

    #if DEBUG
    /// UI tests only: a 3 s fade, so a test can tap while the blackout is still fading (issue #67).
    private static let hushFade = ProcessInfo.processInfo.arguments.contains("-uiTestSlowHushFade") ? 3.0 : 0.3
    #else
    private static let hushFade = 0.3
    #endif

    private func endHush() {
        isHushed = false
        if pausedForHush { viewModel.resumeTimer() }
        pausedForHush = false
    }

    private func togglePause() {
        if viewModel.isPaused { viewModel.resumeTimer() } else { viewModel.pauseTimer() }
    }

    static func timeString(_ seconds: Int) -> String {
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60, secs = seconds % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }
}

/// The header's level name and timer. Only this view observes the clock, so a tick redraws it alone.
private struct TimerButton: View {
    @ObservedObject var clock: GameClock
    let title: String
    let theme: PSPalette
    let showsTimer: Bool
    let isPaused: Bool
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title.uppercased())
                    .psFont(11, weight: .semibold)
                    .tracking(0.9)
                    .foregroundColor(theme.ink3)
                if showsTimer {
                    HStack(spacing: 5) {
                        Text(GameView.timeString(clock.seconds))
                            .accessibilityIdentifier("timerLabel")
                        if isPaused { Image(systemName: "pause").psFont(11, weight: .semibold) }
                    }
                    .psFont(15, weight: .medium, monospacedDigit: true)
                    .foregroundColor(theme.ink2)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge) // the header is 48 pt tall
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
        .accessibilityIdentifier("timerToggle")
        .accessibilityLabel(isPaused ? "Resume timer" : "Pause timer")
        .accessibilityValue(showsTimer ? GameView.timeString(clock.seconds) : "")
    }
}
