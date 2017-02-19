//
//  BTBeaconRegionMap.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 6/30/16.
//  Copyright © 2016 BrightSign, LLC. All rights reserved.
//

import UIKit
import CoreLocation

protocol BTBeaconProximityDataDelegate {
    func beaconProximityData(_ beaconData: BTBeaconProximityData, didChangeFilteredProximityTo newProximityFactor: CLProximity, from oldProximityFactor: CLProximity)

}

class BTBeaconProximityData: NSObject {
    
    weak var beacon: CLBeacon?
    
    var filteredProximityFactor : CLProximity = .unknown
    fileprivate var filteredProximityFarCount = 0
    fileprivate var filteredProximityUnknownCount = 0
    fileprivate var foundInLastScan = false
    
    var appId = "";
    
    var delegate:  BTBeaconProximityDataDelegate?
    
    init(appId: String) {
        super.init()
        self.appId = appId
    }
    
    func startUpdate() {
        foundInLastScan = false
    }
    
    let proximityLostCount = 10
    let proximityNearLostCount = 4
    
    func update(_ beacon: CLBeacon?) {
        self.beacon = beacon
        let oldProximity = filteredProximityFactor
        var proximityValue : CLProximity = .unknown
        //var proximityString = "Unknown"
        
        if let beacon = beacon {
            proximityValue = beacon.proximity
            if proximityValue == .near || proximityValue == .immediate {
                filteredProximityFactor = .near
                filteredProximityFarCount = 0
                filteredProximityUnknownCount = 0
                //proximityString = "Near"
            } else if proximityValue == .far {
                filteredProximityFarCount += 1
                filteredProximityUnknownCount = 0
                
                if filteredProximityFactor == .unknown || filteredProximityFarCount > proximityNearLostCount {
                    filteredProximityFactor = .far
                    //proximityString = "Far"
                }
            }
        }
        if proximityValue == .unknown {
            filteredProximityUnknownCount += 1
            filteredProximityFarCount += 1
            
            if filteredProximityUnknownCount > proximityLostCount {
                filteredProximityFactor = .unknown
            }
        }
        if oldProximity != filteredProximityFactor {
            //BBTLog.write("Changing filtered proximity factor for %@ to %@", appId, proximityString)
            delegate?.beaconProximityData(self, didChangeFilteredProximityTo: filteredProximityFactor, from: oldProximity)
        }
        foundInLastScan = true
    }
    
    func finishUpdate() {
        if !foundInLastScan {
            update(nil)
        }
    }
}

class BTBeaconRegionMap: NSObject {
    
    var proximityDataByAppId: [String:BTBeaconProximityData] = [:]
    var activeBeacons: [CLBeacon] = []
    
    var closestBeacon: BTBeaconProximityData? {
        if activeBeacons.count > 0 {
            return proximityDataByAppId[activeBeacons[0].appId]
        }
        return nil
    }
    
    var closestBeaconAppId: String? {
        if activeBeacons.count > 0 {
            return activeBeacons[0].appId
        }
        return nil
    }
    
    func update(_ regionBeacons: [CLBeacon]) {
        activeBeacons = regionBeacons
        for (_, proximityData) in proximityDataByAppId {
            proximityData.startUpdate()
        }
        for beacon in regionBeacons {
            let appId = beacon.appId
            var proximityData = proximityDataByAppId[appId]
            if (proximityData == nil) {
                proximityData = BTBeaconProximityData(appId: appId)
                proximityDataByAppId[appId] = proximityData
            }
            proximityData!.update(beacon)
        }
        for (_, proximityData) in proximityDataByAppId {
            proximityData.finishUpdate()
        }
    }
    
    func reset() {
        activeBeacons = []
        proximityDataByAppId = [:]
    }

}
