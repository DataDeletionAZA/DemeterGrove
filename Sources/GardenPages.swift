import SwiftUI
import Charts
import AppKit

struct FarmPage: View {
    @ObservedObject var store: GardenStore
    var section: String? = nil
    @State private var selection = "农场"
    var body: some View {
        VStack(spacing: 12) {
            if section == nil { PixelTabs(selection: $selection, items: ["农场", "厨房", "商店"].map { ($0, $0) }) }
            GameRoomView(store: store, room: section ?? selection).id(section ?? selection)
        }
    }
}

struct StatsPage: View {
    @ObservedObject var store: GardenStore
    @State private var range = 7
    private var dates: [Date] {
        (0..<range).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Calendar.current.startOfDay(for: store.now)) }
    }
    private func minutes(_ date: Date) -> Double {
        store.data.sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.seconds } / 60
    }
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 13) {
                Metric(title: "累计专注", value: "\(Int(store.data.totalFocus / 60)) 分钟", foot: "\(store.data.sessions.count) 段专注")
                Metric(title: "累计操作", value: "\(store.data.totalActions) 次", foot: "键盘 \(store.data.keys.values.reduce(0,+)) · 鼠标 \((store.data.mouseClicks ?? [:]).values.reduce(0,+))")
                Metric(title: "日记天数", value: "\(store.data.diaries.values.filter { !$0.text.isEmpty }.count) 天", foot: "\(store.data.diaries.values.reduce(0) { $0 + $1.characters }) 个非空白字符")
            }
            HStack {
                Text("统计范围").font(.title3).fontWeight(.medium)
                Spacer()
                PixelTabs(selection: $range, items: [(7, "7 天"), (30, "30 天")]).frame(width: 160)
            }
            Card(title: "每天的专注 · 分钟", icon: "timer") {
                Chart(dates, id: \.self) { date in
                    BarMark(x: .value("日期", date, unit: .day), y: .value("专注分钟", minutes(date))).foregroundStyle(Palette.sage).cornerRadius(0)
                }.frame(height: 175).chartXAxis { AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : 5)) { value in AxisValueLabel(format: .dateTime.month().day()); AxisGridLine() } }
                    .chartYScale(domain: 0...max(30, (dates.map(minutes).max() ?? 0) * 1.1))

            }
            Card(title: "每天的操作 · 次数", icon: "keyboard") {
                Chart(dates, id: \.self) { date in
                    BarMark(x: .value("日期", date, unit: .day), y: .value("操作次数", store.data.keys[dayKey(date), default: 0] + (store.data.mouseClicks?[dayKey(date)] ?? 0))).foregroundStyle(Palette.clay.opacity(0.75)).cornerRadius(0)
                }.frame(height: 175).chartXAxis { AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : 5)) { _ in AxisValueLabel(format: .dateTime.month().day()); AxisGridLine() } }
                    .chartYScale(domain: 0...max(10, Double(dates.map { store.data.keys[dayKey($0), default: 0] + (store.data.mouseClicks?[dayKey($0)] ?? 0) }.max() ?? 0) * 1.1))
            }
            Card(title: "完成统计", icon: "checkmark.seal") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("已完成 \(store.data.tasks.filter { $0.completedAt != nil }.count) / \(store.data.tasks.count) 件任务", systemImage: "checkmark.circle")
                    Label("累计 \(store.data.habits.reduce(0) { $0 + $1.days.count }) 次打卡", systemImage: "leaf")
                }
                ForEach(store.data.habits) { habit in
                    HStack { Text(habit.title); Spacer(); Text("连续 \(habit.streak()) 天 · 共 \(habit.days.count) 天").foregroundStyle(Palette.muted) }.font(.callout)
                }
            }
        }
    }
}

struct SettingsPage: View {
    @ObservedObject var store: GardenStore
    var body: some View {
        VStack(spacing: 20) {
            Card(title: "桌宠", icon: "person.crop.square") {
                HStack(spacing: 32) {
                    ProfessorSprite(phase:store.petPhase,size:120,economy:store.data.garden.economy,idlePose:store.idlePose,expression:store.petExpression,basePhase:store.petBasePhase)
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("名字", text: $store.data.preferences.name).textFieldStyle(PixelTextFieldStyle()).frame(maxWidth: 260)
                        Toggle("在桌面显示", isOn: Binding(get: { store.data.preferences.petVisible }, set: { store.setPet($0) }))

                    }
                }
            }
            Card(title: "操作计数", icon: "keyboard") {
                Toggle("统计键盘与鼠标点击", isOn: Binding(get: { store.data.preferences.typingEnabled }, set: { store.setTyping($0) }))
                Text("仅保存每日次数，不保存输入内容。").font(.callout).foregroundStyle(Palette.muted)
                HStack {
                    Button("打开系统的输入监控设置") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                    }
                    Text("今天 \(store.todayActions) 次 · \(store.inputStatus)").font(.callout).foregroundStyle(Palette.sage)
                }
            }
            Card(title: "专注与提醒", icon: "bell") {
                PixelStepper(title: "默认专注", value: $store.data.preferences.focusMinutes, range: 1...180).frame(maxWidth: 360)
                PixelStepper(title: "默认休息", value: $store.data.preferences.breakMinutes, range: 1...60).frame(maxWidth: 360)
                Toggle("完成时播放轻提示音", isOn: $store.data.preferences.sound)
                HStack {
                    Button(store.data.preferences.notifications ? "重新检查通知权限" : "开启计时和日程通知") { store.requestNotifications() }
                    if store.data.preferences.notifications {
                        Button("关闭通知") { store.data.preferences.notifications = false; store.refreshReminders() }
                        Text("已获允许").font(.caption).foregroundStyle(Palette.sage)
                    }
                }

            }
            Card(title: "存档与备份", icon: "externaldrive") {
                Text("本机自动保存 · 备份包含日记正文。").font(.callout).foregroundStyle(Palette.muted)
                VStack(alignment: .leading, spacing: 10) {
                    Button("导出备份…") { store.exportData() }.buttonStyle(PixelButtonStyle(primary: true))
                    Button("恢复备份…") { store.importData() }.buttonStyle(PixelButtonStyle())
                    Button("打开存档文件夹") { NSWorkspace.shared.open(store.file.deletingLastPathComponent()) }
                }
                Text("暮色小院 0.7 · 本机版").font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }
}
