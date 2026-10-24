# Signed-distance modelling for the AeroSim animals (Blender 4.2, numpy, pyopenvdb).
#
# An animal's body is described as a set of primitives (ellipsoids, round cones, rounded boxes) placed on its skeleton and
# blended with smooth minimum, so muscles flow into each other the way they do under skin. The field is sampled on a voxel
# grid and turned into a watertight surface with OpenVDB (pyopenvdb ships with Blender). This high-resolution surface is the
# "sculpt": it is used to bake normal, colour and roughness onto the game mesh, which is a remesh of the same surface.
#
# Coordinates: Blender world, metres, Z up. Animals face -Y (Blender's front view), so the glTF export has them facing +Z.
# Helper P(lat, fwd, up) converts the more natural (lateral, forward, up) to Blender (x, y, z) = (lat, -fwd, up).
import numpy as np
import math

def P(lat, fwd, up):
    return np.array([lat, -fwd, up], dtype=np.float64)

def norm(v):
    v = np.asarray(v, dtype=np.float64)
    n = np.linalg.norm(v)
    return v / n if n > 1e-12 else v

def frame(fwd, up_hint):
    """An orthonormal basis (columns x, y, z) whose y axis is `fwd` and whose z axis is as close to `up_hint` as possible."""
    y = norm(fwd)
    x = norm(np.cross(y, up_hint))
    z = np.cross(x, y)
    return np.stack([x, y, z], axis=1)

def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])

def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])

def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])

