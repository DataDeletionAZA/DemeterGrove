import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct MoodChoice: Identifiable {
    var name: String
    var symbol: String
    var id: String { name }
    static let all = [
        MoodChoice(name: "平静", symbol: "calm"), MoodChoice(name: "开心", symbol: "happy"),
        MoodChoice(name: "雀跃", symbol: "joy"), MoodChoice(name: "满足", symbol: "content"),
        MoodChoice(name: "期待", symbol: "expect"), MoodChoice(name: "感激", symbol: "grateful"),
        MoodChoice(name: "安心", symbol: "safe"), MoodChoice(name: "专注", symbol: "focus"),
        MoodChoice(name: "疲惫", symbol: "tired"), MoodChoice(name: "困倦", symbol: "sleepy"),
        MoodChoice(name: "低落", symbol: "sad"), MoodChoice(name: "难过", symbol: "cry"),
        MoodChoice(name: "焦虑", symbol: "anxious"), MoodChoice(name: "紧张", symbol: "nervous"),
        MoodChoice(name: "烦躁", symbol: "irritated"), MoodChoice(name: "生气", symbol: "angry"),
        MoodChoice(name: "孤单", symbol: "lonely"), MoodChoice(name: "想念", symbol: "miss"),
        MoodChoice(name: "惊讶", symbol: "surprised"), MoodChoice(name: "好奇", symbol: "curious"),
        MoodChoice(name: "害羞", symbol: "shy"), MoodChoice(name: "勇敢", symbol: "brave"),
        MoodChoice(name: "放空", symbol: "blank"), MoodChoice(name: "说不清", symbol: "unsure")
    ]
    static func symbol(for name: String) -> String { all.first { $0.name == name }?.symbol ?? "unsure" }
}

struct MoodArtwork: View {
    var symbol: String
    var image: Data? = nil
    var size: CGFloat = 30
    var body: some View {
        Group {
            if let image, let picture = NSImage(data: image) {
                Image(nsImage: picture).resizable().interpolation(.none).scaledToFit()
            } else {
                Canvas { context, bounds in
                    context.withCGContext { c in
                        c.setShouldAntialias(false)
                        c.scaleBy(x: bounds.width / 24, y: bounds.height / 24)
                        let ink = NSColor(red: 0.17, green: 0.13, blue: 0.20, alpha: 1)
                        let light = NSColor(red: 0.93, green: 0.81, blue: 0.56, alpha: 1)
                        let sad = ["sad", "cry", "lonely", "miss", "tired", "sleepy"].contains(symbol)
                        let angry = ["angry", "irritated", "anxious", "nervous"].contains(symbol)
                        let fill = sad ? NSColor(red:0.49,green:0.57,blue:0.65,alpha:1) : angry ? NSColor(red:0.73,green:0.43,blue:0.36,alpha:1) : NSColor(red:0.72,green:0.62,blue:0.38,alpha:1)
                        func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: NSColor) {
                            c.setFillColor(color.cgColor); c.fill(CGRect(x:x,y:y,width:w,height:h))
                        }
                        rect(6,2,12,20,ink);rect(3,5,18,14,ink);rect(5,4,14,16,fill);rect(4,7,16,10,fill)
                        rect(7,4,9,1,light);rect(5,6,1,7,light.withAlphaComponent(0.45))
                        if ["calm","content","safe","sleepy","tired","blank"].contains(symbol) {
                            rect(7,10,3,1,ink);rect(14,10,3,1,ink)
                        } else if ["happy","joy","grateful","shy"].contains(symbol) {
                            rect(7,9,3,1,ink);rect(7,10,1,1,ink);rect(9,10,1,1,ink)
                            rect(14,9,3,1,ink);rect(14,10,1,1,ink);rect(16,10,1,1,ink)
                        } else { rect(8,9,2,3,ink);rect(14,9,2,3,ink) }
                        if angry { rect(7,7,2,1,ink);rect(9,8,2,1,ink);rect(15,7,2,1,ink);rect(13,8,2,1,ink) }
                        if ["surprised","curious","expect"].contains(symbol) {
                            rect(10,14,4,4,ink);rect(11,15,2,2,light)
                        } else if sad || angry {
                            rect(10,15,4,1,ink);rect(9,16,1,1,ink);rect(14,16,1,1,ink)
                        } else if symbol == "unsure" { rect(9,15,3,1,ink);rect(12,16,3,1,ink) }
                        else if symbol == "blank" || symbol == "focus" { rect(10,15,4,1,ink) }
                        else { rect(9,14,1,2,ink);rect(14,14,1,2,ink);rect(10,16,4,1,ink) }
                        if ["cry","anxious","nervous"].contains(symbol) { rect(17,12,2,4,NSColor(red:0.65,green:0.82,blue:0.86,alpha:1)) }
                        if ["shy","grateful","miss"].contains(symbol) { rect(6,13,3,2,.systemPink);rect(16,13,3,2,.systemPink) }
                        if ["joy","brave","expect"].contains(symbol) { rect(20,2,1,5,light);rect(18,4,5,1,light) }
                        if symbol == "sleepy" { rect(19,2,4,1,light);rect(21,3,1,1,light);rect(19,4,4,1,light) }
                        switch symbol {
                        case "content": rect(10,18,4,1,light)
                        case "safe": rect(1,17,4,3,.systemGreen);rect(3,15,2,6,.systemGreen);rect(4,16,1,3,light)
                        case "focus": rect(6,8,5,5,ink);rect(13,8,5,5,ink);rect(7,9,3,3,fill);rect(14,9,3,3,fill);rect(11,9,2,1,ink)
                        case "grateful": rect(19,1,2,2,.systemPink);rect(22,1,2,2,.systemPink);rect(20,3,3,2,.systemPink);rect(21,5,1,1,.systemPink)
                        case "tired": rect(7,12,3,1,ink.withAlphaComponent(0.5));rect(14,12,3,1,ink.withAlphaComponent(0.5))
                        case "lonely": rect(1,1,4,4,light);rect(3,1,3,3,ink)
                        case "miss": rect(1,1,2,2,.systemPink);rect(4,1,2,2,.systemPink);rect(2,3,3,2,.systemPink)
                        case "irritated": rect(1,2,2,4,light);rect(0,1,2,2,light)
                        case "angry": rect(19,1,1,2,ink);rect(22,1,1,2,ink);rect(19,5,1,2,ink);rect(22,5,1,2,ink);rect(20,3,2,2,ink)
                        case "nervous": rect(5,14,1,3,ink);rect(7,15,1,2,ink)
                        case "brave": rect(0,3,1,5,light);rect(0,5,3,1,light)
                        default: break
                        }
                    }
                }
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct DiaryMoodPicker: View {
    @Binding var diary: Diary
    var saved: [Diary]
    @State private var showing = false
    @State private var customizing = false
    private var custom: [Diary] {
        var seen = Set<String>()
        return saved.filter { entry in
            let preset = MoodChoice.all.first { $0.name == entry.mood }
            let customized = entry.moodImage != nil || preset == nil || (entry.moodSymbol != nil && entry.moodSymbol != preset?.symbol)
            return customized && seen.insert(entry.mood).inserted
        }
    }
    var body: some View {
        Button { showing.toggle() } label: {
            HStack(spacing: 8) {
                MoodArtwork(symbol: diary.moodSymbol ?? MoodChoice.symbol(for: diary.mood), image: diary.moodImage)
                Text(diary.mood).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 9))
            }
        }.buttonStyle(PixelButtonStyle()).accessibilityLabel("心情：" + diary.mood)
            .popover(isPresented: $showing, arrowEdge: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("心情").font(.headline).foregroundStyle(Palette.goldLight)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                            ForEach(MoodChoice.all) { mood in
                                Button { diary.mood = mood.name; diary.moodSymbol = mood.symbol; diary.moodImage = nil; showing = false } label: {
                                    VStack(spacing: 5) { MoodArtwork(symbol: mood.symbol); Text(mood.name).font(.system(size: 11)) }.frame(width: 48, height: 55)
                                        .background(diary.mood == mood.name && diary.moodImage == nil ? Palette.moss : .clear, in: PixelFrame(step: 1))
                                }.buttonStyle(.plain)
                            }
                        }
                        if !custom.isEmpty {
                            Divider()
                            ForEach(Array(custom.enumerated()), id: \.offset) { _, mood in
                                Button { diary.mood = mood.mood; diary.moodSymbol = mood.moodSymbol; diary.moodImage = mood.moodImage; showing = false } label: {
                                    HStack { MoodArtwork(symbol: mood.moodSymbol ?? "unsure", image: mood.moodImage, size: 25); Text(mood.mood); Spacer() }
                                }.buttonStyle(PixelButtonStyle())
                            }
                        }
                        Button("自定义心情", systemImage: "plus") { showing = false; customizing = true }.buttonStyle(PixelButtonStyle(primary: true))
                    }.padding(18)
                }.frame(width: 390, height: custom.isEmpty ? 365 : 440).magicSurface(Palette.paper, strong: true).magicControls()
            }
            .sheet(isPresented: $customizing) {
                CustomMoodEditor(name: MoodChoice.all.contains(where: { $0.name == diary.mood }) ? "" : diary.mood,
                                 symbol: diary.moodSymbol ?? "calm", image: diary.moodImage) { name, symbol, image in
                    diary.mood = name; diary.moodSymbol = symbol; diary.moodImage = image
                }
            }
    }
}

