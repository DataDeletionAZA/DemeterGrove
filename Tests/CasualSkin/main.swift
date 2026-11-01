import AppKit
import SwiftUI
import ImageIO

@main
enum CasualSkinChecks {
    struct CheckFailure: Error, CustomStringConvertible { let description: String }
    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !condition() { throw CheckFailure(description: message) }
    }
    static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return try encoder.encode(value)
    }
    static func gardenFingerprint(_ garden: Garden) throws -> Data {
        var object = try JSONSerialization.jsonObject(with: encoded(garden)) as! [String: Any]
        var economy = object["economy"] as! [String: Any]
        economy["owned"] = (economy["owned"] as! [String]).sorted()
        object["economy"] = economy
        return try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
    }
    static func pixels(_ image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { raw in
            let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }
    static func write(_ image: CGImage, to url: URL) throws {
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CheckFailure(description: "PNG encoding failed: \(url.lastPathComponent)")
        }
        try data.write(to: url)
    }
    @MainActor
    static func render(_ sprite: ChibiSprite) throws -> CGImage {
        let renderer = ImageRenderer(content: sprite.frame(width: 200, height: 225))
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw CheckFailure(description: "ChibiSprite render failed") }
        return image
    }
    static func checkEdges(_ image: CGImage, grounded: Bool, label: String) throws {
        let bytes = pixels(image), width = image.width, height = image.height
        var left = width, right = 0, top = height, bottom = 0
        for y in 0..<height {
            for x in 0..<width where bytes[(y * width + x) * 4 + 3] > 16 {
                left = min(left, x); right = max(right, x + 1)
                top = min(top, y); bottom = max(bottom, y + 1)
            }
        }
        try check(left < right && top < bottom, "Empty rendered frame: \(label)")
        try check(left > 0 && right < width && top > 0, "Content touches a side/top edge: \(label), \(left),\(top),\(right),\(bottom)")
        try check(grounded || bottom < height, "Content touches the floating bottom edge: \(label)")
    }
    static func contactSheet(_ frames: [(String, CGImage)], to url: URL) throws {
        let columns = 6, cellWidth = 164, cellHeight = 206
        let rows = (frames.count + columns - 1) / columns
        let width = columns * cellWidth, height = rows * cellHeight
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(NSColor(calibratedWhite: 0.92, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }
        for (index, frame) in frames.enumerated() {
            let x = index % columns * cellWidth, y = height - (index / columns + 1) * cellHeight
            context.draw(frame.1, in: CGRect(x: x + 2, y: y + 22, width: 160, height: 180))
            (frame.0 as NSString).draw(in: CGRect(x: x + 4, y: y + 4, width: 156, height: 16),
                withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.black])
        }
        try write(context.makeImage()!, to: url)
    }
    @MainActor
    static func main() throws {
        let manager = FileManager.default
        let harness = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CASUAL_SKIN_CHECK_ROOT"]!).resolvingSymlinksInPath()
        try check(Bundle.main.bundleURL.resolvingSymlinksInPath().path.hasPrefix(harness.path + "/"), "Not running in the isolated test app")
        let output = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CASUAL_SKIN_QA_DIR"]!)
        let bootstrap = GardenStore(preview: true)
        let folder = bootstrap.file.deletingLastPathComponent().resolvingSymlinksInPath()
        try check(folder == manager.temporaryDirectory.appendingPathComponent("Daygarden-Preview-\(ProcessInfo.processInfo.processIdentifier)").resolvingSymlinksInPath(), "Unexpected preview save location")
        var stores = [bootstrap]
        defer { for store in stores { store.storageLocked = true }; try? manager.removeItem(at: folder) }
        var fixture = AppData()
        fixture.preferences.sound = false
        fixture.garden.coins = 1234
        fixture.garden.economy.outfit = "base"
        fixture.garden.economy.owned = ["sweater", "trousers", "coat", "grayScarf", "blackShoes", "focusSuit"]
        fixture.garden.economy.equipped = ["top": "sweater", "bottom": "trousers", "outer": "coat", "neck": "grayScarf", "shoes": "blackShoes", "focusOutfit": "focusSuit"]
        fixture.garden.economy.adjustments = ["grayScarf": WearAdjustment(x: 7, y: -4, scale: 110)]
        let originalGarden = try gardenFingerprint(fixture.garden)
        var legacy = try JSONSerialization.jsonObject(with: encoded(fixture)) as! [String: Any]
        var preferences = legacy["preferences"] as! [String: Any]
        preferences.removeValue(forKey: "petSkin"); legacy["preferences"] = preferences
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: preferences))
        try check(decoded.petSkin == nil && decoded.selectedPetSkin == .casual, "Legacy preferences do not default to casual")
        bootstrap.storageLocked = true
        try JSONSerialization.data(withJSONObject: legacy).write(to: bootstrap.file, options: .atomic)
        var store = GardenStore(preview: true); stores.append(store)
        try check(!store.storageLocked && store.data.preferences.selectedPetSkin == .casual, "Legacy save failed to load")
        for skin in [PetSkin.original, .casual] {
            try check(store.commitGameChange { $0.preferences.petSkin = skin.rawValue; return true }, "Skin selection failed to save")
            try check(try gardenFingerprint(store.data.garden) == originalGarden, "Changing skin mutated possessions")
            store.storageLocked = true
            store = GardenStore(preview: true); stores.append(store)
            try check(!store.storageLocked && store.data.preferences.selectedPetSkin == skin, "Skin selection did not survive restart")
            try check(try gardenFingerprint(store.data.garden) == originalGarden, "Restart changed possessions")
        }
        let saved = try Data(contentsOf: store.file)
        let preserved = folder.appendingPathComponent("preserved.json")
        try manager.moveItem(at: store.file, to: preserved)
        try manager.createDirectory(at: store.file, withIntermediateDirectories: false)
        try Data([1]).write(to: store.file.appendingPathComponent("blocked"))
        try check(!store.commitGameChange { $0.preferences.petSkin = PetSkin.original.rawValue; return true }, "Blocked save unexpectedly succeeded")
        try check(store.data.preferences.selectedPetSkin == .casual && store.saveStatus == "保存失败", "Failed skin save did not roll back")
        try check(try gardenFingerprint(store.data.garden) == originalGarden && Data(contentsOf: preserved) == saved, "Failed save changed possessions or preserved data")
        RunLoop.main.run(until: Date().addingTimeInterval(0.65))
        try check(store.saveStatus == "保存失败", "Failed save scheduled an unwanted retry")
        try manager.removeItem(at: store.file); try manager.moveItem(at: preserved, to: store.file)
        store.storageLocked = true
        print("PASS: legacy preferences, skin persistence across restarts, unchanged money/clothing, failed-save rollback")

        let resourceFolder = Bundle.main.resourceURL!.appendingPathComponent("ChibiSkins/Casual")
        let names = ["Stand", "Sit", "Drag", "Focus", "Rest", "RestOpen"]
        for body in ChibiBody.allCases {
            let floating = ChibiSkins.rect(body:body,in:CGSize(width:200,height:225),grounded:false)
            let docked = ChibiSkins.rect(body:body,in:CGSize(width:200,height:225),grounded:true)
            try check(floating.size == docked.size && abs(docked.minY-floating.minY-14)<0.001,
                      "Docking changed character size instead of only the baseline")
        }
        for name in names {
            try check(manager.fileExists(atPath: resourceFolder.appendingPathComponent(name + ".png").path), "Missing resource: \(name)")
            try check(ChibiSkins.images[name] != nil, "Resource did not load: \(name)")
        }
        try check(ChibiSkins.isAvailable && Set(ChibiSkins.images.keys) == Set(names), "Incomplete casual skin")
        let configurations: [(String, Int, Int, ChibiBody)] = [("Stand", 0, 0, .stand), ("Sit", 0, 1, .sit), ("Drag", 10, 0, .drag), ("Focus", 30, 0, .focus), ("Rest", 31, 0, .rest)]
        for (name, phase, idle, body) in configurations {
            for expression in 0...3 {
                for time in [0.0, 2.75, 3.2, 4.8, 10.08, 11.2] {
                    for reaction in [false, true] {
                        let currentPhase = reaction && body != .drag ? 20 : phase
                        let pose = ChibiPose(phase: currentPhase, time: time, elapsed: 0.1, basePhase: phase, idlePose: idle,
                            expression: expression, expressionActive: true, glances: true)
                        try check(pose.body == body, "Reaction changed body: \(name)")
                        let expected = body == .rest && (3..<4.8).contains(time) ? "RestOpen" : name
                        try check(ChibiSkins.name(for: pose) == expected && ChibiSkins.frame(for: pose) === ChibiSkins.images[expected], "Casual state selected another skin: \(name)")
                    }
                }
            }
        }
        for (time, expected) in [(0.0, "Rest"), (2.999, "Rest"), (3.0, "RestOpen"), (4.799, "RestOpen"), (4.8, "Rest"), (15.2, "RestOpen")] {
            try check(ChibiSkins.name(for: ChibiPose(phase: 31, time: time, elapsed: 2)) == expected, "Incorrect rest eye window")
            try check(ChibiSkins.name(for: ChibiPose(phase: 31, time: time, elapsed: 2, reduceMotion: true)) == "Rest", "Reduced motion changes rest eyes")
        }
        let now = Date()
        store.data.timer = TimerRun(kind: .stopwatch, target: 1500, taskTitle: "阅读", startedAt: now, resumedAt: now)
        try check(store.petBasePhase == 30, "Running timer does not select focus")
        store.clickPet()
        try check(ChibiPose(phase: store.petPhase, time: 0, elapsed: 0.1, basePhase: store.petBasePhase).body == .focus, "Click interrupts focus pose")
        store.data.timer?.resumedAt = nil
        try check(store.petBasePhase == 31 && ChibiPose(phase: store.petPhase, time: 0, elapsed: 0.1, basePhase: store.petBasePhase).body == .rest, "Paused timer does not retain rest during click")
        store.dragPet(-1200)
        try check(store.petPhase == 11 && ChibiSkins.name(for: ChibiPose(phase: store.petPhase, time: 0, elapsed: 0.1, basePhase: store.petBasePhase)) == "Drag", "Dragging during pause changes skin")
        store.dropPet()
        try check(ChibiPose(phase: store.petPhase, time: 0, elapsed: 0.1, basePhase: store.petBasePhase).body == .rest, "Drop does not restore paused pose")
        store.data.timer?.kind = .rest; store.data.timer?.resumedAt = now; store.tapPhase = 0
        try check(store.petPhase == 31, "Running break does not select rest")
        print("PASS: all five poses, expression/click/blink/gaze selection, drag/drop, focus/pause/rest, eye timing and reduced motion")

        var frames: [(String, CGImage)] = []
        func capture(_ label: String, _ sprite: ChibiSprite) throws {
            let image = try render(sprite)
            try checkEdges(image, grounded: sprite.grounded, label: label)
            try write(image, to: output.appendingPathComponent(label + ".png"))
            frames.append((label, image))
        }
        for (name, phase, idle, _) in configurations {
            for right in [false, true] {
                for grounded in [false, true] {
                    try capture(name + (right ? "-right" : "-left") + (grounded ? "-docked" : ""),
                        ChibiSprite(phase: phase, time: 0, idlePose: idle, facingRight: right, grounded: grounded, skin: .casual))
                }
            }
            let plain = try render(ChibiSprite(phase: phase, time: 0, idlePose: idle, skin: .casual))
            let dressed = try render(ChibiSprite(phase: phase, time: 0, idlePose: idle, economy: fixture.garden.economy, skin: .casual))
            try check(pixels(plain) == pixels(dressed), "Legacy clothes alter casual rendering: \(name)")
            let original = try render(ChibiSprite(phase: phase, time: 0, idlePose: idle, skin: .original))
            try check(pixels(plain) != pixels(original), "Original skin does not restore another image: \(name)")
        }
        for impulse in [-1200.0, 1200.0] {
            let elapsed = stride(from: 0.0, through: 4.0, by: 0.005).max {
                abs(ChibiPose(phase: 10, time: 0, elapsed: $0, dragImpulse: impulse, dragAge: 0).swing) < abs(ChibiPose(phase: 10, time: 0, elapsed: $1, dragImpulse: impulse, dragAge: 0).swing)
            }!
            for right in [false, true] {
                try capture("Drag-\(Int(impulse))-" + (right ? "right" : "left"), ChibiSprite(phase: 10, time: 0, elapsed: elapsed,
                    dragImpulse: impulse, dragAge: 0, facingRight: right, skin: .casual))
            }
        }
        let springTimes = stride(from: 0.0, through: 1.35, by: 0.005).map { ($0, ChibiPose(phase: 20, time: 0, elapsed: $0).spring) }
        for (tag, elapsed) in [("expand", springTimes.max { $0.1 < $1.1 }!.0), ("contract", springTimes.min { $0.1 < $1.1 }!.0)] {
            for idle in [0, 1] {
                for right in [false, true] {
                    try capture((idle == 0 ? "Stand" : "Sit") + "-click-" + tag + (right ? "-R" : "-L"),
                        ChibiSprite(phase: 20, time: 0, elapsed: elapsed, idlePose: idle, facingRight: right, skin: .casual))
                }
            }
        }
        for right in [false, true] {
            for grounded in [false, true] {
                let seated = pixels(try render(ChibiSprite(phase:0,time:0,idlePose:1,facingRight:right,grounded:grounded,skin:.casual)))
                for time in [0.95,2.85] {
                    for phase in [0,20] {
                        let current = pixels(try render(ChibiSprite(phase:phase,time:time,elapsed:0.1,idlePose:1,facingRight:right,grounded:grounded,skin:.casual)))
                        try check(current == seated,"Seated furniture moves during breathing or click feedback")
                    }
                }
            }
        }
        for (phase, first, second) in [(30, 0.0, 0.95), (31, 0.0, 1.2), (31, 3.2, 4.4)] {
            let a = try render(ChibiSprite(phase: phase, time: first, skin: .casual))
            let b = try render(ChibiSprite(phase: phase, time: second, skin: .casual))
            try check(pixels(a) == pixels(b), "Breathing deforms focus/rest furniture or a stable face")
        }
        let a = pixels(try render(ChibiSprite(phase: 31, time: 0, reduceMotion: true, skin: .casual)))
        let b = pixels(try render(ChibiSprite(phase: 31, time: 3.2, reduceMotion: true, skin: .casual)))
        try check(a == b, "Reduced-motion rest is not visually stable")
        let closedSource = CGImageSourceCreateWithURL(resourceFolder.appendingPathComponent("Rest.png") as CFURL, nil)!
        let openSource = CGImageSourceCreateWithURL(resourceFolder.appendingPathComponent("RestOpen.png") as CFURL, nil)!
        let closed = CGImageSourceCreateImageAtIndex(closedSource, 0, nil)!, opened = CGImageSourceCreateImageAtIndex(openSource, 0, nil)!
        try check(closed.width == opened.width && closed.height == opened.height, "Rest eye frames differ in dimensions")
        let closedPixels = pixels(closed), openPixels = pixels(opened)
        var changed = 0
        for y in 0..<closed.height {
            for x in 0..<closed.width {
                let offset = (y * closed.width + x) * 4
                if (0..<4).contains(where: { closedPixels[offset + $0] != openPixels[offset + $0] }) {
                    changed += 1
                    try check((600...1020).contains(x) && (545...690).contains(y), "Rest eye frame changes eyebrows/furniture outside the eye region: \(x),\(y)")
                }
            }
        }
        try check(changed > 0, "Rest eye frames are identical")
        try capture("Rest-open", ChibiSprite(phase: 31, time: 3.2, skin: .casual))
        try contactSheet(frames, to: output.appendingPathComponent("contact-sheet.png"))
        print("PASS: \(frames.count) actual sprite renders, two directions, docked/floating edges, maximum swing/spring, no old clothes, static furniture/faces, eye-only frame differences")
        print("QA: \(output.appendingPathComponent("contact-sheet.png").path)")
    }
}
