import SwiftUI

struct SchedulePage: View {
    @ObservedObject var store: GardenStore
    @State private var adding = false
    @State private var category = "全部记录"
    @State private var status = "全部状态"
    private var selected: Date { store.journalDate }
    private var records: DailyRecords { DailyRecords(date: selected, calendar: store.calendar, rolloverMinutes: store.dayBoundary.rolloverMinutes) }
    private var events: [Appointment] { records.events(in: store.data).filter { matches($0.end <= store.now ? "已完成" : "待处理") } }
    private var tasks: [TaskOccurrence] { records.tasks(in: store.data).filter { matches($0.completedAt == nil ? "待处理" : "已完成") } }
    private var habits: [HabitDayRecord] { records.habits(in: store.data).filter { matches($0.completed ? "已完成" : ($0.entry?.status.title ?? "待处理")) } }
    private var sessions: [FocusSession] { records.sessions(in: store.data).filter { _ in matches("已完成") } }
    private func matches(_ value: String) -> Bool { status == "全部状态" || status == value }
    private func shows(_ value: String) -> Bool { category == "全部记录" || category == value }
    var body: some View {
        VStack(spacing: 20) {
            Card(title: "") {
                PixelCalendar(selection: $store.journalDate, markers: markers, onBrowse: store.stopFollowingJournalToday)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { legend }
                    VStack(alignment: .leading, spacing: 6) { legend }
                }.font(.system(size: 10))
            }
            Card(title: "") {
                ViewThatFits(in: .horizontal) {
                    HStack { dayTitle; Spacer(); addButton }
                    VStack(alignment: .leading, spacing: 12) { dayTitle; addButton }
                }
                HStack(spacing: 10) {
                    PixelSelect(selection: $category, items: ["全部记录", "日程", "任务", "习惯", "专注与休息", "日记"].map { ($0, $0) }).frame(maxWidth: 180)
                    PixelSelect(selection: $status, items: ["全部状态", "待处理", "已完成", "待审核", "待补充"].map { ($0, $0) }).frame(maxWidth: 160)
                    Spacer(minLength: 0)
                }
                if shows("日程") {
                    recordHeading("日程", count: events.count)
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.end <= store.now ? "已结束" : (event.start <= store.now ? "进行中" : "未开始")).font(.caption).foregroundStyle(Palette.muted)
                            EventRow(store: store, event: event)
                        }
                    }
                }
                if shows("任务") {
                    recordHeading("任务", count: tasks.count)
                    ForEach(tasks) { occurrence in TaskRow(store: store, occurrence: occurrence) }
                }
                if shows("习惯") {
                    recordHeading("习惯记录", count: habits.count)
                    ForEach(habits) { record in HabitRecordRow(store: store, record: record, date: selected) }
                }
                if shows("专注与休息") {
                    let visible = sessions
                    recordHeading("专注与休息", count: visible.count)
                    ForEach(visible) { session in SessionRecordRow(store: store, session: session, day: records.interval) }
                }
                if shows("日记") && matches("已完成") { diaryCard }
            }
        }.environment(\.calendar, store.calendar).environment(\.dayBoundary, store.dayBoundary).environment(\.timeZone, store.calendar.timeZone)
        .sheet(isPresented: $adding) {
            EventEditor(store: store, event: Appointment(title: "", start: records.interval.start, end: records.interval.start.addingTimeInterval(3600)))
        }
    }
    private var dayTitle: some View { Text(CalendarDates.key(selected, calendar: store.calendar)).fontWeight(.semibold) }
    private var addButton: some View { Button("添加日程", systemImage: "plus") { adding = true }.buttonStyle(PixelButtonStyle(primary: true)) }
    @ViewBuilder private var legend: some View {
        Label("日程", systemImage: "square.fill").foregroundStyle(Palette.clay)
        Label("任务", systemImage: "square.fill").foregroundStyle(Palette.sage)
        Label("日记", systemImage: "square.fill").foregroundStyle(Palette.goldLight)
        Label("习惯", systemImage: "square.fill").foregroundStyle(Color.purple.opacity(0.8))
        Label("计时", systemImage: "square.fill").foregroundStyle(Color.blue.opacity(0.8))
    }
    private func markers(_ day: Date) -> [Color] {
        let item = DailyRecords(date: day, calendar: store.calendar, rolloverMinutes: store.dayBoundary.rolloverMinutes)
        var marks: [Color] = []
        if !item.events(in: store.data).isEmpty { marks.append(Palette.clay) }
        if !item.tasks(in: store.data).isEmpty { marks.append(Palette.sage) }
        if let diary = store.data.diaries[item.key], !diary.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { marks.append(Palette.goldLight) }
        if !item.habits(in: store.data).isEmpty { marks.append(Color.purple.opacity(0.8)) }
        if !item.sessions(in: store.data).isEmpty { marks.append(Color.blue.opacity(0.8)) }
        return marks
    }
    private func recordHeading(_ title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.top, 8)
            Text(title + " · \(count)").font(.headline).foregroundStyle(Palette.goldLight)
            if count == 0 { Text("没有符合筛选的记录").font(.caption).foregroundStyle(Palette.muted) }
        }
    }
    private var diaryCard: some View {
        let entry = store.data.diaries[records.key]
        return VStack(alignment: .leading, spacing: 12) {
            Divider().padding(.top, 8)
            Text("当日日记").font(.headline).foregroundStyle(Palette.goldLight)
            HStack(alignment: .top, spacing: 13) {
                if let entry, !entry.text.isEmpty {
                    MoodArtwork(symbol: entry.moodSymbol ?? MoodChoice.symbol(for: entry.mood), image: entry.moodImage)
                    Text(entry.text).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                } else { Text("这一天还没有记录").foregroundStyle(Palette.muted); Spacer() }
                Button(entry?.text.isEmpty == false ? "打开日记" : "写日记") { store.openJournal(date: selected) }
                    .buttonStyle(PixelButtonStyle()).disabled(store.calendar.startOfDay(for: selected) > store.today)
            }
        }
    }
}

