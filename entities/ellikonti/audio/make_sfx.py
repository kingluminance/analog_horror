"""Synthesises the sound effects for Ellikonti's post-contract cutscene.

Run:  python entities/ellikonti/audio/make_sfx.py      (numpy + scipy)
Writes the .wav files next to this script. Like the rest of the project's
SFX nothing is sampled -- every sound is built from sines/noise here, so it
can be re-tuned and regenerated. To swap one for a real recording, just
overwrite the .wav with the same file name; the cutscene only knows names.

Cue list (see contract_cutscene.tscn for where each one sits on the timeline):
  church_bell      1 black arms appear  -- big, low church bell
  rubber_stretch   1 arms stretching out like rubber
  wet_grab         2 finger-ends grab the corners of the mouth
  tear_1/2/3       3 the mouth is torn wider in three steps, each one longer
                     and louder: "약간" -> "좌악." -> "좌아악!"
  low_drone        4 swelling low hum while the mouth gets big enough to eat you
  whoosh           5 lunging / being sucked in
  gulp             5 "꿀꺽" -- the cut to black
  small_bell       6 small clear bell when the white light sweeps the dark
  small_bell_far   6 same bell, distant, rung again in the silence
  star_burst       7 "쨔라라라랑~" as the stars burst up once in the next scene
"""
import os
import wave

import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(7)


def t_axis(seconds):
    return np.arange(int(SR * seconds)) / SR


