import Foundation

enum NatureOrigin: String, Codable, CaseIterable {
    case real, harryPotter, original
    var name: String { switch self { case .real: return "现实物种"; case .harryPotter: return "哈利·波特"; case .original: return "原创幻想" } }
}

enum NatureWaterType: String, Codable { case fresh, brackish, salt }
enum NatureFishFood: String, Codable { case lake, river, sea }
enum NatureRarity: String, Codable, CaseIterable {
    case common, uncommon, rare, legendary
    var name: String { switch self { case .common: return "常见"; case .uncommon: return "少见"; case .rare: return "珍稀"; case .legendary: return "奇遇" } }
    var weight: Int { switch self { case .common: return 64; case .uncommon: return 28; case .rare: return 9; case .legendary: return 2 } }
}

struct NatureSource: Identifiable, Equatable {
    var id: String
    var title: String
    var url: String
}

struct NatureFish: Identifiable, Equatable {
    var id: String
    var name: String
    var scientificName: String?
    var origin: NatureOrigin
    var locations: [String]
    var waterTypes: [NatureWaterType]
    var baitIDs: [String]
    var rarity: NatureRarity
    var level: Int
    var foodKind: NatureFishFood
    var isCookable: Bool
    var description: String
    var sourceIDs: [String]
    var spriteKey: String { "fish_" + id }
    var salePrice: Int { switch rarity { case .common: return 6; case .uncommon: return 9; case .rare: return 15; case .legendary: return 27 } }
    var cookingIngredient: Ingredient? {
        guard isCookable else { return nil }
        switch id {
        case "silver_scale": return .silverFish
        case "moonlight": return .moonFish
        case "golden_stripe": return .goldFish
        default: return .fishFillet
        }
    }
}

struct NatureBait: Identifiable, Equatable {
    var id: String
    var name: String
    var origin: NatureOrigin
    var locations: [String]
    var waterTypes: [NatureWaterType]
    var level: Int
    var price: Int
    var description: String
    var sourceIDs: [String]
    var spriteKey: String { "bait_" + id }
}

extension NatureFish {
    var fishingHabitatIDs: [String] {
        switch id {
        case "common_carp", "yellow_perch", "largemouth_bass", "channel_catfish", "brown_bullhead", "northern_pike":
            return ["temperate_lake", "lowland_river"]
        case "bluegill", "pumpkinseed", "black_crappie", "silver_scale", "golden_stripe":
            return ["temperate_lake"]
        case "smallmouth_bass", "walleye":
            return ["temperate_lake", "cool_river"]
        case "brown_trout", "rainbow_trout", "brook_trout", "mountain_whitefish", "glass_fin":
            return ["cool_river", "mountain_lake"]
        case "cutthroat_trout", "amber_gill":
            return ["mountain_lake"]
        case "arctic_grayling", "lake_trout":
            return ["mountain_lake", "polar_lake"]
        case "arctic_char", "snow_lantern":
            return ["polar_lake"]
        case "burbot":
            return ["cool_river", "polar_lake"]
        case "capelin", "atlantic_cod":
            return ["polar_coast", "cool_shelf"]
        case "blue_tilapia", "butterfly_peacock", "arapaima", "silver_arowana", "oscar", "lotus_fan":
            return ["tropical_river"]
        case "striped_bass", "summer_flounder", "red_drum", "tidal_bell":
            return ["coast"]
        case "black_sea_bass", "atlantic_mackerel":
            return ["coast", "cool_shelf"]
        case "atlantic_herring":
            return ["cool_shelf"]
        case "mahi_mahi", "yellowfin_tuna", "swordfish", "star_sail", "ink_ribbon":
            return ["warm_pelagic"]
        case "moonlight":
            return ["temperate_lake", "lowland_river"]
        case "reed_whisker":
            return ["lowland_river"]
        case "aurora_ray":
            return ["polar_coast"]
        default:
            return []
        }
    }
}

struct NatureRanchSpecies: Identifiable, Equatable {
    var id: String
    var name: String
    var scientificName: String?
    var origin: NatureOrigin
    var level: Int
    var price: Int
    var productID: String
    var productName: String
    var productCount: Int
    var productionMinutes: Int
    var ingredient: String?
    var description: String
    var sourceIDs: [String]
    var spriteKey: String { "ranch_" + id }
    var salePrice: Int {
        switch productID {
        case "sheep_wool": return 10
        case "rabbit_fibre": return 9
        case "cashmere": return 11
        case "alpaca_fibre", "mooncalf_dung": return 12
        case "cloud_fleece": return 16
        case "lantern_egg": return 14
        case "moss_tuft": return 17
        default: return max(3, productionMinutes / 5)
        }
    }
}

struct NatureForage: Identifiable, Equatable {
    var id: String
    var name: String
    var scientificName: String?
    var origin: NatureOrigin
    var locations: [String]
    var level: Int
    var rarity: NatureRarity
    var isCookable: Bool
    var ingredient: String?
    var description: String
    var sourceIDs: [String]
    var spriteKey: String { "forage_" + id }
    var salePrice: Int { rarity == .common ? 4 : rarity == .uncommon ? 7 : rarity == .rare ? 12 : 22 }
}

struct NatureWildlife: Identifiable, Equatable {
    var id: String
    var name: String
    var scientificName: String?
    var origin: NatureOrigin
    var locations: [String]
    var level: Int
    var description: String
    var sourceIDs: [String]
    var spriteKey: String { "wildlife_" + id }
}

enum NatureCatalog {
    static let ranchSpecies: [NatureRanchSpecies] = [
        .init(id:"chicken", name:"母鸡", scientificName:"Gallus gallus domesticus", origin:.real, level:1, price:58, productID:"chicken_egg", productName:"鸡蛋", productCount:1, productionMinutes:15, ingredient:"鸡蛋", description:"会啄食种子和小虫的家禽，羽毛能帮助保温。", sourceIDs:["zoo_chicken"]),
        .init(id:"cow", name:"奶牛", scientificName:"Bos taurus", origin:.real, level:1, price:116, productID:"cow_milk", productName:"牛奶", productCount:1, productionMinutes:25, ingredient:"牛奶", description:"反刍动物，胃的不同部分帮助它利用草料。", sourceIDs:["zoo_cow"]),
        .init(id:"duck", name:"家鸭", scientificName:"Anas platyrhynchos domesticus", origin:.real, level:2, price:87, productID:"duck_egg", productName:"鸭蛋", productCount:1, productionMinutes:20, ingredient:"鸭蛋", description:"由绿头鸭驯化而来；宽嘴适合在浅水和泥边觅食。", sourceIDs:["duck_domestication"]),
        .init(id:"goat", name:"奶山羊", scientificName:"Capra hircus", origin:.real, level:3, price:116, productID:"goat_milk", productName:"羊奶", productCount:1, productionMinutes:25, ingredient:"羊奶", description:"擅长取食灌木叶片，横向瞳孔让视野更加开阔。", sourceIDs:["zoo_goat"]),
        .init(id:"sheep", name:"绵羊", scientificName:"Ovis aries", origin:.real, level:4, price:116, productID:"sheep_wool", productName:"羊毛", productCount:1, productionMinutes:35, ingredient:nil, description:"群居的反刍家畜，卷曲的羊毛纤维可以纺成线。", sourceIDs:["sheep_wool"]),
        .init(id:"rabbit", name:"安哥拉兔", scientificName:"Oryctolagus cuniculus", origin:.real, level:4, price:116, productID:"rabbit_fibre", productName:"兔绒", productCount:1, productionMinutes:30, ingredient:nil, description:"长毛家兔，需要梳理和照料毛发；兔绒来自梳收的纤维。", sourceIDs:["rabbit_fibre"]),
        .init(id:"cashmere_goat", name:"绒山羊", scientificName:"Capra hircus", origin:.real, level:5, price:174, productID:"cashmere", productName:"羊绒", productCount:1, productionMinutes:35, ingredient:nil, description:"越冬时靠细密的底绒保暖，换毛时可以梳收。", sourceIDs:["ucanr_cashmere"]),
        .init(id:"alpaca", name:"羊驼", scientificName:"Vicugna pacos", origin:.real, level:5, price:203, productID:"alpaca_fibre", productName:"羊驼绒", productCount:1, productionMinutes:40, ingredient:nil, description:"安第斯山地驯养的骆驼科动物，软蹄垫适合行走。", sourceIDs:["zoo_alpaca"]),
        .init(id:"honeybee", name:"西方蜜蜂", scientificName:"Apis mellifera", origin:.real, level:5, price:145, productID:"bee_honey", productName:"蜂蜜", productCount:1, productionMinutes:30, ingredient:"蜂蜜", description:"社会性昆虫，采集花蜜和花粉，并为许多植物传粉。", sourceIDs:["bee_pollination"]),
        .init(id:"mooncalf", name:"月痴兽", scientificName:nil, origin:.harryPotter, level:6, price:190, productID:"mooncalf_dung", productName:"银色粪肥", productCount:1, productionMinutes:40, ingredient:nil, description:"满月时出穴起舞的羞怯魔法生物；银色粪便有益于魔法植物。", sourceIDs:["hp_mooncalf"]),
        .init(id:"cloud_sheep", name:"云团羊", scientificName:nil, origin:.original, level:7, price:290, productID:"cloud_fleece", productName:"云绒", productCount:1, productionMinutes:45, ingredient:nil, description:"原创。喜欢靠着围栏打盹，轻盈的绒毛像一小片低云。", sourceIDs:[]),
        .init(id:"lantern_hen", name:"灯笼鸡", scientificName:nil, origin:.original, level:8, price:230, productID:"lantern_egg", productName:"暖光蛋", productCount:1, productionMinutes:35, ingredient:nil, description:"原创。尾羽在黄昏亮起微光，留下可用作工艺材料的暖光蛋。", sourceIDs:[]),
        .init(id:"moss_deer", name:"苔背鹿", scientificName:nil, origin:.original, level:9, price:260, productID:"moss_tuft", productName:"柔苔团", productCount:1, productionMinutes:50, ingredient:nil, description:"原创。背上生着柔软的共生苔衣，会把自然脱落的苔团留在草窝里。", sourceIDs:[])
    ]
}

