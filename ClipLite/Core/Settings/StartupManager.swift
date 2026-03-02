import Foundation
import ServiceManagement

enum StartupManagerError: Error {
    case registrationFailed(String)
}

final class StartupManager {
    func setLaunchAtLogin(enabled: Bool) throws {
        if enabled {
            do {
                try SMAppService.mainApp.register()
                Logger.info("Launch at login registered")
            } catch {
                throw StartupManagerError.registrationFailed("register failed: \(error)")
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
                Logger.info("Launch at login unregistered")
            } catch {
                throw StartupManagerError.registrationFailed("unregister failed: \(error)")
            }
        }
    }
}
