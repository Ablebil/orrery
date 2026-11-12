import argparse
import sys
from pathlib import Path

import numpy as np
import soundfile

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SAMPLE_RATE = 44100
WRITE_BLOCK = 4096
SEED = 20261109

MUSIC_NAME = "space_ambient"
MUSIC_CHORD_SECONDS = 12.0
MUSIC_CHORD_OVERLAP = 6.0
MUSIC_TARGET_LUFS = -16.0
MUSIC_PEAK_DBFS = -1.0
MUSIC_QUALITY = 0.3
EFFECT_PEAK_DBFS = -3.0
EFFECT_QUALITY = 0.5

CHORDS = [
    [50, 57, 61, 64, 66],
    [47, 54, 57, 61, 62],
    [43, 50, 54, 59, 61],
    [45, 52, 57, 59, 64],
    [50, 57, 64, 66, 69],
    [42, 54, 57, 61, 64],
    [43, 50, 57, 59, 66],
    [40, 52, 55, 59, 62],
]
BELL_NOTES = [74, 76, 78, 81, 83, 86, 88]
DRONE_NOTE = 38


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate the background music and sound effects.")
    parser.add_argument("--output", type=Path, default=REPOSITORY_ROOT / "godot/assets/audio")
    return parser.parse_args()


def note_frequency(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def decibels_to_gain(decibels: float) -> float:
    return 10.0 ** (decibels / 20.0)


def periodic_frequency(frequency: float, period: float) -> float:
    return max(1.0, round(frequency * period)) / period


def apply_spectrum(signal: np.ndarray, response) -> np.ndarray:
    spectrum = np.fft.rfft(signal, axis=0)
    frequencies = np.fft.rfftfreq(signal.shape[0], 1.0 / SAMPLE_RATE)
    gain = response(frequencies)
    if signal.ndim > 1:
        gain = gain[:, None]
    return np.fft.irfft(spectrum * gain, n=signal.shape[0], axis=0)


def lowpass(cutoff: float, order: int = 2):
    return lambda frequencies: 1.0 / np.sqrt(1.0 + (frequencies / cutoff) ** (2 * order))


def highpass(cutoff: float, order: int = 2):
    return lambda frequencies: 1.0 / np.sqrt(1.0 + (cutoff / np.maximum(frequencies, 1e-6)) ** (2 * order))


def biquad_magnitude(b: tuple[float, float, float], a: tuple[float, float, float], frequencies: np.ndarray) -> np.ndarray:
    z = np.exp(-2j * np.pi * frequencies / SAMPLE_RATE)
    numerator = b[0] + b[1] * z + b[2] * z * z
    denominator = a[0] + a[1] * z + a[2] * z * z
    return np.abs(numerator / denominator)


def k_weighting(frequencies: np.ndarray) -> np.ndarray:
    shelf_gain = 10.0 ** (3.99984385397 / 40.0)
    omega = 2.0 * np.pi * 1681.9744509555319 / SAMPLE_RATE
    alpha = np.sin(omega) / (2.0 * 0.7071752369554193)
    root = np.sqrt(shelf_gain)
    shelf = biquad_magnitude(
        (
            shelf_gain * ((shelf_gain + 1) + (shelf_gain - 1) * np.cos(omega) + 2 * root * alpha),
            -2 * shelf_gain * ((shelf_gain - 1) + (shelf_gain + 1) * np.cos(omega)),
            shelf_gain * ((shelf_gain + 1) + (shelf_gain - 1) * np.cos(omega) - 2 * root * alpha),
        ),
        (
            (shelf_gain + 1) - (shelf_gain - 1) * np.cos(omega) + 2 * root * alpha,
            2 * ((shelf_gain - 1) - (shelf_gain + 1) * np.cos(omega)),
            (shelf_gain + 1) - (shelf_gain - 1) * np.cos(omega) - 2 * root * alpha,
        ),
        frequencies,
    )
    omega = 2.0 * np.pi * 38.13547087613982 / SAMPLE_RATE
    alpha = np.sin(omega) / (2.0 * 0.5003270373253953)
    high = biquad_magnitude(
        ((1 + np.cos(omega)) / 2, -(1 + np.cos(omega)), (1 + np.cos(omega)) / 2),
        (1 + alpha, -2 * np.cos(omega), 1 - alpha),
        frequencies,
    )
    return shelf * high


def integrated_loudness(signal: np.ndarray) -> float:
    weighted = apply_spectrum(signal, k_weighting)
    block = int(0.4 * SAMPLE_RATE)
    hop = int(0.1 * SAMPLE_RATE)
    powers = []
    for start in range(0, weighted.shape[0] - block + 1, hop):
        powers.append(np.sum(np.mean(weighted[start : start + block] ** 2, axis=0)))
    powers = np.array(powers)
    loudness = -0.691 + 10.0 * np.log10(np.maximum(powers, 1e-12))
    gated = powers[loudness > -70.0]
    relative = -0.691 + 10.0 * np.log10(np.mean(gated)) - 10.0
    gated = powers[(loudness > -70.0) & (loudness > relative)]
    return float(-0.691 + 10.0 * np.log10(np.mean(gated)))


def add_wrapped(buffer: np.ndarray, start: int, signal: np.ndarray) -> None:
    indices = (start + np.arange(signal.shape[0])) % buffer.shape[0]
    buffer[indices] += signal


def raised_window(length: int, fade: int) -> np.ndarray:
    window = np.ones(length)
    ramp = np.sin(0.5 * np.pi * np.arange(fade) / fade)
    window[:fade] = ramp
    window[-fade:] = ramp[::-1]
    return window


def render_pad_chord(notes: list[int], length: int, start: int, period: float, rng: np.random.Generator) -> np.ndarray:
    local = np.arange(length) / SAMPLE_RATE
    absolute = ((start + np.arange(length)) % int(period * SAMPLE_RATE)) / SAMPLE_RATE
    brightness = 1.1 + 0.45 * np.sin(2.0 * np.pi * 2.0 * absolute / period + 0.7)
    chord = np.zeros((length, 2))
    for index, note in enumerate(notes):
        level = 0.75 if index == 0 else 0.55
        swell = 0.75 + 0.25 * np.sin(2.0 * np.pi * rng.uniform(0.03, 0.09) * local + rng.uniform(0, 2 * np.pi))
        for channel in range(2):
            for detune in rng.uniform(-11.0, 11.0, size=3):
                frequency = note_frequency(note + detune / 100.0)
                phase = 2.0 * np.pi * frequency * local + rng.uniform(0, 2 * np.pi)
                voice = np.zeros(length)
                for harmonic in range(1, 6):
                    if frequency * harmonic > 6000.0:
                        break
                    voice += np.sin(harmonic * phase) * np.exp(-(harmonic - 1) * brightness) / harmonic
                chord[:, channel] += level * swell * voice
    return chord


def render_shimmer(notes: list[int], length: int, rng: np.random.Generator) -> np.ndarray:
    local = np.arange(length) / SAMPLE_RATE
    shimmer = np.zeros((length, 2))
    for note in rng.choice(notes[1:], size=3, replace=False):
        frequency = note_frequency(note + 24 + rng.uniform(-0.04, 0.04))
        tremolo = np.sin(2.0 * np.pi * rng.uniform(0.08, 0.22) * local + rng.uniform(0, 2 * np.pi)) ** 2
        tone = np.sin(2.0 * np.pi * frequency * local + rng.uniform(0, 2 * np.pi)) * tremolo
        pan = rng.uniform(0.2, 0.8)
        shimmer[:, 0] += tone * np.sqrt(1.0 - pan)
        shimmer[:, 1] += tone * np.sqrt(pan)
    return shimmer


def render_bell(note: int, rng: np.random.Generator) -> np.ndarray:
    length = int(6.0 * SAMPLE_RATE)
    time = np.arange(length) / SAMPLE_RATE
    carrier = note_frequency(note)
    index = 2.2 * np.exp(-time / 0.6)
    modulator = np.sin(2.0 * np.pi * carrier * 1.4 * time)
    attack = np.minimum(1.0, time / 0.004)
    tone = np.sin(2.0 * np.pi * carrier * time + index * modulator) * attack * np.exp(-time / 1.4)
    pan = rng.uniform(0.15, 0.85)
    return np.stack([tone * np.sqrt(1.0 - pan), tone * np.sqrt(pan)], axis=1)


def reverb_impulse(seconds: float, rng: np.random.Generator) -> np.ndarray:
    length = int(seconds * SAMPLE_RATE)
    time = np.arange(length) / SAMPLE_RATE
    noise = rng.standard_normal((length, 2)) * np.exp(-6.9 * time / seconds)[:, None]
    noise = apply_spectrum(noise, lowpass(4500.0, 1))
    noise[: int(0.02 * SAMPLE_RATE)] *= np.linspace(0.0, 1.0, int(0.02 * SAMPLE_RATE))[:, None]
    return noise / np.sqrt(np.sum(noise**2, axis=0))


def circular_convolve(signal: np.ndarray, impulse: np.ndarray) -> np.ndarray:
    padded = np.zeros_like(signal)
    padded[: impulse.shape[0]] = impulse
    spectrum = np.fft.rfft(signal, axis=0) * np.fft.rfft(padded, axis=0)
    return np.fft.irfft(spectrum, n=signal.shape[0], axis=0)


def generate_music() -> np.ndarray:
    rng = np.random.default_rng(SEED)
    period = MUSIC_CHORD_SECONDS * len(CHORDS)
    total = int(period * SAMPLE_RATE)
    time = np.arange(total) / SAMPLE_RATE
    pad = np.zeros((total, 2))
    shimmer = np.zeros((total, 2))
    fade = int(MUSIC_CHORD_OVERLAP * SAMPLE_RATE)
    for index, notes in enumerate(CHORDS):
        chord_rng = np.random.default_rng(SEED + index)
        start = int((index * MUSIC_CHORD_SECONDS - MUSIC_CHORD_OVERLAP / 2) * SAMPLE_RATE)
        length = int((MUSIC_CHORD_SECONDS + MUSIC_CHORD_OVERLAP) * SAMPLE_RATE)
        window = raised_window(length, fade)[:, None]
        add_wrapped(pad, start, render_pad_chord(notes, length, start, period, chord_rng) * window)
        add_wrapped(shimmer, start, render_shimmer(notes, length, chord_rng) * window)
    pad = apply_spectrum(pad, lowpass(2200.0, 2))
    drone = np.zeros((total, 2))
    for octave, level in ((0, 1.0), (-12, 0.6)):
        for channel, detune in enumerate((-0.03, 0.03)):
            frequency = periodic_frequency(note_frequency(DRONE_NOTE + octave + detune), period)
            breathing = 0.8 + 0.2 * np.sin(2.0 * np.pi * 3.0 * time / period + channel)
            drone[:, channel] += level * breathing * np.sin(2.0 * np.pi * frequency * time)
    bells = np.zeros((total, 2))
    moment = rng.uniform(1.0, 4.0)
    while moment < period:
        add_wrapped(bells, int(moment * SAMPLE_RATE), render_bell(int(rng.choice(BELL_NOTES)), rng))
        moment += rng.uniform(5.0, 11.0)
    pad /= np.max(np.abs(pad))
    shimmer /= np.max(np.abs(shimmer))
    drone /= np.max(np.abs(drone))
    bells /= np.max(np.abs(bells))
    dry = 0.62 * pad + 0.32 * drone + 0.05 * shimmer + 0.12 * bells
    send = 0.45 * pad + 0.18 * shimmer + 0.4 * bells
    wet = circular_convolve(send, reverb_impulse(4.5, rng))
    wet *= np.sqrt(np.mean(dry**2) / np.mean(wet**2)) * 0.7
    mix = apply_spectrum(dry + wet, highpass(28.0, 2))
    mix *= decibels_to_gain(MUSIC_TARGET_LUFS - integrated_loudness(mix))
    peak_limit = decibels_to_gain(MUSIC_PEAK_DBFS)
    peak = np.max(np.abs(mix))
    if peak > peak_limit:
        mix *= peak_limit / peak
    return mix


def svf_bandpass(signal: np.ndarray, centers: np.ndarray, resonance: float) -> np.ndarray:
    low = 0.0
    band = 0.0
    output = np.zeros_like(signal)
    damping = 1.0 / resonance
    for index, sample in enumerate(signal):
        tuning = 2.0 * np.sin(np.pi * min(centers[index], SAMPLE_RATE / 6.0) / SAMPLE_RATE)
        low += tuning * band
        high = sample - low - damping * band
        band += tuning * high
        output[index] = band
    return output


def glide(start: float, end: float, seconds: float, time: np.ndarray) -> np.ndarray:
    progress = np.clip(time / seconds, 0.0, 1.0)
    return start * (end / start) ** progress


def oscillator(frequencies: np.ndarray) -> np.ndarray:
    return 2.0 * np.pi * np.cumsum(frequencies) / SAMPLE_RATE


def finish_effect(signal: np.ndarray) -> np.ndarray:
    signal = signal - np.mean(signal)
    tail = int(0.005 * SAMPLE_RATE)
    signal[-tail:] *= np.linspace(1.0, 0.0, tail)
    return signal * decibels_to_gain(EFFECT_PEAK_DBFS) / np.max(np.abs(signal))


def effect_time(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SAMPLE_RATE)) / SAMPLE_RATE


