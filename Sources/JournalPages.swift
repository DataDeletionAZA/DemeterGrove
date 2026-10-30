import SwiftUI

struct SchedulePage: View {
    @ObservedObject var store: GardenStore
    @State private var adding = false
    private var selected: Date { store.journalDate }
    private var events: [Appointment] { events(on: selected).sorted { $0.start < $1.start } }
    private func events(on date: Date) -> [Appointment] {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return store.data.events.filter { $0.start < end && $0.end >= start }
    }
    private var tasks: [GardenTask] {
        store.data.tasks.filter { $0.due.map { Calendar.current.isDate($0, inSameDayAs: selected) } ?? false }
    }
    var body: some View {
        VStack(spacing: 20) {
            Card(title: "") {
                PixelCalendar(selection: $store.journalDate, markers: { day in
                    var marks: [Color] = []
                    if !events(on: day).isEmpty { marks.append(Palette.clay) }
                    if store.data.tasks.contains(where: { $0.due.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false }) { marks.append(Palette.sage) }
                    if let diary = store.data.diaries[dayKey(day)], !diary.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { marks.append(Palette.goldLight) }
                    return marks
                })
                HStack(spacing: 16) {
                    Label("日程", systemImage: "square.fill").foregroundStyle(Palette.clay)
                    Label("任务", systemImage: "square.fill").foregroundStyle(Palette.sage)
                    Label("日记", systemImage: "square.fill").foregroundStyle(Palette.goldLight)
                }.font(.system(size: 10))
            }
            Card(title: "") {
                HStack {
                    Text(selected.formatted(.dateTime.month().day().weekday(.wide))).fontWeight(.semibold)
                    Spacer()
                    Button("添加日程", systemImage: "plus") { adding = true }.buttonStyle(PixelButtonStyle(primary: true))
                }
                if events.isEmpty && tasks.isEmpty { EmptyNote(text: "这一天还没有安排。") }
                ForEach(events) { event in EventRow(store: store, event: event) }
                if !tasks.isEmpty { Text("这一天截止的事项").font(.caption).foregroundStyle(Palette.muted).padding(.top, 6) }
                ForEach(tasks) { task in TaskRow(store: store, task: task) }
            }
            Card(title: "当日日记", icon: "book.closed") {
                let entry = store.data.diaries[dayKey(selected)]
                HStack(alignment: .top, spacing: 13) {
                    if let entry, !entry.text.isEmpty {
                        MoodArtwork(symbol: entry.moodSymbol ?? MoodChoice.symbol(for: entry.mood), image: entry.moodImage)
                        Text(entry.text).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                    } else { Text(Calendar.current.isDateInToday(selected) ? "今日还没有记录" : "这一天还没有记录").foregroundStyle(Palette.muted); Spacer() }
                    Button(entry?.text.isEmpty == false ? "打开日记" : "写日记") { store.openJournal(date: selected) }
                        .buttonStyle(PixelButtonStyle()).disabled(Calendar.current.startOfDay(for: selected) > Calendar.current.startOfDay(for: Date()))
                }
            }
        }.sheet(isPresented: $adding) {
            EventEditor(store: store, event: Appointment(title: "", start: selected, end: selected.addingTimeInterval(3600)))
        }
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
                    Text("\(event.start.formatted(.dateTime.hour().minute())) — \(event.end.formatted(.dateTime.month().day().hour().minute()))")
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
    private var key: String { dayKey(date) }
    private var editableDate: Bool { Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: Date()) }
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
        }.onAppear {
            if !editableDate { store.journalDate = Date() }
        }
    }
    private var calendarCard: some View {
        Card(title: "") {
            HStack {
                Text("日记日历").font(.headline)
                Spacer()
                PixelTabs(selection: $display, items: [(.month, "月"), (.week, "周")]).frame(width: 110)
            }
            PixelCalendar(selection: $store.journalDate, display: display, maximum: Date(), compact: true, markers: { day in
                guard let entry = store.data.diaries[dayKey(day)], !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
                return [Palette.goldLight]
            })
        }
    }
    private var entryCard: some View {
        Card(title: "") {
            HStack {
                Text(date.formatted(.dateTime.year().month().day().weekday(.wide))).font(.headline).foregroundStyle(Palette.goldLight)
                Spacer()
                DiaryMoodPicker(diary: diaryBinding, saved: store.data.diaries.sorted { $0.key > $1.key }.map(\.value)).id(key).disabled(!editableDate)
            }
            Divider()
            TextEditor(text: textBinding).id(key).disabled(!editableDate).font(.system(size: 16)).lineSpacing(9).scrollContentBackground(.hidden)
                .frame(minHeight: 300).padding(8).background(Palette.card)
                .overlay(alignment: .topLeading) {
                    if diary.text.isEmpty {
                        Text(Calendar.current.isDateInToday(date) ? "今日还没有记录" : "这一天还没有记录")
                            .font(.system(size: 16)).foregroundStyle(Palette.muted.opacity(0.7)).padding(.horizontal, 14).padding(.top, 9).allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("\(key)的日记正文")
            HStack {
                Text("\(diary.characters) 字符（不含空白）")
                Spacer()
                Label(store.error.isEmpty ? "本机自动保存" : "请检查保存提示", systemImage: "externaldrive")
            }.font(.caption).foregroundStyle(Palette.muted)
        }
    }
}
