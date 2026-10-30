import SwiftUI

struct RepeatScheduleEditor: View {
    @Binding var enabled: Bool
    @Binding var rule: RepeatRule
    @Binding var anchor: Date
    var calendar: Calendar
    var effective: Date
    var allowsOff = true
    private var weekdays: [Int] { (0..<7).map { (calendar.firstWeekday-1+$0)%7+1 } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if allowsOff { Toggle("重复", isOn: $enabled) } else { Text("周期").font(.callout) }
            if enabled {
                PixelSelect(selection: $rule.unit, items: RepeatUnit.allCases.map { ($0, $0 == .cycle ? $0.rawValue : "每 N " + $0.rawValue) })
                if rule.unit == .cycle {
                    HStack { Text("自定义周期"); TextField("天数", value: $rule.cycleLength, format: .number).textFieldStyle(PixelTextFieldStyle()).frame(width: 100).accessibilityLabel("自定义周期天数"); Text("天") }
                    PixelScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                            ForEach(0..<max(0, min(10_000, rule.cycleLength)), id: \.self) { offset in
                                Button("\(offset+1)") { if !rule.activeDays.insert(offset).inserted { rule.activeDays.remove(offset) } }
                                    .buttonStyle(PixelButtonStyle(primary: rule.activeDays.contains(offset))).accessibilityLabel("循环第 \(offset+1) 天").accessibilityValue(rule.activeDays.contains(offset) ? "执行" : "休息")
                            }
                        }
                    }.frame(maxHeight: 180)
                        .onChange(of: rule.cycleLength) { _, value in rule.activeDays = rule.activeDays.filter { $0 < value }; if rule.activeDays.isEmpty && value > 0 { rule.activeDays = [0] } }
                } else {
                    HStack { Text("间隔"); TextField("间隔", value: $rule.every, format: .number).textFieldStyle(PixelTextFieldStyle()).frame(width: 100); Text(rule.unit.rawValue) }
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
                Text("新周期从 " + effective.formatted(.dateTime.year().month().day()) + " 生效").font(.caption).foregroundStyle(Palette.muted)
            }
        }.onChange(of: rule.unit) { _, _ in
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