# ------------------------------------------------------------------ noise
def _hash3(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = h & 0x7fffffff
    h = (h ^ (h >> 13)) * 1274126177
    h = h & 0x7fffffff
    return (h & 0xffff).astype(np.float64) / 65535.0

def vnoise(p, freq, seed=0):
    """Value noise in [-1, 1] at points p (N, 3), lattice spacing 1/freq."""
    q = p * freq
    f = np.floor(q)
    t = q - f
    t = t * t * (3 - 2 * t)
    i = f.astype(np.int64)
    out = 0.0
    for dx in (0, 1):
        wx = t[:, 0] if dx else 1 - t[:, 0]
        for dy in (0, 1):
            wy = t[:, 1] if dy else 1 - t[:, 1]
            for dz in (0, 1):
                wz = t[:, 2] if dz else 1 - t[:, 2]
                out = out + wx * wy * wz * _hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out * 2.0 - 1.0

def fbm(p, freq, octaves=4, seed=0, gain=0.5):
    s = 0.0
    a = 1.0
    tot = 0.0
    for o in range(octaves):
        s = s + a * vnoise(p, freq * (2.0 ** o), seed + o * 17)
        tot += a
        a *= gain
    return s / tot

# ------------------------------------------------------------------ primitives (each returns distances for points p (N, 3))
class Prim:
    tag = ""
    def bounds(self):
        raise NotImplementedError
    def dist(self, p):
        raise NotImplementedError

class Ellipsoid(Prim):
    def __init__(self, c, r, R=None, tag=""):
        self.c = np.asarray(c, float); self.r = np.asarray(r, float); self.R = np.eye(3) if R is None else np.asarray(R, float)
        self.tag = tag
    def bounds(self):
        m = np.abs(self.R) @ self.r
        return self.c - m, self.c + m
    def dist(self, p):
        q = (p - self.c) @ self.R          # into the local frame (R's columns are the local axes)
        k0 = np.linalg.norm(q / self.r, axis=1)
        k1 = np.linalg.norm(q / (self.r * self.r), axis=1)
        return np.where(k1 > 1e-9, k0 * (k0 - 1.0) / np.maximum(k1, 1e-9), -self.r.min())

class RoundCone(Prim):
    """Capsule from a (radius ra) to b (radius rb). `flat` squashes the cross-section along `flat_axis` (world vector)
    by that factor (0.7 = 70 per cent as thick that way), for limbs that are narrow side to side."""
    def __init__(self, a, b, ra, rb, tag="", flat=1.0, flat_axis=(1, 0, 0)):
        self.a = np.asarray(a, float); self.b = np.asarray(b, float); self.ra = ra; self.rb = rb; self.tag = tag
        self.flat = flat; self.fax = norm(flat_axis)
    def bounds(self):
        r = max(self.ra, self.rb)
        return np.minimum(self.a, self.b) - r, np.maximum(self.a, self.b) + r
    def dist(self, p):
        if self.flat != 1.0:
            # squash space along the axis about the cone's own axis line
            pa = p - self.a
            along = pa @ self.fax
            p = p + np.outer(along * (1.0 / self.flat - 1.0), self.fax)
            scale = self.flat
        else:
            scale = 1.0
        a, b, r1, r2 = self.a, self.b, self.ra, self.rb
        ba = b - a
        l2 = ba @ ba
        rr = r1 - r2
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        pa = p - a
        y = pa @ ba
        z = y - l2
        v = pa * l2 - np.outer(y, ba)
        x2 = np.einsum("ij,ij->i", v, v)
        y2 = y * y * l2
        z2 = z * z * l2
        k = math.copysign(1.0, rr) * rr * rr * x2
        d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - r1
        d1 = np.sqrt(x2 + z2) * il2 - r2
        d2 = np.sqrt(x2 + y2) * il2 - r1
        d = np.where(np.sign(z) * a2 * z2 > k, d1, np.where(np.sign(y) * a2 * y2 < k, d2, d3))
        return d * scale

class RBox(Prim):
    """Rounded box: centre c, half sizes h (local), rotation R, corner radius rad. `taper` (local y from -h to +h) scales
    the x and z half sizes from (1 + taper) to (1 - taper), making a wedge."""
    def __init__(self, c, h, R=None, rad=0.01, tag="", taper=0.0, taper_z=None):
        self.c = np.asarray(c, float); self.h = np.asarray(h, float); self.R = np.eye(3) if R is None else np.asarray(R, float)
        self.rad = rad; self.tag = tag; self.taper = taper; self.taper_z = taper if taper_z is None else taper_z
    def bounds(self):
        m = np.abs(self.R) @ (self.h * (1 + max(abs(self.taper), abs(self.taper_z))) + self.rad)
        return self.c - m, self.c + m
    def dist(self, p):
        q = (p - self.c) @ self.R
        t = np.clip(q[:, 1] / self.h[1], -1, 1)
        sx = 1.0 - self.taper * t
        sz = 1.0 - self.taper_z * t
        hx = self.h[0] * sx - self.rad
        hz = self.h[2] * sz - self.rad
        dq = np.stack([np.abs(q[:, 0]) - hx, np.abs(q[:, 1]) - (self.h[1] - self.rad), np.abs(q[:, 2]) - hz], axis=1)
        out = np.linalg.norm(np.maximum(dq, 0), axis=1) + np.minimum(dq.max(axis=1), 0)
        return out - self.rad

class Displaced(Prim):
    """A primitive with surface noise: amp * fbm(freq) pushed out (positive amp bulges)."""
    def __init__(self, prim, amp, freq, octaves=3, seed=0, tag=None, fn=None):
        self.p = prim; self.amp = amp; self.freq = freq; self.oct = octaves; self.seed = seed
        self.tag = prim.tag if tag is None else tag
        self.fn = fn
    def bounds(self):
        lo, hi = self.p.bounds()
        return lo - abs(self.amp), hi + abs(self.amp)
    def dist(self, p):
        d = self.p.dist(p)
        lim = abs(self.amp) * 3 + 0.01
        near = np.abs(d) < lim
        if near.any():
            pn = p[near]
            n = self.fn(pn) if self.fn is not None else fbm(pn, self.freq, self.oct, self.seed)
            # fade the relief out before the cut-off, so the field stays continuous (no crease where it stops)
            t = np.clip((lim - np.abs(d[near])) / (lim * 0.5), 0.0, 1.0)
            d[near] = d[near] - self.amp * n * t * t * (3 - 2 * t)
        return d

class Mirror(Prim):
    """The primitive and its mirror image across x = 0 (left and right side)."""
    def __init__(self, prim):
        self.p = prim; self.tag = prim.tag
    def bounds(self):
        lo, hi = self.p.bounds()
        m = np.array([-1, 1, 1])
        lo2, hi2 = np.minimum(lo * m, hi * m), np.maximum(lo * m, hi * m)
        return np.minimum(lo, lo2), np.maximum(hi, hi2)
    def dist(self, p):
        q = p.copy(); q[:, 0] = np.abs(q[:, 0])
        # the primitive is defined on the +x side or straddling 0; evaluate it at |x|
        return np.minimum(self.p.dist(q), self.p.dist(p))

# ------------------------------------------------------------------ the field
def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)

def smax(a, b, k):
    return -smin(-a, -b, k)

