import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct HabitsPage: View {
    @ObservedObject var store: GardenStore
    @State private var date = Date()
    @State private var display: CalendarDisplay = .week
    @State private var adding = false
    @State private var deleting: Habit?
    @State private var editing: Habit?
    @State private var showingArchived = false
    @State private var archiveError = ""
    private var visibleHabits: [Habit] { store.data.habits.filter { showingArchived ? $0.archivedAt != nil : $0.archivedAt == nil } }
    private var total: Int { store.data.habitDays.count }
    var body: some View {
        VStack(spacing: 20) {
            Card(title: "") {
                HStack {
                    Text("习惯日历").font(.headline)
                    Spacer()
                    PixelTabs(selection: $display, items: [(.week, "周"), (.month, "月")]).frame(width: 110)
                    Button("添加习惯", systemImage: "plus") { adding = true }.buttonStyle(PixelButtonStyle(primary: true))
                }
                if display == .week {
                    HabitWeekBoard(store: store, selection: $date)
                } else {
                    PixelCalendar(selection: $date, display: .month, maximum: store.now, compact: true, markers: { day in
                        let key = dayKey(day)
                        if store.data.habitDays.contains(key) { return [Palette.sage] }
                        if store.data.habits.contains(where: { $0.checkIns?[key]?.status == .pending }) { return [Palette.goldLight] }
                        return []
                    })
                }
                Text("累计签到 \(total) 天").font(.headline).foregroundStyle(Palette.goldLight).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    ForEach(HabitProgress.milestones, id: \.self) { milestone in
                        VStack(spacing: 5) {
                            Image(systemName: store.data.habitProgress?.milestones.contains(milestone) == true ? "seal.fill" : "seal")
                            Text("\(milestone) 天").font(.caption)
                            Text(HabitProgress.rewardName(milestone)).font(.system(size: 10)).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).foregroundStyle(total >= milestone ? Palette.goldLight : Palette.muted)
                    }
                }.padding(.vertical, 8)
            }
            Card(title: date.formatted(.dateTime.month().day().weekday(.wide)), icon: "checkmark.circle") {
                if !store.calendar.isDate(date, inSameDayAs: store.now) { Text("历史记录").font(.caption).foregroundStyle(Palette.muted) }
                HStack {
                    PixelTabs(selection: $showingArchived, items: [(false, "进行中"), (true, "已归档")]).frame(width: 190)
                    Spacer()
                }
                if visibleHabits.isEmpty { EmptyNote(text: showingArchived ? "暂无归档习惯" : "暂无习惯") }
                if !archiveError.isEmpty { Text(archiveError).font(.caption).foregroundStyle(Palette.clay) }
                ForEach(visibleHabits) { habit in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            HabitRow(store: store, habit: habit, date: date)
                            if habit.archivedAt == nil {
                            Button { editing = habit } label: { Image(systemName: "pencil") }.buttonStyle(.plain).help("编辑习惯").accessibilityLabel("编辑习惯：" + habit.title)
                            Button { deleting = habit } label: { Image(systemName: "trash") }.buttonStyle(.plain).help("归档习惯").accessibilityLabel("归档习惯：" + habit.title)
                            }
                        }
                        HStack(spacing: 6) {
                            Text("近 14 天").font(.system(size: 10)).foregroundStyle(Palette.muted)
                            ForEach((0..<14).reversed(), id: \.self) { offset in
                                let day = store.calendar.date(byAdding: .day, value: -offset, to: date)!
                                Rectangle().fill(habit.days.contains(dayKey(day)) ? Palette.sage : Palette.line.opacity(0.7)).frame(height: 10)
                                    .help("\(dayKey(day))：\(habit.days.contains(dayKey(day)) ? "已完成" : "未完成")")
                            }
                        }
                    }.padding(.vertical, 7)
                    Divider()
                }
            }
        }
        .environment(\.calendar, store.calendar)
        .sheet(isPresented: $adding) { HabitEditor(store: store, habit: Habit(title: "")) }
        .sheet(item: $editing) { habit in HabitEditor(store: store, habit: habit) }
        .alert("归档这个习惯？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("取消", role: .cancel) { deleting = nil }
            Button("归档") {
                if let deleting, !store.removeHabit(deleting.id) { archiveError = store.error.isEmpty ? "归档未能保存，请重试。" : store.error }
                deleting = nil
            }
        } message: { Text("历史记录、照片和奖励会保留。归档后停止提醒和新打卡。") }
    }
}

