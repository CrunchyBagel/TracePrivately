//
//  main.swift
//  SubmitFakeKeys
//

import Foundation


/// This is a utility to generate fake submissions to help test scalability of the server


extension String : Swift.Error {}

func writeToStdError(_ str: String) {
    if let data = str.data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

func writeToStdOut(_ str: String) {
    if let data = str.data(using: .utf8) {
        FileHandle.standardOutput.write(data)
    }
}

func showHelpAndExit() {
    writeToStdError(String(format: "%@ new KeyServer.plist [num submissions]\n", CommandLine.arguments[0]))
    writeToStdError(String(format: "%@ update KeyServer.plist [num new keys]\n", CommandLine.arguments[0]))
    exit(EXIT_FAILURE)
}

extension TPTemporaryExposureKey {
    static func generateRandom(date: Date) -> Self {
        
        let keyData = UUID().data
        
        return Self(
            keyData: keyData,
            rollingStartNumber: TPIntervalNumber.intervalNumberFrom(date: date),
            transmissionRiskLevel: .high
        )
    }
}

func getPlistPath(_ path: String) throws -> URL {
    
    let url = URL(fileURLWithPath: path, isDirectory: false)
    
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw "Not found: \(path)"
    }
    
    return url
}

let dispatchGroup = DispatchGroup()

do {
    if CommandLine.arguments.count < 3 {
        showHelpAndExit()
    }

    enum AppCommand: String {
        case newSubmission = "new"
        case updateSubmission = "update"
    }

    let commandStr = CommandLine.arguments[1]
    guard let appCommand = AppCommand(rawValue: commandStr) else {
        throw "Invalid app command: \(commandStr)"
    }


    let plistUrl = try getPlistPath(CommandLine.arguments[2])

    guard let config = KeyServerConfig(plistUrl: plistUrl) else {
        throw "Invalid KeyServer config"
    }

    switch appCommand {
    case .newSubmission:
        if CommandLine.arguments.count < 4 {
            showHelpAndExit()
        }
        
        KeyServer.shared.config = config

        guard var numSubmissions = Int(CommandLine.arguments[3]) else {
            throw "Must specify number of submissions"
        }
        
        numSubmissions = max(0, min(1000, numSubmissions))
        
        let numKeys = 16
        
        let now = Date()
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        for i in 1 ... numSubmissions {
            
            dispatchGroup.enter()
            
            let operation = AsyncBlockOperation { operation in
                dispatchGroup.enter()

                guard !operation.isCancelled else {
                    operation.complete()
                    return
                }
                
                
                writeToStdOut("Submitting \(i)/\(numSubmissions) ...\n")
                
                var keys: [TPTemporaryExposureKey] = []

                for _ in 0 ..< numKeys {
                    let date = now.addingTimeInterval(-86400)
                    keys.append(TPTemporaryExposureKey.generateRandom(date: date))
                }
                
                
                let formData = InfectedKeysFormData(fields: [])
                let previousSubmissionId: String? = nil
                
                
                KeyServer.shared.submitInfectedKeys(formData: formData, keys: keys, previousSubmissionId: previousSubmissionId) { success, submissionId, error in

                    if let error = error {
                        writeToStdOut("\tFailed: \(error.localizedDescription)\n")
                        queue.cancelAllOperations()
                    }
                    else {
                        writeToStdOut("\tSuccess\n")
                    }

                    Thread.sleep(forTimeInterval: 0.05)
                    
                    operation.complete()
                }
            }
            
            operation.completionBlock = {
                dispatchGroup.leave()
            }
            
            queue.addOperation(operation)
        }
        
    case .updateSubmission:
        break
    }
}
catch {
    writeToStdError("\(error)\n")
    showHelpAndExit()
}

dispatchGroup.notify(queue: .main) {
    exit(EXIT_SUCCESS)
}

dispatchMain()
