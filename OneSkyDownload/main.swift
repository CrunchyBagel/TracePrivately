//
//  main.swift
//  OneSkyDownload
//

import Foundation
import CryptoKit

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

// TODO: Use ArgumentParser library when it's available

if CommandLine.arguments.count < 6 {
    writeToStdError(String(format: "%@ [api key] [api secret] [project id] [filename] [locale]\n", CommandLine.arguments[0]))
    exit(EXIT_FAILURE)
}

let apiKey: String     = CommandLine.arguments[1]
let apiSecret: String  = CommandLine.arguments[2]
let projectId: String  = CommandLine.arguments[3]
let filename: String   = CommandLine.arguments[4]
let localeName: String = CommandLine.arguments[5]

let dispatchGroup = DispatchGroup()


// https://github.com/onesky/api-documentation-platform/blob/master/README.md#authentication
// devHash: md5(concatenate(<timestamp>, <api_secret>))

let now            = Date()
let timestamp: Int = Int(now.timeIntervalSince1970)
let timestampStr   = "\(timestamp)"
let devHashStr     = timestampStr + apiSecret
let devHash        = Insecure.MD5.hash(data: Data(devHashStr.utf8))

let authData: [String: String] = [
    "api_key": apiKey,
    "timestamp": timestampStr,
    "dev_hash" : devHash.compactMap { String(format: "%02x", $0) }.joined()
]

do {
    //URLSession.shared

    var queryItems: [URLQueryItem] = [
        URLQueryItem(name: "locale", value: localeName),
        URLQueryItem(name: "source_file_name", value: filename)
    ]
    
    authData.forEach { queryItems.append(URLQueryItem(name: $0.key, value: $0.value)) }
    
    var components = URLComponents()
    components.scheme = "https"
    components.host = "platform.api.onesky.io"
    components.path = "/1/projects/\(projectId)/translations"
    components.queryItems = queryItems
    
    guard let url = components.url else {
        throw "Unable to create URL"
    }
    
//    writeToStdError("Requesting \(url) ...")
    
    var request = URLRequest(
        url: url,
        cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
        timeoutInterval: 30
    )

    request.httpMethod = "GET"
    

    let requestData: [String: Any] = [:]

    if requestData.count > 0 {
        let jsonData = try JSONSerialization.data(withJSONObject: requestData, options: [])

        request.httpBody = jsonData
        request.setValue(String(jsonData.count), forHTTPHeaderField: "Content-Length")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    dispatchGroup.enter()
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer {
            dispatchGroup.leave()
        }
        
        do {
            if let error = error {
                throw error
            }

            guard let response = response as? HTTPURLResponse else {
                throw "Not a valid response"
            }
            
            guard let data = data else {
                throw "Data not received"
            }
            
            switch response.statusCode {
            case 200:
                if let str = String(data: data, encoding: .utf8) {
                    writeToStdOut(str)
                }
                else {
                    throw "Unable to turn response into string"
                }

            default:
                if let str = String(data: data, encoding: .utf8) {
                    writeToStdError(str)
                }

                throw "Unhandled response with code: \(response.statusCode)"
            }
        }
        catch {
            writeToStdError("\(error)")
            exit(EXIT_FAILURE)
        }
    }
    
    task.resume()
}
catch {
    writeToStdError("\(error)")
    exit(EXIT_FAILURE)
}

dispatchGroup.notify(queue: .main) {
    exit(EXIT_SUCCESS)
}

dispatchMain()
