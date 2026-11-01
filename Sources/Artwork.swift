import SwiftUI
import AppKit

enum Palette {
    static let paper = Color(red: 0.10, green: 0.085, blue: 0.14)
    static let card = Color(red: 0.17, green: 0.14, blue: 0.21)
    static let control = Color(red: 0.23, green: 0.19, blue: 0.28)
    static let gold = Color(red: 0.69, green: 0.57, blue: 0.36)
    static let goldLight = Color(red: 0.91, green: 0.82, blue: 0.62)
    static let lavender = Color(red: 0.58, green: 0.49, blue: 0.65)
    static let sage = Color(red: 0.65, green: 0.72, blue: 0.54)
    static let moss = Color(red: 0.31, green: 0.24, blue: 0.36)
    static let ink = Color(red: 0.91, green: 0.87, blue: 0.77)
    static let muted = Color(red: 0.66, green: 0.61, blue: 0.58)
    static let clay = Color(red: 0.74, green: 0.49, blue: 0.43)
    static let line = Color(red: 0.37, green: 0.30, blue: 0.37)
}

enum SpriteImages {
    static let frames: [NSImage] = {
        guard let url = Bundle.main.url(forResource: "PotionsProfessor", withExtension: "webp"),
              let source = NSImage(contentsOf: url),
              let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cg.width == 1536, cg.height == 2288 else { return [] }
        return (0..<88).compactMap { index in
            guard let frame = cg.cropping(to: CGRect(x: (index % 8) * 192, y: (index / 8) * 208, width: 192, height: 208)) else { return nil }
            return NSImage(cgImage: frame, size: NSSize(width: 192, height: 208))
        }
    }()
}

enum DollImages {
    static let layers:[String:NSImage] = {
        var result:[String:NSImage]=[:]
        for name in Set(["Base","HairFront"]+Cosmetic.all.compactMap(\.asset)) {
            if let url=Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"Doll"),
               let image=NSImage(contentsOf:url) {result[name]=image}
        }
        return result
    }()
    static let bounds:[String:CGRect] = layers.reduce(into:[:]) { result,entry in
        if let image=entry.value.cgImage(forProposedRect:nil,context:nil,hints:nil),let box=alphaBounds(image) {result[entry.key]=box}
    }
    static let thumbnails:[String:NSImage] = layers.reduce(into:[:]) { result,entry in
        guard let image=entry.value.cgImage(forProposedRect:nil,context:nil,hints:nil),
              let box=bounds[entry.key],let cropped=image.cropping(to:box) else{return}
        let scale=min(1,256/max(box.width,box.height))
        let width=max(1,Int(box.width*scale)),height=max(1,Int(box.height*scale))
        guard let context=bitmap(width:width,height:height) else{return}
        context.interpolationQuality = .none
        context.draw(cropped,in:CGRect(x:0,y:0,width:width,height:height))
        if let image=context.makeImage() {result[entry.key]=NSImage(cgImage:image,size:NSSize(width:width,height:height))}
    }
    private static let cache:NSCache<NSString,NSImage> = {
        let value=NSCache<NSString,NSImage>()
        value.countLimit=5;value.totalCostLimit=32*1024*1024
        return value
    }()
    private static let order:[ClothingSlot]=[.socks,.shoes,.bottom,.top,.outfit,.outer,.neck,.wrist,.face,.head]

    static func frame(economy:Economy,eyelid:Int,lookDirection:Int?=nil) -> NSImage? {
        let items=order.compactMap { slot in Cosmetic.all.first{$0.id == economy.worn(slot)} }
        let key=([String(eyelid),String(lookDirection ?? -1)]+items.map { item in
            let a=economy.adjustment(for:item.id)
            return "\(item.id):\(a.x):\(a.y):\(a.scale)"
        }).joined(separator:"|") as NSString
        if let image=cache.object(forKey:key) {return image}
        guard let base=layers["Base"]?.cgImage(forProposedRect:nil,context:nil,hints:nil),
              let context=bitmap(width:1024,height:1536) else{return nil}
        context.interpolationQuality = .none
        context.draw(base,in:CGRect(x:0,y:0,width:1024,height:1536))
        if eyelid>0 || lookDirection != nil {
            for eye in [CGRect(x:459,y:199,width:39,height:13),CGRect(x:525,y:199,width:39,height:13)] {
                guard let skin=base.cropping(to:CGRect(x:eye.minX,y:215,width:eye.width,height:3)),
                      let opened=base.cropping(to:eye),
                      let lash=base.cropping(to:CGRect(x:eye.minX,y:200,width:eye.width,height:2)) else{continue}
                context.saveGState()
                context.setBlendMode(.copy)
                context.draw(skin,in:CGRect(x:eye.minX,y:1536-eye.maxY,width:eye.width,height:eye.height))
                let angle=Double(lookDirection ?? 0)*Double.pi/8
                let offsetX:CGFloat=lookDirection == nil ? 0:sin(angle)*2
                let offsetY:CGFloat=lookDirection == nil ? 0:cos(angle)
                let height:CGFloat=eyelid == 0 ? eye.height:eyelid == 1 ? 6:2
                context.clip(to:CGRect(x:eye.minX,y:1536-eye.maxY,width:eye.width,height:eye.height))
                context.draw(eyelid == 2 ? lash:opened,in:CGRect(x:eye.minX+offsetX,y:1536-eye.midY-height/2+offsetY,width:eye.width,height:height))
                context.restoreGState()
            }
        }
        for item in items {
            if item.slot == .head,let hair=layers["HairFront"]?.cgImage(forProposedRect:nil,context:nil,hints:nil) {
                context.draw(hair,in:CGRect(x:0,y:0,width:1024,height:1536))
            }
            guard let name=item.asset,let source=layers[name]?.cgImage(forProposedRect:nil,context:nil,hints:nil) else{continue}
            let adjustment=economy.adjustment(for:item.id),box=bounds[name] ?? CGRect(x:0,y:0,width:1024,height:1536)
            context.saveGState()
            context.translateBy(x:CGFloat(adjustment.x)+box.midX,y:CGFloat(-adjustment.y)+1536-box.midY)
            let scale=CGFloat(adjustment.scale)/100
            context.scaleBy(x:scale,y:scale)
            context.translateBy(x:-box.midX,y:-(1536-box.midY))
            context.draw(source,in:CGRect(x:0,y:0,width:1024,height:1536))
            context.restoreGState()
        }
        if !items.contains(where:{$0.slot == .head}),let hair=layers["HairFront"]?.cgImage(forProposedRect:nil,context:nil,hints:nil) {
            context.draw(hair,in:CGRect(x:0,y:0,width:1024,height:1536))
        }
        guard let image=context.makeImage() else{return nil}
        let result=NSImage(cgImage:image,size:NSSize(width:1024,height:1536))
        cache.setObject(result,forKey:key,cost:1024*1536*4)
        return result
    }

    static func alphaBounds(_ image:CGImage) -> CGRect? {
        let width=image.width,height=image.height
        var pixels=[UInt8](repeating:0,count:width*height*4)
        return pixels.withUnsafeMutableBytes { raw in
            let bytes=raw.bindMemory(to:UInt8.self)
            guard let context=CGContext(data:raw.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
                                        space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil}
            context.draw(image,in:CGRect(x:0,y:0,width:width,height:height))
            var left=width,top=height,right=0,bottom=0
            for y in 0..<height {
                for x in 0..<width where bytes[(y*width+x)*4+3]>8 {
                    left=min(left,x);right=max(right,x+1);top=min(top,y);bottom=max(bottom,y+1)
                }
            }
            return left<right && top<bottom ? CGRect(x:left,y:top,width:right-left,height:bottom-top):nil
        }
    }
    private static func bitmap(width:Int,height:Int) -> CGContext? {
        CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
                  space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)
    }
}

