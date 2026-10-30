import SwiftUI
import AppKit

struct FocusSessionEditor: View {
    @ObservedObject var store: GardenStore
    var sessionID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sceneViewport) private var viewport
    @State private var title = ""
    @State private var notes = ""
    @State private var recordingMood = false
    @State private var mood = Diary()
    @State private var taskAction: FocusTaskAction = .none
    @State private var rescheduleDate = Date()
    @State private var loaded = false
    @State private var error = ""
    private var dialogSize: CGSize {
        let screen = NSScreen.main?.visibleFrame.size ?? viewport
        return SceneSizing.dialog(preferred: CGSize(width: 580, height: 680),
                                  viewport: CGSize(width: min(viewport.width, screen.width - 50), height: min(viewport.height, screen.height - 80)))
    }
    private var session: FocusSession? { store.data.sessions.first { $0.id == sessionID } }
    private var occurrence: TaskOccurrence? { session.flatMap { store.data.focusTaskOccurrence(for: $0, calendar: store.calendar) } }
    private var hasUnsavedContent: Bool {
        guard let session else { return false }
        return title != session.title || notes != (session.notes ?? "") ||
            (recordingMood ? mood.mood : nil) != session.mood ||
            (recordingMood ? mood.moodSymbol : nil) != session.moodSymbol ||
            (recordingMood ? mood.moodImage : nil) != session.moodImage || taskAction != .none
    }
    private var savedMoods: [Diary] {
        store.data.sessions.compactMap { value in value.mood.map { Diary(mood: $0, moodSymbol: value.moodSymbol, moodImage: value.moodImage) } }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(session?.kind == .rest ? "休息记录" : "专注收尾").font(.title2.bold())
                Spacer()
                Button("关闭") { close() }.buttonStyle(PixelButtonStyle())
            }
            if let session {
                PixelScrollView {
                    VStack(alignment: .leading, spacing: 17) {
                        FocusRecordDetails(session: session)
                        TextField("本次名称", text: $title).textFieldStyle(PixelTextFieldStyle()).accessibilityLabel("本次名称")
                        Text("感想").font(.headline)
                        TextEditor(text: $notes).frame(minHeight: 95, maxHeight: 140).scrollContentBackground(.hidden).padding(8).magicSurface(Palette.card).accessibilityLabel("专注感想")
                        Toggle("记录心情 / 状态", isOn: $recordingMood)
                        if recordingMood { DiaryMoodPicker(diary: $mood, saved: savedMoods) }
                        if let occurrence, session.kind != .rest {
                            Divider()
                            Text("关联任务：" + occurrence.task.title).font(.callout)
                            if let day = occurrence.displayDay { Text("本期日期：" + day).font(.caption).foregroundStyle(Palette.muted) }
                            PixelSelect(selection: $taskAction, items: FocusTaskAction.allCases.map { ($0, $0.rawValue) })
                            if taskAction == .reschedule { PixelDatePicker(title: "本期改到", selection: $rescheduleDate) }
                        }
                        if let feedback = session.aiFeedback {
                            Divider()
                            Text("专注回顾").font(.headline)
                            Text(feedback).textSelection(.enabled)
                            if let date = session.aiReviewedAt {
                                Text(date.formatted(date: .abbreviated, time: .shortened) + (session.aiFeedbackIsEarlierVersion ? " · 基于此前记录" : "")).font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                        if session.kind != .rest {
                            if hasUnsavedContent { Button("保存当前内容") { save(closeAfter: false) }.buttonStyle(PixelButtonStyle()) }
                            FocusReviewButton(store: store, sessionID: sessionID).disabled(hasUnsavedContent)
                        }
                    }.frame(width: max(180, dialogSize.width - 104), alignment: .leading).padding(.trailing, 40)
                }.frame(width: max(1, dialogSize.width - 48))
                if !error.isEmpty { Text(error).font(.callout).foregroundStyle(Palette.clay) }
                HStack {
                    Button("跳过收尾") { close() }.buttonStyle(PixelButtonStyle())
                    Spacer()
                    Button("保存") { save() }.buttonStyle(PixelButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 1000 || notes.count > 20_000)
                }
            } else { Text("找不到这段记录。").foregroundStyle(Palette.muted) }
        }.padding(24).frame(width: dialogSize.width, height: dialogSize.height)
            .magicSurface(Palette.paper, strong: true).magicControls().environment(\.calendar, store.calendar)
            .onAppear { load() }
    }
    private func load() {
        guard !loaded, let session else { return }
        loaded = true; title = session.title; notes = session.notes ?? ""
        recordingMood = session.mood != nil
        mood = Diary(mood: session.mood ?? "平静", moodSymbol: session.moodSymbol, moodImage: session.moodImage)
        rescheduleDate = occurrence?.displayDay.flatMap { Recurrence.date($0, calendar: store.calendar) } ?? store.now
    }
    private func save(closeAfter: Bool = true) {
        guard store.updateFocusSession(sessionID, title: title, notes: notes, mood: recordingMood ? mood.mood : nil,
                                       moodSymbol: recordingMood ? mood.moodSymbol : nil, moodImage: recordingMood ? mood.moodImage : nil,
                                       taskAction: taskAction, rescheduleDate: taskAction == .reschedule ? rescheduleDate : nil) else {
            error = store.error.isEmpty ? "保存失败，请重试。" : store.error; return
        }
        error = ""; taskAction = .none
        title = session?.title ?? title
        if closeAfter { close() }
    }
    private func close() {
        if store.pendingFocusReviewID == sessionID { store.pendingFocusReviewID = nil }
        dismiss()
    }
}