class Field:
    def __init__(self, lo, hi, vox):
        self.vox = vox
        self.lo = np.asarray(lo, float)
        n = np.ceil((np.asarray(hi, float) - self.lo) / vox).astype(int) + 1
        self.n = n
        self.d = np.full(tuple(n), 1.0, dtype=np.float32)
        self.ops = []          # (prim, k, mode) for later queries (tags)

    def _block(self, lo, hi, margin):
        i0 = np.maximum(np.floor((lo - margin - self.lo) / self.vox).astype(int), 0)
        i1 = np.minimum(np.ceil((hi + margin - self.lo) / self.vox).astype(int) + 1, self.n)
        if np.any(i1 <= i0):
            return None
        xs = self.lo[0] + np.arange(i0[0], i1[0]) * self.vox
        ys = self.lo[1] + np.arange(i0[1], i1[1]) * self.vox
        zs = self.lo[2] + np.arange(i0[2], i1[2]) * self.vox
        g = np.stack(np.meshgrid(xs, ys, zs, indexing="ij"), axis=-1).reshape(-1, 3)
        return i0, i1, g

    def add(self, prim, k=0.02):
        lo, hi = prim.bounds()
        blk = self._block(lo, hi, k + 3 * self.vox)
        self.ops.append((prim, k, "add"))
        if blk is None:
            return
        i0, i1, g = blk
        d = prim.dist(g).reshape(tuple(i1 - i0))
        sub = self.d[i0[0]:i1[0], i0[1]:i1[1], i0[2]:i1[2]]
        self.d[i0[0]:i1[0], i0[1]:i1[1], i0[2]:i1[2]] = smin(sub, d, k)

    def sub(self, prim, k=0.01):
        lo, hi = prim.bounds()
        blk = self._block(lo, hi, k + 3 * self.vox)
        self.ops.append((prim, k, "sub"))
        if blk is None:
            return
        i0, i1, g = blk
        d = prim.dist(g).reshape(tuple(i1 - i0))
        sub = self.d[i0[0]:i1[0], i0[1]:i1[1], i0[2]:i1[2]]
        self.d[i0[0]:i1[0], i0[1]:i1[1], i0[2]:i1[2]] = smax(sub, -d, k)

    def cut_below(self, z0):
        """Nothing below the ground plane z0 (hooves are flat on the ground)."""
        iz = int(math.floor((z0 - self.lo[2]) / self.vox))
        zs = self.lo[2] + np.arange(self.n[2]) * self.vox
        plane = (z0 - zs).astype(np.float32)          # positive below the plane
        self.d = np.maximum(self.d, plane[None, None, :])

    def sample(self, p):
        """Trilinear value of the field at points p (N, 3)."""
        p = np.atleast_2d(np.asarray(p, float))
        g = (p - self.lo) / self.vox
        i = np.clip(np.floor(g).astype(int), 0, self.n - 2)
        t = np.clip(g - i, 0, 1)
        out = np.zeros(len(p))
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    w = (t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1]) * (t[:, 2] if dz else 1 - t[:, 2])
                    out += w * self.d[i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz]
        return out

    def surface_along(self, start, direction, max_d=0.5, step=None):
        """First point where the field turns positive (leaves the body) going from `start` along `direction`."""
        step = step or self.vox * 0.5
        d = np.asarray(direction, float); d = d / np.linalg.norm(d)
        ts = np.arange(0, max_d, step)
        pts = np.asarray(start, float)[None] + ts[:, None] * d[None]
        v = self.sample(pts)
        inside = np.nonzero(v < 0)[0]
        if len(inside) == 0:
            return np.asarray(start, float)          # never inside: leave the point where it was
        i0 = inside[0]
        k = np.nonzero(v[i0:] > 0)[0]
        if len(k) == 0:
            return pts[-1]
        k = k[0] + i0
        a, b = v[k - 1], v[k]
        f = -a / (b - a) if b != a else 0.5
        return pts[k - 1] + (pts[k] - pts[k - 1]) * f

    def mesh(self):
        import pyopenvdb as vdb
        g = vdb.FloatGrid(1.0)
        g.copyFromArray(self.d)
        pts, tris, quads = g.convertToPolygons(isovalue=0.0, adaptivity=0.0)
        pts = np.asarray(pts, dtype=np.float64) * self.vox + self.lo
        return pts, np.asarray(tris), np.asarray(quads)

def nearest_tags(ops, pts, chunk=200000):
    """For each point, the tag of the closest added primitive (the one that made that bit of skin) and that distance;
    the second return is a dict tag -> min distance to any primitive with that tag (for soft colour masks)."""
    tags = sorted({op[0].tag for op in ops if op[2] == "add"})
    by_tag = {t: np.full(len(pts), 1e9) for t in tags}
    for prim, k, mode in ops:
        if mode != "add":
            continue
        lo, hi = prim.bounds()
        m = np.all((pts > lo - 0.08) & (pts < hi + 0.08), axis=1)
        if not m.any():
            continue
        d = prim.dist(pts[m])
        cur = by_tag[prim.tag]
        cur[m] = np.minimum(cur[m], d)
    return by_tag
