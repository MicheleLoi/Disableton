import Foundation
import GrooveCore

let usage = """
Disableton — groove MIDI per EZdrummer 3 sincronizzati al Korg Krome

Uso:
  disableton inspect <file.mid> [--bars N] [--meter 4/4] [--no-trim]
      Analizza un groove: lunghezza, note usate, battute vuote, anticipi.

  disableton ports
      Elenca le porte MIDI disponibili.

  disableton monitor [--input nome] [--show-clock]
      Mostra i messaggi in arrivo e misura tempo e stabilità del clock.

  disableton play --loop a.mid [--loop b.mid] [--fill f.mid] [--ending e.mid] [--meter 4/4]
  disableton play --library [--dir cartella] [--song N]
      Segue il clock del Krome e suona i groove sulla porta virtuale "Disableton".
      Opzioni: --input nome, --channel 10, --latency-ms 0, --lookahead-ms 2, --no-autostart,
               --sound ezdrummer|synth|krome (--dest nome della destinazione MIDI, predefinito KROME)

  disableton selftest [--seconds 5] [--bpm 120]
      Verifica senza Krome: priorità tempo reale e puntualità del ciclo di generazione.

  disableton e2e [--bpm 120]
      Prova della catena completa con un Krome e un EZdrummer simulati (porte virtuali).

  disableton demo [--dir cartella] | demo --export cartella
      Aggiunge brani e groove dimostrativi alla libreria, oppure li scrive come file .mid.

  disableton library init|import|add-song|assign|show [--dir cartella]
      import <file.mid>... [--ezd] [--bars N] [--meter M] [--name X]
      add-song "Nome" [--meter 3/4]
      assign <n. brano> <nome groove> [--mode loop|fill|next|ending] [--quantize beat|bar|end]

Comandi predefiniti dal Krome (canale 16, nomi Korg: 36 = C2):
  Program Change n → brano n+1   note 36…47 → slot 1…12   48 fill   50 groove successivo
  49/51 brano precedente/successivo   52 silenzio a fine battuta   59 panic
  CC80 (SW1) fill   CC81 (SW2) groove successivo   CC82 (pedale) fill
"""

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    print(usage)
    exit(0)
}
let rest = Array(arguments.dropFirst())

do {
    switch command {
    case "inspect": try runInspect(rest)
    case "library": try runLibrary(rest)
    case "ports": try runPorts()
    case "monitor": try runMonitor(rest)
    case "play": try runPlay(rest)
    case "selftest": try runSelfTest(rest)
    case "e2e": try runEndToEnd(rest)
    case "demo": try runDemo(rest)
    case "help", "-h", "--help": print(usage)
    default:
        throw CLIError("comando sconosciuto: \(command)\n\n\(usage)")
    }
} catch {
    FileHandle.standardError.write("Errore: \(error)\n".data(using: .utf8)!)
    exit(1)
}
