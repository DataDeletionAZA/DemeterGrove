import SwiftUI
import AppKit

precondition(CommandLine.arguments.count == 2, "Provide the Game resources folder")
let resources = URL(fileURLWithPath: CommandLine.arguments[1])
let canvas = CGRect(x: 0, y: 0, width: 1536, height: 1024)
for object in SceneObject.allCases {
    let url = resources.appendingPathComponent(object.room).appendingPathExtension("png")
    let image = NSImage(contentsOf: url)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    assert(image.width == 1536 && image.height == 1024)
    assert(!object.outline.isEmpty && canvas.contains(object.outline.boundingRect))
    let target = object.target
    assert(target.width > 0 && target.height > 0)
    assert(object.outline.contains(CGPoint(x: target.x * canvas.width, y: target.y * canvas.height)))
    let hitArea = CGRect(x: target.x - target.width / 2, y: target.y - target.height / 2,
                         width: target.width, height: target.height)
    assert(CGRect(x: 0, y: 0, width: 1, height: 1).contains(hitArea))
}
assert(!SceneObject.taskMemo.outline.contains(CGPoint(x: 340, y: 760)))
assert(!SceneObject.recipeBook.outline.contains(CGPoint(x: 480, y: 640)))
assert(SceneObject.gardenPlots.count == 6)
assert(!SceneObject.plotOne.outline.contains(CGPoint(x: 590, y: 440)))
assert(!SceneObject.plotFour.outline.contains(CGPoint(x: 570, y: 670)))
let atlasBounds = try JSONDecoder().decode([String:[[Int]]].self,from:Data(contentsOf:resources.appendingPathComponent("Bounds.json")))
for (name,count) in [("Crops",24),("AlchemyBook",1),("ForgeBook",1)] {
    let cells = atlasBounds[name]!
    let source = NSImage(contentsOf:resources.appendingPathComponent(name+".png"))!.cgImage(forProposedRect:nil,context:nil,hints:nil)!
    assert(cells.count == count)
    let extent = CGRect(x:0,y:0,width:source.width,height:source.height)
    for box in cells {
        assert(box.count == 4)
        let rect = CGRect(x:box[0],y:box[1],width:box[2]-box[0],height:box[3]-box[1])
        assert(!rect.isEmpty && extent.contains(rect))
        assert(source.cropping(to:rect) != nil)
    }
    if name == "Crops" {
        for (index,box) in cells.enumerated() {
            let grid = CGRect(x:Double(index%5)*Double(source.width)/5,y:Double(index/5)*Double(source.height)/5,width:Double(source.width)/5,height:Double(source.height)/5).insetBy(dx:-1,dy:-1)
            assert(grid.contains(CGRect(x:box[0],y:box[1],width:box[2]-box[0],height:box[3]-box[1])))
        }
    }
}
print("PASS: all \(SceneObject.allCases.count) scene object masks match the source canvas and hit centers, with adjacent scenery excluded")
print("PASS: all 24 crop icons and both illustrated books load inside their atlas cells")
