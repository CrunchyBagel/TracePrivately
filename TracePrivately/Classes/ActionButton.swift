//
//  ActionButton.swift
//  TracePrivately
//

import UIKit

public func clamp<T>(_ value: T, minValue: T, maxValue: T) -> T where T : Comparable {
    return min(max(value, minValue), maxValue)
}

class ActionButton: UIButton {
    enum Accessory {
        case disclosure
        
        var image: UIImage? {
            if #available(iOS 13, *) {
                switch self {
                case .disclosure:
                    return UIImage(systemName: "chevron.right")
                }
            }
            else {
                return nil
            }
        }
    }

    private var _backgroundColor: UIColor?
    private var _highlightBackgroundColor: UIColor?
    
    override var backgroundColor: UIColor? {
        didSet {
            if _highlightBackgroundColor == nil {
                _backgroundColor = backgroundColor
                _highlightBackgroundColor = backgroundColor?.darken(0.1)
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
        self.titleLabel?.adjustsFontSizeToFitWidth = true
    }
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted != oldValue {
                self.updateBackgroundColor()
            }
        }
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
    
    private func updateBackgroundColor() {
        self.backgroundColor = self.isHighlighted ? self._highlightBackgroundColor : self._backgroundColor
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
        
        if self.effectiveUserInterfaceLayoutDirection == .rightToLeft {
            self.contentEdgeInsets = UIEdgeInsets(
                top: 0,
                left: imagePadding,
                bottom: 0,
                right: 0
            )
            self.titleEdgeInsets = UIEdgeInsets(
                top: 0,
                left: -imagePadding,
                bottom: 0,
                right: imagePadding
            )
        }
        else {
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
}

extension UIColor {
    func darken(_ amount: CGFloat) -> UIColor {
        return offsetWithHue(0.0, saturation: 0.0, brightness: -amount, alpha: 0.0)
    }

    func lighten(_ amount: CGFloat) -> UIColor {
        return offsetWithHue(0.0, saturation: 0.0, brightness: amount, alpha: 0.0)
    }

    func offsetWithHue(_ hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a:CGFloat = 0

        if self.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            h = fmod(hue + h, 1)
            s = clamp(saturation + s, minValue: 0, maxValue: 1)
            b = clamp(brightness + b, minValue: 0, maxValue: 1)
            a = clamp(alpha + a, minValue: 0, maxValue: 1)
            
            return UIColor(hue: h, saturation: s, brightness: b, alpha: a)
        }
        else {
            return UIColor()
        }
    }
}
