# Disableton

Gestore di groove MIDI di batteria per una **workstation** (sviluppato e provato con un Korg Krome)
su macOS.

La workstation resta il master: invia clock, Start/Stop e i comandi. Disableton conserva la
libreria dei groove, li suona agganciati al clock della workstation e li invia a uno strumento di
batteria: uno strumento software o una DAW attraverso la porta MIDI virtuale «Disableton», il
sintetizzatore di macOS, oppure un kit di batteria della workstation stessa.

**Istruzioni per l'uso: [docs/ISTRUZIONI.md](docs/ISTRUZIONI.md)** (anche dal menu Aiuto dell'app).

Le scelte di progetto sono descritte in [docs/ARCHITETTURA.md](docs/ARCHITETTURA.md).

## Stato

| Parte | Stato |
|---|---|
| Nucleo (`GrooveCore`): file MIDI, groove, clock, motore groove/fill, comandi, libreria, modifica della libreria, MIDI Learn, clock interno per l'ascolto | compila; 75 test superati |
| Livello MIDI di macOS (`MIDIHost`): ingresso dalla workstation, porta virtuale, thread di generazione | verificato in compilazione su GitHub (macOS); **da provare con la workstation** |
| App (`DisabletonApp`, SwiftUI): Preparazione, Comandi, Palco, Impostazioni | compilata e avviata su GitHub (con schermate); **da provare sul Mac** |
| Catena MIDI completa (workstation simulata → Disableton → strumento simulato) | verificata su GitHub a 120 e 87 BPM: note e tempi corretti |
| Riga di comando (`disableton`): `inspect`, `ports`, `monitor`, `play`, `library` | come sopra |

Ogni modifica pubblicata viene verificata automaticamente su un Mac di GitHub (vedi
`.github/workflows/macos.yml`), in ordine: nucleo → MIDI → riga di comando → app → test →
app universale. Il primo passo che fallisce ferma i successivi.

## Requisiti

- macOS 12 Monterey o successivo, Intel o Apple Silicon
- Uno strumento di batteria: software (app o plugin in una DAW), il sintetizzatore di macOS o un
  kit della workstation
