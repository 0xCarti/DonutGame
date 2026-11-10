"""Generate original, quiet marimba-like mini-game feedback (CC0 project assets)."""
import math
from pathlib import Path
import struct
import wave

DEST = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 44100


def cue(name, notes, duration):
    samples = []
    for frame in range(int(duration * RATE)):
        t = frame / RATE
        sample = 0.0
        for delay, hz, gain in notes:
            local = t - delay
            if local < 0:
                continue
            envelope = min(local / 0.006, 1.0) * math.exp(-local * 10)
            tone = math.sin(local * hz * math.tau)
            tone += 0.22 * math.sin(local * hz * 2.01 * math.tau)
            tone += 0.09 * math.sin(local * hz * 3.99 * math.tau)
            sample += tone * envelope * gain
        samples.append(struct.pack("<h", round(max(-1, min(1, sample * 0.26)) * 32767)))
    with wave.open(str(DEST / f"batch_{name}.wav"), "wb") as output:
        output.setparams((1, 2, RATE, len(samples), "NONE", "not compressed"))
        output.writeframes(b"".join(samples))


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    cue("good", [(0, 523.25, 0.9), (0.07, 659.25, 0.7)], 0.36)
    cue("perfect", [(0, 659.25, 0.7), (0.07, 783.99, 0.7), (0.14, 1046.50, 0.7)], 0.52)
    cue("finish", [(0, 523.25, 0.7), (0.10, 659.25, 0.65), (0.20, 783.99, 0.7), (0.31, 1046.50, 0.7), (0.31, 523.25, 0.25)], 0.95)
    print("Generated three original batch feedback cues.")