extension NatureCatalog {
    static let baits: [NatureBait] = [
        .init(id:"earthworm",name:"蚯蚓饵",origin:.real,locations:["lake","river","mountains","polar","tropical"],waterTypes:[.fresh],level:3,price:1,description:"适合多种淡水鱼的虫饵。鱼还没有研究出拒绝免费午餐的习惯。",sourceIDs:["ny_fishing"]),
        .init(id:"sweetcorn",name:"甜玉米饵",origin:.real,locations:["lake","river","tropical"],waterTypes:[.fresh],level:3,price:1,description:"偏向鲤鱼和取食植物的淡水鱼。",sourceIDs:["ny_fishing"]),
        .init(id:"dough",name:"麦香面团",origin:.real,locations:["lake","river","tropical"],waterTypes:[.fresh],level:3,price:2,description:"柔软的谷物饵，适合缓水区。离成为面包，只差一个完全不同的命运。",sourceIDs:["ny_fishing"]),
        .init(id:"insect",name:"昆虫饵",origin:.real,locations:["lake","river","mountains","polar","tropical"],waterTypes:[.fresh],level:5,price:2,description:"模仿水面落虫和水生昆虫幼体。",sourceIDs:["ny_guide","adfg_grayling"]),
        .init(id:"dry_fly",name:"仿生毛钩",origin:.real,locations:["river","mountains","polar"],waterTypes:[.fresh],level:10,price:2,description:"用羽毛和纤维模仿昆虫的人工鱼饵。",sourceIDs:["ny_fishing"]),
        .init(id:"minnow",name:"小鱼饵",origin:.real,locations:["lake","river","mountains","polar","tropical","beach","sea"],waterTypes:[.fresh,.brackish,.salt],level:8,price:2,description:"为捕食性鱼类准备的小鱼形饵。",sourceIDs:["ny_fishing","fwc_peacock"]),
        .init(id:"shrimp",name:"鲜虾饵",origin:.real,locations:["beach","sea"],waterTypes:[.brackish,.salt],level:15,price:2,description:"适合河口和近岸的海水鱼。",sourceIDs:["fwc_red_drum"]),
        .init(id:"squid",name:"鱿鱼条",origin:.real,locations:["beach","sea","polar"],waterTypes:[.salt],level:15,price:3,description:"偏向近海与远海的捕食性鱼。",sourceIDs:["noaa_flounder","noaa_swordfish"]),
        .init(id:"spoon",name:"银色亮片",origin:.real,locations:["lake","river","mountains","polar","beach","sea"],waterTypes:[.fresh,.brackish,.salt],level:10,price:3,description:"靠金属反光与摆动模仿小鱼。水下的广告，也讲究投放位置。",sourceIDs:["ny_fishing"]),
        .init(id:"glow_paste",name:"星露团饵",origin:.original,locations:["lake","river","mountains","polar","tropical","beach","sea"],waterTypes:[.fresh,.brackish,.salt],level:8,price:3,description:"原创。揉入星露的微光团饵，吸引幻想鱼。",sourceIDs:[])
    ]

