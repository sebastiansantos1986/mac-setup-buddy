//
//  EncryptionChecker.swift
//  Mac Setup Buddy
//
//  Utility to check FileVault encryption status
//

import Foundation

struct EncryptionChecker {
    static func checkFileVaultStatus() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/fdesetup"
        task.arguments = ["status"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            task.launch()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Debug output to see what fdesetup returns
            print("FileVault check output: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            
            // Check if FileVault is On
            let isEncrypted = output.contains("FileVault is On")
            print("Encryption status detected: \(isEncrypted)")
            
            return isEncrypted
        } catch {
            print("Error checking FileVault status: \(error)")
            return false
        }
    }
}
