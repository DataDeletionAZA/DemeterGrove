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
    @State private var range: StatsRange = .week
    @State private var date = Date()
    private var period: StatsPeriod { StatsPeriod(date: date, range: range) }
    private var summary: StatsSummary { StatsSummary(data: store.data, period: period) }
    private var year: Int { Calendar.current.component(.year, from: date) }
    private var month: Int { Calendar.current.component(.month, from: date) }
    private var years: [Int] { Array(min(1900, year)...max(2100, year)) }
    private var yearBinding: Binding<Int> {
        Binding(get: { year }, set: { date = CalendarDates.replacingMonth(of: date, year: $0, month: month) })
    }
    private var monthBinding: Binding<Int> {
        Binding(get: { month }, set: { date = CalendarDates.replacingMonth(of: date, year: year, month: $0) })
    }
    var body: some View {
        let summary = summary
        let totalKeys = store.data.keys.values.reduce(0,+)
        let totalClicks = (store.data.mouseClicks ?? [:]).values.reduce(0,+)
        VStack(spacing: 20) {
            HStack(spacing: 13) {
                Metric(title: "累计专注", value: "\(Int(store.data.totalFocus / 60)) 分钟", foot: "\(store.data.sessions.count) 段专注")
                Metric(title: "累计操作", value: "\(compactActionCount(store.data.totalActions)) 次", foot: "键盘 \(compactActionCount(totalKeys)) · 鼠标 \(compactActionCount(totalClicks))")
                    .help("累计 \(store.data.totalActions.formatted()) 次 · 键盘 \(totalKeys.formatted()) 次 · 鼠标 \(totalClicks.formatted()) 次")
                Metric(title: "日记天数", value: "\(store.data.diaries.values.filter { !$0.text.isEmpty }.count) 天", foot: "\(store.data.diaries.values.reduce(0) { $0 + $1.characters }) 个非空白字符")
            }
            Card(title: "统计范围", icon: "calendar") {
                HStack {
                    Text(period.title).font(.headline).foregroundStyle(Palette.goldLight)
                    Spacer(minLength: 6)
                    PixelTabs(selection: $range, items: [(.week, "周"), (.month, "月")]).frame(width: 110)
                }
                HStack(spacing: 8) {
                    PixelSelect(selection: yearBinding, items: years.map { ($0, "\($0) 年") }).frame(width: 120)
                    PixelSelect(selection: monthBinding, items: (1...12).map { ($0, "\($0) 月") }).frame(width: 90)
                    Spacer(minLength: 4)
                    Button { date = period.shifted(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(PixelButtonStyle()).accessibilityLabel(range == .week ? "上一周" : "上个月")
                    Button("今天") { date = store.now }.buttonStyle(PixelButtonStyle())
                    Button { date = period.shifted(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(PixelButtonStyle()).accessibilityLabel(range == .week ? "下一周" : "下个月")
                }
                if range == .week { PixelDatePicker(title: "周内日期", selection: $date) }
            }
            HStack(spacing: 13) {
                Metric(title: "本\(range.rawValue)专注", value: "\(Int(summary.seconds / 60)) 分钟", foot: "\(summary.sessions) 段专注")
                Metric(title: "本\(range.rawValue)操作", value: "\(compactActionCount(summary.actions)) 次", foot: "键盘 \(compactActionCount(summary.keys)) · 鼠标 \(compactActionCount(summary.clicks))")
                    .help("本\(range.rawValue) \(summary.actions.formatted()) 次 · 键盘 \(summary.keys.formatted()) 次 · 鼠标 \(summary.clicks.formatted()) 次")
                Metric(title: "本\(range.rawValue)日记", value: "\(summary.diaryDays) 天", foot: "\(summary.characters) 个非空白字符")
            }
            Card(title: "每天的专注 · 分钟", icon: "timer") {
                Chart(summary.days) { day in
                    BarMark(x: .value("日期", day.date, unit: .day), y: .value("专注分钟", day.minutes)).foregroundStyle(Palette.sage).cornerRadius(0)
                }.frame(height: 175)
                    .chartXScale(domain: period.start...period.end)
                    .chartXAxis { AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 5)) { _ in AxisValueLabel(format: .dateTime.month().day()); AxisGridLine() } }
                    .chartYScale(domain: 0...max(30, (summary.days.map(\.minutes).max() ?? 0) * 1.1))
            }
            Card(title: "每天的操作 · 次数", icon: "keyboard") {
                Chart(summary.days) { day in
                    BarMark(x: .value("日期", day.date, unit: .day), y: .value("操作次数", day.actions)).foregroundStyle(Palette.clay.opacity(0.75)).cornerRadius(0)
                }.frame(height: 175)
                    .chartXScale(domain: period.start...period.end)
                    .chartXAxis { AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 5)) { _ in AxisValueLabel(format: .dateTime.month().day()); AxisGridLine() } }
                    .chartYScale(domain: 0...max(10, Double(summary.days.map(\.actions).max() ?? 0) * 1.1))
            }
            Card(title: "本\(range.rawValue)完成", icon: "checkmark.seal") {
                HStack { Text("任务 \(summary.completedTasks) 件"); Spacer(); Text("签到 \(summary.habitDays) 天"); Spacer(); Text("打卡 \(summary.habitCompletions) 次") }.font(.callout)
            }
            Card(title: "累计完成", icon: "checkmark.seal") {
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
                    Text("今天 \(compactActionCount(store.todayActions)) 次 · \(store.inputStatus)").font(.callout).foregroundStyle(Palette.sage)
                        .help("今天 \(store.todayActions.formatted()) 次")
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
                Text("暮色小院 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版") · 本机版").font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }
}
