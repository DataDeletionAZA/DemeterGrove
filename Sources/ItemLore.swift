import Foundation

enum ItemLore {
    static let cropDescriptions: [String:String] = [
        "胡萝卜":"橙色的部分是储藏养分的根。拔起来时，泥土也会顺便签收一份。",
        "小麦":"穗上结的是籽粒，磨碎后才成为面粉。面包的前半生很安静。",
        "番茄":"厨房里的蔬菜，植物学上的果实。它对分类争议保持鲜红。",
        "土豆":"吃的是地下块茎，不是根。埋头工作终于有了具体形状。",
        "黄瓜":"攀着藤长大的葫芦科果实，切开后有一股清清的瓜香。",
        "卷心菜":"层层叠起的叶片抱成一个球。拆到中心，也没有藏着更小的卷心菜。",
        "蘑菇":"蘑菇属于真菌；地面上的这一朵，只是它露面的部分。",
        "玉米":"每一粒都是一枚果实，整根玉米像一栋过于整齐的公寓。",
        "南瓜":"坚实的外皮包着柔软瓜瓤。做成派以后，秋天就可以切片。",
        "草莓":"红色的部分托着一粒粒小果实。甜味有时很好，有时需要蜂蜜协助。",
        "薄荷":"轻揉叶片就有清香。它在花盆里看着温顺，给块地就另当别论。",
        "柠檬":"果皮的清香和果肉的酸，各自承担着厨房里不同的工作。",
        "星露胡萝卜":"原创的淡紫胡萝卜品种。沾着星露长大，收获后仍然老老实实算胡萝卜。",
        "洋葱":"一层层肥厚叶基围成鳞茎。厨师的眼泪通常不算进配方。",
        "菠菜":"凉爽时节长得好的叶菜，嫩叶也能拌食。煮过后，体积会非常谦虚。",
        "豌豆":"豆荚保护着一排种子；根部与固氮细菌合作。它的地下关系相当好。",
        "茄子":"茄科植物的浆果，果肉很会吸收汤汁。颜色沉稳，性格随和。",
        "甜菜":"根部储藏糖分，嫩叶也有用处。红色品种会让砧板长久记住它。",
        "苹果":"从枝头到果篮，保留着果园的清脆气味。种子长出的树未必复制原来的果味。",
        "梨":"清甜的果肉有细小石细胞，偶尔带一点沙沙的口感。植物也有自己的质地。",
        "茶叶":"茶树是常绿灌木；采下的嫩叶经过不同加工，可以走向不同茶香。",
        "缩皱无花果":"哈利·波特中的魔法植物，紫色果汁用于魔药。这里的果塔是农庄的幻想食谱。",
        "飞天李":"卢娜的耳饰也曾取它的形状。农庄把这枚魔法果实编进了自己的厨房故事。",
        "月豆":"原创。蓝白豆荚弯成月牙，煮成豆泥后便不再坚持天体形状。",
        "晴根薯":"原创。金棕块根长在狭长叶片下面，烤熟带着温暖谷香，阴天也照常成熟。"
    ]

    static let ingredientDescriptions: [String:String] = [
        "焙炒茶叶":"经过焙炒的茶叶，香气从青叶转向温暖的烘香。",
        "大米":"稻谷脱去外壳后的籽粒。吸饱水和热量，便是最朴素的一餐。",
        "鸡蛋":"蛋白受热会凝固；从流动到成形，厨房里的一点材料学。",
        "鸭蛋":"比鸡蛋更丰厚的一枚蛋，适合蒸成细腻的奶点。",
        "牛奶":"含有水、蛋白质和脂肪的乳。看起来安静，进锅后很容易溢出来。",
        "羊奶":"奶山羊带来的乳，风味会随饲料和处理方式改变。",
        "蜂蜜":"蜜蜂将花蜜加工并储存起来的成果。小罐子装着很多次往返。",
        "砂糖":"洁白的甜味晶体，少许能调味，多了也不会替你完成工作。",
        "可可":"可可种子经过加工后的香浓原料。苦味先到，甜味需要另外商量。",
        "咖啡豆":"咖啡果里的种子，烘焙后才有熟悉的香气。它只是原料，还没有开始催人起床。",
        "米饭":"大米吸水煮熟的半成品。可以直接入锅，也可以继续去见鸡蛋。",
        "面条":"面团成了细长条，等着汤汁、蔬菜和一点恰当的火候。",
        "蛋糕胚":"还没有抹奶油的蛋糕。组织已经蓬松，庆祝的理由可以稍后补。",
        "面包":"小麦经烘烤后的另一种生活，切片适合蜂蜜，整块适合饥饿。",
        "鱼肉":"从可烹饪鱼种取得的厨房食材，种类的故事留在鱼类图鉴里。",
        "黄油":"从乳脂得到的柔软脂肪，能把烘烤的香气送得很远。加工所需份数采用厨房规则。",
        "苹果酱":"苹果与糖慢慢熬稠。果园缩进玻璃罐里，还留下了一点酸。",
        "甜菜糖":"从甜菜加工出的甜味原料；这里把提取与结晶合并成了一次厨房加工。",
        "月豆泥":"原创。月豆煮软后捣成的淡蓝馅料，细腻得没有什么需要辩论。"
    ]