def generate_click(rng: np.random.Generator) -> np.ndarray:
    time = effect_time(0.04)
    attack = np.minimum(1.0, time / 0.0008)
    body = 0.6 * np.sin(2.0 * np.pi * 2300.0 * time) * np.exp(-time / 0.006)
    body += 0.4 * np.sin(2.0 * np.pi * 1150.0 * time) * np.exp(-time / 0.011)
    noise = apply_spectrum(rng.standard_normal(time.size), lowpass(5000.0, 2)) * np.exp(-time / 0.0015) * 0.25
    return finish_effect((body + noise) * attack)


def generate_place(rng: np.random.Generator) -> np.ndarray:
    time = effect_time(0.24)
    phase = oscillator(glide(523.25, 783.99, 0.11, time))
    envelope = np.minimum(1.0, time / 0.005) * np.exp(-time / 0.07)
    tone = np.sin(phase) + 0.25 * np.sin(2.0 * phase) + 0.08 * np.sin(3.0 * phase)
    return finish_effect(tone * envelope)


def generate_launch(rng: np.random.Generator) -> np.ndarray:
    time = effect_time(0.6)
    rise = np.clip(time / 0.18, 0.0, 1.0) ** 1.5
    fall = np.clip((0.6 - time) / 0.42, 0.0, 1.0) ** 2
    envelope = np.minimum(rise, fall)
    noise = svf_bandpass(rng.standard_normal(time.size), glide(320.0, 3200.0, 0.5, time), 2.2)
    noise /= np.max(np.abs(noise))
    sweep = np.sin(oscillator(glide(170.0, 760.0, 0.5, time)))
    return finish_effect((0.75 * noise + 0.35 * sweep) * envelope)


