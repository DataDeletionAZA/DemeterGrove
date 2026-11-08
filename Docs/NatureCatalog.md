# DemeterGrove 自然图鉴

本目录包含 48 种鱼、10 种鱼饵、12 种牧场动物、34 种植物与采集材料，以及 17 种野外观察对象。每项都有稳定英文标识、中文名称、来源类别和独立图像标识。

## 资料与游戏规则

现实物种的学名、基本栖地、外形与食性取自渔业机构、自然保护机构、植物园、博物馆和动物园资料。哈利·波特条目以官方百科和专题为准。原创条目在类别和说明中明确标为原创。

地图将不同大陆的生境压缩为游戏区域。湖畔、河谷、群山和雨林钓点采用淡水；海滩采用河口半咸水或近岸海水；远海采用海水。极地同时包含冰湖与寒冷近海，北极红点鲑对应湖居种群，毛鳞鱼对应大西洋寒海种群。远海区域包含冷水大陆架与暖水远洋两个概念环境，海滩的椰林属于暖岸环境。区域共用地图入口不代表所有物种在同一现实水域共存。

等级、售价、稀有度、鱼饵命中关系、产物数量和生产时间均为游戏平衡数值。稀有度不代表现实保护级别；鱼饵关系是对取食习性和钓法的简化。牧场的生产分钟计入专注进度，并不对应现实动物的生长或繁殖周期。厨房的“可烹饪”是游戏配方标记，材料描述不构成现实采食鉴定。

鱼种独立存储；湖鱼、河鱼、海鱼只表示厨房分类。现实鱼中，巨骨舌鱼、双须骨舌鱼和眼斑星丽鱼在本游戏作为观赏收藏。极光鳐和墨绸鱼同样作为观赏收藏。野外动物以观察方式收入图鉴。

月痴兽的外形、满月出穴起舞和银色粪肥有官方依据。牧场等级、价格和专注生产周期是本游戏规则。鳃囊草原作产于地中海；流液草的满月采集要求、曼德拉草成熟叫声与恢复药剂用途、护树罗锅的树栖特征来自官方资料；游戏区域和获得方式属于地图编排。

稀有度抽取权重：常见 64、少见 28、珍稀 9、奇遇 2。鱼类基础售价分别为 14、22、38、62；采集材料基础售价分别为 8、14、25、40。

## 钓点生境

鱼种的 `locations` 对应地图区域，`fishingHabitatIDs` 对应区域内的具体生境。两者与水体类型共同限定可出现的鱼种。

| 生境标识 | 生境 | 地图区域 | 水体 |
|---|---|---|---|
| temperate_lake | 温带浅水湖 | lake | 淡水 |
| lowland_river | 下游缓水河段 | river | 淡水 |
| cool_river | 清凉河段 | river | 淡水 |
| mountain_lake | 高山湖泊 | mountains | 淡水 |
| polar_lake | 极地冰湖 | polar | 淡水 |
| polar_coast | 极地近岸 | polar | 海水 |
| tropical_river | 热带淡水河湾 | tropical | 淡水 |
| coast | 河口与近岸 | beach | 半咸水或海水 |
| cool_shelf | 冷水大陆架 | sea | 海水 |
| warm_pelagic | 暖水远洋 | sea | 海水 |

湖红点鲑分配给高山湖和冰湖；北极红点鲑分配给冰湖；毛鳞鱼和大西洋鳕分配给极地近岸或冷水大陆架；鲯鳅、黄鳍金枪鱼和剑鱼分配给暖水远洋。这些分配沿用对应资料中的基本生境，再简化为游戏钓点。

## 鱼类

