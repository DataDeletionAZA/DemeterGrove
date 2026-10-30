import SwiftUI
import AppKit
import Combine
import UserNotifications

let desktopTools: [(String, String)] = [
    ("任务", "checklist"), ("计时器", "timer"),
    ("日程", "calendar"), ("习惯", "checkmark.circle"), ("日记", "book.closed"),
    ("农场", "carrot"), ("厨房", "frying.pan"), ("商店", "storefront"), ("统计", "chart.bar"),
    ("成长", "sparkles"), ("地图", "map"), ("衣柜", "tshirt")
]

@main
enum DaygardenApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) { }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let store = GardenStore(preview: CommandLine.arguments.contains("--preview"))
    private var item: NSStatusItem!
    private var clock: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        if store.preview { store.seedPreview() }
        store.openMain = { [weak self] in self?.store.pet?.openManager() }
        store.pet = PetController(store: store)
        store.setPet(true)
        if !store.preview, store.data.preferences.typingEnabled { store.setTyping(true, requestPermission: false) }
        if !store.preview, store.data.preferences.notifications { store.refreshReminders() }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "leaf", accessibilityDescription: "暮色小院")
        let menu = NSMenu()
        add("显示桌宠", key: "pet", to: menu)
        menu.addItem(.separator())
        for tool in desktopTools { add(tool.0, key: tool.0, to: menu) }
        menu.addItem(.separator())
        add("设置", key: "设置", to: menu)
        add("管理窗口", key: "manager", to: menu)
        add("退出", key: "quit", to: menu)
        item.menu = menu
        clock = store.$now.sink { [weak self] date in
            guard let self else { return }
            self.item?.button?.title = self.store.data.timer.map { " " + clockText($0.display(at: date)) } ?? ""
        }
        let main = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出暮色小院", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        let edit = NSMenu(title: "编辑")
        for (title, action, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        let editItem = NSMenuItem(); editItem.submenu = edit; main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func add(_ title: String, key: String, to menu: NSMenu) {
        let entry = NSMenuItem(title: title, action: #selector(action(_:)), keyEquivalent: "")
        entry.target = self; entry.representedObject = key; menu.addItem(entry)
    }
    @objc private func action(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        switch key {
        case "pet": store.setPet(true)
        case "manager": store.pet?.openManager()
        case "quit": NSApp.terminate(nil)
        default: store.pet?.openTool(key)
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { store.setPet(true); return false }
    func applicationWillTerminate(_ notification: Notification) { store.shutdown() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}

final class PetController {
    let panel: NSPanel
    private let store: GardenStore
    private let menuPanel = MagicPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
    private var toolPanel: NSPanel?
    private var manager: NSWindow?
    private var moveObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?
    private var localClicks: Any?
    private var globalClicks: Any?
    private let toast = ToastController()
    private var toastSubscription: AnyCancellable?
    private var menuSide: PetMenuSide?
    private var toolSide: PetMenuSide?
    private var toolHistory: [String] = []
    private var toolViews: [String: NSHostingView<ToolPanelView>] = [:]
    private var positioning = false
    private var resizingTool = false
    var managerIsOpen: Bool { manager?.isVisible == true || manager?.isMiniaturized == true }
    init(store: GardenStore) {
        self.store = store
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 310),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = "暮色小院 · 桌宠"
        panel.isReleasedWhenClosed = false
        panel.setFrameAutosaveName("DaygardenPet")
        panel.contentView = NSHostingView(rootView: DesktopPet(store: store, click: { [weak self] in self?.store.clickPet() }, menu: { [weak self] in self?.toggleMenu() }, drag: { [weak self] direction in
            self?.store.dragPet(direction)
        }, drop: { [weak self] in self?.finishPetDrag() }, move: { [weak self] origin, pointer in self?.movePet(to: origin, pointer: pointer) }))
        if !panel.setFrameUsingName("DaygardenPet"), let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 220, y: screen.visibleFrame.minY + 25))
        }
        store.petDocked = panel.frame.height < 250
        panel.setContentSize(NSSize(width:200,height:store.petDocked ? 225:310))
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }), let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 220, y: screen.visibleFrame.minY + 25))
        }
        menuPanel.isOpaque = false
        menuPanel.backgroundColor = .clear
        menuPanel.hasShadow = false
        menuPanel.level = .floating
        menuPanel.hidesOnDeactivate = false
        menuPanel.isMovable = false
        menuPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        menuPanel.isReleasedWhenClosed = false
        menuPanel.title = "桌宠菜单"
        menuPanel.contentView = NSHostingView(rootView: PetMenu(store: store))
        moveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
            self?.positionChanged()
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.positionChanged()
        }
        localClicks = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.toast.outsideClick(window:event.window,point:NSEvent.mouseLocation)
            return event
        }
        globalClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.toast.outsideClick(window:nil,point:NSEvent.mouseLocation)
        }
        toastSubscription = store.$message.sink { [weak self] message in
            guard let self else { return }
            self.toast.show(message,anchor:{ [weak self] in self?.toastAnchor ?? .zero },cleared:{ [weak self] in self?.store.message = "" })
        }
        positionChanged()
    }
    deinit {
        if let moveObserver { NotificationCenter.default.removeObserver(moveObserver) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
        if let localClicks { NSEvent.removeMonitor(localClicks) }
        if let globalClicks { NSEvent.removeMonitor(globalClicks) }
    }
    private var screenArea: NSRect {
        PetPlacement.screen(for: panel.frame, screens: NSScreen.screens.map(\.visibleFrame))
    }
    private var toastAnchor: NSRect {
        if let toolPanel, toolPanel.isVisible { return toolPanel.frame }
        if let manager, manager.isVisible { return manager.frame }
        return panel.frame
    }
    private func finishPetDrag() {
        let area = screenArea
        let dock = panel.frame.minY <= area.minY + 22
        let top = panel.frame.maxY
        store.petDocked = dock
        panel.setContentSize(NSSize(width:200,height:dock ? 225:310))
        panel.setFrameOrigin(NSPoint(x:panel.frame.minX,y:dock ? area.minY:max(area.minY,top-310)))
        positionChanged()
        store.dropPet()
    }
    func movePet(to origin: NSPoint, pointer: NSPoint) {
        var proposed = panel.frame
        proposed.origin = origin
        let area = PetPlacement.screen(for: proposed, screens: NSScreen.screens.map(\.visibleFrame), pointer: pointer)
        panel.setFrameOrigin(PetPlacement.constrain(proposed, to: area).origin)
        positionChanged()
    }
    func positionChanged() {
        guard !positioning else { return }
        positioning = true
        defer { positioning = false }
        let area = screenArea
        let clamped = PetPlacement.constrain(panel.frame, to: area)
        if clamped.origin != panel.frame.origin { panel.setFrameOrigin(clamped.origin) }
        store.petFacingRight = PetPlacement.facingRight(pet: panel.frame, screen: area, previous: store.petFacingRight)
        if menuPanel.isVisible { positionMenu() }
        if toolPanel?.isVisible == true, !resizingTool { positionTool() }
        toast.position()
    }
    private func positionMenu() {
        let size = NSSize(width: min(320, screenArea.width-16), height: min(store.data.timer == nil ? 590 : 670, screenArea.height-16))
        if menuPanel.frame.size != size { menuPanel.setContentSize(size) }
        let placement = PetPlacement.menu(pet: panel.frame, size: menuPanel.frame.size, screen: screenArea, previous: menuSide)
        menuSide = placement.1
        menuPanel.setFrameOrigin(placement.0)
    }
    func beginToolResize() { resizingTool = true }
    func finishToolResize() { resizingTool = false; positionChanged() }
    private func positionTool() {
        guard let toolPanel else { return }
        let area = screenArea
        let sideWidth = max(panel.frame.minX-area.minX-16, area.maxX-panel.frame.maxX-16)
        let maximum = NSSize(width: min(area.width-16, max(360, sideWidth)), height: area.height-16)
        toolPanel.minSize = NSSize(width: min(460, maximum.width), height: min(420, maximum.height))
        if toolPanel.frame.width > maximum.width || toolPanel.frame.height > maximum.height {
            toolPanel.setContentSize(NSSize(width: min(toolPanel.frame.width, maximum.width), height: min(toolPanel.frame.height, maximum.height)))
        }
        let placement = PetPlacement.menu(pet: panel.frame, size: toolPanel.frame.size, screen: area, previous: toolSide)
        toolSide = placement.1
        toolPanel.setFrameOrigin(placement.0)
    }
    func show() { panel.orderFrontRegardless() }
    func hide() { dismissFloating(); panel.orderOut(nil) }
    func closeMenu() { panel.removeChildWindow(menuPanel); menuPanel.orderOut(nil); menuSide = nil }
    func closeTool() {
        if let toolPanel { panel.removeChildWindow(toolPanel); toolPanel.orderOut(nil); toolPanel.contentView = nil }
        toolViews.removeAll()
        toolHistory.removeAll()
        toolSide = nil
    }
    private func dismissFloating() { closeMenu(); closeTool() }
    func back() {
        if let previous = toolHistory.popLast() { showTool(previous) }
        else { closeTool(); showMenu() }
    }
    func toggleMenu() {
        if managerIsOpen { openManager(); return }
        if menuPanel.isVisible { menuPanel.makeKeyAndOrderFront(nil); return }
        closeTool()
        toolHistory.removeAll()
        showMenu()
    }
    private func showMenu() {
        menuPanel.setContentSize(NSSize(width:320,height:min(store.data.timer == nil ? 590:670,screenArea.height-20)))
        positionMenu()
        panel.addChildWindow(menuPanel, ordered: .above)
        NSApp.activate(ignoringOtherApps: true)
        menuPanel.makeKeyAndOrderFront(nil)
    }
    func openTool(_ name: String) {
        let name = ["待办":"任务", "四象限":"任务", "专注":"计时器"][name] ?? name
        if managerIsOpen {
            store.selectedPage = ["待办":"任务", "计时器":"专注"][name] ?? name
            openManager()
            return
        }
        if toolPanel?.isVisible == true, store.activeTool != name { toolHistory.append(store.activeTool) }
        else if menuPanel.isVisible || toolPanel?.isVisible != true { toolHistory.removeAll() }
        closeMenu()
        showTool(name)
    }
    private func showTool(_ name: String) {
        if name == "统计" {store.previewMotion(.review)}
        store.activeTool = name
        let game = ["首页", "书房", "农场", "厨房", "商店", "成长", "地图", "湖畔钓鱼", "林间冒险", "熬制魔药", "衣柜"].contains(name)
        let wide = name == "任务" || game
        let preserveSize = toolPanel?.isVisible == true
        if toolPanel == nil {
            let panel = MagicPanel(contentRect: .zero, styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.isMovable = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.minSize = NSSize(width: 460, height: 420)
            toolPanel = panel
            resizeObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: panel, queue: .main) { [weak self] _ in self?.positionChanged() }
        }
        guard let toolPanel else { return }
        if toolViews[name] == nil { toolViews[name] = NSHostingView(rootView: ToolPanelView(store: store, tool: name)) }
        toolPanel.contentView = toolViews[name]
        toolPanel.title = name
        let area = screenArea
        toolPanel.minSize = NSSize(width: min(game ? 640 : 460, area.width-16), height: min(420,area.height-16))
        if !preserveSize {
            toolPanel.setContentSize(NSSize(width:min(game ? 760:wide ? 720:490,area.width-16),height:min(game ? 820:name == "计时器" ? 500:650,area.height-16)))
        }
        positionTool()
        if toolPanel.parent !== panel { panel.addChildWindow(toolPanel, ordered: .above) }
        NSApp.activate(ignoringOtherApps: true)
        toolPanel.makeKeyAndOrderFront(nil)
    }
    func openManager() {
        closeMenu()
        closeTool()
        if manager == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 720),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "暮色小院 · 管理"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: RootView(store: store))
            window.center()
            manager = window
        }
        NSApp.activate(ignoringOtherApps: true)
        if manager?.isMiniaturized == true { manager?.deminiaturize(nil) }
        manager?.makeKeyAndOrderFront(nil)
    }
}

