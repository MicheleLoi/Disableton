"""Genera la libreria di groove MIDI di batteria (General MIDI, canale 10) pubblicata con ogni versione.
Uso: python3 scripts/genera-libreria.py <cartella di uscita>

Griglia: 16 passi per battuta in 4/4 (sedicesimi), 12 passi in 12/8 (ottavi).
Simboli: X accento, x normale, - medio, g ghost, . pausa."""
import struct, random, os, sys
OUT = sys.argv[1]
PPQ = 960
N = dict(K=36, S=38, R=37, CL=39, H=42, P=44, O=46, Y=51, B=53, C=49, D=57, T=54,
         TH=50, TM=47, TL=45, TF=43)
VEL = {'X': 118, 'x': 96, '-': 72, 'g': 34}

def vlq(n):
    b = [n & 0x7F]; n >>= 7
    while n: b.insert(0, (n & 0x7F) | 0x80); n >>= 7
    return bytes(b)

def write(path, events, name, ts, bpm):
    random.seed(sum(name.encode()) * 7919)  # deterministico tra un'esecuzione e l'altra
    ev = []
    for t, n, v in events:
        t = max(0, t + (random.randint(-5, 5) if t else 0))
        v = max(1, min(127, v + random.randint(-4, 4)))
        ev += [(t, 1, bytes([0x99, n, v])), (t + 60, 0, bytes([0x89, n, 0]))]
    ev.sort(key=lambda e: (e[0], e[1]))
    num, den = ts
    trk = vlq(0) + b'\xff\x03' + vlq(len(name.encode())) + name.encode()
    trk += vlq(0) + b'\xff\x58\x04' + bytes([num, {4: 2, 8: 3}[den], 24, 8])
    trk += vlq(0) + b'\xff\x51\x03' + int(60_000_000 / bpm).to_bytes(3, 'big')
    last = 0
    for t, _, d in ev:
        trk += vlq(t - last) + d; last = t
    trk += vlq(0) + b'\xff\x2f\x00'
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'wb').write(b'MThd' + struct.pack('>IHHH', 6, 0, 1, PPQ) + b'MTrk' + struct.pack('>I', len(trk)) + trk)

class Style:
    def __init__(s, genre, name, bpm, verse, verse2=None, chorus=None, chorus2=None, intro=None,
                 ts=(4, 4), swing=0.0, soft=1.0, fills=None, triplet=False):
        s.genre, s.name, s.bpm, s.ts, s.swing, s.soft = genre, name, bpm, ts, swing, soft
        s.verse, s.verse2 = verse, verse2 or verse
        s.chorus, s.chorus2 = chorus or verse, chorus2 or chorus or verse2 or verse
        s.intro = intro
        # 4/4 terzinato: 12 passi per battuta (terzine di ottavi); 12/8: 12 ottavi.
        if ts[1] == 8:
            s.steps, s.step_ticks = ts[0], PPQ // 2          # ottavi
        else:
            per = 3 if triplet else 4                        # terzine o sedicesimi per battito
            s.steps, s.step_ticks = ts[0] * per, PPQ // per
        s.bar_ticks = s.steps * s.step_ticks
        s.fills = fills

    def tick(s, bar, i):
        t = bar * s.bar_ticks + i * s.step_ticks
        if s.swing and s.steps == 16 and i % 2 == 1:
            t += int(s.step_ticks * s.swing)
        return t

    def render(s, bars):
        out = []
        for b, pattern in enumerate(bars):
            for inst, line in pattern.items():
                assert len(line) == s.steps, (s.name, inst, line)
                for i, ch in enumerate(line):
                    if ch in VEL:
                        out.append((s.tick(b, i), N[inst], int(VEL[ch] * s.soft)))
        return out

def half(p, steps, keep_first):
    """Prima metà (o più) della battuta del groove; il resto vuoto."""
    return {k: v[:keep_first] + '.' * (steps - keep_first) for k, v in p.items()}

