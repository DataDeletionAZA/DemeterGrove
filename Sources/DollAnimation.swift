import Foundation
import CoreGraphics

enum PetMotion:Int,CaseIterable,Identifiable {
    case idle=0,typingLeft=1,typingRight=2,dragRight=10,dragLeft=11,runningRight=12,runningLeft=13
    case waving=20,landing=21,jumping=22,failed=23,working=30,resting=31,waiting=32,review=33
    var id:Int {rawValue}
    static let families:[PetMotion]=[.idle,.runningRight,.runningLeft,.waving,.jumping,.failed,.waiting,.working,.review]
    var name:String {
        switch self {
        case .idle:return "待机";case .runningRight:return "向右走";case .runningLeft:return "向左走"
        case .waving:return "挥手";case .jumping:return "跳跃";case .failed:return "失落"
        case .waiting:return "等待";case .working:return "专注";case .review:return "检查"
        case .resting:return "休息";case .dragRight,.dragLeft:return "拖动";case .landing:return "落地"
        case .typingLeft,.typingRight:return "打字"
        }
    }
    var duration:Double {
        switch self {case .waving:return 1.35;case .jumping:return 1.15;case .failed:return 1.8;case .landing:return 0.55;case .typingLeft,.typingRight:return 0.18;default:return 3.2}
    }
    var frameRate:Double {
        switch self {case .dragLeft,.dragRight,.typingLeft,.typingRight:return 24
        case .runningLeft,.runningRight,.waving,.jumping:return 18
        default:return 12}
    }
}

enum PetLook {
    static func direction(point:CGPoint,size:CGSize) -> Int? {
        let x=point.x-size.width/2,y=point.y-size.height*0.18
        guard hypot(x,y)>18 else{return nil}
        let angle=atan2(x,-y)
        return (Int((angle/(2*Double.pi)*16).rounded())+16)%16
    }
}

struct DollPose {
    let phase:Int
    let time:Double
    let elapsed:Double
    let reduceMotion:Bool
    private let mode:Int
    private let breath:Double
    private let entrance:Double
    private let lookDirection:Int?
    private let coveredLegs:Bool

    init(phase:Int,time:Double,elapsed:Double=1,basePhase:Int=0,reduceMotion:Bool=false,lookDirection:Int?=nil,coveredLegs:Bool=false) {
        self.phase=phase;self.time=time;self.elapsed=max(0,elapsed);self.reduceMotion=reduceMotion
        mode=[1,2,20,21,22].contains(phase) ? basePhase:phase
        breath=sin(time * (mode == 31 ? 1.05:1.55))
        entrance=Self.smooth(0,0.35,elapsed)
        self.lookDirection=lookDirection;self.coveredLegs=coveredLegs
    }
    var motion:PetMotion {PetMotion(rawValue:phase) ?? .idle}
    var gait:Bool {phase == 12 || phase == 13}
    var gazeDirection:Int? {
        if let lookDirection {return ((lookDirection%16)+16)%16}
        if phase == 12 {return 4}
        if phase == 13 {return 12}
        if phase == 23 {return 8}
        if mode == 33 {return 10}
        return nil
    }
    var eyelid:Int {
        guard !reduceMotion else{return 0}
        let local=time.truncatingRemainder(dividingBy:24)
        var closure=mode == 31 || phase == 23 ? 0.45:0.0
        for start in [2.7,8.1,14.8,20.5] {
            let age=local-start
            if age>=0 && age<0.21 {closure=max(closure,age<0.065 ? age/0.065:1-(age-0.065)/0.145)}
        }
        return closure>0.78 ? 2:closure>0.25 ? 1:0
    }
    var focusAmount:Double {!reduceMotion && mode == 30 ? entrance:0}
    var usesArmRig:Bool {!reduceMotion && (focusAmount>0 || gait || [1,2,20,22,23,32,33].contains(phase))}
    var usesLegRig:Bool {!reduceMotion && !coveredLegs && (gait || phase == 22)}
    private var stride:Double {sin(elapsed*2*Double.pi/0.82)}
    private var airborne:Double {
        phase == 22 && elapsed>0.18 && elapsed<0.82 ? sin((elapsed-0.18)/0.64*Double.pi):0
    }