struct DesktopPet: View {
    @ObservedObject var store: GardenStore
    @State private var countScope = 0
    var click: () -> Void
    var menu: () -> Void
    var drag: (CGFloat) -> Void
    var drop: () -> Void
    var move: (NSPoint, NSPoint) -> Void
    private var countBadge: some View {
        let title = ["目前","今日","总量"][countScope]
        let count = [store.data.availableActions,store.todayActions,store.data.totalActions][countScope]
        return Button { countScope = (countScope+1)%3 } label: {
            HStack(spacing:6) {
                Image(systemName:"keyboard")
                Text(title).foregroundStyle(Palette.muted)
                Text(compactActionCount(count)).monospacedDigit()
            }.font(.system(size:11,weight:.medium)).foregroundStyle(Palette.ink)
                .padding(.horizontal,10).frame(height:24).magicSurface(Palette.card.opacity(0.94))
        }.buttonStyle(.plain)
            .accessibilityLabel("切换计数").accessibilityValue(title+"："+count.formatted()+" 次")
            .help(title+"："+count.formatted()+" 次")
    }
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ProfessorSprite(phase:store.petPhase,size:200,economy:store.data.garden.economy,lookDirection:store.petLookDirection,motionStart:store.tapPhase == 0 ? nil:store.petAnimationBegan,idlePose:store.idlePose,expression:store.petExpression,dragImpulse:Double(store.petDragImpulse),dragUpdated:store.petDragUpdated,basePhase:store.petBasePhase,facingRight:store.petFacingRight,glances:true,grounded:store.petDocked).frame(width:200,height:225)
                PetDragSurface(click:click,drag:drag,drop:drop,move:move,look:{point,size in store.updatePetLook(point:point,size:size)})
            }.frame(width:200,height:225)
            if !store.petDocked {
            HStack(spacing: 6) {
                countBadge
                Button(action:menu) {
                    Image(systemName:"ellipsis").font(.system(size:12,weight:.semibold)).foregroundStyle(Palette.ink)
                        .frame(width:24,height:24).magicSurface(Palette.card.opacity(0.94))
                }.buttonStyle(.plain).accessibilityLabel("功能菜单").help("功能菜单")
            }
            if let timer = store.data.timer {
                Button { store.pet?.openTool("计时器") } label: {
                    HStack(spacing: 6) {
                        Image(systemName: timer.resumedAt == nil ? "pause.fill" : timer.kind == .rest ? "moon.fill" : "timer").font(.system(size:10))
                        Text(clockText(timer.display(at:store.now))).font(.system(size:14,weight:.medium)).monospacedDigit()
                        Text(timer.resumedAt == nil ? "暂停" : timer.kind == .rest ? "休息" : "专注").font(.system(size:10))
                    }.foregroundStyle(Palette.goldLight).padding(.horizontal,9).frame(height:28).magicSurface(Palette.card.opacity(0.94))
                }.buttonStyle(.plain).padding(.top,5).accessibilityLabel("打开当前计时")
            }
            }
            Spacer(minLength: 0)
        }.frame(width:200,height:store.petDocked ? 225:310,alignment:.top).preferredColorScheme(.dark)
            .onChange(of:store.error) { _,value in
                if !value.isEmpty {store.animatePet(PetMotion.failed.rawValue,seconds:PetMotion.failed.duration)}
            }
    }
}