struct HabitRecordRow: View {
    @ObservedObject var store: GardenStore
    var record: HabitDayRecord
    var date: Date
    @State private var showing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.habit.title + (record.habit.archivedAt == nil ? "" : " · 已归档")).fontWeight(.medium)
                Spacer()
                Text(record.completed ? "已完成" : (record.entry?.status.title ?? "已记录")).font(.caption).foregroundStyle(Palette.goldLight)
                Button("回看") { showing = true }.buttonStyle(PixelButtonStyle()).accessibilityLabel("回看习惯：" + record.habit.title)
            }
            if let entry = record.entry {
                if !entry.text.isEmpty { Text(entry.text).lineLimit(3).font(.callout) }
                if let image = entry.image, let picture = NSImage(data: image) { Image(nsImage: picture).resizable().scaledToFit().frame(maxWidth: 160, maxHeight: 100) }
                Text("提交：" + store.dayBoundary.timestamp(entry.submittedAt)).font(.caption).foregroundStyle(Palette.muted)
                if let reviewedAt = entry.reviewedAt { Text("审核：" + store.dayBoundary.timestamp(reviewedAt)).font(.caption).foregroundStyle(Palette.muted) }
                if let feedback = entry.feedback, !feedback.isEmpty { Text("反馈：" + feedback).lineLimit(3).font(.callout) }
            } else { Text("已完成 · 无材料记录").font(.caption).foregroundStyle(Palette.muted) }
        }.padding(.vertical, 8)
        .sheet(isPresented: $showing) { HabitEvidenceEditor(store: store, habitID: record.habit.id, date: date) }
    }
}