struct HabitWeekBoard: View {
    @ObservedObject var store: GardenStore
    @Binding var selection: Date
    @Environment(\.sceneViewport) private var viewport
    private var days: [Date] { CalendarDates.days(in: selection, week: true, calendar: store.calendar).compactMap { $0 } }
    private var cardWidth: CGFloat { max(158, (viewport.width - 108) / 7) }
    private var boardHabits: [Habit] {
        let keys = Set(days.map { CalendarDates.key($0, calendar: store.calendar) })
        return store.data.habits.filter { habit in
            habit.archivedAt == nil || !habit.days.isDisjoint(with: keys) || (habit.checkIns ?? [:]).keys.contains { keys.contains($0) }
        }
    }
    private var boardHeight: CGFloat { max(190, CGFloat(boardHabits.count) * 48 + 112) }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(days.first!.formatted(.dateTime.year().month().day()) + " — " + days.last!.formatted(.dateTime.month().day())).font(.callout).foregroundStyle(Palette.goldLight)
                Spacer(minLength: 6)
                Button { move(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(PixelButtonStyle()).accessibilityLabel("上一周")
                Button { move(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(PixelButtonStyle()).accessibilityLabel("下一周")
                    .disabled(store.calendar.date(byAdding: .day, value: 7, to: days.first!)! > store.calendar.startOfDay(for: store.now))
            }
            HStack { Button("回到今天") { selection = store.now }.buttonStyle(PixelButtonStyle()).disabled(store.calendar.isDate(selection, inSameDayAs: store.now)); Spacer() }
            ScrollViewReader { reader in
                PixelScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(days, id: \.self) { day in
                            HabitDayCard(habits: boardHabits, day: day, today: store.now, calendar: store.calendar, selected: store.calendar.isDate(day, inSameDayAs: selection)) { selection = day }
                                .frame(width: cardWidth, height: boardHeight).id(dayKey(day))
                        }
                    }.padding(.bottom, 8)
                }.frame(height: boardHeight + 12)
                    .onAppear { reader.scrollTo(dayKey(selection), anchor: .center) }
                    .onChange(of: selection) { _, value in reader.scrollTo(dayKey(value), anchor: .center) }
            }
        }
    }
    private func move(_ amount: Int) { selection = store.calendar.date(byAdding: .day, value: amount * 7, to: selection)! }
}

