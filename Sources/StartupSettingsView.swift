import SwiftUI
import AppKit
import ServiceManagement

struct StartupSettingsView: View {
    @State private var status = SMAppService.mainApp.status
    @State private var error = ""

    var body: some View {
        Card(title: "启动", icon: "settings") {
            Toggle("开机自动启动", isOn: Binding(
                get: { status == .enabled || status == .requiresApproval },
                set: setEnabled
            )).toggleStyle(PixelToggleStyle())
            if status == .requiresApproval {
                Text("等待系统允许").font(.caption).foregroundStyle(Palette.clay)
                Button("打开系统登录项设置") { SMAppService.openSystemSettingsLoginItems() }
            }
            if !error.isEmpty {
                Text(error).font(.caption).foregroundStyle(Palette.clay)
            }
        }
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private func refresh() {
        status = SMAppService.mainApp.status
    }

    private func setEnabled(_ enabled: Bool) {
        error = ""
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled && service.status != .requiresApproval {
                    try service.register()
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
        } catch {
            self.error = "启动设置未能更新：\(error.localizedDescription)"
        }
        refresh()
    }
}
