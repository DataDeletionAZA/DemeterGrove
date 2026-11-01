import SwiftUI
import AppKit
import ImageIO

enum ChibiBody: String, CaseIterable {
    case stand = "Stand", sit = "Sit", focus = "Focus", rest = "Rest", drag = "DragRight"
    var neck: Double {
        switch self { case .stand: return 232; case .sit: return 215; case .focus: return 222; case .rest: return 200; case .drag: return 170 }
    }
    var waist: Double { self == .stand ? 340 : 315 }
}

struct ChibiPose {
    var phase: Int
    var time: Double
    var elapsed: Double
    var basePhase = 0
    var idlePose = 0
    var expression = 0
    var expressionActive = false
    var dragImpulse = 0.0
    var reduceMotion = false
    var dragAge: Double? = nil
    var glances = false

    var body: ChibiBody {
        if phase == 10 || phase == 11 { return .drag }
        let base = phase == 30 || phase == 31 ? phase : basePhase
        if base == 30 { return .focus }
        if base == 31 { return .rest }
        return idlePose == 1 ? .sit : .stand
    }
    var reacting: Bool { (phase == 20 && elapsed < 1.35) || (phase == 23 && elapsed < 1.8) }
    private var glanceMoment: Double? {
        guard glances, !reduceMotion, !reacting, body != .rest, body != .drag else { return nil }
        return time.truncatingRemainder(dividingBy: body == .focus ? 97 : 47)
    }
    var blinking: Bool {
        guard !reduceMotion else { return false }
        if let local = glanceMoment {
            if (10..<10.18).contains(local) || (12.18..<12.36).contains(local) { return true }
            if glance > 0 { return false }
        }
        let local = time.truncatingRemainder(dividingBy: 17)
        return [2.7, 7.4, 7.75, 13.1].contains { local >= $0 && local < $0 + 0.15 }
    }
    var expressionIndex: Int { !expressionActive && phase == 23 ? 2 : expression }
    var hasExpression: Bool { (expressionActive || reacting) && body != .drag }
    var imageName: String {
        if hasExpression {
            let legacy = [0, 1, 2, 3, 0, 2, 2, 0, 1][max(0, min(8, expressionIndex))]
            return body.rawValue + "Expression" + String(legacy)
        }
        if blinking && (body == .stand || body == .sit || body == .focus) { return body.rawValue + "Blink" }
        if glance > 0 { return body.rawValue + "Gaze" }
        return body.rawValue
    }
    var breath: Double { reduceMotion || body == .drag ? 0 : sin(time * 2 * .pi / (body == .rest ? 4.8 : 3.8)) * 3.2 }
    var glance: Double {
        guard let local = glanceMoment, (10.18..<12.18).contains(local) else { return 0 }
        return 1
    }
    var spring: Double {
        guard !reduceMotion, phase == 20 || phase == 21 || phase == 22 else { return 0 }
        let t = max(0, elapsed)
        return sin(t * 19) * exp(-t * 6.5) * (phase == 21 ? 0.75 : 1)
    }
    var swing: Double {
        guard !reduceMotion, body == .drag else { return 0 }
        let t = max(0, elapsed), velocity = max(-1, min(1, dragImpulse / 900))
        let age = max(0, dragAge ?? t)
        let entrance = min(1, t / 0.12)
        return entrance * (0.13 * sin(t * 5.5) * exp(-t * 0.55) + velocity * 0.20 * cos(age * 5.5) * exp(-age * 1.2))
    }
}

enum ChibiImages {
    static let images: [String: NSImage] = {
        var names = ChibiBody.allCases.map(\.rawValue)
        names += ["StandBlink", "SitBlink", "FocusBlink", "StandGaze", "SitGaze", "FocusGaze"]
        names += ["Stand", "Sit", "Focus", "Rest"].flatMap { body in (0..<4).map { body + "Expression" + String($0) } }
        return names.reduce(into: [:]) { result, name in
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Chibi"),
               let image = NSImage(contentsOf: url) { result[name] = image }
        }
    }()
}