struct PetDragSurface: NSViewRepresentable {
    var click: () -> Void
    var drag: (CGFloat) -> Void
    var drop: () -> Void
    var move: (NSPoint, NSPoint) -> Void
    var look:(CGPoint?,CGSize)->Void
    func makeNSView(context: Context) -> PetDragView { let view = PetDragView(); view.click = click; view.drag = drag; view.drop = drop; view.move=move; view.look=look; return view }
    func updateNSView(_ view: PetDragView, context: Context) { view.click = click; view.drag = drag; view.drop = drop; view.move=move; view.look=look }
}

final class PetDragView: NSView {
    var click: (() -> Void)?
    var drag: ((CGFloat) -> Void)?
    var move: ((NSPoint, NSPoint) -> Void)?
    var drop: (() -> Void)?
    var look:((CGPoint?,CGSize)->Void)?
    private var mouseArea:NSTrackingArea?
    override var isFlipped:Bool {true}
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let mouseArea {removeTrackingArea(mouseArea)}
        let area=NSTrackingArea(rect:bounds,options:[.mouseMoved,.mouseEnteredAndExited,.activeAlways,.inVisibleRect],owner:self)
        addTrackingArea(area);mouseArea=area
    }
    override func mouseEntered(with event:NSEvent) {mouseMoved(with:event)}
    override func mouseMoved(with event:NSEvent) {look?(convert(event.locationInWindow,from:nil),bounds.size)}
    override func mouseExited(with event:NSEvent) {look?(nil,bounds.size)}
    private var start = NSPoint.zero
    private var origin = NSPoint.zero
    private var lastDrag = NSPoint.zero
    private var lastDragTime: TimeInterval = 0
    private var moved = false
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { start = NSEvent.mouseLocation;lastDrag=start;lastDragTime=event.timestamp; origin = window?.frame.origin ?? .zero; moved = false }
    override func mouseDragged(with event: NSEvent) {
        let point = NSEvent.mouseLocation
        let delta = NSPoint(x: point.x - start.x, y: point.y - start.y)
        guard moved || hypot(delta.x, delta.y) > 3 else { return }
        let velocity = (point.x-lastDrag.x) / max(1.0/240, event.timestamp-lastDragTime)
        drag?(velocity)
        lastDrag=point
        lastDragTime=event.timestamp
        moved = true
        move?(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y), point)
    }
    override func mouseUp(with event: NSEvent) {
        if moved { drop?(); window?.saveFrame(usingName: "DaygardenPet") } else { click?() }
    }
    override func rightMouseDown(with event: NSEvent) { click?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 { click?() } else { super.keyDown(with: event) }
    }
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { "桌宠" }
    override func accessibilityPerformPress() -> Bool { click?(); return true }
}

