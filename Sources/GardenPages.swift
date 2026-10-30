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
    @State private var weekDate = Date()
    @State private var monthDate = Date()
    private var date: Date { range == .week ? weekDate : monthDate }
    private var period: StatsPeriod { StatsPeriod(date:date,range:range,calendar:store.calendar) }
    private var current: Bool { period.contains(store.now) }
    private var year: Int { store.calendar.component(.year,from:monthDate) }
    private var month: Int { store.calendar.component(.month,from:monthDate) }
    private var yearBinding: Binding<Int> {
        Binding(get:{year},set:{monthDate=CalendarDates.replacingMonth(of:monthDate,year:$0,month:month,calendar:store.calendar)})
    }
    private var monthBinding: Binding<Int> {
        Binding(get:{month},set:{monthDate=CalendarDates.replacingMonth(of:monthDate,year:year,month:$0,calendar:store.calendar)})
    }
    private var periodName: String { (current ? "本":"这一")+range.rawValue }
    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            PixelTabs(selection:$range,items:[(.week,"周"),(.month,"月")]).frame(width:160).padding(.bottom,12)
            periodContent.id(range)
        }
    }
    private var periodContent: some View {
        let summary=StatsSummary(data:store.data,period:period)
        return VStack(alignment:.leading,spacing:18) {
            HStack {
                Text(periodName).font(.title2).foregroundStyle(Palette.goldLight)
                Spacer()
                Button { shift(-1) } label: {Image(systemName:"chevron.left")}
                    .accessibilityLabel(range == .week ? "上一周":"上个月")
                Button { shift(1) } label: {Image(systemName:"chevron.right")}
                    .accessibilityLabel(range == .week ? "下一周":"下个月")
            }
            Text(period.title).font(.callout).foregroundStyle(Palette.muted)
            HStack {
                Button("回到今天") { if range == .week {weekDate=store.now} else {monthDate=store.now} }.disabled(current)
                Spacer(minLength:8)
                if range == .month {
                    PixelSelect(selection:yearBinding,items:Array(min(1900,year)...max(2100,year)).map{($0,"\($0) 年")}).frame(width:110)
                    PixelSelect(selection:monthBinding,items:(1...12).map{($0,"\($0) 月")}).frame(width:80)
                }
            }
            HStack(spacing:10) {
                Metric(title:periodName+"专注",value:"\(Int(summary.seconds/60)) 分钟",foot:"\(summary.sessions) 段专注")
                Metric(title:periodName+"操作",value:"\(compactActionCount(summary.actions)) 次",foot:"键盘 \(compactActionCount(summary.keys)) · 鼠标 \(compactActionCount(summary.clicks))")
                    .help("\(summary.actions.formatted()) 次 · 键盘 \(summary.keys.formatted()) 次 · 鼠标 \(summary.clicks.formatted()) 次")
                Metric(title:periodName+"日记",value:"\(summary.diaryDays) 天",foot:"\(summary.characters) 个字符")
            }
            Text("专注 · 分钟").font(.headline)
            Chart(summary.days) {day in
                BarMark(x:.value("日期",day.date,unit:.day),y:.value("专注分钟",day.minutes)).foregroundStyle(Palette.sage)
            }.frame(height:175).chartXScale(domain:period.start...period.end)
                .chartXAxis {AxisMarks(values:.stride(by:.day,count:range == .week ? 1:5)) {_ in AxisValueLabel(format:.dateTime.month().day());AxisGridLine()}}
                .chartYScale(domain:0...max(30,(summary.days.map(\.minutes).max() ?? 0)*1.1))
            Text("操作 · 次数").font(.headline)
            Chart(summary.days) {day in
                BarMark(x:.value("日期",day.date,unit:.day),y:.value("操作次数",day.actions)).foregroundStyle(Palette.clay.opacity(0.75))
            }.frame(height:175).chartXScale(domain:period.start...period.end)
                .chartXAxis {AxisMarks(values:.stride(by:.day,count:range == .week ? 1:5)) {_ in AxisValueLabel(format:.dateTime.month().day());AxisGridLine()}}
                .chartYScale(domain:0...max(10,Double(summary.days.map(\.actions).max() ?? 0)*1.1))
            HStack {Text("任务 \(summary.completedTasks) 件");Spacer();Text("签到 \(summary.habitDays) 天");Spacer();Text("打卡 \(summary.habitCompletions) 次")}.font(.callout)
        }.padding(18).magicSurface(Palette.card,strong:true)
    }
    private func shift(_ amount:Int) {
        if range == .week {weekDate=period.shifted(amount)} else {monthDate=period.shifted(amount)}
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
            Card(title:"日历",icon:"calendar") {
                HStack {
                    Text("一周开始于")
                    PixelSelect(selection:Binding(get:{store.data.preferences.weekStartsOn ?? 2},set:{store.data.preferences.weekStartsOn=$0}),items:[(2,"周一"),(1,"周日")]).frame(width:150)
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
            AISettingsView(store:store)
            Card(title: "存档与备份", icon: "externaldrive") {
                Text(store.saveStatus).font(.callout).foregroundStyle(Palette.muted)
                VStack(alignment: .leading, spacing: 10) {
                    Button("导出备份…") { store.exportData() }.buttonStyle(PixelButtonStyle(primary: true))
                    Button("恢复备份…") { store.importData() }.buttonStyle(PixelButtonStyle())
                    Button("打开存档文件夹") { NSWorkspace.shared.open(store.file.deletingLastPathComponent()) }
                }
                Text("暮色小院 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版")").font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }
}
