//
//  ActionButton.swift
//  TracePrivately
//
//  Created by Quentin Zervaas on 22/4/20.
//  Copyright © 2020 Quentin Zervaas. All rights reserved.
//

import UIKit

class ActionButton: UIButton {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

    override func layoutSubviews() {
        super.layoutSubviews()
        
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
        
        self.layer.cornerRadius = 8
    }
}
