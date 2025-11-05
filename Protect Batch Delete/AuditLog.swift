import Foundation
import CryptoKit
import AppKit

struct AuditEntry: Codable {
    let timestamp: String
    let actor: String
    let action: String // e.g., "delete"
    let source: String // e.g., "csv" or "fetch"
    let serial: String
    let uuid: String
    let hostName: String
    let outcome: String // "success" or "failure"
    let responseCode: Int?
    let error: String?
}

struct SignedAuditEnvelope: Codable {
    let entries: [AuditEntry]
    let signatureBase64: String
    let publicKeyBase64: String
    let algorithm: String // e.g., "P256-SHA256"
}

final class AuditLogStore: ObservableObject {
    @Published private(set) var entries: [AuditEntry] = []

    private let keyService = "co.uk.mallion.jamfprotect-batch-delete.audit"
    private let keyAccount = "privateKey"

    func append(_ entry: AuditEntry) {
        entries.append(entry)
    }

    func clear() {
        entries.removeAll()
    }

    func exportSignedAuditLog() {
        guard entries.isEmpty == false else { return }
        do {
            // Serialize entries as canonical JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let payload = try encoder.encode(entries)

            // Load or create signing key
            let privKey = try loadOrCreatePrivateKey()
            let signature = try sign(data: payload, with: privKey)
            let publicKey = privKey.publicKey

            // Prepare envelope
            let envelope = SignedAuditEnvelope(
                entries: entries,
                signatureBase64: Data(signature).base64EncodedString(),
                publicKeyBase64: publicKey.derRepresentation.base64EncodedString(),
                algorithm: "P256-SHA256"
            )
            let envelopeData = try JSONEncoder().encode(envelope)

            // Save via NSSavePanel
            let panel = NSSavePanel()
            panel.allowedContentTypes = [ .json ]
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions.insert(.withFractionalSeconds)
            let ts = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
            panel.nameFieldStringValue = "audit-log-\(ts).json"
            panel.canCreateDirectories = true
            if panel.runModal() == .OK, let url = panel.url {
                try envelopeData.write(to: url, options: .atomic)
            }
        } catch {
            // Best-effort alert
            let alert = NSAlert()
            alert.messageText = "Export Error"
            alert.informativeText = "Could not export signed audit log.\n\n\(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    // MARK: - Signing helpers
    private func loadOrCreatePrivateKey() throws -> P256.Signing.PrivateKey {
        // Try to load from Keychain helper as base64 string
        let creds = Keychain().retrieve(service: keyService)
        if creds.count == 2, creds[0] == keyAccount, let data = Data(base64Encoded: creds[1]) {
            if let key = try? P256.Signing.PrivateKey(rawRepresentation: data) {
                return key
            }
        }
        // Create new key and persist
        let newKey = P256.Signing.PrivateKey()
        let raw = newKey.rawRepresentation
        let b64 = Data(raw).base64EncodedString()
        Keychain().save(service: keyService, account: keyAccount, data: b64)
        return newKey
    }

    private func sign(data: Data, with key: P256.Signing.PrivateKey) throws -> Data {
        let signature = try key.signature(for: SHA256.hash(data: data))
        return signature.derRepresentation
    }
}
