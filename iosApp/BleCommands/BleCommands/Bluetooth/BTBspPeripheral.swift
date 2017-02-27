//
//  BTBspPeripheral.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 1/13/16.
//  Copyright © 2017 BrightSign, LLC. All rights reserved.
//

import UIKit
import CoreLocation
import CoreBluetooth
import Foundation

enum PeripheralProximity : String {
    case unknown = "u"
    case distant = "d"
    case far = "f"
    case near = "n"
}

class BTBspPeripheral: NSObject, CBPeripheralDelegate {
    
    // If you use this module to write your own customized app, you should generate a new unique ID for your app
    // This same ID must be set as the service ID in the BtlePlugin script that is part of the BrightSign presentation
    static let bsBspServiceUUID = CBUUID(string: "99A80B03-E9F7-4B19-B6B5-4FD18B22DC42")
    
    // The following GUIDs identify the characteristics used by the service
    // As long as you have a unique service ID (above,) these do not need to be changed
    static let bsClientIdCharUUID = CBUUID(string: "152013eb-406f-4598-8590-a86f76cb535c")
    static let bsUserDataCharUUID = CBUUID(string: "cf2186ff-e140-47b5-a18d-0b2ec79f8b98")
    static let bsCommandCharUUID = CBUUID(string: "3c0a1e45-4677-4f6e-8cbc-98e190840d30")
    static let bsPlayerInfoCharUUID = CBUUID(string: "a2011df6-1241-482f-99d5-a2d635a32436")
    static let bsPlayerDataCharUUID = CBUUID(string: "90b9776a-bc0f-4b35-8135-1848bc5eab1b")

    static let bsCharIdArray = [
        BTBspPeripheral.bsClientIdCharUUID,
        BTBspPeripheral.bsUserDataCharUUID,
        BTBspPeripheral.bsCommandCharUUID,
        BTBspPeripheral.bsPlayerInfoCharUUID,
        BTBspPeripheral.bsPlayerDataCharUUID
    ];
    
    // We calculate "proximity thresholds" to determine a general range for the device
    // For ease of determination, we compute these thresholds as RSSI values, based on the TxPower given
    //  for the transmitter in the service data
    let distanceNearThreshold = 3.0 //meters
    let distanceFarThreshold = 10.0 //meters

    weak var manager: BTCentralManager?
    var peripheral: CBPeripheral
    var adData : [String : AnyObject]
    var appId : String
    var txPower : Int
    
    private var averageRssi : Int
    var rssi : Int {
        get {
            return averageRssi
        }
        set (newRssi) {
            addRssiMeasurement(newRssi)
        }
    }
    var distance : Double {
        get {
            if averageRssi == 0 || txPower >= 0 {
                return -1.0
            }
            
            // See http://stackoverflow.com/questions/20416218/understanding-ibeacon-distancing
            let ratio = Double(averageRssi)/Double(txPower)
            if ratio < 1.0 {
                return pow(ratio, 10)
            }
            return 0.89976 * pow(ratio, 7.7095) + 0.111
        }
    }
    fileprivate var rssiNearThreshold = 0
    fileprivate var rssiFarThreshold = 0
    var proximity : PeripheralProximity = .unknown
    var lostScanContact = false
    var removeDevice = false
    
    struct BspStatus : OptionSet {
        var rawValue: UInt8
        
        static let busy = BspStatus(rawValue: 1 << 0)
    }
    var status : BspStatus = []
    var isBusy : Bool {
        get {
            return status.contains(.busy)
        }
    }
    
    var characteristics : [CBUUID:CBCharacteristic] = [:]
    fileprivate var characteristicsValid = false
    
    var isClosestPeripheral = false
    var sessionActive = false
    var sessionClosing = false
    var playerDataValid = false
    var playerInfoValid = false
    var userData : [String : String] = [:]
    var playerUserData : [String : String] = [:]
    var playerData : [String : Any] = [:]
    var playerInfo : [String : Any] = [:]
    
    var nextUpdate : DispatchWorkItem?
    var nextRssiRetrieval : DispatchWorkItem?
    var nextRssiCalculation : DispatchWorkItem?
    
    fileprivate var refreshUserData = false
    fileprivate var connectionInProgress = false
    
    fileprivate var outgoingCommandQueue : [String] = []
    
    var name : String {
        get { return peripheral.name != nil ? peripheral.name! : "unknown" }
    }
    
