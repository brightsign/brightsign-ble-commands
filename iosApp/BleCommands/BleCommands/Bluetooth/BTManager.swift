//
//  BTManager.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 1/6/16.
//  Copyright © 2016 BrightSign, LLC. All rights reserved.
//

import UIKit
import CoreLocation
import CoreBluetooth

protocol BTManagerDelegate {
    func didChangeActivePeripheral(_ btBspPeripheral: BTBspPeripheral?)
}

class BTManager: NSObject, BTBeaconManagerDelegate, BTCentralManagerDelegate {
    
    // Singleton
    static let sharedInstance = BTManager()
    
    var delegate:  BTManagerDelegate?
    
    let beaconManager = BTBeaconManager()
    let centralManager = BTCentralManager()
    
    var isInRegion = false
    var isPeripheralSessionActive = false

    override init() {
        super.init()
        beaconManager.delegate = self
        centralManager.delegate = self
    }
    
    func prepareForBackground() {
        BBTLog.write("Preparing for background")
        centralManager.prepareForBackground()
//        centralManager.stopScanningForPeripherals()
    }
    
    func prepareForForeground() {
        BBTLog.write("Preparing for foreground")
//        if isInRegion {
//            centralManager.startScanningForPeripherals();
//        }
        centralManager.prepareForForeground()
    }
    
    // Start monitoring for specified beacon regions
    func startBeaconMonitoring(_ identifier: String) {
        beaconManager.startBeaconMonitoring(identifier)
    }
    
    func stopBeaconMonitoring(_ identifier: String) {
        beaconManager.stopBeaconMonitoring(identifier)
    }
    
    // Start monitoring for default beacon region
    func startDefaultBeaconMonitoring() {
        beaconManager.startBeaconMonitoring(BTBeaconManager.bsIdentifier)
    }
    
    func stopDefaultBeaconMonitoring() {
        beaconManager.stopBeaconMonitoring(BTBeaconManager.bsIdentifier)
    }
    
    // MARK: - Beacon manager delegate
    
    func beaconManager(_ manager: BTBeaconManager, didEnterRegion beaconRegion: CLBeaconRegion)
    {
        var notification : UILocalNotification?

        if !beaconManager.isRangingForRegion(beaconRegion) {
            beaconManager.startRangingForRegion(beaconRegion)
            // Display notification here only if app is in background
            if UIApplication.shared.applicationState != .active {
                notification = UILocalNotification()
                notification!.alertBody = "Welcome to BrightSign"
            }
        }
        isInRegion = true
        
        // Display the notification to the user if necessary
        if let notification = notification {
            UIApplication.shared.presentLocalNotificationNow(notification)
        }
    }
    
    func beaconManager(_ manager: BTBeaconManager, didExitRegion beaconRegion: CLBeaconRegion)
    {
        BBTLog.write("Exiting region %@", beaconRegion.identifier)
        beaconManager.stopRangingForRegion(beaconRegion)
        isInRegion = false
    }
    
    func beaconManager(_ manager: BTBeaconManager, didUpdateBeaconRegionMap identifier: String)
    {
//        if let regionMap = manager.getBeaconRegionMap(identifier) {
//            centralManager.updateForBeaconRegionMap(regionMap)
//        }
    }
    
    // MARK: - Central manager control
    
    func startScanningForPeripherals() {
        centralManager.startScanningForPeripherals()
    }
    
    func stopScanningForPeripherals() {
        centralManager.stopScanningForPeripherals()
    }
    
    func startSessionWithClosestPeripheral() -> Bool {
        if let bsPeripheral = centralManager.closestPeripheral {
            return centralManager.startSession(with: bsPeripheral)
        }
        return false
    }
    
    func stopPeripheralSession() {
        centralManager.stopSession()
    }
    
    func sendCommandToActivePeripheral(_ command: String) {
        centralManager.sendCommandToActivePeripheral(command)
    }
    
    // MARK: - Central manager delegate
    
    func centralManager(_ manager:BTCentralManager, willConnectToPeripheral btBspPeripheral:BTBspPeripheral)
    {
    }
    
    func centralManager(_ manager:BTCentralManager, didDisconnectFromPeripheral btBspPeripheral:BTBspPeripheral)
    {
    }
    
    func centralManager(_ manager:BTCentralManager, didChangeActivePeripheral btBspPeripheral: BTBspPeripheral?)
    {
        isPeripheralSessionActive = btBspPeripheral != nil
        delegate?.didChangeActivePeripheral(btBspPeripheral)
    }
}
