import SwiftUI

enum CalendarDisplay: String, CaseIterable { case month = "月", week = "周" }

struct PixelCalendar: View {
    @Binding var selection: Date
    @Environment(\.calendar) private var calendar
    var display: CalendarDisplay = .month
    var minimum: Date? = nil
    var maximum: Date? = nil
    var compact = false
    var markers: (Date) -> [Color] = { _ in [] }
    var onSelect: () -> Void = {}
    @State private var visible = Date()
    private var week: Bool { display == .week }
    private var cells: [Date?] { CalendarDates.days(in: visible, week: week, calendar:calendar) }
    private var title: String {
        if week {
            let first = CalendarDates.weekStart(visible, calendar:calendar)
            let last = calendar.date(byAdding: .day, value: 6, to: first)!
            return first.formatted(.dateTime.year().month().day()) + " — " + last.formatted(.dateTime.month().day())
        }
        return visible.formatted(.dateTime.year().month(.wide))
    }
    var body: some View {
        VStack(spacing: compact ? 10 : 14) {
            HStack(spacing: 7) {
                Text(title).font(.system(size: compact ? 14 : 17, weight: .semibold)).foregroundStyle(Palette.goldLight)
                Spacer(minLength: 4)
                Button { move(-1) } label: { Image(systemName: "chevron.left") }.help(week ? "上一周" : "上个月").disabled(!canMove(-1))
                Button { move(1) } label: { Image(systemName: "chevron.right") }.help(week ? "下一周" : "下个月").disabled(!canMove(1))
            }
            HStack {
                Button("回到今天") { visible = Date(); choose(Date()) }
                    .disabled(!allowed(Date()) || (calendar.isDateInToday(selection) && cells.compactMap { $0 }.contains { calendar.isDateInToday($0) }))
                Spacer()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach((0..<7).map { ["日", "一", "二", "三", "四", "五", "六"][(calendar.firstWeekday-1+$0)%7] }, id: \.self) {
                    Text($0).font(.system(size: 11)).foregroundStyle(Palette.muted).frame(height: 22)
                }
                ForEach(cells.indices, id: \.self) { index in
                    if let day = cells[index] { dayButton(day) }
                    else { Color.clear.frame(height: compact ? 36 : 52) }
                }
            }
        }
        .onAppear { visible = selection }
        .onChange(of: selection) { _, value in visible = value }
        .onChange(of: display) { _, _ in visible = selection }
    }
    private func dayButton(_ day: Date) -> some View {
        let active = calendar.isDate(day, inSameDayAs: selection)
        return Button { choose(day) } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))").font(.system(size: compact ? 12 : 14, weight: calendar.isDateInToday(day) ? .bold : .regular))
                HStack(spacing: 3) {
                    ForEach(Array(markers(day).prefix(3).enumerated()), id: \.offset) { _, color in Rectangle().fill(color).frame(width: 4, height: 3) }
                }.frame(height: 4)
            }.frame(maxWidth: .infinity).frame(height: compact ? 36 : 52)
                .background(PixelFrame(step: 1).fill(active ? Palette.moss : Palette.control.opacity(0.55)))
                .overlay(PixelFrame(step: 1).strokeBorder(active ? Palette.gold : calendar.isDateInToday(day) ? Palette.gold.opacity(0.5) : Palette.line.opacity(0.5), lineWidth: 1))
                .foregroundStyle(active ? Palette.goldLight : Palette.ink).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!allowed(day)).opacity(allowed(day) ? 1 : 0.3)
            .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
            .accessibilityValue(markers(day).isEmpty ? "" : "有记录")
            .accessibilityAddTraits(active ? [.isSelected] : [])
    }
    private func allowed(_ day: Date) -> Bool { CalendarDates.allowed(day, minimum: minimum, maximum: maximum) }
    private func choose(_ day: Date) {
        guard allowed(day) else { return }
        selection = CalendarDates.replacingDay(of: selection, with: day)
        onSelect()
    }
    private func target(_ step: Int) -> Date {
        let anchor = week ? CalendarDates.weekStart(visible, calendar:calendar) : CalendarDates.monthStart(visible, calendar:calendar)
        return calendar.date(byAdding: week ? .weekOfYear : .month, value: step, to: anchor)!
    }
    private func canMove(_ step: Int) -> Bool {
        CalendarDates.days(in: target(step), week: week, calendar:calendar).compactMap { $0 }.contains(where: allowed)
    }
    private func move(_ step: Int) { visible = target(step) }
}

struct PixelDatePicker: View {
    var title: String
    @Binding var selection: Date
    var minimum: Date? = nil
    var maximum: Date? = nil
    @State private var showing = false
    var body: some View {
        HStack(spacing: 12) {
            if !title.isEmpty { Text(title).foregroundStyle(Palette.muted) }
            Button { showing.toggle() } label: {
                HStack(spacing: 9) {
                    PixelIcon(name: "calendar", size: 19)
                    Text(selection.formatted(.dateTime.year().month().day())).monospacedDigit()
                    Image(systemName: "chevron.down").font(.system(size: 9))
                }
            }.buttonStyle(PixelButtonStyle()).accessibilityLabel(title.isEmpty ? "选择日期" : title)
                .popover(isPresented: $showing, arrowEdge: .bottom) {
                    PixelCalendar(selection: $selection, minimum: minimum, maximum: maximum, compact: true, onSelect: { showing = false })
                        .padding(16).frame(width: 350).magicSurface(Palette.paper, strong: true).magicControls()
                }
        }
    }
}

struct PixelDateTimePicker: View {
    var title: String
    @Binding var selection: Date
    @State private var showingTime = false
    @State private var choosingHour = true
    private var timeText: String {
        String(format: "%02d:%02d", Calendar.current.component(.hour, from: selection), Calendar.current.component(.minute, from: selection))
    }
    var body: some View {
        HStack {
            PixelDatePicker(title: title, selection: $selection)
            Button(timeText) { showingTime.toggle() }
                .buttonStyle(PixelButtonStyle()).accessibilityLabel(title + "时间")
                .popover(isPresented: $showingTime, arrowEdge: .bottom) {
                    VStack(spacing: 12) {
                        Text(timeText).font(.title2).monospacedDigit().foregroundStyle(Palette.goldLight)
                        PixelTabs(selection: $choosingHour, items: [(true, "时"), (false, "分")])
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                            ForEach(0..<(choosingHour ? 24 : 60), id: \.self) { value in
                                Button(String(format: "%02d", value)) { setTime(value) }
                                    .buttonStyle(PixelButtonStyle(primary: Calendar.current.component(choosingHour ? .hour : .minute, from: selection) == value))
                            }
                        }
                        Button("完成") { showingTime = false }.buttonStyle(PixelButtonStyle(primary: true))
                    }.padding(16).frame(width: 310).magicSurface(Palette.paper, strong: true).magicControls()
                }
        }
    }
    private func setTime(_ value: Int) {
        let hour = choosingHour ? value : Calendar.current.component(.hour, from: selection)
        let minute = choosingHour ? Calendar.current.component(.minute, from: selection) : value
        if let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: selection) { selection = date }
        if choosingHour { choosingHour = false }
    }
}