def merge(a, b):
    out = dict(a)
    for k, v in b.items():
        if k in out:
            out[k] = ''.join(y if y != '.' else x for x, y in zip(out[k], v))
        else:
            out[k] = v
    return out

def fills16(st):
    base = half(st.verse, 16, 8)
    f1 = merge(base, {'S': '........xx-xxXXX', 'K': '........x.......'})
    f2 = merge(base, {'TH': '........xx......', 'TM': '..........xx....', 'TL': '............xx..', 'TF': '..............XX', 'K': '........x...x...'})
    f3 = merge(half(st.verse, 16, 4), {'S': '....X..X..X..X.X', 'K': '..x..x..x..x.x..', 'C': '............X...'})
    return [('Fill 1 rullante', f1), ('Fill 2 tom', f2), ('Fill 3 sincopato', f3)]

def fills12(st):
    base = half(st.verse, 12, 6)
    f1 = merge(base, {'S': '......g-xxXX', 'K': '......x.....'})
    f2 = merge(base, {'TH': '......xx....', 'TM': '........xx..', 'TF': '..........XX', 'K': '......x..x..'})
    f3 = merge(half(st.verse, 12, 3), {'S': '...x..x.xX.X', 'K': '.x..x..x....'})
    return [('Fill 1 rullante', f1), ('Fill 2 tom', f2), ('Fill 3 terzine', f3)]

