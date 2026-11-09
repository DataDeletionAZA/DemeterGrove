import Foundation

enum FoodContent {
    static let cropSpriteKeys: [Crop:String] = [
        .onion:"onion", .spinach:"spinach", .pea:"pea", .eggplant:"eggplant",
        .beet:"beet", .apple:"apple", .pear:"pear", .tea:"tea",
        .shrivelfig:"shrivelfig", .dirigiblePlum:"dirigible_plum", .moonbean:"moonbean", .sunroot:"sunroot"
    ]
    static let spriteKeys: [Int:String] = Dictionary(uniqueKeysWithValues: (0..<27).map {
        ($0+25, String(format:"food_v019_%02d",$0))
    })
    static let processedSprites: [String:Int] = ["黄油":45,"苹果酱":46,"甜菜糖":47,"月豆泥":48]

    static let recipes: [Dish] = {
        let rows: [(String,FoodCategory,String,CookingMethod,[String:Int])] = [
            ("菠菜鸡蛋面",.main,"noodles",.boil,["面条":1,"菠菜":1,"鸡蛋":1]),
            ("豌豆焖饭",.main,"rice",.steam,["米饭":1,"豌豆":1,"洋葱":1]),
            ("洋葱黄油面",.main,"noodles",.fry,["面条":1,"洋葱":1,"黄油":1]),
            ("月豆面包",.main,"bread",.bake,["小麦":1,"月豆泥":1,"牛奶":1]),
            ("洋葱浓汤",.hot,"soup",.boil,["洋葱":1,"牛奶":1]),
            ("番茄烩茄子",.hot,"stirfry",.fry,["番茄":1,"茄子":1]),
            ("晴根薯焗盘",.hot,"bake",.bake,["晴根薯":1,"黄油":1]),
            ("甜菜炖土豆",.hot,"soup",.boil,["甜菜":1,"土豆":1]),
            ("苹果卷心菜沙拉",.cold,"salad",.mix,["苹果":1,"卷心菜":1,"柠檬":1]),
            ("梨香卷心菜",.cold,"salad",.mix,["梨":1,"卷心菜":1,"薄荷":1]),
            ("飞天李黄瓜碟",.cold,"salad",.mix,["飞天李":1,"黄瓜":1]),
            ("苹果酥",.dessert,"cake",.bake,["苹果酱":1,"小麦":1,"黄油":1]),
            ("蜂蜜烤梨",.dessert,"toast",.bake,["梨":1,"蜂蜜":1,"甜菜糖":1]),
            ("缩皱无花果塔",.dessert,"cake",.bake,["缩皱无花果":1,"小麦":1,"鸡蛋":1]),
            ("月豆小圆饼",.dessert,"cake",.bake,["月豆泥":1,"小麦":1,"黄油":1]),
            ("南瓜馅饼",.dessert,"cake",.bake,["南瓜":1,"小麦":1,"鸡蛋":1]),
            ("梨蜜热饮",.drink,"tea",.brew,["梨":1,"蜂蜜":1]),
            ("飞天李特调",.drink,"tea",.mix,["飞天李":1,"柠檬":1,"蜂蜜":1]),
            ("黄油奶饮",.drink,"milk",.brew,["牛奶":1,"黄油":1,"砂糖":1]),
            ("焙茶拿铁",.drink,"tea",.brew,["焙炒茶叶":1,"牛奶":1,"蜂蜜":1]),
            ("黄油",.main,"bread",.mix,["牛奶":2]),
            ("苹果酱",.main,"bread",.boil,["苹果":2,"砂糖":1]),
            ("甜菜糖",.main,"bread",.boil,["甜菜":2]),
            ("月豆泥",.main,"bread",.boil,["月豆":2])
        ]
        return rows.enumerated().map { index,row in
            var dish=Dish(id:row.0,name:row.0,category:row.1,baseID:row.2,ingredients:row.4,sprite:25+index,quality:65)
            dish.methodID=row.3
            return dish
        }
    }()
}