struct HabitDayCard: View {
    var habits: [Habit]
    var day: Date
    var today: Date
    var calendar: Calendar = .current
    var selected: Bool
    var choose: () -> Void
    private var completed: Int { habits.filter { HabitDayState.value(for: $0, on: day, today: today, calendar: calendar) == .completed }.count }
    private var planned: Int { habits.filter { $0.isScheduled(on: day, calendar: calendar) }.count }
    private var future: Bool { calendar.startOfDay(for: day) > calendar.startOfDay(for: today) }
    var body: some View {
        Button(action: choose) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .firstTextBaseline) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: 13, weight: .medium))
                    Spacer(minLength: 3)
                    if calendar.isDate(day, inSameDayAs: today) { Text("今天").font(.system(size: 10)).foregroundStyle(Palette.goldLight) }
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(day.formatted(.dateTime.day())).font(.system(size: 25, weight: .medium))
                    Spacer(minLength: 3)
                    Text("\(completed) 完成 · \(planned) 计划").font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                Rectangle().fill(Palette.line).frame(height: 1)
                if habits.isEmpty { Text("暂无习惯").font(.caption).foregroundStyle(Palette.muted) }
                ForEach(habits) { habit in
                    let state = HabitDayState.value(for: habit, on: day, today: today, calendar: calendar)
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: symbol(state)).font(.system(size: 12)).foregroundStyle(color(state)).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(habit.title).font(.system(size: 12)).lineLimit(1)
                            Text(state.rawValue).font(.system(size: 10)).foregroundStyle(color(state))
                        }
                    }.frame(height: 37, alignment: .top)
                }
                Spacer(minLength: 0)
            }.padding(5).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }.buttonStyle(PixelButtonStyle(primary: selected)).disabled(future).opacity(future ? 0.55 : 1)
            .accessibilityLabel(day.formatted(date: .complete, time: .omitted)).accessibilityValue((["已完成 \(completed) / \(habits.count) 项"] + habits.map { $0.title + "：" + HabitDayState.value(for: $0, on: day, today: today, calendar: calendar).rawValue }).joined(separator: "，"))
    }
    private func symbol(_ state: HabitDayState) -> String {
        switch state { case .completed: return "checkmark.circle.fill"; case .pending: return "clock"; case .needsMore: return "exclamationmark.circle"; case .empty, .upcoming, .rest, .notStarted, .archived: return "circle" }
    }
    private func color(_ state: HabitDayState) -> Color {
        switch state { case .completed: return Palette.sage; case .pending: return Palette.goldLight; case .needsMore: return Palette.clay; case .empty, .upcoming, .rest, .notStarted, .archived: return Palette.muted }
    }
}

struct HabitRow: View {
    @ObservedObject var store: GardenStore
    var habit: Habit
    var date: Date
    @State private var checkingIn = false
    private var key: String { dayKey(date) }
    private var completed: Bool { habit.days.contains(key) }
    private var entry: HabitCheckIn? { habit.checkIns?[key] }
    private var today: Bool { store.calendar.isDate(date, inSameDayAs: store.now) && habit.archivedAt == nil }
    var body: some View {
        HStack {
            Image(systemName: completed ? "checkmark.circle.fill" : "leaf").foregroundStyle(Palette.sage)
            VStack(alignment: .leading, spacing: 5) {
                Text(habit.title + (habit.archivedAt == nil ? "" : " · 已归档")).lineLimit(2)
                if let rule = Recurrence.revision(habit.scheduleRevisions, on: date, calendar: store.calendar)?.rule { Text(rule.summary).font(.caption).foregroundStyle(Palette.muted) }
                if habit.archivedAt == nil, let minutes = habit.reminderMinutes { Label(String(format: "%02d:%02d 提醒", minutes / 60, minutes % 60), systemImage: "bell").font(.system(size: 10)).foregroundStyle(Palette.muted) }
            }
            Spacer()
            Text("累计 \(habit.days.count) 天").font(.caption).foregroundStyle(Palette.muted)
            Button(habit.archivedAt != nil ? "历史记录" : store.reviewingHabits.contains(habit.id) && today ? "审核中" : completed ? "已完成" : (entry?.status.title ?? (today ? (habit.isScheduled(on: date, calendar: store.calendar) ? "打卡" : "额外打卡") : HabitDayState.value(for: habit, on: date, today: store.now, calendar: store.calendar).rawValue))) { checkingIn = true }
                .buttonStyle(PixelButtonStyle(primary: today && !completed)).accessibilityLabel((habit.archivedAt == nil ? "打卡：" : "历史记录：") + habit.title).accessibilityValue(completed ? "已完成" : (entry?.status.title ?? "未打卡")).disabled(habit.archivedAt == nil && !today && entry == nil)
        }.sheet(isPresented: $checkingIn) {
            if habit.archivedAt != nil { HabitHistoryView(store: store, habitID: habit.id) }
            else { HabitEvidenceEditor(store: store, habitID: habit.id, date: date) }
        }
    }
}

