//
//  BTBeaconManager.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 2/22/16.
//  Copyright © 2016 BrightSign, LLC. All rights reserved.
//

import UIKit
import CoreLocation

protocol BTBeaconManagerDelegate {
    func beaconManager(_ manager: BTBeaconManager, didEnterRegion beaconRegion: CLBeaconRegion)
    func beaconManager(_ manager: BTBeaconManager, didExitRegion beaconRegion: CLBeaconRegion)
    func beaconManager(_ manager: BTBeaconManager, didUpdateBeaconRegionMap identifier: String)
}

extension CLBeacon
{
    var appId: String {
        let major = self.major.uint16Value;
        let minor = self.minor.uint16Value;
        return BTBeaconManager.getAppId(major, minor)
    }
}

class BTBeaconManager: NSObject, CLLocationManagerDelegate {

    static let bsIdentifier = "BrightSign"
    static let bsLocationUUID = UUID(uuidString: "BE760858-9DE9-4685-BDD2-C75A1EF15DC8")!
    
    fileprivate var locationManager: CLLocationManager?
    
    fileprivate var beaconRegionsById: [String:CLBeaconRegion] = [:]
    fileprivate var rangedRegions: [CLBeaconRegion] = []
    fileprivate var beaconRegionMaps: [String:BTBeaconRegionMap] = [:]
    
    var currentBeaconRegionId: String?
    
    static func getAppId(_ major: CLBeaconMajorValue, _ minor: CLBeaconMinorValue) -> String {
        let a = (major >> 8) & 0xFF
        let b = major & 0xFF
        let c = (minor >> 8) & 0xFF
        let d = minor & 0xFF
        return String(format:"%02x%02x%02x%02x",a,b,c,d)
    }

    var delegate:  BTBeaconManagerDelegate?
    
    override init() {
        super.init()
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestAlwaysAuthorization()
        
        // Add default beacon region (BrightSign)
        beaconRegionsById[BTBeaconManager.bsIdentifier] = CLBeaconRegion(proximityUUID: BTBeaconManager.bsLocationUUID, identifier: BTBeaconManager.bsIdentifier)
    }
    
    func prepareForBackground() {
    }
    
    // Allow addition of other beacon regions to monitor
    func addBeaconRegion(_ identifier: String, proximityID: UUID, major: CLBeaconMajorValue?, minor: CLBeaconMinorValue?) {
        if let major = major, let minor = minor {
            beaconRegionsById[identifier] = CLBeaconRegion(proximityUUID: proximityID, major: major, minor: minor, identifier: identifier)
        } else if let major = major {
            beaconRegionsById[identifier] = CLBeaconRegion(proximityUUID: proximityID, major: major, identifier: identifier)
        } else {
            beaconRegionsById[identifier] = CLBeaconRegion(proximityUUID: proximityID, identifier: identifier)
        }
    }
    
    func deleteBeaconRegion(_ identifier: String) {
        beaconRegionsById[identifier] = nil
    }
    
    func getBeaconRegion(_ identifier: String) -> CLBeaconRegion? {
        return beaconRegionsById[identifier]
    }
    
    func startBeaconNotification(_ identifier: String, message: String) {
        // We can set a given region for notifications or monitoring, but not both
        stopBeaconMonitoring(identifier)
        
        if let beaconRegion = beaconRegionsById[identifier] {
            let notification = UILocalNotification()
            notification.alertBody = message
            notification.soundName = UILocalNotificationDefaultSoundName
            beaconRegion.notifyOnEntry = true
            beaconRegion.notifyOnExit = false
            beaconRegion.notifyEntryStateOnDisplay = true
            notification.region = beaconRegion
            notification.regionTriggersOnce = false
            BBTLog.write("Starting notification for region: %@", identifier)
            UIApplication.shared.scheduleLocalNotification(notification);
        }
    }
    
    func stopBeaconNotification(_ identifier: String) {
        if let scheduledNotifications = UIApplication.shared.scheduledLocalNotifications {
            for notification in scheduledNotifications {
                if let br = notification.region as? CLBeaconRegion, br.identifier == identifier {
                    BBTLog.write("Stopping notification for region: %@", br.identifier)
                    UIApplication.shared.cancelLocalNotification(notification)
                }
            }
        }
    }
    
