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

        if #available(iOS 13, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: DataManager.backgroundProcessingTaskIdentifier, using: .main) { task in
            
                self.handleBackgroundTask(task: task)
            }
        }

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        DataManager.shared.fetchLatestInfectedKeys { _, _ in
            self.scheduleNextBackgroundProcess(minimumDate: Date().addingTimeInterval(Self.backgroundProcessingInterval))
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        DataManager.shared.saveContext()
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        DataManager.shared.fetchLatestInfectedKeys { numNewKeys, error in
            guard error == nil else {
                completionHandler(.failed)
                return
            }
            
            completionHandler(numNewKeys > 0 ? .newData : .noData)
            self.scheduleNextBackgroundProcess(minimumDate: Date().addingTimeInterval(Self.backgroundProcessingInterval))
        }
    }
}

extension AppDelegate {
    func scheduleNextBackgroundProcess(minimumDate: Date) {
        if #available(iOS 13, *) {
            let request = BGAppRefreshTaskRequest(identifier: DataManager.backgroundProcessingTaskIdentifier)
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
        case DataManager.backgroundProcessingTaskIdentifier:
            DataManager.shared.fetchLatestInfectedKeys { _, error in
                task.setTaskCompleted(success: error == nil)
                self.scheduleNextBackgroundProcess(minimumDate: Date().addingTimeInterval(Self.backgroundProcessingInterval))
            }
            
        default:
            task.setTaskCompleted(success: true)
        }
    }
}