    static let dishDescriptions: [String:String] = [
        "田园饭":"米饭接住了胡萝卜和玉米，像把菜园缩成一只碗。",
        "蛋炒饭":"鸡蛋裹住米粒，简单的一锅饭最考验翻动的耐心。",
        "番茄面":"番茄的酸甜挂在面条上，红色汤汁负责留下证据。",
        "蘑菇烩饭":"米粒吸进奶香与菌菇风味，整碗饭显得比原料更从容。",
        "南瓜面包":"南瓜把面包染成暖金色，外壳轻脆，里面柔软。",
        "胡萝卜浓汤":"胡萝卜的甜味被慢慢煮开，橙色浓汤安静地暖着碗。",
        "番茄炒蛋":"红与金黄在锅里碰面，一道不需要仪式感的家常菜。",
        "蘑菇炖菜":"土豆让汤汁变厚，蘑菇留下清楚的林地香气。",
        "奶香焗土豆":"土豆吸着奶香烤熟，金色表面藏着柔软的中心。",
        "奶油玉米汤":"甜玉米浸在奶汤里，喝到最后仍有几粒坚持留下。",
        "田园沙拉":"黄瓜和番茄保留了脆度，也保留了各自的意见。",
        "薄荷拌黄瓜":"薄荷清香落在黄瓜切面上，是一道凉快的小菜。",
        "柠檬胡萝卜丝":"细细的胡萝卜丝拌进柠檬酸香，颜色比语气明亮。",
        "甜玉米沙拉":"玉米的甜与黄瓜的脆，落在同一只盘子上。",
        "柠檬卷心菜":"卷心菜叶片裹着清酸汁水，咬下去有整齐的响声。",
        "草莓奶油蛋糕":"红果、奶油和松软蛋糕叠在一起，切的时候需要一点公平。",
        "南瓜布丁":"南瓜融进奶蛋凝成的细腻甜点，勺尖很容易抵达底部。",
        "牛奶布丁":"蛋白质在温热中凝住奶香，轻轻一晃，还会犹豫。",
        "蜂蜜吐司":"烤过的面包接住蜂蜜，边角酥脆，中间柔软。",
        "巧克力蛋糕":"可可的微苦藏在绵软蛋糕里，让甜味有了可以依靠的边。",
        "奶茶":"茶香与奶香各退一步，杯子终于达成一致。",
        "柠檬茶":"一片柠檬把茶汤提亮，香气比杯里的热度先到。",
        "薄荷茶":"温水带出薄荷清香，入口之后，午后显得宽了一点。",
        "草莓牛奶":"草莓将牛奶染成浅粉色，果肉有时会在杯底等人。",
        "热可可":"浓厚的可可香停在杯沿，温热使苦与甜靠得很近。",
        "清蒸银鳞鱼":"原创鱼种的清蒸菜，汤汁很轻，银鳞已经完成了它的闪亮工作。",
        "柠檬月光鱼":"原创。柠檬酸香落在柔软鱼肉上，烤箱不负责保存月光。",
        "香煎金纹鱼":"原创。薄薄的煎壳带着香气，金纹的身价在锅里变得很具体。",
        "菠菜鸡蛋面":"绿叶、蛋花与面条在热汤里排好位置，一碗认真但不隆重的饭。",
        "豌豆焖饭":"蒸汽让洋葱与米饭慢慢靠近，绿色豌豆仍保留圆圆的轮廓。",
        "洋葱黄油面":"洋葱受热变甜，黄油把香气裹在面条上。空盘不需要解释。",
        "月豆面包":"原创。淡蓝豆馅藏在烤得温暖的面包里，切开才看见一弯夜色。",
        "洋葱浓汤":"洋葱的辛味在锅里退下，留下带奶香的温柔甜意。",
        "番茄烩茄子":"茄子吸饱番茄汁，形状仍在，立场已经完全改变。",
        "晴根薯焗盘":"原创。晴根薯边缘烤得金黄，黄油沿切面缓缓融下去。",
        "甜菜炖土豆":"甜菜把汤与土豆都染红，整锅菜保持着惊人的视觉团结。",
        "苹果卷心菜沙拉":"苹果的甜酸夹在卷心菜脆叶里，柠檬把收尾留得干净。",
        "梨香卷心菜":"梨片给脆叶添一点清甜，薄荷只占很小一席。",
        "飞天李黄瓜碟":"农庄幻想食谱。魔法果实与黄瓜拌在一起，盘子负责使它们留在桌上。",
        "苹果酥":"热苹果盖着松脆的黄油酥层，勺子一落下，安静便结束了。",
        "蜂蜜烤梨":"梨在烤箱里变软，蜂蜜沿果肉留下琥珀色的光。",
        "缩皱无花果塔":"农庄幻想食谱。魔法无花果卧在金色塔皮里，这次缩短的是下午茶时间。",
        "月豆小圆饼":"原创。小圆饼包着淡蓝豆馅，边缘酥松，适合慢慢掰开。",
        "南瓜馅饼":"金色饼皮托住香甜南瓜馅，切下的一角像一封秋天的便笺。",
        "梨蜜热饮":"梨的清甜融进蜜香里，温热而轻盈。",
        "飞天李特调":"农庄幻想饮品。酸甜果香盛在玻璃杯里，耳饰与饮料终于各司其职。",
        "黄油奶饮":"农庄自制的奶香饮品，借来魔法酒馆的气氛，泡沫比杯沿高一点。",
        "焙茶拿铁":"温暖焙香与牛奶相遇，蜂蜜让收尾柔和了一点。"
    ]

