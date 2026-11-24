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
| Nucleo (`GrooveCore`): file MIDI, groove, clock, motore groove/fill, comandi, libreria, modifica della libreria, MIDI Learn, clock interno per l'ascolto | compila; 53 test superati |
| Livello MIDI di macOS (`MIDIHost`): ingresso dal Krome, porta virtuale, thread di generazione | verificato in compilazione su GitHub (macOS); **da provare con il Krome** |
| App (`DisabletonApp`, SwiftUI): Preparazione, Comandi, Palco, Impostazioni | compilata e avviata su GitHub (con schermate); **da provare sul Mac** |
| Catena MIDI completa (Krome simulato → Disableton → EZdrummer simulato) | verificata su GitHub a 120 e 87 BPM: note e tempi corretti |
| Riga di comando (`disableton`): `inspect`, `ports`, `monitor`, `play`, `library` | come sopra |

Ogni modifica pubblicata viene verificata automaticamente su un Mac di GitHub (vedi
`.github/workflows/macos.yml`), in ordine: nucleo → MIDI → riga di comando → app → test →
app universale. Il primo passo che fallisce ferma i successivi.

## Requisiti

- macOS 12 Monterey o successivo, Intel o Apple Silicon
- EZdrummer 3 (applicazione autonoma)
- Korg Krome collegato via USB (oppure con un'interfaccia MIDI a 5 poli)
- Solo per compilare da sé: Xcode 14 o successivo (su Monterey: Xcode 14.2)

## Scaricare l'app già pronta

1. Su GitHub apri la scheda **Actions** del repository → l'ultima esecuzione riuscita di **macOS**.
2. In fondo, sotto **Artifacts**, scarica **Disableton-macOS** e scompattalo: contiene
   `Disableton.zip` (l'app) e `disableton-cli.zip` (la riga di comando).
3. Scompatta `Disableton.zip` e sposta **Disableton.app** in Applicazioni.
4. Al primo avvio macOS avvisa che lo sviluppatore non è identificato (l'app non è firmata con un
   certificato Apple): clic destro su Disableton.app → **Apri** → **Apri**. Solo la prima volta.

## L'app

Tre viste, scelte in alto (**Preparazione · Comandi · Palco**), più le **Impostazioni**
(ingranaggio, oppure ⌘,):

- **Preparazione**: scaletta dei brani (il numero corrisponde al Program Change dal Krome:
  brano 1 = PC 0), i groove del brano in ordine, la libreria (ricerca, filtro, importazione,
  ascolto) e il pannello dello slot selezionato: groove, comportamento (ripetuto, fill con
  ritorno, una volta poi il successivo, finale), momento del cambio, groove di avvio, tasto del
  Krome con **Impara**. I groove si aggiungono trascinandoli dalla libreria o con il "+".
- **Comandi**: la zona C2–B3 del Krome disegnata come tastiera, con lo stato di ogni tasto
  (suona, in coda, groove del brano, comando); clic su un tasto per cambiarne l'azione o
  reimpararlo; gli altri controlli (SW1, SW2, pedale, Program Change).
- **Palco**: schermata scura leggibile a 2–3 metri: brano, groove che suona, prossimo groove,
  battuta, battiti, tempo, brano successivo. Esc torna alla Preparazione; ⌃⌘F schermo intero.
- **Impostazioni**: ingresso dal Krome, clock interno per provare senza Krome, destinazione del
  suono, canale, anticipo della batteria, cartella della libreria, brani dimostrativi.

Ogni modifica viene salvata subito. Se il Krome sta suonando, le modifiche ai brani diventano
effettive allo Stop, per non disturbare l'esecuzione.

## Provare tutto senza EZdrummer 3

1. Apri l'app → Impostazioni → **Aggiungi brani dimostrativi** (rock, funk, shuffle, fill,
   finale, valzer, 6/8, generati dal programma).
2. Impostazioni → Suono della batteria → **Sintetizzatore integrato di macOS** (gratuito, già
   presente su ogni Mac), oppure **Kit di batteria del Krome** (una traccia del Krome con un kit
   di batteria che riceve sul canale 10).
3. Senza Krome: Impostazioni → Clock → **Avvia** (clock interno). Con il Krome: avvia il suo
   sequencer (GLOBAL → MIDI → MIDI Clock = Internal).
4. Prova cambi di groove, fill e brani dalla tastiera del Krome (canale 16, vedi la vista
   Comandi) o con un clic nella Preparazione.

Quando avrai EZdrummer 3 basterà scegliere "EZdrummer 3" come destinazione del suono e abilitare
l'ingresso "Disableton" nelle sue impostazioni MIDI.

## Compilazione (facoltativa)

```sh
git clone https://github.com/MicheleLoi/Disableton.git
cd Disableton
git checkout ccr-900483bd-tiua7z
swift build -c release
swift test
scripts/build-app.sh        # crea dist/Disableton.app universale
```

Il programma a riga di comando si trova in `.build/release/disableton` (o in `dist/`). Negli
esempi seguenti è abbreviato in `disableton`.

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
