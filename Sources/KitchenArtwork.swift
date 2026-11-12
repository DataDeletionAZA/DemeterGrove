import SwiftUI

struct SeedCrateArt: View {
    var body: some View {
        Canvas { context,size in
            let sx=size.width/48,sy=size.height/40
            func block(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:Color) {
                context.fill(Path(CGRect(x:x*sx,y:y*sy,width:w*sx,height:h*sy)),with:.color(color))
            }
            let dark=Color(red:0.25,green:0.13,blue:0.07),wood=Color(red:0.56,green:0.33,blue:0.14)
            block(3,18,42,19,dark);block(6,20,36,14,wood)
            for x in [9.0,20,31] {
                block(x,5,10,19,Color(red:0.9,green:0.78,blue:0.49));block(x+1,7,8,2,Color(red:0.64,green:0.47,blue:0.24))
                block(x+5,12,1,9,Color(red:0.25,green:0.4,blue:0.13));block(x+2,12,3,3,Color(red:0.4,green:0.58,blue:0.18));block(x+6,15,3,3,Color(red:0.49,green:0.63,blue:0.23))
            }
            block(3,23,42,3,Color(red:0.73,green:0.48,blue:0.22));block(3,33,42,3,Color(red:0.42,green:0.23,blue:0.1))
            for x in [6.0,39] {block(x,20,3,16,Color(red:0.77,green:0.51,blue:0.25));block(x,27,2,2,dark)}
        }.shadow(color:.black.opacity(0.3),radius:0,x:2,y:3).accessibilityHidden(true)
    }
}

struct IngredientCategoryDropdown: View {
    @Binding var selection:IngredientCategory
    @State private var expanded=false
    @Environment(\.compactSceneControls) private var compact
    var body:some View {
        Button {expanded.toggle()} label: {
            HStack(spacing:3) {Text(selection.rawValue).font(.system(size:11));Spacer(minLength:0);Text(expanded ? "▴":"▾").font(.caption)}
                .padding(.horizontal,8).padding(.vertical,compact ? 6:8).frame(maxWidth:.infinity).background(Palette.card,in:PixelFrame()).overlay(PixelFrame().stroke(Palette.line,lineWidth:1))
        }.buttonStyle(.plain).accessibilityLabel("食材分类，\(selection.rawValue)")
            .overlay(alignment:.topLeading) {
                if expanded {
                    VStack(alignment:.leading,spacing:0) {
                        ForEach(IngredientCategory.allCases) {category in
                            Button {selection=category;expanded=false} label: {
                                HStack {Text(category.rawValue);Spacer(minLength:0);if category == selection {Text("✓")}}
                                    .font(.system(size:11)).padding(9).frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }.magicSurface(Palette.card,strong:true).offset(y:compact ? 31:35)
                }
            }.onKeyPress(.escape) {expanded=false;return .handled}.zIndex(20)
    }
}

struct TableIngredient:View {
    var portion:KitchenSelection.Portion
    var size:CGFloat
    var takeBack:()->Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        TimelineView(.animation(minimumInterval:1/30,paused:reduceMotion)) {timeline in
            let age=timeline.date.timeIntervalSince(portion.droppedAt)
            let lift=reduceMotion ? 0:IngredientDrop.height(age:age)
            let tilt=Double(portion.slot%3-1)*5 + (reduceMotion || age>=0.64 ? 0:sin(age*13)*8)
            ObjectButton(label:"取回一份\(portion.ingredient.rawValue)",action:takeBack) {
                ZStack {
                    Rectangle().fill(.black.opacity(0.18)).frame(width:size*0.65,height:3).offset(y:size*0.40)
                    IngredientArt(name:portion.ingredient.rawValue,size:size).rotationEffect(.degrees(tilt)).offset(y:lift)
                }.frame(width:size,height:size)
            }
        }
    }
}

struct CookingToolArt:View {
    var method:CookingMethod
    var body:some View {
        Canvas {context,size in
            let sx=size.width/64,sy=size.height/48
            func block(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:Color) {
                context.fill(Path(CGRect(x:x*sx,y:y*sy,width:w*sx,height:h*sy)),with:.color(color))
            }
            let metal=Color(red:0.29,green:0.32,blue:0.33),edge=Color(red:0.66,green:0.61,blue:0.49),light=Color(red:0.85,green:0.79,blue:0.59)
            switch method {
            case .brew:
                block(17,15,28,25,edge);block(20,18,22,19,light);block(45,20,9,15,edge);block(45,23,5,8,Palette.paper);block(19,14,25,4,Color(red:0.35,green:0.2,blue:0.10))
            case .bake:
                block(10,9,44,34,metal);block(15,16,34,20,edge);block(18,19,28,14,Palette.paper);block(21,24,22,7,Palette.gold);block(16,11,3,3,light);block(24,11,3,3,light)
            case .mix:
                block(9,24,44,5,edge);block(13,29,36,6,light);block(18,35,26,6,edge);block(37,9,4,20,Palette.gold);block(30,22,10,6,Palette.goldLight)
            case .fry:
                block(6,24,38,10,metal);block(11,22,28,4,edge);block(44,25,18,5,Palette.gold);block(12,25,25,3,Color(red:0.61,green:0.37,blue:0.16))
            case .boil,.steam:
                block(13,17,38,24,metal);block(8,21,6,6,edge);block(50,21,6,6,edge);block(12,16,40,4,edge)
                block(18,22,3,14,edge)
                if method == .steam {block(14,11,36,5,light);block(28,7,8,4,edge)}
                else {block(19,19,26,4,Color(red:0.50,green:0.64,blue:0.57))}
            }
        }.accessibilityHidden(true)
    }
}

struct CookingSequence:View {
    var start:Date
    var method:CookingMethod
    var ingredients:[String]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        TimelineView(.animation(minimumInterval:0.06,paused:reduceMotion)) {timeline in
            let age=max(0,timeline.date.timeIntervalSince(start))
            let stage=min(2,Int(age))
            ZStack {
                CookingToolArt(method:method).frame(width:100,height:80)
                    .rotationEffect(.degrees(reduceMotion || stage != 1 ? 0:sin(age*16)*3))
                if stage == 0 {
                    ForEach(Array(ingredients.enumerated()),id:\.offset) {index,name in
                        let p=min(1,max(0,(age-Double(index)*0.08)/0.48))
                        IngredientArt(name:name,size:27).offset(x:Double(index%3-1)*23*(1-p),y:reduceMotion ? -28:-74+64*p*p)
                            .opacity(p>=1 ? 0:1)
                    }
                }
                Canvas {context,size in
                    for i in 0..<7 {
                        let p=(age*1.7+Double(i)/7).truncatingRemainder(dividingBy:1)
                        let x=size.width*(0.32+Double(i%4)*0.11),y=size.height*(0.48-p*0.35)
                        if stage == 1 {
                            context.fill(Path(CGRect(x:x,y:y,width:4,height:4)),with:.color(Palette.goldLight.opacity(1-p)))
                        } else if stage == 2 {
                            let d=Double(i)*Double.pi/3.5
                            context.fill(Path(CGRect(x:size.width/2+cos(d)*38,y:size.height*0.44+sin(d)*30,width:4,height:4)),with:.color(Palette.goldLight))
                        }
                    }
                }
                Text(["备料","料理中","装盘"][stage]).font(.system(size:11,weight:.medium)).foregroundStyle(Palette.goldLight)
                    .padding(.horizontal,8).padding(.vertical,4).background(Palette.paper,in:PixelFrame()).offset(y:57)
            }
        }.allowsHitTesting(false).accessibilityLabel("正在制作料理")
    }
}