struct PetMenu: View {
    @ObservedObject var store: GardenStore
    var body: some View {
        VStack(spacing: 0) {
            MagicHeader(title: store.data.preferences.name, draggable: false) { store.pet?.closeMenu() }
            PixelScrollView {
            VStack(alignment: .leading, spacing: 13) {
                if store.counter == nil {
                    Button { store.setTyping(true) } label: {
                        HStack(spacing: 7) {
                            Image(systemName:"exclamationmark.circle.fill")
                            Text("操作计数未开启").font(.system(size:12,weight:.medium))
                            Spacer()
                            Image(systemName:"chevron.right").font(.system(size:10))
                        }.foregroundStyle(Color(red:1,green:0.53,blue:0.48)).padding(9)
                            .background(Color.red.opacity(0.10),in:PixelFrame())
                    }.buttonStyle(.plain).accessibilityLabel("开启操作计数")
                }
                ActionCountsView(store:store)
                if let run = store.data.timer {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(clockText(run.display(at: store.now))).font(.system(size: 24, design: .monospaced))
                            Text(run.taskTitle).font(.caption).lineLimit(1).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Button { run.resumedAt == nil ? store.resumeTimer() : store.pauseTimer() } label: { Image(systemName: run.resumedAt == nil ? "play.fill" : "pause.fill") }
                        Button { store.finishTimer() } label: { Image(systemName: "stop.fill") }.help("结束并记录")
                    }.padding(10).magicSurface(Palette.paper)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(desktopTools, id: \.0) { tool in
                        Button { store.pet?.openTool(tool.0) } label: {
                            HStack(spacing: 10) {
                                PixelIcon(name: tool.0, size: 28)
                                Text(tool.0).font(.system(size: 14))
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity).frame(height: 28)
                        }.buttonStyle(PixelButtonStyle())
                    }
                }
                HStack {
                    Text("平时姿势").font(.system(size: 12)).foregroundStyle(Palette.muted)
                    PixelTabs(selection: Binding(get: { store.idlePose }, set: { store.idlePose = $0 }), items: [(0, "站立"), (1, "坐地")])
                }
                HStack {
                    Button("设置") { store.pet?.openTool("设置") }
                    Spacer()
                    Button("管理") { store.pet?.openManager() }
                    Button("收起") { store.setPet(false) }
                }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.muted).padding(.top, 4)
            }.padding(16)
            }
        }.frame(width: 320).frame(maxHeight: .infinity).magicSurface(Palette.card, strong: true)
            .foregroundStyle(Palette.ink).magicControls()
    }
}

