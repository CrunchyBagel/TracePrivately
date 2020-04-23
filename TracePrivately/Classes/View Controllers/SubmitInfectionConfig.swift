//
//  SubmitInfectionConfig.swift
//  TracePrivately
//

import UIKit

struct SubmitInfectionConfig {
    
    enum FieldType: String {
        case shortText = "ShortText"
        case longText = "LongText"
        case photo = "Photo"
    }
    
    struct Field {
        let type: FieldType
        let required: Bool
        let formName: String
        let placeholder: String?
        
        let localizedTitle: String?
        let localizedDescription: String?
    }
    
    let sortedFields: [Field]
    
    static let empty = SubmitInfectionConfig(sortedFields: [])
}

extension SubmitInfectionConfig {
    init?(plistUrl: URL) {
        guard let config = NSDictionary(contentsOf: plistUrl) else {
            return nil
        }
        
        guard let formConfig = config.object(forKey: "Form") as? [String: Any] else {
            return nil
        }
        
        guard let sortedFieldsConfig = formConfig["SortedFields"] as? [[String: Any]] else {
            return nil
        }
        
        let sortedFields = sortedFieldsConfig.compactMap { SubmitInfectionConfig.Field(config: $0) }
        
        self.init(sortedFields: sortedFields)
    }
}

extension SubmitInfectionConfig.Field {
    fileprivate init?(config: [String: Any]) {
        guard let typeStr = config["Type"] as? String, let type = SubmitInfectionConfig.FieldType(rawValue: typeStr) else {
            return nil
        }
        
        guard let formName = config["FormName"] as? String else {
            return nil
        }
        
        let required: Bool
        
        if let requiredNumber = config["Required"] as? NSNumber {
            required = requiredNumber.boolValue
        }
        else {
            required = false
        }
        
        let localizedTitle: String?
        
        if let translations = config["LocalizedTitle"] as? [String: String] {
            localizedTitle = Self.currentTranslation(translations: translations)
        }
        else {
            localizedTitle = nil
        }
        
        let localizedDescription: String?

        if let translations = config["LocalizedDescription"] as? [String: String] {
            localizedDescription = Self.currentTranslation(translations: translations)
        }
        else {
            localizedDescription = nil
        }
        
        let localizedPlaceholder: String?

        if let translations = config["LocalizedPlaceholder"] as? [String: String] {
            localizedPlaceholder = Self.currentTranslation(translations: translations)
        }
        else {
            localizedPlaceholder = nil
        }

        self.init(
            type: type,
            required: required,
            formName: formName,
            placeholder: localizedPlaceholder,
            localizedTitle: localizedTitle,
            localizedDescription: localizedDescription
        )
    }
    
    private static func currentTranslation(translations: [String: String]) -> String? {
        
        // TODO: Make this a bit smarter: accept both just language or language + country code and use the closest possible match
        for localization in Bundle.main.preferredLocalizations {
            if let str = translations[localization] {
                return str
            }
        }
        
        // Fall back to base, and if that's not there, just take the first one
        return translations["Base"] ?? translations.first?.value
    }
}
