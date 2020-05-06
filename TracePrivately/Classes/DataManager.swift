//
//  DataManager.swift
//  TracePrivately
//

import CoreData

class DataManager {
    static let shared = DataManager()
    

    private init() {
        
    }
    
    static let exposureContactsUpdatedNotification = Notification.Name("exposureContactsUpdatedNotification")
    static let infectionsUpdatedNotification = Notification.Name("infectionsUpdatedNotification")

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "TracePrivately")
        
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            description.setOption(FileProtectionType.complete as NSObject, forKey: NSPersistentStoreFileProtectionKey)
            
            if #available(iOS 11.0, *) {
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            }
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            
            if let url = storeDescription.url {
                print("Core Data URL: \(url.relativeString)")
            }

            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true

        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

extension DataManager {
    func clearRemoteKeyAndLocalExposuresCache(completion: @escaping (Swift.Error?) -> Void) {
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            do {
                let fetchRequests: [NSFetchRequest<NSFetchRequestResult>] = [
                    RemoteInfectedKeyEntity.fetchRequest(),
                    ExposureContactInfoEntity.fetchRequest()
                ]
                
                for fetchRequest in fetchRequests {
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    try context.execute(deleteRequest)
                }
                
                try context.save()
                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }
}

extension DataManager {
    func deleteLocalInfections(completion: @escaping (Swift.Error?) -> Void) {
        
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            do {
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = LocalInfectionEntity.fetchRequest()
                
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                try context.execute(deleteRequest)
                
                try context.save()
                
                NotificationCenter.default.post(name: DataManager.infectionsUpdatedNotification, object: nil)
                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    struct KeyUpdateCount {
        let inserted: Int
        let updated: Int
        let deleted: Int
        
        static let empty = KeyUpdateCount(inserted: 0, updated: 0, deleted: 0)
    }

    func saveInfectedKeys(keys: [TPTemporaryExposureKey], deletedKeys: [TPTemporaryExposureKey], clearCacheFirst: Bool, completion: @escaping (KeyUpdateCount?, Swift.Error?) -> Void) {
        
        guard keys.count > 0 else {
            completion(.empty, nil)
            return
        }
        
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            
            var numInserted = 0
            var numUpdated = 0
            var numDeleted = 0

            let now = Date()

            if clearCacheFirst {
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = RemoteInfectedKeyEntity.fetchRequest()
                
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                
                do {
                    try context.execute(deleteRequest)
                }
                catch {
                    completion(nil, error)
                }
            }
            else {
                let request: NSFetchRequest<RemoteInfectedKeyEntity> = RemoteInfectedKeyEntity.fetchRequest()
                

                // Remove deleted keys first
                
                var deleteEntities: [RemoteInfectedKeyEntity] = []
                
                for key in deletedKeys {
                    
                    let data = key.keyData
                    
                    request.predicate = NSPredicate(format: "infectedKey = %@ AND rollingStartNumber = %@", data as CVarArg, Int64(key.rollingStartNumber) as NSNumber)
                    
                    do {
                        let entities = try context.fetch(request)
                        deleteEntities.append(contentsOf: entities)
                    }
                    catch {
                        
                    }
                }
                
                if deleteEntities.count > 0 {
                    print("Deleting entities: \(deleteEntities)")
                    deleteEntities.forEach { context.delete($0) }
                }
                
                numDeleted = deleteEntities.count
            }
            

            // Check incoming keys against submitted keys to see if the
            // submitted infection has been approved
            
            var localInfectionsUpdated = false
            
            do {
                let fetchRequest: NSFetchRequest<LocalInfectionEntity> = LocalInfectionEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "status != %@", InfectionStatus.submittedApproved.rawValue)
                
                let entities = try context.fetch(fetchRequest)
                
                let keyData: Set<Data> = Set(keys.map { $0.comparisonData })
                
                var approvedEntities: [LocalInfectionEntity] = []
                
                for entity in entities {
                    guard let keysSet = entity.infectedKey else {
                        continue
                    }
                    
                    let keyEntities = keysSet.compactMap { $0 as? LocalInfectionKeyEntity }
                    
                    let localData: Set<Data> = Set(keyEntities.compactMap { $0.temporaryExposureKey?.comparisonData })
                    
                    if keyData.intersection(localData).count > 0 {
                        approvedEntities.append(entity)
                    }
                }
                
                if approvedEntities.count > 0 {
                    approvedEntities.forEach { entity in
                        entity.status = InfectionStatus.submittedApproved.rawValue
                    }
                    
                    localInfectionsUpdated = true
                }
            }
            catch {
                
            }

            let request: NSFetchRequest<RemoteInfectedKeyEntity> = RemoteInfectedKeyEntity.fetchRequest()

            for key in keys {
                
                let data = key.keyData
                
                let insertKey: Bool
                
                if clearCacheFirst {
                    insertKey = true
                }
                else {
                    request.predicate = NSPredicate(format: "infectedKey = %@ AND rollingStartNumber = %@", data as CVarArg, Int64(key.rollingStartNumber) as NSNumber)
                    
                    let transmissionRiskLevel = Int16(key.transmissionRiskLevel)

                    do {
                        let entities = try context.fetch(request)
                        
                        for entity in entities {
                            if entity.transmissionRiskLevel != transmissionRiskLevel {
                                entity.transmissionRiskLevel = transmissionRiskLevel
                                numUpdated += 1
                            }
                        }
                        
                        insertKey = entities.count == 0
                    }
                    catch {
                        completion(nil, error)
                        return
                    }
                }
                
                if insertKey {
                    // TODO: Handle rolling period
                    let entity = RemoteInfectedKeyEntity(context: context)
                    entity.dateAdded = now
                    entity.infectedKey = data
                    // Core data doesn't support unsigned ints, so using Int64 instead of UInt32
                    entity.rollingStartNumber = Int64(key.rollingStartNumber)
                    entity.transmissionRiskLevel = Int16(key.transmissionRiskLevel)

                    numInserted += 1
                }
            }
            
            let keyCount = KeyUpdateCount(inserted: numInserted, updated: numUpdated, deleted: numDeleted)
            
            do {
                if context.hasChanges {
                    try context.save()
                }
                
                if localInfectionsUpdated {
                    NotificationCenter.default.post(name: DataManager.infectionsUpdatedNotification, object: nil)
                }
                
                completion(keyCount, nil)
            }
            catch {
                completion(keyCount, error)
            }
        }
    }
    
