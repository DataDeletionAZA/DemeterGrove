import Foundation

final class PetController {
    func openTool(_ name: String) { }
    func show() { }
    func hide() { }
    func closeMenu() { }
}

enum PetMotion: Int {
    case dragRight = 10, dragLeft = 11, landing = 21, jumping = 22, resting = 31
    var duration: Double { 0.1 }
}

enum PetLook {
    static func direction(point: CGPoint, size: CGSize) -> Int? { nil }
}