enum ChibiSkins {
    struct Artwork {
        let crop: CGRect
        let headWidth: CGFloat
        let headCenter: CGFloat
        var scale: CGFloat { 277 / headWidth }
        var size: CGSize { CGSize(width: crop.width * scale, height: crop.height * scale) }
        var center: CGFloat { (headCenter - crop.minX) * scale }
    }
    static let artwork: [ChibiBody: Artwork] = [
        .stand: Artwork(crop: CGRect(x:7,y:4,width:986,height:1547),headWidth:986,headCenter:500),
        .sit: Artwork(crop: CGRect(x:28,y:55,width:983,height:1465),headWidth:952,headCenter:535),
        .drag: Artwork(crop: CGRect(x:51,y:1,width:914,height:1529),headWidth:914,headCenter:508),
        .focus: Artwork(crop: CGRect(x:132,y:16,width:1223,height:1564),headWidth:820,headCenter:817),
        .rest: Artwork(crop: CGRect(x:132,y:12,width:1223,height:1568),headWidth:813,headCenter:815.5)
    ]
    struct Layers {
        let background: NSImage
        let person: NSImage
        let foreground: NSImage
    }
    struct ExpressionPatch {
        let image: NSImage
        let rect: CGRect
    }
    static let expressionRects: [ChibiBody: CGRect] = [
        .stand: CGRect(x:195,y:420,width:490,height:345),
        .sit: CGRect(x:240,y:450,width:480,height:310),
        .focus: CGRect(x:600,y:490,width:440,height:270),
        .rest: CGRect(x:610,y:480,width:430,height:270)
    ]
    private static let layerCache: NSCache<NSString,NSImage> = {
        let cache = NSCache<NSString,NSImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        cache.countLimit = 12
        return cache
    }()
    private static let patchCache: NSCache<NSString,NSImage> = {
        let cache = NSCache<NSString,NSImage>()
        cache.totalCostLimit = 6 * 1024 * 1024
        cache.countLimit = 12
        return cache
    }()
    private static let expressionCache: NSCache<NSString,NSImage> = {
        let cache = NSCache<NSString,NSImage>()
        cache.totalCostLimit = 16 * 1024 * 1024
        cache.countLimit = 8
        return cache
    }()
    static func baseName(for pose: ChibiPose) -> String {
        if pose.body == .drag { return "Drag" }
        if pose.body != .rest { return pose.body.rawValue }
        if pose.hasExpression { return "RestOpen" }
        let moment = pose.time.truncatingRemainder(dividingBy: 12)
        return !pose.reduceMotion && (3..<4.8).contains(moment) ? "RestOpen" : "Rest"
    }
    static func name(for pose: ChibiPose) -> String {
        pose.hasExpression ? pose.body.rawValue + "Expression" + String(max(0,min(8,pose.expressionIndex))) : baseName(for:pose)
    }
    private static func source(name:String,subdirectory:String = "ChibiSkins/Casual") -> CGImage? {
        guard let url = Bundle.main.url(forResource:name,withExtension:"png",subdirectory:subdirectory),
              let source = CGImageSourceCreateWithURL(url as CFURL,nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source,0,nil)
    }
    private static func bitmap(width:Int,height:Int) -> CGContext? {
        CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
                  space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)
    }
    private static func bitmapImage(_ pixels:CGImage,size:CGSize) -> NSImage {
        let representation = NSBitmapImageRep(cgImage:pixels)
        representation.size = size
        let image = NSImage(size:size)
        image.addRepresentation(representation)
        return image
    }
    private static func displayImage(original:CGImage,spec:Artwork) -> NSImage? {
        guard let cropped = original.cropping(to:spec.crop),
              let context = bitmap(width:Int(ceil(spec.size.width*2)),height:Int(ceil(spec.size.height*2))) else { return nil }
        context.interpolationQuality = .high
        context.draw(cropped,in:CGRect(x:0,y:0,width:context.width,height:context.height))
        guard let image = context.makeImage() else { return nil }
        return bitmapImage(image,size:spec.size)
    }
    static let images: [String:NSImage] = {
        var result: [String:NSImage] = [:]
        for (name,body) in [("Stand",ChibiBody.stand),("Sit",.sit),("Drag",.drag),("Focus",.focus),("Rest",.rest),("RestOpen",.rest)] {
            guard let spec = artwork[body], let original = source(name:name),
                  let image = displayImage(original:original,spec:spec) else { continue }
            result[name] = image
        }
        return result
    }()
    static var isAvailable: Bool { images.count == 6 }
    static func expressionPatch(for pose:ChibiPose) -> ExpressionPatch? {
        guard pose.hasExpression, let rect = expressionRects[pose.body] else { return nil }
        let key = pose.body.rawValue + String(max(0,min(8,pose.expressionIndex)))
        if let image = patchCache.object(forKey:key as NSString) { return ExpressionPatch(image:image,rect:rect) }
        guard let original = source(name:key,subdirectory:"ChibiSkins/Casual/Expressions") else { return nil }
        let image = bitmapImage(original,size:rect.size)
        patchCache.setObject(image,forKey:key as NSString,cost:original.bytesPerRow*original.height)
        return ExpressionPatch(image:image,rect:rect)
    }
    static func patchRect(_ patch:ExpressionPatch,body:ChibiBody,in rect:CGRect) -> CGRect {
        guard let spec = artwork[body] else { return .zero }
        return CGRect(x:rect.minX+(patch.rect.minX-spec.crop.minX)/spec.crop.width*rect.width,
                      y:rect.minY+(patch.rect.minY-spec.crop.minY)/spec.crop.height*rect.height,
                      width:patch.rect.width/spec.crop.width*rect.width,height:patch.rect.height/spec.crop.height*rect.height)
    }
    static func frame(for pose:ChibiPose) -> NSImage? {
        guard let base = images[baseName(for:pose)] else { return nil }
        return applyingExpression(to:base,pose:pose,key:name(for:pose))
    }
    static func personFrame(for pose:ChibiPose,layers:Layers) -> NSImage {
        applyingExpression(to:layers.person,pose:pose,key:"Person/"+name(for:pose))
    }
    private static func applyingExpression(to base:NSImage,pose:ChibiPose,key:String) -> NSImage {
        guard pose.hasExpression, pose.expressionIndex != 0 else { return base }
        if let cached = expressionCache.object(forKey:key as NSString) { return cached }
        guard let patch = expressionPatch(for:pose),
              let baseCG = (base.representations.first as? NSBitmapImageRep)?.cgImage,
              let patchCG = (patch.image.representations.first as? NSBitmapImageRep)?.cgImage,
              let pixels = baseCG.dataProvider?.data,
              let bytes = CFDataGetBytePtr(pixels),
              CFDataGetLength(pixels) >= baseCG.bytesPerRow * baseCG.height,
              let context = CGContext(data:nil,width:baseCG.width,height:baseCG.height,
                                      bitsPerComponent:baseCG.bitsPerComponent,bytesPerRow:baseCG.bytesPerRow,
                                      space:baseCG.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo:baseCG.bitmapInfo.rawValue),
              let destination = context.data else { return base }
        // Preserve the existing premultiplied pixels outside the expression patch.
        destination.copyMemory(from:bytes,byteCount:baseCG.bytesPerRow * baseCG.height)
        let bounds = CGRect(x:0,y:0,width:baseCG.width,height:baseCG.height)
        let target = patchRect(patch,body:pose.body,in:bounds)
        context.interpolationQuality = .none
        context.setBlendMode(.sourceAtop)
        context.draw(patchCG,in:CGRect(x:target.minX,y:bounds.height-target.maxY,width:target.width,height:target.height))
        guard let composite = context.makeImage() else { return base }
        let image = bitmapImage(composite,size:base.size)
        expressionCache.setObject(image,forKey:key as NSString,cost:composite.bytesPerRow*composite.height)
        return image
    }
    static func layers(for pose:ChibiPose) -> Layers? {
        guard pose.body != .stand, pose.body != .drag, let spec = artwork[pose.body] else { return nil }
        let name = baseName(for:pose)
        var images: [NSImage] = []
        for role in ["background","person","foreground"] {
            let key = name + "-" + role
            if let cached = layerCache.object(forKey:key as NSString) { images.append(cached); continue }
            guard let original = source(name:key,subdirectory:"ChibiSkins/Casual/Layers"),
                  let image = displayImage(original:original,spec:spec) else { return nil }
            layerCache.setObject(image,forKey:key as NSString,cost:Int(ceil(spec.size.width*2))*Int(ceil(spec.size.height*2))*4)
            images.append(image)
        }
        return Layers(background:images[0],person:images[1],foreground:images[2])
    }
    static func motion(for pose:ChibiPose) -> CGSize {
        guard !pose.reduceMotion, pose.body != .drag else { return CGSize(width:1,height:1) }
        let spring = pose.spring * (pose.phase == 21 ? 1 / 0.75 : 1)
        return CGSize(width:max(0.97,min(1.03,1+spring*0.05)),
                      height:max(0.96,min(1.03,1-spring*0.06+pose.breath*0.00045)))
    }
    static func pivot(body:ChibiBody,in rect:CGRect) -> CGPoint {
        guard let spec = artwork[body] else { return CGPoint(x:rect.midX,y:rect.maxY) }
        let original = body == .sit ? CGPoint(x:493,y:1054) : CGPoint(x:807,y:1004)
        return CGPoint(x:rect.minX+(original.x-spec.crop.minX)/spec.crop.width*rect.width,
                       y:rect.minY+(original.y-spec.crop.minY)/spec.crop.height*rect.height)
    }
    static func rect(body:ChibiBody,in size:CGSize,grounded:Bool,facingRight:Bool = false) -> CGRect {
        guard let spec = artwork[body] else { return .zero }
        let bottom:CGFloat = grounded ? 0:14
        let scale = min(size.width / 480, max(0,size.height - 18) / 535)
        let x = size.width / 2 - spec.center * scale
        let width = spec.size.width * scale, height = spec.size.height * scale
        return CGRect(x:facingRight ? size.width-x-width:x,y:size.height-bottom-height,width:width,height:height)
    }
}

