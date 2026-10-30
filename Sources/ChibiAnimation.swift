import SwiftUI
import AppKit

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
        if reacting && body != .drag { return body.rawValue + "Expression" + String(phase == 23 ? 2 : max(0, min(3, expression))) }
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

struct ChibiSprite: View, Animatable {
    var phase = 0
    var time: Double
    var elapsed: Double = 1
    var basePhase = 0
    var reduceMotion = false
    var idlePose = 0
    var expression = 0
    var dragImpulse = 0.0
    var dragAge: Double? = nil
    var facingRight = false
    var glances = false
    var grounded = false
    var animatableData: Double {
        get { dragImpulse }
        set { dragImpulse = newValue }
    }

    var body: some View {
        let pose = ChibiPose(phase: phase, time: time, elapsed: elapsed, basePhase: basePhase,
                             idlePose: idlePose, expression: expression, dragImpulse: dragImpulse, reduceMotion: reduceMotion, dragAge: dragAge,glances:glances)
        Canvas { context, size in
            guard let source = ChibiImages.images[pose.imageName] else { return }
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
