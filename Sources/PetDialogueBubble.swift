import AppKit
import SwiftUI

final class PetDialogueBubbleController {
    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private weak var store: GardenStore?
    private var timer: Timer?
    private var speechID: UUID?
    private let anchor: () -> NSRect?
    init(store: GardenStore, anchor: @escaping () -> NSRect?) {
        self.store = store; self.anchor = anchor
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = "桌宠说话"; panel.isReleasedWhenClosed = false
    }
    deinit { timer?.invalidate() }
    func show(_ speech: PetSpeech?) {
        timer?.invalidate(); timer = nil
        guard let speech, anchor() != nil else { panel.orderOut(nil); speechID = nil; return }
        speechID = speech.id
        let width: CGFloat = 290
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 2
        let textHeight = (speech.line.text as NSString).boundingRect(with: NSSize(width: width - 50, height: 400), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: NSFont.systemFont(ofSize: 13), .paragraphStyle: paragraph]).height
        let size = NSSize(width: width, height: min(310, max(38, ceil(textHeight) + 18)))
        let hosting = NSHostingView(rootView: PetDialogueBubbleContent(text: speech.line.text) { [weak self] in self?.dismiss(id: speech.id) })
        hosting.sizingOptions = []; hosting.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hosting; panel.setContentSize(size)
        panel.alphaValue = 1; position(); panel.orderFrontRegardless()
        let timer = Timer(timeInterval: 0.04, repeats: true) { [weak self] _ in
            guard let self, let store = self.store, store.petSpeech?.id == self.speechID else { self?.hide(); return }
            guard self.anchor() != nil else { self.dismiss(); return }
            let hovered = self.panel.frame.contains(NSEvent.mouseLocation)
            store.setPetSpeechHovered(hovered)
            guard store.petSpeech?.id == self.speechID else { return }
            let progress = store.petSpeechProgress
            self.panel.alphaValue = hovered ? 1 : max(0, 1 - max(0, progress - 0.82) / 0.18)
            self.position()
        }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    private func position() {
        guard let frame = anchor() else { return }
        let screen = PetPlacement.screen(for: frame, screens: NSScreen.screens.map(\.visibleFrame))
        let fitsLeft = frame.minX - panel.frame.width - 12 >= screen.minX + 8
        let fitsRight = frame.maxX + panel.frame.width + 12 <= screen.maxX - 8
        let above = frame.maxY + 8
        let fitsAbove = above + panel.frame.height <= screen.maxY - 8
        let centeredX = frame.midX - panel.frame.width / 2
        let x = fitsAbove ? centeredX : fitsLeft ? frame.minX - panel.frame.width - 12 : fitsRight ? frame.maxX + 12 : centeredX
        let sideY = frame.maxY - panel.frame.height
        let preferredY = fitsAbove ? above : fitsLeft || fitsRight ? sideY : frame.minY - panel.frame.height - 8
        let y = max(screen.minY + 8, min(preferredY, screen.maxY - panel.frame.height - 8))
        panel.setFrameOrigin(NSPoint(x: max(screen.minX + 8, min(x, screen.maxX - panel.frame.width - 8)), y: y))
    }
    private func hide() { timer?.invalidate(); timer = nil; panel.orderOut(nil); speechID = nil }
    func dismiss(id: UUID? = nil) { guard id == nil || speechID == id else { return }; let current = speechID; hide(); if let current { store?.dismissPetSpeech(id: current) } }
}

private struct PetDialogueBubbleContent: View {
    var text: String
    var close: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(text).font(.system(size: 13)).lineSpacing(2).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            Button(action: close) { Image(systemName: "xmark").font(.system(size: 9)).frame(width: 18, height: 18) }.buttonStyle(.plain).accessibilityLabel("关闭桌宠台词")
        }.padding(.horizontal,12).padding(.vertical,9).frame(maxWidth: .infinity, maxHeight: .infinity, alignment:.topLeading).foregroundStyle(Palette.goldLight).magicSurface(Palette.card, strong: true).accessibilityElement(children: .contain)
    }
}
