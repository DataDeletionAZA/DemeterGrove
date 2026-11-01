import SwiftUI

struct FocusReviewButton: View {
    @ObservedObject var store: GardenStore
    var sessionID: UUID
    var client = AIClient()
    @State private var request: Task<Void, Never>?
    @State private var requestID = UUID()
    @State private var working = false
    @State private var error = ""
    private var session: FocusSession? { store.data.sessions.first { $0.id == sessionID } }
    private var busy: Bool { working || store.focusReviewRequests[sessionID] != nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            AIWritingPresetPicker(store: store, feature: .focusReview).disabled(busy)
            HStack {
                Button(working ? "评价中…" : "请 AI 评价") { generate() }.buttonStyle(PixelButtonStyle()).disabled(busy || session == nil)
                if working { Button("取消") { cancel() }.buttonStyle(PixelButtonStyle()) }
            }
            if let profile = store.data.ai?.profile(for: .focusReview) {
                Text("发送至 \(AIProfile.secureURL(profile.baseURL)?.host ?? profile.name) · \(profile.model)").font(.caption).foregroundStyle(Palette.muted)
            }
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.clay) }
        }.onDisappear { cancel() }
    }
    private func cancel() {
        if store.focusReviewRequests[sessionID] == requestID { store.focusReviewRequests[sessionID] = nil }
        requestID = UUID(); request?.cancel(); request = nil; working = false
    }
    private func generate() {
        guard store.focusReviewRequests[sessionID] == nil else { return }
        guard let snapshot = session, let profile = store.data.ai?.profile(for: .focusReview) else { error = "请先在设置中为专注评价选择 API 预设。"; return }
        cancel(); error = ""; working = true
        let id = requestID, writing = store.data.ai?.writing(for: .focusReview) ?? .standard
        store.focusReviewRequests[sessionID] = id
        request = Task { @MainActor in
            defer { if store.focusReviewRequests[sessionID] == id { store.focusReviewRequests[sessionID] = nil } }
            do {
                let feedback = try await client.reviewFocus(profile: profile, record: snapshot.aiReviewRecord(boundary: store.dayBoundary), writing: writing)
                guard !Task.isCancelled, id == requestID else { return }
                guard session == snapshot, store.data.ai?.profile(for: .focusReview) == profile,
                      (store.data.ai?.writing(for: .focusReview) ?? .standard) == writing else {
                    error = "记录或预设已变化，请重新评价。"; working = false; return
                }
                if !store.updateFocusFeedback(sessionID, feedback: feedback) { error = "评价未能保存，请重试。" }
            } catch {
                guard !Task.isCancelled, id == requestID else { return }
                self.error = AIError.message(error)
            }
            guard id == requestID else { return }; working = false; request = nil
        }
    }
}

extension FocusSession {
    func aiReviewRecord(boundary: DayBoundary) -> String {
        let values: [String: Any] = [
            "名称": title, "类型": kind.rawValue,
            "开始时间": beganAt.map { boundary.timestamp($0) } ?? "未知",
            "结束时间": endedAt.map { boundary.timestamp($0) } ?? "未知",
            "专注秒数": kind == .rest ? 0 : seconds,
            "休息秒数": kind == .rest ? seconds : 0,
            "暂停次数": pauseCount.map(String.init) ?? "未知",
            "暂停秒数": pausedSeconds.map { String(Int($0)) } ?? "未知",
            "心情或状态": mood ?? "", "感想": notes ?? ""
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]), let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
}
