//
//  AppDelegate.swift
//  TracePrivately
//

import UIKit
import BackgroundTasks

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let backgroundProcessingInterval: TimeInterval = 3600

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
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        DataManager.shared.saveContext()
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
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
            }
            catch {

            }
        }
        else {
            let interval = minimumDate.timeIntervalSinceNow
            UIApplication.shared.setMinimumBackgroundFetchInterval(interval)
        }
    }
    
    @available(iOS 13, *)
    func handleBackgroundTask(task: BGTask) {
        switch task.identifier {
        case ContactTraceManager.backgroundProcessingTaskIdentifier:
            ContactTraceManager.shared.performBackgroundUpdate { error in
                task.setTaskCompleted(success: error == nil)
                self.scheduleNextBackgroundProcess(minimumDate: Date().addingTimeInterval(Self.backgroundProcessingInterval))
            }
            
        default:
            task.setTaskCompleted(success: true)
        }
    }
}

