"""Generate the project's original sound palette using Python's standard library.

Run: python tools/generate_audio.py
No downloaded samples, external instruments, or existing melodies are used.
"""

from array import array
import math
import json
from pathlib import Path
import random
import struct
import wave


RATE = 32000
TAU = math.tau
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RNG = random.Random(54821)
METRICS = {}


def hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def tone(note, seconds, kind="bell", amplitude=1.0):
    frequency = hz(note)
    result = array("f")
    for i in range(round(seconds * RATE)):
        t = i / RATE
        phase = TAU * frequency * t
        attack = min(1.0, t / 0.007)
        release = min(1.0, (seconds - t) / 0.045)
        if kind == "bell":
            value = (math.sin(phase) * math.exp(-t * 5.0)
                     + 0.22 * math.sin(phase * 2.0) * math.exp(-t * 11.0)
                     + 0.055 * math.sin(phase * 4.0) * math.exp(-t * 18.0))
        elif kind == "wood":
            value = (math.sin(phase) + 0.22 * math.sin(phase * 2.76)) * math.exp(-t * 21.0)
        elif kind == "bass":
            value = (math.sin(phase) + 0.13 * math.sin(phase * 2.0)) * math.exp(-t * 3.0)
        else:
            value = (math.sin(phase) + 0.10 * math.sin(phase * 3.0)) * math.exp(-t * 4.0)
        result.append(amplitude * value * attack * release)
    return result


def noise(seconds, amplitude=0.1, decay=16.0):
    result = array("f")
    smooth = 0.0
    for i in range(round(seconds * RATE)):
        t = i / RATE
        smooth = smooth * 0.67 + RNG.uniform(-1.0, 1.0) * 0.33
        result.append(amplitude * smooth * math.exp(-t * decay)
                      * min(1.0, t / 0.002) * min(1.0, (seconds - t) / 0.02))
    return result


def empty(seconds):
    return array("f", [0.0]) * round(seconds * RATE)


def mix(target, source, at=0.0, gain=1.0, wrap=False):
    start = round(at * RATE)
    for i, value in enumerate(source):
        index = start + i
        if wrap:
            index %= len(target)
        elif index >= len(target):
            break
        target[index] += value * gain


def write_wav(name, channels, peak):
    maximum = max(max(abs(v) for v in channel) for channel in channels)
    gain = peak / max(maximum, 0.00001)
    frames = bytearray()
    for frame in zip(*channels):
        for value in frame:
            frames.extend(struct.pack("<h", round(max(-1.0, min(1.0, value * gain)) * 32767)))
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as output:
        output.setnchannels(len(channels))
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(frames)
    rms = math.sqrt(sum(v * v for v in channels[0]) / len(channels[0])) * gain
    METRICS[name] = {"seconds": len(channels[0]) / RATE, "peak": peak, "rms": rms,
                     "channels": len(channels), "sample_rate": RATE}
    print(f"{path.name:20} {len(channels[0])/RATE:5.2f}s  peak={peak:.2f}  rms={rms:.3f}")


def make_sfx():
    drop = empty(0.30)
    mix(drop, tone(48, 0.16, "wood", 0.6))
    mix(drop, tone(64, 0.23, "wood", 0.16), 0.028)
    mix(drop, noise(0.20, 0.45), 0.015)
    write_wav("drop", [drop], 0.62)

    flip = empty(0.24)
    mix(flip, noise(0.11, 0.35, 25.0))
    mix(flip, tone(67, 0.17, "wood", 0.4), 0.055)
    write_wav("flip", [flip], 0.55)

    click = empty(0.12)
    mix(click, tone(76, 0.10, "wood", 0.6))
    mix(click, tone(64, 0.09, "wood", 0.2), 0.01)
    write_wav("click", [click], 0.45)

    sale = empty(0.70)
    for note, at, gain in [(76, 0.00, 0.5), (79, 0.085, 0.45), (84, 0.17, 0.5)]:
        mix(sale, tone(note, 0.49, "bell", gain), at)
    write_wav("sale", [sale], 0.62)

    upgrade = empty(1.10)
    for i, note in enumerate([60, 64, 67, 72, 76]):
        mix(upgrade, tone(note, 0.55, "bell", 0.38), i * 0.105)
    write_wav("upgrade", [upgrade], 0.60)

    failure = empty(1.15)
    for i, note in enumerate([64, 62, 57]):
        mix(failure, tone(note, 0.62, "round", 0.34), i * 0.23)
    write_wav("failure", [failure], 0.55)

    win = empty(1.70)
    for note, at in [(67, 0.0), (72, 0.14), (76, 0.28), (79, 0.47), (84, 0.71)]:
        mix(win, tone(note, 0.88, "bell", 0.32), at)
    for note in [48, 60, 64]:
        mix(win, tone(note, 0.90, "round", 0.15), 0.71)
    write_wav("win", [win], 0.65)