    fileprivate var commands : [(String,String)] = []
    var commandArray : [(String,String)] {
        get { return commands }
    }
    
    init(peripheral: CBPeripheral, manager: BTCentralManager, adData: [String : AnyObject]) {
        self.manager = manager
        self.peripheral = peripheral
        self.adData = adData
        self.txPower = 0
        self.averageRssi = 0
        
        if  let svcData = adData[CBAdvertisementDataServiceDataKey] as? [CBUUID:Data], svcData.count > 0,
            let dataValue = svcData[BTBspPeripheral.bsBspServiceUUID]
        {
            var data = dataValue
            if data.count > 5 {
                self.status.rawValue = data.removeLast()
            }
            if data.count > 4 {
                self.txPower = Int(Int8(bitPattern: data.removeLast()))
            }
            appId = data.hexString()
        } else {
            status.rawValue = 0
            appId = "0"
        }
        super.init()
        peripheral.delegate = self
        
        if self.txPower != 0 {
            self.rssiNearThreshold = getRssiThreshold(for: distanceNearThreshold)
            self.rssiFarThreshold = getRssiThreshold(for: distanceFarThreshold)
        }
        
        // Set up timed work item to calculate average RSSI once per second
        scheduleRssiCalculation()
    }
    
    fileprivate func getRssiThreshold(for distance: Double) -> Int {
        if distance <= 1.0 {
            return (Int)(pow(distance, 0.1) * Double(self.txPower) - 0.5)
        }
        // See http://stackoverflow.com/questions/20416218/understanding-ibeacon-distancing
        return (Int)(pow(((distance - 0.111) / 0.89976), 0.12971) * Double(self.txPower) - 0.5)
    }
    
    func updateStatus(adData: [String : AnyObject]) {
        if  let svcData = adData[CBAdvertisementDataServiceDataKey] as? [CBUUID:Data], svcData.count > 0,
            let data = svcData[BTBspPeripheral.bsBspServiceUUID]
        {
            if data.count > 5 {
                let lastStatus = status
                status.rawValue = data[5]
                if lastStatus.contains(.busy) != isBusy {
                    BBTLog.write("Peripheral status changed to %@, (%@)", isBusy ? "BUSY" : "NOT BUSY", peripheral.identifier.uuidString)
                    if !isBusy {
                        // Wait until busy flag clears to reset sessionClosing
                        // This flag can then be used to prevent display of a busy message after closing
                        sessionClosing = false
                    }
                }
            }
            if data.count > 4 {
                self.txPower = Int(Int8(bitPattern: data[4]))
            }
        }
    }
    
    fileprivate func cleanup() {
        characteristicsValid = false
        characteristics = [:]
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let btp = object as? BTBspPeripheral, (btp.peripheral.identifier == self.peripheral.identifier) {
            return true
        }
        return false
    }
    
    func prepareForBackground() {
        cancelUpdate()
        cancelRssiCalculation()
        
        if !sessionClosing {
            manager!.cancelConnection(self)
        }
   }
    
    func prepareForRemoval() {
        cancelUpdate()
        cancelRssiCalculation()
        manager!.cancelConnection(self)
    }
    
    func activateSession() {
        if  let manager = manager, !sessionActive {
            BBTLog.write("Starting session")
            sessionActive = true
            sessionClosing = false
            refreshUserData = true
            connectionInProgress = true
            // Start initial connection
            manager.connect(self)
        }
    }
    
    let closeCommand = "__close"
    func closeSession() {
        if sessionActive  && !sessionClosing {
            BBTLog.write("Closing session")
            cancelUpdate()
            refreshUserData = false
            sessionClosing = true
            sessionActive = false
            if connectionInProgress {
                doWriteCharacteristic(BTBspPeripheral.bsCommandCharUUID, string: closeCommand)
            }
            lostScanContact = false
            sendUpdateNotification()
        }
    }
    
    fileprivate func updateSession() {
        nextUpdate = nil
        if lostScanContact {
            if sessionActive {
                // Skip update but schedule another attempt
                scheduleUpdate(5000)
            }
        } else if sessionActive || sessionClosing {
            // Write client ID to keep session alive
            doWriteCharacteristic(BTBspPeripheral.bsClientIdCharUUID, string: manager!.btDeviceIdString!)
        }
    }
    
