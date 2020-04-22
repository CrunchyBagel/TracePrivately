//
//  FontExtension.swift
//  TracePrivately
//

import UIKit

extension UIFont {
    func sizeOfString(string: String, constrainedToWidth width: CGFloat) -> CGSize {
        let label = UILabel()
        label.font = self
        label.numberOfLines = 0
        label.text = string
        label.lineBreakMode = .byWordWrapping
        
        let rect = label.textRect(forBounds: CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude), limitedToNumberOfLines: 0)
        return rect.size
    }
}

