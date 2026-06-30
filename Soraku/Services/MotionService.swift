import Foundation
import CoreMotion
import Observation

@MainActor
@Observable
final class MotionService {
    private(set) var tilt: Double = 0
    private(set) var rawRoll: Double = 0
    private(set) var available: Bool = false

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var simulatedTilt: Double = 0
    @ObservationIgnored var sensitivity: Double = 0.5

    func start() {
        guard manager.isDeviceMotionAvailable else {
            available = false
            return
        }
        available = true
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let roll = motion.attitude.roll
            let pitch = motion.attitude.pitch
            self.rawRoll = roll
            let magnitude = min(1.0, (abs(roll) + abs(pitch) * 0.5) / (0.9 - self.sensitivity * 0.55))
            self.tilt = max(self.simulatedTilt, magnitude)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        simulatedTilt = 0
        tilt = 0
    }

    func applySimulatedTilt(_ value: Double) {
        simulatedTilt = max(0, min(1, value))
        tilt = max(tilt, simulatedTilt)
        if !available { tilt = simulatedTilt }
    }
}
