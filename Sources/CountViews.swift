import SwiftUI

struct CountText: View {
    var count: Int
    var body: some View {
        Text(compactActionCount(count)).monospacedDigit().lineLimit(1)
            .help(count.formatted()+" 次").accessibilityLabel(count.formatted()+" 次")
    }
}
struct ActionCountsView: View {
    @ObservedObject var store: GardenStore
    var body: some View {
        HStack(spacing:18) {
            item("目前",store.data.availableActions)
            item("今日",store.todayActions)
            item("总量",store.data.totalActions)
        }.frame(maxWidth:.infinity)
    }
    private func item(_ title: String,_ count: Int) -> some View {
        VStack(spacing:5) {
            Text(title).font(.system(size:11)).foregroundStyle(Palette.muted)
            CountText(count:count).font(.system(size:18,weight:.medium))
        }.frame(maxWidth:.infinity).accessibilityElement(children:.ignore)
            .accessibilityLabel(title).accessibilityValue(count.formatted()+" 次").help(count.formatted()+" 次")
    }
}
