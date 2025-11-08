import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Streak") {
                    Text("\(viewModel.stats.streakDays) days")
                }
                Section("Best Times") {
                    ForEach(Difficulty.allCases) { difficulty in
                        HStack {
                            Text(difficulty.displayName)
                            Spacer()
                            Text(viewModel.formattedBestTime(for: difficulty))
                        }
                    }
                }
                Section("Solved") {
                    ForEach(Difficulty.allCases) { difficulty in
                        HStack {
                            Text(difficulty.displayName)
                            Spacer()
                            Text("\(viewModel.solvedCount(for: difficulty))")
                        }
                    }
                    HStack {
                        Text("Total")
                        Spacer()
                        Text("\(viewModel.stats.totalPuzzlesSolved)")
                    }
                }
                Section("Time Spent") {
                    HStack {
                        Text("Total time")
                        Spacer()
                        Text(viewModel.totalTimeString())
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }
}
