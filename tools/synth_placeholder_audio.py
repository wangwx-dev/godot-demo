# 占位音效/BGM 批量合成（stdlib only，M2 三个占位 wav 的同源做法扩全表）。
# 运行：python tools/synth_placeholder_audio.py
# 产物：assets/audio/sfx/*.wav + assets/audio/music/*.wav（44.1kHz 16bit 单声道）
# 定位：asset-list §7 全部非 ⏸ 行推到 🟨（正式音频后续整包替换）。
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
ROOT = Path(__file__).resolve().parent.parent / "assets" / "audio"
random.seed(20260718)


def write_wav(rel: str, samples: list) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.86 / peak if peak > 0.86 else 1.0
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767))
            for s in samples))
    print(f"[synth] {rel}  {len(samples)/SR:.2f}s")


def silence(dur):
    return [0.0] * int(SR * dur)


def mix(*tracks):
    out = [0.0] * max(len(t) for t in tracks)
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def tone(freq, dur, vol=0.5, decay=6.0, wave_fn=math.sin, sweep=1.0):
    """衰减单音；sweep=结束频率/起始频率（滑音）。"""
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = freq * (sweep ** t)
        phase += 2 * math.pi * f / SR
        out.append(wave_fn(phase) * vol * math.exp(-decay * t))
    return out


def saw(p):
    return 2.0 * ((p / (2 * math.pi)) % 1.0) - 1.0


def square(p):
    return 1.0 if (p / (2 * math.pi)) % 1.0 < 0.5 else -1.0


def noise(dur, vol=0.5, decay=8.0, lowpass=0.0):
    n = int(SR * dur)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / n
        s = random.uniform(-1, 1)
        if lowpass > 0.0:
            s = prev + lowpass * (s - prev)
            prev = s
        out.append(s * vol * math.exp(-decay * t))
    return out


def chirp_seq(freqs, note_dur, vol=0.4, decay=9.0, wave_fn=math.sin):
    out = []
    for f in freqs:
        out += tone(f, note_dur, vol, decay, wave_fn)
    return out


# ---------------- SFX ----------------
# 武器
write_wav("sfx/bat_swing.wav", mix(noise(0.13, 0.5, 14.0, 0.25), tone(120, 0.13, 0.35, 18)))
write_wav("sfx/pistol_shot.wav", mix(noise(0.09, 0.7, 26.0), tone(220, 0.06, 0.4, 30, square)))
write_wav("sfx/molotov_ignite.wav", mix(
    noise(0.45, 0.55, 5.0, 0.12),
    tone(90, 0.45, 0.3, 4.0, math.sin, 0.6)))
# 命中/击杀
write_wav("sfx/hit_flesh.wav", mix(noise(0.07, 0.4, 22.0, 0.4), tone(170, 0.07, 0.4, 26)))
write_wav("sfx/kill_dissolve.wav", tone(520, 0.22, 0.32, 9.0, math.sin, 0.35))
# 玩家
write_wav("sfx/player_hurt.wav", mix(tone(300, 0.18, 0.5, 10.0, square, 0.55), noise(0.1, 0.2, 18)))
write_wav("sfx/dodge_roll.wav", noise(0.16, 0.4, 9.0, 0.6))
# 升级/UI
write_wav("sfx/level_up.wav", chirp_seq([392, 523, 659, 784], 0.09, 0.4, 7.0))
write_wav("sfx/ui_confirm.wav", chirp_seq([660, 880], 0.06, 0.35, 10.0))
# 拾取/开箱
write_wav("sfx/pickup_coin.wav", chirp_seq([988, 1319], 0.045, 0.3, 12.0))
write_wav("sfx/pickup_xp.wav", tone(740, 0.06, 0.22, 14.0, math.sin, 1.3))
write_wav("sfx/chest_loop.wav", mix(tone(440, 0.09, 0.18, 10.0), tone(587, 0.09, 0.1, 10.0)))
write_wav("sfx/chest_open.wav", mix(noise(0.1, 0.3, 16, 0.3), chirp_seq([523, 784], 0.1, 0.35, 8.0)))
# 臃肿者
write_wav("sfx/bloater_warning.wav", tone(140, 0.9, 0.45, 1.6, saw, 2.2))
write_wav("sfx/bloater_explode.wav", mix(noise(0.5, 0.8, 7.0, 0.18), tone(60, 0.5, 0.5, 6.0)))
# 精英
write_wav("sfx/elite_spawn.wav", mix(tone(98, 0.7, 0.5, 3.0, saw), tone(147, 0.7, 0.3, 3.0, saw)))
write_wav("sfx/elite_down.wav", mix(tone(392, 0.5, 0.4, 5.0, math.sin, 0.4), noise(0.3, 0.3, 8, 0.2)))
# 载具
write_wav("sfx/vehicle_found.wav", chirp_seq([784, 784], 0.08, 0.3, 12.0))
write_wav("sfx/vehicle_depart.wav", tone(70, 0.85, 0.55, 1.2, saw, 3.0))
# 商店
write_wav("sfx/shop_exchange_tick.wav", chirp_seq([1047, 1568], 0.05, 0.3, 12.0))


# ---------------- BGM（短循环占位：氛围底 + 微律动） ----------------
def bgm_loop(rel, chord, bpm, dur, vol=0.16, dark=True):
    n = int(SR * dur)
    out = [0.0] * n
    for freq in chord:
        phase = 0.0
        for i in range(n):
            lfo = 1.0 + 0.004 * math.sin(2 * math.pi * 0.25 * i / SR)
            phase += 2 * math.pi * freq * lfo / SR
            w = saw(phase) if dark else math.sin(phase)
            out[i] += w * vol / len(chord)
    # 律动：每拍一个低频脉冲
    beat = int(SR * 60.0 / bpm)
    for start in range(0, n, beat):
        for i in range(min(int(SR * 0.1), n - start)):
            t = i / (SR * 0.1)
            out[start + i] += math.sin(2 * math.pi * 55 * i / SR) * 0.22 * math.exp(-5 * t)
    # 循环缝合：首尾 0.05s 交叉淡化
    fade = int(SR * 0.05)
    for i in range(fade):
        k = i / fade
        out[i] = out[i] * k + out[n - fade + i] * (1 - k)
    write_wav(rel, out)


bgm_loop("music/bgm_battle.wav", [55.0, 82.4, 110.0], 92, 8.0, 0.15, True)       # 阴沉小调走注
bgm_loop("music/bgm_safe.wav", [130.8, 164.8, 196.0], 60, 8.0, 0.12, False)      # 温和大三和弦
bgm_loop("music/bgm_assault.wav", [49.0, 73.4, 98.0], 132, 6.0, 0.18, True)      # 更低更快的压迫
print("[synth] 全部完成")