    func allInfectedKeys(completion: @escaping ([TPTemporaryExposureKey]?, Swift.Error?) -> Void) {
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            let request: NSFetchRequest<RemoteInfectedKeyEntity> = RemoteInfectedKeyEntity.fetchRequest()
            
            do {
                let entities = try context.fetch(request)
                
                let keys: [TPTemporaryExposureKey] = entities.compactMap { $0.temporaryExposureKey }
                completion(keys, nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }
}

// This is used to has keys that need to be updated local. Could probably be improved.
extension TPTemporaryExposureKey {
    var comparisonData: Data {
        let rollingData = withUnsafeBytes(of: rollingStartNumber) { Data($0) }
        return self.keyData + rollingData
    }
}

extension RemoteInfectedKeyEntity {
    var temporaryExposureKey: TPTemporaryExposureKey? {
        guard let keyData = self.infectedKey else {
            return nil
        }
        
        return .init(
            keyData: keyData,
            rollingPeriod: TPIntervalNumber(0), // TODO: Period
            rollingStartNumber: TPIntervalNumber(self.rollingStartNumber),
            transmissionRiskLevel: TPRiskLevel(self.transmissionRiskLevel)
        )
    }
}

extension LocalInfectionKeyEntity {
    var temporaryExposureKey: TPTemporaryExposureKey? {
        guard let keyData = self.infectedKey else {
            return nil
        }
        
        return .init(
            keyData: keyData,
            rollingPeriod: TPIntervalNumber(0), // TODO: Period
            rollingStartNumber: TPIntervalNumber(self.rollingStartNumber),
            transmissionRiskLevel: TPRiskLevel(self.transmissionRiskLevel)
        )
    }
}

extension DataManager {
    func submitReport(formData: InfectedKeysFormData, keys: [TPTemporaryExposureKey], completion: @escaping (Bool, Swift.Error?) -> Void) {
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            // Putting this as pending effectively saves a draft in case something goes wrong in submission
            
            let entity = LocalInfectionEntity(context: context)
            entity.dateAdded = Date()
            entity.status = DataManager.InfectionStatus.pendingSubmission.rawValue
            
            try? context.save()
        
            NotificationCenter.default.post(name: DataManager.infectionsUpdatedNotification, object: nil)

            KeyServer.shared.submitInfectedKeys(formData: formData, keys: keys, previousSubmissionId: nil) { success, submissionId, error in
                
                context.perform {
                    if success {
                        // XXX: Check against the local database to see if it should be submittedApproved or submittedUnapproved.
                        entity.status = DataManager.InfectionStatus.submittedUnapproved.rawValue
                        entity.remoteIdentifier = submissionId
                        
                        for key in keys {
                            let keyEntity = LocalInfectionKeyEntity(context: context)
                            keyEntity.infectedKey = key.keyData
                            keyEntity.rollingStartNumber = Int64(key.rollingStartNumber)
                            keyEntity.transmissionRiskLevel = Int16(key.transmissionRiskLevel)
                            // TODO: Rolling period
                            keyEntity.infection = entity
                        }

                        try? context.save()
                        
                        NotificationCenter.default.post(name: DataManager.infectionsUpdatedNotification, object: nil)
                        
                        completion(true, nil)
                    }
                    else {
                        completion(false, error)
                    }
                }
            }
        }

    }
}

extension DataManager {
    enum InfectionStatus: String {
        case pendingSubmission = "P"
        case submittedUnapproved = "U" // Submitted but hasn't been received back as an infected key
        case submittedApproved = "S" // Submitted and seen in the remote infection list
    }
}

extension DataManager {
    // Other statuses could be added here to allow the user to flag each
    // exposure with a level of confidence. For example, maybe they know
    // for a fact they were in their car alone, so they could mark an
    // exposure as not possible
    enum ExposureStatus: String {
        case unread = "D"
        case read = "V"
    }
    
