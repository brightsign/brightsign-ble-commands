//
//  BTCentralManager.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 2/16/16.
//  Copyright © 2016 BrightSign, LLC. All rights reserved.
//

import UIKit
import CoreLocation
import CoreBluetooth

protocol BTCentralManagerDelegate {
    func centralManager(_ manager:BTCentralManager, willConnectToPeripheral btBspPeripheral:BTBspPeripheral)
    func centralManager(_ manager:BTCentralManager, didDisconnectFromPeripheral btBspPeripheral:BTBspPeripheral)
    func centralManager(_ manager:BTCentralManager, didChangeActivePeripheral btBspPeripheral: BTBspPeripheral?)
}

class BTCentralManager: NSObject, CBCentralManagerDelegate {

    // Singleton
    static let sharedInstance = BTBeaconManager()
    
    fileprivate var centralManager: CBCentralManager?
    
    fileprivate var peripheralScanEnabled = false
    
    fileprivate var bsPeripherals: [UUID:BTBspPeripheral] = [:]
    fileprivate var bsPeripheralsByAppId: [String:BTBspPeripheral] = [:]
    fileprivate var bsPeripheralsByDistance : [UUID] = []
    
    var btDeviceIdString : String? = UserDefaults.standard.object(forKey: "btDeviceIdentifier") as? String
    
    var activePeripheral: BTBspPeripheral?
    var closestPeripheral: BTBspPeripheral?
    
    var activePeripheralLocked = false
    
