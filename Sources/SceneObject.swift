import SwiftUI

enum SceneObject: CaseIterable {
    case farmDoor, kitchenDoor, studyDoor, shopDoor, signpost, shopExit, gardenExit, forestExit
    case taskMemo, calendar, diary, hourglass, habitBook, recipeBook, cookingCounter
    case plotOne, plotTwo, plotThree, plotFour, plotFive, plotSix

    static let gardenPlots: [SceneObject] = [.plotOne, .plotTwo, .plotThree, .plotFour, .plotFive, .plotSix]

    var room: String {
        switch self {
        case .farmDoor, .kitchenDoor, .studyDoor, .shopDoor, .signpost: return "Courtyard"
        case .taskMemo, .calendar, .diary, .hourglass, .habitBook: return "Study"
        case .recipeBook, .cookingCounter: return "Kitchen"
        case .shopExit: return "Shop"
        case .gardenExit: return "Garden"
        case .forestExit: return "Forest"
        case .plotOne, .plotTwo, .plotThree, .plotFour, .plotFive, .plotSix: return "Garden"
        }
    }

    var target: (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        switch self {
        case .gardenExit: return (0.50,0.16,0.10,0.24)
        case .forestExit: return (0.50,0.29,0.18,0.28)
        case .shopExit: return (0.91,0.34,0.16,0.52)
        case .farmDoor: return (0.211, 0.52, 0.07, 0.18)
        case .kitchenDoor: return (0.406, 0.52, 0.07, 0.18)
        case .studyDoor: return (0.626, 0.52, 0.07, 0.18)
        case .shopDoor: return (0.806, 0.52, 0.07, 0.18)
        case .signpost: return (0.91, 0.79, 0.12, 0.12)
        case .taskMemo: return (0.253, 0.647, 0.23, 0.17)
        case .calendar: return (0.257, 0.30, 0.13, 0.22)
        case .diary: return (0.51, 0.661, 0.18, 0.17)
        case .hourglass: return (0.737, 0.586, 0.12, 0.25)
        case .habitBook: return (0.833, 0.306, 0.12, 0.17)
        case .recipeBook: return (0.15, 0.62, 0.24, 0.26)
        case .cookingCounter: return (0.86, 0.54, 0.22, 0.30)
        case .plotOne: return (0.261, 0.434, 0.21, 0.20)
        case .plotTwo: return (0.503, 0.434, 0.21, 0.20)
        case .plotThree: return (0.743, 0.434, 0.21, 0.20)
        case .plotFour: return (0.242, 0.653, 0.21, 0.20)
        case .plotFive: return (0.505, 0.653, 0.21, 0.20)
        case .plotSix: return (0.767, 0.653, 0.21, 0.20)
        }
    }

    var outline: Path {
        let points: [(CGFloat, CGFloat)]
        switch self {
        case .gardenExit:
            points = [(702,264),(702,79),(724,46),(770,24),(812,47),(835,83),(835,264)]
        case .forestExit:
            points = [(632,432),(637,287),(650,241),(683,205),(726,187),(770,186),(814,202),(845,235),(863,281),(870,432)]
        case .shopExit:
            points = [(1268,588),(1268,252),(1275,198),(1298,157),(1333,132),(1375,124),(1420,138),(1452,168),(1473,210),(1473,588)]
        case .farmDoor:
            points = [(269,617),(269,494),(273,474),(283,459),(299,448),(318,443),(335,445),(352,454),(365,471),(372,491),(372,617)]
        case .kitchenDoor:
            points = [(584,613),(584,511),(589,493),(598,480),(612,470),(629,466),(647,471),(660,483),(670,502),(671,613)]
        case .studyDoor:
            points = [(912,613),(912,493),(918,475),(931,461),(947,454),(966,453),(984,460),(998,475),(1008,495),(1008,613)]
        case .shopDoor:
            points = [(1194,628),(1194,508),(1200,489),(1212,475),(1228,468),(1247,468),(1264,477),(1275,491),(1281,509),(1281,628)]
        case .signpost:
            points = [(1304,782),(1350,752),(1479,783),(1479,852),(1409,840),(1409,925),(1384,925),(1381,835),(1321,820)]
        case .taskMemo:
            points = [(216,706),(298,589),(483,598),(536,576),(567,568),(562,590),(522,627),(495,662),(496,708),(459,718),(447,741),(215,737)]
        case .calendar:
            points = [(300,201),(491,201),(495,231),(487,410),(303,410),(297,395),(309,234)]
        case .diary:
            points = [(651,735),(673,612),(692,596),(854,596),(869,606),(895,710),(900,748),(879,755),(669,755)]
        case .hourglass:
            points = [(1061,490),(1083,480),(1177,480),(1205,491),(1203,512),(1187,521),(1187,666),(1205,682),(1205,707),(1183,719),(1080,719),(1055,707),(1055,684),(1071,670),(1071,523),(1062,516)]
        case .habitBook:
            points = [(1196,384),(1218,245),(1228,236),(1355,238),(1368,249),(1359,303),(1361,335),(1349,389),(1339,400),(1207,399)]
        case .recipeBook:
            points = [(61,588),(86,570),(217,556),(241,543),(354,535),(378,543),(439,704),(432,720),(281,745),(251,738),(100,757),(88,738)]
        case .cookingCounter:
            points = [(1205,464),(1230,447),(1404,447),(1458,467),(1458,663),(1480,683),(1435,696),(1220,680),(1198,662)]
        case .plotOne:
            points = [(270,359),(545,359),(562,377),(557,423),(565,443),(558,481),(568,509),(547,528),(267,528),(240,512),(246,461),(257,411),(260,380)]
        case .plotTwo:
            points = [(643,358),(899,358),(922,376),(928,418),(925,451),(935,478),(932,515),(911,530),(634,528),(610,507),(615,463),(611,410),(615,381)]
        case .plotThree:
            points = [(1006,360),(1261,357),(1285,376),(1287,417),(1301,451),(1299,495),(1307,514),(1281,532),(1018,530),(989,516),(985,470),(977,430),(982,389)]
        case .plotFour:
            points = [(229,575),(534,574),(551,589),(549,627),(557,654),(549,695),(551,748),(529,767),(204,762),(176,739),(182,691),(198,642),(203,604)]
        case .plotFive:
            points = [(635,575),(912,575),(930,591),(935,625),(945,650),(946,697),(953,741),(937,766),(621,766),(597,748),(601,697),(605,653),(602,617),(615,589)]
        case .plotSix:
            points = [(1021,575),(1299,575),(1318,593),(1329,634),(1348,665),(1354,705),(1371,742),(1355,761),(1040,768),(1009,748),(1003,708),(997,668),(992,630),(1001,594)]
        }
        return Path { path in
            path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
            path.closeSubpath()
        }
    }
}