struct HabitEditor: View {
    @ObservedObject var store: GardenStore
    @State var habit: Habit
    @State private var reminding: Bool
    @State private var reminderHour: Int
    @State private var reminderMinute: Int
    @State private var error = ""
    @State private var repeating = true
    @State private var repeatRule: RepeatRule
    @State private var anchor: Date
    @State private var library: ReminderTextLibrary
    private var effective: Date { store.data.habits.contains(where: { $0.id == habit.id }) ? store.calendar.date(byAdding: .day, value: 1, to: store.now)! : store.now }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sceneViewport) private var viewport
    init(store: GardenStore, habit: Habit) {
        self.store = store
        _habit = State(initialValue: habit)
        _reminding = State(initialValue: habit.reminderMinutes != nil)
        let minutes = habit.reminderMinutes ?? 20 * 60
        _reminderHour = State(initialValue: minutes / 60)
        _reminderMinute = State(initialValue: minutes % 60)
        let revision = habit.scheduleRevisions?.max { $0.effectiveFrom < $1.effectiveFrom }
        _repeatRule = State(initialValue: revision?.rule ?? RepeatRule(weekdays: [store.calendar.component(.weekday, from: store.now)]))
        _anchor = State(initialValue: revision.flatMap { Recurrence.date($0.anchor, calendar: store.calendar) } ?? store.now)
        _library = State(initialValue: habit.messageLibrary ?? ReminderTextLibrary(texts: [habit.encouragement ?? ""]))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(store.data.habits.contains { $0.id == habit.id } ? "编辑习惯" : "添加习惯").font(.title2)
            PixelScrollView { VStack(alignment: .leading, spacing: 16) {
            TextField("习惯名称", text: $habit.title).textFieldStyle(PixelTextFieldStyle())
            RepeatScheduleEditor(enabled: $repeating, rule: $repeatRule, anchor: $anchor, calendar: store.calendar, effective: effective, allowsOff: false)
            Toggle("提醒", isOn: $reminding)
            if reminding {
                HStack {
                    Text("提醒时间")
                    PixelSelect(selection: $reminderHour, items: (0..<24).map { ($0, String(format: "%02d 时", $0)) })
                    PixelSelect(selection: $reminderMinute, items: (0..<60).map { ($0, String(format: "%02d 分", $0)) })
                }
                if !store.data.preferences.notifications {
                    HStack { Text("系统通知未开启").font(.caption).foregroundStyle(Palette.muted); Spacer(); Button("开启通知") { store.requestNotifications() }.buttonStyle(PixelButtonStyle()) }
                }
            }
            ReminderMessagesEditor(library: $library)
            AIEncouragementButton(store: store, feature: .habitEncouragement, subject: habit.title) { texts in
                library.phrases.append(contentsOf: texts.map { ReminderPhrase(text: $0) }); library.normalize()
            }.buttonStyle(PixelButtonStyle())
            }.padding(.trailing, 20)}.frame(maxHeight: min(580, max(160, viewport.height - 230)))
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.clay) }
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    habit.reminderMinutes = reminding ? reminderHour * 60 + reminderMinute : nil
                    let old = habit.scheduleRevisions?.max { $0.effectiveFrom < $1.effectiveFrom }
                    if old?.rule != repeatRule || old?.anchor != CalendarDates.key(anchor, calendar: store.calendar) {
                        habit.scheduleRevisions = Recurrence.revised(habit.scheduleRevisions, rule: repeatRule, anchor: anchor, effective: effective, calendar: store.calendar)
                    }
                    library.normalize(); habit.messageLibrary = library; habit.encouragement = nil
                    if store.upsert(habit) { dismiss() }
                    else { error = store.error.isEmpty ? "习惯未能保存，请检查填写内容后重试。" : store.error }
                }.buttonStyle(PixelButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
                    .disabled(habit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !repeatRule.isValid)
            }
        }.padding(28).frame(width: 500).magicSurface(Palette.paper, strong: true).magicControls()
    }
}

