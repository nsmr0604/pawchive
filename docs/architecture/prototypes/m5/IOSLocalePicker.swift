import Foundation
import UIKit
import UniformTypeIdentifiers

// Standalone copy-based probe. The host must retain the delegate while the picker is shown.
@MainActor
final class IOSLocalePicker: NSObject, UIDocumentPickerDelegate {
    enum Outcome {
        case imported(String)
        case exported
        case cancelled
        case failed(Error)
    }

    enum ProbeError: Error {
        case missingSelection
        case invalidUTF8
        case oversizedFile
    }

    private static let maxBytes = 1024 * 1024
    private let exportFile: URL?
    private var finish: ((Outcome) -> Void)?

    init(exportFile: URL? = nil, finish: @escaping (Outcome) -> Void) {
        // For export the host stages a private JSON file and removes it after completion.
        self.exportFile = exportFile
        self.finish = finish
    }

    func makePicker() -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        if let exportFile {
            picker = UIDocumentPickerViewController(forExporting: [exportFile], asCopy: true)
        } else {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        }
        picker.allowsMultipleSelection = false
        picker.delegate = self
        return picker
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        complete(.cancelled)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            complete(.failed(ProbeError.missingSelection))
            return
        }
        if exportFile != nil {
            complete(.exported)
            return
        }
        do {
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            var bytes = Data()
            while let chunk = try file.read(upToCount: 8192), !chunk.isEmpty {
                guard chunk.count <= Self.maxBytes - bytes.count else {
                    throw ProbeError.oversizedFile
                }
                bytes.append(chunk)
            }
            guard let json = String(data: bytes, encoding: .utf8) else { throw ProbeError.invalidUTF8 }
            complete(.imported(json))
        } catch {
            complete(.failed(error))
        }
    }

    private func complete(_ outcome: Outcome) {
        let callback = finish
        finish = nil
        callback?(outcome)
    }
}
