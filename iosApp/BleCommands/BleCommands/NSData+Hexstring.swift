//
//  NSData+Hexstring.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 1/15/16.
//  Copyright © 2016 BrightSign, LLC. All rights reserved.
//

import Foundation
import UIKit

extension Data
{
    func hexString() -> String
    {
        var str = ""
        
        var bytes = [UInt8](repeating: 0, count: self.count)
        (self as NSData).getBytes(&bytes, length:self.count)
        for byte in bytes {
            str += String(format:"%02x", byte)
        }
        return str
    }
}
