import SwiftUI

struct RepeatScheduleEditor: View {
    @Binding var enabled: Bool
    @Binding var rule: RepeatRule
    @Binding var anchor: Date
    var calendar: Calendar
    var effective: Date
    var allowsOff = true
    @State private var customDays = false
    private var activeCount: Binding<Int> { Binding(get: { rule.continuousActiveDays ?? rule.activeDays.count }, set: { value in
        let rest = max(0, rule.cycleLength - rule.activeDays.count)
        guard value > 0, value + rest <= 10_000 else { return }
        rule = .workRest(active: value, rest: rest)
    }) }
    private var restCount: Binding<Int> { Binding(get: { rule.cycleLength - rule.activeDays.count }, set: { value in
        let active = max(1, rule.activeDays.count)
        guard value >= 0, active + value <= 10_000 else { return }
        rule = .workRest(active: active, rest: value)
    }) }
    private var activeField: some View {
        HStack(spacing: 7) { Text("连续执行"); TextField("执行天数", value: activeCount, format: .number).textFieldStyle(PixelTextFieldStyle()).frame(width: 68); Text("天") }
    }
    private var restField: some View {
        HStack(spacing: 7) { Text("再休息"); TextField("休息天数", value: restCount, format: .number).textFieldStyle(PixelTextFieldStyle()).frame(width: 68); Text("天") }
    }
    private func cycleDay(_ offset: Int) -> some View {
        let active = rule.activeDays.contains(offset)
        return VStack(spacing: 5) {
            Text("第\(offset+1)天").font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7)
            Text(active ? "执行" : "休息").font(.system(size: 12, weight: .medium))
        }.frame(maxWidth: .infinity).frame(height: 52)
            .foregroundStyle(active ? Palette.goldLight : Palette.muted)
            .background(PixelFrame(step: 1).fill(active ? Palette.moss : Palette.control))
            .overlay(PixelFrame(step: 1).strokeBorder(active ? Palette.gold : Palette.line, lineWidth: 1))
            .accessibilityElement(children: .ignore).accessibilityLabel("循环第 \(offset+1) 天").accessibilityValue(active ? "执行" : "休息")
    }
    private var weekdays: [Int] { (0..<7).map { (calendar.firstWeekday-1+$0)%7+1 } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if allowsOff { Toggle("重复", isOn: $enabled) } else { Text("周期").font(.callout) }
            if enabled {
                PixelSelect(selection: $rule.unit, items: [(.day, "间隔天数"), (.week, "按星期重复"), (.month, "按月重复"), (.cycle, "执行与休息循环")])
                if rule.unit == .cycle {
                    PixelTabs(selection: $customDays, items: [(false, "连续执行后休息"), (true, "逐天自定")])
                        .onChange(of: customDays) { _, custom in
                            if !custom, rule.continuousActiveDays == nil { rule = .workRest(active: max(1, rule.activeDays.count), rest: max(0, rule.cycleLength-rule.activeDays.count)) }
                        }
                    if !customDays {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { activeField; restField }
                            VStack(alignment: .leading, spacing: 8) { activeField; restField }
                        }
                        Text(rule.summary).font(.caption).foregroundStyle(Palette.goldLight)
                    } else {
                    HStack { Text("循环总天数"); TextField("天数", value: $rule.cycleLength, format: .number).textFieldStyle(PixelTextFieldStyle()).frame(width: 100).accessibilityLabel("自定义周期天数"); Text("天") }
                    }
                    Text(customDays ? "点选执行日；其余为休息日。下面从开始日期的第 1 天起，完成后重新循环。" : "下方为完整一轮；完成后回到第 1 天。可切到「逐天自定」选择任意执行日。").font(.caption).foregroundStyle(Palette.muted)
                    PixelScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                            ForEach(0..<max(0, min(10_000, rule.cycleLength)), id: \.self) { offset in
                                if customDays {
                                    Button { if !rule.activeDays.insert(offset).inserted { rule.activeDays.remove(offset) } } label: { cycleDay(offset) }.buttonStyle(.plain)
                                } else { cycleDay(offset) }
                            }
                        }
                    }.frame(maxHeight: 180)
                        .onChange(of: rule.cycleLength) { _, value in rule.activeDays = rule.activeDays.filter { $0 < value }; if rule.activeDays.isEmpty && value > 0 { rule.activeDays = [0] } }
                } else {
                    HStack { Text("间隔"); TextField("间隔", value: $rule.every, format: .number).textFieldStyle(PixelTextFieldStyle()).frame(width: 100); Text(rule.unit.rawValue) }
                    Text(rule.unit == .day ? "每隔 \(rule.every) 天执行 1 次；如需连续执行多天后休息，请选择「执行与休息循环」。" : rule.summary).font(.caption).foregroundStyle(Palette.muted)
                    if rule.unit == .week {
                        HStack(spacing: 5) {
                            ForEach(weekdays, id: \.self) { day in
                                Button(["日", "一", "二", "三", "四", "五", "六"][day-1]) { if !rule.weekdays.insert(day).inserted { rule.weekdays.remove(day) } }
                                    .buttonStyle(PixelButtonStyle(primary: rule.weekdays.contains(day))).accessibilityLabel("周"+["日", "一", "二", "三", "四", "五", "六"][day-1]).accessibilityValue(rule.weekdays.contains(day) ? "已选" : "未选")
                            }
                        }
                    }
                }
                PixelDatePicker(title: "开始日期", selection: $anchor)
                Text("第 1 天是 " + CalendarDates.key(anchor, calendar: calendar) + "；新周期从 " + CalendarDates.key(effective, calendar: calendar) + " 生效").font(.caption).foregroundStyle(Palette.muted)
            }
        }.onAppear { customDays = rule.continuousActiveDays == nil }
        .onChange(of: rule.unit) { _, unit in
            if unit == .cycle, rule.cycleLength == 4, rule.activeDays == [0, 1, 2] { rule = .workRest(active: 14, rest: 1) }
            customDays = rule.continuousActiveDays == nil
            rule.every = max(1, rule.every); rule.cycleLength = max(1, rule.cycleLength)
            if rule.weekdays.isEmpty { rule.weekdays = [calendar.component(.weekday, from: anchor)] }
            if rule.activeDays.isEmpty { rule.activeDays = [0] }
        }
    }
}

struct ReminderMessagesEditor: View {
    @Binding var library: ReminderTextLibrary
    @State private var draft = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("激励语 · \(library.phrases.count) 条").font(.callout)
                Spacer()
            }
            PixelScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach($library.phrases) { $phrase in
                        HStack(alignment: .top) {
                            TextField("激励语", text: $phrase.text, axis: .vertical).lineLimit(1...4).textFieldStyle(PixelTextFieldStyle())
                            if phrase.text.count > ReminderTextLibrary.maximumTextLength { Text("内容过长").font(.caption).foregroundStyle(Palette.clay) }
                            Button { library.phrases.removeAll { $0.id == phrase.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel("删除激励语")
                        }
                    }
                }
            }.frame(minHeight: 0, maxHeight: library.phrases.isEmpty ? 0 : 170)
            HStack(alignment: .top) {
                TextField("添加一条激励语", text: $draft, axis: .vertical).lineLimit(1...4).textFieldStyle(PixelTextFieldStyle())
                Button("添加") { library.phrases.append(ReminderPhrase(text: draft)); library.normalize(); draft = "" }.buttonStyle(PixelButtonStyle()).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.count > ReminderTextLibrary.maximumTextLength)
            }
        }
    }
}
