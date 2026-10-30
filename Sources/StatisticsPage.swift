import SwiftUI
import Charts

struct StatsPage: View {
    @ObservedObject var store: GardenStore
    @State private var range: StatsRange = .week
    @State private var weekDate = Date()
    @State private var monthDate = Date()
    @State private var yearDate = Date()
    private var date: Date { range == .week ? weekDate : (range == .month ? monthDate : yearDate) }
    private var period: StatsPeriod { StatsPeriod(date: date, range: range, calendar: store.calendar) }
    private var current: Bool { period.contains(store.now) }
    private var year: Int { store.calendar.component(.year, from: date) }
    private var month: Int { store.calendar.component(.month, from: monthDate) }
    private var yearBinding: Binding<Int> {
        Binding(get: { year }, set: { value in
            if range == .year { yearDate = CalendarDates.replacingMonth(of: yearDate, year: value, month: 1, calendar: store.calendar) }
            else { monthDate = CalendarDates.replacingMonth(of: monthDate, year: value, month: month, calendar: store.calendar) }
        })
    }
    private var monthBinding: Binding<Int> {
        Binding(get: { month }, set: { monthDate = CalendarDates.replacingMonth(of: monthDate, year: year, month: $0, calendar: store.calendar) })
    }
    private var periodName: String { (current ? "本" : "这一") + range.rawValue }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelTabs(selection: $range, items: [(.week, "周"), (.month, "月"), (.year, "年")]).frame(width: 220)
            periodContent.id(range)
        }
    }
    private var periodContent: some View {
        let summary = StatsSummary(data: store.data, period: period)
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(periodName).font(.title2).foregroundStyle(Palette.goldLight)
                Spacer()
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(PixelButtonStyle()).accessibilityLabel("上一" + range.rawValue)
                Button { shift(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(PixelButtonStyle()).accessibilityLabel("下一" + range.rawValue)
            }
            Text(period.title).font(.callout).foregroundStyle(Palette.muted)
            HStack {
                Button("回到今天") { resetDate() }.buttonStyle(PixelButtonStyle()).disabled(current)
                Spacer(minLength: 8)
                if range != .week {
                    PixelSelect(selection: yearBinding, items: Array(min(1900, year)...max(2100, year)).map { ($0, "\($0) 年") }).frame(width: 110)
                }
                if range == .month { PixelSelect(selection: monthBinding, items: (1...12).map { ($0, "\($0) 月") }).frame(width: 80) }
            }
            if range == .week { PixelDatePicker(title: "周内日期", selection: $weekDate) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)], alignment: .leading, spacing: 10) {
                Metric(title: periodName + "专注", value: "\(Int(summary.seconds / 60)) 分钟", foot: "\(summary.sessions) 段专注")
                Metric(title: periodName + "休息", value: "\(Int(summary.restSeconds / 60)) 分钟", foot: "\(summary.restSessions) 段休息 · 暂停 \(Int(summary.pausedSeconds / 60)) 分钟")
                Metric(title: periodName + "操作", value: "\(compactActionCount(summary.actions)) 次", foot: "键盘 \(compactActionCount(summary.keys)) · 鼠标 \(compactActionCount(summary.clicks))")
                    .help("\(summary.actions.formatted()) 次 · 键盘 \(summary.keys.formatted()) 次 · 鼠标 \(summary.clicks.formatted()) 次")
                Metric(title: periodName + "日记", value: "\(summary.diaryDays) 天", foot: "\(summary.characters) 个字符")
            }
            if range == .year { yearCharts } else { dayCharts(summary) }
            ViewThatFits(in: .horizontal) {
                HStack { totals(summary) }
                VStack(alignment: .leading, spacing: 8) { totals(summary) }
            }.font(.callout)
        }.padding(18).magicSurface(Palette.card, strong: true)
    }
    @ViewBuilder private func totals(_ summary: StatsSummary) -> some View {
        Text("任务 \(summary.completedTasks) 件"); Spacer(minLength: 0)
        Text("签到 \(summary.habitDays) 天"); Spacer(minLength: 0)
        Text("习惯打卡 \(summary.habitCompletions) 次")
    }
    private var yearCharts: some View {
        let months = StatsMonth.months(data: store.data, year: period)
        return VStack(alignment: .leading, spacing: 16) {
            Text("十二个月 · 专注与休息（分钟）").font(.headline)
            Chart(months) { item in
                BarMark(x: .value("月份", item.date, unit: .month), y: .value("分钟", item.summary.seconds / 60))
                    .foregroundStyle(by: .value("记录", "专注")).position(by: .value("记录", "专注"))
                BarMark(x: .value("月份", item.date, unit: .month), y: .value("分钟", item.summary.restSeconds / 60))
                    .foregroundStyle(by: .value("记录", "休息")).position(by: .value("记录", "休息"))
            }.chartForegroundStyleScale(["专注": Palette.sage, "休息": Palette.goldLight])
                .chartXAxis { AxisMarks(values: months.map(\.date)) { AxisValueLabel(format: .dateTime.month()); AxisGridLine() } }
                .frame(height: 220)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), alignment: .leading)], spacing: 10) {
                ForEach(months) { item in
                    Button { monthDate = item.date; range = .month } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.date.formatted(.dateTime.month(.wide))).fontWeight(.semibold)
                            Text("专注 \(Int(item.summary.seconds / 60)) 分 · 休息 \(Int(item.summary.restSeconds / 60)) 分").font(.caption)
                            Text("任务 \(item.summary.completedTasks) · 打卡 \(item.summary.habitCompletions) · 日记 \(item.summary.diaryDays)").font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(PixelButtonStyle()).accessibilityLabel(item.date.formatted(.dateTime.year().month()) + "统计")
                }
            }
        }
    }
    private func dayCharts(_ summary: StatsSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("专注与休息 · 分钟").font(.headline)
            Chart(summary.days) { day in
                BarMark(x: .value("日期", day.date, unit: .day), y: .value("分钟", day.minutes))
                    .foregroundStyle(by: .value("记录", "专注")).position(by: .value("记录", "专注"))
                BarMark(x: .value("日期", day.date, unit: .day), y: .value("分钟", day.restSeconds / 60))
                    .foregroundStyle(by: .value("记录", "休息")).position(by: .value("记录", "休息"))
            }.frame(height: 175).chartXScale(domain: period.start...period.end)
                .chartForegroundStyleScale(["专注": Palette.sage, "休息": Palette.goldLight])
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 5)) { _ in AxisValueLabel(format: .dateTime.month().day()); AxisGridLine() } }
                .chartYScale(domain: 0...max(30, (summary.days.map { max($0.minutes, $0.restSeconds / 60) }.max() ?? 0) * 1.1))
            Text("操作 · 次数").font(.headline)
            Chart(summary.days) { day in
                BarMark(x: .value("日期", day.date, unit: .day), y: .value("操作次数", day.actions)).foregroundStyle(Palette.clay.opacity(0.75))
            }.frame(height: 175).chartXScale(domain: period.start...period.end)
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 5)) { _ in AxisValueLabel(format: .dateTime.month().day()); AxisGridLine() } }
                .chartYScale(domain: 0...max(10, Double(summary.days.map(\.actions).max() ?? 0) * 1.1))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), alignment: .leading)], spacing: 8) {
                ForEach(summary.days) { day in
                    Button { openDay(day.date) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(day.date.formatted(.dateTime.month().day().weekday(.abbreviated))).fontWeight(.medium)
                            Text("专注 \(Int(day.minutes)) 分 · 休息 \(Int(day.restSeconds / 60)) 分").font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(PixelButtonStyle()).accessibilityLabel("打开" + day.date.formatted(date: .complete, time: .omitted) + "日程")
                }
            }
        }
    }
    private func openDay(_ day: Date) { store.journalDate = day; store.selectedPage = "日程"; store.pet?.openTool("日程") }
    private func resetDate() {
        switch range { case .week: weekDate = store.now; case .month: monthDate = store.now; case .year: yearDate = store.now }
    }
    private func shift(_ amount: Int) {
        switch range { case .week: weekDate = period.shifted(amount); case .month: monthDate = period.shifted(amount); case .year: yearDate = period.shifted(amount) }
    }
}
