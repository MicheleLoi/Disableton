# Da fare: versione avanzata (ramo `splitter`)

Elenco delle funzioni previste per la versione avanzata. Non fanno parte degli aggiornamenti
pubblicati finché non vengono completate e unite al ramo principale.

## Già presente su questo ramo

- **Mappa delle note** per strumenti che non seguono la disposizione General MIDI (convertire una
  nota in un'altra o non suonarla), scelta per destinazione del suono.

## Da fare

1. **Splitter: un suono per canale.** Mandare ogni pezzo della batteria (cassa, rullante,
   charleston…) su un canale MIDI diverso, così in una DAW o in Element ogni suono può avere la
   sua traccia o il suo strumento. Va gestito lo spegnimento delle note su tutti i canali usati
   (cambi di groove, stop, panic). Aggiornare le guide di REAPER ed Element con l'uso a più tracce.

2. **Più parti per brano su canali diversi.** Oltre alla batteria, altre parti (es. basso sul
   canale 2, arpeggio, pad) che partono, cambiano e si fermano insieme alla batteria, come la
   sezione ritmica di un arranger. Da decidere: canale per parte, oppure canale preso dal file MIDI
   (oggi il canale scritto nel file viene ignorato e tutto esce su un solo canale).

3. **Note lunghe attraverso la fine del loop.** Oggi una nota tenuta oltre la fine del groove
   viene chiusa alla fine del giro: accordi e pad legati tra un giro e l'altro si spezzano.
   Servono note che continuano nel giro successivo (o una scelta per groove).

4. **Altri messaggi MIDI del file.** Riprodurre anche pitch bend, aftertouch e cambi di programma
   presenti nei groove (oggi si riproducono solo note e controller).

5. **Testi non solo per la batteria.** Interfaccia e dettagli del groove pensati anche per altri
   strumenti: nomi delle note (oggi sono i nomi dei suoni di batteria General MIDI), parole come
   «batteria» dove la parte può essere un altro strumento.