def generate_merge(rng: np.random.Generator) -> np.ndarray:
    time = effect_time(0.85)
    attack = np.minimum(1.0, time / 0.003)
    thump = np.sin(oscillator(44.0 + 80.0 * np.exp(-time / 0.05))) * np.exp(-time / 0.22)
    noise = svf_bandpass(rng.standard_normal(time.size), 180.0 + 1800.0 * np.exp(-time / 0.08), 0.9)
    noise = noise / np.max(np.abs(noise)) * np.exp(-time / 0.14)
    rumble = apply_spectrum(rng.standard_normal(time.size), lowpass(140.0, 2))
    rumble = rumble / np.max(np.abs(rumble)) * np.exp(-time / 0.3)
    return finish_effect((thump + 0.45 * noise + 0.3 * rumble) * attack)


def generate_remove(rng: np.random.Generator) -> np.ndarray:
    time = effect_time(0.26)
    phase = oscillator(glide(880.0, 290.0, 0.18, time))
    envelope = np.minimum(1.0, time / 0.002) * np.exp(-time / 0.075)
    tone = np.sin(phase) + 0.22 * np.sin(2.0 * phase)
    pop = apply_spectrum(rng.standard_normal(time.size), highpass(1500.0, 2)) * np.exp(-time / 0.002) * 0.6
    return finish_effect(tone * envelope + pop)