struct SessionRecordRow: View {
    @ObservedObject var store: GardenStore
    var session: FocusSession
    var day: DateInterval
    @State private var showing = false
    private var pauses: [FocusInterval] { (session.pauseIntervals ?? []).filter { $0.beganAt < day.end && $0.endedAt > day.start } }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(session.title.isEmpty ? session.kind.rawValue : session.title).fontWeight(.medium)
                    Text("\(session.kind == .rest ? "休息" : "专注") · 当日 \(Int(session.recordedSeconds(in: day) / 60)) 分 \(Int(session.recordedSeconds(in: day)) % 60) 秒").font(.caption).foregroundStyle(Palette.sage)
                }
                Spacer()
                Button("回看") { showing = true }.buttonStyle(PixelButtonStyle()).accessibilityLabel("回看计时：" + session.title)
            }
            if let start = session.beganAt, let end = session.endedAt {
                Text(store.dayBoundary.timestamp(start) + " — " + store.dayBoundary.timestamp(end)).font(.caption).foregroundStyle(Palette.muted)
            } else { Text("结束：" + store.dayBoundary.timestamp(session.date) + " · 起止时间未记录").font(.caption).foregroundStyle(Palette.muted) }
            if let segments = session.segments {
                ForEach(Array(segments.filter { $0.beganAt < day.end && $0.endedAt > day.start }.enumerated()), id: \.offset) { _, segment in
                    Text((session.kind == .rest ? "休息 · " : "专注 · ") + store.dayBoundary.timestamp(max(segment.beganAt, day.start)) + " — " + store.dayBoundary.timestamp(min(segment.endedAt, day.end))).font(.caption).foregroundStyle(Palette.sage)
                }
            }
            ForEach(Array(pauses.enumerated()), id: \.offset) { _, pause in
                Text("暂停 · " + store.dayBoundary.timestamp(max(pause.beganAt, day.start)) + " — " + store.dayBoundary.timestamp(min(pause.endedAt, day.end))).font(.caption).foregroundStyle(Palette.muted)
            }
            if let mood = session.mood, !mood.isEmpty { Text("心情：" + mood).font(.caption).foregroundStyle(Palette.muted) }
            if let reviewedAt = session.aiReviewedAt { Text("评价：" + store.dayBoundary.timestamp(reviewedAt)).font(.caption).foregroundStyle(Palette.muted) }
            if let notes = session.notes, !notes.isEmpty { Text(notes).lineLimit(3).font(.callout) }
            if let feedback = session.aiFeedback, !feedback.isEmpty { Text("反馈：" + feedback).lineLimit(3).font(.callout) }
        }.padding(.vertical, 8)
            .sheet(isPresented: $showing) { FocusSessionEditor(store: store, sessionID: session.id) }
    }
}

struct EventRow: View {
    @ObservedObject var store: GardenStore
    var event: Appointment
    @State private var editing = false
    @State private var deleting = false
    var body: some View {
        HStack(spacing: 14) {
            Rectangle().fill(Palette.clay.opacity(0.7)).frame(width: 3, height: 40)
            Button { editing = true } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title).fontWeight(.medium)
                    Text(store.dayBoundary.timestamp(event.start) + " — " + store.dayBoundary.timestamp(event.end))
                        .font(.caption).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help("编辑日程")
            if event.remind { Image(systemName: "bell").font(.caption).foregroundStyle(Palette.muted) }
            Button { deleting = true } label: { Image(systemName: "trash") }.buttonStyle(.plain).help("删除日程")
        }.padding(.vertical, 5)
            .sheet(isPresented: $editing) { EventEditor(store: store, event: event) }
            .alert("删除这条日程？", isPresented: $deleting) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) { store.data.events.removeAll { $0.id == event.id }; store.refreshReminders() }
            }
    }
}