def fills_generic(st):
    n = st.steps
    h = n // 2
    base = half(st.verse, n, h)
    rest = n - h
    roll = ''.join('X' if i >= rest - 2 else ('x' if i % 2 == 0 else '-') for i in range(rest))
    f1 = merge(base, {'S': '.' * h + roll, 'K': '.' * h + 'x' + '.' * (rest - 1)})
    q = max(1, rest // 4)
    toms = {'TH': 0, 'TM': 1, 'TL': 2, 'TF': 3}
    f2 = dict(base)
    for t, k in toms.items():
        line = ['.'] * n
        for i in range(h + k * q, min(n, h + (k + 1) * q if k < 3 else n)):
            line[i] = 'X' if (t == 'TF' and i >= n - 2) else 'x'
        f2 = merge(f2, {t: ''.join(line)})
    f2 = merge(f2, {'K': '.' * h + 'x' + '.' * (rest - 1)})
    third = n // 4
    s3 = ['.'] * n; k3 = ['.'] * n
    for i in range(third, n):
        if (i - third) % 3 == 0: s3[i] = 'X'
        elif (i - third) % 3 == 2: k3[i] = 'x'
    f3 = merge(half(st.verse, n, third), {'S': ''.join(s3), 'K': ''.join(k3)})
    return [('Fill 1 rullante', f1), ('Fill 2 tom', f2), ('Fill 3 terzine' if st.steps % 3 == 0 else 'Fill 3 sincopato', f3)]

def build(st):
    S = st.steps
    crash = {'C': 'X' + '.' * (S - 1)}
    endhit = {'C': 'X' + '.' * (S - 1), 'K': 'X' + '.' * (S - 1)}
    if st.fills:
        fills = st.fills(st)
    elif S == 16:
        fills = fills16(st)
    elif S == 12:
        fills = fills12(st)
    else:
        fills = fills_generic(st)
    intro = st.intro or [half({k: v for k, v in st.verse.items() if k in ('H', 'Y', 'P', 'R', 'T')}, S, S), fills[0][1]]
    parts = [
        ('Intro', intro),
        ('Strofa', [st.verse, st.verse2]),
        ('Ritornello', [merge(st.chorus, crash), st.chorus2]),
    ] + [(n, [f]) for n, f in fills] + [
        ('Finale', [fills[0][1], endhit]),
    ]
    for part, bars in parts:
        name = f'{st.genre} {st.name} - {part}'
        write(os.path.join(OUT, st.genre, name + '.mid'), st.render(bars), name, st.ts, st.bpm)

H8 = 'x.x.x.x.x.x.x.x.'
STYLES = [
    # ---------- POP-ROCK ----------
    Style('Pop-rock', 'Ottavi', 120,
          verse={'H': 'X.x.X.x.X.x.X.x.', 'K': 'x.....x.x.......', 'S': '....X.......X...'},
          verse2={'H': 'X.x.X.x.X.x.X.x.', 'K': 'x.....x.x.x.....', 'S': '....X.......X..g'},
          chorus={'O': 'x.x.x.x.x.x.x.x.', 'K': 'x.....x.x.x.....', 'S': '....X.......X...'},
          chorus2={'O': 'x.x.x.x.x.x.x.x.', 'K': 'x.x...x.x.x.....', 'S': '....X.......X.x.'}),
    Style('Pop-rock', 'Ballata', 72, soft=0.85,
          verse={'H': 'x.-.x.-.x.-.x.-.', 'K': 'x.......x.x.....', 'S': '....X.......X...'},
          verse2={'H': 'x.-.x.-.x.-.x.-.', 'K': 'x......xx.......', 'S': '....X.......X...'},
          chorus={'Y': 'x.x.x.x.x.x.x.x.', 'K': 'x.......x.x.....', 'S': '....X.......X...'},
          chorus2={'Y': 'x.x.x.x.x.x.x.x.', 'K': 'x......xx.x.....', 'S': '....X.......X...'}),
    Style('Pop-rock', 'Quattro in battere', 118,
          verse={'H': 'x.x.x.x.x.x.x.x.', 'K': 'x...x...x...x...', 'S': '....X.......X...'},
          chorus={'H': 'x...x...x...x...', 'O': '..x...x...x...x.', 'K': 'x...x...x...x...', 'S': '....X.......X...', 'CL': '....x.......x...'}),
    # ---------- SOUL ----------
    Style('Soul', 'Motown', 120,
          verse={'H': H8, 'K': 'x.x...x.x.x...x.', 'S': '-...X...-...X...', 'T': '....x.......x...'},
          verse2={'H': H8, 'K': 'x.x...x.x.x.x...', 'S': '-...X...-...X...', 'T': '....x.......x...'},
          chorus={'H': H8, 'K': 'x.x...x.x.x...x.', 'S': 'x...X...x...X...', 'T': 'x.x.x.x.x.x.x.x.'}),
    Style('Soul', 'Memphis', 100,
          verse={'H': 'X.x.X.x.X.x.X.x.', 'K': 'x......x..x.....', 'S': '....X.......X...'},
          verse2={'H': 'X.x.X.x.X.x.X.x.', 'K': 'x.....x...x.....', 'S': '....X.....g.X...'},
          chorus={'H': 'X.x.X.x.X.x.X.o.', 'K': 'x......x..x.....', 'S': '....X.......X...', 'T': '....x.......x...'},
          chorus2={'H': 'X.x.X.x.X.x.X.o.', 'K': 'x.....x...x..x..', 'S': '....X.......X...', 'T': '....x.......x...'}),
    Style('Soul', 'Philly', 110,
          verse={'H': 'x-x-x-x-x-x-x-x-', 'K': 'x...x...x...x...', 'S': '....X.......X...'},
          chorus={'H': 'x...x...x...x...', 'O': '..x...x...x...x.', 'K': 'x...x...x...x...', 'S': '....X.......X...', 'T': 'x.x.x.x.x.x.x.x.'}),
    Style('Soul', 'Neo soul', 85, swing=0.33, soft=0.85,
          verse={'H': 'x-x-x-x-x-x-x-x-', 'K': 'x......x.x....x.', 'R': '....X.......X...'},
          verse2={'H': 'x-x-x-x-x-x-x-x-', 'K': 'x......x..x...x.', 'R': '....X.......X..x'},
          chorus={'H': 'x-x-x-x-x-x-x-x-', 'K': 'x......x.x....x.', 'S': '....X..g....X.g.'},
          chorus2={'H': 'x-x-x-x-x-x-o-x-', 'K': 'x......x..x...x.', 'S': '....X..g.g..X...'}),
    Style('Soul', 'Ballata 12-8', 120, ts=(12, 8), soft=0.85,
          verse={'H': 'x--x--x--x--', 'K': 'x.....x..x..', 'S': '...X.....X..'},
          verse2={'H': 'x--x--x--x--', 'K': 'x....xx.....', 'S': '...X.....X.g'},
          chorus={'Y': 'x--x--x--x--', 'K': 'x.....x..x..', 'S': '...X.....X..'},
          chorus2={'Y': 'x--x--x--x--', 'K': 'x....xx..x..', 'S': '...X.....X..'}),
    # ---------- FUNK ----------
    Style('Funk', 'Sedicesimi', 100,
          verse={'H': 'X-x-X-x-X-x-X-x-', 'K': 'x.x.......x..x..', 'S': '....X..g.g..X..g'},
          verse2={'H': 'X-x-X-x-X-x-X-x-', 'K': 'x.x....x..x.....', 'S': '....X..g.g..X.g.'},
          chorus={'H': 'X-x-X-x-X-x-X-o-', 'K': 'x.x.......x..x..', 'S': '....X..g.g..X..g'},
          chorus2={'H': 'X-x-X-x-X-x-X-o-', 'K': 'x.x....x..x..x..', 'S': '....X..g.g..X.gX'}),
    Style('Funk', 'Break', 96,
          verse={'H': 'x.x.x.x.x.x.x.o.', 'K': 'x.x.......x.x...', 'S': '....X..g.g.gX..g'},
          verse2={'H': 'x.x.x.x.x.x.x.o.', 'K': 'x.x.......x...x.', 'S': '....X..g.g..X.g.'},
          chorus={'Y': 'x.x.x.x.x.x.x.x.', 'B': 'x...x...x...x...', 'K': 'x.x.......x.x...', 'S': '....X..g.g.gX..g'}),
    Style('Funk', 'New Orleans', 100,
          verse={'H': H8, 'K': 'x..x..x...x..x..', 'S': '....X..x..x.X..g'},
          verse2={'H': H8, 'K': 'x..x..x...x.....', 'S': '..g.X..x..x.X.x.'},
          chorus={'B': 'x.x.x.x.x.x.x.x.', 'K': 'x..x..x...x..x..', 'S': '....X..x..x.X..g'}),
]

T = 'x.xx.xx.xx.x'   # shuffle: battito + terza terzina
STYLES += [
    # ---------- POP-ROCK TERZINATI ----------
    Style('Pop-rock', 'Shuffle', 120, triplet=True,
          verse={'H': T, 'K': 'x.....x.....', 'S': '...X.....X..'},
          verse2={'H': T, 'K': 'x....xx.....', 'S': '...X.....X.g'},
          chorus={'Y': 'X.xX.xX.xX.x', 'K': 'x.....x..x..', 'S': '...X.....X..'},
          chorus2={'Y': 'X.xX.xX.xX.x', 'K': 'x....xx..x..', 'S': '...X.....X.x'}),
    Style('Pop-rock', 'Shuffle a metà tempo', 84, triplet=True,
          verse={'H': 'xgxxgxxgxxgx', 'K': 'x....x...x..', 'S': '..g.g.X.g..g'},
          verse2={'H': 'xgxxgxxgxxgx', 'K': 'x....x..xx..', 'S': '..g.g.X.g.gg'},
          chorus={'O': 'x..x..x..x..', 'H': '.gx.gx.gx.gx', 'K': 'x....x...x..', 'S': '....g.X....g'}),
    Style('Pop-rock', 'Ballata 12-8', 132, ts=(12, 8),
          verse={'H': 'x--x--x--x--', 'K': 'x.....x.....', 'S': '...X.....X..'},
          verse2={'H': 'x--x--x--x--', 'K': 'x.....x.x...', 'S': '...X.....X..'},
          chorus={'O': 'x..x..x..x..', 'H': '.--.--.--.--', 'K': 'x....xx.....', 'S': '...X.....X..'},
          chorus2={'O': 'x..x..x..x..', 'H': '.--.--.--.--', 'K': 'x....xx..x..', 'S': '...X.....XX.'}),
    # ---------- SOUL TERZINATI ----------
    Style('Soul', 'Shuffle', 110, triplet=True,
          verse={'H': T, 'K': 'x....xx.....', 'S': '...X.....X..', 'T': '...x.....x..'},
          verse2={'H': T, 'K': 'x....xx..x..', 'S': '...X.....X..', 'T': '...x.....x..'},
          chorus={'H': T, 'K': 'x....xx.....', 'S': '...X.....X..', 'T': 'x.xx.xx.xx.x'}),
    Style('Soul', 'Shuffle a metà tempo', 80, triplet=True, soft=0.9,
          verse={'H': 'xgxxgxxgxxgx', 'K': 'x....x...x..', 'S': '.g..g.X..g.g'},
          verse2={'H': 'xgxxgxxgxxgx', 'K': 'x..x.x...x..', 'S': '.g..g.X.gg.g'},
          chorus={'Y': 'x.xx.xx.xx.x', 'K': 'x....x...x..', 'S': '.g..g.X..g.g'}),
    Style('Soul', 'Gospel 12-8', 132, ts=(12, 8),
          verse={'Y': 'x--x--x--x--', 'K': 'x..x.xx.....', 'S': '...X.....X.g', 'P': '...x.....x..'},
          verse2={'Y': 'x--x--x--x--', 'K': 'x..x.xx..x..', 'S': '...X.....X..', 'P': '...x.....x..'},
          chorus={'Y': 'x--x--x--x--', 'K': 'x..x.xx..x.x', 'S': '...X..g..X.g', 'T': '...x.....x..'}),
]

SW = 'x..x.xx..x.x'   # ride swing: 1, 2, 2-e, 3, 4, 4-e
STYLES += [
    # ---------- JAZZ ----------
    Style('Jazz', 'Swing', 140, triplet=True,
          verse={'Y': SW, 'P': '...x.....x..', 'K': 'g..g..g..g..', 'S': '.....g...g..'},
          verse2={'Y': SW, 'P': '...x.....x..', 'K': 'g..g..g..g..', 'S': '..g.....g..g'},
          chorus={'Y': 'X..x.xX..x.x', 'P': '...x.....x..', 'K': 'g..g..g..g.x', 'S': '..g..g..xg..'},
          fills=fills_generic),
    Style('Jazz', 'Ballata spazzole', 60, triplet=True, soft=0.6,
          verse={'S': SW, 'P': '...x.....x..', 'K': 'g.....g.....'},
          verse2={'S': SW, 'P': '...x.....x..', 'K': 'g.....g..g..'},
          chorus={'Y': SW, 'S': '...x.....x..', 'P': '...x.....x..', 'K': 'g.....g.....'},
          fills=fills_generic),
    Style('Jazz', 'Valzer', 150, ts=(3, 4), triplet=True,
          verse={'Y': 'x..x.xx..', 'P': '...x..x..', 'K': 'g........', 'S': '......g..'},
          verse2={'Y': 'x..x.xx..', 'P': '...x..x..', 'K': 'g.....g..', 'S': '.....g...'},
          chorus={'Y': 'X..x.xx..', 'P': '...x..x..', 'K': 'g.....g..', 'S': '..g...g.g'}),
    Style('Jazz', 'Bossa nova', 130, soft=0.85,
          verse={'R': 'x..x..x...x..x..', 'K': 'x..xx..xx..xx..x', 'H': 'x.x.x.x.x.x.x.x.'},
          verse2={'R': '..x..x...x..x...', 'K': 'x..xx..xx..xx..x', 'H': 'x.x.x.x.x.x.x.x.'},
          chorus={'R': 'x..x..x...x..x..', 'K': 'x..xx..xx..xx..x', 'Y': 'x.x.x.x.x.x.x.x.'},
          chorus2={'R': '..x..x...x..x...', 'K': 'x..xx..xx..xx..x', 'Y': 'x.x.x.x.x.x.x.x.'},
          fills=fills_generic),
]

for st in STYLES:
    build(st)
print('ok')
