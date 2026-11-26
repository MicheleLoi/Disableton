# Disableton: istruzioni d'uso

## In breve

1. Disableton è una batteria che suona i groove (ritmi in formato MIDI) a tempo con la tua workstation: la workstation comanda, Disableton la segue.
2. Colleghi la workstation al Mac con il cavo USB e scegli la sua porta in **Impostazioni → Ingresso MIDI**.
3. Prepari i brani nella vista **Preparazione**: ogni brano è una sequenza di groove (ritmo base, fill, finale).
4. Scegli dove suona la batteria in **Impostazioni → Suono della batteria**: un programma sul Mac (porta virtuale «Disableton»), il sintetizzatore di macOS, oppure uno strumento MIDI (anche la workstation stessa).
5. Dal vivo premi Start sulla workstation e comandi i groove con tasti, pedale o manopole (vista **Comandi**); la vista **Palco** si legge da lontano.

## Indice

- [Termini usati in questo manuale](#termini-usati-in-questo-manuale)
- [1. Installazione e aggiornamenti](#1-installazione-e-aggiornamenti)
- [2. Collegare la workstation](#2-collegare-la-workstation)
- [3. Dove suona la batteria](#3-dove-suona-la-batteria)
- [4. Brani e groove (Preparazione)](#4-brani-e-groove-preparazione)
- [5. SEQ e COMBI sulla workstation](#5-seq-e-combi-sulla-workstation)
- [6. Comandi dalla workstation](#6-comandi-dalla-workstation)
- [7. Impara (MIDI Learn)](#7-impara-midi-learn)
- [8. Pausa, Stop, Finale, Panic](#8-pausa-stop-finale-panic)
- [9. Intensità (volume dei colpi)](#9-intensità-volume-dei-colpi)
- [10. Creare groove con l'AI](#10-creare-groove-con-lai)
- [11. Segnalare un problema](#11-segnalare-un-problema)
- [Problemi frequenti](#problemi-frequenti)

## Termini usati in questo manuale

- **Workstation**: la tua tastiera/workstation hardware. In questo manuale gli esempi di menu della workstation sono dati per il Korg Krome (61 tasti) e sono sempre introdotti da «sul Krome». Se hai un altro modello, cerca le voci equivalenti.
- **Groove**: un breve ritmo di batteria (una o più battute) salvato come file MIDI (.mid).
- **Brano**: nella scaletta di Disableton, una sequenza di groove (i «slot»): per esempio ritmo base, fill, finale.
- **Fill**: breve variazione di batteria, di solito di una battuta, che porta da una parte all'altra.
- **Finale**: groove che chiude il brano.
- **Clock MIDI**: l'impulso di tempo che la workstation manda a Disableton. Con il clock Disableton suona esattamente al tuo tempo.
- **Porta virtuale**: un «cavo MIDI» interno al Mac che si chiama «Disableton». Programmi come REAPER lo vedono come se fosse un'altra tastiera.
- **Canale MIDI**: ogni messaggio MIDI viaggia su uno di 16 canali. La batteria usa di solito il canale 10; i comandi di Disableton usano per impostazione predefinita il canale 16.

---

## 1. Installazione e aggiornamenti

### Installare

1. Trascina **Disableton** nella cartella **Applicazioni**.
2. Aprilo da lì. Libreria e impostazioni sono salvate a parte: in **Impostazioni → Libreria** vedi la cartella e puoi aprirla con **Mostra nel Finder**.

Chiudere la finestra non ferma la musica: l'app resta attiva e la finestra si riapre cliccando l'icona nel Dock. Con **⌘Q** mentre suona, l'app chiede conferma.

### Aggiornare

Quando esce una nuova versione compare in alto a destra il pulsante **Aggiorna a …** (con il numero di versione). Puoi anche usare il menu **Disableton → Controlla aggiornamenti…**.

1. **Ferma tutto**: premi Stop sulla workstation (o **Stop** in Disableton). Se sta suonando, l'aggiornamento non parte e compare un avviso.
2. Premi **Aggiorna a …** e conferma con **Installa e riavvia**.
3. Disableton si chiude e si riapre aggiornato. Libreria e impostazioni restano invariate.

Se l'app non può sostituirsi da sola (per esempio non è in Applicazioni), si apre la pagina di download: scarica `Disableton.zip` e sostituisci l'app in Applicazioni.

### Dopo un aggiornamento: la porta «Disableton» sparisce e riappare

La porta virtuale esiste solo mentre Disableton è aperto, quindi durante il riavvio sparisce e poi ricompare. I programmi che la usavano possono non accorgersene. In **REAPER**:

1. **Settings…** (⌘,) → **Audio** → **MIDI Inputs**.
2. Premi **Reset all MIDI devices** (oppure chiudi e riapri REAPER con Disableton già aperto).
3. Controlla che la traccia abbia ancora come ingresso MIDI «Disableton» (vedi [3a](#a-porta-virtuale-disableton-programmi-e-daw)).

---

## 2. Collegare la workstation

1. Collega la workstation al Mac con il cavo **USB** e accendila.
2. Apri Disableton → **Impostazioni** (icona a ingranaggio in alto a destra, oppure **⌘,**).
3. Nella sezione **Workstation**, dal menu **Ingresso MIDI** scegli la porta della workstation **per nome**.
4. Sulla workstation imposta il **MIDI Clock** su **Internal**: la workstation deve essere lei a dare il tempo. Sul Krome: **GLOBAL → P1: MIDI → MIDI Clock**.
5. Controlla la barra scura in alto: il pallino diventa verde e compare «Clock workstation» quando il clock arriva. Sotto il menu, la riga «Collegate: …» elenca le sorgenti collegate.

Note utili:

- L'opzione di partenza è **Tutte le sorgenti**. Se però accendi o colleghi la workstation **dopo** aver aperto Disableton, non viene collegata da sola: premi **Aggiorna elenco** e scegli la workstation per nome nel menu.
- Il tempo mostrato (per esempio «120.0 BPM») può oscillare di 0,1: è normale, è una misura del clock.
- Colori del pallino nella barra in alto: verde = clock della workstation in arrivo; arancione = «In attesa del clock»; blu = clock interno o ascolto; rosso = «Motore MIDI fermo».
- Se serve ricollegare tutto: **Impostazioni → Libreria → Riavvia motore MIDI…** (se sta suonando, si interrompe).

### Provare senza workstation

Per sentire i groove senza la workstation: pulsante **Prova senza workstation** nella barra in alto (o **⌘R**, o menu **Riproduzione**). Suona il brano selezionato con il clock interno; il tempo si imposta in **Impostazioni → Clock** («Prova senza workstation», da 40 a 240 BPM). Si ferma con **Ferma** / **Stop**. Mentre la workstation sta suonando, questa prova non parte.

---

## 3. Dove suona la batteria

Disableton non contiene suoni: manda le note di batteria a qualcuno che le suoni. Si sceglie in **Impostazioni → Suono della batteria**, con tre possibilità. La riga «Uscita attuale» mostra dove sta andando il suono.

Nella stessa sezione trovi:

- **Canale MIDI** (stepper): il canale su cui Disableton manda le note (di solito 10).
- **Anticipo batteria** (da 0 a 40 ms): se la batteria arriva in ritardo rispetto ai suoni della workstation, aumentalo.

### a. Porta virtuale «Disableton» (programmi e DAW)

Scegli **Porta virtuale «Disableton» (strumenti software e DAW)**. Tieni Disableton aperto: la porta esiste solo finché l'app è aperta.

#### Con REAPER

Una volta sola:

1. REAPER → **Settings…** → **Audio** → **MIDI Inputs**.
2. Clic destro sulla riga «Disableton» → **Enable input for track record input**. Poi Apply e OK.
3. Se «Disableton» non è nell'elenco, REAPER era stato aperto prima di Disableton: premi **Reset all MIDI devices** nella stessa pagina, oppure chiudi e riapri REAPER con Disableton già aperto.

In ogni progetto:

1. Prepara una traccia con lo strumento di batteria che vuoi usare.
2. Sulla traccia apri il menu dell'ingresso e scegli **Input: MIDI → Disableton → All channels**.
3. Attiva la registrazione sulla traccia (pulsante rosso) e il monitoraggio dell'ingresso (icona altoparlante accanto al pulsante rosso).
4. Per non registrare mentre suoni: clic destro sul pulsante rosso → **Record: disable (input monitoring only)**.
5. Prova: in Disableton premi **Prova senza workstation**. La traccia di REAPER mostra attività MIDI e lo strumento suona.

REAPER non deve essere in play né sincronizzato: il tempo viene dalla workstation (o dal clock interno di Disableton).

#### Con un programma «standalone» (con una sua finestra)

Se lo strumento ha un'app propria, basta scegliere «Disableton» come ingresso MIDI in quell'app. Esempio, Analog Lab V:

1. Clicca l'icona **≡** in alto a **sinistra**.
2. Scegli **Audio MIDI Settings**.
3. Spunta **Disableton**.

Attenzione: **non** usare l'ingranaggio in alto a destra: la sua scheda «MIDI» serve per i controller, non per questo.

#### Strumenti che sono solo plugin (per esempio SSD 5.5 Free)

Un plugin non ha un'app propria e non compare in Applicazioni. Va caricato dentro un programma che lo ospita, per esempio REAPER:

1. In REAPER: **Track → Insert virtual instrument on new track**, poi scegli il plugin.
2. Imposta l'ingresso della traccia come sopra.
3. Se SSD mostra «empty» o 0.0MB, non ha nessun kit caricato: nella sua pagina **Create** scegli un kit dall'elenco (per esempio «Deluxe 2 Free»).

In alternativa a una DAW puoi usare **Element**, un programma gratuito che ospita plugin senza tracce né progetti: guida in **Aiuto → Element: strumenti plugin senza DAW…**. Anche **Aiuto → Collegare una DAW (esempio: REAPER)…** riassume i passi per REAPER.

#### Suona note invece di batteria

Se invece dei colpi di batteria sentite note intonate («Do Do Re…»), lo strumento caricato non è un kit di batteria (per esempio è un preset di sintetizzatore). Carica un kit di batteria. Se un kit suona i suoni sbagliati (per esempio un rullante al posto della cassa), non segue la disposizione General MIDI: scegli un kit General MIDI.

### b. Sintetizzatore di macOS

Scegli **Sintetizzatore integrato di macOS (suoni di prova)**. Non serve altro: è utile per provare i groove, il suono è semplice.

### c. Strumento MIDI collegato (la workstation stessa o un altro synth)

Per far suonare la batteria dalla workstation:

1. In **Suono della batteria** scegli **Strumento MIDI collegato (workstation o altro synth)**.
2. Nel menu **Destinazione MIDI** scegli la porta dei **suoni** della workstation (sul Krome: «KROME SOUND»; non la porta di controllo).
3. Imposta **Canale MIDI** su 10.
4. Sulla workstation scegli una traccia o un timbro con un **kit di batteria** sul **canale 10**, con stato **Play** (non muta).

Avvertenza mostrata dall'app: con questa uscita il **pedale damper** collegato alla workstation (o a un altro strumento) può smettere di agire sui suoni dello strumento stesso. Se succede, usa la porta virtuale «Disableton».

Se la batteria si sovrappone a un altro ritmo, o **continua a suonare dopo che Disableton si è fermato**, sulla workstation sta andando il suo **DRUM TRACK** (o l'**ARP**): spegnilo.

---

## 4. Brani e groove (Preparazione)

La vista **Preparazione** (**⌘1**) ha tre colonne e, sotto, la libreria. Le viste si cambiano dal selettore in alto (**Preparazione / Comandi / Palco**) o dal menu **Vista**.

### La scaletta (colonna a sinistra)

- **+** crea un nuovo brano; **−** elimina il brano selezionato (si può annullare con **⌘Z**); **↑** e **↓** lo spostano; si può anche trascinare.
- Il numero del brano è anche il suo numero di Program Change: «Brano n = Program Change n−1 dalla workstation». Se sposti un brano, il numero cambia di conseguenza.
- Il nome del brano si modifica nel campo in alto al centro.
- Il triangolo accanto a un brano indica quello selezionato sulla workstation.

### Importare i groove

1. Nella **Libreria groove** premi **Importa .mid…**, oppure trascina i file .mid dal Finder (o da un programma di batteria) sulla libreria.
2. Con la casella **Cerca** filtri per nome.
3. Doppio clic su un groove (o clic destro → **Dettagli…**) per vederne le informazioni; da lì si può anche impostare lunghezza, metro e intensità (vedi [capitolo 9](#9-intensità-volume-dei-colpi)).
4. Il pulsante con il triangolo ascolta il groove da solo; il cestino lo elimina dalla libreria (si annulla con ⌘Z).

### Aggiungere groove a un brano

1. Seleziona il brano nella scaletta.
2. Sulla riga del groove nella libreria premi **+** (**Aggiungi al brano selezionato**), oppure trascinalo nell'area tratteggiata **Trascina qui un groove**.
3. Compare una scheda nella sequenza «Groove del brano, in ordine». Ogni scheda mostra numero e nota predefinita (per esempio «1 · C1 (24)»), il nome, il comportamento e la lunghezza.

Per cambiare l'ordine: trascina le schede, oppure seleziona una scheda e usa le frecce **←** e **→** nel pannello di destra. Per toglierla: la **x** sulla scheda o **Togli dal brano** (il groove resta in libreria).

L'ordine conta: i primi 12 groove sono quelli che si possono richiamare con i tasti predefiniti (vedi [capitolo 6](#6-comandi-dalla-workstation)), e «Groove successivo» e «Groove precedente» seguono questo ordine.

### Far partire un groove

- Sulla scheda: il pulsante **▶ Suona** (diventa «In coda» o «Sta suonando»).
- Clic destro sulla scheda → **Fai partire questo groove**.
- Nel pannello di destra: **Fai partire nel brano**.

Se la batteria è ferma, parte subito con il clock interno (a Prova senza workstation); se sta già suonando, parte al momento scelto in **Cambio**.

### Il pannello di destra (dettagli dello slot)

Seleziona una scheda e usa:

- **Groove**: cambia il groove di quella posizione.
- **Comportamento**: che cosa fa il groove quando viene eseguito.
  - **Ripetuto**: si ripete finché non arriva un altro comando. È il ritmo base.
  - **Fill, poi ritorno**: suona una volta, poi torna da solo al ritmo ripetuto che suonava prima.
  - **Una volta, poi il successivo**: suona una volta e passa al groove successivo del brano. Va bene per un'introduzione, o per un fill che porta dalla strofa al ritornello.
  - **Finale, poi silenzio**: suona una volta e poi la batteria si ferma.
  - Quando aggiungi un groove, il comportamento viene scelto dal **nome**: se contiene «fill» diventa Fill, poi ritorno; se contiene «finale» diventa Finale, poi silenzio; altrimenti Ripetuto. Puoi cambiarlo quando vuoi, anche in modo diverso da un brano all'altro.
- **Cambio**: quando parte il groove.
  - **Alla battuta** (predefinito): alla prossima battuta. Per un fill nella battuta 8, lo richiami durante la 7.
  - **Al battito**: al prossimo battito. Per un fill di mezza battuta, lo richiami durante il battito 2 così parte sul 3.
  - **A fine groove**: aspetta che il groove in corso arrivi alla fine.
- **Parte allo Start della workstation**: segna il groove che parte quando premi Start (o il comando **Avvia**). Sulla scheda compare il segno **AVVIO**. Il segno segue il **groove**, non la posizione: se sposti la scheda, l'AVVIO si sposta con lei.
- **Tasto sulla workstation**: mostra il tasto assegnato a quel groove e il pulsante **Impara** per cambiarlo (vedi [capitolo 7](#7-impara-midi-learn)).
- **Ascolta da solo a … BPM** e il cursore **Tempo**: ascolto del groove senza workstation.
- **Dettagli del groove…**: apre la scheda del groove.

Il link **Fill, finali e comportamento: guida** apre la guida dell'app (la stessa di **Aiuto → Fill, finali e comportamento dei groove…**).

Regole da conoscere:

- Il comando **Fill** della workstation suona il **primo fill** del brano; gli altri fill si richiamano con il loro tasto di posizione (1, 2, 3…), come ogni groove.
- Dopo un fill il groove riparte dall'inizio.
- Un fill deve finire su una barra di battuta; i fill di una battuta funzionano meglio.
- Disableton misura un groove in battute intere, fino all'ultima battuta che contiene una nota; le battute vuote iniziali vengono saltate.

### Metro (tempo musicale) del brano

Accanto al nome del brano c'è il menu **Metro**: vale **per brano**. Le battute e i puntini dei battiti nella barra in alto (uno per ogni battito della battuta) seguono questo metro.

- Un brano **in 12/8** va impostato **a mano**: Disableton non lo riconosce da solo.
- Un brano in **4/4 con sensazione di terzine o shuffle** resta **4/4**.

### Le modifiche mentre la batteria suona

Se modifichi brani, ordine o groove mentre la batteria suona, il brano in corso **non cambia subito**: le modifiche valgono appena la batteria si ferma o tace, cioè dopo **Stop**, **Pausa** o **Finale**. È una scelta voluta, per non rompere il groove dal vivo. Il pannello di destra lo ricorda: «Le modifiche fatte mentre la batteria suona valgono appena si ferma o tace (Stop, Pausa, Finale).»

---

## 5. SEQ e COMBI sulla workstation

Disableton si comporta in modo diverso a seconda che la workstation mandi o no il messaggio **Start**.

### In SEQ (sequencer)

1. Premi **▶** sulla workstation: manda Start e Disableton parte con il groove segnato **AVVIO** (o con il groove che hai richiamato prima dello Start).
2. Premi **■** sulla workstation: manda Stop e Disableton si ferma.

Il brano del sequencer ha una **lunghezza** e si ferma da solo alla fine. Se la batteria si ferma prima del previsto, controlla la lunghezza del brano sulla workstation (sul Krome: comando di menu **Set Song Length**).

### In COMBI

In Combi la workstation manda il **clock** ma **non** manda Start. Quindi serve il comando **Avvia** (di default sul tasto C2, canale 16, o un controllo che hai imparato). **Avvia** parte al tempo del clock con il groove segnato AVVIO.

**Avvia è ignorato mentre la batteria sta già suonando.** Se invece la batteria è in silenzio (dopo una Pausa o un Finale, con il clock che continua), **Avvia** fa ripartire il groove di avvio alla battuta successiva.

Se premi **Avvia** e non succede niente, controlla che il clock arrivi (barra in alto: «Clock workstation»).

---

## 6. Comandi dalla workstation

La vista **Comandi** (**⌘2**) mostra la tastiera della workstation con i comandi assegnati ai tasti.

### Perché il canale 16

I comandi predefiniti rispondono **solo sul canale MIDI 16**: è un canale che nessuno usa, così i tasti che suoni normalmente non fanno partire comandi per sbaglio.

### La disposizione predefinita

Nomi delle note come sulla workstation Korg: **C1 = nota MIDI 24**, **C2 = nota MIDI 36**.

| Tasto | Nota | Comando |
|---|---|---|
| C1 – B1 | 24 – 35 | **Groove 1 – 12 del brano** (i loop) |
| C2 | 36 | **Avvia** (al tempo della workstation) |
| C#2 | 37 | **Groove precedente** |
| D2 | 38 | **Fill** |
| D#2 | 39 | **Groove successivo** |
| E2 | 40 | **Pausa a fine battuta** (riprende a tempo) |
| F2 | 41 | **Stop** (ferma; riparte con Avvia) |
| F#2 | 42 | **Brano precedente** |
| G2 | 43 | **Finale** (poi silenzio) |
| G#2 | 44 | **Brano successivo** |

In più, un **Program Change** sul canale 16 sceglie il brano con lo stesso numero (vedi [capitolo 7](#brano-dal-program-change)).

Controller (SW1, SW2, pedale, manopole) **non** hanno comandi predefiniti: si assegnano con Impara.

### Come raggiungere quei tasti sul Krome a 61 tasti

Sul Krome a 61 tasti la tastiera normalmente parte da C2. Per arrivare a C1 (i loop 1–12) **abbassa l'ottava** della workstation.

### Come mandare i comandi sul canale 16

In **SEQ**:

1. Con **Track Select** scegli una traccia che trasmette sul canale 16 (per esempio Track16).
2. Se serve, imposta la traccia: **P3 Track Parameters → MIDI**: **MIDI Channel** 16, **Status** BTH o EXT.
3. Attenzione: **Play/Mute non è Track Select**. Quello che conta per il canale di trasmissione è la traccia selezionata con Track Select.

In **COMBI** la tastiera trasmette sul **canale MIDI globale**, non su quello dei timbri. Due strade:

- **Impara**: assegna i tasti al canale che la workstation usa davvero (vedi [capitolo 7](#7-impara-midi-learn)). È la strada più semplice.
- **Canale globale 16**: imposta il canale globale della workstation su 16, metti esplicitamente in muto i timbri che sono sul 16, e silenzia le due ottave più basse con le zone di tasti (**P4 Zone/Delay → Key Z**, **Bottom Key**), così quando suoni normalmente non fai partire comandi.

### La vista Comandi

Colori dei tasti (legenda sotto la tastiera):

- **blu** = groove del brano («groove del brano»)
- **viola** = comandi («comando»)
- **verde** = sta suonando («suona ora»)
- **arancione** = in coda («in coda»)
- **chiaro** = posizione vuota in questo brano («slot vuoto in questo brano»)
- **pallino arancione** su un tasto = tasto **imparato** («tasto imparato»)

Abbreviazioni sui tasti:

| Scritta | Significato |
|---|---|
| 1 … 12 | groove 1 … 12 del brano |
| ◀GR / GR▶ | groove precedente / successivo |
| ◀B / B▶ | brano precedente / successivo |
| FILL | fill |
| PAUSA | pausa a fine battuta |
| STOP | stop |
| FINALE | finale |
| AVVIA | avvia |
| INT | intensità (manopola) |
| PANIC | panic |

Come usarla:

1. Clicca un tasto: a destra compare il **Tasto selezionato** con la sua azione.
2. Per cambiarla, usa il menu **Azione del tasto**: cambia solo quel tasto, senza toccare gli altri tasti e controlli imparati.
3. **Prova: …** esegue il comando come se arrivasse dalla workstation (utile senza workstation, ma deve essere già in corso la riproduzione per i comandi di cambio).
4. **Ripristina predefiniti…** (nella sezione **Altri controlli**) rimette la disposizione della tabella qui sopra e **cancella** i tasti imparati. Si può annullare con **⌘Z**.

Per capire perché un tasto non fa niente, in basso a destra:

- **Ultimo comando ricevuto**: l'ultimo messaggio che Disableton ha riconosciuto come comando.
- **Ultimo messaggio non associato**: l'ultimo messaggio arrivato che **non** corrisponde a nessun comando. Se premi un tasto e compare qui, il tasto non ha un comando oppure è su un altro canale.

---

## 7. Impara (MIDI Learn)

**Impara** serve a dire a Disableton: «quando premo questo controllo della workstation, fai questo». Funziona con qualsiasi controllo che mandi un messaggio MIDI.

### Aggiungere un comando

1. Vai in **Comandi** → sezione **Altri controlli** → **+ Aggiungi comando**.
2. Dal menu scegli il comando (per esempio «Avvia (al tempo della workstation)»).
3. La barra in alto diventa arancione: «MIDI Learn: premi un tasto o un controllo sulla workstation…».
4. Premi il tasto, gira la manopola o premi il pedale sulla workstation. Compare un avviso con il risultato («… ora comanda …»).
5. Per rinunciare premi **Annulla**.

Altri modi: nella scheda di un groove (Preparazione) il pulsante **Impara** accanto a «Tasto sulla workstation»; nella vista Comandi il pulsante **Impara** su ogni comando già presente (per cambiarne il controllo) o **Impara: assegna … al prossimo tasto premuto** dal tasto selezionato. Il cestino elimina un comando (si annulla con ⌘Z).

Regole:

- Impara accetta **note**, **controller (CC)** e **Program Change**.
- I pulsanti che agiscono solo **dentro** la workstation (Program Up/Down, Tap, ARP, DRUM TRACK, tasti del pannello) non mandano nessun messaggio MIDI e **non si possono imparare**.
- Un controllo comanda una sola cosa: se assegni un controllo già usato, il vecchio comando di quel controllo viene sostituito (l'avviso lo dice). Anche l'inverso: un comando ha un solo controllo per tipo, per esempio una sola nota; imparandolo di nuovo, la nota precedente viene sostituita.
- Un comando da **controller** (manopola, joystick, pedale continuo) scatta **una volta** quando il valore sale oltre la metà (manopola oltre le «ore 12»). Per farlo scattare ancora, riporta il controllo sotto la metà.

### Esempi sul Krome

- **Le 4 REALTIME CONTROLS** (manopole) in modalità ARP mandano i controller **CC 22–25** (impostazione: **GLOBAL → P2 Controllers → CC Assign**). Tieni l'**ARP spento** per non cambiare il suono.
- **Joystick** su/giù: **CC 1 / CC 2**. Attenzione: muovendolo aggiunge anche vibrato / wah alle note tenute.
- **Pedale** (interruttore): collegalo all'ingresso **ASSIGNABLE SWITCH**. In **GLOBAL → P2 Controllers → Foot Controllers** imposta **Foot Switch Assign** = **Foot Switch** (non Program Up/Down), con pedale di tipo **momentaneo**, e salva con **WRITE** in Global.
- **SW1 / SW2** e il pedale non hanno comandi predefiniti.

### Brano dal Program Change

Il comando **Brano dal Program Change** fa sì che cambiando Combi (o programma) sulla workstation Disableton passi al brano con lo stesso numero (Combi 001 → brano 1).

- I Program Change sul canale 16 funzionano già di default.
- Se la tua workstation li manda su un altro canale: **+ Aggiungi comando → Brano dal Program Change**, poi cambia Combi sulla workstation: Disableton impara il canale.
- Se cambi brano in altri modi (per esempio con i tasti Brano successivo/precedente) e il Program Change ti disturba, **eliminalo** con il cestino.

### Una disposizione consigliata per il live

- **Pedale** = Groove successivo.
- **Manopola 1** = Avvia, **2** = Fill, **3** = Groove precedente, **4** = Stop oppure Finale.
- **Joystick** su/giù = Brano successivo / Brano precedente.
- Tasti per richiamare direttamente i loop.

---

## 8. Pausa, Stop, Finale, Panic

| Comando | Che cosa fa |
|---|---|
| **Pausa** (E2) | Silenzio **a fine battuta**. Disableton resta a tempo con la workstation e riprende con un tasto di groove o con **Avvia**. |
| **Stop** (F2 e pulsante **Stop** in alto) | Stop vero: la batteria si ferma, le modifiche fatte nel frattempo vengono applicate, e il successivo **Avvia** parte **nel momento in cui lo premi**. |
| **Finale** (G2) | Suona il groove «Finale, poi silenzio» del brano e poi si ferma come con Stop. Se il brano non ha un finale, il comando si comporta come **Pausa**. |
| **Panic** | Emergenza per le note rimaste appese. |

Dettagli:

- **Pausa**: nella barra in alto compare «→ silenzio a fine battuta» con il pulsante **Annulla** per cambiare idea.
- **Stop**: se avevi deciso un groove con la workstation ferma, il pulsante diventa **Annulla avvio**. Con il clock interno si chiama **Ferma**.
- **Finale**: se ci sono più finali nel brano, viene usato il primo.
- **Groove successivo** (D#2) e **Groove precedente** (C#2) scorrono **soltanto** i groove **Ripetuto** e saltano apposta fill e finale. Per un fill usa **Fill** o il suo tasto di posizione.
- **Panic**: bottone rosso **PANIC** nella barra in alto, voce **Riproduzione → Panic (silenzio immediato)** (**⇧⌘.**). Si può anche assegnare a un controllo con Impara; **non** ha un tasto predefinito.

Scorciatoie di Riproduzione: **⌘.** = Stop, **⇧⌘.** = Panic, **⌘R** = Prova senza workstation.

---

## 9. Intensità (volume dei colpi)

L'intensità moltiplica la forza dei colpi (la «velocity»): il rapporto tra cassa, rullante e piatti resta lo stesso, cambia solo quanto forte suonano tutti.

### Dal vivo

1. **Impostazioni → Suono della batteria → Intensità dal vivo**: cursore da 50% a 200%; **100%** riporta al valore normale.
2. Per comandarla con una **manopola** della workstation: **Comandi → + Aggiungi comando → Intensità della batteria (manopola)**, poi gira la manopola. Manopola a metà = **100%**, tutta a sinistra = **50%**, tutta a destra = **200%**.
3. All'avvio dell'app l'intensità riparte sempre da 100%.

### Per un singolo groove

1. In libreria fai **doppio clic** sul groove (o clic destro → **Dettagli…**; oppure, dal pannello di destra, **Dettagli del groove…**).
2. Nel riquadro **Intensità** muovi il **cursore** (da 50% a 200%).
3. **Ascolta** (riquadro «Ascolto (senza workstation)») suona il groove con quell'intensità.
4. Per tenere il risultato: **Salva come nuovo groove** (crea un nuovo groove in libreria, con il nome seguito dalla percentuale) oppure **Esporta .mid…** (crea un file).

Note:

- I pulsanti **Salva come nuovo groove** e **Esporta .mid…** sono grigi quando l'intensità è esattamente 100%: non c'è nulla da cambiare.
- Il file originale **non viene mai modificato**.
- I colpi che con l'intensità scelta supererebbero il massimo (127) vengono fermati a 127: compare un avviso arancione con il numero di colpi interessati.

---

## 10. Creare groove con l'AI

Puoi chiedere a un assistente AI che crei file MIDI di batteria e poi importarli in Disableton.

1. Apri **Aiuto → Fill, finali e comportamento dei groove…**
2. In fondo alla guida trovi tre modelli di richiesta: **Groove (ripetuto)**, **Fill** e **Finale**. Ognuno ha un pulsante **Copia**.
3. Copia il modello, riempi i punti «…» (metro, lunghezza, stile, tempo di riferimento, nome del file) e incollalo in una chat con un assistente AI capace di creare file scaricabili.
4. Scarica il file .mid e importalo con **Importa .mid…** (vedi [capitolo 4](#4-brani-e-groove-preparazione)). Ascoltalo prima di usarlo sul palco.

Cose da sapere:

- Le richieste chiedono note di batteria **General MIDI** (canale 10): è la disposizione standard dei suoni di batteria, che la maggior parte dei kit segue.
- Un groove «con spazzole» dipende dal **kit** che hai caricato nello strumento: il file MIDI contiene solo note; se vuoi le spazzole, scegli un kit di spazzole nello strumento.
- Il nome del file diventa il nome del groove. «Fill …» e «Finale …» fanno scegliere subito il comportamento giusto (vedi [capitolo 4](#il-pannello-di-destra-dettagli-dello-slot)).

---

## 11. Segnalare un problema

1. Menu **Aiuto → Segnala un problema…**
2. Descrivi cosa stavi facendo, cosa ti aspettavi e cosa hai sentito.
3. Vedi in anteprima il **rapporto allegato** (versione, impostazioni, porte MIDI, registro degli eventi; non contiene nomi di brani né di groove). Puoi premere **Copia rapporto** oppure **Apri la segnalazione su GitHub**. Il rapporto viene anche copiato negli appunti.
4. Attenzione: la segnalazione sarà **pubblica** su GitHub.

In **Aiuto** trovi anche **Mostra il registro**, che apre nel Finder il file con gli eventi dell'app.

---

## Vista Palco

La vista **Palco** (**⌘3**) è una schermata scura da leggere a 2–3 metri: mostra il brano, **SUONA** (il groove in corso), **IN CODA / PROSSIMO** (il cambio che sta per arrivare), la battuta con i puntini dei battiti, il tempo e il brano successivo. Si esce con **Esc** (torna a Preparazione); il pulsante con le frecce in alto a destra (o **⌃⌘F**) attiva lo schermo intero. In Palco restano visibili **Stop** e **PANIC**.

---

## Problemi frequenti

| Sintomo | Causa | Che cosa fare |
|---|---|---|
| Barra in alto con «In attesa del clock» (pallino arancione) | Disableton non riceve il clock | Controlla il cavo USB; in **Impostazioni → Ingresso MIDI** scegli la workstation **per nome** (se l'hai accesa dopo l'app, premi **Aggiorna elenco**); sulla workstation **MIDI Clock = Internal**. |
| La workstation è collegata ma non compare tra le sorgenti | Accesa o collegata dopo l'apertura di Disableton con «Tutte le sorgenti» | **Aggiorna elenco** e scegli la workstation per nome. |
| Il tempo oscilla di 0,1 BPM | Misura del clock | Normale: non fare nulla. |
| Premo Start e non suona niente | Il brano non ha nessun groove segnato AVVIO, oppure nessun brano è selezionato | In **Preparazione** attiva **Parte allo Start della workstation** su un groove; verifica che la porta di uscita sia quella giusta in **Suono della batteria**. |
| In COMBI la batteria non parte | In Combi la workstation non manda Start | Usa il comando **Avvia** (C2 sul canale 16 o un controllo imparato). |
| **Avvia** non fa niente | Sta già suonando (Avvia è ignorato mentre suona), oppure il clock non arriva | Se sta suonando è normale. Altrimenti controlla «Clock workstation» nella barra in alto. |
| In SEQ la batteria si ferma da sola | Il brano del sequencer è finito | Allunga il brano sulla workstation (sul Krome: **Set Song Length**). |
| I tasti non fanno niente | I comandi predefiniti rispondono solo al **canale 16**, e sul Krome da 61 tasti i loop 1–12 stanno sotto la tastiera | Seleziona (SEQ) una traccia sul canale 16 con Track Select; abbassa l'ottava per C1; oppure usa **Impara**. In **Comandi** guarda «Ultimo messaggio non associato». |
| In COMBI i tasti non rispondono sul canale 16 | In Combi la tastiera trasmette sul canale globale | Usa **Impara**, oppure imposta il canale globale su 16 e silenzia le due ottave più basse con le zone di tasti (vedi [capitolo 6](#6-comandi-dalla-workstation)). |
| Un controllo non si lascia imparare | Il pulsante agisce solo dentro la workstation (Program Up/Down, Tap, ARP, DRUM TRACK, tasti del pannello) | Scegli un altro controllo: manopole REALTIME CONTROLS, joystick, pedale o un tasto. |
| La manopola scatta una volta sola | Un comando da controller scatta quando il valore sale oltre la metà | Riporta la manopola sotto la metà per riarmarla. |
| Muovendo il joystick cambia anche il suono | Il joystick manda anche vibrato / wah | Normale per CC 1 / CC 2; scegli un altro controllo se ti disturba. |
| Le manopole in modalità ARP cambiano il suono | L'ARP è acceso | Tieni l'**ARP spento** e usa i CC 22–25 solo come comandi. |
| Il pedale non funziona | Assegnazione pedale non corretta | Pedale in **ASSIGNABLE SWITCH**; **Foot Switch Assign = Foot Switch** (non Program Up/Down); pedale momentaneo; **WRITE** in Global. |
| Le modifiche ai groove non si sentono | Le modifiche valgono appena la batteria si ferma o tace | Fai **Stop**, **Pausa** o **Finale**, poi riparti. |
| Il brano non suona in 12/8 come dovrebbe | Il metro va impostato a mano | Imposta **Metro** = 12/8 accanto al nome del brano. |
| Il brano in terzine/shuffle «sembra» in 12 | È in 4/4 con sensazione di terzine | Lascia **4/4**. |
| Nella DAW la porta «Disableton» non c'è | REAPER è stato aperto prima di Disableton, o dopo un aggiornamento | REAPER → Settings… → Audio → MIDI Inputs → **Reset all MIDI devices** (o riapri REAPER con Disableton aperto); poi controlla l'ingresso della traccia. |
| REAPER non riceve niente | La traccia non è pronta | Input MIDI → Disableton → All channels; traccia armata e monitoraggio attivo; in Disableton la destinazione è la porta virtuale. |
| Sento note intonate («Do Do Re…») | Lo strumento non è un kit di batteria | Carica un kit di batteria. |
| Un kit suona i suoni sbagliati (per esempio un rullante al posto della cassa) | Il kit non segue la disposizione General MIDI | Scegli un kit General MIDI. |
| SSD mostra «empty» / 0.0MB | Nessun kit caricato | Pagina **Create** → scegli un kit (per esempio «Deluxe 2 Free»). |
| Il plugin non compare in Applicazioni | Un plugin non è un'app | Caricalo in REAPER (**Track → Insert virtual instrument on new track**) o in Element. |
| In Analog Lab non trovo «Disableton» | Si cerca nella scheda sbagliata | Icona **≡** in alto a sinistra → **Audio MIDI Settings** → spunta **Disableton** (non l'ingranaggio in alto a destra). |
| La batteria arriva in ritardo | Latenza dello strumento o della DAW | Aumenta **Anticipo batteria**; in REAPER riduci «Request block size» (per esempio 128). |
| La batteria si sovrappone a un altro ritmo, o continua dopo lo Stop | Sulla workstation sta andando il suo **DRUM TRACK** (o l'**ARP**) | Spegnilo. |
| Con l'uscita «Strumento MIDI collegato» il pedale damper non agisce più sui suoni della workstation | Effetto noto di questa uscita (avvertenza nell'app) | Usa la porta virtuale «Disableton». |
| Note rimaste appese | Interruzione a metà | **PANIC** (⇧⌘.). |
| Non riesco ad aggiornare | Sta suonando, oppure l'app non è in Applicazioni | Ferma la riproduzione; se l'app non può sostituirsi da sola, scarica `Disableton.zip` dalla pagina che si apre e sostituisci l'app in Applicazioni. |
| Un tasto imparato ha cambiato un altro comando | Un controllo comanda una sola cosa | L'avviso nella barra in alto dice che cosa è stato sostituito; **⌘Z** per annullare, poi riassegna. |
| Ho perso i tasti imparati | **Ripristina predefiniti…** li cancella | **⌘Z** subito dopo; altrimenti reimparali. |
