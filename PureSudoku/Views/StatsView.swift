import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Streak") {
                    Text("\(viewModel.stats.streakDays) days")
                }
                .sleepRowBackground()
                Section("Best Times") {
                    ForEach(Difficulty.allCases) { difficulty in
                        HStack {
                            Text(difficulty.displayName)
                            Spacer()
                            Text(viewModel.formattedBestTime(for: difficulty))
                        }
                    }
                }
                .sleepRowBackground()
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
                .sleepRowBackground()
                Section("Time Spent") {
                    HStack {
                        Text("Total time")
                        Spacer()
                        Text(viewModel.totalTimeString())
                    }
                }
                .sleepRowBackground()
            }
            .themedTitle("Stats")
        }
    }
}