struct ChibiSprite: View, Animatable {
    var phase = 0
    var time: Double
    var elapsed: Double = 1
    var basePhase = 0
    var reduceMotion = false
    var idlePose = 0
    var expression = 0
    var expressionActive = false
    var dragImpulse = 0.0
    var economy = Economy()
    var dragAge: Double? = nil
    var facingRight = false
    var glances = false
    var grounded = false
    var skin:PetSkin = .casual
    var animatableData: Double {
        get { dragImpulse }
        set { dragImpulse = newValue }
    }

    var body: some View {
        let pose = ChibiPose(phase: phase, time: time, elapsed: elapsed, basePhase: basePhase,
                             idlePose: idlePose, expression: expression, expressionActive: expressionActive, dragImpulse: dragImpulse, reduceMotion: reduceMotion, dragAge: dragAge,glances:glances)
        Canvas { context, size in
            if skin == .casual {
                let rect = ChibiSkins.rect(body:pose.body,in:size,grounded:grounded)
                var drawing = context
                if facingRight { drawing.translateBy(x:size.width,y:0); drawing.scaleBy(x:-1,y:1) }
                if pose.body == .drag {
                    guard let source = ChibiSkins.frame(for:pose) else { return }
                    let spec = ChibiSkins.artwork[.drag]!
                    let pivot = CGPoint(x:rect.minX+(520-spec.crop.minX)/spec.crop.width*rect.width,
                                        y:rect.minY+(760-spec.crop.minY)/spec.crop.height*rect.height)
                    drawing.translateBy(x:pivot.x,y:pivot.y)
                    drawing.rotate(by:.radians(pose.swing * 0.55 * (facingRight ? -1:1)))
                    drawing.translateBy(x:-pivot.x,y:-pivot.y)
                    drawing.draw(drawing.resolve(Image(nsImage:source).interpolation(.none)),in:rect)
                    return
                }
                let motion = ChibiSkins.motion(for:pose)
                if pose.body != .stand, !pose.reduceMotion, let layers = ChibiSkins.layers(for:pose) {
                    drawing.draw(drawing.resolve(Image(nsImage:layers.background).interpolation(.none)),in:rect)
                    var person = drawing
                    let pivot = ChibiSkins.pivot(body:pose.body,in:rect)
                    person.translateBy(x:pivot.x,y:pivot.y)
                    person.scaleBy(x:motion.width,y:motion.height)
                    person.translateBy(x:-pivot.x,y:-pivot.y)
                    let figure = ChibiSkins.personFrame(for:pose,layers:layers)
                    person.draw(person.resolve(Image(nsImage:figure).interpolation(.none)),in:rect)
                    drawing.draw(drawing.resolve(Image(nsImage:layers.foreground).interpolation(.none)),in:rect)
                } else {
                    guard let source = ChibiSkins.frame(for:pose) else { return }
                    if pose.body == .stand {
                        drawing.translateBy(x:rect.midX,y:rect.maxY)
                        drawing.scaleBy(x:motion.width,y:motion.height)
                        drawing.translateBy(x:-rect.midX,y:-rect.maxY)
                    }
                    drawing.draw(drawing.resolve(Image(nsImage:source).interpolation(.none)),in:rect)
                }
                return
            }
            guard let rawSource = ChibiImages.images[pose.imageName] else { return }
            let source = ChibiWardrobe.frame(source: rawSource, imageName: pose.imageName, body: pose.body.rawValue, economy: economy)
            let image = context.resolve(Image(nsImage: source).interpolation(.none))
            let w = source.size.width, h = source.size.height
            let scale = min(size.width / 480, size.height / 535)
            let baseline = size.height - (grounded ? 0 : 14)
            var drawing = context
            if facingRight {
                drawing.translateBy(x:size.width,y:0)
                drawing.scaleBy(x:-1,y:1)
            }
            if pose.body == .drag {
                // The nape is the suspension point; the feet remain free below it.
                drawing.translateBy(x: size.width * 0.40, y: size.height * 0.39)
                drawing.rotate(by: .radians(pose.swing * (facingRight ? -1 : 1)))
                drawing.scaleBy(x: scale, y: scale)
                drawing.translateBy(x: -65, y: -170)
                drawing.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
                return
            }
            drawing.translateBy(x: size.width / 2, y: baseline)
            drawing.scaleBy(x: scale * (1 + pose.spring * 0.13), y: scale * (1 - pose.spring * 0.14))
            drawing.translateBy(x: -w / 2, y: -h)
            let cuts: [Double] = [0, pose.body.neck, min(pose.body.waist, h - 10), h]
            let moved = [-pose.breath, cuts[1] - pose.breath, cuts[2], h]
            for index in 0..<cuts.count - 1 {
                let y = cuts[index], height = cuts[index + 1] - y
                let destinationY = moved[index], destinationHeight = moved[index + 1] - destinationY
                var band = drawing
                band.clip(to: Path(CGRect(x: 0, y: destinationY, width: w, height: destinationHeight)), style: FillStyle(antialiased: false))
                band.translateBy(x: 0, y: destinationY)
                band.scaleBy(x: 1, y: destinationHeight / height)
                band.translateBy(x: 0, y: -y)
                band.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
        }.accessibilityHidden(true)
    }
}