struct EventEditor: View {
    @ObservedObject var store: GardenStore
    @State var event: Appointment
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("日程").font(.title2).fontWeight(.semibold)
            TextField("日程名称", text: $event.title).textFieldStyle(PixelTextFieldStyle())
            PixelDateTimePicker(title: "开始", selection: $event.start)
            PixelDateTimePicker(title: "结束", selection: $event.end)
            if event.end < event.start { Text("结束时间需要晚于开始时间。").foregroundStyle(.red).font(.caption) }
            Toggle("开始时提醒", isOn: $event.remind)
            TextField("备注", text: $event.notes, axis: .vertical).lineLimit(3...5).textFieldStyle(PixelTextFieldStyle())
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.clay) }
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    if store.upsert(event) { dismiss() }
                    else { error = store.error.isEmpty ? "日程未能保存，请检查填写内容后重试。" : store.error }
                }.keyboardShortcut(.defaultAction).buttonStyle(PixelButtonStyle(primary: true))
                    .disabled(event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || event.end < event.start)
            }
        }.padding(28).frame(width: 450).magicSurface(Palette.paper, strong: true).magicControls()
    }
}

struct DiaryPage: View {
    @ObservedObject var store: GardenStore
    @State private var display: CalendarDisplay = .month
    private var date: Date { store.journalDate }
    private var key: String { CalendarDates.key(date, calendar: store.calendar) }
    private var editableDate: Bool { store.calendar.startOfDay(for: date) <= store.today }
    private var diary: Diary { store.data.diaries[key] ?? Diary() }
    private var diaryBinding: Binding<Diary> {
        let entryKey = key
        return Binding(get: { store.data.diaries[entryKey] ?? Diary() }, set: { store.data.diaries[entryKey] = $0 })
    }
    private var textBinding: Binding<String> {
        let entryKey = key
        return Binding(get: { store.data.diaries[entryKey]?.text ?? "" }, set: { value in
            var item = store.data.diaries[entryKey] ?? Diary()
            item.text = value
            store.data.diaries[entryKey] = item
        })
    }
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                calendarCard.frame(width: 330)
                entryCard.frame(minWidth: 360)
            }
            VStack(spacing: 16) {
                calendarCard
                entryCard
            }
        }.environment(\.calendar, store.calendar).environment(\.dayBoundary, store.dayBoundary).environment(\.timeZone, store.calendar.timeZone)
        .onAppear {
            if !editableDate { store.journalDate = store.today }
        }
    }
    private var calendarCard: some View {
        Card(title: "") {
            HStack {
                Text("日记日历").font(.headline)
                Spacer()
                PixelTabs(selection: $display, items: [(.month, "月"), (.week, "周")]).frame(width: 110)
            }
            PixelCalendar(selection: $store.journalDate, display: display, maximum: store.today, compact: true, markers: { day in
                guard let entry = store.data.diaries[CalendarDates.key(day, calendar: store.calendar)], !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
                return [Palette.goldLight]
            }, onBrowse: store.stopFollowingJournalToday)
        }
    }
    private var entryCard: some View {
        Card(title: "") {
            HStack {
                Text(CalendarDates.key(date, calendar: store.calendar)).font(.headline).foregroundStyle(Palette.goldLight)
                Spacer()
                DiaryMoodPicker(diary: diaryBinding, saved: store.data.diaries.sorted { $0.key > $1.key }.map(\.value)).id(key).disabled(!editableDate)
            }
            Divider()
            TextEditor(text: textBinding).id(key).disabled(!editableDate).font(.system(size: 16)).lineSpacing(9).scrollContentBackground(.hidden)
                .frame(minHeight: 300).padding(8).background(Palette.card)
                .overlay(alignment: .topLeading) {
                    if diary.text.isEmpty {
                        Text(store.calendar.isDate(date, inSameDayAs: store.today) ? "今日还没有记录" : "这一天还没有记录")
                            .font(.system(size: 16)).foregroundStyle(Palette.muted.opacity(0.7)).padding(.horizontal, 14).padding(.top, 9).allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("\(key)的日记正文")
            HStack {
                Text("\(diary.characters) 字符（不含空白）")
                Spacer()
                Label(store.saveStatus, systemImage: "externaldrive")
            }.font(.caption).foregroundStyle(Palette.muted)
        }
    }
}