EFFECTS = {
    "click": generate_click,
    "place": generate_place,
    "launch": generate_launch,
    "merge": generate_merge,
    "remove": generate_remove,
}


def write_ogg(path: Path, samples: np.ndarray, quality: float) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    channels = 1 if samples.ndim == 1 else samples.shape[1]
    with soundfile.SoundFile(path, "w", SAMPLE_RATE, channels, subtype="VORBIS", format="OGG", compression_level=1.0 - quality) as output:
        for start in range(0, samples.shape[0], WRITE_BLOCK):
            output.write(samples[start : start + WRITE_BLOCK].astype(np.float32))
    peak = 20.0 * np.log10(np.max(np.abs(samples)))
    print(f"Generated {path.name} ({samples.shape[0] / SAMPLE_RATE:.2f}s, peak {peak:.1f} dBFS)")


def main() -> int:
    arguments = parse_arguments()
    music = generate_music()
    print(f"Music loudness {integrated_loudness(music):.1f} LUFS")
    write_ogg(arguments.output / "music" / f"{MUSIC_NAME}.ogg", music, MUSIC_QUALITY)
    for index, (name, generator) in enumerate(EFFECTS.items()):
        write_ogg(arguments.output / "effects" / f"{name}.ogg", generator(np.random.default_rng(SEED + 100 + index)), EFFECT_QUALITY)
    return 0


if __name__ == "__main__":
    sys.exit(main())
