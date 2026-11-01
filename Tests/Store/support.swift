import Foundation

final class PetController {
    func openTool(_ name: String) { }
    func show() { }
    func hide() { }
    func closeMenu() { }
}

enum PetMotion: Int {
    case dragRight = 10, dragLeft = 11, waving = 20, landing = 21, jumping = 22, failed = 23, resting = 31
    var duration: Double {
        switch self {
        case .waving: return 1.35
        case .landing: return 0.55
        case .jumping: return 1.15
        case .failed: return 1.8
        default: return 3.2
        }
    }
}

enum PetLook {
    static func direction(point: CGPoint, size: CGSize) -> Int? { nil }
}