    fileprivate func scheduleUpdate(_ delay : Int) {
        if let nextUpdate = nextUpdate {
            nextUpdate.cancel()
        }
        if sessionActive || sessionClosing {
            //BBTLog.write("Set timer for session update")
            nextUpdate = DispatchWorkItem { self.updateSession() }
            let delay = DispatchTime.now() + .milliseconds(delay)
            DispatchQueue.main.asyncAfter(deadline: delay, execute: nextUpdate!)
        } else {
            nextUpdate = nil
        }
    }
    
    fileprivate func cancelUpdate() {
        if let nextUpdate = nextUpdate {
            nextUpdate.cancel()
        }
        nextUpdate = nil
    }
    
    func setUserDataValue(_ value: String, key: String) {
        userData[key] = value;
    }
    
    func deleteUserDataForKey(_ key: String) -> Bool {
        if let _ = userData.removeValue(forKey: key) {
            return true
        }
        return false
    }
    
    func sendCommand(_ command: String) {
        if sessionActive && !lostScanContact {
            doWriteCharacteristic(BTBspPeripheral.bsCommandCharUUID, string: command)
        }
    }
    
    func resetPlayerInfo() {
        playerInfoValid = false
        playerDataValid = false
    }

    fileprivate func updateUserData() {
        if sessionActive {
            if refreshUserData || !userData.elementsEqual(playerUserData, by: ==) {
                playerUserData = userData
                refreshUserData = false
                do {
                    let userVarData = try JSONSerialization.data(withJSONObject: playerUserData)
                    let userDataString = String(data: userVarData, encoding: String.Encoding.utf8)
                    doWriteCharacteristic(BTBspPeripheral.bsUserDataCharUUID, string: userDataString!)
                } catch let error {
                    BBTLog.write("Error queuing UserVar data: %@", error.localizedDescription)
                }
            }
        }
    }
    
    func didConnect() {
        peripheral.discoverServices([BTBspPeripheral.bsBspServiceUUID])
    }
    
    fileprivate func processConnection() {
        scheduleGetRssiWhileConnected()
        // identify this device
        BBTLog.write("didConnect")
        doWriteCharacteristic(BTBspPeripheral.bsClientIdCharUUID, string: manager!.btDeviceIdString!)
        if sessionActive {
            // update user variable structure
            updateUserData()
        }
    }
    
    func didDisconnect() {
        BBTLog.write("didDisconnect")
        cleanup()
        connectionInProgress = false
        sessionActive = false
    }
    
