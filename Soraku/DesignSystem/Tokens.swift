import SwiftUI

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 14
    static let l: CGFloat = 22
    static let xl: CGFloat = 34
    static let xxl: CGFloat = 52
}

enum Radius {
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 26
    static let pill: CGFloat = 40
}

enum Durations {
    static let quick: Double = 0.22
    static let gentle: Double = 0.5
    static let slow: Double = 1.1
    static let breathe: Double = 3.4
}

extension Font {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .serif) }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .serif) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func numeric(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .rounded).monospacedDigit() }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

extension View {
    func breathingScale(active: Bool, reduced: Bool, amount: CGFloat = 0.04) -> some View {
        modifier(BreathingScale(active: active, reduced: reduced, amount: amount))
    }
}

private struct BreathingScale: ViewModifier {
    var active: Bool
    var reduced: Bool
    var amount: CGFloat
    @State private var pulse = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(reduced ? 1 : (pulse ? 1 + amount : 1 - amount * 0.4))
            .onAppear {
                guard active, !reduced else { return }
                withAnimation(.easeInOut(duration: Durations.breathe).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