    func armTransform(side:Double,forearm:Bool) -> CGAffineTransform {
        guard !reduceMotion else{return .identity}
        let shoulder=CGPoint(x:side<0 ? 380:644,y:375),elbow=CGPoint(x:side<0 ? 355:669,y:580)
        var upper=side*0.045*focusAmount
        var lower=side*(side<0 ? 0.38:0.62)*focusAmount
        if focusAmount>0 {lower+=sin(elapsed*3.3+side)*0.045*focusAmount}
        if mode == 33 {
            upper=(side<0 ? -0.03:0.05)*entrance
            lower=(side<0 ? -0.32:2.5+sin(elapsed*1.2)*0.035)*entrance
        }
        if mode == 32 {upper=(side<0 ? -0.035:0.12)*entrance;lower=(side<0 ? -0.35:-1.6)*entrance}
        if phase == 23 {upper=side*0.09*entrance;lower = -side*0.1*entrance}
        if gait {
            let direction=phase == 12 ? 1.0:-1.0
            upper = -side*stride*0.22*direction;lower=side*0.08
        }
        if phase == 20 && side>0 {
            let wave=Self.smooth(0,0.28,elapsed)*(1-Self.smooth(0.95,1.35,elapsed))
            upper = -0.5*wave
            lower = (-2.4+sin(elapsed*14)*0.13)*wave
        }
        if phase == 22 {upper=side*0.14*airborne;lower=side*0.16*airborne}
        if (phase == 1 && side<0) || (phase == 2 && side>0) {lower+=side*0.07*sin(min(1,elapsed/0.18)*Double.pi)}
        return partTransform(pivot:shoulder,hinge:elbow,upper:upper,lower:forearm ? lower:0)
    }

    func legTransform(side:Double,shin:Bool,start:CGFloat=750) -> CGAffineTransform {
        guard !reduceMotion else{return .identity}
        var upper=0.0,lower=0.0
        if gait {
            let direction=phase == 12 ? 1.0:-1.0
            upper=side*stride*0.21*direction
            lower=side*max(0,side*stride)*0.18*direction
        }
        if phase == 22 {upper=side*0.07*airborne;lower=side*0.10*airborne}
        if start>750 {
            return partTransform(pivot:CGPoint(x:side<0 ? 460:564,y:start),hinge:CGPoint(x:side<0 ? 460:564,y:start),upper:upper*0.65,lower:0)
        }
        return partTransform(pivot:CGPoint(x:side<0 ? 460:564,y:760),hinge:CGPoint(x:side<0 ? 458:566,y:1060),upper:upper,lower:shin ? lower:0)
    }

    private func partTransform(pivot:CGPoint,hinge:CGPoint,upper:Double,lower:Double) -> CGAffineTransform {
        let anchor=point(pivot)
        func moved(_ p:CGPoint) -> CGPoint {
            let bent=Self.rotated(p,around:hinge,angle:lower)
            let rotated=Self.rotated(bent,around:pivot,angle:upper)
            return CGPoint(x:rotated.x+anchor.x-pivot.x,y:rotated.y+anchor.y-pivot.y)
        }
        let a=CGPoint.zero,b=CGPoint(x:1,y:0),c=CGPoint(x:0,y:1)
        return DollMesh.transform(a,b,c,to:moved(a),moved(b),moved(c))
    }