    static let equipmentDescriptions: [String:String] = [
        "mineral:coal":"古老植物物质形成的含碳岩石，在炉中释放储存已久的热。",
        "mineral:copper":"含铜矿石，是铸造铜料的来源。绿锈来得很慢，账单通常更快。",
        "mineral:iron":"含铁矿石，需要炉火和冶炼才能成为可用的铁。",
        "mineral:silver":"含银矿石，金属藏在岩石里，并没有提前替你铸成钱币。",
        "mineral:gold":"含金矿石，闪亮值得留意；普通亮片也很擅长这一点。",
        "mineral:quartz":"主要成分是二氧化硅的常见矿物，晶面平直而清亮。",
        "mineral:moonstone":"长石类宝石的光泽随角度游移，名字里的月亮属于比喻。",
        "mineral:diamond_shard":"钻石的小碎片，同样有坚硬的晶体结构；农庄以碎片合成整颗作为加工规则。",
        "mineral:diamond":"碳原子形成紧密晶格的宝石。很硬，但并非不会破裂。",
        "mineral:obsidian":"熔岩迅速冷却形成的火山玻璃，锋利断口有着贝壳般的弧面。",
        "mineral:starlight_ore":"原创。深色矿体里夹着细亮晶面，熄灯以后仍不急着黯淡。",
        "gear:copper_sickle":"弯刃贴着草茎收割，小心避开还要继续生长的部分。",
        "gear:iron_staff":"铁箍保护杖端，在泥地和石路上替膝盖承担一点争执。",
        "gear:iron_coat":"厚实外衣用铁扣固定，御风，也挡住路旁不太友好的枝条。",
        "gear:quartz_charm":"一枚清亮的石英坠子。寻路加成是农庄的魔法，晶体本身很安静。",
        "gear:silver_compass":"银壳收好指针，岔路上的犹豫仍由旅人自己负责。",
        "gear:obsidian_blade":"火山玻璃制成的采集刃，锋利而怕磕碰，需要稳妥收好。",
        "gear:moon_coat":"原创。云绒与羊驼绒衬住月石扣，在冷风里留下一层安稳。",
        "gear:star_lens":"原创。星辉晶片嵌入勘察镜，细微的踪迹从镜片另一侧变得清楚。",
        "rod:willow":"轻巧的入门钓竿，适合第一次把安静带到湖边。",
        "rod:ash":"结实的竿身传来水下轻震，握稳比握紧更有用。",
        "rod:river":"为河流中的长久等待准备，收线时也经得住一点急脾气。",
        "rod:ocean":"适合沿岸远投的钓竿，能把鱼线送远，不能把烦恼一起甩掉。",
        "rod:star":"原创。竿节嵌着细细星纹，夜间垂钓时也容易辨认。",
        "potion:dew":"原创。薄荷与月光草酿成的清亮药液，把一点湿润还给农田。",
        "potion:seed":"原创。南瓜与琥珀的暖色混在瓶里，晃一晃，像藏着尚未展开的春天。",
        "potion:bloom":"原创。草莓与星砂酿成的药剂，能为已经播下的作物添一点生长进度。"
    ]

