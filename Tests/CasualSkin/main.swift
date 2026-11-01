import AppKit
import SwiftUI
import ImageIO
import Darwin

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
    static func contactSheet(_ frames: [(String, CGImage)], to url: URL, columns: Int = 6) throws {
        let cellWidth = 164, cellHeight = 206
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
    static func sourceImage(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL,nil),
              let image = CGImageSourceCreateImageAtIndex(source,0,nil) else {
            throw CheckFailure(description:"Missing or unreadable image: \(url.path)")
        }
        return image
    }
    static func mapped(_ original: CGRect, body: ChibiBody, right: Bool, grounded: Bool) -> CGRect {
        let spec = ChibiSkins.artwork[body]!
        let rect = ChibiSkins.rect(body:body,in:CGSize(width:200,height:225),grounded:grounded)
        let target = CGRect(x:rect.minX+(original.minX-spec.crop.minX)/spec.crop.width*rect.width,
                            y:rect.minY+(original.minY-spec.crop.minY)/spec.crop.height*rect.height,
                            width:original.width/spec.crop.width*rect.width,height:original.height/spec.crop.height*rect.height)
        return CGRect(x:(right ? 200-target.maxX:target.minX)*2,y:target.minY*2,width:target.width*2,height:target.height*2)
    }
    static func checkFace(_ current: [UInt8], baseline: [UInt8], width: Int, rect: CGRect, label: String, requireChange: Bool = true, strictAlpha: Bool = true) throws {
        let allowed = CGRect(x:floor(rect.minX),y:floor(rect.minY),width:ceil(rect.maxX)-floor(rect.minX),height:ceil(rect.maxY)-floor(rect.minY))
        var changed = 0
        for offset in stride(from:0,to:current.count,by:4) {
            let x = (offset/4)%width, y = (offset/4)/width
            if strictAlpha && current[offset+3] != baseline[offset+3] {
                throw CheckFailure(description:"Expression changes alpha: \(label), \(x),\(y), \(baseline[offset+3])->\(current[offset+3])")
            }
            if (0..<3).contains(where:{current[offset+$0] != baseline[offset+$0]}) {
                changed += 1
                if !allowed.contains(CGPoint(x:x,y:y)) {
                    throw CheckFailure(description:"Expression changes hair/clothes/furniture outside face: \(label), \(x),\(y), \(Array(baseline[offset..<offset+4])) -> \(Array(current[offset..<offset+4]))")
                }
            }
        }
        try check(!requireChange || changed>0,"Expression has no visible change: \(label)")
    }
    static func checkFurniture(_ current:[UInt8],baseline:[UInt8],width:Int,body:ChibiBody,right:Bool,grounded:Bool,label:String) throws {
        guard body != .stand else { return }
        let points: [CGPoint] = body == .sit ? [CGPoint(x:90,y:1020),CGPoint(x:940,y:950),CGPoint(x:880,y:1300)] :
            [CGPoint(x:800,y:1150),CGPoint(x:200,y:1080),CGPoint(x:400,y:1400),CGPoint(x:1100,y:1400),CGPoint(x:550,y:150),CGPoint(x:1080,y:150)]
        for point in points {
            let rect = mapped(CGRect(origin:point,size:.zero),body:body,right:right,grounded:grounded)
            let x = Int(rect.minX.rounded()), y = Int(rect.minY.rounded())
            for dy in -1...1 { for dx in -1...1 {
                let offset = ((y+dy)*width+x+dx)*4
                try check((0..<3).allSatisfy { current[offset+$0] == baseline[offset+$0] },"Furniture RGB moves: \(label), source \(point.x),\(point.y)")
            }}
        }
        let original = body == .sit ? CGRect(x:280,y:1020,width:400,height:65) : CGRect(x:590,y:939,width:430,height:45)
        let seam = mapped(original,body:body,right:right,grounded:grounded)
        for y in Int(ceil(seam.minY))..<Int(floor(seam.maxY)) {
            for x in Int(ceil(seam.minX))..<Int(floor(seam.maxX)) {
                let offset = (y*width+x)*4
                try check(baseline[offset+3]<240 || current[offset+3]>=200,"Transparent seam under moving torso: \(label), \(x),\(y)")
            }
        }
    }
    @MainActor
    static func main() throws {
        setbuf(stdout,nil)
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
            for expression in 0...8 {
                for time in [0.0,2.75,3.2,4.8,10.08,11.2] {
                    for reaction in [false,true] {
                        for reduced in [false,true] {
                            let currentPhase = reaction && body != .drag ? 20:phase
                            let pose = ChibiPose(phase:currentPhase,time:time,elapsed:0.1,basePhase:phase,idlePose:idle,
                                expression:expression,expressionActive:true,reduceMotion:reduced,glances:true)
                            try check(pose.body == body,"Reaction changed body: \(name)")
                            let expected = body == .drag ? "Drag":name+"Expression"+String(expression)
                            try check(ChibiSkins.name(for:pose) == expected,"Incorrect expression selected: \(expected)")
                            try check(ChibiSkins.frame(for:pose) != nil,"Missing rendered expression: \(expected)")
                            try check(ChibiImages.images[pose.imageName] != nil,"Missing original-skin fallback: \(pose.imageName)")
                            if body == .rest { try check(ChibiSkins.baseName(for:pose) == "RestOpen","Rest expression does not use open-eye base") }
                        }
                    }
                }
            }
            if body != .drag {
                let talking = ChibiPose(phase:20,time:0,elapsed:0.1,basePhase:phase,idlePose:idle,expression:8)
                let ended = ChibiPose(phase:20,time:0,elapsed:10,basePhase:phase,idlePose:idle,expression:8)
                try check(ChibiSkins.name(for:talking) == name+"Expression8","Click reaction loses expression")
                try check(ChibiSkins.name(for:ended) == name && ChibiSkins.frame(for:ended) === ChibiSkins.images[name],"Finished speech does not restore base pose")
                let failed = ChibiPose(phase:23,time:0,elapsed:0.1,basePhase:phase,idlePose:idle,expression:8)
                try check(failed.expressionIndex == 2 && ChibiSkins.name(for:failed) == name+"Expression2","Failure reaction does not use closed/frowning expression")
            }
        }
        try check(ChibiPose(phase:0,time:0,elapsed:0,expression:42,expressionActive:true).expressionIndex == 42,"Raw expression index is clamped before skin selection")
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
        let poses = configurations.filter { $0.3 != .drag }
        let restPlain = try render(ChibiSprite(phase:31,time:0,skin:.casual))
        let restFace = try render(ChibiSprite(phase:31,time:0,expression:0,expressionActive:true,skin:.casual))
        try write(restPlain,to:output.appendingPathComponent("Rest-base-plain.png"))
        try write(restFace,to:output.appendingPathComponent("Rest-base-expression0.png"))
        try check(restPlain.bitsPerComponent == 8 && restFace.bitsPerComponent == 8 && restPlain.bitsPerPixel == 32 && restFace.bitsPerPixel == 32 && CFEqual(restPlain.colorSpace,restFace.colorSpace),"Expression switches the Canvas bit depth or color space")
        try checkFace(pixels(restFace),baseline:pixels(restPlain),width:restFace.width,
            rect:mapped(ChibiSkins.expressionRects[.rest]!,body:.rest,right:false,grounded:false),
            label:"Rest quick face",requireChange:false,strictAlpha:false)
        print("PASS: Rest expression preserves pixels outside face before the full render matrix")
        var expressionFrames: [(String,CGImage)] = []
        var remembered: [String:Data] = [:]
        for (name,phase,idle,body) in poses {
            var patchContents = Set<Data>()
            for expression in 0...8 {
                let patch = try sourceImage(resourceFolder.appendingPathComponent("Expressions/\(name)\(expression).png"))
                let target = ChibiSkins.expressionRects[body]!
                try check(patch.width == Int(target.width) && patch.height == Int(target.height),"Expression patch has incorrect dimensions: \(name)\(expression)")
                let expressionPose = ChibiPose(phase:phase,time:0,elapsed:10,idlePose:idle,expression:expression,expressionActive:true,reduceMotion:true)
                let baseCG = ChibiSkins.images[ChibiSkins.baseName(for:expressionPose)]!.cgImage(forProposedRect:nil,context:nil,hints:nil)!
                let frameCG = ChibiSkins.frame(for:expressionPose)!.cgImage(forProposedRect:nil,context:nil,hints:nil)!
                let baseAlpha = pixels(baseCG), frameAlpha = pixels(frameCG)
                try check(stride(from:3,to:baseAlpha.count,by:4).allSatisfy { baseAlpha[$0] == frameAlpha[$0] },"Static expression changes original alpha: \(name)\(expression)")
                let bytes = pixels(patch)
                try check(stride(from:3,to:bytes.count,by:4).contains { bytes[$0]>16 },"Empty expression patch: \(name)\(expression)")
                patchContents.insert(Data(bytes))
            }
            try check(patchContents.count == 9,"Expression patch images are duplicated: \(name)")
            for right in [false,true] {
                for grounded in [false,true] {
                    for reduced in [false,true] {
                        let plain = try render(ChibiSprite(phase:phase,time:0,reduceMotion:reduced,idlePose:idle,facingRight:right,grounded:grounded,skin:.casual))
                        let baseline = try render(ChibiSprite(phase:phase,time:0,reduceMotion:reduced,idlePose:idle,expression:0,expressionActive:true,facingRight:right,grounded:grounded,skin:.casual))
                        let basePixels = pixels(baseline)
                        if !right && !grounded && !reduced {
                            try write(plain,to:output.appendingPathComponent(name+"-base-plain.png"))
                            try write(baseline,to:output.appendingPathComponent(name+"-base-expression0.png"))
                        }
                        let face = mapped(ChibiSkins.expressionRects[body]!,body:body,right:right,grounded:grounded)
                        try checkFace(basePixels,baseline:pixels(plain),width:baseline.width,rect:face,label:name+" base face",requireChange:false,strictAlpha:false)
                        var unique = Set<Data>()
                        for expression in 0...8 {
                            let sprite = ChibiSprite(phase:phase,time:0,reduceMotion:reduced,idlePose:idle,expression:expression,
                                expressionActive:true,facingRight:right,grounded:grounded,skin:.casual)
                            let image = try render(sprite), current = pixels(image)
                            let label = "\(name)-expression\(expression)"+(right ? "-R":"-L")+(grounded ? "-docked":"")+(reduced ? "-still":"")
                            try checkEdges(image,grounded:grounded,label:label)
                            try checkFace(current,baseline:basePixels,width:image.width,rect:face,label:label,requireChange:expression != 0)
                            unique.insert(Data(current))
                            if !right && !grounded {
                                remembered[name+String(expression)+(reduced ? "-still":"-layers")] = Data(current)
                                if reduced {
                                    try write(image,to:output.appendingPathComponent(label+".png"))
                                    expressionFrames.append(("\(name) \(expression)",image))
                                }
                            }
                        }
                        try check(unique.count == 9,"Nine expressions do not produce nine distinct frames: \(name)")
                    }
                }
            }
            for expression in 0...8 {
                let original = try render(ChibiSprite(phase:phase,time:0,reduceMotion:true,idlePose:idle,expression:expression,expressionActive:true,skin:.original))
                let bytes = pixels(original)
                try check(stride(from:3,to:bytes.count,by:4).contains { bytes[$0]>16 },"Original-skin expression is empty: \(name)\(expression)")
            }
        }
        for _ in 0..<2 {
            for (name,phase,idle,_) in poses.reversed() {
                for expression in (0...8).reversed() {
                    for reduced in [false,true] {
                        let image = try render(ChibiSprite(phase:phase,time:0,reduceMotion:reduced,idlePose:idle,expression:expression,expressionActive:true,skin:.casual))
                        try check(Data(pixels(image)) == remembered[name+String(expression)+(reduced ? "-still":"-layers")],"Cache eviction loses expression or layers: \(name)\(expression)")
                    }
                }
            }
        }
        try contactSheet(expressionFrames,to:output.appendingPathComponent("expressions-36-contact.png"),columns:9)
        print("PASS: 36 distinct real expression patches, both directions/docking/motion settings, fixed alpha/appearance outside face, original-skin fallbacks and cache revisits")

        let springTimes = stride(from:0.0,through:1.35,by:0.005).map { ($0,ChibiPose(phase:20,time:0,elapsed:$0).spring) }
        let peaks = [("squash",springTimes.max { $0.1<$1.1 }!.0),("rebound",springTimes.min { $0.1<$1.1 }!.0)]
        var actionFrames: [(String,CGImage)] = []
        for (name,phase,idle,body) in poses {
            for right in [false,true] {
                for grounded in [false,true] {
                    let base = try render(ChibiSprite(phase:phase,time:0,elapsed:10,idlePose:idle,expression:3,expressionActive:true,facingRight:right,grounded:grounded,skin:.casual))
                    let basePixels = pixels(base)
                    for action in [20,21] {
                        for (tag,elapsed) in peaks {
                            let pose = ChibiPose(phase:action,time:0,elapsed:elapsed,basePhase:phase,idlePose:idle,expression:3,expressionActive:true)
                            let motion = ChibiSkins.motion(for:pose)
                            try check((0.97...1.03).contains(motion.width) && (0.96...1.03).contains(motion.height),"Motion exceeds reconstructed background bounds")
                            let sprite = ChibiSprite(phase:action,time:0,elapsed:elapsed,basePhase:phase,idlePose:idle,expression:3,expressionActive:true,facingRight:right,grounded:grounded,skin:.casual)
                            let image = try render(sprite), current = pixels(image)
                            let label = "\(name)-phase\(action)-\(tag)"+(right ? "-R":"-L")+(grounded ? "-docked":"")
                            try check(current != basePixels,"Click/drop feedback has no visible deformation: \(label)")
                            try checkFurniture(current,baseline:basePixels,width:image.width,body:body,right:right,grounded:grounded,label:label)
                            try capture(label,sprite)
                            if !right && !grounded { actionFrames.append(("\(name) \(action) \(tag)",image)) }
                        }
                        let ended = try render(ChibiSprite(phase:action,time:0,elapsed:10,basePhase:phase,idlePose:idle,expression:3,expressionActive:true,facingRight:right,grounded:grounded,skin:.casual))
                        try check(pixels(ended) == basePixels,"Animation does not restore the same expression frame: \(name), phase \(action)")
                        let reduced = try render(ChibiSprite(phase:action,time:0,elapsed:peaks[0].1,basePhase:phase,reduceMotion:true,idlePose:idle,expression:3,expressionActive:true,facingRight:right,grounded:grounded,skin:.casual))
                        let reducedBase = try render(ChibiSprite(phase:phase,time:0,reduceMotion:true,idlePose:idle,expression:3,expressionActive:true,facingRight:right,grounded:grounded,skin:.casual))
                        try check(pixels(reduced) == pixels(reducedBase),"Reduced motion deforms expression: \(name)")
                    }
                    if body != .stand {
                        for time in [0.95,2.85] {
                            let breathed = try render(ChibiSprite(phase:phase,time:time,idlePose:idle,expression:3,expressionActive:true,facingRight:right,grounded:grounded,skin:.casual))
                            try check(pixels(breathed) != basePixels,"Natural breathing has no character movement: \(name)")
                            try checkFurniture(pixels(breathed),baseline:basePixels,width:breathed.width,body:body,right:right,grounded:grounded,label:name+" breathing")
                        }
                    }
                }
            }
        }
        try contactSheet(actionFrames,to:output.appendingPathComponent("actions-4-poses-contact.png"),columns:4)
        print("PASS: click/drop squash and rebound for four poses, static furniture RGB, torso seam opacity, matching settled expressions and reduced-motion stability")

        func animationRow(_ images:[CGImage]) throws -> CGImage {
            let context = CGContext(data:nil,width:1600,height:450,bitsPerComponent:8,bytesPerRow:6400,
                space:images[0].colorSpace!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.interpolationQuality = .none;context.setBlendMode(.copy)
            for (index,image) in images.enumerated() { context.draw(image,in:CGRect(x:index*400,y:0,width:400,height:450)) }
            return context.makeImage()!
        }
        var animationBase: [CGImage] = []
        for (_,phase,idle,_) in poses {
            animationBase.append(try render(ChibiSprite(phase:0,time:0,elapsed:10,basePhase:phase,idlePose:idle,expression:4,expressionActive:true,skin:.casual)))
        }
        try write(animationRow(animationBase),to:output.appendingPathComponent("animation-settled.png"))
        var animationTimes = Array(stride(from:0.0,through:1.35,by:1.0/24))
        if animationTimes.last! < 1.35 { animationTimes.append(1.35) }
        var animationManifest: [[String:Any]] = []
        for (index,elapsed) in animationTimes.enumerated() {
            var row: [CGImage] = []
            for (_,phase,idle,_) in poses {
                row.append(try render(ChibiSprite(phase:20,time:0,elapsed:elapsed,basePhase:phase,idlePose:idle,expression:4,expressionActive:true,skin:.casual)))
            }
            let filename = String(format:"animation-%03d.png",index)
            try write(animationRow(row),to:output.appendingPathComponent(filename))
            for (column,pose) in poses.enumerated() {
                let current = pixels(row[column]), baseline = pixels(animationBase[column])
                if index == 0 { try check(current == baseline,"Animation does not start on its expression frame: \(pose.0)") }
                try checkFurniture(current,baseline:baseline,width:row[column].width,body:pose.3,right:false,grounded:false,label:"\(pose.0) animation frame \(index)")
            }
            animationManifest.append(["file":filename,"elapsed":elapsed])
        }
        let animationInfo: [String:Any] = ["fps":24,"size":[1600,450],"columns":poses.map { $0.0 },"expression":4,"phase":20,"settled":"animation-settled.png","frames":animationManifest]
        try JSONSerialization.data(withJSONObject:animationInfo,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("animation.json"))
        print("PASS: \(animationTimes.count) actual four-pose Canvas animation PNGs at 24 fps, matching phase-0 expression and static furniture throughout")
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
        print("PASS: \(frames.count) actual sprite renders, two directions, docked/floating edges, maximum swing/spring, no old clothes, fixed furniture during character motion, eye-only frame differences")
        print("QA: \(output.appendingPathComponent("contact-sheet.png").path)")
    }
}