private enum DollArms {
    static func mask(side:Double) -> Path {
        let points:[CGPoint]=[.init(x:200,y:350),.init(x:400,y:350),.init(x:412,y:445),.init(x:394,y:540),
                              .init(x:392,y:580),.init(x:390,y:600),.init(x:384,y:650),.init(x:380,y:670),
                              .init(x:374,y:700),.init(x:365,y:730),.init(x:361,y:750),.init(x:358,y:770),
                              .init(x:355,y:790),.init(x:360,y:810),.init(x:360,y:850),.init(x:355,y:870),
                              .init(x:350,y:890),.init(x:348,y:910),.init(x:200,y:910)]
        return Path { path in
            for (index,p) in points.enumerated() {
                let point=CGPoint(x:side<0 ? p.x:1024-p.x,y:p.y)
                if index == 0 {path.move(to:point)} else {path.addLine(to:point)}
            }
            path.closeSubpath()
        }
    }
    static let both:Path = {
        var path=mask(side:-1);path.addPath(mask(side:1));return path
    }()
    static var moving:Path {
        both.intersection(Path(CGRect(x:0,y:380,width:1024,height:540)))
    }
}

private enum DollLegs {
    static func mask(side:Double,start:CGFloat) -> Path {
        Path(CGRect(x:side<0 ? 320:512,y:start,width:192,height:1536-start))
    }
    static func both(start:CGFloat) -> Path {Path(CGRect(x:320,y:start,width:384,height:1536-start))}
}