    static let fish: [NatureFish] = [
        .init(id:"common_carp",name:"鲤鱼",scientificName:"Cyprinus carpio",origin:.real,locations:["lake","river"],waterTypes:[.fresh],baitIDs:["earthworm","sweetcorn","dough"],rarity:.common,level:3,foodKind:.lake,isCookable:true,description:"喜欢有水草和软底的缓水。探寻河底食物时，很少顾及水面是否清澈。",sourceIDs:["ny_guide","ny_fishing"]),
        .init(id:"yellow_perch",name:"黄鲈",scientificName:"Perca flavescens",origin:.real,locations:["lake","river"],waterTypes:[.fresh],baitIDs:["earthworm","insect","minnow"],rarity:.common,level:3,foodKind:.lake,isCookable:true,description:"身侧有暗色竖纹，常在水草边寻找小动物。",sourceIDs:["ny_guide"]),
        .init(id:"bluegill",name:"蓝鳃太阳鱼",scientificName:"Lepomis macrochirus",origin:.real,locations:["lake"],waterTypes:[.fresh],baitIDs:["earthworm","insect"],rarity:.common,level:3,foodKind:.lake,isCookable:true,description:"圆扁的小鱼，常躲在浅水水草和沉木旁。",sourceIDs:["ny_guide","ny_fishing"]),
        .init(id:"pumpkinseed",name:"驼背太阳鱼",scientificName:"Lepomis gibbosus",origin:.real,locations:["lake"],waterTypes:[.fresh],baitIDs:["earthworm","insect"],rarity:.common,level:3,foodKind:.lake,isCookable:true,description:"鳃盖后缘的红斑和脸上的蓝色纹路很醒目。",sourceIDs:["ny_guide"]),
        .init(id:"largemouth_bass",name:"大口黑鲈",scientificName:"Micropterus salmoides",origin:.real,locations:["lake","river"],waterTypes:[.fresh],baitIDs:["minnow","spoon","earthworm"],rarity:.uncommon,level:5,foodKind:.lake,isCookable:true,description:"在水草和沉木旁埋伏猎物。安静并不总意味着性情温和。",sourceIDs:["fws_largemouth"]),
        .init(id:"black_crappie",name:"黑莓鲈",scientificName:"Pomoxis nigromaculatus",origin:.real,locations:["lake"],waterTypes:[.fresh],baitIDs:["minnow","insect","earthworm"],rarity:.uncommon,level:5,foodKind:.lake,isCookable:true,description:"银灰的身体散布黑斑，喜欢有遮蔽物的淡水。",sourceIDs:["ny_guide"]),
        .init(id:"smallmouth_bass",name:"小口黑鲈",scientificName:"Micropterus dolomieu",origin:.real,locations:["river","lake"],waterTypes:[.fresh],baitIDs:["minnow","spoon","earthworm"],rarity:.uncommon,level:10,foodKind:.river,isCookable:true,description:"常在较清澈的岩石河段和湖中活动。",sourceIDs:["ny_guide"]),
        .init(id:"channel_catfish",name:"斑点叉尾鮰",scientificName:"Ictalurus punctatus",origin:.real,locations:["river","lake"],waterTypes:[.fresh],baitIDs:["earthworm","minnow"],rarity:.uncommon,level:10,foodKind:.river,isCookable:true,description:"有触须与分叉尾鳍，会在底层寻找食物。",sourceIDs:["ny_guide"]),
        .init(id:"brown_bullhead",name:"褐首鲇",scientificName:"Ameiurus nebulosus",origin:.real,locations:["river","lake"],waterTypes:[.fresh],baitIDs:["earthworm","minnow"],rarity:.common,level:10,foodKind:.river,isCookable:true,description:"夜里用触须探寻河底食物。黑暗对于它，少一层障碍，多一顿晚饭。",sourceIDs:["ny_fishing"]),
        .init(id:"walleye",name:"大眼梭鲈",scientificName:"Sander vitreus",origin:.real,locations:["river","lake"],waterTypes:[.fresh],baitIDs:["minnow","earthworm","spoon"],rarity:.rare,level:10,foodKind:.river,isCookable:true,description:"大眼睛适应较暗的水下环境。",sourceIDs:["ny_guide"]),
        .init(id:"northern_pike",name:"白斑狗鱼",scientificName:"Esox lucius",origin:.real,locations:["river","lake"],waterTypes:[.fresh],baitIDs:["minnow","spoon"],rarity:.rare,level:10,foodKind:.river,isCookable:true,description:"身体修长，有浅色斑点，是水草间的伏击猎手。",sourceIDs:["ny_guide"]),
        .init(id:"brown_trout",name:"褐鳟",scientificName:"Salmo trutta",origin:.real,locations:["river","mountains"],waterTypes:[.fresh],baitIDs:["earthworm","insect","dry_fly","minnow"],rarity:.uncommon,level:10,foodKind:.river,isCookable:true,description:"喜欢凉爽水域，身体常见红黑色斑点。",sourceIDs:["ny_guide","nps_fish"]),
        .init(id:"rainbow_trout",name:"虹鳟",scientificName:"Oncorhynchus mykiss",origin:.real,locations:["river","mountains"],waterTypes:[.fresh],baitIDs:["earthworm","insect","dry_fly","spoon"],rarity:.uncommon,level:10,foodKind:.river,isCookable:true,description:"体侧有粉红色带，能在凉爽河流和湖泊生活。",sourceIDs:["ny_guide","idaho_mountain"]),
        .init(id:"brook_trout",name:"美洲红点鲑",scientificName:"Salvelinus fontinalis",origin:.real,locations:["mountains","river"],waterTypes:[.fresh],baitIDs:["earthworm","insect","dry_fly"],rarity:.uncommon,level:12,foodKind:.river,isCookable:true,description:"喜爱凉水溪流；深色背部常有浅色虫纹。",sourceIDs:["idaho_mountain","ny_guide"]),
        .init(id:"cutthroat_trout",name:"割喉鳟",scientificName:"Oncorhynchus clarkii",origin:.real,locations:["mountains"],waterTypes:[.fresh],baitIDs:["insect","dry_fly","minnow"],rarity:.rare,level:12,foodKind:.river,isCookable:true,description:"下颌附近的红橙色斑纹是重要辨识特征。",sourceIDs:["idaho_mountain","parks_fish"]),
        .init(id:"mountain_whitefish",name:"山地柱白鲑",scientificName:"Prosopium williamsoni",origin:.real,locations:["mountains","river"],waterTypes:[.fresh],baitIDs:["insect","dry_fly","earthworm"],rarity:.common,level:12,foodKind:.river,isCookable:true,description:"银色的鲑科鱼类，常见于冷水山地河流。",sourceIDs:["idaho_mountain","mt_whitefish"]),
        .init(id:"arctic_grayling",name:"北极茴鱼",scientificName:"Thymallus arcticus",origin:.real,locations:["mountains","polar"],waterTypes:[.fresh],baitIDs:["insect","dry_fly","earthworm"],rarity:.rare,level:12,foodKind:.river,isCookable:true,description:"帆状背鳍在冷水里舒展，常取食水生昆虫。一面没有离开过水的旗。",sourceIDs:["adfg_grayling"]),
        .init(id:"arctic_char",name:"北极红点鲑",scientificName:"Salvelinus alpinus",origin:.real,locations:["polar"],waterTypes:[.fresh],baitIDs:["minnow","spoon","insect"],rarity:.uncommon,level:25,foodKind:.lake,isCookable:true,description:"极地冷水鱼；这里采用终生住在湖里的种群。",sourceIDs:["adfg_char"]),
        .init(id:"lake_trout",name:"湖红点鲑",scientificName:"Salvelinus namaycush",origin:.real,locations:["polar","mountains"],waterTypes:[.fresh],baitIDs:["minnow","spoon"],rarity:.rare,level:12,foodKind:.lake,isCookable:true,description:"偏爱深冷湖泊，尾鳍深叉，体表有浅色斑点。",sourceIDs:["adfg_laketrout"]),
        .init(id:"burbot",name:"江鳕",scientificName:"Lota lota",origin:.real,locations:["polar","river"],waterTypes:[.fresh],baitIDs:["minnow","earthworm"],rarity:.uncommon,level:10,foodKind:.river,isCookable:true,description:"下颌有一根触须，是寒冷淡水中的夜行猎手。",sourceIDs:["adfg_burbot"]),
        .init(id:"capelin",name:"毛鳞鱼",scientificName:"Mallotus villosus",origin:.real,locations:["polar","sea"],waterTypes:[.salt],baitIDs:["shrimp","spoon"],rarity:.common,level:20,foodKind:.sea,isCookable:true,description:"生活在寒冷海水里的小型群游鱼。",sourceIDs:["dfo_capelin"]),
        .init(id:"blue_tilapia",name:"奥利亚罗非鱼",scientificName:"Oreochromis aureus",origin:.real,locations:["tropical"],waterTypes:[.fresh],baitIDs:["sweetcorn","dough","earthworm"],rarity:.common,level:18,foodKind:.river,isCookable:true,description:"生活在温暖的湖泊和河流，常取食藻类和碎屑。",sourceIDs:["fwc_tilapia"]),
        .init(id:"butterfly_peacock",name:"眼斑丽鱼",scientificName:"Cichla ocellaris",origin:.real,locations:["tropical"],waterTypes:[.fresh],baitIDs:["minnow"],rarity:.uncommon,level:18,foodKind:.river,isCookable:true,description:"温暖淡水中的捕食者，尾部眼斑十分醒目。",sourceIDs:["fwc_peacock"]),
        .init(id:"arapaima",name:"巨骨舌鱼",scientificName:"Arapaima gigas",origin:.real,locations:["tropical"],waterTypes:[.fresh],baitIDs:["minnow","insect"],rarity:.legendary,level:18,foodKind:.river,isCookable:false,description:"亚马孙流域的大型鱼，会浮到水面呼吸空气。",sourceIDs:["zoo_arapaima"]),
        .init(id:"silver_arowana",name:"双须骨舌鱼",scientificName:"Osteoglossum bicirrhosum",origin:.real,locations:["tropical"],waterTypes:[.fresh],baitIDs:["insect","minnow","earthworm"],rarity:.rare,level:18,foodKind:.river,isCookable:false,description:"银色长身与上翘的嘴，适合在水面附近觅食。",sourceIDs:["zoo_arowana"]),
        .init(id:"oscar",name:"眼斑星丽鱼",scientificName:"Astronotus ocellatus",origin:.real,locations:["tropical"],waterTypes:[.fresh],baitIDs:["earthworm","insect","minnow"],rarity:.uncommon,level:18,foodKind:.river,isCookable:false,description:"南美洲暖水鱼，尾柄处常有显眼的眼状斑。",sourceIDs:["fwc_oscar"]),
        .init(id:"striped_bass",name:"条纹鲈",scientificName:"Morone saxatilis",origin:.real,locations:["beach"],waterTypes:[.brackish,.salt],baitIDs:["minnow","shrimp","spoon"],rarity:.uncommon,level:15,foodKind:.sea,isCookable:true,description:"沿岸与河口的洄游鱼，身侧有平行深色条纹。",sourceIDs:["noaa_stripedbass"]),
        .init(id:"black_sea_bass",name:"黑海鲈",scientificName:"Centropristis striata",origin:.real,locations:["beach","sea"],waterTypes:[.salt],baitIDs:["shrimp","squid","minnow"],rarity:.uncommon,level:15,foodKind:.sea,isCookable:true,description:"常靠近礁石和其他海底结构活动。",sourceIDs:["noaa_seabass"]),
        .init(id:"summer_flounder",name:"夏鲆",scientificName:"Paralichthys dentatus",origin:.real,locations:["beach"],waterTypes:[.brackish,.salt],baitIDs:["shrimp","squid","minnow"],rarity:.uncommon,level:15,foodKind:.sea,isCookable:true,description:"身体扁平，常卧在沙泥底等待猎物。",sourceIDs:["noaa_flounder"]),
        .init(id:"red_drum",name:"眼斑拟石首鱼",scientificName:"Sciaenops ocellatus",origin:.real,locations:["beach"],waterTypes:[.brackish,.salt],baitIDs:["shrimp","minnow"],rarity:.rare,level:15,foodKind:.sea,isCookable:true,description:"尾柄有黑斑，常在河口和近岸寻找甲壳类。",sourceIDs:["fwc_red_drum"]),
        .init(id:"atlantic_cod",name:"大西洋鳕",scientificName:"Gadus morhua",origin:.real,locations:["sea","polar"],waterTypes:[.salt],baitIDs:["minnow","squid"],rarity:.uncommon,level:20,foodKind:.sea,isCookable:true,description:"冷水大陆架鱼类，下颌有明显触须。",sourceIDs:["noaa_cod"]),
        .init(id:"atlantic_herring",name:"大西洋鲱",scientificName:"Clupea harengus",origin:.real,locations:["sea"],waterTypes:[.salt],baitIDs:["spoon","shrimp"],rarity:.common,level:20,foodKind:.sea,isCookable:true,description:"银色鱼群一起转身，像海里翻过一页薄纸。主要取食浮游动物。",sourceIDs:["noaa_herring"]),
        .init(id:"atlantic_mackerel",name:"大西洋鲭",scientificName:"Scomber scombrus",origin:.real,locations:["sea","beach"],waterTypes:[.salt],baitIDs:["spoon","minnow","squid"],rarity:.common,level:15,foodKind:.sea,isCookable:true,description:"背上有波浪纹，常成群在海水中游动。",sourceIDs:["noaa_mackerel"]),
        .init(id:"mahi_mahi",name:"鲯鳅",scientificName:"Coryphaena hippurus",origin:.real,locations:["sea"],waterTypes:[.salt],baitIDs:["minnow","squid","spoon"],rarity:.rare,level:20,foodKind:.sea,isCookable:true,description:"暖水远洋鱼，常靠近漂浮海藻和其他漂浮物。",sourceIDs:["noaa_mahimahi"]),
        .init(id:"yellowfin_tuna",name:"黄鳍金枪鱼",scientificName:"Thunnus albacares",origin:.real,locations:["sea"],waterTypes:[.salt],baitIDs:["minnow","squid"],rarity:.rare,level:20,foodKind:.sea,isCookable:true,description:"热带与亚热带远洋鱼，游速快，鳍呈鲜黄色。",sourceIDs:["noaa_yellowfin"]),
        .init(id:"swordfish",name:"剑鱼",scientificName:"Xiphias gladius",origin:.real,locations:["sea"],waterTypes:[.salt],baitIDs:["squid","minnow"],rarity:.legendary,level:20,foodKind:.sea,isCookable:true,description:"延长的扁平上颌如同长剑，在不同水层追逐猎物。名字省去了很多解释。",sourceIDs:["noaa_swordfish"]),
        .init(id:"silver_scale",name:"银鳞鱼",scientificName:nil,origin:.original,locations:["lake"],waterTypes:[.fresh],baitIDs:["earthworm","dough","glow_paste"],rarity:.common,level:3,foodKind:.lake,isCookable:true,description:"原创。转身时银鳞会接连闪亮，像抖落一串水珠。",sourceIDs:[]),
        .init(id:"moonlight",name:"月光鱼",scientificName:nil,origin:.original,locations:["lake","river"],waterTypes:[.fresh],baitIDs:["earthworm","insect","glow_paste"],rarity:.uncommon,level:3,foodKind:.lake,isCookable:true,description:"原创。半透明的鳍沿着水波留下淡淡月色。",sourceIDs:[]),
        .init(id:"golden_stripe",name:"金纹鱼",scientificName:nil,origin:.original,locations:["lake"],waterTypes:[.fresh],baitIDs:["sweetcorn","glow_paste"],rarity:.rare,level:3,foodKind:.lake,isCookable:true,description:"原创。侧身的金色纹路会随水流缓缓改变。",sourceIDs:[]),
        .init(id:"reed_whisker",name:"苇须鱼",scientificName:nil,origin:.original,locations:["river"],waterTypes:[.fresh],baitIDs:["earthworm","dough","glow_paste"],rarity:.common,level:10,foodKind:.river,isCookable:true,description:"原创。嘴边的细须像两根小芦苇，爱钻进草根下。",sourceIDs:[]),
        .init(id:"glass_fin",name:"玻璃鳍鱼",scientificName:nil,origin:.original,locations:["river","mountains"],waterTypes:[.fresh],baitIDs:["dry_fly","glow_paste"],rarity:.rare,level:10,foodKind:.river,isCookable:true,description:"原创。透明长鳍映着溪底卵石的颜色。",sourceIDs:[]),
        .init(id:"amber_gill",name:"琥珀鳃鱼",scientificName:nil,origin:.original,locations:["mountains"],waterTypes:[.fresh],baitIDs:["insect","glow_paste"],rarity:.uncommon,level:12,foodKind:.river,isCookable:true,description:"原创。鳃边像藏着一颗琥珀，在清水里轻轻发亮。",sourceIDs:[]),
        .init(id:"snow_lantern",name:"雪灯鱼",scientificName:nil,origin:.original,locations:["polar"],waterTypes:[.fresh],baitIDs:["minnow","glow_paste"],rarity:.uncommon,level:25,foodKind:.lake,isCookable:true,description:"原创。腹部发出温柔的蓝光，在冰湖下连成小灯队。",sourceIDs:[]),
        .init(id:"aurora_ray",name:"极光鳐",scientificName:nil,origin:.original,locations:["polar"],waterTypes:[.salt],baitIDs:["squid","glow_paste"],rarity:.legendary,level:25,foodKind:.sea,isCookable:false,description:"原创。翼状鳍上流动着极光，只留下图鉴里的相遇记录。",sourceIDs:[]),
        .init(id:"lotus_fan",name:"莲扇鱼",scientificName:nil,origin:.original,locations:["tropical"],waterTypes:[.fresh],baitIDs:["dough","glow_paste"],rarity:.uncommon,level:18,foodKind:.river,isCookable:true,description:"原创。尾鳍像一把小莲叶，在暖水湾里舒展。",sourceIDs:[]),
        .init(id:"tidal_bell",name:"潮铃鱼",scientificName:nil,origin:.original,locations:["beach"],waterTypes:[.brackish,.salt],baitIDs:["shrimp","glow_paste"],rarity:.uncommon,level:15,foodKind:.sea,isCookable:true,description:"原创。鳍边有贝壳一样的纹路，常跟着涨潮靠岸。",sourceIDs:[]),
        .init(id:"star_sail",name:"星帆鱼",scientificName:nil,origin:.original,locations:["sea"],waterTypes:[.salt],baitIDs:["minnow","glow_paste"],rarity:.rare,level:20,foodKind:.sea,isCookable:true,description:"原创。高背鳍像绣着星点的帆，追逐漂浮海藻。",sourceIDs:[]),
        .init(id:"ink_ribbon",name:"墨绸鱼",scientificName:nil,origin:.original,locations:["sea"],waterTypes:[.salt],baitIDs:["squid","glow_paste"],rarity:.legendary,level:20,foodKind:.sea,isCookable:false,description:"原创。深蓝长尾像展开的绸带，转身时散出星点微光。",sourceIDs:[])
    ]
}