| 标识 | 中文名与学名 | 类别 | 区域 | 等级 / 稀有度 | 鱼饵 | 厨房 | 资料 |
|---|---|---|---|---|---|---|---|
| common_carp | 鲤鱼 · *Cyprinus carpio* | 现实物种 | 湖畔、河谷 | 3 / 常见 | 蚯蚓饵、甜玉米饵、麦香面团 | 食材 | [ny_guide](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf) · [ny_fishing](https://extapps.dec.ny.gov/docs/fish_marine_pdf/nycfishnmap.pdf) |
| yellow_perch | 黄鲈 · *Perca flavescens* | 现实物种 | 湖畔、河谷 | 3 / 常见 | 蚯蚓饵、昆虫饵、小鱼饵 | 食材 | [ny_guide](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf) |
| bluegill | 蓝鳃太阳鱼 · *Lepomis macrochirus* | 现实物种 | 湖畔 | 3 / 常见 | 蚯蚓饵、昆虫饵 | 食材 | [ny_guide](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf) · [ny_fishing](https://extapps.dec.ny.gov/docs/fish_marine_pdf/nycfishnmap.pdf) |
| pumpkinseed | 驼背太阳鱼 · *Lepomis gibbosus* | 现实物种 | 湖畔 | 3 / 常见 | 蚯蚓饵、昆虫饵 | 食材 | [ny_guide](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf) |
| largemouth_bass | 大口黑鲈 · *Micropterus salmoides* | 现实物种 | 湖畔、河谷 | 5 / 少见 | 小鱼饵、银色亮片、蚯蚓饵 | 食材 | [fws_largemouth](https://www.fws.gov/species/largemouth-bass-micropterus-salmoides) |
| black_crappie | 黑莓鲈 · *Pomoxis nigromaculatus* | 现实物种 | 湖畔 | 5 / 少见 | 小鱼饵、昆虫饵、蚯蚓饵 | 食材 | [ny_guide](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf) |
| smallmouth_bass | 小口黑鲈 · *Micropterus dolomieu* | 现实物种 | 河谷、湖畔 | 10 / 少见 | 小鱼饵、银色亮片、蚯蚓饵 | 食材 | [ny_guide](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf) |
| channel_catfish | 斑点叉尾鮰 · *Ictalurus punctatus* | 现实物种 | 河谷、湖畔 | 10 / 少见 | 蚯蚓饵、小鱼饵 | 食材 | [ny_guide](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf) |
| brown_bullhead | 褐首鲇 · *Ameiurus nebulosus* | 现实物种 | 河谷、湖畔 | 10 / 常见 | 蚯蚓饵、小鱼饵 | 食材 | [ny_fishing](https://extapps.dec.ny.gov/docs/fish_marine_pdf/nycfishnmap.pdf) |
| walleye | 大眼梭鲈 · *Sander vitreus* | 现实物种 | 河谷、湖畔 | 10 / 珍稀 | 小鱼饵、蚯蚓饵、银色亮片 | 食材 | [ny_guide](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf) |
| northern_pike | 白斑狗鱼 · *Esox lucius* | 现实物种 | 河谷、湖畔 | 10 / 珍稀 | 小鱼饵、银色亮片 | 食材 | [ny_guide](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf) |
| brown_trout | 褐鳟 · *Salmo trutta* | 现实物种 | 河谷、群山 | 10 / 少见 | 蚯蚓饵、昆虫饵、仿生毛钩、小鱼饵 | 食材 | [ny_guide](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf) · [nps_fish](https://www.nps.gov/biho/learn/nature/fish.htm) |
| rainbow_trout | 虹鳟 · *Oncorhynchus mykiss* | 现实物种 | 河谷、群山 | 10 / 少见 | 蚯蚓饵、昆虫饵、仿生毛钩、银色亮片 | 食材 | [ny_guide](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf) · [idaho_mountain](https://idfg.idaho.gov/ifwis/fishingplanner/water/1156347437134) |
| brook_trout | 美洲红点鲑 · *Salvelinus fontinalis* | 现实物种 | 群山、河谷 | 12 / 少见 | 蚯蚓饵、昆虫饵、仿生毛钩 | 食材 | [idaho_mountain](https://idfg.idaho.gov/ifwis/fishingplanner/water/1156347437134) · [ny_guide](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf) |
| cutthroat_trout | 割喉鳟 · *Oncorhynchus clarkii* | 现实物种 | 群山 | 12 / 珍稀 | 昆虫饵、仿生毛钩、小鱼饵 | 食材 | [idaho_mountain](https://idfg.idaho.gov/ifwis/fishingplanner/water/1156347437134) · [parks_fish](https://parks.canada.ca/pn-np/ab/banff/activ/peche-fishing/peche-fishing3) |
| mountain_whitefish | 山地柱白鲑 · *Prosopium williamsoni* | 现实物种 | 群山、河谷 | 12 / 常见 | 昆虫饵、仿生毛钩、蚯蚓饵 | 食材 | [idaho_mountain](https://idfg.idaho.gov/ifwis/fishingplanner/water/1156347437134) · [mt_whitefish](https://fieldguide.mt.gov/speciesDetail.aspx?elcode=afcha03060) |
| arctic_grayling | 北极茴鱼 · *Thymallus arcticus* | 现实物种 | 群山、极地 | 12 / 珍稀 | 昆虫饵、仿生毛钩、蚯蚓饵 | 食材 | [adfg_grayling](https://www.adfg.alaska.gov/index.cfm?adfg=arcticgrayling.main) |
| arctic_char | 北极红点鲑 · *Salvelinus alpinus* | 现实物种 | 极地 | 25 / 少见 | 小鱼饵、银色亮片、昆虫饵 | 食材 | [adfg_char](https://www.adfg.alaska.gov/index.cfm?adfg=ArcticChar.main) |
| lake_trout | 湖红点鲑 · *Salvelinus namaycush* | 现实物种 | 极地、群山 | 12 / 珍稀 | 小鱼饵、银色亮片 | 食材 | [adfg_laketrout](https://www.adfg.alaska.gov/index.cfm?adfg=laketrout.main) |
| burbot | 江鳕 · *Lota lota* | 现实物种 | 极地、河谷 | 10 / 少见 | 小鱼饵、蚯蚓饵 | 食材 | [adfg_burbot](https://www.adfg.alaska.gov/index.cfm?adfg=burbot.main) |
| capelin | 毛鳞鱼 · *Mallotus villosus* | 现实物种 | 极地、远海 | 20 / 常见 | 鲜虾饵、银色亮片 | 食材 | [dfo_capelin](https://www.dfo-mpo.gc.ca/species-especes/profiles-profils/capelin-capelan-eng.html) |
| blue_tilapia | 奥利亚罗非鱼 · *Oreochromis aureus* | 现实物种 | 雨林 | 18 / 常见 | 甜玉米饵、麦香面团、蚯蚓饵 | 食材 | [fwc_tilapia](https://myfwc.com/wildlifehabitats/profiles/freshwater/blue-tilapia/) |
| butterfly_peacock | 眼斑丽鱼 · *Cichla ocellaris* | 现实物种 | 雨林 | 18 / 少见 | 小鱼饵 | 食材 | [fwc_peacock](https://myfwc.com/fishing/freshwater/fishing-tips/butterfly-peacock-bass/) |
| arapaima | 巨骨舌鱼 · *Arapaima gigas* | 现实物种 | 雨林 | 18 / 奇遇 | 小鱼饵、昆虫饵 | 观赏 | [zoo_arapaima](https://www.nationalzoo.si.edu/animals/arapaima) |
| silver_arowana | 双须骨舌鱼 · *Osteoglossum bicirrhosum* | 现实物种 | 雨林 | 18 / 珍稀 | 昆虫饵、小鱼饵、蚯蚓饵 | 观赏 | [zoo_arowana](https://www.nationalzoo.si.edu/animals/silver-arowana) |
| oscar | 眼斑星丽鱼 · *Astronotus ocellatus* | 现实物种 | 雨林 | 18 / 少见 | 蚯蚓饵、昆虫饵、小鱼饵 | 观赏 | [fwc_oscar](https://myfwc.com/wildlifehabitats/profiles/freshwater/oscar/) |
| striped_bass | 条纹鲈 · *Morone saxatilis* | 现实物种 | 海滩 | 15 / 少见 | 小鱼饵、鲜虾饵、银色亮片 | 食材 | [noaa_stripedbass](https://www.fisheries.noaa.gov/species/atlantic-striped-bass) |
| black_sea_bass | 黑海鲈 · *Centropristis striata* | 现实物种 | 海滩、远海 | 15 / 少见 | 鲜虾饵、鱿鱼条、小鱼饵 | 食材 | [noaa_seabass](https://www.fisheries.noaa.gov/species/black-sea-bass) |
| summer_flounder | 夏鲆 · *Paralichthys dentatus* | 现实物种 | 海滩 | 15 / 少见 | 鲜虾饵、鱿鱼条、小鱼饵 | 食材 | [noaa_flounder](https://www.fisheries.noaa.gov/species/summer-flounder) |
| red_drum | 眼斑拟石首鱼 · *Sciaenops ocellatus* | 现实物种 | 海滩 | 15 / 珍稀 | 鲜虾饵、小鱼饵 | 食材 | [fwc_red_drum](https://myfwc.com/wildlifehabitats/profiles/saltwater/drums/red-drum/) |
| atlantic_cod | 大西洋鳕 · *Gadus morhua* | 现实物种 | 远海、极地 | 20 / 少见 | 小鱼饵、鱿鱼条 | 食材 | [noaa_cod](https://www.fisheries.noaa.gov/species/atlantic-cod) |
| atlantic_herring | 大西洋鲱 · *Clupea harengus* | 现实物种 | 远海 | 20 / 常见 | 银色亮片、鲜虾饵 | 食材 | [noaa_herring](https://www.fisheries.noaa.gov/species/atlantic-herring) |
| atlantic_mackerel | 大西洋鲭 · *Scomber scombrus* | 现实物种 | 远海、海滩 | 15 / 常见 | 银色亮片、小鱼饵、鱿鱼条 | 食材 | [noaa_mackerel](https://www.fisheries.noaa.gov/species/atlantic-mackerel) |
| mahi_mahi | 鲯鳅 · *Coryphaena hippurus* | 现实物种 | 远海 | 20 / 珍稀 | 小鱼饵、鱿鱼条、银色亮片 | 食材 | [noaa_mahimahi](https://www.fisheries.noaa.gov/species/atlantic-mahi-mahi) |
| yellowfin_tuna | 黄鳍金枪鱼 · *Thunnus albacares* | 现实物种 | 远海 | 20 / 珍稀 | 小鱼饵、鱿鱼条 | 食材 | [noaa_yellowfin](https://www.fisheries.noaa.gov/species/atlantic-yellowfin-tuna) |
| swordfish | 剑鱼 · *Xiphias gladius* | 现实物种 | 远海 | 20 / 奇遇 | 鱿鱼条、小鱼饵 | 食材 | [noaa_swordfish](https://www.fisheries.noaa.gov/species/north-atlantic-swordfish) |
| silver_scale | 银鳞鱼 | 原创幻想 | 湖畔 | 3 / 常见 | 蚯蚓饵、麦香面团、星露团饵 | 食材 |  |
| moonlight | 月光鱼 | 原创幻想 | 湖畔、河谷 | 3 / 少见 | 蚯蚓饵、昆虫饵、星露团饵 | 食材 |  |
| golden_stripe | 金纹鱼 | 原创幻想 | 湖畔 | 3 / 珍稀 | 甜玉米饵、星露团饵 | 食材 |  |
| reed_whisker | 苇须鱼 | 原创幻想 | 河谷 | 10 / 常见 | 蚯蚓饵、麦香面团、星露团饵 | 食材 |  |
| glass_fin | 玻璃鳍鱼 | 原创幻想 | 河谷、群山 | 10 / 珍稀 | 仿生毛钩、星露团饵 | 食材 |  |
| amber_gill | 琥珀鳃鱼 | 原创幻想 | 群山 | 12 / 少见 | 昆虫饵、星露团饵 | 食材 |  |
| snow_lantern | 雪灯鱼 | 原创幻想 | 极地 | 25 / 少见 | 小鱼饵、星露团饵 | 食材 |  |
| aurora_ray | 极光鳐 | 原创幻想 | 极地 | 25 / 奇遇 | 鱿鱼条、星露团饵 | 观赏 |  |
| lotus_fan | 莲扇鱼 | 原创幻想 | 雨林 | 18 / 少见 | 麦香面团、星露团饵 | 食材 |  |
| tidal_bell | 潮铃鱼 | 原创幻想 | 海滩 | 15 / 少见 | 鲜虾饵、星露团饵 | 食材 |  |
| star_sail | 星帆鱼 | 原创幻想 | 远海 | 20 / 珍稀 | 小鱼饵、星露团饵 | 食材 |  |
| ink_ribbon | 墨绸鱼 | 原创幻想 | 远海 | 20 / 奇遇 | 鱿鱼条、星露团饵 | 观赏 |  |

## 鱼饵

| 标识 | 名称 | 类别 | 区域 | 等级 / 单价 | 说明 |
|---|---|---|---|---|---|
| earthworm | 蚯蚓饵 | 现实物种 | 湖畔、河谷、群山、极地、雨林 | 3 / 2 | 适合多种淡水鱼的小份虫饵。 |
| sweetcorn | 甜玉米饵 | 现实物种 | 湖畔、河谷、雨林 | 3 / 2 | 偏向鲤鱼和取食植物的淡水鱼。 |
| dough | 麦香面团 | 现实物种 | 湖畔、河谷、雨林 | 3 / 3 | 柔软的谷物饵，适合缓水区。 |
| insect | 昆虫饵 | 现实物种 | 湖畔、河谷、群山、极地、雨林 | 5 / 3 | 模仿水面落虫和水生昆虫幼体。 |
| dry_fly | 仿生毛钩 | 现实物种 | 河谷、群山、极地 | 10 / 4 | 用羽毛和纤维模仿昆虫的人工鱼饵。 |
| minnow | 小鱼饵 | 现实物种 | 湖畔、河谷、群山、极地、雨林、海滩、远海 | 8 / 4 | 为捕食性鱼类准备的小鱼形饵。 |
| shrimp | 鲜虾饵 | 现实物种 | 海滩、远海 | 15 / 4 | 适合河口和近岸的海水鱼。 |
| squid | 鱿鱼条 | 现实物种 | 海滩、远海、极地 | 15 / 5 | 偏向近海与远海的捕食性鱼。 |
| spoon | 银色亮片 | 现实物种 | 湖畔、河谷、群山、极地、海滩、远海 | 10 / 5 | 金属反光与摆动模仿游动的小鱼。 |
| glow_paste | 星露团饵 | 原创幻想 | 湖畔、河谷、群山、极地、雨林、海滩、远海 | 8 / 6 | 原创。揉入星露的微光团饵，吸引幻想鱼。 |

## 牧场

| 标识 | 动物 | 类别 | 等级 / 价格 | 产物 | 专注分钟 | 资料 |
|---|---|---|---|---|---|---|
| chicken | 母鸡 | 现实物种 | 1 / 90 | 鸡蛋 ×1 | 15 | [zoo_chicken](https://nationalzoo.si.edu/animals/chicken) |
| cow | 奶牛 | 现实物种 | 1 / 180 | 牛奶 ×1 | 25 | [zoo_cow](https://nationalzoo.si.edu/animals/cow) |
| duck | 家鸭 | 现实物种 | 2 / 130 | 鸭蛋 ×1 | 20 | [duck_domestication](https://www.allaboutbirds.org/guide/mallard) |
| goat | 奶山羊 | 现实物种 | 3 / 180 | 羊奶 ×1 | 25 | [zoo_goat](https://nationalzoo.si.edu/animals/goat) |
| sheep | 绵羊 | 现实物种 | 4 / 210 | 羊毛 ×1 | 35 | [sheep_wool](https://www.fao.org/livestock-systems/global-distributions/sheep/en/) |
| rabbit | 安哥拉兔 | 现实物种 | 4 / 190 | 兔绒 ×1 | 30 | [rabbit_fibre](https://www.fao.org/4/v9384e/v9384e05.htm) |
| alpaca | 羊驼 | 现实物种 | 5 / 280 | 羊驼绒 ×1 | 40 | [zoo_alpaca](https://nationalzoo.si.edu/animals/alpaca) |
| honeybee | 西方蜜蜂 | 现实物种 | 5 / 200 | 蜂蜜 ×1 | 30 | [bee_pollination](https://www.nrcs.usda.gov/sites/default/files/2024-06/Honey%20Bee%20SD-FS-94%206-24.pdf) |
| mooncalf | 月痴兽 | 哈利·波特 | 6 / 360 | 银色粪肥 ×1 | 40 | [hp_mooncalf](https://www.harrypotter.com/fact-file/creatures/mooncalf) |
| cloud_sheep | 云团羊 | 原创幻想 | 7 / 400 | 云绒 ×1 | 45 |  |
| lantern_hen | 灯笼鸡 | 原创幻想 | 8 / 420 | 暖光蛋 ×1 | 35 |  |
| moss_deer | 苔背鹿 | 原创幻想 | 9 / 500 | 柔苔团 ×1 | 50 |  |

## 植物与采集材料

| 标识 | 名称与学名 | 类别 | 区域 | 等级 / 稀有度 | 说明 | 资料 |
|---|---|---|---|---|---|---|
| wild_strawberry | 野草莓 · *Fragaria vesca* | 现实物种 | 森林、湖畔、河谷 | 5 / 常见 | 林缘和草地的低矮植物，白花之后结出小红果。 | [woodland_strawberry](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/plants/wild-flowers/wild-strawberry/) |
| bilberry | 欧洲越橘 · *Vaccinium myrtillus* | 现实物种 | 森林、群山 | 5 / 少见 | 酸性林地和山坡上的矮灌木，果实呈蓝黑色。 | [woodland_bilberry](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/plants/wild-flowers/bilberry/) |
| raspberry | 覆盆子 · *Rubus idaeus* | 现实物种 | 森林、河谷 | 5 / 常见 | 枝条带刺，常见于林缘和较开阔的灌丛。 | [scottish_plants](https://www.ruralpayments.org/media/resources/Trees-and-shrubs-native-to-Scotland.pdf) |
| hazelnut | 榛子 · *Corylus avellana* | 现实物种 | 森林 | 5 / 少见 | 坚果包在叶状果苞里，也是许多小动物的食物。 | [kew_wildlife](https://growwild.kew.org/native-plants-wildlife) · [scottish_plants](https://www.ruralpayments.org/media/resources/Trees-and-shrubs-native-to-Scotland.pdf) |
| spearmint | 留兰香 · *Mentha spicata* | 现实物种 | 湖畔、河谷 | 3 / 常见 | 芳香的薄荷属草本，常在潮湿环境生长。 | [kew_mint](https://powo.science.kew.org/taxon/urn%3Alsid%3Aipni.org%3Anames%3A451162-1/general-information) |
| dandelion | 蒲公英 · *Taraxacum officinale* | 现实物种 | 森林、湖畔、河谷 | 3 / 常见 | 黄色头状花序之后形成带冠毛的种子球。 | [kew_wildlife](https://growwild.kew.org/native-plants-wildlife) |
| rosehip | 犬蔷薇果 · *Rosa canina* | 现实物种 | 森林、河谷 | 5 / 少见 | 蔷薇花谢后形成的红色果实，为鸟类提供食物。 | [scottish_plants](https://www.ruralpayments.org/media/resources/Trees-and-shrubs-native-to-Scotland.pdf) |
| pine_cone | 欧洲赤松球果 · *Pinus sylvestris* | 现实物种 | 森林、群山 | 5 / 常见 | 落在林地上的木质球果，鳞片之间曾保护着种子。 | [scottish_plants](https://www.ruralpayments.org/media/resources/Trees-and-shrubs-native-to-Scotland.pdf) |
| birch_bark | 白桦落皮 · *Betula pendula* | 现实物种 | 森林、群山 | 5 / 常见 | 从地上拾得的薄片树皮，表面有深色横向纹理。 | [scottish_plants](https://www.ruralpayments.org/media/resources/Trees-and-shrubs-native-to-Scotland.pdf) |
| acorn | 夏栎橡实 · *Quercus robur* | 现实物种 | 森林 | 5 / 常见 | 坚果坐在小杯状壳斗里，是林间动物的秋日食物。 | [scottish_plants](https://www.ruralpayments.org/media/resources/Trees-and-shrubs-native-to-Scotland.pdf) |
| river_reed | 芦苇秆 · *Phragmites australis* | 现实物种 | 湖畔、河谷 | 3 / 常见 | 湿地边缘的高大禾草，空心茎秆可作编织材料。 | [kew_reed](https://dnr.wisconsin.gov/topic/Invasives/fact/Phragmites) |
| willow_twig | 白柳落枝 · *Salix alba* | 现实物种 | 湖畔、河谷 | 3 / 常见 | 水岸柳树落下的柔韧细枝。 | [scottish_plants](https://www.ruralpayments.org/media/resources/Trees-and-shrubs-native-to-Scotland.pdf) |
| cloudberry | 云莓 · *Rubus chamaemorus* | 现实物种 | 极地 | 25 / 少见 | 寒冷湿地上的低矮植物，成熟果实呈琥珀色。 | [blm_berries](https://www.blm.gov/sites/default/files/docs/2021-08/AK-Wild-Berries-Infographic.pdf) |
| lingonberry | 红果越橘 · *Vaccinium vitis-idaea* | 现实物种 | 极地、群山 | 12 / 少见 | 常绿矮灌木，结成簇的小红果。 | [blm_berries](https://www.blm.gov/sites/default/files/docs/2021-08/AK-Wild-Berries-Infographic.pdf) |
| cottongrass | 棉花莎草 · *Eriophorum angustifolium* | 现实物种 | 极地 | 25 / 常见 | 寒地湿润环境中的莎草，白色冠毛随风摇动。 | [arctic_plants](https://www.gov.nt.ca/sites/ecc/files/resources/southern_arctic_ecological_land_classification_report.pdf) |
| driftwood | 海漂木 | 现实物种 | 海滩 | 15 / 常见 | 被水流搬运、在岸上留下的木材。 | [noaa_driftwood](https://www.weather.gov/safety/ripcurrent-waves) |
| sea_glass | 海玻璃 | 现实物种 | 海滩 | 15 / 少见 | 被海浪和沙砾磨圆的旧玻璃碎片。 | [nps_seaglass](https://home.nps.gov/places/sea-glass-sign.htm) |
| quartz | 石英晶簇 | 现实物种 | 群山、河谷 | 10 / 少见 | 常见的二氧化硅矿物，可形成有平直晶面的晶体。 | [smithsonian_quartz](https://naturalhistory.si.edu/explore/collections/geogallery/10026259) |
| amethyst | 紫水晶 | 现实物种 | 群山 | 12 / 珍稀 | 带紫色的石英变种。 | [smithsonian_quartz](https://naturalhistory.si.edu/explore/collections/geogallery/10026259) |
| amber | 琥珀石 | 现实物种 | 森林、海滩 | 5 / 珍稀 | 古老树脂形成的有机宝石，常呈金黄到棕色。 | [smithsonian_amber](https://www.si.edu/object/amber-fossilized-tree-resin%3Anmnheducation_14538139) |
| cacao | 可可果 · *Theobroma cacao* | 现实物种 | 雨林 | 18 / 少见 | 果实直接长在树干和粗枝上，种子经加工可制成可可。 | [kew_cacao](https://www.kew.org/plants/cacao-tree) |
| vanilla | 香荚兰果荚 · *Vanilla planifolia* | 现实物种 | 雨林 | 18 / 珍稀 | 攀缘兰科植物的果实，香气在采收后的加工中逐渐形成。 | [cornell_vanilla](https://conservatory.cals.cornell.edu/plants/vanilla-planifolia/) |
| coconut | 椰子 · *Cocos nucifera* | 现实物种 | 雨林、海滩 | 15 / 少见 | 热带椰树的果实，厚纤维外层适应海岸环境。 | [kew_coconut](https://www.kew.org/plants/coconut-palm) |
| moon_herb | 月光草 | 原创幻想 | 森林、湖畔 | 5 / 少见 | 原创。叶缘收集淡淡月色，是魔药材料。 |  |
| star_sand | 星砂 | 原创幻想 | 森林、海滩、远海 | 5 / 珍稀 | 原创。细小颗粒在暗处闪烁，像一把碎星。 |  |
| ember_moss | 余烬苔 | 原创幻想 | 群山 | 12 / 少见 | 原创。贴着岩缝生长，绒尖保留着暖橙微光。 |  |
| frost_bell | 霜铃花 | 原创幻想 | 极地 | 25 / 珍稀 | 原创。冰蓝花冠像小铃铛，霜雪在花瓣上结成细纹。 |  |
| aurora_crystal | 极光晶 | 原创幻想 | 极地 | 25 / 奇遇 | 原创。晶体里浮着缓缓移动的青紫光带。 |  |
| rain_lotus | 雨露莲 | 原创幻想 | 雨林 | 18 / 少见 | 原创。宽大的叶片把雨滴收拢在一处。 |  |
| tidal_pearl | 潮声珠 | 原创幻想 | 海滩、远海 | 15 / 珍稀 | 原创。珠面有潮汐般的光纹，握在掌心仿佛能听见海浪。 |  |
| cloud_seed | 云絮种 | 原创幻想 | 群山 | 12 / 珍稀 | 原创。带着蓬松白绒的种子，在山风里缓慢飘落。 |  |
| gillyweed | 鳃囊草 | 哈利·波特 | 海滩、远海 | 15 / 珍稀 | 原作中的地中海魔法植物，能让食用者短暂适应水下呼吸。 | [hp_gillyweed](https://www.harrypotter.com/fact-file/plants-and-potions/gillyweed) |
| fluxweed | 流液草 | 哈利·波特 | 森林、河谷 | 10 / 珍稀 | 原作中的复方汤剂材料，需要在满月时采集。 | [hp_plants](https://www.harrypotter.com/features/harry-potter-101-wizarding-plants) · [hp_moon](https://www.harrypotter.com/features/the-importance-of-the-moon-in-the-wizarding-world) |
| mandrake | 曼德拉草 | 哈利·波特 | 森林 | 12 / 奇遇 | 原作中的人形魔法植物，成熟后叫声致命，可用于配制恢复药剂。 | [hp_mandrake](https://www.harrypotter.com/fact-file/plants-and-potions/mandrake) |

## 野外观察

| 标识 | 动物与学名 | 类别 | 区域 | 等级 | 资料 |
|---|---|---|---|---|---|
| red_fox | 赤狐 · *Vulpes vulpes* | 现实物种 | 森林、河谷 | 5 | [woodland_fox](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/fox/) |
| red_squirrel | 欧亚红松鼠 · *Sciurus vulgaris* | 现实物种 | 森林 | 5 | [woodland_squirrel](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/red-squirrel/) |
| european_robin | 欧亚鸲 · *Erithacus rubecula* | 现实物种 | 森林、湖畔、河谷 | 3 | [woodland_robin](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/birds/robin/) |
| european_hedgehog | 西欧刺猬 · *Erinaceus europaeus* | 现实物种 | 森林 | 5 | [woodland_hedgehog](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/hedgehog/) |
| european_badger | 欧洲獾 · *Meles meles* | 现实物种 | 森林 | 5 | [woodland_badger](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/badger/) |
| eurasian_otter | 欧亚水獭 · *Lutra lutra* | 现实物种 | 河谷、湖畔、海滩 | 5 | [woodland_otter](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/otter/) |
| mountain_hare | 雪兔 · *Lepus timidus* | 现实物种 | 群山 | 12 | [naturescot_hare](https://www.nature.scot/plants-animals-and-fungi/mammals/land-mammals/hares-and-rabbits) |
| yellow_bellied_marmot | 黄腹旱獭 · *Marmota flaviventris* | 现实物种 | 群山 | 12 | [nps_marmot](https://home.nps.gov/yell/learn/nature/yellow-bellied-marmot.htm) |
| arctic_fox | 北极狐 · *Vulpes lagopus* | 现实物种 | 极地 | 25 | [adfg_fox](https://www.adfg.alaska.gov/index.cfm?adfg=arcticfox.main) |
| snowy_owl | 雪鸮 · *Bubo scandiacus* | 现实物种 | 极地 | 25 | [adfg_owl](https://www.adfg.alaska.gov/index.cfm?adfg=birdviewing.iconicbirds&species=snowyowl) |
| red_eyed_tree_frog | 红眼树蛙 · *Agalychnis callidryas* | 现实物种 | 雨林 | 18 | [zoo_treefrog](https://nationalzoo.si.edu/animals/news/new-zoo-red-eyed-tree-frogs) |
| harbor_seal | 港海豹 · *Phoca vitulina* | 现实物种 | 海滩、远海、极地 | 15 | [noaa_seal](https://www.fisheries.noaa.gov/species/harbor-seal) |
| bowtruckle | 护树罗锅 | 哈利·波特 | 森林 | 8 | [hp_bowtruckle](https://www.harrypotter.com/fact-file/creatures/bowtruckle) |
| moon_moth | 月绒蛾 | 原创幻想 | 森林、湖畔 | 5 |  |
| pebble_tortoise | 卵石龟 | 原创幻想 | 河谷、群山 | 10 |  |
| rain_sprite | 雨枝灵 | 原创幻想 | 雨林 | 18 |  |
| tidal_mouse | 潮沫鼠 | 原创幻想 | 海滩 | 15 |  |

## 图像标识

独立图像存放于 `Resources/Game/Nature/`。鱼类使用 `fish_<id>.png`，鱼饵使用 `bait_<id>.png`，牧场动物使用 `ranch_<id>.png`，植物与材料使用 `forage_<id>.png`，野外观察对象使用 `wildlife_<id>.png`。名称调整不改变英文标识。

## 资料目录

- `ny_guide`：[NYSDEC · I FISH NY 淡水鱼辨识、栖地与食性](https://extapps.dec.ny.gov/docs/fish_marine_pdf/gsfishing.pdf)
- `ny_fishing`：[NYSDEC · 纽约钓鱼地图与鱼饵建议](https://extapps.dec.ny.gov/docs/fish_marine_pdf/nycfishnmap.pdf)
- `fws_largemouth`：[USFWS · Largemouth Bass](https://www.fws.gov/species/largemouth-bass-micropterus-salmoides)
- `nps_fish`：[NPS · Big Hole Fish](https://www.nps.gov/biho/learn/nature/fish.htm)
- `idaho_mountain`：[Idaho Fish and Game · North Fork Boise River](https://idfg.idaho.gov/ifwis/fishingplanner/water/1156347437134)
- `parks_fish`：[Parks Canada · Banff 鱼类辨识](https://parks.canada.ca/pn-np/ab/banff/activ/peche-fishing/peche-fishing3)
- `mt_whitefish`：[Montana Field Guide · Mountain Whitefish](https://fieldguide.mt.gov/speciesDetail.aspx?elcode=afcha03060)
- `adfg_grayling`：[ADF&G · Arctic Grayling](https://www.adfg.alaska.gov/index.cfm?adfg=arcticgrayling.main)
- `adfg_char`：[ADF&G · Arctic Char](https://www.adfg.alaska.gov/index.cfm?adfg=ArcticChar.main)
- `adfg_laketrout`：[ADF&G · Lake Trout](https://www.adfg.alaska.gov/index.cfm?adfg=laketrout.main)
- `adfg_burbot`：[ADF&G · Burbot](https://www.adfg.alaska.gov/index.cfm?adfg=burbot.main)
- `dfo_capelin`：[DFO Canada · Atlantic Capelin](https://www.dfo-mpo.gc.ca/species-especes/profiles-profils/capelin-capelan-eng.html)
- `fwc_tilapia`：[FWC · Blue Tilapia](https://myfwc.com/wildlifehabitats/profiles/freshwater/blue-tilapia/)
- `fwc_peacock`：[FWC · Butterfly Peacock Bass Fishing Tips](https://myfwc.com/fishing/freshwater/fishing-tips/butterfly-peacock-bass/)
- `zoo_arapaima`：[Smithsonian National Zoo · Arapaima](https://www.nationalzoo.si.edu/animals/arapaima)
- `zoo_arowana`：[Smithsonian National Zoo · Silver Arowana](https://www.nationalzoo.si.edu/animals/silver-arowana)
- `fwc_oscar`：[FWC · Oscar](https://myfwc.com/wildlifehabitats/profiles/freshwater/oscar/)
- `noaa_stripedbass`：[NOAA Fisheries · Atlantic Striped Bass](https://www.fisheries.noaa.gov/species/atlantic-striped-bass)
- `noaa_seabass`：[NOAA Fisheries · Black Sea Bass](https://www.fisheries.noaa.gov/species/black-sea-bass)
- `noaa_flounder`：[NOAA Fisheries · Summer Flounder](https://www.fisheries.noaa.gov/species/summer-flounder)
- `fwc_red_drum`：[FWC · Red Drum](https://myfwc.com/wildlifehabitats/profiles/saltwater/drums/red-drum/)
- `noaa_cod`：[NOAA Fisheries · Atlantic Cod](https://www.fisheries.noaa.gov/species/atlantic-cod)
- `noaa_herring`：[NOAA Fisheries · Atlantic Herring](https://www.fisheries.noaa.gov/species/atlantic-herring)
- `noaa_mackerel`：[NOAA Fisheries · Atlantic Mackerel](https://www.fisheries.noaa.gov/species/atlantic-mackerel)
- `noaa_mahimahi`：[NOAA Fisheries · Atlantic Mahi Mahi](https://www.fisheries.noaa.gov/species/atlantic-mahi-mahi)
- `noaa_yellowfin`：[NOAA Fisheries · Atlantic Yellowfin Tuna](https://www.fisheries.noaa.gov/species/atlantic-yellowfin-tuna)
- `noaa_swordfish`：[NOAA Fisheries · North Atlantic Swordfish](https://www.fisheries.noaa.gov/species/north-atlantic-swordfish)
- `zoo_chicken`：[Smithsonian National Zoo · Chicken](https://nationalzoo.si.edu/animals/chicken)
- `zoo_cow`：[Smithsonian National Zoo · Cow](https://nationalzoo.si.edu/animals/cow)
- `zoo_goat`：[Smithsonian National Zoo · Goat](https://nationalzoo.si.edu/animals/goat)
- `zoo_alpaca`：[Smithsonian National Zoo · Alpaca](https://nationalzoo.si.edu/animals/alpaca)
- `duck_domestication`：[Cornell Lab · Mallard](https://www.allaboutbirds.org/guide/mallard)
- `sheep_wool`：[FAO · Sheep](https://www.fao.org/livestock-systems/global-distributions/sheep/en/)
- `rabbit_fibre`：[FAO · Harvesting of Textile Animal Fibres](https://www.fao.org/4/v9384e/v9384e05.htm)
- `bee_pollination`：[USDA · Honey Bee](https://www.nrcs.usda.gov/sites/default/files/2024-06/Honey%20Bee%20SD-FS-94%206-24.pdf)
- `woodland_strawberry`：[Woodland Trust · Wild Strawberry](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/plants/wild-flowers/wild-strawberry/)
- `woodland_bilberry`：[Woodland Trust · Bilberry](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/plants/wild-flowers/bilberry/)
- `kew_wildlife`：[Kew Grow Wild · Native Plants for Wildlife](https://growwild.kew.org/native-plants-wildlife)
- `scottish_plants`：[Scottish Forestry · Native Tree and Shrub Species](https://www.ruralpayments.org/media/resources/Trees-and-shrubs-native-to-Scotland.pdf)
- `kew_mint`：[Kew POWO · Mentha spicata](https://powo.science.kew.org/taxon/urn%3Alsid%3Aipni.org%3Anames%3A451162-1/general-information)
- `kew_reed`：[Wisconsin DNR · Common Reed](https://dnr.wisconsin.gov/topic/Invasives/fact/Phragmites)
- `blm_berries`：[BLM Alaska · Wild Berries](https://www.blm.gov/sites/default/files/docs/2021-08/AK-Wild-Berries-Infographic.pdf)
- `arctic_plants`：[Northwest Territories · Southern Arctic Plants](https://www.gov.nt.ca/sites/ecc/files/resources/southern_arctic_ecological_land_classification_report.pdf)
- `noaa_driftwood`：[NOAA NWS · Coastal Driftwood](https://www.weather.gov/safety/ripcurrent-waves)
- `nps_seaglass`：[NPS · Sea Glass](https://home.nps.gov/places/sea-glass-sign.htm)
- `smithsonian_quartz`：[Smithsonian NMNH · Amethyst Quartz](https://naturalhistory.si.edu/explore/collections/geogallery/10026259)
- `smithsonian_amber`：[Smithsonian · Amber](https://www.si.edu/object/amber-fossilized-tree-resin%3Anmnheducation_14538139)
- `kew_cacao`：[Kew · Cacao Tree](https://www.kew.org/plants/cacao-tree)
- `cornell_vanilla`：[Cornell Conservatory · Vanilla planifolia](https://conservatory.cals.cornell.edu/plants/vanilla-planifolia/)
- `kew_coconut`：[Kew · Coconut Palm](https://www.kew.org/plants/coconut-palm)
- `woodland_fox`：[Woodland Trust · Fox](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/fox/)
- `woodland_squirrel`：[Woodland Trust · Red Squirrel](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/red-squirrel/)
- `woodland_robin`：[Woodland Trust · Robin](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/birds/robin/)
- `woodland_hedgehog`：[Woodland Trust · Hedgehog](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/hedgehog/)
- `woodland_badger`：[Woodland Trust · Badger](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/badger/)
- `woodland_otter`：[Woodland Trust · Otter](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/otter/)
- `naturescot_hare`：[NatureScot · Hares and Rabbits](https://www.nature.scot/plants-animals-and-fungi/mammals/land-mammals/hares-and-rabbits)
- `nps_marmot`：[NPS Yellowstone · Yellow-bellied Marmot](https://home.nps.gov/yell/learn/nature/yellow-bellied-marmot.htm)
- `adfg_fox`：[ADF&G · Arctic Fox](https://www.adfg.alaska.gov/index.cfm?adfg=arcticfox.main)
- `adfg_owl`：[ADF&G · Snowy Owl](https://www.adfg.alaska.gov/index.cfm?adfg=birdviewing.iconicbirds&species=snowyowl)
- `zoo_treefrog`：[Smithsonian National Zoo · Red-eyed Tree Frogs](https://nationalzoo.si.edu/animals/news/new-zoo-red-eyed-tree-frogs)
- `noaa_seal`：[NOAA Fisheries · Harbor Seal](https://www.fisheries.noaa.gov/species/harbor-seal)
- `hp_mooncalf`：[Harry Potter Official Encyclopedia · Mooncalf](https://www.harrypotter.com/fact-file/creatures/mooncalf)
- `hp_gillyweed`：[Harry Potter Official Encyclopedia · Gillyweed](https://www.harrypotter.com/fact-file/plants-and-potions/gillyweed)
- `hp_mandrake`：[Harry Potter Official Encyclopedia · Mandrake](https://www.harrypotter.com/fact-file/plants-and-potions/mandrake)
- `hp_bowtruckle`：[Harry Potter Official Encyclopedia · Bowtruckle](https://www.harrypotter.com/fact-file/creatures/bowtruckle)
- `hp_plants`：[Harry Potter Official · Wizarding Plants](https://www.harrypotter.com/features/harry-potter-101-wizarding-plants)
- `hp_moon`：[Harry Potter Official · The Importance of the Moon](https://www.harrypotter.com/features/the-importance-of-the-moon-in-the-wizarding-world)
