# Architettura

## Decisioni

1. **La workstation è il master.** Invia MIDI clock (24 impulsi per quarto), Start, Stop, Continue
   e Song Position Pointer. Disableton non ha un tempo proprio.
2. **I groove li suona Disableton, non lo strumento di batteria.** Molti strumenti di batteria
   aperti come applicazione autonoma non si sincronizzano a un clock esterno. Ricevono quindi le
   note già sincronizzate da una porta MIDI virtuale (`Disableton`), oppure da una DAW che ospita
   lo strumento come plugin.
3. **I groove si importano come file `.mid`** e vengono copiati nella libreria. Non si leggono
   formati proprietari.
4. **Ardour e altri progetti open source sono stati valutati e scartati come base.** Ardour
   segue il clock esterno variando la velocità di riproduzione invece di adottarne il tempo, ci
   sono problemi segnalati con Start/Stop, e manca l'indirezione brano → groove. Si riusano
   invece le librerie di sistema (CoreMIDI, Foundation) e si scrive solo la logica specifica.
5. **Il nucleo è indipendente dalla piattaforma** (`GrooveCore`, solo Foundation) e si può
   testare senza hardware. Le parti che dipendono da CoreMIDI stanno nel programma
   `disableton`, e in seguito nell'app grafica.

## Moduli

```
GrooveCore (nessuna dipendenza da macOS, testato anche su Linux)
  MIDIMessage        messaggi MIDI 1.0, conversione UMP (CoreMIDI moderno), nomi delle note
  MIDIFile           lettore di Standard MIDI File (formato 0 e 1)
  Groove             groove a 960 PPQ: import, taglio delle battute vuote, lunghezza, mappa note
  ClockFollower      stima di tempo e fase dal clock (regressione su 24 impulsi), SPP, Continue
  ClockGenerator     clock interno per ascoltare i groove senza la workstation
  GrooveEngine       motore musicale: loop, fill con ritorno, cambi quantizzati, note sospese
  ControlMap         comandi MIDI → azioni (predefiniti sul canale 16), MIDI Learn
  PlaybackController collega clock, comandi e motore; produce messaggi con l'istante di invio
  Library            libreria persistente (JSON + copie dei file MIDI), impostazioni
  LibraryEditing     modifiche usate dall'interfaccia (brani, slot, groove di avvio)

MIDIHost (solo macOS)
  CoreMIDIBackend    ingresso dalla workstation, porta virtuale verso gli strumenti, orologio di sistema
  LiveHost           motore dal vivo: thread di generazione ogni 0,5 ms, ascolto, MIDI Learn

DisabletonApp (SwiftUI, macOS 12+)
  AppModel           stato dell'app: salva ogni modifica e la passa al motore
  Viste              Palco, Brani, Groove, Comandi MIDI, Impostazioni

disableton (riga di comando)
  inspect, ports, monitor, play, library
```

L'interfaccia è volutamente sottile: tutta la logica verificabile sta in `GrooveCore`.

## Temporizzazione

- Ogni impulso di clock aggiorna una retta *tempo = a + b · impulso*, stimata sugli ultimi 24
  impulsi. Da questa retta si calcolano l'istante di qualsiasi posizione musicale e il tempo in
  BPM. Il jitter dei singoli impulsi viene così smussato.
- Le note dei groove (a 960 PPQ) vengono collocate tra un impulso e l'altro con la retta stimata:
  le sfumature dei groove suonati da batteristi reali non vengono quantizzate.
- Un thread ad alta priorità genera ogni 0,5 ms gli eventi dei 2 ms successivi e li invia con
  timestamp futuro. Una compensazione di latenza regolabile anticipa la batteria.
- Se il clock si interrompe senza Stop, si prosegue al tempo stimato per al massimo una battuta,
  poi si smette di suonare.
- Allo Stop si spengono le note attive e si invia All Notes Off (CC 123).

## Semantica dei comandi

- I cambi vengono messi in coda e applicati al confine scelto: battito, battuta o fine del
  groove. Le battute si contano dall'inizio del brano con il metro del brano.
- Un fill (`fill`) torna al groove ripetuto che suonava prima, anche dopo più fill di seguito.
- Uno slot scelto a trasporto fermo parte allo Start.
- Con un Continue da metà brano, il groove riparte allineato come se suonasse dall'inizio.
- Ripremere il groove in corso annulla il cambio in coda.

## Limiti noti (da affrontare dopo la Fase 0)

- Cambi di metro all'interno di un brano non gestiti: un solo metro per brano.
- Colpi suonati leggermente in anticipo sul battere (anticipi umani a fine groove): al primo
  ingresso in un groove nuovo si sente l'anticipo del groove precedente. `inspect` mostra quanti
  ce ne sono, per decidere se serve gestirli.
- La conversione delle note tra disposizioni diverse (es. kit non General MIDI) va definita sui file reali (per ora: tabella
  configurabile, nessuna conversione predefinita).
- Ripartire da metà brano richiede che il groove giusto sia già selezionato, oppure in futuro
  un arrangiamento salvato per brano.
