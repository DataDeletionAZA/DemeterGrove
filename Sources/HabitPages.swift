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
                PixelCalendar(selection: $date, display: display, maximum: store.now, compact: true, markers: { day in
                    let key = dayKey(day)
                    if store.data.habitDays.contains(key) { return [Palette.sage] }
                    if store.data.habits.contains(where: { $0.checkIns?[key]?.status == .pending }) { return [Palette.goldLight] }
                    return []
                })
                HStack { Text("累计签到 \(total) 天").font(.headline).foregroundStyle(Palette.goldLight); Spacer(); Text("同一天多个习惯只计 1 天").font(.caption).foregroundStyle(Palette.muted) }
                Text("当天任一习惯审核通过，获得 \(HabitProgress.dailyCoins) 铜纳特。累计天数无需连续。").font(.caption).foregroundStyle(Palette.muted)
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
                if !Calendar.current.isDate(date, inSameDayAs: store.now) { Text("历史记录仅供查看。打卡材料只能在当天提交。").font(.caption).foregroundStyle(Palette.muted) }
                if store.data.habits.isEmpty { EmptyNote(text: "添加一个想慢慢养成的小习惯。") }
                ForEach(store.data.habits) { habit in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            HabitRow(store: store, habit: habit, date: date)
                            Button { editing = habit } label: { Image(systemName: "pencil") }.buttonStyle(.plain).help("编辑习惯").accessibilityLabel("编辑习惯：" + habit.title)
                            Button { deleting = habit } label: { Image(systemName: "trash") }.buttonStyle(.plain).help("删除习惯").accessibilityLabel("删除习惯：" + habit.title)
                        }
                        HStack(spacing: 6) {
                            Text("近 14 天").font(.system(size: 10)).foregroundStyle(Palette.muted)
                            ForEach((0..<14).reversed(), id: \.self) { offset in
                                let day = Calendar.current.date(byAdding: .day, value: -offset, to: date)!
                                Rectangle().fill(habit.days.contains(dayKey(day)) ? Palette.sage : Palette.line.opacity(0.7)).frame(height: 10)
                                    .help("\(dayKey(day))：\(habit.days.contains(dayKey(day)) ? "已完成" : "未完成")")
                            }
                        }
                    }.padding(.vertical, 7)
                    Divider()
                }
            }
        }
        .sheet(isPresented: $adding) { HabitEditor(store: store, habit: Habit(title: "")) }
        .sheet(item: $editing) { habit in HabitEditor(store: store, habit: habit) }
        .alert("删除这个习惯？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("取消", role: .cancel) { deleting = nil }
            Button("删除", role: .destructive) { if let deleting { store.removeHabit(deleting.id) }; deleting = nil }
        } message: { Text("累计签到天数和已获得的奖励会保留。") }
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
    private var today: Bool { Calendar.current.isDate(date, inSameDayAs: store.now) }
    var body: some View {
        HStack {
            Image(systemName: completed ? "checkmark.circle.fill" : "leaf").foregroundStyle(Palette.sage)
            VStack(alignment: .leading, spacing: 5) {
                Text(habit.title).lineLimit(2)
                if let encouragement = habit.encouragement, !encouragement.isEmpty { Text(encouragement).font(.caption).foregroundStyle(Palette.muted).lineLimit(2) }
                if let minutes = habit.reminderMinutes { Label(String(format: "%02d:%02d 提醒", minutes / 60, minutes % 60), systemImage: "bell").font(.system(size: 10)).foregroundStyle(Palette.muted) }
            }
            Spacer()
            Text("累计 \(habit.days.count) 天").font(.caption).foregroundStyle(Palette.muted)
            Button(completed ? "已完成" : (entry?.status.title ?? (today ? "打卡" : "未打卡"))) { checkingIn = true }
                .buttonStyle(PixelButtonStyle(primary: today && !completed)).accessibilityLabel("打卡：" + habit.title).accessibilityValue(completed ? "已完成" : (entry?.status.title ?? "未打卡")).disabled(!today && entry == nil)
        }.sheet(isPresented: $checkingIn) { HabitEvidenceEditor(store: store, habitID: habit.id, date: date) }
    }
}