    func point(_ source:CGPoint) -> CGPoint {
        guard !reduceMotion else{return source}
        let x=Double(source.x),y=Double(source.y),side=x<512 ? -1.0:1.0
        let upper=1-Self.smooth(680,1440,y)
        let chest=Self.smooth(300,410,y)*(1-Self.smooth(510,720,y))
        var dx=(x-512)*breath*0.0035*chest,dy = -breath*4*upper
        let focus=mode == 30 ? entrance:0,rest=mode == 31 ? entrance:0
        let waiting=mode == 32 ? entrance:0,review=mode == 33 ? entrance:0
        let failed=phase == 23 ? entrance:0
        let head=(1-Self.smooth(340,430,y))*(1-Self.smooth(180,280,abs(x-512)))
        let angle=Double(gazeDirection ?? 0)*Double.pi/8
        let lookX=gazeDirection == nil ? 0:sin(angle),lookY=gazeDirection == nil ? 0:-cos(angle)
        let headAngle=focus*0.045-rest*0.024+waiting*0.055-review*0.055+lookX*0.065+sin(elapsed*3)*failed*0.025
        let turned=Self.rotated(source,around:CGPoint(x:512,y:340),angle:headAngle)
        dx+=(Double(turned.x)-x+focus*3+lookX*16)*head
        dy+=(Double(turned.y)-y+focus*15+rest*5+review*10+failed*18+lookY*10)*head
        dy+=(rest*3+failed*7)*upper*(1-head)

        if !usesArmRig {
            let arm=Self.smooth(65,145,abs(x-512))*(1-Self.smooth(220,300,abs(x-512)))*Self.smooth(340,450,y)*(1-Self.smooth(900,1000,y))
            let wrist=Self.smooth(560,810,y)*arm
            var angle=sin(time*0.85+side)*0.004
            if phase == 10 || phase == 11 {angle=(phase == 10 ? 1.0:-1.0)*0.055+side*0.005+sin(time*3.4)*0.006}
            let swung=Self.rotated(source,around:CGPoint(x:side<0 ? 380:644,y:375),angle:angle)
            dx+=(Double(swung.x)-x)*arm+side*8*rest*wrist
            dy+=(Double(swung.y)-y)*arm+4*rest*wrist
        }
        let leg=Self.smooth(760,840,y)*(1-Self.smooth(160,240,abs(x-512)))
        if phase == 10 || phase == 11 {
            let angle=(phase == 10 ? 1.0:-1.0)*0.04+side*0.004+sin(time*3.4)*0.006
            let swung=Self.rotated(source,around:CGPoint(x:side<0 ? 460:564,y:760),angle:angle)
            dx+=(Double(swung.x)-x)*leg;dy+=(Double(swung.y)-y)*leg
        }
        if phase == 21 || (phase == 22 && elapsed>=0.82) {
            let start=phase == 22 ? 0.82:0.0,t=min(1,(elapsed-start)/0.55)
            let landing=sin(t*Double.pi)*exp(-t*1.5)
            let knee=Self.smooth(760,1040,y)*(1-Self.smooth(1100,1440,y))*leg
            dy+=24*landing*upper+9*landing*knee;dx+=side*8*landing*knee
        }
        if phase == 22 {
            dy-=116*airborne
            if elapsed<0.18 {dy+=18*sin(elapsed/0.18*Double.pi)*upper}
        }
        if gait {
            dy+=680*(1-cos(stride*0.21))
            if coveredLegs {
                dx+=stride*8*Self.smooth(850,1380,y)
                dy+=side*stride*4*Self.smooth(1380,1450,y)
            }
        }
        return CGPoint(x:x+dx,y:y+dy)
    }
    private static func smooth(_ low:Double,_ high:Double,_ value:Double) -> Double {
        let t=min(1,max(0,(value-low)/(high-low)));return t*t*(3-2*t)
    }
    private static func rotated(_ p:CGPoint,around pivot:CGPoint,angle:Double) -> CGPoint {
        let x=p.x-pivot.x,y=p.y-pivot.y,c=cos(angle),s=sin(angle)
        return CGPoint(x:pivot.x+x*c-y*s,y:pivot.y+x*s+y*c)
    }
}

enum DollMesh {
    struct Triangle {let a:Int;let b:Int;let c:Int}
    private static let xs:[CGFloat]=[0,300,360,410,462,512,562,614,664,724,1024]
    private static let ys:[CGFloat]=[0,340,385,580,680,790,900,1060,1380,1536]
    static let points:[CGPoint]=ys.flatMap{y in xs.map{CGPoint(x:$0,y:y)}}
    static let triangles:[Triangle]=faces(columns:xs.count,rows:ys.count)
    static let calmPoints:[CGPoint]=[CGFloat(0),340,385,680,1440,1536].flatMap {y in
        [CGFloat(0),340,512,684,1024].map{CGPoint(x:$0,y:y)}
    }
    static let calmTriangles:[Triangle]=faces(columns:5,rows:6)
    private static func faces(columns:Int,rows:Int) -> [Triangle] {
        (0..<rows-1).flatMap {row in
        (0..<columns-1).flatMap {column -> [Triangle] in
            let a=row*columns+column,b=a+1,c=a+columns,d=c+1
            return [Triangle(a:a,b:b,c:d),Triangle(a:a,b:d,c:c)]
        }
        }
    }
    static func transform(_ a:CGPoint,_ b:CGPoint,_ c:CGPoint,to p:CGPoint,_ q:CGPoint,_ r:CGPoint) -> CGAffineTransform {
        let ux=b.x-a.x,uy=b.y-a.y,vx=c.x-a.x,vy=c.y-a.y,det=ux*vy-uy*vx
        let m11=((q.x-p.x)*vy-(r.x-p.x)*uy)/det
        let m21=((r.x-p.x)*ux-(q.x-p.x)*vx)/det
        let m12=((q.y-p.y)*vy-(r.y-p.y)*uy)/det
        let m22=((r.y-p.y)*ux-(q.y-p.y)*vx)/det
        return CGAffineTransform(a:m11,b:m12,c:m21,d:m22,tx:p.x-m11*a.x-m21*a.y,ty:p.y-m12*a.x-m22*a.y)
    }
}
