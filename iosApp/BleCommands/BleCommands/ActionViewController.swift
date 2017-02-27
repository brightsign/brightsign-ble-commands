//
//  ActionViewController.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 12/16/16.
//  Copyright © 2017 BrightSign, LLC. All rights reserved.
//

import UIKit

class ActionViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let bsp = BTCentralManager.sharedInstance.activePeripheral {
            setActions(bsp.commandArray)
        } else {
            setActions([])
        }
        NotificationCenter.default.addObserver(self, selector: #selector(ActionViewController.deviceDataUpdated(_:)), name: NSNotification.Name(rawValue: "updateDeviceData"), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return actionLabels.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath) as! ActionViewCell

        cell.actionLabel.text = actionLabels[indexPath.row]

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row < actionCommands.count {
            let actionCommand = actionCommands[indexPath.row]
            BTCentralManager.sharedInstance.sendCommandToActivePeripheral(actionCommand)
            tableView.deselectRow(at: indexPath, animated: false)
        } else {
            BBTLog.write("Unexpected: Action command not found in list!")
            if let bspPeripheral = BTCentralManager.sharedInstance.activePeripheral {
                bspPeripheral.resetPlayerInfo()
            }
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    private var actionLabels : [String] = []
    private var actionCommands : [String] = []
    
    func setActions(_ actionList: [(String, String)]) {
        actionLabels.removeAll()
        actionCommands.removeAll()
        for (label, command) in actionList {
            actionLabels.append(label)
            actionCommands.append(command)
        }
    }
    
    func deviceDataUpdated(_ notification: Notification) {
        if let bsp = notification.object as? BTBspPeripheral {
            setActions(bsp.commandArray)
            tableView.reloadData()
        }
    }

}