extension NatureCatalog {
    static let forage: [NatureForage] = [
        .init(id:"wild_strawberry",name:"野草莓",scientificName:"Fragaria vesca",origin:.real,locations:["forest","lake","river"],level:5,rarity:.common,isCookable:true,ingredient:"草莓",description:"林缘和草地的低矮植物，白花之后结出小红果。",sourceIDs:["woodland_strawberry"]),
        .init(id:"bilberry",name:"欧洲越橘",scientificName:"Vaccinium myrtillus",origin:.real,locations:["forest","mountains"],level:5,rarity:.uncommon,isCookable:true,ingredient:"欧洲越橘",description:"酸性林地和山坡上的矮灌木，果实呈蓝黑色。",sourceIDs:["woodland_bilberry"]),
        .init(id:"raspberry",name:"覆盆子",scientificName:"Rubus idaeus",origin:.real,locations:["forest","river"],level:5,rarity:.common,isCookable:true,ingredient:"覆盆子",description:"枝条带刺，常见于林缘和较开阔的灌丛。",sourceIDs:["scottish_plants"]),
        .init(id:"hazelnut",name:"榛子",scientificName:"Corylus avellana",origin:.real,locations:["forest"],level:5,rarity:.uncommon,isCookable:true,ingredient:"榛子",description:"坚果包在叶状果苞里，也是许多小动物的食物。",sourceIDs:["kew_wildlife","scottish_plants"]),
        .init(id:"spearmint",name:"留兰香",scientificName:"Mentha spicata",origin:.real,locations:["lake","river"],level:3,rarity:.common,isCookable:true,ingredient:"薄荷",description:"芳香的薄荷属草本，常在潮湿环境生长。",sourceIDs:["kew_mint"]),
        .init(id:"dandelion",name:"蒲公英",scientificName:"Taraxacum officinale",origin:.real,locations:["forest","lake","river"],level:3,rarity:.common,isCookable:false,ingredient:nil,description:"黄色头状花序之后形成带冠毛的种子球。",sourceIDs:["kew_wildlife"]),
        .init(id:"rosehip",name:"犬蔷薇果",scientificName:"Rosa canina",origin:.real,locations:["forest","river"],level:5,rarity:.uncommon,isCookable:true,ingredient:"犬蔷薇果",description:"蔷薇花谢后形成的红色果实，为鸟类提供食物。",sourceIDs:["scottish_plants"]),
        .init(id:"pine_cone",name:"欧洲赤松球果",scientificName:"Pinus sylvestris",origin:.real,locations:["forest","mountains"],level:5,rarity:.common,isCookable:false,ingredient:nil,description:"落在林地上的木质球果，鳞片之间曾保护着种子。",sourceIDs:["scottish_plants"]),
        .init(id:"birch_bark",name:"白桦落皮",scientificName:"Betula pendula",origin:.real,locations:["forest","mountains"],level:5,rarity:.common,isCookable:false,ingredient:nil,description:"从地上拾得的薄片树皮，表面有深色横向纹理。",sourceIDs:["scottish_plants"]),
        .init(id:"acorn",name:"夏栎橡实",scientificName:"Quercus robur",origin:.real,locations:["forest"],level:5,rarity:.common,isCookable:false,ingredient:nil,description:"坚果坐在小杯状壳斗里，是林间动物的秋日食物。",sourceIDs:["scottish_plants"]),
        .init(id:"river_reed",name:"芦苇秆",scientificName:"Phragmites australis",origin:.real,locations:["lake","river"],level:3,rarity:.common,isCookable:false,ingredient:nil,description:"湿地边缘的高大禾草，空心茎秆可作编织材料。",sourceIDs:["kew_reed"]),
        .init(id:"willow_twig",name:"白柳落枝",scientificName:"Salix alba",origin:.real,locations:["lake","river"],level:3,rarity:.common,isCookable:false,ingredient:nil,description:"水岸柳树落下的柔韧细枝。",sourceIDs:["scottish_plants"]),
        .init(id:"cloudberry",name:"云莓",scientificName:"Rubus chamaemorus",origin:.real,locations:["polar"],level:25,rarity:.uncommon,isCookable:true,ingredient:"云莓",description:"寒冷湿地上的低矮植物，成熟果实呈琥珀色。",sourceIDs:["blm_berries"]),
        .init(id:"lingonberry",name:"红果越橘",scientificName:"Vaccinium vitis-idaea",origin:.real,locations:["polar","mountains"],level:12,rarity:.uncommon,isCookable:true,ingredient:"红果越橘",description:"常绿矮灌木，结成簇的小红果。",sourceIDs:["blm_berries"]),
        .init(id:"cottongrass",name:"棉花莎草",scientificName:"Eriophorum angustifolium",origin:.real,locations:["polar"],level:25,rarity:.common,isCookable:false,ingredient:nil,description:"寒地湿润环境中的莎草，白色冠毛随风摇动。",sourceIDs:["arctic_plants"]),
        .init(id:"driftwood",name:"海漂木",scientificName:nil,origin:.real,locations:["beach"],level:15,rarity:.common,isCookable:false,ingredient:nil,description:"被水流搬运、在岸上留下的木材。",sourceIDs:["noaa_driftwood"]),
        .init(id:"sea_glass",name:"海玻璃",scientificName:nil,origin:.real,locations:["beach"],level:15,rarity:.uncommon,isCookable:false,ingredient:nil,description:"被海浪和沙砾磨圆的旧玻璃碎片。",sourceIDs:["nps_seaglass"]),
        .init(id:"quartz",name:"石英晶簇",scientificName:nil,origin:.real,locations:["mountains","river"],level:10,rarity:.uncommon,isCookable:false,ingredient:nil,description:"常见的二氧化硅矿物，可形成有平直晶面的晶体。",sourceIDs:["smithsonian_quartz"]),
        .init(id:"amethyst",name:"紫水晶",scientificName:nil,origin:.real,locations:["mountains"],level:12,rarity:.rare,isCookable:false,ingredient:nil,description:"带紫色的石英变种。",sourceIDs:["smithsonian_quartz"]),
        .init(id:"amber",name:"琥珀石",scientificName:nil,origin:.real,locations:["forest","beach"],level:5,rarity:.rare,isCookable:false,ingredient:nil,description:"古老树脂形成的有机宝石，常呈金黄到棕色。",sourceIDs:["smithsonian_amber"]),
        .init(id:"rattan",name:"藤条",scientificName:nil,origin:.real,locations:["tropical"],level:18,rarity:.common,isCookable:false,ingredient:nil,description:"棕榈科攀援植物的长茎，剥去外面的叶鞘后，坚韧的藤芯可以劈成细条来编织。",sourceIDs:["kew_rattan"]),
        .init(id:"cacao",name:"可可果",scientificName:"Theobroma cacao",origin:.real,locations:["tropical"],level:18,rarity:.uncommon,isCookable:true,ingredient:"可可",description:"果实直接长在树干和粗枝上，种子经加工可制成可可。",sourceIDs:["kew_cacao"]),
        .init(id:"vanilla",name:"香荚兰果荚",scientificName:"Vanilla planifolia",origin:.real,locations:["tropical"],level:18,rarity:.rare,isCookable:true,ingredient:"香荚兰果荚",description:"攀缘兰科植物的果实，香气在采收后的加工中逐渐形成。",sourceIDs:["cornell_vanilla"]),
        .init(id:"coconut",name:"椰子",scientificName:"Cocos nucifera",origin:.real,locations:["tropical","beach"],level:15,rarity:.uncommon,isCookable:true,ingredient:"椰子",description:"热带椰树的果实，厚纤维外层适应海岸环境。",sourceIDs:["kew_coconut"]),
        .init(id:"moon_herb",name:"月光草",scientificName:nil,origin:.original,locations:["forest","lake"],level:5,rarity:.uncommon,isCookable:false,ingredient:nil,description:"原创。叶缘收集淡淡月色，是魔药材料。",sourceIDs:[]),
        .init(id:"star_sand",name:"星砂",scientificName:nil,origin:.original,locations:["forest","beach","sea"],level:5,rarity:.rare,isCookable:false,ingredient:nil,description:"原创。细小颗粒在暗处闪烁，像一把碎星。",sourceIDs:[]),
        .init(id:"ember_moss",name:"余烬苔",scientificName:nil,origin:.original,locations:["mountains"],level:12,rarity:.uncommon,isCookable:false,ingredient:nil,description:"原创。贴着岩缝生长，绒尖保留着暖橙微光。",sourceIDs:[]),
        .init(id:"frost_bell",name:"霜铃花",scientificName:nil,origin:.original,locations:["polar"],level:25,rarity:.rare,isCookable:false,ingredient:nil,description:"原创。冰蓝花冠像小铃铛，霜雪在花瓣上结成细纹。",sourceIDs:[]),
        .init(id:"aurora_crystal",name:"极光晶",scientificName:nil,origin:.original,locations:["polar"],level:25,rarity:.legendary,isCookable:false,ingredient:nil,description:"原创。晶体里浮着缓缓移动的青紫光带。",sourceIDs:[]),
        .init(id:"rain_lotus",name:"雨露莲",scientificName:nil,origin:.original,locations:["tropical"],level:18,rarity:.uncommon,isCookable:false,ingredient:nil,description:"原创。宽大的叶片把雨滴收拢在一处。",sourceIDs:[]),
        .init(id:"tidal_pearl",name:"潮声珠",scientificName:nil,origin:.original,locations:["beach","sea"],level:15,rarity:.rare,isCookable:false,ingredient:nil,description:"原创。珠面有潮汐般的光纹，握在掌心仿佛能听见海浪。",sourceIDs:[]),
        .init(id:"cloud_seed",name:"云絮种",scientificName:nil,origin:.original,locations:["mountains"],level:12,rarity:.rare,isCookable:false,ingredient:nil,description:"原创。带着蓬松白绒的种子，在山风里缓慢飘落。",sourceIDs:[]),
        .init(id:"gillyweed",name:"鳃囊草",scientificName:nil,origin:.harryPotter,locations:["beach","sea"],level:15,rarity:.rare,isCookable:false,ingredient:nil,description:"原作中的地中海魔法植物，能让食用者短暂适应水下呼吸。",sourceIDs:["hp_gillyweed"]),
        .init(id:"fluxweed",name:"流液草",scientificName:nil,origin:.harryPotter,locations:["forest","river"],level:10,rarity:.rare,isCookable:false,ingredient:nil,description:"原作中的复方汤剂材料，需要在满月时采集。",sourceIDs:["hp_plants","hp_moon"]),
        .init(id:"mandrake",name:"曼德拉草",scientificName:nil,origin:.harryPotter,locations:["forest"],level:12,rarity:.legendary,isCookable:false,ingredient:nil,description:"原作中的人形魔法植物，成熟后叫声致命，可用于配制恢复药剂。",sourceIDs:["hp_mandrake"])
    ]
}

