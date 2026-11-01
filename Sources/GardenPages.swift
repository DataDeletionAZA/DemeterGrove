import SwiftUI
import Charts
import AppKit

struct FarmPage: View {
    @ObservedObject var store: GardenStore
    var section: String? = nil
    @State private var selection = "农场"
    var body: some View {
        VStack(spacing: 12) {
            if section == nil { PixelTabs(selection: $selection, items: ["农场", "厨房", "商店"].map { ($0, $0) }) }
            GameRoomView(store: store, room: section ?? selection).id(section ?? selection)
        }
    }
}

struct SettingsPage: View {
    @ObservedObject var store: GardenStore
    @State private var section = "通用"
    private let sections = ["通用", "桌宠", "专注与提醒", "AI 服务", "表达与提示词", "存档"]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SceneToolbar(items:sections.map {item in SceneToolbarItem(item,selected:section == item){section=item}})
            sectionContent
        }
    }
    @ViewBuilder private var sectionContent: some View {
        VStack(spacing: 20) {
            if section == "桌宠" {
            Card(title: "桌宠", icon: "person.crop.square") {
                HStack(spacing: 32) {
                    ProfessorSprite(phase:store.petPhase,size:120,economy:store.data.garden.economy,idlePose:store.idlePose,expression:store.petExpression,basePhase:store.petBasePhase,skin:store.data.preferences.selectedPetSkin)
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("名字", text: $store.data.preferences.name).textFieldStyle(PixelTextFieldStyle()).frame(maxWidth: 260)
                        Toggle("在桌面显示", isOn: Binding(get: { store.data.preferences.petVisible }, set: { store.setPet($0) }))

                    }
                }
            }
            PetDialogueSettingsView(store: store)
            }
            if section == "通用" {
            Card(title: "操作计数", icon: "keyboard") {
                Toggle("统计键盘与鼠标点击", isOn: Binding(get: { store.data.preferences.typingEnabled }, set: { store.setTyping($0) }))
                Text(store.data.preferences.typingEnabled ? store.inputStatus : "计数未开启").font(.callout).foregroundStyle(Palette.sage)
                if store.data.preferences.typingEnabled && store.inputStatus != "正在计数" {
                    Button("打开系统的输入监控设置") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                    }
                }
            }
            DaySettingsView(store:store)
            Card(title:"日历",icon:"calendar") {
                HStack {
                    Text("一周开始于")
                    PixelSelect(selection:Binding(get:{store.data.preferences.weekStartsOn ?? 2},set:{store.data.preferences.weekStartsOn=$0}),items:[(2,"周一"),(1,"周日")]).frame(width:150)
                }
            }
            }
            if section == "专注与提醒" {
            Card(title: "专注与提醒", icon: "bell") {
                PixelStepper(title: "默认专注", value: $store.data.preferences.focusMinutes, range: 1...180).frame(maxWidth: 360)
                PixelStepper(title: "默认休息", value: $store.data.preferences.breakMinutes, range: 1...60).frame(maxWidth: 360)
                Toggle("完成时播放轻提示音", isOn: $store.data.preferences.sound)
                HStack {
                    Button(store.data.preferences.notifications ? "重新检查通知权限" : "开启计时和日程通知") { store.requestNotifications() }
                    if store.data.preferences.notifications {
                        Button("关闭通知") { store.data.preferences.notifications = false; store.refreshReminders() }
                        Text("已获允许").font(.caption).foregroundStyle(Palette.sage)
                    }
                }

            }
            }
            if section == "AI 服务" { AISettingsView(store:store) }
            if section == "表达与提示词" { AIPromptSettingsView(store:store) }
            if section == "存档" {
            Card(title: "存档与备份", icon: "externaldrive") {
                Text(store.saveStatus).font(.callout).foregroundStyle(Palette.muted)
                VStack(alignment: .leading, spacing: 10) {
                    Button("导出备份") { store.exportData() }.buttonStyle(PixelButtonStyle(primary: true))
                    Button("恢复备份") { store.importData() }.buttonStyle(PixelButtonStyle())
                    Button("打开存档文件夹") { NSWorkspace.shared.open(store.file.deletingLastPathComponent()) }
                }
                Text("暮色小院 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版")").font(.caption).foregroundStyle(Palette.muted)
            }
            }
        }
    }
}
