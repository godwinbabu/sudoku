import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Streak") {
                    Text("\(viewModel.stats.streakDays) days")
                }
                .paletteRowBackground()
                Section("Best Times") {
                    ForEach(Difficulty.allCases) { difficulty in
                        HStack {
                            Text(difficulty.displayName)
                            Spacer()
                            Text(viewModel.formattedBestTime(for: difficulty))
                        }
                    }
                }
                .paletteRowBackground()
                Section("Solved") {
                    ForEach(Difficulty.allCases) { difficulty in
                        HStack {
                            Text(difficulty.displayName)
                            Spacer()
                            Text("\(viewModel.solvedCount(for: difficulty))")
                        }
                    }
                    HStack {
                        Text("Imported")
                        Spacer()
                        Text("\(viewModel.stats.importedPuzzlesSolved)")
                    }
                    HStack {
                        Text("Total")
                        Spacer()
                        Text("\(viewModel.stats.totalPuzzlesSolved)")
                    }
                }
                .paletteRowBackground()
                Section("Time Spent") {
                    HStack {
                        Text("Total time")
                        Spacer()
                        Text(viewModel.totalTimeString())
                    }
                }
                .paletteRowBackground()
            }
            .themedTitle("Stats")
        }
    }
}