    static let productDescriptions: [String:String] = [
        "sheep_wool":"剪收的卷曲羊毛，可以纺成线，也能给厚外衣一点底气。",
        "rabbit_fibre":"从安哥拉兔毛中梳收的柔软纤维，轻得让手指先察觉温度。",
        "alpaca_fibre":"羊驼提供的纤维，柔软而保暖，适合编进远行衣物。",
        "mooncalf_dung":"月痴兽留下的银色粪肥。月光再浪漫，农庄也需要处理实际事务。",
        "cloud_fleece":"原创。云团羊产的轻软绒毛，抓在手里像一片终于肯留下的云。",
        "lantern_egg":"原创。灯笼鸡留下的暖光工艺材料，壳内的光亮温和而稳定。",
        "moss_tuft":"原创。苔背鹿自然脱落的柔软苔团，带着一点湿润林地的气息。"
    ]

    static let miscellaneousDescriptions: [String:String] = [
        "feed_bag":"农庄配好的混合饲料，一袋能装入六份。粮袋不大，开饭的动静通常不小。",
        "waterweed":"顺着水流摇动的水草，捞上岸后可以堆肥。它对自己被误认为鱼没有意见。",
        "driftwood":"被水流带来的一小段木头，边角已磨得柔和。",
        "shell":"潮水留下的空贝壳，坚硬外壳曾保护过柔软的身体。",
        "river_pebble":"河流搬运磨圆的石子，表面光滑，口袋装多了仍然很重。"
    ]

    static let companionDescriptions: [String:String] = [
        "rowan":"熟悉林间采集的同伴，认得浆果，也认得值得绕开的灌丛。",
        "mira":"沿着河谷带路的向导，先看水势，再决定鞋子会付出什么代价。",
        "oswin":"稳重的巡路护卫，习惯把队伍放在自己视线里。",
        "iris":"有耐心的草药师，先认清一片叶子，再谈它能做什么。",
        "cedar":"山地勘察员，擅长在看似相同的石坡里找出可走的路。",
        "brann":"远行护卫，行囊简洁，遇事时比平常更安静。",
        "linnet":"研究雨林生物的同伴，笔记本总比衣服更需要防水。",
        "vesper":"星夜领航员，能把遥远天光与脚下道路放在同一幅图里。"
    ]

