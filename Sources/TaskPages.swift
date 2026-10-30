import SwiftUI

let quadrantTitles = ["重要 · 紧急", "重要 · 不紧急", "不重要 · 紧急", "不重要 · 不紧急"]
let quadrantHints = ["先着手处理", "留出整段时间", "集中安排处理", "有余力再做"]
let quadrantColors = [Palette.clay, Palette.sage, Color(red: 0.64, green: 0.55, blue: 0.32), Color(red: 0.49, green: 0.53, blue: 0.56)]

struct TasksPage: View {
    @ObservedObject var store: GardenStore
    @State private var display = "清单"
    @State private var category: String?
    @State private var filter = "未完成"
    @State private var adding = false
    var tasks: [GardenTask] {
        store.data.tasks.filter { (category == nil || $0.categoryName == category) && (filter == "全部" || (filter == "已完成" ? $0.completedAt != nil : $0.completedAt == nil)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                PixelTabs(selection: $display, items: [("清单", "清单"), ("四象限", "四象限")]).frame(width: 170)
                PixelSelect(selection: $filter, items: ["未完成", "已完成", "全部"].map { ($0, $0) }).frame(width: 125)
                Spacer()
                Button("添加事项", systemImage: "plus") { adding = true }.buttonStyle(PixelButtonStyle(primary: true))
            }
            PixelSelect(selection: $category, items: [(nil as String?, "全部类型")] + Array(Set(store.data.tasks.map(\.categoryName))).sorted().map { (Optional($0), $0) }).frame(maxWidth: 240)
            if display == "四象限" {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 18) {
                    ForEach(0..<4) { quadrant in
                        Card(title: "") {
                            HStack {
                                Text(String(format: "%02d", quadrant + 1)).font(.system(size: 22, design: .serif)).foregroundStyle(quadrantColors[quadrant])
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(quadrantTitles[quadrant]).fontWeight(.semibold)
                                    Text(quadrantHints[quadrant]).font(.caption).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                Text("\(tasks.filter { $0.quadrant == quadrant }.count)").foregroundStyle(Palette.muted)
                            }
                            Divider()
                            let items = tasks.filter { $0.quadrant == quadrant }
                            if items.isEmpty { EmptyNote(text: "暂时没有任务") }
                            ForEach(items) { task in TaskRow(store: store, task: task) }
                            Spacer(minLength: 0)
                        }.frame(minHeight: 200, alignment: .top)
                    }
                }
            } else {
                Card(title: "任务清单", icon: "checklist") {
                    if tasks.isEmpty { EmptyNote(text: "暂无任务") }
                    ForEach(tasks.sorted { $0.quadrant < $1.quadrant }) { task in TaskRow(store: store, task: task) }
                }
            }

        }.sheet(isPresented: $adding) { TaskEditor(store: store, task: GardenTask(title: "", category: "待办")) }
    }
}

struct TaskRow: View {
    @ObservedObject var store: GardenStore
    var task: GardenTask
    @State private var editing = false
    @State private var deleting = false
    @State private var more = false
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { store.toggleTask(task.id) } label: {
                Image(systemName: task.completedAt == nil ? "circle" : "checkmark.circle.fill")
                    .font(.system(size: 19)).foregroundStyle(task.completedAt == nil ? Palette.muted : Palette.sage)
            }.buttonStyle(.plain).help(task.completedAt == nil ? "标记完成" : "恢复未完成")
            Button { editing = true } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.title).strikethrough(task.completedAt != nil).lineLimit(2).multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Circle().fill(quadrantColors[task.quadrant]).frame(width: 5, height: 5)
                        Text(task.categoryName)
                        Text(quadrantTitles[task.quadrant])
                        if let due = task.due { Text("截止 " + due.formatted(.dateTime.month().day())).foregroundStyle(due < Calendar.current.startOfDay(for: Date()) && task.completedAt == nil ? Palette.clay : Palette.muted) }
                    }.font(.system(size: 10)).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help("编辑任务")
            if task.completedAt == nil {
                Button { store.startTimer(kind: .pomodoro, minutes: store.data.preferences.focusMinutes, task: task) } label: {
                    Image(systemName: "play.circle").font(.system(size: 20))
                }.buttonStyle(.plain).foregroundStyle(Palette.sage).help("为这件任务开始番茄钟")
            }
            Button { more.toggle() } label: {
                Image(systemName: "ellipsis").frame(width: 24, height: 26)
            }.buttonStyle(.plain).accessibilityLabel("更多操作：" + task.title)
                .popover(isPresented: $more, arrowEdge: .bottom) {
                    VStack(spacing: 8) {
                        Button("编辑任务") { more = false; editing = true }.buttonStyle(PixelButtonStyle())
                        Button("删除任务") { more = false; deleting = true }.buttonStyle(PixelButtonStyle())
                    }.padding(14).frame(width: 180).magicSurface(Palette.paper, strong: true).magicControls()
                }
        }.padding(.vertical, 6)
            .sheet(isPresented: $editing) { TaskEditor(store: store, task: task) }
            .alert("删除这件任务？", isPresented: $deleting) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) { store.data.tasks.removeAll { $0.id == task.id } }
            } message: { Text("已有的专注记录会保留。") }
    }
}

