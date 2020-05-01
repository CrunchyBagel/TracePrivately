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

func getPlistPath(str: String) throws -> URL {
    
}

if CommandLine.arguments.count < 2 {
    showHelpAndExit()
}

let command = CommandLine.arguments[1]

switch command {
case "new":
    if CommandLine.arguments.count < 4 {
        showHelpAndExit()
    }
    
    let plistPath = try getPlistPath(str: CommandLine.arguments[1])
    
case "update":
    let plistPath = try getPlistPath(str: CommandLine.arguments[1])

default:
    showHelpAndExit()
}