    static let clothingDescriptions: [String:String] = [
        "black":"垂落整齐的黑色长袍，袖口收得利落，适合书房里普通的一天。",
        "travel":"深绿旅行袍，宽松的下摆给脚步留下余地。",
        "winter":"紫灰厚袍，把寒冷留在领口以外，颜色像傍晚的雪影。",
        "shirt":"干净的米白衬衫，领口平整，袖子可以挽起来做事。",
        "sweater":"炭灰针织毛衣，软和而安静，适合久坐阅读。",
        "trousers":"剪裁简洁的深色长裤，走路和坐下都不必重新商量。",
        "jeans":"蓝色牛仔裤，经得住日常走动，也经得住忘记搭配。",
        "coat":"炭灰长外套，在衣摆里收住一点冷风。",
        "jacket":"轻便的浅棕夹克，适合天气尚未认真决定温度的时候。",
        "grayScarf":"灰色围巾松松绕在颈间，让外出的理由少冷一点。",
        "greenScarf":"一条墨绿围巾，颜色沉静，保暖的工作很直接。",
        "watch":"经典腕表，指针照常走动，不评价今天完成了多少。",
        "bracelet":"细细的银色手链，随手腕动作反射一点光。",
        "blackSocks":"朴素黑短袜，负责鞋子里不太显眼的舒适。",
        "creamSocks":"奶油色短袜，颜色温暖，穿好后大部分时间看不见。",
        "longSocks":"深灰长袜，在靴筒与裤脚之间补上一层暖意。",
        "wizard":"黑色尖顶帽，轮廓足够明确，远远看去就有魔法师的样子。",
        "flowers":"白色小花发夹，夹住一缕头发，也留住一点春天。",
        "pumpkin":"南瓜色贝雷帽，柔软圆润，像把秋日戴在头顶。",
        "snow":"厚软的冬日绒帽，把耳边的冷风挡住一部分。",
        "glasses":"细框眼镜安稳架在鼻梁上，让神情多一点认真。",
        "mask":"贴合面部的黑色口罩，衣柜里一件低调的面饰。",
        "blackShoes":"擦得整洁的黑皮鞋，落地时声音克制。",
        "boots":"棕色短靴包住脚踝，为不太平整的路面多做一点准备。",
        "focusSuit":"适合在书桌旁久坐的常服，舒适到不必频繁想起衣服。"
    ]

    static func text(for key: String) -> String? {
        let parts=key.split(separator:":",maxSplits:1).map(String.init)
        let prefix=parts.count == 2 ? parts[0]:""
        let value=parts.count == 2 ? parts[1]:key
        switch prefix {
        case "crop","seed": return cropDescriptions[value]
        case "ingredient": return ingredient(value)
        case "dish": return dishDescriptions[value] ?? ingredient(value)
        case "fish","fishing": return NatureCatalog.fish.first{$0.id == value}?.description ?? miscellaneousDescriptions[value]
        case "bait": return NatureCatalog.baits.first{$0.id == value}?.description
        case "animal","ranch": return NatureCatalog.ranchSpecies.first{$0.id == value}?.description ?? product(value)
        case "feed": return miscellaneousDescriptions[value]
        case "forage": return NatureCatalog.forage.first{$0.id == value}?.description ?? product(value)
        case "wildlife": return NatureCatalog.wildlife.first{$0.id == value}?.description
        case "product": return product(value)
        case "mineral","mining": return equipmentDescriptions["mineral:"+value]
        case "gear","rod","potion": return equipmentDescriptions[key]
        case "companion": return companionDescriptions[value]
        case "clothing": return clothingDescriptions[value]
        case "find": return equipmentDescriptions["potion:"+value] ?? natural(value)
        default:
            if key == "water" || key == "露水" { return "清亮的农庄露水，播种和采买都需要它。小小一滴，也有自己的去处。" }
            return ingredient(key) ?? dishDescriptions[key] ?? natural(key) ?? equipmentDescriptions[key]
        }
    }

    private static func ingredient(_ name:String)->String? {
        ingredientDescriptions[name] ?? cropDescriptions[name] ??
        NatureCatalog.forage.first{$0.ingredient == name}?.description ??
        NatureCatalog.fish.first{$0.name == name}?.description
    }

    private static func product(_ id:String)->String? {
        if let text=productDescriptions[id] { return text }
        guard let item=NatureCatalog.ranchSpecies.first(where:{$0.productID == id || $0.productName == id}) else { return nil }
        if let text=productDescriptions[item.productID] {return text}
        guard let name=item.ingredient else {return nil}
        return ingredient(name)
    }

    private static func natural(_ value:String)->String? {
        NatureCatalog.forage.first{$0.id == value || $0.name == value}?.description ??
        NatureCatalog.fish.first{$0.id == value || $0.name == value}?.description ??
        NatureCatalog.ranchSpecies.first{$0.id == value || $0.name == value}?.description ?? product(value) ?? miscellaneousDescriptions[value]
    }
}
