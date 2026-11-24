// swift-tools-version:5.7
// 5.7 = Xcode 14: permette di compilare anche su un Mac Intel con macOS 12 Monterey.
import PackageDescription

let package = Package(
    name: "Disableton",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "GrooveCore", targets: ["GrooveCore"]),
        .executable(name: "disableton", targets: ["disableton"]),
        .executable(name: "DisabletonApp", targets: ["DisabletonApp"]),
    ],
    targets: [
        // Nucleo indipendente dalla piattaforma: file MIDI, groove, clock, motore, libreria.
        .target(name: "GrooveCore"),
        // Livello MIDI di macOS (CoreMIDI): ingresso dal Krome, porta virtuale, thread di generazione.
        .target(name: "MIDIHost", dependencies: ["GrooveCore"]),
        // Strumento a riga di comando: ispezione file, libreria, monitor MIDI, riproduzione.
        .executableTarget(name: "disableton", dependencies: ["GrooveCore", "MIDIHost"]),
        // App con interfaccia grafica (SwiftUI).
        .executableTarget(name: "DisabletonApp", dependencies: ["GrooveCore", "MIDIHost"]),
        .testTarget(name: "GrooveCoreTests", dependencies: ["GrooveCore"]),
    ]
)