    enum ExposureLocalNotificationStatus: String {
        case notSent = "P"
        case sent = "S"
    }
    
    func updateStatus(exposure entity: ExposureContactInfoEntity, status: ExposureStatus, completion: @escaping (Swift.Error?) -> Void) {

        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            
            guard let entity = context.object(with: entity.objectID) as? ExposureContactInfoEntity else {
                completion(nil)
                return
            }
            
            if status.rawValue != entity.status {
                entity.status = status.rawValue
            }

            do {
                if context.hasChanges {
                    try context.save()
                    
                    ContactTraceManager.shared.updateBadgeCount()
                }
                
                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }
    
    func saveExposures(exposures: [TPExposureInfo], completion: @escaping (Swift.Error?) -> Void) {
        
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            
            var delete: [ExposureContactInfoEntity] = []
            var insert: [TPExposureInfo] = []

            do {
                let request = ExposureFetchRequest(includeStatuses: [], includeNotificationStatuses: [], sortDirection: nil)
                let existingEntities = try context.fetch(request.fetchRequest)
                
                for entity in existingEntities {
                    var found = false
                    
                    for exposure in exposures {
                        if entity.matches(exposure: exposure) {
                            found = true
                            break
                        }
                    }
                    
                    if found {
                        // Already have this contact
                        print("Contact already exists, skipping")
                    }
                    else {
                        print("Contact not found in new list, deleting: \(entity)")
                        delete.append(entity)
                    }
                }
                
                for exposure in exposures {
                    var found = false
                    
                    for entity in existingEntities {
                        if entity.matches(exposure: exposure) {
                            found = true
                            break
                        }
                    }
                    
                    if found {
                        // Already have this contact
                    }
                    else {
                        print("New exposure detected: \(exposure)")
                        insert.append(exposure)
                    }
                }
                
                print("Deleting: \(delete.count)")
                print("Inserting: \(insert.count)")

                delete.forEach { context.delete($0) }

                for contact in insert {
                    let entity = ExposureContactInfoEntity(context: context)
                    entity.timestamp = contact.date
                    entity.duration = contact.duration
                    entity.attenuationValue = Int16(contact.attenuationValue)
                    entity.totalRiskScore = Int16(contact.totalRiskScore)
                    entity.transmissionRiskLevel = Int16(contact.transmissionRiskLevel)
                    
                    entity.status = ExposureStatus.unread.rawValue
                    entity.localNotificationStatus = ExposureLocalNotificationStatus.notSent.rawValue
                }
                
                try context.save()
                
                NotificationCenter.default.post(name: Self.exposureContactsUpdatedNotification, object: nil)
                
                completion(nil)
            }
            catch {
                completion(error)
            }
        }
        
    }
}

extension DataManager {
    enum DiseaseStatus {
        case nothingDetected
        case exposed
        case infection
        case infectionPending
        case infectionPendingAndExposed
    }
    
