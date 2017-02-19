//
//  ActionViewCell.swift
//  BrightSignBT
//
//  Created by Jim Sugg on 12/18/16.
//  Copyright © 2016 BrightSign, LLC. All rights reserved.
//

import UIKit

class ActionViewCell: UITableViewCell {
    
    @IBOutlet weak var actionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