    func didfailToConnect() {
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let err = error {
            BBTLog.write("Error discovering services: %@", err.localizedDescription);
            cleanup()
        } else if let svcs = peripheral.services {
            for service in svcs {
                peripheral.discoverCharacteristics(BTBspPeripheral.bsCharIdArray, for: service)
            }
        } else {
            BBTLog.write("No services returned from discovery")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let err = error {
            BBTLog.write("Error discovering characteristics: %@", err.localizedDescription);
            cleanup()
        } else if let chars = service.characteristics {
            for char in chars {
                self.characteristics[char.uuid] = char
            }
            characteristicsValid = true
            processConnection()
        } else {
            BBTLog.write("No characteristics returned from discovery")
        }
    }
    
    fileprivate func doWriteCharacteristic(_ charUUID: CBUUID, string: String) {
        if let char = characteristics[charUUID],
            let data = string.data(using: String.Encoding.utf8)
        {
            BBTLog.write("--- Writing: '%@' to %@", string, charUUID.uuidString)
            peripheral.writeValue(data, for: char, type: CBCharacteristicWriteType.withResponse)
        } else {
            BBTLog.write("Could not write characteristic")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let err = error {
            BBTLog.write("Error writing value: %@", err.localizedDescription);
        } else {
            //BBTLog.write("Value write successful: %@", characteristic.uuid)
            // After writing the ClientId to let the player know who we are, read the user data
            if characteristic.uuid.isEqual(BTBspPeripheral.bsClientIdCharUUID) {
                if sessionActive {
                    if !playerInfoValid {
                        readCharacteristicData(BTBspPeripheral.bsPlayerInfoCharUUID)
                    }
                    if !playerDataValid {
                        readCharacteristicData(BTBspPeripheral.bsPlayerDataCharUUID)
                    }
                    readCharacteristicData(BTBspPeripheral.bsUserDataCharUUID)
                }
            }
        }
    }
    
    func readCharacteristicData(_ charUUID: CBUUID) {
        if let char = characteristics[charUUID] {
            BBTLog.write("Reading value for %@", charUUID)
            peripheral.readValue(for: char)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let err = error {
            BBTLog.write("Error reading value: %@", err.localizedDescription)
        } else if let data = characteristic.value,
            let str = String(data: data, encoding: String.Encoding.utf8)
        {
            if characteristic.uuid.isEqual(BTBspPeripheral.bsUserDataCharUUID) {
                BBTLog.write("User variable data updated, value = %@", str)
                processUserVarData(userVarData: data, error: error)
                scheduleUpdate(2000)
            } else if characteristic.uuid.isEqual(BTBspPeripheral.bsPlayerInfoCharUUID) {
                BBTLog.write("Player info updated, value = %@", str)
                processPlayerInfo(playerInfoData: data, error: error)
            } else if characteristic.uuid.isEqual(BTBspPeripheral.bsPlayerDataCharUUID) {
                BBTLog.write("Player data updated, value = %@", str)
                processPlayerData(playerData: data, error: error)
            } else {
                BBTLog.write("Data updated, value = &@, id = %@", str, characteristic.uuid.uuidString)
            }
        } else {
            BBTLog.write("Value read successful, but no value found")
        }
    }
    
    fileprivate func processUserVarData(userVarData: Data?, error: Error?) {
        if let error = error {
            BBTLog.write("Error reading UserVar data: %@", error.localizedDescription)
        } else if let data = userVarData {
            do {
                let userData = try JSONSerialization.jsonObject(with: data) as! [String:String]
                self.userData = userData
                //BBTLog.write("Updated UserVar data")
            } catch let error {
                BBTLog.write("Error parsing UserVar data: %@", error.localizedDescription)
            }
        }
    }
    
    fileprivate func processPlayerInfo(playerInfoData: Data?, error: Error?) {
        if let error = error {
            BBTLog.write("Error reading PlayerInfo data: %@", error.localizedDescription)
        } else if let data = playerInfoData {
            do {
                self.playerInfo = try JSONSerialization.jsonObject(with: data) as! [String:AnyObject]
                self.playerInfoValid = true
                //BBTLog.write("Updated PlayerInfo data")
            } catch let error {
                BBTLog.write("Error parsing PlayerInfo data: %@", error.localizedDescription)
            }
        }
    }
    
    fileprivate func processPlayerData(playerData: Data?, error: Error?) {
        if let error = error {
            BBTLog.write("Error reading PlayerData: %@", error.localizedDescription)
        } else if let data = playerData {
            do {
                self.playerData = try JSONSerialization.jsonObject(with: data) as! [String:AnyObject]
                self.playerDataValid = true
                parseCommandsFromPlayerData()
                //BBTLog.write("Updated PlayerData")
                sendDeviceDataUpdateNotification()
            } catch let error {
                BBTLog.write("Error parsing PlayerData: %@", error.localizedDescription)
            }
        }
    }
    
    fileprivate func parseCommandsFromPlayerData() {
        commands = []
        if let commandArray = playerData["cm"] as? [String] {
            let sep : Character = "|"
            for str in commandArray {
                if let idx = str.characters.index(of: sep) {
                    let label = str.substring(to: idx)
                    let value = str.substring(from: str.index(after: idx))
                    commands.append((label,value))
                } else if !str.isEmpty {
                    commands.append((str,str))
                }
            }
        }
    }
    
    fileprivate func sendUpdateNotification() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "updatePeripheralData"), object: self, userInfo: nil)
    }
    
