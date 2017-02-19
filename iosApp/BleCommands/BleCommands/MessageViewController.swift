//
//  MessageViewController.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 12/16/16.
//  Copyright © 2016 BrightSign, LLC. All rights reserved.
//

import UIKit

class MessageViewController: UIViewController {

    fileprivate var currentPeripheralProximity : PeripheralProximity = .unknown
    fileprivate var lastPeripheralProximity : PeripheralProximity = .unknown
    fileprivate var currentPeripheralBusy : Bool = false

    @IBOutlet weak var currentMessage: UILabel!
    
    func reset() {
        currentPeripheralProximity = .unknown
        lastPeripheralProximity = .unknown
        UpdateMessage()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(MessageViewController.peripheralRangeUpdated(_:)), name: NSNotification.Name(rawValue: "updatePeripheralData"), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func peripheralRangeUpdated(_ notification: Notification) {
        if let bsp = notification.object as? BTBspPeripheral {
            if currentPeripheralProximity != bsp.proximity || currentPeripheralBusy != bsp.isBusy {
                lastPeripheralProximity = currentPeripheralProximity
                currentPeripheralProximity = bsp.proximity
                currentPeripheralBusy = bsp.isBusy && !(bsp.sessionClosing || bsp.sessionActive)
                UpdateMessage()
            }
        }
    }
    
    func UpdateMessage() {
        if currentPeripheralProximity == .near {
            if currentPeripheralBusy {
                currentMessage.text = "Another visitor is interacting with the BrightBeacon™ demonstration. Please check back in a few minutes."
            } else {
                currentMessage.text = "Touch the Connect button to interact with the BrightBeacon™ demonstration."
            }
        } else if currentPeripheralProximity == .far {
            if lastPeripheralProximity == .near {
                currentMessage.text = "Thanks for visiting BrightSign."
            } else {
                currentMessage.text = "You're almost there! Come closer to the BrightBeacon™ demo to use your mobile device to control the presentation!"
            }
        } else {
            currentMessage.text = "Come closer to the BrightBeacon™ installation to see the interactive demo."
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

}
