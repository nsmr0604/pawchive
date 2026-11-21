import UIKit

@main
@MainActor
final class IOSProbeApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = ProbeViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

@MainActor
private final class ProbeViewController: UIViewController {
    private let status = UILabel()
    private var picker: IOSLocalePicker?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        status.text = "Choose a Files test."
        status.numberOfLines = 0

        let open = UIButton(type: .system)
        open.setTitle("Open JSON", for: .normal)
        open.addAction(UIAction { [weak self] _ in self?.showPicker() }, for: .touchUpInside)
        let export = UIButton(type: .system)
        export.setTitle("Export fixture JSON", for: .normal)
        export.addAction(UIAction { [weak self] _ in self?.startExport() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [open, export, status])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -20)
        ])
    }

    private func startExport() {
        guard picker == nil else { return }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent("pawkemoviewer-files-probe.json")
            try Data(#"{"locale.name":"Files Probe","probe":"ok"}"#.utf8).write(to: file, options: .atomic)
            showPicker(exportFile: file)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            status.text = "Could not stage the export."
        }
    }

    private func showPicker(exportFile: URL? = nil) {
        guard picker == nil else { return }
        let picker = IOSLocalePicker(exportFile: exportFile) { [weak self] outcome in
            if let exportFile {
                try? FileManager.default.removeItem(at: exportFile.deletingLastPathComponent())
            }
            guard let self else { return }
            self.picker = nil
            switch outcome {
            case .imported(let json): self.status.text = "Read \(json.utf8.count) UTF-8 bytes"
            case .exported: self.status.text = "Export complete"
            case .cancelled: self.status.text = "Cancelled"
            case .failed(let error): self.status.text = "Failed: \(type(of: error))"
            }
        }
        self.picker = picker
        present(picker.makePicker(), animated: true)
    }
}
