//
//  SupportReportExporter.swift
//  Mac Setup Buddy
//
//  Creates support-friendly setup reports for IT handoff.
//

import Foundation

enum SupportReportExporter {
    static func exportErrorReport(
        error: InstallationError,
        policyName: String?,
        diagnosticInfo: String
    ) throws -> URL {
        let report: [String: String] = [
            "reportType": "error",
            "createdAt": timestamp(),
            "computerName": Host.current().localizedName ?? "Unknown",
            "errorTitle": error.title,
            "errorDescription": error.description,
            "policyName": policyName ?? "Unknown",
            "diagnosticInfo": diagnosticInfo
        ]

        return try writeReport(report, prefix: "MacSetupBuddy_Error_Report")
    }

    static func exportCompletionReport(config: CommandLineConfig) throws -> URL {
        let report: [String: String] = [
            "reportType": "completion",
            "createdAt": timestamp(),
            "computerName": Host.current().localizedName ?? "Unknown",
            "userName": config.userName ?? "Unknown",
            "email": config.email ?? "Unknown",
            "department": config.userDepartment ?? "Unknown",
            "title": config.userTitle ?? "Unknown",
            "assetTag": config.assetTag ?? "Unknown",
            "deviceName": config.deviceName ?? "Unknown",
            "deviceModel": config.deviceModel ?? "Unknown",
            "serialNumber": config.serialNumber ?? "Unknown",
            "osVersion": config.osVersion ?? "Unknown",
            "fileVault": (config.isEncrypted ?? false) ? "Enabled" : "Not Enabled",
            "status": "Setup Complete"
        ]

        return try writeReport(report, prefix: "MacSetupBuddy_Completion_Report")
    }

    private static func writeReport(_ report: [String: String], prefix: String) throws -> URL {
        let destination = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let fileName = "\(prefix)_\(fileTimestamp()).json"
        let fileURL = destination.appendingPathComponent(fileName)

        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
