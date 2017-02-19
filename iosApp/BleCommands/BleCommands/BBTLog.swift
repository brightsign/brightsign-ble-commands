//
//  BBTLog.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 1/26/16.
//  Copyright © 2016 BrightSign, LLC. All rights reserved.
//

import Foundation

protocol BBTLogDelegate {
    func setLogText(_ text: String)
}
class BBTLog: NSObject {
    
    static var delegate: BBTLogDelegate?
    
    static var consoleText = ""
    
    static let timeStampFormatter = DateFormatter()
    
    static func setup() {
        timeStampFormatter.dateFormat = "HH.mm.ss.SSS"
    }
    
    static var enabled : Bool {
        get {
            if let enab = UserDefaults.standard.object(forKey: "bbtLogEnabled") as? Bool {
                return enab
            } else {
                return false
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "bbtLogEnabled")
            UserDefaults.standard.synchronize()
        }
    }
    
    static func write(_ format: String, _ args: CVarArg...) {
        let s = String(format: format, arguments: args)
        NSLog(s)
        let timeString = timeStampFormatter.string(from: Date())
        while consoleText.characters.count > 20 * 1024 {
            if let index = consoleText.characters.index(of: "\n") {
                consoleText.removeSubrange(consoleText.startIndex...index)
            } else {
                consoleText = ""
            }
        }
        consoleText = consoleText + "[" + timeString + "] " + s + "\n"
        delegate?.setLogText(consoleText)
    }
}