struct CustomMoodEditor: View {
    @State var name: String
    @State var symbol: String
    @State var image: Data?
    var save: (String, String, Data?) -> Void
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("自定义心情").font(.title3).fontWeight(.semibold)
            HStack(spacing: 14) { MoodArtwork(symbol: symbol, image: image, size: 48); TextField("心情名称", text: $name).textFieldStyle(PixelTextFieldStyle()) }
            if name.count > 40 { Text("心情名称最多 40 个字。").font(.caption).foregroundStyle(.red) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 6) {
                ForEach(MoodChoice.all) { mood in
                    Button { symbol = mood.symbol; image = nil } label: {
                        MoodArtwork(symbol: mood.symbol, size: 28).padding(5)
                            .background(symbol == mood.symbol && image == nil ? Palette.moss : .clear, in: PixelFrame(step: 1))
                    }.buttonStyle(.plain).help(mood.name).accessibilityLabel(mood.name)
                }
            }
            Button("导入图片", systemImage: "photo") { importImage() }.buttonStyle(PixelButtonStyle())
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") { save(name.trimmingCharacters(in: .whitespacesAndNewlines), symbol, image); dismiss() }
                    .buttonStyle(PixelButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 40)
            }
        }.padding(25).frame(width: 410).magicSurface(Palette.paper, strong: true).magicControls()
    }
    private func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic, .webP]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 20 * 1024 * 1024,
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 256, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary),
                  let data = NSBitmapImageRep(cgImage: thumbnail).representation(using: .png, properties: [:]), data.count <= 262_144 else {
                error = "这张图片无法读取，请选择一张较小的图片。"; return
            }
            image = data; error = ""
        } catch { self.error = "图片读取失败：\(error.localizedDescription)" }
    }
}