    fileprivate func sendDeviceDataUpdateNotification() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "updateDeviceData"), object: self, userInfo: nil)
    }
    
    fileprivate func scheduleGetRssiWhileConnected() {
        nextRssiRetrieval = DispatchWorkItem {self.retrieveRssi()}
        let delay = DispatchTime.now() + .milliseconds(250)
        DispatchQueue.main.asyncAfter(deadline: delay, execute: nextRssiRetrieval!)
    }
    
    fileprivate func cancelRssiRetrieval() {
        if let nextRssiRetrieval = nextRssiRetrieval {
            nextRssiRetrieval.cancel()
        }
        nextRssiRetrieval = nil
    }
    
    fileprivate func retrieveRssi() {
        if connectionInProgress {
            peripheral.readRSSI()
            scheduleGetRssiWhileConnected()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error = error {
            BBTLog.write("Error reading RSSI data: %@ (%@)", error.localizedDescription, peripheral.identifier.uuidString)
        } else {
            addRssiMeasurement(RSSI.intValue)
        }
    }
    
    private var rssiMeasurements : [(rssi : Int, time : Date)] = []
    fileprivate func addRssiMeasurement(_ rssi: Int) {
        if averageRssi == 0 {
            averageRssi = rssi
        }
        objc_sync_enter(self);
        defer { objc_sync_exit(self) }
        rssiMeasurements.append((rssi,Date()));
    }
    
    fileprivate func scheduleRssiCalculation() {
        nextRssiCalculation = DispatchWorkItem {self.calculateAverageRssi()}
        let delay = DispatchTime.now() + .seconds(1)
        DispatchQueue.main.asyncAfter(deadline: delay, execute: nextRssiCalculation!)
    }
    
    fileprivate func cancelRssiCalculation() {
        if let nextRssiCalculation = nextRssiCalculation {
            nextRssiCalculation.cancel()
        }
        nextRssiCalculation = nil
    }
    
    // We keep all RSSI measurements and compute a running average to smooth out the inevitable noise
    // We drop the highest and lowest 10% of RSSI measurements
    //We average measurement over the most recent 8 seconds - older measrements are discarded
    let rssiAverageInterval : TimeInterval = 8;
    let lostContactThreshold : Int = 5;
    let deviceRemovalThreshold : Int = 30;
    private var lostContactCounter = 0
    private var deviceRemovalCounter = 30
    fileprivate func calculateAverageRssi() {
        if UIApplication.shared.applicationState == .active {
            // Filter out all measurements older than the start of the current averaging interval
            let startTime = Date(timeIntervalSinceNow: -rssiAverageInterval)
            
            var newRssiMeasurements : [(rssi : Int, time : Date)] = []
            do {
                objc_sync_enter(self);
                defer { objc_sync_exit(self) }
                newRssiMeasurements = rssiMeasurements.filter { (measurement) -> Bool in
                    measurement.time >= startTime
                }
                rssiMeasurements = newRssiMeasurements
            }
            newRssiMeasurements.sort { (measurementA, measurementB) -> Bool in
                measurementA.rssi < measurementB.rssi
            }
            
            let count = newRssiMeasurements.count;
            if count > 0 {
                var start = 0;
                var end = count - 1
                if (count > 2) {
                    // Remove upper and lower 10%
                    start = count/10 + 1
                    end = count - count/10 - 2
                }
                let activeMeasurements = newRssiMeasurements[start...end]
                let sum : Int = activeMeasurements.reduce(0, { (sum, measurement) -> Int in
                    sum + measurement.rssi
                })
                averageRssi = sum / activeMeasurements.count
                if averageRssi > rssiNearThreshold {
                    if proximity != .near {
                        BBTLog.write("Moving into proximity range 'near'")
                    }
                    proximity = .near
                } else if averageRssi > rssiFarThreshold {
                    // Incorporate a bit of hysteresis on near -> far transitions
                    if (proximity == .near && averageRssi < rssiNearThreshold-1) || proximity != .far {
                        BBTLog.write("Moving into proximity range 'far'")
                        proximity = .far
                    }
                } else {
                    // Also incorporate hysteresis on near/far -> distant transitions
                    if proximity == .unknown || (proximity != .distant && averageRssi < rssiFarThreshold-1) {
                        BBTLog.write("Moving into proximity range 'distant'")
                        proximity = .distant
                    }
                }
                lostScanContact = false
                lostContactCounter = lostContactThreshold
                deviceRemovalCounter = deviceRemovalThreshold
                removeDevice = false
                //BBTLog.write("Average RSSI: %d, distance: %.2f", averageRssi, distance);
            } else {
                averageRssi = 0
                if lostContactCounter > 0 {
                    lostContactCounter = lostContactCounter - 1
                    lostScanContact = lostContactCounter == 0
                    // Cancel any pending connection
                    manager!.cancelConnection(self)
                }

                if deviceRemovalCounter > 0 {
                    deviceRemovalCounter = deviceRemovalCounter - 1
                }
                removeDevice = deviceRemovalCounter == 0
                if proximity != .unknown {
                    BBTLog.write("Moving into proximity range 'unknown'")
                }
                proximity = .unknown
                BBTLog.write("Out of range");
            }
            
            if removeDevice {
                BBTLog.write("Peripheral marked for removal, appId: %@", self.appId)
            }
            sendUpdateNotification()
        }
        if !removeDevice {
            scheduleRssiCalculation()
        }
    }
}
