import SwiftUI

struct RangePicker: View {
    let title: String
    @Binding var selection: TrendsRange

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(TrendsRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}
