import SwiftUI

enum CraftRollMotion {
    static let duration: TimeInterval = 2.6
    static func progress(_ elapsed: TimeInterval) -> Double { min(1, max(0, elapsed / duration)) }
    static func turns(_ elapsed: TimeInterval) -> Double {
        let p = progress(elapsed)
        return 1 - pow(1-p, 3)
    }
}

struct CraftRollPresentation: View {
    let roll: CraftRoll
    let title: String
    var subtitle: String = ""
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sceneViewport) private var viewport
    @State private var began = Date()
    @State private var finished = false
    private var tint: Color { roll.criticalFailure ? Color(red:0.85,green:0.42,blue:0.38) : roll.quality < 25 ? Palette.muted : Palette.goldLight }
    var body: some View {
        let compact=viewport.height>0 && viewport.height<520
        SceneDialog(preferred: CGSize(width: 490, height: 450)) {
            HStack { Text(title).font(.title3); Spacer(); Button("关闭", action: onComplete) }
        } content: {
            VStack(spacing: compact ? 6:10) {
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                TimelineView(.animation(minimumInterval: 1/30, paused: finished || reduceMotion)) { timeline in
                    let elapsed = reduceMotion || finished ? CraftRollMotion.duration : max(0,timeline.date.timeIntervalSince(began))
                    CraftDie(roll: roll, elapsed: elapsed).frame(height:compact ? 100:160)
                }.accessibilityLabel(finished ? "骰子点数 \(roll.natural)" : "骰子滚动中")
                HStack(spacing: 12) {
                    Text(finished ? "\(roll.natural)" : "—").monospacedDigit()
                    Text(roll.modifier >= 0 ? "+ \(roll.modifier)" : "− \(-roll.modifier)")
                    Text("=")
                    Text(finished ? "\(roll.total)" : "—").monospacedDigit()
                }.font(.system(size: 20, weight: .medium)).foregroundStyle(Palette.goldLight)
                Text(finished ? roll.tierTitle : "鉴定中").font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(finished ? tint : Palette.muted).frame(height: 34)
                Text(finished ? (roll.criticalFailure ? "材料已损毁" : "品质 \(roll.quality)") : "合格线 8")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
            }.frame(maxWidth: .infinity).padding(.vertical, 4)
        } footer: {
            HStack { Spacer(); Button(finished ? "完成" : "查看结果") { if finished { onComplete() } else { finished = true } }
                    .buttonStyle(PixelButtonStyle(primary: true)) }
        }
        .task {
            began = Date()
            if reduceMotion { finished = true; return }
            try? await Task.sleep(for: .seconds(CraftRollMotion.duration))
            guard !Task.isCancelled else { return }
            finished = true
        }
    }
}

struct CraftDie: View {
    var roll: CraftRoll
    var elapsed: TimeInterval
    private struct Vertex {
        var x: Double; var y: Double; var z: Double
        func rotated(_ a: Double, _ b: Double, _ c: Double) -> Vertex {
            let y1 = y*cos(a)-z*sin(a), z1 = y*sin(a)+z*cos(a)
            let x2 = x*cos(b)+z1*sin(b), z2 = -x*sin(b)+z1*cos(b)
            return Vertex(x:x2*cos(c)-y1*sin(c),y:x2*sin(c)+y1*cos(c),z:z2)
        }
    }
    private static let faces = [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],
        [1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],[3,9,4],[3,4,2],
        [3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
    var body: some View {
        let theme = ThemeAppearance.shared.theme
        Canvas { context, size in
            let p = CraftRollMotion.progress(elapsed), turn = CraftRollMotion.turns(elapsed)
            let t = (1+sqrt(5.0))/2
            let source = [Vertex(x:-1,y:t,z:0),Vertex(x:1,y:t,z:0),Vertex(x:-1,y:-t,z:0),Vertex(x:1,y:-t,z:0),
                Vertex(x:0,y:-1,z:t),Vertex(x:0,y:1,z:t),Vertex(x:0,y:-1,z:-t),Vertex(x:0,y:1,z:-t),
                Vertex(x:t,y:0,z:-1),Vertex(x:t,y:0,z:1),Vertex(x:-t,y:0,z:-1),Vertex(x:-t,y:0,z:1)]
            let vertices = source.map { $0.rotated(0.35 + (1-turn)*Double.pi*5, 0.18+(1-turn)*Double.pi*7, -0.15+(1-turn)*Double.pi*3) }
            let radius = min(size.height*0.39, size.width*0.29)
            let bounce = p < 1 ? -abs(sin(p*Double.pi*4))*20*(1-p) : 0
            let center = CGPoint(x:size.width/2+(p<1 ? sin(p*15)*18*(1-p):0),y:size.height/2+bounce)
            context.fill(Path(ellipseIn:CGRect(x:size.width/2-radius*0.7,y:size.height*0.88,width:radius*1.4,height:9)),with:.color(.black.opacity(0.25)))
            func projected(_ v: Vertex) -> CGPoint {
                let scale = radius / (2.0 - v.z*0.12)
                return CGPoint(x:center.x+v.x*scale,y:center.y+v.y*scale)
            }
            let ordered = Self.faces.enumerated().sorted { a,b in
                a.element.reduce(0) { $0+vertices[$1].z } < b.element.reduce(0) { $0+vertices[$1].z }
            }
            let foremost = ordered.last?.offset
            for (index, face) in ordered {
                let points = face.map { projected(vertices[$0]) }
                var shape = Path(); shape.move(to:points[0]); shape.addLine(to:points[1]); shape.addLine(to:points[2]); shape.closeSubpath()
                let z = face.reduce(0) { $0+vertices[$1].z }/3
                let light = max(0.12,min(0.8,0.38+z*0.15))
                let original = roll.criticalFailure && p>=1 ? Color(red:0.32+light*0.22,green:0.13+light*0.14,blue:0.16+light*0.12) :
                    Color(red:0.19+light*0.25,green:0.16+light*0.22,blue:0.27+light*0.32)
                let base = theme == .original ? original :
                    (roll.criticalFailure && p>=1 ? Palette.clay : Palette.control).opacity(0.55+light*0.5)
                context.fill(shape,with:.color(base))
                context.stroke(shape,with:.color(Palette.goldLight.opacity(0.75)),lineWidth:1.2)
                if z > 0.35 {
                    let point = CGPoint(x:points.map(\.x).reduce(0,+)/3,y:points.map(\.y).reduce(0,+)/3)
                    let number = p>=1 && index == foremost ? roll.natural : ((index+roll.natural+7)%20)+1
                    context.draw(Text("\(number)").font(.system(size:index == foremost ? 24:13,weight:.semibold)).foregroundColor(Palette.goldLight),at:point)
                }
            }
            if p >= 1, roll.criticalSuccess {
                for i in 0..<12 {
                    let a = Double(i)*Double.pi/6
                    let x = center.x+cos(a)*radius*1.22, y = center.y+sin(a)*radius*1.10
                    context.fill(Path(CGRect(x:x,y:y,width:3,height:3)),with:.color(Palette.goldLight))
                }
            }
        }.accessibilityHidden(true)
    }
}
