import AppKit

struct ChibiWardrobeLayer {
    var name:String
    var behindBody:Bool
}

enum ChibiWardrobe {
    static let dimensions:[String:CGSize] = ["Stand":CGSize(width:280,height:431),"Sit":CGSize(width:280,height:357),"DragRight":CGSize(width:257,height:421),"Focus":CGSize(width:279,height:397),"Rest":CGSize(width:285,height:374)]
    private static let dailySlots:[ClothingSlot] = [.bottom,.shoes,.top,.outer,.neck]
    private static let images:[String:NSImage] = {
        guard let folder=Bundle.main.resourceURL?.appendingPathComponent("ChibiWardrobe"),
              let files=try? FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil) else{return [:]}
        return files.filter{$0.pathExtension.lowercased() == "png"}.reduce(into:[:]) {result,url in
            if let image=NSImage(contentsOf:url) {result[url.deletingPathExtension().lastPathComponent]=image}
        }
    }()
    private static let bounds:[String:CGRect] = images.reduce(into:[:]) {result,entry in
        if let image=entry.value.cgImage(forProposedRect:nil,context:nil,hints:nil),let box=DollImages.alphaBounds(image) {result[entry.key]=box}
    }
    private static let cache:NSCache<NSString,NSImage> = {
        let cache=NSCache<NSString,NSImage>();cache.countLimit=48;cache.totalCostLimit=16*1024*1024;return cache
    }()
    static let availableItems:[Cosmetic] = Cosmetic.all.filter {item in
        guard item.asset != nil else{return false}
        return bodies(for:item).allSatisfy {body in
            guard validImage(body+"_Foreground",body:body) else{return false}
            return layers(for:item,body:body).allSatisfy{validImage($0.name,body:body)}
        } && !bodies(for:item).isEmpty
    }
    static func bodies(for item:Cosmetic)->[String] {
        if item.slot == .focusOutfit {return ["Focus","Rest"]}
        return dailySlots.contains(item.slot) ? ["Stand","Sit","DragRight"]:[]
    }
    static func layers(for item:Cosmetic,body:String)->[ChibiWardrobeLayer] {
        guard let asset=item.asset,bodies(for:item).contains(body) else{return []}
        let prefix=body+"_"+asset
        if item.slot == .outer || item.slot == .neck {
            return [.init(name:prefix+"_Back",behindBody:true),.init(name:prefix+"_Front",behindBody:false)]
        }
        return [.init(name:prefix,behindBody:false)]
    }
    private static func validImage(_ name:String,body:String)->Bool {
        guard let image=images[name]?.cgImage(forProposedRect:nil,context:nil,hints:nil),let size=dimensions[body] else{return false}
        return image.width == Int(size.width) && image.height == Int(size.height)
    }
    static func frame(source:NSImage,imageName:String,body:String,economy:Economy)->NSImage {
        let slots=(body == "Focus" || body == "Rest") ? [.focusOutfit]:dailySlots
        let items=slots.compactMap {slot in availableItems.first{$0.id == economy.worn(slot)}}
        guard !items.isEmpty,let expected=dimensions[body],let cgSource=source.cgImage(forProposedRect:nil,context:nil,hints:nil),
              cgSource.width == Int(expected.width),cgSource.height == Int(expected.height) else{return source}
        let key=([imageName]+items.map {item in
            let a=economy.adjustment(for:item.id);return "\(item.id):\(a.x):\(a.y):\(a.scale)"
        }).joined(separator:"|") as NSString
        if let image=cache.object(forKey:key) {return image}
        guard let context=bitmap(width:cgSource.width,height:cgSource.height) else{return source}
        let rect=CGRect(x:0,y:0,width:cgSource.width,height:cgSource.height)
        context.interpolationQuality = .none
        for item in items {for layer in layers(for:item,body:body) where layer.behindBody {draw(layer,item:item,body:body,economy:economy,in:context,rect:rect)}}
        context.draw(cgSource,in:rect)
        for item in items {for layer in layers(for:item,body:body) where !layer.behindBody {draw(layer,item:item,body:body,economy:economy,in:context,rect:rect)}}
        let maskName=validImage(imageName+"_Foreground",body:body) ? imageName+"_Foreground":body+"_Foreground"
        if let mask=images[maskName]?.cgImage(forProposedRect:nil,context:nil,hints:nil),let foreground=bitmap(width:cgSource.width,height:cgSource.height) {
            foreground.draw(cgSource,in:rect)
            foreground.setBlendMode(.destinationIn)
            foreground.draw(mask,in:rect)
            if let image=foreground.makeImage() {context.draw(image,in:rect)}
        }
        guard let image=context.makeImage() else{return source}
        let result=NSImage(cgImage:image,size:source.size)
        cache.setObject(result,forKey:key,cost:cgSource.width*cgSource.height*4)
        return result
    }
    private static func draw(_ layer:ChibiWardrobeLayer,item:Cosmetic,body:String,economy:Economy,in context:CGContext,rect:CGRect) {
        guard let image=images[layer.name]?.cgImage(forProposedRect:nil,context:nil,hints:nil) else{return}
        let a=economy.adjustment(for:item.id)
        context.saveGState()
        let box=layers(for:item,body:body).compactMap{bounds[$0.name]}.reduce(CGRect.null){$0.union($1)}
        if item.slot.isAccessory,!box.isNull {
            context.translateBy(x:CGFloat(a.x)*rect.width/1024+box.midX,y:CGFloat(-a.y)*rect.height/1536+rect.height-box.midY)
            context.scaleBy(x:CGFloat(a.scale)/100,y:CGFloat(a.scale)/100)
            context.translateBy(x:-box.midX,y:-(rect.height-box.midY))
        }
        context.draw(image,in:rect)
        context.restoreGState()
    }
    static func thumbnail(asset:String)->NSImage? {
        guard let item=availableItems.first(where:{$0.asset == asset}),let body=bodies(for:item).first,let size=dimensions[body],
              let context=bitmap(width:Int(size.width),height:Int(size.height)) else{return nil}
        let key=("thumbnail:"+asset) as NSString
        if let image=cache.object(forKey:key) {return image}
        for layer in layers(for:item,body:body) {
            if let image=images[layer.name]?.cgImage(forProposedRect:nil,context:nil,hints:nil) {context.draw(image,in:CGRect(origin:.zero,size:size))}
        }
        guard let image=context.makeImage(),let box=DollImages.alphaBounds(image),let cropped=image.cropping(to:box) else{return nil}
        let result=NSImage(cgImage:cropped,size:box.size)
        cache.setObject(result,forKey:key,cost:cropped.width*cropped.height*4)
        return result
    }
    private static func bitmap(width:Int,height:Int)->CGContext? {
        CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
                  space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)
    }
}
