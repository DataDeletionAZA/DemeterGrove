import SwiftUI
import AppKit

final class ToastController {
    private let panel = NSPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
    private var clock: Timer?
    private var lifetime = ToastLifetime()
    private var anchor: (() -> NSRect)?
    private var cleared: (() -> Void)?
    init() {
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
        panel.title = "提示"; panel.isReleasedWhenClosed = false
    }
    deinit { clock?.invalidate() }
    func show(_ message: String, anchor: @escaping () -> NSRect, cleared: @escaping () -> Void) {
        clock?.invalidate()
        guard !message.isEmpty else { panel.orderOut(nil); return }
        self.anchor = anchor; self.cleared = cleared; lifetime = ToastLifetime()
        let width: CGFloat = 330
        let textHeight = (message as NSString).boundingRect(with:NSSize(width:width-28,height:200),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:[.font:NSFont.systemFont(ofSize:13)]).height
        panel.setContentSize(NSSize(width:width,height:min(140,max(42,ceil(textHeight)+26))))
        panel.contentView = NSHostingView(rootView:ToastContent(message:message))
        position(); panel.alphaValue = 1; panel.orderFrontRegardless()
        var previous = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval:0.04,repeats:true) { [weak self] _ in
            guard let self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            self.lifetime.hovered = self.panel.frame.contains(NSEvent.mouseLocation)
            self.lifetime.advance(now-previous); previous = now
            if self.lifetime.expired { self.dismiss(); return }
            self.panel.alphaValue = self.lifetime.opacity; self.position()
        }
        clock = timer; RunLoop.main.add(timer,forMode:.common)
    }
    func position() {
        guard let frame = anchor?() else { return }
        let screen = PetPlacement.screen(for:frame,screens:NSScreen.screens.map(\.visibleFrame))
        let x = max(screen.minX+8,min(frame.midX-panel.frame.width/2,screen.maxX-panel.frame.width-8))
        let baseY = max(screen.minY+8,min(frame.maxY+8,screen.maxY-panel.frame.height-34))
        panel.setFrameOrigin(NSPoint(x:x,y:baseY+lifetime.progress*24))
    }
    func outsideClick(window: NSWindow?, point: NSPoint) {
        if panel.isVisible, window !== panel, !panel.frame.contains(point) { dismiss() }
    }
    func dismiss() {
        clock?.invalidate(); clock = nil; panel.orderOut(nil)
        let callback = cleared; cleared = nil; callback?()
    }
}
private struct ToastContent: View {
    var message: String
    var body: some View {
        Text(message).font(.system(size:13)).foregroundStyle(Palette.goldLight).multilineTextAlignment(.center)
            .lineLimit(5).padding(12).frame(maxWidth:.infinity,maxHeight:.infinity)
            .magicSurface(Palette.card,strong:true)
            .accessibilityLabel(message)
    }
}
