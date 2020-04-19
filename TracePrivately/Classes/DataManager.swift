//
//  DataManager.swift
//  TracePrivately
//

import CoreData

class DataManager {
    static let shared = DataManager()
    
    static let backgroundProcessingTaskIdentifier = "dm.processor"

    private init() {
        
    }
    
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
    // TODO: Need to automatically purge old keys
    private static let lastRecievedInfectedKeysKey = "lastRecievedInfectedKeysKey"
    
    private var lastRecievedInfectedKeys: Date? {
        return UserDefaults.standard.object(forKey: Self.lastRecievedInfectedKeysKey) as? Date
    }

    func saveLastReceivedInfectedKeys(date: Date) {
        UserDefaults.standard.set(date, forKey: Self.lastRecievedInfectedKeysKey)
        UserDefaults.standard.synchronize()
    }

    func saveInfectedKeys(keys: [CTDailyTracingKey], completion: @escaping (_ numNewKeys: Int, _ error: Swift.Error?) -> Void) {
        
        guard keys.count > 0 else {
            completion(0, nil)
            return
        }
        
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            let request: NSFetchRequest<RemoteInfectedKeyEntity> = RemoteInfectedKeyEntity.fetchRequest()
            
            let date = Date()
                
            var numNewKeys = 0

            for key in keys {
                
                let data = key.keyData
                
                request.predicate = NSPredicate(format: "infectedKey = %@", data as CVarArg)
                
                do {
                    let count = try context.count(for: request)
                    let alreadyHasKey = count > 0
                    
                    if !alreadyHasKey {
                        let entity = RemoteInfectedKeyEntity(context: context)
                        entity.dateAdded = date
                        entity.infectedKey = data
                        
                        numNewKeys += 1
                    }
                }
                catch {
                    completion(0, error)
                    return
                }
            }
            
            do {
                if context.hasChanges {
                    try context.save()
                }
                
                completion(numNewKeys, nil)
            }
            catch {
                completion(numNewKeys, error)
            }
        }
    }
    
    func fetchLatestInfectedKeys(completion: @escaping (_ numNewKeys: Int, _ error: Swift.Error?) -> Void) {
        KeyServer.shared.retrieveInfectedKeys(since: self.lastRecievedInfectedKeys) { response, error in
            guard let response = response else {
                completion(0, error)
                return
            }
            
            self.saveInfectedKeys(keys: response.keys) { numNewKeys, error in
                if let error = error {
                    completion(0, error)
                    return
                }
                
                self.saveLastReceivedInfectedKeys(date: response.date)
                completion(numNewKeys, nil)
            }
        }
    }
    
    func allInfectedKeys(completion: @escaping ([CTDailyTracingKey]?, Swift.Error?) -> Void) {
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            let request: NSFetchRequest<RemoteInfectedKeyEntity> = RemoteInfectedKeyEntity.fetchRequest()
            
            do {
                let entities = try context.fetch(request)
                
                let keys: [CTDailyTracingKey] = entities.compactMap { $0.infectedKey }.map { CTDailyTracingKey(keyData: $0) }
                completion(keys, nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }
}

extension DataManager {
    // Other statuses could be added here to allow the user to flag each
    // exposure with a level of confidence. For example, maybe they know
    // for a fact they were in their car alone, so they could mark an
    // exposure as not possible
    enum ExposureStatus: String {
        case detected = "D"
    }
    
    func saveExposures(contacts: [CTContactInfo], completion: @escaping (Error?) -> Void) {
        
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            
            var delete: [ExposureContactInfoEntity] = []
            var insert: [CTContactInfo] = []

            let fetchRequest: NSFetchRequest<ExposureContactInfoEntity> = ExposureContactInfoEntity.fetchRequest()
            
            do {
                let existingEntities = try context.fetch(fetchRequest)
                
                for entity in existingEntities {
                    var found = false
                    
                    for contact in contacts {
                        if entity.matches(contact: contact) {
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
                
                for contact in contacts {
                    var found = false
                    
                    for entity in existingEntities {
                        if entity.matches(contact: contact) {
                            found = true
                            break
                        }
                    }
                    
                    if found {
                        // Already have this contact
                    }
                    else {
                        print("New exposure detected: \(contact)")
                        insert.append(contact)
                    }
                }
                
                print("Deleting: \(delete.count)")
                print("Inserting: \(insert.count)")

                delete.forEach { context.delete($0) }

                for contact in insert {
                    let entity = ExposureContactInfoEntity(context: context)
                    entity.timestamp = contact.date
                    entity.duration = contact.duration
                    entity.status = ExposureStatus.detected.rawValue
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

fileprivate extension ExposureContactInfoEntity {
    var contactInfo: CTContactInfo? {
        guard let timestamp = self.timestamp else {
            return nil
        }
        
        return CTContactInfo(duration: self.duration, timestamp: timestamp.timeIntervalSinceReferenceDate)
    }
    
    func matches(contact: CTContactInfo) -> Bool {
        if contact.duration != self.duration {
            return false
        }
        
        if contact.date != self.timestamp {
            return false
        }
        
        return true
    }
}
