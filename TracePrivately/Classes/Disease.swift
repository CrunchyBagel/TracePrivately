//
//  Disease.swift
//  TracePrivately
//
//  Created by Quentin Zervaas on 18/4/20.
//  Copyright © 2020 Quentin Zervaas. All rights reserved.
//

import Foundation

enum Disease {
    case covid19
    
    var localizedTitle: String {
        return NSLocalizedString("disease.covid19.title", comment: "")
    }
    
    static let current = Disease.covid19
}