extension NatureCatalog {
    static let wildlife: [NatureWildlife] = [
        .init(id:"red_fox",name:"赤狐",scientificName:"Vulpes vulpes",origin:.real,locations:["forest","river"],level:5,description:"尖耳、蓬松长尾的杂食动物，能适应多种林缘环境。",sourceIDs:["woodland_fox"]),
        .init(id:"red_squirrel",name:"欧亚红松鼠",scientificName:"Sciurus vulgaris",origin:.real,locations:["forest"],level:5,description:"灵活的林栖啮齿动物，常在树间搜寻种子和坚果。",sourceIDs:["woodland_squirrel"]),
        .init(id:"european_robin",name:"欧亚鸲",scientificName:"Erithacus rubecula",origin:.real,locations:["forest","lake","river"],level:3,description:"胸口橙红的小鸟，会在低矮枝条和地面附近觅食。",sourceIDs:["woodland_robin"]),
        .init(id:"european_hedgehog",name:"西欧刺猬",scientificName:"Erinaceus europaeus",origin:.real,locations:["forest"],level:5,description:"多在夜间活动，常在林缘落叶间寻找无脊椎动物。",sourceIDs:["woodland_hedgehog"]),
        .init(id:"european_badger",name:"欧洲獾",scientificName:"Meles meles",origin:.real,locations:["forest"],level:5,description:"黑白脸纹很醒目，会在林地和开阔地之间觅食。",sourceIDs:["woodland_badger"]),
        .init(id:"eurasian_otter",name:"欧亚水獭",scientificName:"Lutra lutra",origin:.real,locations:["river","lake","beach"],level:5,description:"流线形身体和有蹼的脚适合游泳，常沿水岸活动。",sourceIDs:["woodland_otter"]),
        .init(id:"mountain_hare",name:"雪兔",scientificName:"Lepus timidus",origin:.real,locations:["mountains"],level:12,description:"生活在高地的兔形目动物，冬季白毛帮助融入雪地。",sourceIDs:["naturescot_hare"]),
        .init(id:"yellow_bellied_marmot",name:"黄腹旱獭",scientificName:"Marmota flaviventris",origin:.real,locations:["mountains"],level:12,description:"喜欢岩石和高山草地，常站在岩顶观察四周。",sourceIDs:["nps_marmot"]),
        .init(id:"arctic_fox",name:"北极狐",scientificName:"Vulpes lagopus",origin:.real,locations:["polar"],level:25,description:"短耳和厚毛帮助保温，适应无树的寒冷地区。",sourceIDs:["adfg_fox"]),
        .init(id:"snowy_owl",name:"雪鸮",scientificName:"Bubo scandiacus",origin:.real,locations:["polar"],level:25,description:"北方苔原的白色大鸮，羽毛间常带深色斑纹。",sourceIDs:["adfg_owl"]),
        .init(id:"red_eyed_tree_frog",name:"红眼树蛙",scientificName:"Agalychnis callidryas",origin:.real,locations:["tropical"],level:18,description:"热带林间的夜行蛙类，用脚趾吸盘攀住叶片。",sourceIDs:["zoo_treefrog"]),
        .init(id:"harbor_seal",name:"港海豹",scientificName:"Phoca vitulina",origin:.real,locations:["beach","sea","polar"],level:15,description:"近岸海豹，会在岩礁和沙洲休息，再入水觅食。",sourceIDs:["noaa_seal"]),
        .init(id:"bowtruckle",name:"护树罗锅",scientificName:nil,origin:.harryPotter,locations:["forest"],level:8,description:"原作中守护树木的枝条状小生物，擅长藏在绿叶和树皮间。",sourceIDs:["hp_bowtruckle"]),
        .init(id:"moon_moth",name:"月绒蛾",scientificName:nil,origin:.original,locations:["forest","lake"],level:5,description:"原创。绒毛般的触角轻颤，翅面像一对小月牙。",sourceIDs:[]),
        .init(id:"pebble_tortoise",name:"卵石龟",scientificName:nil,origin:.original,locations:["river","mountains"],level:10,description:"原创。背甲像一堆圆卵石，静止时很难被发现。",sourceIDs:[]),
        .init(id:"rain_sprite",name:"雨枝灵",scientificName:nil,origin:.original,locations:["tropical"],level:18,description:"原创。手脚像细枝，爱把叶片上的雨水晃成一串。",sourceIDs:[]),
        .init(id:"tidal_mouse",name:"潮沫鼠",scientificName:nil,origin:.original,locations:["beach"],level:15,description:"原创。卷尾像小海浪，会沿潮线搜集圆润的小石子。",sourceIDs:[])
    ]
}