struct HabitEvidenceEditor: View {
    @ObservedObject var store: GardenStore
    var habitID: UUID
    var date: Date
    var reviewClient = AIClient()
    @State private var text = ""
    @State private var image: Data?
    @State private var showingPhoto = false
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sceneViewport) private var viewport
    private var habit: Habit? { store.data.habits.first { $0.id == habitID } }
    private var entry: HabitCheckIn? { habit?.checkIns?[dayKey(date)] }
    private var isToday: Bool { store.calendar.isDate(date, inSameDayAs: store.now) }
    private var editable: Bool { isToday && habit != nil && habit?.archivedAt == nil && habit?.days.contains(dayKey(date)) != true }
    private var reviewing: Bool { editable && store.reviewingHabits.contains(habitID) }
    private var profile: AIProfile? { store.data.ai?.profile(for: .habitReview) }
    private var changed: Bool { entry?.text != text.trimmingCharacters(in: .whitespacesAndNewlines) || entry?.image != image }
    private var reviewError: String { editable ? (store.reviewErrors[habitID] ?? "") : "" }
    private var submitTitle: String {
        guard profile != nil else { return "保存材料" }
        if entry?.status == .pending && !changed { return reviewError.isEmpty ? "开始审核" : "重试审核" }
        return "提交并审核"
    }
    var body: some View {
        PixelScrollView { VStack(alignment: .leading, spacing: 17) {
            Text(habit?.title ?? "习惯打卡").font(.title2)
            Text(date.formatted(.dateTime.year().month().day())).font(.caption).foregroundStyle(Palette.muted)
            if reviewing { Label("审核中", systemImage: "hourglass").foregroundStyle(Palette.goldLight) }
            else if let entry { Text("状态：\(entry.status.title)").foregroundStyle(Palette.goldLight) }
            if habit?.archivedAt != nil { Text("已归档 · 历史材料").font(.caption).foregroundStyle(Palette.muted) }
            if let entry {
                Text("提交：" + entry.submittedAt.formatted(date: .numeric, time: .shortened)).font(.caption).foregroundStyle(Palette.muted)
                if let reviewedAt = entry.reviewedAt { Text("审核：" + reviewedAt.formatted(date: .numeric, time: .shortened)).font(.caption).foregroundStyle(Palette.muted) }
            }
            if let feedback = entry?.feedback, !feedback.isEmpty { Text(feedback).font(.callout).textSelection(.enabled) }
            Text("打卡材料").font(.callout)
            TextEditor(text: $text).scrollContentBackground(.hidden).padding(8).frame(height: 135).background(Palette.card).border(Palette.line).disabled(!editable || reviewing).accessibilityLabel("打卡文字")
            HStack {
                if let image, let picture = NSImage(data: image) {
                    Button { showingPhoto = true } label: {
                        Image(nsImage: picture).resizable().scaledToFit().frame(width: 120, height: 100)
                    }.buttonStyle(.plain).help("放大照片").accessibilityLabel("放大打卡照片")
                }
                if editable {
                    Button(image == nil ? "添加照片" : "更换照片", systemImage: "photo") { importImage() }.buttonStyle(PixelButtonStyle())
                    if image != nil { Button("移除照片") { image = nil }.buttonStyle(PixelButtonStyle()) }
                }
            }
            .disabled(reviewing)
            if editable {
                AIWritingPresetPicker(store: store, feature: .habitReview)
                if let profile {
                    Label("发送至 \(AIProfile.secureURL(profile.baseURL)?.host ?? profile.name) · \(profile.model)", systemImage: "sparkles")
                        .font(.caption).foregroundStyle(Palette.muted).textSelection(.enabled)
                } else {
                    HStack {
                        Text("未设置审核服务").font(.caption).foregroundStyle(Palette.muted)
                        Spacer()
                        Button("打开设置") {
                            dismiss(); store.selectedPage = "设置"; store.pet?.openTool("设置")
                        }.buttonStyle(PixelButtonStyle())
                    }
                }
            }
            if !error.isEmpty || !reviewError.isEmpty {
                Text(error.isEmpty ? reviewError : error).font(.caption).foregroundStyle(Palette.clay)
            }
            HStack {
                Button("关闭") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                if editable {
                    if entry?.status == .pending {
                        Button("撤回材料") {
                            if store.cancelHabitSubmission(habitID, date: date) { dismiss() }
                            else { error = store.error.isEmpty ? "只能撤回当天尚未处理的材料。" : store.error }
                        }.buttonStyle(PixelButtonStyle())
                    }
                    if reviewing {
                        Button("取消审核") { store.cancelHabitReview(habitID) }.buttonStyle(PixelButtonStyle())
                    } else {
                        Button(submitTitle) { submit() }.buttonStyle(PixelButtonStyle(primary: true))
                            .disabled((text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && image == nil) || text.count > 4000)
                    }
                }
            }
        }.padding(28) }.frame(width: 500, height: min(760, max(360, viewport.height - 20))).magicSurface(Palette.paper, strong: true).magicControls()
            .onAppear { text = entry?.text ?? ""; image = entry?.image }
            .sheet(isPresented: $showingPhoto) { if let image { HabitPhotoPreview(data: image) } }
    }
    private func submit() {
        error = ""
        if entry?.status != .pending || changed {
            guard store.submitHabitEvidence(habitID, date: date, text: text, image: image) else {
                error = store.error.isEmpty ? "材料未能保存，请重试。" : store.error; return
            }
        }
        guard profile != nil else { return }
        Task { @MainActor in _ = await store.reviewHabit(habitID, date: date, client: reviewClient) }
    }
    private func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .webP]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 20 * 1024 * 1024,
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1200, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary),
                  let bytes = NSBitmapImageRep(cgImage: thumbnail).representation(using: .jpeg, properties: [.compressionFactor: 0.8]), bytes.count <= 2_097_152 else {
                error = "这张照片无法读取，请换一张小于 20 MB 的图片。"; return
            }
            image = bytes; error = ""
        } catch { self.error = "照片读取失败：\(error.localizedDescription)" }
    }
}