struct HabitEditor: View {
    @ObservedObject var store: GardenStore
    @State var habit: Habit
    @State private var reminding: Bool
    @State private var reminderHour: Int
    @State private var reminderMinute: Int
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    init(store: GardenStore, habit: Habit) {
        self.store = store
        _habit = State(initialValue: habit)
        _reminding = State(initialValue: habit.reminderMinutes != nil)
        let minutes = habit.reminderMinutes ?? 20 * 60
        _reminderHour = State(initialValue: minutes / 60)
        _reminderMinute = State(initialValue: minutes % 60)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(store.data.habits.contains { $0.id == habit.id } ? "编辑习惯" : "添加习惯").font(.title2)
            TextField("习惯名称", text: $habit.title).textFieldStyle(PixelTextFieldStyle())
            Toggle("每天提醒", isOn: $reminding)
            if reminding {
                HStack {
                    Text("提醒时间")
                    PixelSelect(selection: $reminderHour, items: (0..<24).map { ($0, String(format: "%02d 时", $0)) })
                    PixelSelect(selection: $reminderMinute, items: (0..<60).map { ($0, String(format: "%02d 分", $0)) })
                }
                if !store.data.preferences.notifications {
                    HStack { Text("需要允许系统通知").font(.caption).foregroundStyle(Palette.muted); Spacer(); Button("开启通知") { store.requestNotifications() }.buttonStyle(PixelButtonStyle()) }
                }
            }
            TextField("给自己的激励语（可选）", text: Binding(get: { habit.encouragement ?? "" }, set: { habit.encouragement = $0 }), axis: .vertical).lineLimit(2...4).textFieldStyle(PixelTextFieldStyle())
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.clay) }
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    habit.reminderMinutes = reminding ? reminderHour * 60 + reminderMinute : nil
                    if store.upsert(habit) { dismiss() }
                    else { error = store.error.isEmpty ? "习惯未能保存，请检查填写内容后重试。" : store.error }
                }.buttonStyle(PixelButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
                    .disabled(habit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (habit.encouragement?.count ?? 0) > 300)
            }
        }.padding(28).frame(width: 440).magicSurface(Palette.paper, strong: true).magicControls()
    }
}

struct HabitEvidenceEditor: View {
    @ObservedObject var store: GardenStore
    var habitID: UUID
    var date: Date
    @State private var text = ""
    @State private var image: Data?
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    private var habit: Habit? { store.data.habits.first { $0.id == habitID } }
    private var entry: HabitCheckIn? { habit?.checkIns?[dayKey(date)] }
    private var editable: Bool { Calendar.current.isDate(date, inSameDayAs: store.now) && habit?.days.contains(dayKey(date)) != true }
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text(habit?.title ?? "习惯打卡").font(.title2)
            Text(date.formatted(.dateTime.year().month().day())).font(.caption).foregroundStyle(Palette.muted)
            if let entry { Text("状态：\(entry.status.title)").foregroundStyle(Palette.goldLight) }
            if let feedback = entry?.feedback, !feedback.isEmpty { Text(feedback).font(.callout) }
            Text("用文字或照片记录今天做过的事。").font(.callout)
            TextEditor(text: $text).scrollContentBackground(.hidden).padding(8).frame(height: 135).background(Palette.card).border(Palette.line).disabled(!editable).accessibilityLabel("打卡文字")
            HStack {
                if let image, let picture = NSImage(data: image) { Image(nsImage: picture).resizable().scaledToFit().frame(width: 120, height: 100) }
                if editable {
                    Button(image == nil ? "添加照片" : "更换照片", systemImage: "photo") { importImage() }.buttonStyle(PixelButtonStyle())
                    if image != nil { Button("移除照片") { image = nil }.buttonStyle(PixelButtonStyle()) }
                }
            }
            Text("审核服务尚未连接。材料会保存在本机，审核通过后计入签到并发放奖励。").font(.caption).foregroundStyle(Palette.muted)
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.clay) }
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
                    Button(entry == nil ? "保存打卡材料" : "更新打卡材料") {
                        if store.submitHabitEvidence(habitID, date: date, text: text, image: image) { dismiss() }
                        else { error = store.error.isEmpty ? "仅能保存当天的材料，请填写文字或选择照片。" : store.error }
                    }.buttonStyle(PixelButtonStyle(primary: true)).disabled((text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && image == nil) || text.count > 4000)
                }
            }
        }.padding(28).frame(width: 500).magicSurface(Palette.paper, strong: true).magicControls()
            .onAppear { text = entry?.text ?? ""; image = entry?.image }
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
