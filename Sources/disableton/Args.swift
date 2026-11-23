import Foundation
import GrooveCore

struct CLIError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

/// Parser minimale: `--nome valore`, flag booleani e argomenti posizionali.
struct Args {
    private(set) var positionals: [String] = []
    private var options: [String: [String]] = [:]
    private var flags: Set<String> = []

    init(_ argv: [String], flags flagNames: Set<String> = []) throws {
        var i = 0
        while i < argv.count {
            let arg = argv[i]
            if arg.hasPrefix("--") {
                let name = String(arg.dropFirst(2))
                if flagNames.contains(name) {
                    flags.insert(name)
                } else {
                    guard i + 1 < argv.count else { throw CLIError("manca il valore per --\(name)") }
                    options[name, default: []].append(argv[i + 1])
                    i += 1
                }
            } else {
                positionals.append(arg)
            }
            i += 1
        }
    }

    func value(_ name: String) -> String? { options[name]?.last }
    func values(_ name: String) -> [String] { options[name] ?? [] }
    func flag(_ name: String) -> Bool { flags.contains(name) }

    func int(_ name: String) throws -> Int? {
        guard let v = value(name) else { return nil }
        guard let n = Int(v) else { throw CLIError("--\(name) richiede un numero intero") }
        return n
    }

    func double(_ name: String) throws -> Double? {
        guard let v = value(name) else { return nil }
        guard let n = Double(v.replacingOccurrences(of: ",", with: ".")) else { throw CLIError("--\(name) richiede un numero") }
        return n
    }

    func timeSignature(_ name: String) throws -> TimeSignature? {
        guard let v = value(name) else { return nil }
        guard let ts = TimeSignature(string: v) else { throw CLIError("metro non valido: \(v) (es. 4/4, 3/4, 6/8)") }
        return ts
    }

    func positional(_ index: Int, _ what: String) throws -> String {
        guard index < positionals.count else { throw CLIError("manca \(what)") }
        return positionals[index]
    }
}

