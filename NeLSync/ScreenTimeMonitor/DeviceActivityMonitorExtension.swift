import DeviceActivity
import ManagedSettings

class ScreenTimeMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        print("Event reached threshold: \(event)")
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        print("Monitoring interval ended for: \(activity)")
    }
}