struct TaskEditor: View {
    @ObservedObject var store: GardenStore
    @State private var task: GardenTask
    @State private var hasDate: Bool
    @State private var due: Date
    @State private var categoryChoice: String
    @State private var customCategory: String
    @State private var error = ""
    var onSave: ((GardenTask) -> Void)?
    @Environment(\.dismiss) private var dismiss
    init(store: GardenStore, task: GardenTask, onSave: ((GardenTask) -> Void)? = nil) {
        self.store = store
        self.onSave = onSave
        let presets = ["待办", "任务", "娱乐休闲"]
        _categoryChoice = State(initialValue: presets.contains(task.categoryName) ? task.categoryName : "自定义")
        _customCategory = State(initialValue: presets.contains(task.categoryName) ? "" : task.categoryName)
        _task = State(initialValue: task)
        _hasDate = State(initialValue: task.due != nil)
        _due = State(initialValue: task.due ?? Date())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("任务").font(.title2).fontWeight(.semibold)
            TextField("任务名称", text: $task.title).textFieldStyle(PixelTextFieldStyle())
            HStack {
                Text("类型")
                PixelSelect(selection: $categoryChoice, items: ["待办", "任务", "娱乐休闲", "自定义"].map { ($0, $0) })
            }
            if categoryChoice == "自定义" { TextField("输入分类名称", text: $customCategory).textFieldStyle(PixelTextFieldStyle()) }
            HStack { Toggle("重要", isOn: $task.important); Toggle("紧急", isOn: $task.urgent) }
            Toggle("截止日期（可选）", isOn: $hasDate)
            if hasDate { PixelDatePicker(title: "截止", selection: $due) }
            Text("备注").font(.callout)
            TextEditor(text: $task.notes).scrollContentBackground(.hidden).padding(8).frame(height: 100).background(Palette.card).border(Palette.line)
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.clay) }
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    task.due = hasDate ? due : nil
                    task.category = (categoryChoice == "自定义" ? customCategory : categoryChoice).trimmingCharacters(in: .whitespacesAndNewlines)
                    if store.upsert(task) { onSave?(task); dismiss() }
                    else { error = store.error.isEmpty ? "事项未能保存，请检查填写内容后重试。" : store.error }
                }
                    .buttonStyle(PixelButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
                    .disabled(task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (categoryChoice == "自定义" && (customCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || customCategory.count > 40)))
            }
        }.padding(28).frame(width: 420).magicSurface(Palette.paper, strong: true).magicControls()
    }
}

struct FocusPage: View {
    @ObservedObject var store: GardenStore
    var body: some View {
        VStack(spacing: 20) {
            Card(title: "计时器", icon: "timer") { TimerControls(store: store, compact: false) }
            Card(title: "今日记录", icon: "clock") {
                if store.todaySessions.isEmpty { EmptyNote(text: "今日还没有专注记录") }
                ForEach(store.todaySessions.reversed()) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(session.title)
                            Text("\(session.kind.rawValue) · \(session.date.formatted(.dateTime.hour().minute())) 结束").font(.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Text(clockText(session.seconds)).monospacedDigit()
                    }.padding(.vertical, 6)
                }
            }
        }
    }
}