struct ToolPanelView: View {
    @ObservedObject var store: GardenStore
    var tool: String
    var body: some View {
        VStack(spacing: 0) {
        MagicHeader(title: tool, draggable: false, back: { store.pet?.back() }) { store.pet?.closeTool() }
        GeometryReader { viewport in
        PixelScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !store.error.isEmpty { Text(store.error).font(.caption).foregroundStyle(.red) }
                Group {
                    switch tool {
                    case "任务", "待办": TasksPage(store: store)
                    case "计时器": TimerControls(store: store, compact: true)
                    case "四象限": TasksPage(store: store)
                    case "日程": SchedulePage(store: store)
                    case "习惯": HabitsPage(store: store)
                    case "日记": DiaryPage(store: store)
                    case "农场", "厨房", "商店": FarmPage(store: store, section: tool)
                    case "统计": StatsPage(store: store)
                    case "成长": GrowthPage(store:store)
                    case "首页": HomeScene(store:store)
                    case "书房": StudyScene(store:store)
                    case "地图", "湖畔钓鱼": MapPage(store:store,journey:.fishing)
                    case "林间冒险": MapPage(store:store,journey:.adventure)
                    case "熬制魔药": MapPage(store:store,journey:.potions)
                    case "衣柜": WardrobePage(store:store)
                    default: SettingsPage(store: store)
                    }
                }.disabled(store.storageLocked && tool != "设置")
            }.padding(18).frame(maxWidth: .infinity, alignment: .topLeading)
                .environment(\.sceneViewport,CGSize(width:max(200,viewport.size.width-36),height:max(180,viewport.size.height-36)))
        }
        }
        }.magicSurface(Palette.card, strong: true).foregroundStyle(Palette.ink).magicControls()
            .overlay { WindowResizeBorder(began:{store.pet?.beginToolResize()},ended:{store.pet?.finishToolResize()}) }
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .environment(\.calendar,store.calendar)
    }
}

struct QuickTasks: View {
    @ObservedObject var store: GardenStore
    @State private var title = ""
    @State private var completed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                TextField("添加待办", text: $title).textFieldStyle(PixelTextFieldStyle()).onSubmit(add)
                Button("添加", action: add).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Toggle("显示已完成", isOn: $completed).font(.caption)
            let tasks = store.allTaskOccurrences.filter { completed || $0.completedAt == nil }.sorted { $0.task.quadrant < $1.task.quadrant }
            if tasks.isEmpty { EmptyNote(text: "暂无待办") }
            ForEach(tasks) { occurrence in TaskRow(store: store, occurrence: occurrence); Divider() }
        }
    }
    private func add() {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        store.upsert(GardenTask(title: clean)); title = ""
    }
}