struct FocusRecordDetails: View {
    var session: FocusSession
    @State private var showingSegments = false
    @State private var showingPauses = false
    private func dateText(_ date: Date?) -> String { date?.formatted(date: .abbreviated, time: .standard) ?? "未知" }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack { Text(session.kind.rawValue); Spacer(); Text(clockText(session.seconds)).monospacedDigit().fixedSize().foregroundStyle(Palette.goldLight) }
            Text("开始：" + dateText(session.beganAt)).font(.callout)
            Text("结束：" + dateText(session.endedAt)).font(.callout)
            if session.kind != .rest {
                Text("暂停：" + (session.pauseCount.map { "\($0) 次" } ?? "未知") + " · " + (session.pausedSeconds.map(clockText) ?? "未知")).font(.callout)
            }
            if let segments = session.segments {
                Button { showingSegments.toggle() } label: {
                    HStack { Text(session.kind == .rest ? "休息片段" : "实际专注片段"); Spacer(); Image(systemName: showingSegments ? "chevron.up" : "chevron.down") }
                }.buttonStyle(PixelButtonStyle()).accessibilityLabel(session.kind == .rest ? "休息片段" : "实际专注片段").accessibilityValue(showingSegments ? "已展开" : "已收起")
                if showingSegments { ForEach(Array(segments.enumerated()), id: \.offset) { _, interval in intervalRow(interval) } }
            } else { Text("实际片段：未知").font(.caption).foregroundStyle(Palette.muted) }
            if session.kind != .rest, let pauses = session.pauseIntervals, !pauses.isEmpty {
                Button { showingPauses.toggle() } label: {
                    HStack { Text("暂停区间"); Spacer(); Image(systemName: showingPauses ? "chevron.up" : "chevron.down") }
                }.buttonStyle(PixelButtonStyle()).accessibilityLabel("暂停区间").accessibilityValue(showingPauses ? "已展开" : "已收起")
                if showingPauses { ForEach(Array(pauses.enumerated()), id: \.offset) { _, interval in intervalRow(interval) } }
            }
        }
    }
    private func intervalRow(_ interval: FocusInterval) -> some View {
        HStack {
            Text(interval.beganAt.formatted(date: .abbreviated, time: .standard) + " — " + interval.endedAt.formatted(date: .abbreviated, time: .standard))
            Spacer(); Text(clockText(interval.seconds)).monospacedDigit().fixedSize()
        }.font(.caption).padding(.vertical, 3)
    }
}
