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
        // Livello MIDI di macOS (CoreMIDI): ingresso dalla workstation, porta virtuale, thread di generazione.
        .target(name: "MIDIHost", dependencies: ["GrooveCore"]),
        // Groove di prova per test e verifiche: non fa parte dell'app.
        .target(name: "TestMaterial", dependencies: ["GrooveCore"]),
        // Strumento a riga di comando: ispezione file, libreria, monitor MIDI, riproduzione, prove.
        .executableTarget(name: "disableton", dependencies: ["GrooveCore", "MIDIHost", "TestMaterial"]),
        // App con interfaccia grafica (SwiftUI).
        .executableTarget(name: "DisabletonApp", dependencies: ["GrooveCore", "MIDIHost"]),
        .testTarget(name: "GrooveCoreTests", dependencies: ["GrooveCore", "TestMaterial"]),
    ]
)
