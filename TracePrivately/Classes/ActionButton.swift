//
//  ActionButton.swift
//  TracePrivately
//

import UIKit

class ActionButton: UIButton {
    enum Accessory {
        case disclosure
        
        var image: UIImage? {
            if #available(iOS 13, *) {
                switch self {
                case .disclosure:
                    return UIImage(systemName: "chevron.right.circle.fill")
                }
            }
            else {
                return nil
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.setup()
    }
    
    private func setup() {
        self.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
    }
    
    var accessory: Accessory? {
        didSet {
            self.updateAccessory()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
        
        self.layer.cornerRadius = 8
    }
    
    override func setTitleColor(_ color: UIColor?, for state: UIControl.State) {
        super.setTitleColor(color, for: state)
        self.imageView?.tintColor = color
    }
    
    private func updateAccessory() {
        guard let image = self.accessory?.image else {
            self.setImage(nil, for: .normal)
            return
        }
        
        self.adjustsImageWhenHighlighted = false

        self.setImage(image, for: .normal)
        
        self.imageView?.tintColor = self.titleColor(for: .normal)
        
        self.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        self.titleLabel?.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        self.imageView?.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        
        let imagePadding: CGFloat = 10
        
        self.contentEdgeInsets = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: 0,
            right: imagePadding
        )
        self.titleEdgeInsets = UIEdgeInsets(
            top: 0,
            left: imagePadding,
            bottom: 0,
            right: -imagePadding
        )
    }
}
