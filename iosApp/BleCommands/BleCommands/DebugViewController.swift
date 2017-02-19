//
//  DebugViewController.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 1/8/16.
//  Copyright © 2016 BrightSign, LLC. All rights reserved.
//

import UIKit
import CoreLocation

class DebugViewController: UITableViewController, UITextFieldDelegate {

    @IBOutlet weak var bsStatus: UILabel!
    @IBOutlet weak var bsAccuracy: UILabel!
    @IBOutlet weak var bsRssi: UILabel!
    
    @IBOutlet weak var sessionStatus: UILabel!
    @IBOutlet weak var sessionDistance: UILabel!
    @IBOutlet weak var sessionRSSI: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(DebugViewController.beaconRangeUpdated(_:)), name: NSNotification.Name(rawValue: "updateBeaconRegionMap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DebugViewController.peripheralRangeUpdated(_:)), name: NSNotification.Name(rawValue: "updatePeripheralData"), object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
//
//    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return 1
//    }

    /*
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath)

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: - BTManagerDelegate and Notifications
    
    func beaconRangeUpdated(_ notification: Notification)
    {
        if let userInfo = notification.userInfo as? [String:AnyObject],
            let regionMap = userInfo["map"] as? BTBeaconRegionMap,
            let closestBeaconData = regionMap.closestBeacon,
            let beacon = closestBeaconData.beacon
        {
            switch beacon.proximity {
            case .unknown: bsStatus.text = "Unknown"
            case .immediate: bsStatus.text = "Immediate"
            case .near: bsStatus.text = "Near"
            case .far: bsStatus.text = "Far"
            }
            bsAccuracy.text = String.localizedStringWithFormat("%.2f", beacon.accuracy)
            bsRssi.text = String(beacon.rssi)
            self.tableView.reloadData()
        }
    }
    
    func peripheralRangeUpdated(_ notification: Notification)
    {
        if let bsp = notification.object as? BTBspPeripheral {
            sessionStatus.text = bsp.sessionActive ? "Active" : (bsp.isBusy ? "Busy" : "Inactive")
            if bsp.sessionActive || bsp.isClosestPeripheral {
                sessionDistance.text = String.localizedStringWithFormat("%.2f (%@)", bsp.distance, bsp.proximity.rawValue)
                sessionRSSI.text = String(bsp.rssi)
            } else {
                sessionDistance.text = "-1.00 (u)"
                sessionRSSI.text = "0"
            }
            self.tableView.reloadData()
        }
    }
}
