//
//  HomeViewController.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 12/13/16.
//  Copyright © 2016 BrightSign, LLC. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController, BTManagerDelegate {
    
    fileprivate var currentPeripheralProximity : PeripheralProximity = .unknown
    fileprivate var currentPeripheralBusy = false
    fileprivate var actionViewActive = false
    fileprivate var diagnosticsHidden = true

    @IBOutlet weak var contentContainerView: UIView!
    @IBOutlet weak var connectButton: UIButton!
    
    fileprivate lazy var messageViewController : MessageViewController = {
        return self.storyboard?.instantiateViewController(withIdentifier: "messageViewController") as! MessageViewController
    } ()
    
    fileprivate lazy var actionViewController : ActionViewController = {
        return self.storyboard?.instantiateViewController(withIdentifier: "actionViewController") as! ActionViewController
    } ()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            return .lightContent
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let diagnosticsHidden = UserDefaults.standard.object(forKey: "diagnosticsHidden") as? Bool {
            self.diagnosticsHidden = diagnosticsHidden
        }
        btnShowDiagnostic.isHidden = diagnosticsHidden
        
        add(asContentViewController: messageViewController)
        
        BTManager.sharedInstance.delegate = self
        startMonitoring()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(HomeViewController.peripheralRangeUpdated(_:)), name: NSNotification.Name(rawValue: "updatePeripheralData"), object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func didEnterBackground() {
        connectButton.isHidden = true
        currentPeripheralProximity = .unknown
        messageViewController.reset()
        if actionViewActive {
            showMessageView()
        }
    }
    
    func startMonitoring() {
        BTManager.sharedInstance.startDefaultBeaconMonitoring()
        BTManager.sharedInstance.startScanningForPeripherals()
    }
    
    func stopMonitoring() {
        BTManager.sharedInstance.stopDefaultBeaconMonitoring()
        BTManager.sharedInstance.stopScanningForPeripherals()
    }
    
    func peripheralRangeUpdated(_ notification: Notification) {
        if let bsp = notification.object as? BTBspPeripheral {
            if currentPeripheralProximity != bsp.proximity || currentPeripheralBusy != bsp.isBusy {
                currentPeripheralProximity = bsp.proximity
                currentPeripheralBusy = bsp.isBusy
            }
            if bsp.sessionActive && (currentPeripheralProximity == .distant || currentPeripheralProximity == .unknown) {
                // Close the session is user wanders out of far range
                bsp.closeSession()
                showMessageView()
            }
            connectButton.isHidden = !(bsp.sessionActive || (currentPeripheralProximity == .near && !bsp.isBusy))
        }
    }
    
    // MARK: - Actions
    
    fileprivate func setConnectButtonTitle(_ title: String) {
        connectButton.setTitle(title, for: .normal)
        connectButton.setTitle(title, for: .highlighted)
    }
    
    fileprivate func showMessageView() {
        setConnectButtonTitle("Connect")
        remove(asContentViewController: actionViewController)
        add(asContentViewController: messageViewController)
        actionViewActive = false
    }
    
    fileprivate func showActionView() {
        setConnectButtonTitle("Disconnect")
        remove(asContentViewController: messageViewController)
        add(asContentViewController: actionViewController)
        actionViewActive = true
    }
    
    @IBAction func toggleConnection(_ sender: UIButton) {
        if BTManager.sharedInstance.isPeripheralSessionActive {
            BTManager.sharedInstance.stopPeripheralSession()
            showMessageView()
        } else {
            let success = BTManager.sharedInstance.startSessionWithClosestPeripheral()
            if (success) {
                showActionView()
            }
        }
    }
    
    // MARK: - Child view management
    
    fileprivate func add(asContentViewController viewController: UIViewController) {
        addChildViewController(viewController)
        
        contentContainerView.addSubview(viewController.view)
        
        viewController.view.frame = contentContainerView.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        viewController.didMove(toParentViewController: self)
    }

    fileprivate func remove(asContentViewController viewController: UIViewController) {
        viewController.willMove(toParentViewController: nil)
        
        viewController.view.removeFromSuperview()
        
        viewController.removeFromParentViewController()
    }
    
    // MARK: - Diagnostics view management

    @IBOutlet weak var btnShowDiagnostic: UIButton!
    
    @IBAction func toggleDiagnosticVisibility(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            diagnosticsHidden = !diagnosticsHidden
            btnShowDiagnostic.isHidden = diagnosticsHidden
            UserDefaults.standard.set(diagnosticsHidden, forKey: "diagnosticsHidden")
            UserDefaults.standard.synchronize()
        }
    }
    
    @IBAction func returnedFromDiagnostics(_ segue: UIStoryboardSegue) {
    }
    
    // MARK: - BT Manager delegate
    
    func didChangeActivePeripheral(_ btBspPeripheral: BTBspPeripheral?) {
        // Set a test name so we can test setting user data
        if let bsp = btBspPeripheral {
            bsp.setUserDataValue("Test User", key: "name")
        } else if actionViewActive {
            showMessageView()
        }
    }
}
