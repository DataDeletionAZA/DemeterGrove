import SwiftUI

enum NatureImages {
    private static var cache:[String:NSImage]=[:]
    static func image(_ key:String)->NSImage? {
        if let image=cache[key] {return image}
        guard let url=Bundle.main.url(forResource:key,withExtension:"png",subdirectory:"Game/Nature"),let image=NSImage(contentsOf:url) else{return nil}
        cache[key]=image;return image
    }
}

struct GameNatureSprite:View {
    var key:String
    var size:CGFloat
    var body:some View {
        Group {
            if let image=NatureImages.image(key) {
                Image(nsImage:image).resizable().interpolation(.none).scaledToFit()
            }
        }.frame(width:size,height:size).accessibilityHidden(true)
    }
}

struct SceneImageHotspot:View {
    var background:String
    var rect:CGRect
    var size:CGSize
    var label:String
    var action:()->Void
    var body:some View {
        let target=CGRect(x:rect.minX*size.width,y:rect.minY*size.height,width:rect.width*size.width,height:rect.height*size.height)
        ObjectButton(label:label,action:action,embeddedInBackdrop:true,caption:label) {
            RoomBackdrop(name:background).frame(width:size.width,height:size.height)
                .offset(x:size.width/2-target.midX,y:size.height/2-target.midY)
                .frame(width:target.width,height:target.height).clipped()
        }.position(x:target.midX,y:target.midY)
    }
}