struct HabitPhotoPreview: View {
    var data: Data
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 16) {
            if let image = NSImage(data: data) { Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity) }
            Button("关闭") { dismiss() }.buttonStyle(PixelButtonStyle()).keyboardShortcut(.cancelAction)
        }.padding(24).frame(minWidth: 400, idealWidth: 720, minHeight: 360, idealHeight: 640)
            .magicSurface(Palette.paper, strong: true)
    }
}

struct HabitHistoryView: View {
    @ObservedObject var store: GardenStore
    var habitID: UUID
    @State private var selected: HabitHistoryDay?
    @Environment(\.dismiss) private var dismiss
    private var habit: Habit? { store.data.habits.first { $0.id == habitID } }
    private var days: [String] { Set(habit?.days ?? []).union(Set(habit?.checkIns?.keys.map { $0 } ?? [])).sorted(by: >) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(habit?.title ?? "习惯历史").font(.title2)
            if let archivedAt = habit?.archivedAt { Text("归档于 " + archivedAt.formatted(date: .numeric, time: .shortened)).font(.caption).foregroundStyle(Palette.muted) }
            PixelScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if days.isEmpty { EmptyNote(text: "暂无历史记录") }
                    ForEach(days, id: \.self) { day in
                        Button {
                            if let date = Recurrence.date(day, calendar: store.calendar) { selected = HabitHistoryDay(date: date) }
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack { Text(day); Spacer(); Text(habit?.days.contains(day) == true ? "已完成" : (habit?.checkIns?[day]?.status.title ?? "已记录")) }
                                if let entry = habit?.checkIns?[day] {
                                    if !entry.text.isEmpty { Text(entry.text).lineLimit(2).font(.caption).foregroundStyle(Palette.muted) }
                                    if entry.image != nil { Label("有照片 · 点击回看", systemImage: "photo").font(.caption).foregroundStyle(Palette.muted) }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(PixelButtonStyle()).accessibilityLabel("查看" + day + "材料")
                    }
                }.padding(.trailing, 18)
            }
            Button("关闭") { dismiss() }.buttonStyle(PixelButtonStyle()).keyboardShortcut(.cancelAction)
        }.padding(24).frame(width: 520, height: 580).magicSurface(Palette.paper, strong: true)
        .sheet(item: $selected) { item in HabitEvidenceEditor(store: store, habitID: habitID, date: item.date) }
    }
}

private struct HabitHistoryDay: Identifiable { var date: Date; var id: Date { date } }