def make_music():
    # Original sixteen-bar, 96 BPM waltz. All tails wrap into the beginning,
    # making a phase-continuous 30-second loop without a restart gap.
    beat = 60.0 / 96.0
    duration = 16 * 3 * beat
    left, right = empty(duration), empty(duration)
    chords = [(48, 60, 64, 67), (43, 59, 62, 67), (45, 60, 64, 69), (41, 60, 65, 69),
              (48, 60, 64, 67), (50, 62, 65, 69), (43, 59, 62, 65), (48, 60, 64, 67)] * 2
    melody = [
        [(0, 76), (1.5, 79), (2, 76)], [(0, 74), (1, 71)],
        [(0.5, 72), (1.5, 76), (2.5, 79)], [(0, 77), (2, 76)],
        [(0, 79), (1, 76), (2.5, 72)], [(0.5, 74), (2, 77)],
        [(0, 74), (1.5, 71)], [(0, 72)],
        [(0, 76), (1.5, 79), (2, 84)], [(0.5, 83), (2, 79)],
        [(0, 81), (1, 76), (2, 72)], [(0.5, 77), (2, 81)],
        [(0, 79), (1.5, 76)], [(0, 77), (1, 74), (2.5, 72)],
        [(0.5, 71), (1.5, 74), (2, 79)], [(0, 76), (1, 72)],
    ]

    def stereo(source, at, gain, pan=0.0):
        mix(left, source, at, gain * math.sqrt((1.0 - pan) / 2.0), True)
        mix(right, source, at, gain * math.sqrt((1.0 + pan) / 2.0), True)

    for bar, chord in enumerate(chords):
        start = bar * 3 * beat
        stereo(tone(chord[0], 1.1, "bass"), start, 0.18, -0.10)
        for offbeat in [1, 2]:
            for note in chord[1:]:
                stereo(tone(note, 0.45, "round"), start + offbeat * beat, 0.034, -0.30)
            stereo(noise(0.12, 0.15, 32.0), start + offbeat * beat, 0.08, 0.3)
        for position, note in melody[bar]:
            at = start + position * beat
            source = tone(note, 1.0, "bell")
            stereo(source, at, 0.13, 0.18)
            stereo(source, at + beat * 0.75, 0.014, -0.35)

    write_wav("fairground_loop", [left, right], 0.48)


def make_score_sfx():
    # Accents are layered by a bounded six-voice runtime mixer. Small sales stay
    # gentle; big sales add harmony and a little motion, not much more loudness.
    small = empty(0.25)
    mix(small, tone(76, 0.23, "bell", 0.35))
    mix(small, tone(60, 0.10, "wood", 0.10))
    write_wav("sale_small", [small], 0.52)
    big = empty(0.92)
    for i, note in enumerate([72, 76, 79, 84]):
        mix(big, tone(note, 0.60, "bell", 0.28), i * 0.075)
    for note in [48, 60, 67]:
        mix(big, tone(note, 0.70, "round", 0.08), 0.15)
    write_wav("sale_big", [big], 0.60)
    jackpot = empty(1.30)
    for i, note in enumerate([67, 72, 76, 79, 84]):
        mix(jackpot, tone(note, 0.65, "bell", 0.28), i * 0.065)
    for note in [48, 60, 64, 67, 72]:
        mix(jackpot, tone(note, 0.80, "round", 0.095), 0.33)
    for note, at in [(84, 0.56), (79, 0.69), (88, 0.82)]:
        mix(jackpot, tone(note, 0.42, "bell", 0.12), at)
    write_wav("sale_jackpot", [jackpot], 0.64)
    coins = empty(0.48)
    for i, (note, gain) in enumerate([(88, 0.28), (79, 0.22), (91, 0.16), (84, 0.10)]):
        mix(coins, tone(note, 0.25, "wood", gain), i * 0.055)
        mix(coins, tone(note + 12, 0.20, "bell", gain * 0.1), i * 0.055)
    write_wav("score_coins", [coins], 0.42)
    # A soft rising sweep with a zero-ended envelope to prevent clicks.
    rise = empty(0.42)
    for i in range(len(rise)):
        t = i / RATE
        fraction = t / 0.42
        phase = TAU * (260.0 * t + 0.5 * (650.0 - 260.0) / 0.42 * t * t)
        envelope = math.sin(math.pi * fraction) ** 2
        rise[i] = envelope * (math.sin(phase) + 0.07 * math.sin(phase * 2.0))
    write_wav("score_rise", [rise], 0.42)
    goal = empty(1.10)
    for note, at in [(67, 0.0), (76, 0.18), (84, 0.36)]:
        mix(goal, tone(note, 0.70, "bell", 0.30), at)
    for note in [48, 60, 64]:
        mix(goal, tone(note, 0.72, "round", 0.09), 0.36)
    write_wav("quota_goal", [goal], 0.60)


def validate_palette():
    # Conservative sum of six effects plus maximum music, independent of phase.
    maximum_effect = max(value["peak"] for name, value in METRICS.items()
                         if name != "fairground_loop")
    worst_mix = 6 * maximum_effect * 10 ** (-15 / 20) + 0.48 * 10 ** (-12 / 20)
    assert worst_mix < 0.85, worst_mix
    for name, metrics in METRICS.items():
        with wave.open(str(OUT / f"{name}.wav"), "rb") as source:
            samples = array("h", source.readframes(source.getnframes()))
        assert 0 < max(abs(value) for value in samples) < 32767, name
        if name == "fairground_loop":
            channels = metrics["channels"]
            assert all(abs(samples[c] - samples[-channels + c]) < 1000 for c in range(channels))
    report = {"assets": METRICS, "runtime_max_sfx_voices": 6,
              "runtime_max_sfx_volume_db": -15.0, "music_max_volume_db": -12.0,
              "worst_case_linear_peak_bound": worst_mix,
              "note": "Conservative sum of six effect peak bounds plus maximum music peak; no limiter required."}
    (OUT / "mix_validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"AUDIO_ASSETS_OK: {len(METRICS)} streams, no clipped PCM; worst mix bound={worst_mix:.3f}")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    make_sfx()
    make_music()
    make_score_sfx()
    validate_palette()