struct TimerControls: View {
    @ObservedObject var store: GardenStore
    var compact: Bool
    @State private var kind: TimerKind = .pomodoro
    private var minutes: Int { store.focusDraftMinutes }
    @State private var taskID: UUID?
    @State private var customTitle = "自由专注"
    @State private var selectingTask = false
    init(store: GardenStore, compact: Bool) {
        self.store = store
        self.compact = compact
    }
    var body: some View {
        VStack(spacing: compact ? 17 : 24) {
            if let run = store.data.timer {
                HStack {
                    Text(run.kind.rawValue).font(.caption).padding(.horizontal, 10).padding(.vertical, 5).background(Palette.moss.opacity(0.5), in: PixelFrame())
                    Spacer()
                    Text(run.resumedAt == nil ? "已暂停" : "进行中").font(.caption).foregroundStyle(Palette.muted)
                }
                Text(clockText(run.display(at: store.now)))
                    .font(.system(size: compact ? 54 : 72, weight: .regular, design: .monospaced)).monospacedDigit().foregroundStyle(Palette.goldLight).padding(.vertical, 10)
                Text(run.taskTitle).font(.callout).foregroundStyle(Palette.muted).lineLimit(2)
                if run.kind != .stopwatch {
                    PixelProgress(value: run.elapsed(at: store.now) / run.target)
                }
                HStack(spacing: 12) {
                    Button(run.resumedAt == nil ? "继续" : "暂停", systemImage: run.resumedAt == nil ? "play.fill" : "pause.fill") {
                        run.resumedAt == nil ? store.resumeTimer() : store.pauseTimer()
                    }.buttonStyle(PixelButtonStyle(primary: true))
                    Button(run.kind == .rest ? "结束休息" : "结束并记录") { store.finishTimer() }.buttonStyle(PixelButtonStyle())
                }
                Text(run.kind == .rest ? "休息中" : "每 5 分钟专注 · 1 滴露水")
                    .font(.caption).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            } else {
                PixelTabs(selection: $kind, items: [(.pomodoro, "番茄钟"), (.stopwatch, "正计时"), (.countdown, "倒计时")])
                Text(kind == .stopwatch ? "00:00" : clockText(Double(minutes * 60)))
                    .font(.system(size: compact ? 54 : 72, weight: .regular, design: .monospaced)).monospacedDigit().foregroundStyle(Palette.goldLight).padding(.vertical, 10)
                if kind != .stopwatch { PixelStepper(title: "时长", value: $store.focusDraftMinutes, range: 1...180).frame(maxWidth: 310) }
                Button { selectingTask = true } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                        Text(store.data.tasks.first { $0.id == taskID }?.title ?? customTitle).lineLimit(2)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }.frame(maxWidth: compact ? 290 : 380)
                }.buttonStyle(PixelButtonStyle()).accessibilityLabel("选择专注事项").help("选择现有任务、新建任务或填写本次名称")
                HStack(spacing: 12) {
                    Button("开始专注", systemImage: "play.fill") {
                        store.startTimer(kind: kind, minutes: minutes, task: store.data.tasks.first { $0.id == taskID }, title: customTitle)
                    }.buttonStyle(PixelButtonStyle(primary: true)).controlSize(.large)
                    if store.canStartBreak {
                        Button("休息 \(store.data.preferences.breakMinutes) 分钟") {
                            store.startTimer(kind: .rest, minutes: store.data.preferences.breakMinutes, task: nil)
                        }.buttonStyle(PixelButtonStyle())
                    }
                }
            }
        }.frame(maxWidth: .infinity).padding(.vertical, compact ? 6 : 20)
            .sheet(isPresented: $selectingTask) {
                FocusTaskPicker(store: store) { task, title in
                    taskID = task?.id; customTitle = title; selectingTask = false
                }
            }
    }
}


struct FocusTaskPicker: View {
    @ObservedObject var store: GardenStore
    var choose: (GardenTask?, String) -> Void
    @State private var creating = false
    @State private var title = ""
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss
    private var tasks: [GardenTask] {
        store.data.tasks.filter { $0.completedAt == nil && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.categoryName.localizedCaseInsensitiveContains(search)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("这次想做什么？").font(.title2); Spacer(); Button("关闭") { dismiss() } }
            TextField("搜索现有任务或类型", text: $search).textFieldStyle(PixelTextFieldStyle())
            PixelScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if tasks.isEmpty { EmptyNote(text: "没有找到未完成的事项") }
                    ForEach(tasks) { task in
                        Button { choose(task, task.title) } label: {
                            HStack { Text(task.title).multilineTextAlignment(.leading); Spacer(); Text(task.categoryName).font(.caption).foregroundStyle(Palette.muted) }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(PixelButtonStyle()).accessibilityLabel(task.title)
                    }
                }
            }.frame(height: 210)
            Button("新建任务并选择", systemImage: "plus") { creating = true }.buttonStyle(PixelButtonStyle())
            Divider()
            Text("只给本次计时起个名字").font(.callout)
            HStack {
                TextField("例如：休闲阅读", text: $title).textFieldStyle(PixelTextFieldStyle())
                Button("使用") { choose(nil, title.trimmingCharacters(in: .whitespacesAndNewlines)) }.buttonStyle(PixelButtonStyle(primary: true)).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Button("自由专注") { choose(nil, "自由专注") }.buttonStyle(PixelButtonStyle())
        }.padding(26).frame(width: 470).magicSurface(Palette.paper, strong: true).magicControls()
            .sheet(isPresented: $creating) { TaskEditor(store: store, task: GardenTask(title: "", category: "待办")) { task in choose(task, task.title) } }
    }
}
