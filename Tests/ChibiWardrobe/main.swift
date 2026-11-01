import AppKit

@main
struct ChibiWardrobeChecks {
    static func image(size:CGSize,color:NSColor,rect:CGRect?=nil)->NSImage {
        let context=CGContext(data:nil,width:Int(size.width),height:Int(size.height),bitsPerComponent:8,bytesPerRow:Int(size.width)*4,
                              space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(color.cgColor);context.fill(rect ?? CGRect(origin:.zero,size:size))
        return NSImage(cgImage:context.makeImage()!,size:size)
    }
    static func write(_ name:String,size:CGSize,color:NSColor,rect:CGRect?=nil,to folder:URL) throws {
        let cgImage=image(size:size,color:color,rect:rect).cgImage(forProposedRect:nil,context:nil,hints:nil)!
        let data=NSBitmapImageRep(cgImage:cgImage).representation(using:.png,properties:[:])!
        try data.write(to:folder.appendingPathComponent(name+".png"))
    }
    static func color(_ image:NSImage,_ x:Int,_ y:Int)->NSColor {
        let cgImage=image.cgImage(forProposedRect:nil,context:nil,hints:nil)!
        return NSBitmapImageRep(cgImage:cgImage).colorAt(x:x,y:cgImage.height-y-1)!.usingColorSpace(.deviceRGB)!
    }
    static func expect(_ image:NSImage,_ x:Int,_ y:Int,_ wanted:NSColor) {
        let actual=color(image,x,y),expected=wanted.usingColorSpace(.deviceRGB)!
        assert(abs(actual.redComponent-expected.redComponent)<0.03 && abs(actual.greenComponent-expected.greenComponent)<0.03 && abs(actual.blueComponent-expected.blueComponent)<0.03,
               "Unexpected layer at \(x),\(y): \(actual), expected \(expected)")
    }
    static func main() throws {
        let root=URL(fileURLWithPath:ProcessInfo.processInfo.environment["WARDROBE_CHECK_ROOT"]!).resolvingSymlinksInPath()
        let folder=Bundle.main.resourceURL!.appendingPathComponent("ChibiWardrobe")
        assert(folder.resolvingSymlinksInPath().path.hasPrefix(root.path+"/"))
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let bodyNames=["Stand","Sit","DragRight"]
        for body in bodyNames {
            let size=ChibiWardrobe.dimensions[body]!
            try write(body+"_Foreground",size:size,color:.white,rect:CGRect(x:45,y:45,width:3,height:3),to:folder)
            try write(body+"_TopSweater",size:size,color:.red,rect:CGRect(x:30,y:30,width:60,height:60),to:folder)
            try write(body+"_BottomTrousers",size:size,color:.green,rect:CGRect(x:30,y:30,width:80,height:80),to:folder)
            try write(body+"_ShoesBlack",size:size,color:.yellow,rect:CGRect(x:120,y:120,width:20,height:20),to:folder)
            try write(body+"_OuterCoat_Back",size:size,color:.purple,rect:CGRect(x:0,y:0,width:20,height:20),to:folder)
            try write(body+"_OuterCoat_Front",size:size,color:.orange,rect:CGRect(x:40,y:40,width:20,height:20),to:folder)
            try write(body+"_ScarfGray_Back",size:size,color:.black,rect:CGRect(x:0,y:0,width:20,height:20),to:folder)
            try write(body+"_ScarfGray_Front",size:size,color:.cyan,rect:CGRect(x:45,y:45,width:8,height:8),to:folder)
            try write(body+"_TopShirt",size:body == "Sit" ? CGSize(width:2,height:2):size,color:.white,to:folder)
        }
        try write("Stand_BottomJeans",size:ChibiWardrobe.dimensions["Stand"]!,color:.white,to:folder)
        try write("StandExpression1_Foreground",size:ChibiWardrobe.dimensions["Stand"]!,color:.white,rect:CGRect(x:55,y:55,width:3,height:3),to:folder)
        for body in ["Focus","Rest"] {
            let size=ChibiWardrobe.dimensions[body]!
            try write(body+"_Foreground",size:size,color:.white,rect:CGRect(x:45,y:45,width:3,height:3),to:folder)
            try write(body+"_FocusSuit",size:size,color:.magenta,rect:CGRect(x:30,y:30,width:80,height:80),to:folder)
        }
        assert(Set(ChibiWardrobe.availableItems.map(\.id)) == Set(["sweater","trousers","coat","grayScarf","blackShoes","focusSuit"]))
        var economy=Economy(outfit:"base")
        economy.owned=["black","travel","shirt","sweater","trousers","coat","grayScarf","blackShoes","focusSuit"]
        economy.equipped=["top":"sweater","bottom":"trousers","outer":"coat","neck":"grayScarf","shoes":"blackShoes","focusOutfit":"focusSuit"]
        let previousOwned=economy.owned,previousEquipped=economy.equipped
        for body in bodyNames {
            let source=image(size:ChibiWardrobe.dimensions[body]!,color:.blue)
            let result=ChibiWardrobe.frame(source:source,imageName:body,body:body,economy:economy)
            assert(result.size == source.size)
            expect(result,10,10,.blue)
            expect(result,35,35,.red)
            expect(result,55,55,.orange)
            expect(result,50,50,.cyan)
            expect(result,46,46,.blue)
            expect(result,100,100,.green)
            expect(result,125,125,.yellow)
            assert(ChibiWardrobe.frame(source:source,imageName:body,body:body,economy:economy) === result)
        }
        let pieces:[(ClothingSlot,String)] = [(.top,"sweater"),(.bottom,"trousers"),(.outer,"coat"),(.neck,"grayScarf"),(.shoes,"blackShoes")]
        for combination in 0..<32 {
            var outfit=Economy(outfit:"base")
            outfit.equipped=[:]
            for (index,piece) in pieces.enumerated() where combination & (1<<index) != 0 {outfit.equipped?[piece.0.rawValue]=piece.1}
            for body in bodyNames {
                let source=image(size:ChibiWardrobe.dimensions[body]!,color:.blue)
                let result=ChibiWardrobe.frame(source:source,imageName:body,body:body,economy:outfit)
                expect(result,46,46,.blue)
                expect(result,35,35,combination & 1 != 0 ? .red:combination & 2 != 0 ? .green:.blue)
                assert(result.size == source.size)
            }
        }
        let standSize=ChibiWardrobe.dimensions["Stand"]!
        let clearEdge=image(size:standSize,color:.blue,rect:CGRect(x:20,y:20,width:240,height:391))
        let back=ChibiWardrobe.frame(source:clearEdge,imageName:"StandBack",body:"Stand",economy:economy)
        expect(back,10,10,.black);assert(color(back,10,10).alphaComponent>0.99)
        var coatOnly=economy;coatOnly.equipped?["neck"]=nil
        expect(ChibiWardrobe.frame(source:clearEdge,imageName:"StandCoatBack",body:"Stand",economy:coatOnly),10,10,.purple)
        var adjusted=economy;adjusted.adjustments=["grayScarf":WearAdjustment(x:0,y:0,scale:125)]
        let scaled=ChibiWardrobe.frame(source:image(size:standSize,color:.blue),imageName:"StandScaled",body:"Stand",economy:adjusted)
        expect(scaled,55,55,.cyan)
        let source=image(size:standSize,color:.green)
        let expression=ChibiWardrobe.frame(source:source,imageName:"StandExpression0",body:"Stand",economy:economy)
        expect(expression,46,46,.green)
        let expressionMask=ChibiWardrobe.frame(source:source,imageName:"StandExpression1",body:"Stand",economy:economy)
        expect(expressionMask,56,56,.green)
        expect(expressionMask,46,46,.cyan)
        for body in ["Focus","Rest"] {
            let source=image(size:ChibiWardrobe.dimensions[body]!,color:.blue)
            let result=ChibiWardrobe.frame(source:source,imageName:body+"Expression1",body:body,economy:economy)
            expect(result,50,50,.magenta);expect(result,46,46,.blue)
        }
        var empty=Economy(outfit:"base");empty.equipped=["top":"shirt"]
        assert(ChibiWardrobe.frame(source:source,imageName:"Stand",body:"Stand",economy:empty) === source)
        let malformed=image(size:CGSize(width:5,height:5),color:.blue)
        assert(ChibiWardrobe.frame(source:malformed,imageName:"bad",body:"Stand",economy:economy) === malformed)
        let thumb=ChibiWardrobe.thumbnail(asset:"TopSweater")!
        assert(thumb.size.width == 60 && thumb.size.height == 60)
        assert(ChibiWardrobe.thumbnail(asset:"TopShirt") == nil)
        assert(economy.owned == previousOwned && economy.equipped == previousEquipped)
        let store=GardenStore(preview:true)
        defer {try? FileManager.default.removeItem(at:store.file.deletingLastPathComponent())}
        let sweater=Cosmetic.all.first{$0.id == "sweater"}!
        store.data.garden.coins=1000
        assert(!store.commitGameChange{$0.buyCosmetic(sweater,at:store.now) && $0.wear(sweater.id,slot:sweater.slot)})
        assert(store.data.garden.coins == 1000 && !store.data.garden.economy.owned.contains(sweater.id))
        store.data.sessions=[FocusSession(id:UUID(),title:"阅读",kind:.stopwatch,date:store.now,seconds:36000)]
        store.data.garden.coins=0
        assert(!store.commitGameChange{$0.buyCosmetic(sweater,at:store.now) && $0.wear(sweater.id,slot:sweater.slot)})
        store.data.garden.coins=1000
        assert(!store.commitGameChange{$0.buyCosmetic(sweater,at:store.now) && $0.wear("invalid",slot:.top)})
        assert(store.data.garden.coins == 1000 && !store.data.garden.economy.owned.contains(sweater.id))
        assert(store.commitGameChange{$0.buyCosmetic(sweater,at:store.now) && $0.wear(sweater.id,slot:sweater.slot)})
        let afterPurchase=store.data.garden.coins
        assert(afterPurchase == 1000-sweater.price && store.data.garden.economy.worn(.top) == sweater.id)
        assert(!store.commitGameChange{$0.buyCosmetic(sweater,at:store.now) && $0.wear(sweater.id,slot:sweater.slot)})
        assert(store.data.garden.coins == afterPurchase)
        assert(store.commitGameChange{$0.wear("",slot:.top)})
        assert(store.data.garden.economy.worn(.top).isEmpty)
        assert(store.commitGameChange{$0.wear(sweater.id,slot:.top)})
        let saved=try Data(contentsOf:store.file)
        try FileManager.default.removeItem(at:store.file)
        try FileManager.default.createDirectory(at:store.file,withIntermediateDirectories:false)
        try Data([1]).write(to:store.file.appendingPathComponent("blocked"))
        let trousers=Cosmetic.all.first{$0.id == "trousers"}!
        assert(!store.commitGameChange{$0.buyCosmetic(trousers,at:store.now) && $0.wear(trousers.id,slot:trousers.slot)})
        assert(store.data.garden.coins == afterPurchase && !store.data.garden.economy.owned.contains(trousers.id))
        assert(store.data.garden.economy.worn(.top) == sweater.id && store.data.garden.economy.worn(.bottom).isEmpty)
        assert(store.saveStatus == "保存失败")
        RunLoop.main.run(until:Date().addingTimeInterval(0.65))
        assert(store.saveStatus == "保存失败")
        try FileManager.default.removeItem(at:store.file)
        try saved.write(to:store.file)
        print("PASS: 32 independent clothing combinations; insufficient funds/level, atomic buy-and-wear, duplicate buy, wear/remove and failed-save rollback without delayed retry")
        print("PASS: Q-style asset completeness and dimensions, all daily poses, back/front order, current-expression foreground masks, focus/rest suit, safe fallback, cropped thumbnails and unchanged ownership")
    }
}
