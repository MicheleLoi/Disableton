import Foundation

// MARK: - Versioni e release

/// Versione dell'app: "0.1.<numero di build>". Il numero di build cresce a ogni verifica su GitHub.
public struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    public var components: [Int]

    public init(_ components: [Int]) {
        self.components = components
    }

    /// Accetta "0.1.12", "v0.1.12", "12".
    public init?(string: String) {
        var s = string.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        let parts = s.split(separator: ".").map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        components = parts.map { $0! }
    }

    public var description: String { components.map(String.init).joined(separator: ".") }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        let n = max(a.components.count, b.components.count)
        for i in 0..<n {
            let x = i < a.components.count ? a.components[i] : 0
            let y = i < b.components.count ? b.components[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    public static func == (a: AppVersion, b: AppVersion) -> Bool { !(a < b) && !(b < a) }
}

/// Ultima release pubblicata su GitHub (risposta di `/repos/{owner}/{repo}/releases/latest`).
public struct ReleaseInfo: Equatable, Sendable {
    public var version: AppVersion
    public var name: String
    public var notes: String
    public var pageURL: URL?
    public var appZipURL: URL

    public static let repository = "MicheleLoi/Disableton"
    public static var latestAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }

    /// nil se la risposta non contiene una versione valida o il file dell'app.
    public static func parse(_ data: Data, assetName: String = "Disableton.zip") -> ReleaseInfo? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String,
              let version = AppVersion(string: tag),
              let assets = object["assets"] as? [[String: Any]]
        else { return nil }
        let zip = assets.first { ($0["name"] as? String) == assetName }
        guard let urlString = zip?["browser_download_url"] as? String,
              let url = URL(string: urlString),
              url.scheme == "https",
              url.host == "github.com" || url.host?.hasSuffix(".githubusercontent.com") == true
        else { return nil }
        return ReleaseInfo(version: version,
                           name: object["name"] as? String ?? tag,
                           notes: object["body"] as? String ?? "",
                           pageURL: (object["html_url"] as? String).flatMap(URL.init(string:)),
                           appZipURL: url)
    }
}

// MARK: - Registro degli eventi

/// Registro testuale dell'app (in ~/Library/Logs/Disableton). Tiene in memoria le ultime righe
/// per il rapporto diagnostico. Da usare dal thread principale, mai dal thread della batteria.
public final class EventLog {
    public let fileURL: URL?
    public private(set) var recentLines: [String] = []
    private let maxRecent: Int
    private let maxFileBytes: Int
    private let formatter: DateFormatter

    public init(fileURL: URL?, maxRecent: Int = 300, maxFileBytes: Int = 2_000_000) {
        self.fileURL = fileURL
        self.maxRecent = maxRecent
        self.maxFileBytes = maxFileBytes
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        if let url = fileURL {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
    }

    public static var defaultURL: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        return library.appendingPathComponent("Logs/Disableton/Disableton.log")
    }

    public func log(_ message: String, date: Date = Date()) {
        let line = "\(formatter.string(from: date))  \(message)"
        recentLines.append(line)
        if recentLines.count > maxRecent { recentLines.removeFirst(recentLines.count - maxRecent) }
        guard let url = fileURL else { return }
        rotateIfNeeded(url)
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: url)
        }
    }

    private func rotateIfNeeded(_ url: URL) {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int,
              size > maxFileBytes else { return }
        let old = url.appendingPathExtension("1")
        try? FileManager.default.removeItem(at: old)
        try? FileManager.default.moveItem(at: url, to: old)
    }
}

// MARK: - Rapporto diagnostico

/// Testo da allegare a una segnalazione. Non contiene nomi di brani o groove (la segnalazione
/// su GitHub è pubblica) e sostituisce la cartella home con "~".
public struct DiagnosticReport {
    public var sections: [(title: String, lines: [String])] = []

    public init() {}

    public mutating func add(_ title: String, _ lines: [String]) {
        sections.append((title, lines))
    }

    public func text(homeDirectory: String = NSHomeDirectory()) -> String {
        var out: [String] = []
        for section in sections {
            out.append("### \(section.title)")
            out.append(contentsOf: section.lines)
            out.append("")
        }
        return DiagnosticReport.anonymize(out.joined(separator: "\n"), homeDirectory: homeDirectory)
    }

    public static func anonymize(_ text: String, homeDirectory: String) -> String {
        guard homeDirectory.count > 1 else { return text }
        return text.replacingOccurrences(of: homeDirectory, with: "~")
    }
}

/// Link a una nuova segnalazione precompilata su GitHub.
public enum IssueLink {
    /// GitHub accetta URL fino a circa 8000 caratteri: il corpo viene accorciato se serve,
    /// togliendo righe dal fondo del registro (le più vecchie stanno in alto e restano le ultime).
    public static func url(title: String, body: String, repository: String = ReleaseInfo.repository,
                           maxLength: Int = 7_500) -> URL {
        let base = "https://github.com/\(repository)/issues/new"
        func make(_ text: String) -> URL? {
            var components = URLComponents(string: base)!
            components.queryItems = [URLQueryItem(name: "title", value: title), URLQueryItem(name: "body", value: text)]
            return components.url
        }
        var text = body
        let note = "\n\n_(rapporto accorciato: quello completo è negli appunti, incollalo qui se serve)_"
        while let url = make(text), url.absoluteString.count > maxLength, text.count > 200 {
            var lines = text.components(separatedBy: "\n")
            let drop = max(1, lines.count / 10)
            lines.removeLast(min(drop, lines.count - 1))
            text = lines.joined(separator: "\n")
            if !text.hasSuffix(note) { text = String(text.prefix(max(0, text.count - note.count))) + note }
        }
        return make(text) ?? URL(string: base)!
    }
}

// MARK: - Crash

/// Rapporti di crash che macOS salva in ~/Library/Logs/DiagnosticReports.
public enum CrashReports {
    public static var defaultDirectory: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        return library.appendingPathComponent("Logs/DiagnosticReports")
    }

    /// File di crash dell'app più recenti di `date`, dal più nuovo.
    public static func find(in directory: URL = defaultDirectory, appName: String = "Disableton",
                            newerThan date: Date) -> [URL] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)
        else { return [] }
        let matches = files.compactMap { url -> (URL, Date)? in
            let name = url.lastPathComponent
            guard name.hasPrefix(appName + "-") || name.hasPrefix(appName + "_"),
                  ["ips", "crash", "hang", "spin"].contains(url.pathExtension),
                  let modified = (try? url.resourceValues(forKeys: Set(keys)))?.contentModificationDate,
                  modified > date
            else { return nil }
            return (url, modified)
        }
        return matches.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    /// Inizio del rapporto, sufficiente a capire dove si è fermata l'app.
    public static func excerpt(of url: URL, maxLines: Int = 80) -> String {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return "(file non leggibile)" }
        return text.components(separatedBy: "\n").prefix(maxLines).joined(separator: "\n")
    }
}
