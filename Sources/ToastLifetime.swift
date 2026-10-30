import Foundation

struct ToastLifetime {
    var elapsed: TimeInterval = 0
    var hovered = false
    let duration: TimeInterval = 3.2
    mutating func advance(_ delta: TimeInterval) { if !hovered { elapsed += max(0,delta) } }
    var progress: Double { min(1,elapsed/duration) }
    var opacity: Double { hovered ? 1 : expired ? 0 : max(0,1-max(0,progress-0.55)/0.45) }
    var expired: Bool { !hovered && elapsed >= duration }
}
