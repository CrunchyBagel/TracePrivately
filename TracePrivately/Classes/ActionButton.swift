//
//  ActionButton.swift
//  TracePrivately
//

import UIKit

class ActionButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
        
        self.layer.cornerRadius = 8
    }
}
