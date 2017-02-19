//
//  ConsoleViewController.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 12/8/16.
//  Copyright © 2016 BrightSign, LLC. All rights reserved.
//

import UIKit

class ConsoleViewController: UIViewController, BBTLogDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        BBTLog.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        textViewConsole.text = BBTLog.consoleText
        doAutoScroll()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: - Console
    
    @IBOutlet weak var textViewConsole: UITextView!
    
    var scrollLocked = false
    
    @IBOutlet weak var autoScrollStateLabel: UILabel!
    @IBAction func toggleAutoScroll(_ sender: UIButton) {
        scrollLocked = !scrollLocked
        autoScrollStateLabel.text = scrollLocked ? "No" : "Yes"
    }
    
    func setLogText(_ logText: String) {
        textViewConsole.text = logText
        doAutoScroll()
    }
    
    fileprivate func doAutoScroll() {
        if !scrollLocked {
            let bottomOffset = CGPoint(x:0, y:textViewConsole.contentSize.height - textViewConsole.bounds.size.height)
            textViewConsole.setContentOffset(bottomOffset, animated: true)
        }
    }
}
