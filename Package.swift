// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Disableton",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GrooveCore", targets: ["GrooveCore"]),
        .executable(name: "disableton", targets: ["disableton"]),
    ],
    targets: [
        // Nucleo indipendente dalla piattaforma: file MIDI, groove, clock, motore, libreria.
        .target(name: "GrooveCore"),
        // Strumento a riga di comando: ispezione file, libreria, monitor MIDI, riproduzione.
        // Le parti CoreMIDI sono compilate solo su macOS.
        .executableTarget(name: "disableton", dependencies: ["GrooveCore"]),
        .testTarget(name: "GrooveCoreTests", dependencies: ["GrooveCore"]),
    ]
)