def bandpass(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return lfilter(b, a, x)


def lowpass(x, cutoff, order=2):
    b, a = butter(order, cutoff / (SR / 2), btype="low")
    return lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = butter(order, cutoff / (SR / 2), btype="high")
    return lfilter(b, a, x)


def glide(f0, f1, seconds, curve=1.0):
    """Phase of a sine whose frequency glides f0 -> f1."""
    t = t_axis(seconds)
    k = (t / seconds) ** curve
    freq = f0 + (f1 - f0) * k
    return 2 * np.pi * np.cumsum(freq) / SR


def reverb(x, seconds=2.5, mix=0.35, damp=4000):
    """Cheap Schroeder-style tail: a few feedback combs, lowpassed."""
    pad = np.zeros(int(SR * seconds))
    dry = np.concatenate([x, pad])
    tail = np.zeros_like(dry)
    for delay_ms, fb in ((29.7, 0.84), (37.1, 0.83), (41.1, 0.82), (43.7, 0.81)):
        d = int(SR * delay_ms / 1000)
        y = dry.copy()
        for i in range(d, len(y), d):  # recursive comb, one delay-length block at a time
            end = min(i + d, len(y))
            y[i:end] += fb * y[i - d:end - d]
        tail += y
    tail = lowpass(tail / 4, damp)
    return dry * (1 - mix) + tail * mix


def save(name, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    fade = min(len(x), int(SR * 0.01))
    x[-fade:] *= np.linspace(1, 0, fade)  # no click at the end
    m = np.max(np.abs(x)) or 1.0
    data = (x / m * peak * 32767).astype(np.int16)
    with wave.open(os.path.join(HERE, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ------------------------------------------------------------------ bells
def bell(f, seconds, partials, strike=0.25):
    """partials: (ratio, amplitude, decay_seconds). Each partial is a pair of
    slightly detuned sines so it beats/wobbles like real cast metal.
    `seconds` must be ~4x the longest decay or the ring gets chopped off."""
    t = t_axis(seconds)
    x = np.zeros_like(t)
    for ratio, amp, decay in partials:
        env = np.exp(-t / decay)
        x += amp * env * (np.sin(2 * np.pi * f * ratio * t)
                          + 0.6 * np.sin(2 * np.pi * f * ratio * 1.0025 * t + 1.3))
    hit = rng.standard_normal(len(t)) * np.exp(-t / 0.015)
    x += strike * bandpass(hit, f * 1.5, min(f * 12, SR / 2 - 100))
    return x


def church_bell():
    # Classic church-bell partial set (hum, prime, tierce, quint, nominal...),
    # low fundamental, lower partials ring longest.
    x = bell(98.0, 14.0, [
        (0.5, 0.8, 4.5), (1.0, 1.0, 3.6), (1.19, 0.55, 2.6), (1.5, 0.35, 2.0),
        (2.0, 0.6, 1.8), (2.52, 0.25, 1.2), (3.0, 0.22, 0.9), (4.07, 0.15, 0.6),
        (5.32, 0.1, 0.4),
    ], strike=0.4)
    return reverb(x, 3.0, 0.3, 2500)


def small_bell(far=False):
    x = bell(1318.5, 6.0, [
        (1.0, 1.0, 1.4), (2.01, 0.45, 0.8), (2.76, 0.3, 0.55), (5.40, 0.18, 0.3),
        (8.93, 0.08, 0.15),
    ], strike=0.15)
    if far:
        x = lowpass(x, 2600) * 0.5
        return reverb(x, 4.0, 0.65, 3000)
    return reverb(x, 4.0, 0.45, 6000)  # long ringing tail in the dark


# ------------------------------------------------------------------ rubber
def rubber_stretch():
    # Stick-slip squeak: a pulse wave gliding up then sagging, chopped by an
    # irregular grain rate so it reads as rubber dragging, plus a low gooey body.
    secs = 1.8
    t = t_axis(secs)
    phase = glide(120, 360, secs, 0.7) + 0.4 * np.sin(2 * np.pi * 7 * t)
    pulse = np.sign(np.sin(phase)) * 0.6 + np.sin(phase * 2) * 0.3
    grains = (np.sin(2 * np.pi * np.cumsum(38 + 25 * rng.random(len(t))) / SR) > 0.2).astype(float)
    grains = lowpass(grains, 300)
    squeak = bandpass(pulse * (0.35 + grains), 300, 2200)
    body = np.sin(glide(70, 55, secs)) * 0.5
    env = np.minimum(t / 0.25, 1) * np.exp(-np.maximum(t - 1.2, 0) / 0.25)
    return (squeak + body) * env


def wet_grab():
    t = t_axis(0.3)
    n = lowpass(rng.standard_normal(len(t)), 1600) * np.exp(-t / 0.04)
    thump = np.sin(2 * np.pi * 110 * t) * np.exp(-t / 0.06)
    smack = bandpass(rng.standard_normal(len(t)), 2000, 6000) * np.exp(-t / 0.008)
    return n * 1.2 + thump * 0.8 + smack * 0.5


def tear(seconds, centre, loudness, groan):
    """Ripping: a dense crackle of tiny impulses whose rate speeds up, through a
    band around `centre`, ending abruptly ("좌-악!"), plus a falling rubbery
    groan for the bigger steps."""
    t = t_axis(seconds)
    rate = np.linspace(80, 900, len(t))  # impulses per second, accelerating
    clicks = (rng.random(len(t)) < rate / SR).astype(float) * rng.choice([-1, 1], len(t))
    clicks += 0.15 * rng.standard_normal(len(t))
    rip = bandpass(clicks, centre * 0.5, min(centre * 2.5, SR / 2 - 100), order=3)
    env = np.minimum(t / (seconds * 0.6), 1) ** 1.5
    env *= np.where(t > seconds - 0.04, np.linspace(1, 0, len(t)), 1)  # hard stop
    x = rip * env * 3.0
    if groan:
        g = np.sign(np.sin(glide(240, 90, seconds, 0.8))) * 0.4
        x += bandpass(g, 120, 1200) * env * groan
    return x * loudness


# ------------------------------------------------------------------ eating
def low_drone():
    secs = 3.2
    t = t_axis(secs)
    x = (np.sin(glide(42, 58, secs)) + 0.6 * np.sin(glide(42.6, 58.9, secs))
         + 0.3 * np.sin(glide(84, 116, secs)))
    saw = lowpass(((t * 63) % 1.0) * 2 - 1, 180) * 0.4
    env = (t / secs) ** 1.6
    return (x + saw) * env


def whoosh():
    secs = 0.8
    t = t_axis(secs)
    n = rng.standard_normal(len(t))
    lo = bandpass(n, 300, 900)
    mid = bandpass(n, 900, 2400)
    hi = bandpass(n, 2400, 6000)
    k = t / secs  # crossfade upward through the bands
    out = lo * np.clip(1 - 2 * k, 0, 1) + mid * (1 - np.abs(2 * k - 1)) + hi * np.clip(2 * k - 1, 0, 1)
    env = np.sin(np.pi * np.minimum(k, 1)) ** 0.7
    return out * env


def gulp():
    # "꿀" -- wet bubble gliding up; "꺽" -- low throat thump right after.
    a = t_axis(0.22)
    gul = np.sin(glide(140, 320, 0.22, 0.6)) * np.sin(np.pi * a / 0.22)
    gul += 0.3 * lowpass(rng.standard_normal(len(a)), 900) * np.sin(np.pi * a / 0.22)
    b = t_axis(0.3)
    kkeok = np.sin(glide(150, 55, 0.3, 0.5)) * np.exp(-b / 0.07)
    kkeok += 0.6 * bandpass(rng.standard_normal(len(b)), 300, 1500) * np.exp(-b / 0.02)
    return np.concatenate([gul * 0.8, np.zeros(int(SR * 0.03)), kkeok * 1.2])


# ------------------------------------------------------------------ stars
def star_burst():
    """"쨔라라라랑~": bright hit ("쨔"), a fast ascending pentatonic run of
    little bell pings ("라라라라"), then a shimmering high chord that rings out
    with a tremolo ("랑~")."""
    secs = 4.0
    x = np.zeros(int(SR * secs))

    def add(sig, at):
        s0 = int(SR * at)
        n = min(len(sig), len(x) - s0)
        x[s0:s0 + n] += sig[:n]

    # 쨔
    hit = t_axis(0.25)
    zza = highpass(rng.standard_normal(len(hit)), 4000) * np.exp(-hit / 0.03) * 0.5
    for f in (2093.0, 2637.0, 3136.0):
        zza += np.sin(2 * np.pi * f * hit) * np.exp(-hit / 0.08) * 0.35
    add(zza, 0.0)
    # 라라라라 -- C major pentatonic, two octaves up from C6
    scale = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0]
    run = [f * (2 ** octave) for octave in (0, 1) for f in scale] + [4186.0]
    for i, f in enumerate(run):
        ping = bell(f, 0.9, [(1.0, 1.0, 0.35), (2.76, 0.25, 0.12), (5.40, 0.1, 0.06)], strike=0.05)
        add(ping * (0.35 + 0.03 * i), 0.06 + i * 0.055)
    # 랑~
    ring_at = 0.06 + len(run) * 0.055
    ring_t = t_axis(secs - ring_at)
    trem = 1.0 + 0.25 * np.sin(2 * np.pi * 6.0 * ring_t)
    ring = np.zeros_like(ring_t)
    for f, amp in ((2093.0, 1.0), (2637.0, 0.7), (3136.0, 0.6), (4186.0, 0.35), (1046.5, 0.5)):
        ring += amp * bell(f, secs - ring_at, [(1.0, 1.0, 1.1), (2.76, 0.2, 0.3)], strike=0.0)[:len(ring_t)]
    add(ring * trem * 0.3, ring_at)
    sparkle = highpass(rng.standard_normal(len(x)), 6000) * np.exp(-t_axis(secs) / 0.9) * 0.06
    return reverb(x + sparkle, 2.0, 0.3, 8000)


def main():
    save("church_bell", church_bell())
    save("rubber_stretch", rubber_stretch(), 0.7)
    save("wet_grab", wet_grab(), 0.6)
    save("tear_1", tear(0.35, 2200, 0.5, 0.0), 0.45)  # "약간"
    save("tear_2", tear(0.6, 1700, 0.8, 0.5), 0.7)  # "좌악."
    save("tear_3", tear(1.1, 1300, 1.0, 0.9), 0.95)  # "좌아악!"
    save("low_drone", low_drone(), 0.8)
    save("whoosh", whoosh(), 0.8)
    save("gulp", gulp(), 0.9)
    save("small_bell", small_bell(), 0.75)
    save("small_bell_far", small_bell(far=True), 0.45)
    save("star_burst", star_burst(), 0.85)
    print("sfx written to", HERE)


if __name__ == "__main__":
    main()
