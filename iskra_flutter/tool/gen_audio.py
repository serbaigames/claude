#!/usr/bin/env python3
"""Музыка и звуки «Искры»: синтез с нуля (numpy + ffmpeg), чтобы не тащить чужие файлы.

Запуск: python3 tool/gen_audio.py  → assets/audio/*.mp3 (музыка) и *.wav (звуки).
Сиды фиксированы — повторный запуск даёт те же файлы.
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8,
        'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env(n, a, d, s, r, sus_len):
    """ADSR по отсчётам: a, d, r — секунды, s — уровень, sus_len — длина ноты до отпускания."""
    t = np.arange(n) / SR
    e = np.ones(n) * s
    if a > 0:
        e = np.where(t < a, t / a, e)
    m = (t >= a) & (t < a + d)
    e[m] = 1 - (1 - s) * (t[m] - a) / max(d, 1e-6)
    rel = t >= sus_len
    lvl = np.interp(sus_len, t, e) if n else 0
    e[rel] = lvl * np.exp(-(t[rel] - sus_len) / max(r, 1e-4) * 4)
    return e


def tone(f, dur, bright=8.0, harm=24, kind='saw', detune=0.0, vib=0.0, rel=0.4, a=0.01, d=0.2, s=0.6, phase=0.0):
    """Сумма гармоник с мягким срезом: тёплый «аналоговый» тембр без алиасинга."""
    n = int((dur + rel) * SR)
    t = np.arange(n) / SR
    fm = f * (1 + vib * 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.4, 0, 1))
    ph = 2 * np.pi * np.cumsum(fm) / SR + phase
    out = np.zeros(n)
    for dt in ([0.0] if detune == 0 else [-detune, 0.0, detune]):
        mul = 2 ** (dt / 1200)
        for h in range(1, harm + 1):
            if f * h * mul > SR / 2.3:
                break
            if kind == 'square' and h % 2 == 0:
                continue
            amp = (1 / h) * np.exp(-(h - 1) / bright)
            if kind == 'sine':
                amp = 1.0 if h == 1 else 0
            out += amp * np.sin(ph * mul * h)
    out /= max(1e-9, np.max(np.abs(out)))
    return out * env(n, a, d, s, rel, dur)


def bell(f, dur, rel=2.0):
    n = int((dur + rel) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, dec in [(1, 1, 1.0), (2.76, .45, 2.2), (5.4, .25, 3.5), (8.93, .12, 5)]:
        out += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * dec * 1.6)
    return out * np.clip(t / 0.003, 0, 1) * 0.5


def noise(n, rng):
    return rng.standard_normal(n)


def lp_noise(n, rng, k=8):
    x = noise(n + k, rng)
    return np.convolve(x, np.ones(k) / k, 'same')[:n]


def kick(rng):
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 42 + 90 * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7) * 0.9


def hat(rng, open_=False):
    n = int((0.25 if open_ else 0.06) * SR)
    t = np.arange(n) / SR
    x = noise(n, rng)
    x = x - np.convolve(x, np.ones(3) / 3, 'same')  # грубый ВЧ-фильтр
    return x * np.exp(-t * (14 if open_ else 60)) * 0.25


def snare(rng):
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 20)
    return (body * 0.5 + lp_noise(n, rng, 2) * np.exp(-t * 16) * 0.6) * 0.6


def tom(rng, f0=110):
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = f0 * (1 + 0.5 * np.exp(-t * 12))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6) * 0.7


def reverb(x, rng, secs=2.6, mix=0.3):
    """Свёртка с затухающим шумом — простая «космическая» реверберация, стерео."""
    n = int(secs * SR)
    t = np.arange(n) / SR
    out = []
    for ch in range(2):
        ir = lp_noise(n, rng, 3) * np.exp(-t * 3.2 / secs * 2)
        ir[: int(0.012 * SR)] = 0
        ir /= np.sqrt(np.sum(ir ** 2))
        L = len(x) + n
        N = 1 << (L - 1).bit_length()
        w = np.fft.irfft(np.fft.rfft(x[:, ch], N) * np.fft.rfft(ir, N), N)[: len(x)]
        out.append(w)
    w = np.stack(out, 1)
    return x * (1 - mix) + w * mix * 1.4


def delay(x, secs, fb=0.4, n=4, pan=True):
    out = x.copy()
    d = int(secs * SR)
    g = 1.0
    for i in range(1, n + 1):
        g *= fb
        sh = np.zeros_like(x)
        if d * i < len(x):
            sh[d * i:] = x[: len(x) - d * i] * g
            if pan:
                sh[:, (i % 2)] *= 0.55
        out += sh
    return out


class Mix:
    def __init__(self, secs, tail=3.0):
        self.len = int(secs * SR)
        self.buf = np.zeros((self.len + int(tail * SR), 2))

    def add(self, sig, at, gain=1.0, pan=0.0):
        i = int(at * SR)
        if i >= len(self.buf):
            return
        sig = sig[: len(self.buf) - i]
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        self.buf[i: i + len(sig), 0] += sig * gain * l * 1.41
        self.buf[i: i + len(sig), 1] += sig * gain * r * 1.41

    def bus(self):
        return Bus(self)

    def loop(self):
        """Хвост за концом цикла накладывается на начало — шов не слышен."""
        b = self.buf
        out = b[: self.len].copy()
        tail = b[self.len:]
        out[: len(tail)] += tail
        return out


class Bus(Mix):
    def __init__(self, parent):
        self.len = parent.len
        self.buf = np.zeros_like(parent.buf)


def chord_notes(name, octave=4):
    """'Am', 'F', 'Cmaj7', 'Dm7', 'Gsus4', 'Em' → midi"""
    root = name[0] + (name[1] if len(name) > 1 and name[1] in '#b' else '')
    q = name[len(root):]
    r = 12 * (octave + 1) + NOTE[root]
    iv = {'': [0, 4, 7], 'm': [0, 3, 7], 'maj7': [0, 4, 7, 11], 'm7': [0, 3, 7, 10], '7': [0, 4, 7, 10],
          'sus4': [0, 5, 7], 'sus2': [0, 2, 7], 'add9': [0, 4, 7, 14], 'madd9': [0, 3, 7, 14]}[q]
    return [r + i for i in iv]


def scale_notes(key, mode):
    steps = {'aeolian': [0, 2, 3, 5, 7, 8, 10], 'dorian': [0, 2, 3, 5, 7, 9, 10], 'ionian': [0, 2, 4, 5, 7, 9, 11]}[mode]
    base = NOTE[key]
    return sorted({12 * o + base + s for o in range(3, 8) for s in steps})


def melody(rng, chords, scale, beats_per_bar, lo=67, hi=86, density=0.55):
    """Мелодия фразами A A' B A: опора на звуки аккорда, ход по гамме."""
    def phrase(bars):
        out = []
        cur = int(rng.choice([n for n in scale if lo + 4 <= n <= hi - 6]))
        for bi, ch in enumerate(bars):
            tones = [n % 12 for n in chord_notes(ch)]
            pos = 0.0
            pats = [[1, 1, 1, 1], [1.5, .5, 2], [2, 1, 1], [.5, .5, 1, 2], [3, 1], [1, .5, .5, 2], [4]]
            pat = pats[rng.integers(len(pats))]
            pat = [p * beats_per_bar / 4 for p in pat]
            for k, dur in enumerate(pat):
                if rng.random() > density and k > 0:
                    pos += dur
                    continue
                strong = k == 0 or pos % 2 == 0
                cands = [n for n in scale if lo <= n <= hi and abs(n - cur) <= (5 if strong else 3)]
                if strong:
                    ct = [n for n in cands if n % 12 in tones]
                    cands = ct or cands
                cur = int(rng.choice(cands)) if cands else cur
                out.append((bi, pos, dur, cur))
                pos += dur
        return out
    n = len(chords)
    q = n // 4
    A = phrase(chords[:q])
    A2 = phrase(chords[q:2 * q])
    A2 = A[: len(A) // 2] + [x for x in A2 if x[0] >= q // 2]
    B = phrase(chords[2 * q:3 * q])
    res = [(b, p, d, m) for (b, p, d, m) in A]
    res += [(b + q if b < q // 2 else b, p, d, m) for (b, p, d, m) in A2]
    res += [(b + 2 * q, p, d, m) for (b, p, d, m) in B]
    res += [(b + 3 * q, p, d, m) for (b, p, d, m) in A]
    return res


def song(name, seed, bpm, prog, key, mode, bars, drums=True, arp=True, lead=True, battle=False, bells=False):
    rng = np.random.default_rng(seed)
    beat = 60 / bpm
    bar = beat * 4
    chords = (prog * (bars // len(prog) + 1))[:bars]
    m = Mix(bars * bar, tail=4)
    pad, arpb, leadb, bass, drum = m.bus(), m.bus(), m.bus(), m.bus(), m.bus()
    scale = scale_notes(key, mode)
    for i, ch in enumerate(chords):
        t0 = i * bar
        notes = chord_notes(ch, 3 if battle else 4)
        # пэд: расстроенные пилы с мягким срезом
        for j, nn in enumerate(notes):
            pad.add(tone(hz(nn), bar, bright=3 if not battle else 4, detune=9, a=0.6 if not battle else 0.05, d=1.0,
                         s=0.75, rel=1.2, phase=j), t0, 0.11, pan=(j - 1.5) * 0.35)
        # бас
        root = chord_notes(ch, 2)[0]
        if battle:
            for s16 in range(16):
                if s16 % 4 == 3 and rng.random() < .5:
                    continue
                nn = root + (12 if s16 % 8 == 6 else 0)
                bass.add(tone(hz(nn), beat / 4 * 0.8, bright=5, kind='saw', a=0.003, d=0.08, s=0.5, rel=0.05),
                         t0 + s16 * beat / 4, 0.32)
        else:
            for k, (pos, dur) in enumerate([(0, 1.5), (1.5, .5), (2, 1.5), (3.5, .5)] if drums else [(0, 4)]):
                nn = root + (7 if k == 3 else 0)
                bass.add(tone(hz(nn), dur * beat * 0.9, bright=2.5, kind='square', a=0.01, d=0.2, s=0.7, rel=0.15),
                         t0 + pos * beat, 0.3)
        # арпеджио
        if arp:
            seq = notes + [notes[1] + 12, notes[2] + 12, notes[0] + 12]
            order = [0, 1, 2, 3, 4, 2, 1, 3] if len(seq) > 4 else [0, 1, 2, 1]
            step = beat / 2 if not battle else beat / 4
            for s8 in range(int(bar / step)):
                nn = seq[order[s8 % len(order)] % len(seq)] + 12
                arpb.add(tone(hz(nn), step * 0.6, bright=6, kind='saw', a=0.002, d=0.12, s=0.15, rel=0.2),
                         t0 + s8 * step, 0.12, pan=0.4 * np.sin(s8))
        if bells and i % 2 == 0:
            for k in range(2):
                nn = rng.choice([n for n in scale if 76 <= n <= 93])
                arpb.add(bell(hz(nn), 1.5), t0 + rng.integers(0, 4) * beat, 0.16, pan=rng.uniform(-.7, .7))
        # ударные
        if drums:
            for b4 in range(4):
                tb = t0 + b4 * beat
                if battle:
                    drum.add(kick(rng), tb, 0.9)
                    drum.add(hat(rng), tb + beat / 2, 0.5, pan=.3)
                    if b4 in (1, 3):
                        drum.add(snare(rng), tb, 0.7)
                    if i % 4 == 3 and b4 == 3:
                        for k in range(4):
                            drum.add(tom(rng, 140 - k * 18), tb + k * beat / 4, 0.6, pan=-.4 + k * .25)
                else:
                    if b4 in (0, 2) or (b4 == 3 and i % 2):
                        drum.add(kick(rng), tb + (beat / 2 if b4 == 3 else 0), 0.7)
                    if b4 in (1, 3):
                        drum.add(snare(rng), tb, 0.35)
                    for h in range(2):
                        drum.add(hat(rng, open_=(h == 1 and b4 == 3)), tb + h * beat / 2, 0.35, pan=.25)
    # мелодия: вступает со второй четверти, если трек длинный
    if lead:
        mel = melody(rng, chords, scale, 4, lo=64 if battle else 67, hi=84 if battle else 86,
                     density=0.75 if battle else 0.55)
        for bi, pos, dur, nn in mel:
            if bi < 4 and not battle:
                continue
            leadb.add(tone(hz(nn), dur * beat * 0.92, bright=5 if battle else 3.5, detune=4, vib=1.0, a=0.03, d=0.3,
                           s=0.65, rel=0.35), bi * bar + pos * beat, 0.2)
    arp_wet = delay(arpb.buf, beat * 0.75, 0.38, 4)
    lead_wet = delay(leadb.buf, beat * 0.75, 0.3, 3)
    room = pad.buf + arp_wet + lead_wet * 1.0
    room = reverb(room, rng, secs=3.2, mix=0.45)
    m.buf = room + bass.buf + drum.buf * (0.8 if drums else 0)
    out = m.loop()
    out /= np.max(np.abs(out)) / 0.89
    out = np.tanh(out * 1.1) / np.tanh(1.1)
    write_mp3(name, out)


def write_wav(path, x, sr=SR):
    x = np.clip(x, -1, 1)
    if x.ndim == 1:
        x = x[:, None]
    with wave.open(path, 'wb') as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((x * 32000).astype('<i2').tobytes())


def write_mp3(name, x):
    tmp = os.path.join(OUT, name + '.tmp.wav')
    write_wav(tmp, x)
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', tmp, '-codec:a', 'libmp3lame', '-b:a', '96k',
                    os.path.join(OUT, name + '.mp3')], check=True)
    os.remove(tmp)


# ---------- звуки ----------
def sweep(f0, f1, dur, kind='sine', curve=1.0):
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    f = f0 + (f1 - f0) * t ** curve
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == 'saw':
        return sum(np.sin(ph * h) / h for h in range(1, 8))
    return np.sin(ph)


def fade(x, a=0.003, r=None):
    n = len(x)
    t = np.arange(n) / SR
    e = np.clip(t / a, 0, 1)
    if r:
        e *= np.exp(-t * r)
    return x * e


def seq(parts):
    """parts: [(сигнал, сек)] → смешанный моно-сигнал"""
    n = max(int(at * SR) + len(s) for s, at in parts)
    out = np.zeros(n)
    for s, at in parts:
        i = int(at * SR)
        out[i: i + len(s)] += s
    return out


def sfx_all():
    rng = np.random.default_rng(7)
    p = lambda m, d=0.12, br=4, r=0.2: tone(hz(m), d, bright=br, a=0.002, d=0.08, s=0.4, rel=r)
    sounds = {
        'tap': fade(sweep(1400, 900, 0.045), r=60) * 0.5,
        'open': seq([(p(79, .05, 3, .15), 0), (p(84, .06, 3, .25), .05)]) * 0.45,
        'close': seq([(p(84, .05, 3, .12), 0), (p(79, .06, 3, .2), .05)]) * 0.4,
        'capture': seq([(p(72 + i * 4 - (i > 1), .07, 5, .3), i * .06) for i in range(4)] + [(bell(hz(91), .1, 1.0) * .6, .24)]) * 0.5,
        'build': seq([(fade(lp_noise(int(.12 * SR), rng, 20), r=30) * .9, 0), (tom(rng, 160) * .8, 0), (bell(hz(84), .1, .8) * .5, .06)]) * 0.55,
        'level': seq([(bell(hz(88), .1, 1.2), 0), (bell(hz(95), .1, 1.4) * .7, .09)]) * 0.5,
        'tech': seq([(tone(hz(m), .6, bright=3, detune=8, a=.08, d=.3, s=.7, rel=.8) * .35, .05 * i) for i, m in enumerate([67, 71, 74, 79, 83])]) * 0.6,
        'era': seq([(tone(hz(43), 1.2, bright=3, detune=10, a=.4, d=.4, s=.8, rel=1.0) * .7, 0), (bell(hz(79), .1, 2.0) * .6, .3), (bell(hz(86), .1, 2.0) * .4, .5)]) * 0.55,
        'alarm': seq([(tone(hz(m), .11, bright=3, kind='square', a=.005, d=.05, s=.8, rel=.04) * .5, i * .14) for i, m in enumerate([81, 76, 81, 76])]) * 0.55,
        'lost': seq([(tone(hz(m), .16, bright=3, detune=12, a=.005, d=.1, s=.6, rel=.25) * .5, i * .12) for i, m in enumerate([67, 63, 60, 55])]) * 0.55,
        'zap': fade(sweep(1800, 220, .16, 'saw', .5), r=14) * 0.32,
        'cast': seq([(fade(sweep(300, 1500, .35, 'saw', 1.5), r=6) * .25, 0), (fade(lp_noise(int(.4 * SR), rng, 4), .1, 7) * .25, 0), (bell(hz(91), .1, 1.0) * .4, .3)]) * 0.6,
        'hurt': seq([(fade(lp_noise(int(.2 * SR), rng, 6), r=22) * .9, 0), (tom(rng, 70) * .9, 0)]) * 0.55,
        'heal': seq([(fade(np.sin(2 * np.pi * np.cumsum(np.linspace(hz(72), hz(84), int(.4 * SR))) / SR), .05, 6) * .4, 0), (bell(hz(96), .1, .8) * .3, .2)]) * 0.55,
        'start': seq([(fade(lp_noise(int(.9 * SR), rng, 30), .3, 4) * 1.5, 0), (bell(hz(48), .1, 2.0) * 1.0, .45), (bell(hz(55), .1, 2.0) * .6, .45)]) * 0.5,
        'win': seq([(p(m, .12 if i < 3 else .5, 4, .6) * .45, i * .1) for i, m in enumerate([72, 76, 79, 84])] + [(bell(hz(96), .1, 1.5) * .4, .3)]) * 0.6,
        'lose': seq([(tone(hz(m), .3, bright=3, detune=10, a=.01, d=.2, s=.6, rel=.5) * .45, i * .22) for i, m in enumerate([67, 66, 63, 55])]) * 0.55,
        'jump': seq([(fade(sweep(80, 1600, 1.4, 'saw', 2.2), .2, 1.5) * .25, 0), (fade(lp_noise(int(1.6 * SR), rng, 12), .6, 2.5) * .8, 0), (bell(hz(84), .1, 2.0) * .6, 1.3)]) * 0.55,
        'buy': seq([(bell(hz(98), .1, .5) * .6, 0), (bell(hz(103), .1, .7) * .6, .07)]) * 0.5,
        'art': seq([(bell(hz(m), .1, 1.0) * .35, i * .05) for i, m in enumerate([86, 91, 93, 98, 103])]) * 0.55,
        'error': seq([(tone(hz(52), .12, bright=2, kind='square', a=.004, d=.05, s=.7, rel=.05) * .5, 0), (tone(hz(49), .16, bright=2, kind='square', a=.004, d=.05, s=.7, rel=.08) * .5, .13)]) * 0.5,
    }
    for k, x in sounds.items():
        x = x / max(1e-9, np.max(np.abs(x))) * (0.9 if k not in ('tap', 'open', 'close') else 0.5)
        write_wav(os.path.join(OUT, f'sfx_{k}.wav'), x, SR)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    sfx_all()
    song('music_drift', 11, 84, ['Am', 'F', 'C', 'G', 'Am', 'F', 'G', 'Em'], 'A', 'aeolian', 32)
    song('music_nebula', 23, 72, ['Dm7', 'Gsus4', 'Dm7', 'Am', 'Bb', 'F', 'Gsus4', 'A'], 'D', 'dorian', 24, drums=False,
         bells=True)
    song('music_pulsar', 31, 100, ['Em', 'C', 'G', 'D', 'Em', 'C', 'Am', 'B'], 'E', 'aeolian', 32)
    song('music_battle', 47, 128, ['Cm', 'Ab', 'Bb', 'G', 'Cm', 'Ab', 'Fm', 'G'], 'C', 'aeolian', 32, battle=True)
