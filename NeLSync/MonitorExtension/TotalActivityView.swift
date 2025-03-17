import SwiftUI

struct TotalActivityView: View {
    var activityReport: String

    var body: some View {
        VStack {
            Text("Screen Time Report")
                .font(.largeTitle)
                .padding()

            Text(activityReport)
                .font(.title2)
                .padding()
        }
    }
}
