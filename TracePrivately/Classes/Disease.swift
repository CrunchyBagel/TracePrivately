//
//  Disease.swift
//  TracePrivately
//

import Foundation

enum Disease {
    case covid19
    
    var localizedTitle: String {
        switch self {
        case .covid19:
            return NSLocalizedString("disease.covid19.title", comment: "")
        }
    }
    
    static let current = Disease.covid19
}