- Una workstation (es. Korg Krome) collegata via USB (oppure con un'interfaccia MIDI a 5 poli)
- Solo per compilare da sé: Xcode 14 o successivo (su Monterey: Xcode 14.2)

## Scaricare l'app già pronta

Ogni versione che supera tutte le verifiche viene pubblicata come release su GitHub.

1. Scarica **https://github.com/MicheleLoi/Disableton/releases/latest/download/Disableton.zip**
   (link fisso, sempre all'ultima versione; meglio con Firefox sui Mac con Monterey).
2. Scompatta e sposta **Disableton.app** in Applicazioni.
3. Al primo avvio macOS avvisa che lo sviluppatore non è identificato (l'app non è firmata con un
   certificato Apple): clic destro su Disableton.app → **Apri** → **Apri**. Solo la prima volta.

Dopo la prima installazione non serve più scaricare a mano: all'avvio Disableton controlla se c'è
una nuova versione e mostra **Aggiorna a …** in alto; un clic la scarica, la verifica,
sostituisce l'app e la riavvia (non durante l'esecuzione: prima va fermata la workstation).

## Segnalare un problema

Menu **Aiuto → Segnala un problema…** (oppure Impostazioni → Assistenza): scrivi cosa è successo e
premi **Apri la segnalazione su GitHub**. Si apre nel browser una segnalazione già compilata con
versione, impostazioni, porte MIDI e registro degli eventi (senza nomi di brani o groove); basta
premere *Submit*. Se Disableton si chiude per un errore, al riavvio propone da solo la segnalazione
con il rapporto di macOS.

Il registro degli eventi è in `~/Library/Logs/Disableton/Disableton.log`.

## L'app

Tre viste, scelte in alto (**Preparazione · Comandi · Palco**), più le **Impostazioni**
(ingranaggio, oppure ⌘,):

- **Preparazione**: scaletta dei brani con i pulsanti + − ↑ ↓ (il numero corrisponde al Program
  Change dalla workstation: brano 1 = PC 0), i groove del brano in ordine, la libreria (ricerca, filtro, importazione,
  ascolto) e il pannello dello slot selezionato: groove, comportamento (ripetuto, fill con
  ritorno, una volta poi il successivo, finale), momento del cambio, groove di avvio, tasto del
  workstation con **Impara**. I groove si aggiungono trascinandoli dalla libreria o con il "+".
- **Comandi**: la zona C1–B2 della workstation disegnata come tastiera, con lo stato di ogni tasto
  (suona, in coda, groove del brano, comando); clic su un tasto per cambiarne l'azione o
  reimpararlo; gli altri controlli (SW1, SW2, pedale, Program Change).
- **Palco**: schermata scura leggibile a 2–3 metri: brano, groove che suona, prossimo groove,
  battuta, battiti, tempo, brano successivo. Esc torna alla Preparazione; ⌃⌘F schermo intero.
- **Impostazioni**: ingresso dalla workstation, clock interno per provare senza workstation, destinazione del
  suono, canale, anticipo della batteria, cartella della libreria, assistenza e aggiornamenti.

Ogni modifica viene salvata subito. Se la workstation sta suonando, le modifiche ai brani diventano
effettive allo Stop, per non disturbare l'esecuzione.

## Provare tutto senza workstation

Guida passo passo: [docs/PROVA-SENZA-WORKSTATION.md](docs/PROVA-SENZA-WORKSTATION.md). In breve:

1. Scarica i file MIDI di prova (non fanno parte dell'app):
   https://github.com/MicheleLoi/Disableton/releases/latest/download/Groove-di-prova.zip
2. Importali con **Importa .mid…** e prepara qualche brano nella Preparazione.
3. Impostazioni → Suono della batteria → **Sintetizzatore integrato di macOS** (gratuito) oppure
   **Kit di batteria della workstation**.
4. Senza workstation: Impostazioni → Clock → **Avvia**. Con la workstation: avvia il suo sequencer
   (MIDI Clock su Internal; sul Krome: GLOBAL → P1: MIDI → MIDI Clock).

Per uno strumento software o una DAW basta scegliere la porta virtuale «Disableton» come
destinazione del suono e selezionare «Disableton» come ingresso MIDI nello strumento.

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

## Fase 0: verifiche con la workstation

### 1. Clock e trasporto

Sulla workstation il **MIDI Clock va su Internal** (sul Krome: **GLOBAL → P1: MIDI → MIDI Clock**).

```sh
disableton ports                    # trova il nome della porta della workstation
disableton monitor --input NOME    # sostituisci con il nome mostrato da "ports"
```

Avvia e ferma il sequencer della workstation, poi sposta la posizione e premi di nuovo Play. Devono
comparire:

- `Start`, `Stop`, `Continue`, `SongPos`;
- una riga `Clock: … BPM, scarto max impulsi ±… ms` per ogni quarto.

**Da annotare:** il tempo misurato confrontato con quello della workstation, e lo scarto massimo degli
impulsi.

### 2. Comandi dalla workstation

In un brano della workstation imposta una traccia come esterna (**EXT** o **BTH**) sul **canale 16** e
registra alcune note tra C1 e B2. Con `monitor` attivo devono arrivare dei `NoteOn ch16`.
Prova anche SW1/SW2 e il pedale, se li hai assegnati a controller (CC80/81/82).

### 3. Groove da un programma di batteria

Esporta 2 o 3 groove come file MIDI sulla Scrivania (un groove, un fill e una variante), poi:

```sh
disableton inspect ~/Desktop/NomeGroove.mid
```

**Da annotare:** lunghezza in battute, battute vuote iniziali, note usate e anticipi.

### 4. Prova decisiva: groove agganciato alla workstation

```sh
disableton play --input NOME --loop ~/Desktop/Strofa.mid --loop ~/Desktop/Ritornello.mid --fill ~/Desktop/Fill.mid
```

Nello strumento di batteria seleziona l'ingresso MIDI **Disableton**.

Avvia il sequencer della workstation: il primo groove parte sul primo battere. Con note sul canale 16:

| Nota (Korg) | Numero | Azione |
|---|---|---|
| C1, C#1, D1… B1 | 24, 25, 26… 35 | slot 1, 2, 3… 12 (cambio alla battuta successiva) |
| C2 | 36 | avvia: la batteria parte al tempo della workstation anche senza Start (es. in Combi); ignorato se sta già suonando |
| C#2 / D#2 | 37 / 39 | groove precedente / successivo |
| D2 | 38 | fill, poi ritorno al groove precedente |
| E2 | 40 | pausa: silenzio dalla battuta successiva, si riprende a tempo con un loop o Avvia |
| F2 | 41 | stop vero: la batteria si ferma subito e riparte con Avvia (succede da solo anche dopo il Finale) |
| F#2 / G#2 | 42 / 44 | brano precedente / successivo |
| G2 | 43 | finale: il groove «Finale, poi silenzio» del brano (senza finale: silenzio a fine battuta) |
| Program Change n | – | brano n+1 |
| SW1, SW2, pedale | – | nessun comando predefinito: si assegnano con **Impara** |

Lascialo suonare per almeno 10 minuti, cambiando tempo, fermando e ripartendo, anche da metà
brano.

Se la batteria arriva in ritardo rispetto alla workstation, anticipala con `--latency-ms 5` (per
esempio).

### 5. Libreria

```sh
disableton library init
disableton library import ~/Desktop/Strofa.mid ~/Desktop/Ritornello.mid ~/Desktop/Fill.mid
disableton library add-song "Primo brano"
disableton library assign 1 Strofa
disableton library assign 1 Ritornello
disableton library assign 1 Fill --mode fill
disableton library show
disableton play --library --input NOME
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
