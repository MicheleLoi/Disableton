# Disableton

Gestore di groove MIDI per **Korg Krome** + **EZdrummer 3** su macOS.

Il Krome resta il master: invia clock, Start/Stop e i comandi di selezione. Disableton conserva
la libreria dei groove (quelli esportati da EZdrummer 3 e quelli personali), li suona agganciati
al clock del Krome e li invia a EZdrummer 3 attraverso una porta MIDI virtuale. EZdrummer 3
funziona come applicazione autonoma e fa solo da generatore sonoro.

Le scelte di progetto sono descritte in [docs/ARCHITETTURA.md](docs/ARCHITETTURA.md).

## Stato

| Parte | Stato |
|---|---|
| Nucleo (`GrooveCore`): file MIDI, groove, inseguimento del clock, motore groove/fill, comandi, libreria | scritto, con test; **da compilare e verificare su Mac** |
| Riga di comando (`disableton`): `inspect`, `ports`, `monitor`, `play`, `library` | scritta; **da verificare su Mac con il Krome** |
| Interfaccia grafica (SwiftUI) | da fare, dopo le verifiche della Fase 0 |

## Requisiti

- macOS 13 o successivo, Intel o Apple Silicon
- Xcode 15 o successivo, oppure i Command Line Tools (`xcode-select --install`)
- EZdrummer 3 (applicazione autonoma)
- Korg Krome collegato via USB (oppure con un'interfaccia MIDI a 5 poli)

## Compilazione

```sh
git clone https://github.com/MicheleLoi/Disableton.git
cd Disableton
git checkout ccr-900483bd-tiua7z
swift build -c release
swift test
```

Il programma compilato si trova in `.build/release/disableton`. Negli esempi seguenti è
abbreviato in `disableton`. Per usarlo così: `alias disableton=$PWD/.build/release/disableton`.

## Fase 0: verifiche con il Krome

### 1. Clock e trasporto

Sul Krome: **GLOBAL → MIDI → MIDI Clock = Internal**.

```sh
disableton ports                    # trova il nome della porta del Krome
disableton monitor --input KROME    # sostituisci con il nome mostrato da "ports"
```

Avvia e ferma il sequencer del Krome, poi sposta la posizione e premi di nuovo Play. Devono
comparire:

- `Start`, `Stop`, `Continue`, `SongPos`;
- una riga `Clock: … BPM, scarto max impulsi ±… ms` per ogni quarto.

**Da annotare:** il tempo misurato confrontato con quello del Krome, e lo scarto massimo degli
impulsi.

### 2. Comandi dal Krome

In un brano del Krome imposta una traccia come esterna (**EXT** o **BTH**) sul **canale 16** e
registra alcune note tra C2 e C3. Con `monitor` attivo devono arrivare dei `NoteOn ch16`.
Prova anche SW1/SW2 e il pedale, se li hai assegnati a controller (CC80/81/82).

### 3. Groove esportati da EZdrummer 3

Trascina 2 o 3 groove dal browser di EZdrummer 3 sulla Scrivania (un groove, un fill e una
variante), poi:

```sh
disableton inspect ~/Desktop/NomeGroove.mid
```

**Da annotare:** lunghezza in battute, battute vuote iniziali, note usate e anticipi.

### 4. Prova decisiva: groove agganciato al Krome

```sh
disableton play --input KROME --loop ~/Desktop/Strofa.mid --loop ~/Desktop/Ritornello.mid --fill ~/Desktop/Fill.mid
```

In EZdrummer 3: **Settings → MIDI** → abilita l'ingresso **Disableton**.

Avvia il sequencer del Krome: il primo groove parte sul primo battere. Con note sul canale 16:

| Nota (Korg) | Numero | Azione |
|---|---|---|
| C2, C#2, D2… | 36, 37, 38… | slot 1, 2, 3… (cambio alla battuta successiva) |
| C3 | 48 | fill, poi ritorno al groove precedente |
| D3 | 50 | groove successivo |
| E3 | 52 | silenzio dalla battuta successiva |
| B3 | 59 | panic (spegne tutte le note) |
| C#3 / D#3 | 49 / 51 | brano precedente / successivo |
| Program Change n | – | brano n+1 |
| CC80 (SW1), CC82 (pedale) | – | fill |
| CC81 (SW2) | – | groove successivo |

Lascialo suonare per almeno 10 minuti, cambiando tempo, fermando e ripartendo, anche da metà
brano.

Se la batteria arriva in ritardo rispetto al Krome, anticipala con `--latency-ms 5` (per
esempio).

### 5. Libreria

```sh
disableton library init
disableton library import --ezd ~/Desktop/Strofa.mid ~/Desktop/Ritornello.mid ~/Desktop/Fill.mid
disableton library add-song "Primo brano"
disableton library assign 1 Strofa
disableton library assign 1 Ritornello
disableton library assign 1 Fill --mode fill
disableton library show
disableton play --library --input KROME
```

La libreria si trova in `~/Library/Application Support/Disableton`: un file `library.json`
più le copie dei file MIDI. Il file JSON si può anche modificare a mano.

Modalità degli slot (`--mode`):

- `loop`: si ripete;
- `fill`: suona una volta, poi torna al groove precedente;
- `next`: suona una volta, poi passa allo slot successivo;
- `ending`: suona una volta, poi silenzio.

Momento del cambio (`--quantize`): `bar` (battuta, predefinito), `beat` (battito), `end`
(fine del groove in corso).