struct DollSprite: View {
    var economy=Economy()
    var phase=0
    var time:Double
    var elapsed:Double=1
    var basePhase=0
    var reduceMotion=false
    var lookDirection:Int?=nil
    var body:some View {
        let coveredLegs = !economy.worn(.outfit).isEmpty
        let outer=economy.worn(.outer)
        let legStart:CGFloat=outer == "coat" ? 1065:outer == "jacket" ? 840:750
        let pose=DollPose(phase:phase,time:time,elapsed:elapsed,basePhase:basePhase,reduceMotion:reduceMotion,lookDirection:lookDirection,coveredLegs:coveredLegs)
        Canvas { context,size in
            guard let frame=DollImages.frame(economy:economy,eyelid:pose.eyelid,lookDirection:pose.gazeDirection) else{return}
            let image=context.resolve(Image(nsImage:frame).interpolation(.none))
            let scale=min(size.width/1024,size.height/1680)
            let origin=CGPoint(x:(size.width-1024*scale)/2,y:(size.height-1680*scale)/2+144*scale)
            let detailed=[1,2,10,11,12,13,20,21,22,23,32,33].contains(phase)
            let points=detailed ? DollMesh.points:DollMesh.calmPoints
            let triangles=detailed ? DollMesh.triangles:DollMesh.calmTriangles
            func viewport(_ point:CGPoint) -> CGPoint {
                CGPoint(x:origin.x+point.x*scale,y:origin.y+point.y*scale)
            }
            let moved=points.map { point -> CGPoint in
                let p=pose.point(point)
                return viewport(p)
            }
            for triangle in triangles {
                let a=triangle.a,b=triangle.b,c=triangle.c
                var path=Path()
                path.move(to:moved[a]);path.addLine(to:moved[b]);path.addLine(to:moved[c]);path.closeSubpath()
                var clipped=context
                clipped.clip(to:path,style:FillStyle(antialiased:false))
                clipped.concatenate(DollMesh.transform(points[a],points[b],points[c],to:moved[a],moved[b],moved[c]))
                if pose.usesArmRig {clipped.clip(to:DollArms.moving,style:FillStyle(antialiased:false),options:.inverse)}
                if pose.usesLegRig {clipped.clip(to:DollLegs.both(start:legStart),style:FillStyle(antialiased:false),options:.inverse)}
                clipped.draw(image,in:CGRect(x:0,y:0,width:1024,height:1536))
            }
            if pose.usesLegRig {
                for side in [-1.0,1.0] {
                    for shin in legStart>750 ? [false]:[false,true] {
                        let rig=pose.legTransform(side:side,shin:shin,start:legStart)
                        let a=CGPoint.zero,b=CGPoint(x:1,y:0),c=CGPoint(x:0,y:1)
                        var limb=context
                        limb.concatenate(DollMesh.transform(a,b,c,to:viewport(a.applying(rig)),viewport(b.applying(rig)),viewport(c.applying(rig))))
                        limb.clip(to:DollLegs.mask(side:side,start:legStart),style:FillStyle(antialiased:false))
                        limb.clip(to:DollArms.both,style:FillStyle(antialiased:false),options:.inverse)
                        if legStart == 750 {
                            limb.clip(to:Path(CGRect(x:0,y:shin ? 1050:740,width:1024,height:shin ? 486:330)),style:FillStyle(antialiased:false))
                        }
                        limb.draw(image,in:CGRect(x:0,y:0,width:1024,height:1536))
                    }
                }
            }
            if pose.usesArmRig {
                for side in [-1.0,1.0] {
                    for forearm in [false,true] {
                        let rig=pose.armTransform(side:side,forearm:forearm)
                        let a=CGPoint.zero,b=CGPoint(x:1,y:0),c=CGPoint(x:0,y:1)
                        var limb=context
                        limb.concatenate(DollMesh.transform(a,b,c,to:viewport(a.applying(rig)),viewport(b.applying(rig)),viewport(c.applying(rig))))
                        limb.clip(to:DollArms.mask(side:side),style:FillStyle(antialiased:false))
                        limb.clip(to:Path(CGRect(x:0,y:forearm ? 570:330,width:1024,height:forearm ? 360:260)),style:FillStyle(antialiased:false))
                        limb.draw(image,in:CGRect(x:0,y:0,width:1024,height:1536))
                    }
                }
            }
        }.accessibilityHidden(true)
    }
}

struct ProfessorSprite: View {
    var phase=0
    var size:CGFloat=220
    var economy=Economy()
    var lookDirection:Int?=nil
    var motionStart:Date?=nil
    var idlePose=0
    var expression=0
    var expressionActive=false
    var dragImpulse=0.0
    var dragUpdated:Date?=nil
    var basePhase=0
    var facingRight=false
    var glances=false
    var grounded=false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var began=Date()
    var body:some View {
        TimelineView(.animation(minimumInterval:1/(PetMotion(rawValue:phase)?.frameRate ?? 12),paused:reduceMotion)) { timeline in
            if ChibiImages.images["Stand"] != nil {
                ChibiSprite(phase:phase,time:timeline.date.timeIntervalSince1970,
                            elapsed:timeline.date.timeIntervalSince(motionStart ?? began),basePhase:basePhase,
                            reduceMotion:reduceMotion,idlePose:idlePose,expression:expression,expressionActive:expressionActive,dragImpulse:dragImpulse,economy:economy,
                            dragAge:dragUpdated.map {timeline.date.timeIntervalSince($0)},facingRight:facingRight,glances:glances,grounded:grounded)
                    .animation(reduceMotion ? nil:.easeOut(duration:0.14),value:dragImpulse)
            } else {Text("人物图片未载入").font(.caption).foregroundStyle(Palette.muted)}
        }.frame(width:size,height:grounded ? size*1.125:size*208/192).accessibilityHidden(true)
            .onAppear {began=Date()}
            .onChange(of:phase) { old,value in
                if !([10,11].contains(old) && [10,11].contains(value)) {began=Date()}
            }
    }
}