    func diseaseStatus(context: NSManagedObjectContext) -> DiseaseStatus {
        let exposureRequest = ExposureFetchRequest(includeStatuses: [ .unread, .read ], includeNotificationStatuses: [], sortDirection: .timestampAsc)
        let numContacts = (try? context.count(for: exposureRequest.fetchRequest)) ?? 0
        
        let infectionRequest = InfectionFetchRequest(minDate: nil, includeStatuses: [ .submittedApproved, .submittedUnapproved ])
        
        var hasPending = false
        var hasApproved = false
        
        do {
            let infections = try context.fetch(infectionRequest.fetchRequest)

            infections.forEach { infection in
                switch infection.status {
                case InfectionStatus.submittedUnapproved.rawValue:
                    hasPending = true
                case InfectionStatus.submittedApproved.rawValue:
                    hasApproved = true
                default:
                    break
                }
            }
            
        }
        catch {

        }
        
        if hasPending {
            if numContacts > 0 {
                return .infectionPendingAndExposed
            }
            else {
                return .infectionPending
            }
        }
        else if hasApproved {
            return .infection
        }
        else if numContacts > 0 {
            return .exposed
        }
        else {
            return .nothingDetected
        }
    }
}

extension ExposureContactInfoEntity {
    var contactInfo: TPExposureInfo? {
        guard let timestamp = self.timestamp else {
            return nil
        }
        
        return .init(
            attenuationValue: UInt8(self.attenuationValue),
            date: timestamp,
            duration: self.duration,
            totalRiskScore: TPRiskScore(self.totalRiskScore),
            transmissionRiskLevel: TPRiskLevel(self.transmissionRiskLevel)
        )
    }
    
    func matches(exposure b: TPExposureInfo) -> Bool {
        guard let a = self.contactInfo else {
            return false
        }
        
        if a.attenuationValue != b.attenuationValue {
            return false
        }
        
        if a.duration != b.duration  {
            return false
        }

        if a.date != b.date {
            return false
        }

        if a.transmissionRiskLevel != b.transmissionRiskLevel {
            return false
        }

        if a.totalRiskScore != b.totalRiskScore {
            return false
        }
        
        return true
    }
}

struct ExposureFetchRequest {
    enum SortDirection {
        case timestampAsc
        case timestampDesc

        var sortDescriptors: [NSSortDescriptor] {
            switch self {
            case .timestampAsc:
                return [
                    NSSortDescriptor(key: "timestamp", ascending: true),
                    NSSortDescriptor(key: "duration", ascending: false)
                ]
            case .timestampDesc:
                return [
                    NSSortDescriptor(key: "timestamp", ascending: false),
                    NSSortDescriptor(key: "duration", ascending: true)
                ]
            }
        }
    }
    
    let includeStatuses: Set<DataManager.ExposureStatus>
    let includeNotificationStatuses: Set<DataManager.ExposureLocalNotificationStatus>
    let sortDirection: SortDirection?
    
    var fetchRequest: NSFetchRequest<ExposureContactInfoEntity> {
        
        let fetchRequest: NSFetchRequest<ExposureContactInfoEntity> = ExposureContactInfoEntity.fetchRequest()
        
        var predicates: [NSPredicate] = []

        if includeStatuses.count > 0 {
            predicates.append(NSPredicate(format: "status IN %@", includeStatuses.map { $0.rawValue }))
        }
        
        if includeNotificationStatuses.count > 0 {
            predicates.append(NSPredicate(format: "localNotificationStatus IN %@", includeNotificationStatuses.map { $0.rawValue }))
        }
        
        if predicates.count > 0 {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        if let sortDirection = sortDirection {
            fetchRequest.sortDescriptors = sortDirection.sortDescriptors
        }

        return fetchRequest
    }
}

struct InfectionFetchRequest {
    let minDate: Date?
    let includeStatuses: Set<DataManager.InfectionStatus>

    var fetchRequest: NSFetchRequest<LocalInfectionEntity> {
        
        let fetchRequest: NSFetchRequest<LocalInfectionEntity> = LocalInfectionEntity.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        if includeStatuses.count > 0 {
            predicates.append(NSPredicate(format: "status IN %@", includeStatuses.map { $0.rawValue }))
        }
        
        if let minDate = minDate {
            predicates.append(NSPredicate(format: "dateAdded >= %@", minDate as CVarArg))
        }
        
        if predicates.count > 0 {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        return fetchRequest
    }
}
