# يولّد أيقونات التطبيق وأصواته بدون أي مكتبات خارجية.
# التشغيل: python3 tool/make_assets.py
import math, os, struct, wave, zlib

os.makedirs('assets/icon', exist_ok=True)
os.makedirs('assets/sounds', exist_ok=True)

# ---------------- PNG ----------------
def write_png(path, w, h, pixels):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw.extend(pixels[y * w * 4:(y + 1) * w * 4])
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(png)

def smooth(edge, d, aa=1.2):
    v = (edge - d) / aa + 0.5
    return 0.0 if v <= 0 else 1.0 if v >= 1 else v

def over(dst, src, a):
    return [dst[i] * (1 - a) + src[i] * a for i in range(3)], dst[3] + (1 - dst[3]) * a

def render(S, scale=1.0, background=True):
    c = S / 2
    R = S * 0.30 * scale
    rr = R * 1.18
    br = S * 0.013 * scale
    n = 33
    px = bytearray(S * S * 4)
    for y in range(S):
        for x in range(S):
            dx, dy = x - c + 0.5, y - c + 0.5
            d = math.hypot(dx, dy)
            if background:
                t = min(d / (S * 0.72), 1)
                col, a = [10 * (1 - t) + 3 * t, 52 * (1 - t) + 18 * t, 40 * (1 - t) + 14 * t], 1.0
            else:
                col, a = [0, 0, 0], 0.0
            # توهّج
            g = max(0.0, 1 - max(0.0, d - R) / (R * 0.5)) * 0.55 if d > R * 0.9 else 0
            if g > 0:
                col, a = over(col + [a], [16, 185, 129], g)
            # الدائرة الخارجية والداخلية
            k = smooth(R, d)
            if k > 0:
                col, a = over(col + [a], [16, 160, 112], k)
            k = smooth(R * 0.86, d)
            if k > 0:
                col, a = over(col + [a], [8, 95, 68], k)
            k = smooth(R * 0.22, d)
            if k > 0:
                col, a = over(col + [a], [232, 196, 110], k)
            # حبات السبحة
            if abs(d - rr) < br + 2:
                ang = math.atan2(dy, dx) + math.pi / 2
                i = round(ang / (2 * math.pi / n))
                ba = i * 2 * math.pi / n - math.pi / 2
                bd = math.hypot(dx - rr * math.cos(ba), dy - rr * math.sin(ba))
                k = smooth(br, bd)
                if k > 0:
                    col, a = over(col + [a], [232, 196, 110], k)
            o = (y * S + x) * 4
            px[o:o + 4] = bytes([int(min(255, max(0, v))) for v in col] + [int(a * 255)])
    return px

S = 512
write_png('assets/icon/icon.png', S, S, render(S))
write_png('assets/icon/foreground.png', S, S, render(S, 0.75, False))
write_png('assets/icon/splash.png', S, S, render(S, 1.0, False))

# أيقونة الإشعار (أبيض على شفاف)
N = 96
px = bytearray(N * N * 4)
for y in range(N):
    for x in range(N):
        d = math.hypot(x - 47.5, y - 47.5)
        a = max(smooth(34, d) - smooth(26, d), smooth(10, d))
        px[(y * N + x) * 4:(y * N + x) * 4 + 4] = bytes([255, 255, 255, int(a * 255)])
write_png('assets/icon/notification.png', N, N, px)

# ---------------- WAV ----------------
SR = 44100
def bell(f, dur, decay):
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        v = (math.sin(2 * math.pi * f * t) + 0.35 * math.sin(2 * math.pi * f * 2.01 * t)
             + 0.12 * math.sin(2 * math.pi * f * 3.02 * t)) * math.exp(-t * decay)
        if t < 0.006:
            v *= t / 0.006
        out.append(v)
    return out

def save(path, sig):
    m = max(abs(v) for v in sig) or 1
    w = wave.open(path, 'wb')
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(b''.join(struct.pack('<h', int(v / m * 0.6 * 32767)) for v in sig))
    w.close()

save('assets/sounds/tap.wav', bell(880, 0.45, 9))
chime = [0.0] * int(SR * 2.2)
for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
    b = bell(f, 1.6, 3.2)
    st = int(SR * 0.16 * i)
    for j, v in enumerate(b):
        if st + j < len(chime):
            chime[st + j] += v
save('assets/sounds/goal.wav', chime)
print('assets ready')