    func startBeaconMonitoring(_ identifier: String) {
        // We can set a given region for notifications or monitoring, but not both
        stopBeaconNotification(identifier)
        if let locMgr = locationManager,
            let beaconRegion = beaconRegionsById[identifier]
        {
            beaconRegion.notifyOnEntry = true
            beaconRegion.notifyOnExit = true
            beaconRegion.notifyEntryStateOnDisplay = false
            BBTLog.write("Starting monitoring for region: %@", identifier)
            locMgr.startMonitoring(for: beaconRegion)
            currentBeaconRegionId = identifier
        }
    }
    
    func stopBeaconMonitoring(_ identifier: String) {
        if let locMgr = locationManager
        {
            for region in locMgr.monitoredRegions {
                if let br = region as? CLBeaconRegion, br.identifier == identifier {
                    BBTLog.write("Stopping monitoring for region: %@", region.identifier)
                    locMgr.stopMonitoring(for: region)
                    currentBeaconRegionId = nil
                    break;
                }
            }
        }
    }
    
    func stopAllBeaconMonitoring() {
        if let locMgr = locationManager {
            for region in locMgr.monitoredRegions {
                BBTLog.write("Stopping monitoring for region: %@", region.identifier)
                locMgr.stopMonitoring(for: region)
            }
        }
    }
    
    func startRangingForRegion(_ beaconRegion: CLBeaconRegion) {
        stopRangingForRegion(beaconRegion)
        if let locMgr = locationManager {
            BBTLog.write("Starting ranging for region: %@", beaconRegion.identifier)
            locMgr.startRangingBeacons(in: beaconRegion)
            rangedRegions.append(beaconRegion)
        }
    }
    
    // Return true if region was active and is now stopped
    func stopRangingForRegion(_ beaconRegion: CLBeaconRegion) {
        if let locMgr = locationManager {
            for region in rangedRegions {
                if beaconRegion.identifier == region.identifier {
                    BBTLog.write("Stopped ranging for region: %@", beaconRegion.identifier)
                    locMgr.stopRangingBeacons(in: region)
                    if let index = rangedRegions.index(of: region) {
                        rangedRegions.remove(at: index)
                    }
                }
            }
        }
    }
    
    func isRangingForRegion(_ beaconRegion: CLBeaconRegion) -> Bool {
        for region in rangedRegions {
            if beaconRegion.identifier == region.identifier {
                return true
            }
        }
        return false
    }
    
    func isRangingForCurrentRegion() -> Bool {
        if let regionId = currentBeaconRegionId,
            let beaconRegion = beaconRegionsById[regionId]
        {
            return isRangingForRegion(beaconRegion)
        }
        return false
    }
    
    func startRangingForBeaconRegion(_ identifier: String?) {
        if let identifier = identifier, let beaconRegion = beaconRegionsById[identifier] {
            startRangingForRegion(beaconRegion)
        }
    }
    
    func stopRangingForBeaconRegion(_ identifier: String?) {
        if let identifier = identifier, let beaconRegion = beaconRegionsById[identifier] {
            stopRangingForRegion(beaconRegion)
        }
    }
    
    func startRangingForCurrentBeaconRegion() {
        startRangingForBeaconRegion(currentBeaconRegionId)
    }
    
    func stopRangingForCurrentBeaconRegion() {
        stopRangingForBeaconRegion(currentBeaconRegionId)
    }
    
    func getBeaconRegionMap(_ identifier: String) -> BTBeaconRegionMap? {
        return beaconRegionMaps[identifier]
    }
    
    func updateBeaconRegionMap(_ identifier: String, beacons: [CLBeacon]) -> BTBeaconRegionMap {
        if beaconRegionMaps[identifier] == nil {
            beaconRegionMaps[identifier] = BTBeaconRegionMap()
        }
        beaconRegionMaps[identifier]!.update(beacons)
        return beaconRegionMaps[identifier]!
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        // A user can transition in or out of a region while the application is not running. When this happens CoreLocation will launch the application momentarily, call this delegate method and we will let the user know via a local notification.        
        if let br = region as? CLBeaconRegion {
            if state == .inside {
                delegate?.beaconManager(self, didEnterRegion: br)
            } else if state == .outside {
                beaconRegionMaps[br.identifier]?.reset()
                delegate?.beaconManager(self, didExitRegion: br)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in beaconRegion: CLBeaconRegion) {
        delegate?.beaconManager(self, didUpdateBeaconRegionMap: beaconRegion.identifier)
        
        let regionMap = updateBeaconRegionMap(beaconRegion.identifier, beacons: beacons)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "updateBeaconRegionMap"), object: self, userInfo: ["map": regionMap])
    }
}
