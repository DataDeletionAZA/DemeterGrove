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
    var imageName: String {
        if (expressionActive || reacting) && body != .drag { return body.rawValue + "Expression" + String(!expressionActive && phase == 23 ? 2 : max(0, min(3, expression))) }
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
    static func name(for pose: ChibiPose) -> String {
        switch pose.body {
        case .stand: return "Stand"
        case .sit: return "Sit"
        case .drag: return "Drag"
        case .focus: return "Focus"
        case .rest:
            let moment = pose.time.truncatingRemainder(dividingBy: 12)
            return !pose.reduceMotion && (3..<4.8).contains(moment) ? "RestOpen" : "Rest"
        }
    }
    static let images: [String:NSImage] = {
        var result: [String:NSImage] = [:]
        for (name,body) in [("Stand",ChibiBody.stand),("Sit",.sit),("Drag",.drag),("Focus",.focus),("Rest",.rest),("RestOpen",.rest)] {
            guard let spec = artwork[body],
                  let url = Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"ChibiSkins/Casual"),
                  let source = CGImageSourceCreateWithURL(url as CFURL,nil),
                  let original = CGImageSourceCreateImageAtIndex(source,0,nil),
                  let cropped = original.cropping(to:spec.crop) else { continue }
            let width = Int(ceil(spec.size.width * 2)), height = Int(ceil(spec.size.height * 2))
            guard let context = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
                                          space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            context.interpolationQuality = .high
            context.draw(cropped,in:CGRect(x:0,y:0,width:width,height:height))
            if let image = context.makeImage() { result[name] = NSImage(cgImage:image,size:spec.size) }
        }
        return result
    }()
    static var isAvailable: Bool { images.count == 6 }
    static func frame(for pose:ChibiPose) -> NSImage? { images[name(for:pose)] }
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
                guard let source = ChibiSkins.frame(for:pose) else { return }
                let image = context.resolve(Image(nsImage:source).interpolation(.none))
                let rect = ChibiSkins.rect(body:pose.body,in:size,grounded:grounded)
                var drawing = context
                if facingRight { drawing.translateBy(x:size.width,y:0); drawing.scaleBy(x:-1,y:1) }
                if pose.body == .drag {
                    let spec = ChibiSkins.artwork[.drag]!
                    let pivot = CGPoint(x:rect.minX+(520-spec.crop.minX)/spec.crop.width*rect.width,
                                        y:rect.minY+(760-spec.crop.minY)/spec.crop.height*rect.height)
                    drawing.translateBy(x:pivot.x,y:pivot.y)
                    drawing.rotate(by:.radians(pose.swing * 0.55 * (facingRight ? -1:1)))
                    drawing.translateBy(x:-pivot.x,y:-pivot.y)
                } else if pose.body == .stand {
                    drawing.translateBy(x:rect.midX,y:rect.maxY)
                    drawing.scaleBy(x:1+pose.spring*0.035,y:1+pose.breath*0.0005-pose.spring*0.035)
                    drawing.translateBy(x:-rect.midX,y:-rect.maxY)
                }
                drawing.draw(image,in:rect)
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