extension NatureCatalog {
    static let sources: [NatureSource] = [
        .init(id:"ny_guide",title:"NYSDEC · I FISH NY 淡水鱼辨识、栖地与食性",url:"https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf"),
        .init(id:"ny_fishing",title:"NYSDEC · 纽约钓鱼地图与鱼饵建议",url:"https://extapps.dec.ny.gov/docs/fish_marine_pdf/nycfishnmap.pdf"),
        .init(id:"fws_largemouth",title:"USFWS · Largemouth Bass",url:"https://www.fws.gov/species/largemouth-bass-micropterus-salmoides"),
        .init(id:"nps_fish",title:"NPS · Big Hole Fish",url:"https://www.nps.gov/biho/learn/nature/fish.htm"),
        .init(id:"idaho_mountain",title:"Idaho Fish and Game · North Fork Boise River",url:"https://idfg.idaho.gov/ifwis/fishingplanner/water/1156347437134"),
        .init(id:"parks_fish",title:"Parks Canada · Banff 鱼类辨识",url:"https://parks.canada.ca/pn-np/ab/banff/activ/peche-fishing/peche-fishing3"),
        .init(id:"mt_whitefish",title:"Montana Field Guide · Mountain Whitefish",url:"https://fieldguide.mt.gov/speciesDetail.aspx?elcode=afcha03060"),
        .init(id:"adfg_grayling",title:"ADF&G · Arctic Grayling",url:"https://www.adfg.alaska.gov/index.cfm?adfg=arcticgrayling.main"),
        .init(id:"adfg_char",title:"ADF&G · Arctic Char",url:"https://www.adfg.alaska.gov/index.cfm?adfg=ArcticChar.main"),
        .init(id:"adfg_laketrout",title:"ADF&G · Lake Trout",url:"https://www.adfg.alaska.gov/index.cfm?adfg=laketrout.main"),
        .init(id:"adfg_burbot",title:"ADF&G · Burbot",url:"https://www.adfg.alaska.gov/index.cfm?adfg=burbot.main"),
        .init(id:"dfo_capelin",title:"DFO Canada · Atlantic Capelin",url:"https://www.dfo-mpo.gc.ca/species-especes/profiles-profils/capelin-capelan-eng.html"),
        .init(id:"fwc_tilapia",title:"FWC · Blue Tilapia",url:"https://myfwc.com/wildlifehabitats/profiles/freshwater/blue-tilapia/"),
        .init(id:"fwc_peacock",title:"FWC · Butterfly Peacock Bass Fishing Tips",url:"https://myfwc.com/fishing/freshwater/fishing-tips/butterfly-peacock-bass/"),
        .init(id:"zoo_arapaima",title:"Smithsonian National Zoo · Arapaima",url:"https://www.nationalzoo.si.edu/animals/arapaima"),
        .init(id:"zoo_arowana",title:"Smithsonian National Zoo · Silver Arowana",url:"https://www.nationalzoo.si.edu/animals/silver-arowana"),
        .init(id:"fwc_oscar",title:"FWC · Oscar",url:"https://myfwc.com/wildlifehabitats/profiles/freshwater/oscar/"),
        .init(id:"noaa_stripedbass",title:"NOAA Fisheries · Atlantic Striped Bass",url:"https://www.fisheries.noaa.gov/species/atlantic-striped-bass"),
        .init(id:"noaa_seabass",title:"NOAA Fisheries · Black Sea Bass",url:"https://www.fisheries.noaa.gov/species/black-sea-bass"),
        .init(id:"noaa_flounder",title:"NOAA Fisheries · Summer Flounder",url:"https://www.fisheries.noaa.gov/species/summer-flounder"),
        .init(id:"fwc_red_drum",title:"FWC · Red Drum",url:"https://myfwc.com/wildlifehabitats/profiles/saltwater/drums/red-drum/"),
        .init(id:"noaa_cod",title:"NOAA Fisheries · Atlantic Cod",url:"https://www.fisheries.noaa.gov/species/atlantic-cod"),
        .init(id:"noaa_herring",title:"NOAA Fisheries · Atlantic Herring",url:"https://www.fisheries.noaa.gov/species/atlantic-herring"),
        .init(id:"noaa_mackerel",title:"NOAA Fisheries · Atlantic Mackerel",url:"https://www.fisheries.noaa.gov/species/atlantic-mackerel"),
        .init(id:"noaa_mahimahi",title:"NOAA Fisheries · Atlantic Mahi Mahi",url:"https://www.fisheries.noaa.gov/species/atlantic-mahi-mahi"),
        .init(id:"noaa_yellowfin",title:"NOAA Fisheries · Atlantic Yellowfin Tuna",url:"https://www.fisheries.noaa.gov/species/atlantic-yellowfin-tuna"),
        .init(id:"noaa_swordfish",title:"NOAA Fisheries · North Atlantic Swordfish",url:"https://www.fisheries.noaa.gov/species/north-atlantic-swordfish"),
        .init(id:"zoo_chicken",title:"Smithsonian National Zoo · Chicken",url:"https://nationalzoo.si.edu/animals/chicken"),
        .init(id:"zoo_cow",title:"Smithsonian National Zoo · Cow",url:"https://nationalzoo.si.edu/animals/cow"),
        .init(id:"zoo_goat",title:"Smithsonian National Zoo · Goat",url:"https://nationalzoo.si.edu/animals/goat"),
        .init(id:"ucanr_cashmere",title:"UC Small Farms Network · Cashmere Goats",url:"https://ucanr.edu/program/uc-small-farms-network/cashmere-goats"),
        .init(id:"zoo_alpaca",title:"Smithsonian National Zoo · Alpaca",url:"https://nationalzoo.si.edu/animals/alpaca"),
        .init(id:"duck_domestication",title:"Cornell Lab · Mallard",url:"https://www.allaboutbirds.org/guide/mallard"),
        .init(id:"sheep_wool",title:"FAO · Sheep",url:"https://www.fao.org/livestock-systems/global-distributions/sheep/en/"),
        .init(id:"rabbit_fibre",title:"FAO · Harvesting of Textile Animal Fibres",url:"https://www.fao.org/4/v9384e/v9384e05.htm"),
        .init(id:"bee_pollination",title:"USDA · Honey Bee",url:"https://www.nrcs.usda.gov/sites/default/files/2024-06/Honey%20Bee%20SD-FS-94%206-24.pdf"),
        .init(id:"woodland_strawberry",title:"Woodland Trust · Wild Strawberry",url:"https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/plants/wild-flowers/wild-strawberry/"),
        .init(id:"woodland_bilberry",title:"Woodland Trust · Bilberry",url:"https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/plants/wild-flowers/bilberry/"),
        .init(id:"kew_wildlife",title:"Kew Grow Wild · Native Plants for Wildlife",url:"https://growwild.kew.org/native-plants-wildlife"),
        .init(id:"scottish_plants",title:"Scottish Forestry · Native Tree and Shrub Species",url:"https://www.ruralpayments.org/media/resources/Trees-and-shrubs-native-to-Scotland.pdf"),
        .init(id:"kew_mint",title:"Kew POWO · Mentha spicata",url:"https://powo.science.kew.org/taxon/urn%3Alsid%3Aipni.org%3Anames%3A451162-1/general-information"),
        .init(id:"kew_reed",title:"Wisconsin DNR · Common Reed",url:"https://dnr.wisconsin.gov/topic/Invasives/fact/Phragmites"),
        .init(id:"blm_berries",title:"BLM Alaska · Wild Berries",url:"https://www.blm.gov/sites/default/files/docs/2021-08/AK-Wild-Berries-Infographic.pdf"),
        .init(id:"arctic_plants",title:"Northwest Territories · Southern Arctic Plants",url:"https://www.gov.nt.ca/sites/ecc/files/resources/southern_arctic_ecological_land_classification_report.pdf"),
        .init(id:"noaa_driftwood",title:"NOAA NWS · Coastal Driftwood",url:"https://www.weather.gov/safety/ripcurrent-waves"),
        .init(id:"nps_seaglass",title:"NPS · Sea Glass",url:"https://home.nps.gov/places/sea-glass-sign.htm"),
        .init(id:"smithsonian_quartz",title:"Smithsonian NMNH · Amethyst Quartz",url:"https://naturalhistory.si.edu/explore/collections/geogallery/10026259"),
        .init(id:"smithsonian_amber",title:"Smithsonian · Amber",url:"https://www.si.edu/object/amber-fossilized-tree-resin%3Anmnheducation_14538139"),
        .init(id:"kew_cacao",title:"Kew · Cacao Tree",url:"https://www.kew.org/plants/cacao-tree"),
        .init(id:"cornell_vanilla",title:"Cornell Conservatory · Vanilla planifolia",url:"https://conservatory.cals.cornell.edu/plants/vanilla-planifolia/"),
        .init(id:"kew_coconut",title:"Kew · Coconut Palm",url:"https://www.kew.org/plants/coconut-palm"),
        .init(id:"woodland_fox",title:"Woodland Trust · Fox",url:"https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/fox/"),
        .init(id:"woodland_squirrel",title:"Woodland Trust · Red Squirrel",url:"https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/red-squirrel/"),
        .init(id:"woodland_robin",title:"Woodland Trust · Robin",url:"https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/birds/robin/"),
        .init(id:"woodland_hedgehog",title:"Woodland Trust · Hedgehog",url:"https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/hedgehog/"),
        .init(id:"woodland_badger",title:"Woodland Trust · Badger",url:"https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/badger/"),
        .init(id:"woodland_otter",title:"Woodland Trust · Otter",url:"https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/otter/"),
        .init(id:"naturescot_hare",title:"NatureScot · Hares and Rabbits",url:"https://www.nature.scot/plants-animals-and-fungi/mammals/land-mammals/hares-and-rabbits"),
        .init(id:"nps_marmot",title:"NPS Yellowstone · Yellow-bellied Marmot",url:"https://home.nps.gov/yell/learn/nature/yellow-bellied-marmot.htm"),
        .init(id:"adfg_fox",title:"ADF&G · Arctic Fox",url:"https://www.adfg.alaska.gov/index.cfm?adfg=arcticfox.main"),
        .init(id:"adfg_owl",title:"ADF&G · Snowy Owl",url:"https://www.adfg.alaska.gov/index.cfm?adfg=birdviewing.iconicbirds&species=snowyowl"),
        .init(id:"zoo_treefrog",title:"Smithsonian National Zoo · Red-eyed Tree Frogs",url:"https://nationalzoo.si.edu/animals/news/new-zoo-red-eyed-tree-frogs"),
        .init(id:"noaa_seal",title:"NOAA Fisheries · Harbor Seal",url:"https://www.fisheries.noaa.gov/species/harbor-seal"),
        .init(id:"hp_mooncalf",title:"Harry Potter Official Encyclopedia · Mooncalf",url:"https://www.harrypotter.com/fact-file/creatures/mooncalf"),
        .init(id:"hp_gillyweed",title:"Harry Potter Official Encyclopedia · Gillyweed",url:"https://www.harrypotter.com/fact-file/plants-and-potions/gillyweed"),
        .init(id:"hp_mandrake",title:"Harry Potter Official Encyclopedia · Mandrake",url:"https://www.harrypotter.com/fact-file/plants-and-potions/mandrake"),
        .init(id:"kew_rattan",title:"Royal Botanic Gardens, Kew · Sustainable Rattan",url:"https://www.kew.org/science/our-science/projects/sustainable-rattan"),
        .init(id:"hp_bowtruckle",title:"Harry Potter Official Encyclopedia · Bowtruckle",url:"https://www.harrypotter.com/fact-file/creatures/bowtruckle"),
        .init(id:"hp_plants",title:"Harry Potter Official · Wizarding Plants",url:"https://www.harrypotter.com/features/harry-potter-101-wizarding-plants"),
        .init(id:"hp_moon",title:"Harry Potter Official · The Importance of the Moon",url:"https://www.harrypotter.com/features/the-importance-of-the-moon-in-the-wizarding-world")
    ]

