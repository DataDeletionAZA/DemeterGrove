import SwiftUI

struct DaySettingsView: View {
    @ObservedObject var store: GardenStore
    @State private var followsSystem = true
    @State private var zone = "Asia/Shanghai"
    @State private var hour = 0
    @State private var minute = 0
    @State private var error = ""
    @State private var choosingZone = false
    @State private var search = ""
    private let commonZones = ["Asia/Shanghai", "America/New_York", "Asia/Tokyo", "Europe/London", "America/Los_Angeles", "Asia/Hong_Kong", "Asia/Taipei", "Europe/Paris", "Australia/Sydney"]
    private var preview: DayBoundary { DayBoundary(timeZoneID: followsSystem ? nil : zone, rolloverMinutes: hour * 60 + minute) }
    private var matches: [String] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return commonZones }
        return TimeZone.knownTimeZoneIdentifiers.filter { $0.localizedCaseInsensitiveContains(query) || zoneTitle($0).localizedCaseInsensitiveContains(query) }
    }
    private var example: String {
        let span = preview.interval(forDay: preview.day(for: store.now))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN"); formatter.timeZone = preview.calendar.timeZone
        formatter.dateFormat = "M月d日 HH:mm"
        return "今天包括：" + formatter.string(from: span.start) + " — " + formatter.string(from: span.end.addingTimeInterval(-60))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("日期与换日").font(.headline).foregroundStyle(Palette.goldLight)
            Toggle("时区跟随 Mac 系统", isOn: $followsSystem)
            if !followsSystem {
                Button { search = ""; choosingZone = true } label: {
                    HStack { Text(zoneTitle(zone)); Spacer(); Image(systemName: "magnifyingglass") }
                }.buttonStyle(PixelButtonStyle()).accessibilityLabel("搜索或选择时区")
                    .popover(isPresented: $choosingZone, arrowEdge: .bottom) { zonePicker }
            } else { Text("系统时区：" + zoneTitle(TimeZone.current.identifier)).font(.caption).foregroundStyle(Palette.muted) }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { Text("每天换日时间"); rolloverControls }
                VStack(alignment: .leading, spacing: 8) { Text("每天换日时间"); rolloverControls }
            }
            Text(example).font(.caption).foregroundStyle(Palette.goldLight)
            Text("换日前的凌晨记录仍属于前一天。已有日记、打卡和操作计数保留原日期。").font(.caption).foregroundStyle(Palette.muted)
            HStack {
                Text("小院今天：" + store.todayKey).font(.caption).foregroundStyle(Palette.goldLight)
                Spacer()
                Button("保存日期设置") {
                    if store.updateDaySettings(timeZoneID: followsSystem ? nil : zone, rolloverMinutes: hour * 60 + minute) { error = ""; store.message = "日期设置已保存。" }
                    else { error = store.error.isEmpty ? "日期设置未能保存，请重试。" : store.error }
                }.buttonStyle(PixelButtonStyle(primary: true))
            }
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.clay) }
        }.onAppear {
            followsSystem = store.data.preferences.dayTimeZoneID == nil
            zone = store.data.preferences.dayTimeZoneID ?? TimeZone.current.identifier
            hour = store.dayBoundary.rolloverMinutes / 60
            minute = store.dayBoundary.rolloverMinutes % 60
        }
    }
    private var rolloverControls: some View {
        HStack(spacing: 10) {
            PixelSelect(selection: $hour, items: (0..<24).map { ($0, String(format: "%02d 时", $0)) }).frame(width: 108)
            PixelSelect(selection: $minute, items: (0..<60).map { ($0, String(format: "%02d 分", $0)) }).frame(width: 108)
        }
    }
    private var zonePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择时区").font(.headline)
            TextField("搜索城市、国家或时区名称", text: $search).textFieldStyle(PixelTextFieldStyle()).accessibilityLabel("搜索时区")
            Button("跟随 Mac 系统") { followsSystem = true; choosingZone = false }.buttonStyle(PixelButtonStyle())
            Text(search.isEmpty ? "常用时区" : "搜索结果 · \(matches.count)").font(.caption).foregroundStyle(Palette.muted)
            PixelScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach(matches, id: \.self) { id in
                        Button { zone = id; choosingZone = false } label: {
                            VStack(alignment: .leading, spacing: 3) { Text(zoneTitle(id)); Text(id).font(.caption).foregroundStyle(Palette.muted) }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(PixelButtonStyle(primary: zone == id))
                    }
                    if matches.isEmpty { Text("没有找到时区，试试城市名称或英文名称。").font(.caption).foregroundStyle(Palette.muted) }
                }.padding(.trailing, 16)
            }.frame(height: 260)
        }.padding(18).frame(width: 400).magicSurface(Palette.paper, strong: true).magicControls()
    }
    private func zoneTitle(_ id: String) -> String {
        switch id {
        case "Asia/Shanghai": return "北京时间 · 中国大陆"
        case "America/New_York": return "纽约 · 美国东部"
        case "America/Los_Angeles": return "洛杉矶 · 美国西部"
        case "Asia/Tokyo": return "东京 · 日本"
        case "Europe/London": return "伦敦 · 英国"
        case "Asia/Hong_Kong": return "香港"
        case "Asia/Taipei": return "台北"
        case "Europe/Paris": return "巴黎 · 法国"
        case "Australia/Sydney": return "悉尼 · 澳大利亚"
        default: return TimeZone(identifier: id)?.localizedName(for: .generic, locale: Locale(identifier: "zh_CN")) ?? id
        }
    }
}