    var delegate: BTCentralManagerDelegate?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        if btDeviceIdString == nil {
            btDeviceIdString = UUID().uuidString;
            UserDefaults.standard.set(btDeviceIdString, forKey: "btDeviceIdentifier")
            UserDefaults.standard.synchronize()
        }
    }
    
    func reset() {
        bsPeripherals = [:]
        bsPeripheralsByAppId = [:]
        bsPeripheralsByDistance = []
        activePeripheral = nil
    }
    
    func prepareForBackground() {
        stopCheckingBspPeripheralSession()
        activePeripheral?.closeSession()
        for (_, bsPeripheral) in bsPeripheralsByAppId {
            bsPeripheral.prepareForBackground()
        }
        activePeripheral = nil
        delegate?.centralManager(self, didChangeActivePeripheral:nil)
        
        stopScanningForPeripherals()
    }
    
    func prepareForForeground() {
        reset()
        startScanningForPeripherals()
        if peripheralScanEnabled {
            startCheckingBspPeripheralSession()
        }
    }
    
    func peripheralForAppId(_ appId: String) -> BTBspPeripheral?
    {
        return bsPeripheralsByAppId[appId]
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if centralManager?.state == .poweredOn {
            if peripheralScanEnabled {
                startScanningForPeripherals()
            }
        } else {
            reset()
        }
    }
    
    func connect(_ btBspPeripheral: BTBspPeripheral) {
        delegate?.centralManager(self, willConnectToPeripheral:btBspPeripheral)
        let options = [ CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true ];
        centralManager!.connect(btBspPeripheral.peripheral, options: options)
        BBTLog.write("Connecting peripheral: %@", btBspPeripheral.name)
    }
    
    func disconnect(_ btBspPeripheral: BTBspPeripheral) {
        centralManager!.cancelPeripheralConnection(btBspPeripheral.peripheral)
        BBTLog.write("Disconnecting peripheral: %@", btBspPeripheral.name)
    }
    
    func cancelConnection(_ btBspPeripheral: BTBspPeripheral) {
        centralManager!.cancelPeripheralConnection(btBspPeripheral.peripheral)
    }
    
    private var logNextUpdate = false
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let btpExisting = bsPeripherals[peripheral.identifier] {
            btpExisting.rssi = RSSI.intValue
            btpExisting.updateStatus(adData: advertisementData as [String : AnyObject])
            let busyStr = btpExisting.isBusy ? "YES" : "NO"
            if logNextUpdate {
                BBTLog.write("Updated peripheral (%@), appId: %@, busy: %@, txp: %d, rssi: %@", btpExisting.peripheral.identifier.uuidString, btpExisting.appId, busyStr, btpExisting.txPower, RSSI);
                logNextUpdate = false
            }
            if peripheral != btpExisting.peripheral {
                BBTLog.write(" !!!!!!!! Peripheral object mismatch after update")
            }
        } else {
            let btp = BTBspPeripheral(peripheral: peripheral, manager: self, adData: advertisementData as [String : AnyObject])
            btp.rssi = RSSI.intValue
            bsPeripherals[peripheral.identifier] = btp
            if bsPeripheralsByAppId[btp.appId] == nil {
                bsPeripheralsByAppId[btp.appId] = btp
            }
            let busyStr = btp.isBusy ? "YES" : "NO"
            BBTLog.write("Add peripheral (%@), appId: %@, busy: %@, txp: %d, rssi: %@", btp.peripheral.identifier.uuidString, btp.appId, busyStr, btp.txPower, RSSI);
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let btp = bsPeripherals[peripheral.identifier] {
            btp.didConnect()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logNextUpdate = true
        if let btp = bsPeripherals[peripheral.identifier] {
            btp.didDisconnect()
        }
        processDisconnect(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        BBTLog.write("Failed to connect to peripheral")
        if let btp = bsPeripherals[peripheral.identifier] {
            btp.didfailToConnect()
        }
        processDisconnect(peripheral)
    }
    
    fileprivate func processDisconnect(_ peripheral: CBPeripheral) {
        if let btp = bsPeripherals[peripheral.identifier] {
            delegate?.centralManager(self, didDisconnectFromPeripheral:btp)
        }
    }
    
    func startScanningForPeripherals() {
        if centralManager?.state == .poweredOn {
            peripheralScanEnabled = true
            centralManager?.scanForPeripherals(withServices: [BTBspPeripheral.bsBspServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
            BBTLog.write("Starting scan for peripherals")
            startCheckingBspPeripheralSession()
        } else if !peripheralScanEnabled {
            // Wait for status to come back, then start
            peripheralScanEnabled = true
        } else {
            BBTLog.write("Bluetooth disabled, cannot scan for peripherals")
        }
    }
    
    func stopScanningForPeripherals() {
        BBTLog.write("Stopping scan for peripherals")
        stopCheckingBspPeripheralSession()
        centralManager?.stopScan()
        peripheralScanEnabled = false
    }
    
    func startSession(with bsPeripheral: BTBspPeripheral) -> Bool {
        if activePeripheral == nil && !bsPeripheral.isBusy && !bsPeripheral.lostScanContact {
            self.activePeripheral = bsPeripheral
            
            // Inform delegate - delegate may update peripheral state before we activate the session
            BBTLog.write("Setting active peripheral to: %@", bsPeripheral.peripheral.identifier.uuidString)
            delegate?.centralManager(self, didChangeActivePeripheral:self.activePeripheral)
            
            self.activePeripheral?.activateSession()
            return true
        }
        return false
    }

    func stopSession() {
        if let activePeripheral = activePeripheral {
            self.activePeripheral = nil
            
            BBTLog.write("Setting active peripheral to: nil")
            delegate?.centralManager(self, didChangeActivePeripheral:nil)
            
            activePeripheral.closeSession()
        }
    }
    
    func sendCommandToActivePeripheral(_ command: String) {
        if let activePeripheral = activePeripheral {
            activePeripheral.sendCommand(command)
        }
    }
    
    var sessionCheck : DispatchWorkItem?
    fileprivate func startCheckingBspPeripheralSession() {
        let delay = DispatchTime.now() + .seconds(1)
        sessionCheck = DispatchWorkItem { self.checkBspPepripheralSession() }
        DispatchQueue.main.asyncAfter(deadline: delay, execute: sessionCheck!)
    }
    
    fileprivate func stopCheckingBspPeripheralSession() {
        if let sessionCheck = sessionCheck {
            sessionCheck.cancel()
            self.sessionCheck = nil
        }
    }
    
    fileprivate func sortPeripheralsByDistance() {
        var idArray : [UUID] = Array(bsPeripherals.keys)
        idArray.sort {
            return bsPeripherals[$0]!.distance < bsPeripherals[$1]!.distance
        }
        bsPeripheralsByDistance = idArray
    }
    
    fileprivate func checkBspPepripheralSession() {
        // Do not check for session if app is not active
        if UIApplication.shared.applicationState == .active {
            if let activePeripheral = activePeripheral {
                if activePeripheral.lostScanContact {
                    BBTLog.write("Resetting active peripheral")
                    activePeripheral.closeSession()
                    delegate?.centralManager(self, didChangeActivePeripheral:nil)
                    self.activePeripheral = nil
                }
            }
            // Check for peripheral device removal from our list (for devices out of range > 30 seconds)
            var peripheralIdsToRemove : [UUID] = []
            for (id, bsPeripheral) in bsPeripherals {
                if bsPeripheral.removeDevice {
                    peripheralIdsToRemove.append(id)
                }
            }
            for id in peripheralIdsToRemove {
                if let bsPeripheral = bsPeripherals[id] {
                    bsPeripheral.prepareForRemoval()
                    BBTLog.write("Removing peripheral, appId: %@", bsPeripheral.appId)
                    bsPeripheralsByAppId.removeValue(forKey: bsPeripheral.appId)
                    bsPeripherals.removeValue(forKey: id)
                }
            }
            sortPeripheralsByDistance()
            self.closestPeripheral = nil
            if bsPeripheralsByDistance.count > 0 {
                for (id, bsPeripheral) in bsPeripherals {
                    if bsPeripheralsByDistance[0] == id {
                        bsPeripheral.isClosestPeripheral = true
                        self.closestPeripheral = bsPeripheral
                    } else {
                        bsPeripheral.isClosestPeripheral = false
                    }
                }
            }
        }
        // Schedule next check
        startCheckingBspPeripheralSession()
    }
}