    static func validationErrors() -> [String] {
        let locationWaters: [String:Set<NatureWaterType>] = ["lake":[.fresh],"river":[.fresh],"mountains":[.fresh],"polar":[.fresh,.salt],"tropical":[.fresh],"beach":[.brackish,.salt],"sea":[.salt]]
        let locationLevels = ["lake":3,"forest":5,"river":10,"mountains":12,"polar":25,"tropical":18,"beach":15,"sea":20]
        let sourceIDs = Set(sources.map(\.id))
        let baitIDs = Set(baits.map(\.id))
        var errors: [String] = []
        func check(_ id: String, _ origin: NatureOrigin, _ references: [String]) {
            if id.isEmpty || id.range(of:"^[a-z][a-z0-9_]*$",options:.regularExpression) == nil { errors.append("Invalid identifier: " + id) }
            if origin != .original && references.isEmpty { errors.append("Missing source: " + id) }
            if !Set(references).isSubset(of:sourceIDs) { errors.append("Unknown source: " + id) }
        }
        let allIDs = fish.map(\.id) + baits.map(\.id) + ranchSpecies.map(\.id) + forage.map(\.id) + wildlife.map(\.id)
        if Set(allIDs).count != allIDs.count { errors.append("Duplicate nature identifier") }
        if Set(sources.map(\.id)).count != sources.count { errors.append("Duplicate source identifier") }
        for row in fish {
            check(row.id,row.origin,row.sourceIDs)
            if row.level < 1 || row.locations.isEmpty || row.waterTypes.isEmpty || row.baitIDs.isEmpty || !Set(row.baitIDs).isSubset(of:baitIDs) { errors.append("Incomplete fish: " + row.id) }
            if row.fishingHabitatIDs.isEmpty { errors.append("Missing fishing habitat: " + row.id) }
            for location in row.locations {
                guard let water = locationWaters[location] else { errors.append("Unknown fishing location: " + row.id); continue }
                if water.isDisjoint(with:row.waterTypes) { errors.append("Water mismatch: " + row.id + "/" + location) }
                let usable = baits.contains { bait in row.baitIDs.contains(bait.id) && bait.locations.contains(location) && !Set(bait.waterTypes).isDisjoint(with:row.waterTypes) && bait.level <= max(row.level,locationLevels[location] ?? 1) }
                if !usable { errors.append("No available bait: " + row.id + "/" + location) }
            }
            if row.foodKind == .sea && !row.waterTypes.contains(.salt) && !row.waterTypes.contains(.brackish) { errors.append("Sea ingredient in fresh water: " + row.id) }
        }
        for row in baits {
            check(row.id,row.origin,row.sourceIDs)
            if row.price <= 0 || row.level < 1 || row.locations.isEmpty || row.waterTypes.isEmpty { errors.append("Invalid bait: " + row.id) }
        }
        for row in ranchSpecies {
            check(row.id,row.origin,row.sourceIDs)
            if row.level < 1 || row.price <= 0 || row.productCount < 1 || row.productionMinutes < 1 || row.productID.isEmpty || row.productName.isEmpty { errors.append("Invalid ranch species: " + row.id) }
        }
        for row in forage {
            check(row.id,row.origin,row.sourceIDs)
            if row.locations.isEmpty || row.locations.contains(where:{ locationLevels[$0] == nil }) || row.level < 1 || (!row.isCookable && row.ingredient != nil) { errors.append("Invalid forage: " + row.id) }
        }
        for row in wildlife {
            check(row.id,row.origin,row.sourceIDs)
            if row.locations.isEmpty || row.locations.contains(where:{ locationLevels[$0] == nil }) || row.level < 1 { errors.append("Invalid wildlife: " + row.id) }
        }
        return errors
    }
}
