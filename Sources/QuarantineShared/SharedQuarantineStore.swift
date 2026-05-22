import Foundation
import WidgetKit

public enum SharedQuarantineStore {
    private static let filename = "shared-quarantine.json"

    public static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(filename)
    }

    public static func write(_ state: SharedQuarantine) {
        guard let url = fileURL,
              let data = try? JSONEncoder().encode(state)
        else { return }
        _ = try? data.write(to: url, options: [.atomic])
        WidgetCenter.shared.reloadAllTimelines()
    }

    public static func read() -> SharedQuarantine {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(
                  SharedQuarantine.self, from: data)
        else { return SharedQuarantine() }
        return state
    }
}
