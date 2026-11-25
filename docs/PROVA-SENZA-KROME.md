# Prova senza Krome e senza EZdrummer

Circa 15 minuti. Se un passo non va come descritto, annota il numero del passo e cosa è successo,
poi continua (o fermati, se il problema impedisce i passi successivi).

## Materiale

Scarica **Groove-di-prova.zip** (8 file MIDI di batteria General MIDI, generati per i test):
https://github.com/MicheleLoi/Disableton/releases/latest/download/Groove-di-prova.zip
e scompattalo: ottieni la cartella *Groove di prova*.

| File | Metro | Lunghezza | Uso nella prova |
|---|---|---|---|
| Rock strofa | 4/4 | 2 battute | groove |
| Rock ritornello | 4/4 | 2 battute | groove (con piatto sul primo battere) |
| Fill tom | 4/4 | 1 battuta | fill |
| Finale | 4/4 | 1 battuta | finale (un colpo, poi silenzio) |
| Funk 16esimi | 4/4 | 1 battuta | groove |
| Shuffle | 4/4 | 1 battuta | groove |
| Valzer | 3/4 | 1 battuta | groove |
| Sei ottavi | 6/8 | 1 battuta | groove |

## A. Importazione (requisito 3)

1. Preparazione → **Importa .mid…** → seleziona tutti gli 8 file → Apri.
   → Nella libreria compaiono 8 groove con lunghezza e metro della tabella.
2. Trascina di nuovo uno dei file dal Finder sulla libreria.
   → Compare una copia con il nome seguito da "2" (es. "Valzer 2"). Eliminala con clic destro →
   *Elimina dalla libreria*.

## B. Preparazione dei brani (requisito 4)

3. **+** sotto la scaletta → rinomina il brano in "Prova rock" (campo nome in alto al centro).
4. Aggiungi al brano, con il **+** accanto a ogni groove della libreria (o trascinandolo sulla
   sequenza): *Rock strofa*, *Rock ritornello*, *Fill tom*, *Finale*.
   → Fill tom risulta "Fill, poi ritorno", Finale "Finale, poi silenzio", gli altri "Ripetuto";
   Rock strofa ha l'etichetta AVVIO.
5. **+** → "Prova valzer", metro **3/4**, groove *Valzer*. **+** → "Prova 6/8", metro **6/8**,
   groove *Sei ottavi*.
6. Seleziona "Prova valzer" e usa **↑** per portarlo in cima, poi **↓** per rimetterlo al suo posto.
   Crea un brano di troppo e cancellalo con **−** (chiede conferma).
7. Chiudi e riapri Disableton.
   → Brani e groove sono ancora lì (salvataggio automatico).

## C. Suono e tempo (requisiti 7, 8, 12)

8. Impostazioni → Suono della batteria → **Sintetizzatore integrato di macOS** → Fine.
9. Seleziona "Prova rock" → **Seleziona** (in alto al centro).
10. Impostazioni → Clock → **120** BPM → **Avvia** → Fine.
    → Barra nera: "Clock interno", 120 BPM, battuta e 4 pallini che avanzano; suona *Rock strofa*
    (scheda verde).
11. Clic destro su *Rock ritornello* → **Suona dal Krome (prova)**.
    → Scheda arancione ("in coda"), poi alla battuta successiva parte il ritornello: il cambio cade
    esattamente sul battere, senza buchi né colpi doppi.
12. Clic destro su *Fill tom* → **Suona dal Krome (prova)**.
    → Una battuta di fill, poi torna da solo al ritornello.
13. Vista **Palco** → leggibile da lontano? Esc per tornare.
14. Clic destro su *Finale* → **Suona dal Krome (prova)** → un colpo, poi silenzio.
15. Impostazioni → Clock → **Ferma**. Ripeti con "Prova valzer" (3 pallini per battuta) e
    "Prova 6/8" (6 pallini), anche a 80 e 160 BPM.
16. Durante la riproduzione premi **PANIC** → il suono si interrompe subito.

## D. Segnalazione

17. **Aiuto → Segnala un problema…** → scrivi cosa è andato bene e cosa no → **Apri la
    segnalazione su GitHub** → *Submit*. Il registro allegato mostra tempi e cambi reali.
