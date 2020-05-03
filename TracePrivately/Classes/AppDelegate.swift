//
//  AppDelegate.swift
//  TracePrivately
//

import UIKit
import BackgroundTasks
import Intents

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    #if targetEnvironment(simulator)
    static let useModernBackgroundProcessing = false
    #else
    static let useModernBackgroundProcessing = true
    #endif

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        if let url = Bundle.main.url(forResource: "KeyServer", withExtension: "plist") {
            if let adapter = KeyServerConfig.createAdapter(plistUrl: url) {
                KeyServer.shared.adapter = adapter
            }
        }
        
        if let url = Bundle.main.url(forResource: "ExposureNotifications", withExtension: "plist") {
            if let config = ExposureNotificationConfig(plistUrl: url) {
                ContactTraceManager.shared.config = config
            }
        }
        

        ContactTraceManager.shared.applicationDidFinishLaunching()

        if #available(iOS 12, *) {
            let shortcuts: [INShortcut?] = [
                INShortcut(intent: StartTracingIntent()),
                INShortcut(intent: StopTracingIntent()),
            ]
            
            INVoiceShortcutCenter.shared.setShortcutSuggestions(shortcuts.compactMap { $0 })
        }
        
        if Self.useModernBackgroundProcessing {
            if #available(iOS 13, *) {
                BGTaskScheduler.shared.register(forTaskWithIdentifier: ContactTraceManager.backgroundProcessingTaskIdentifier, using: .main) { task in
                    self.handleBackgroundTask(task: task)
                }
            }
        }

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        ContactTraceManager.shared.applicationDidBecomeActive()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        ContactTraceManager.shared.scheduleNextBackgroundUpdate()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        DataManager.shared.saveContext()
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        print("performFetchWithCompletionHandler")
        
        ContactTraceManager.shared.performBackgroundUpdate { error in
            guard error == nil else {
                completionHandler(.failed)
                return
            }
            
            completionHandler(.newData)
            ContactTraceManager.shared.scheduleNextBackgroundUpdate()
        }
    }
}

extension AppDelegate {
    func scheduleNextBackgroundProcess(minimumDate: Date) {
        if Self.useModernBackgroundProcessing {
            if #available(iOS 13, *) {
                let request = BGAppRefreshTaskRequest(identifier: ContactTraceManager.backgroundProcessingTaskIdentifier)
                request.earliestBeginDate = minimumDate
                do {
                    try BGTaskScheduler.shared.submit(request)
                    print("Scheduling background request for \(minimumDate)")
                }
                catch {

                    if let error = error as? BGTaskScheduler.Error {
                        switch error.code {
                        case .notPermitted:
                            print("Error: Not permitted")
                        case .tooManyPendingTaskRequests:
                            print("Error: Too many requests")
                        case .unavailable:
                            print("Error: Unavailable")

                        @unknown default:
                            print("Error: Unknown")
                        }
                    }
                    else {
                        print("Error scheduling background request: \(error)")
                    }
                }

                return
            }
        }

        print("Scheduling legacy background request for \(minimumDate)")
        let interval = minimumDate.timeIntervalSinceNow
    
        DispatchQueue.main.async {
            UIApplication.shared.setMinimumBackgroundFetchInterval(interval)
        }
    }
    
    @available(iOS 13, *)
    func handleBackgroundTask(task: BGTask) {
        print("Handling background task: \(task)")
        
        switch task.identifier {
        case ContactTraceManager.backgroundProcessingTaskIdentifier:
            
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            
            task.expirationHandler = {
                queue.cancelAllOperations()
            }
            
            let operation = AsyncBlockOperation { operation in
                ContactTraceManager.shared.performBackgroundUpdate { error in
                    operation.complete()
                }
            }
            
            operation.completionBlock = {
                let success = !operation.isCancelled
                
                if success {
                    ContactTraceManager.shared.scheduleNextBackgroundUpdate()
                }
                
                task.setTaskCompleted(success: success)
            }
            
            queue.addOperation(operation)
            
        default:
            task.setTaskCompleted(success: true)
        }
    }
}

extension AppDelegate {
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        if #available(iOS 12.0, *) {
            if let intent = userActivity.interaction?.intent {
                switch intent {
                case is StartTracingIntent:
                    ContactTraceManager.shared.startTracing { _ in
                        
                    }
                    
                    return true
                    
                case is StopTracingIntent:
                    ContactTraceManager.shared.stopTracing()
                    
                    return true
                    
                default:
                    return false
                }
            }
        }

        return false

    }
}
