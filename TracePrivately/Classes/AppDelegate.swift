//
//  AppDelegate.swift
//  TracePrivately
//

import UIKit
import BackgroundTasks

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let backgroundProcessingInterval: TimeInterval = 10 // TODO: Low number just for testing
//    static let backgroundProcessingInterval: TimeInterval = 3600

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        ContactTraceManager.shared.applicationDidFinishLaunching()
        
        if #available(iOS 13, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: ContactTraceManager.backgroundProcessingTaskIdentifier, using: .main) { task in
                self.handleBackgroundTask(task: task)
            }
        }

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        ContactTraceManager.shared.performBackgroundUpdate { _ in
            self.scheduleNextBackgroundProcess(minimumDate: Date().addingTimeInterval(Self.backgroundProcessingInterval))
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        self.scheduleNextBackgroundProcess(minimumDate: Date().addingTimeInterval(Self.backgroundProcessingInterval))
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
            self.scheduleNextBackgroundProcess(minimumDate: Date().addingTimeInterval(Self.backgroundProcessingInterval))
        }
    }
}

extension AppDelegate {
    func scheduleNextBackgroundProcess(minimumDate: Date) {
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
        }
        else {
            print("Scheduling legacy background request for \(minimumDate)")
            let interval = minimumDate.timeIntervalSinceNow
        
            DispatchQueue.main.async {
                UIApplication.shared.setMinimumBackgroundFetchInterval(interval)
            }
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
                    self.scheduleNextBackgroundProcess(minimumDate: Date().addingTimeInterval(Self.backgroundProcessingInterval))
                }
                
                task.setTaskCompleted(success: success)
            }
            
            queue.addOperation(operation)
            
        default:
            task.setTaskCompleted(success: true)
        }
    }
}
