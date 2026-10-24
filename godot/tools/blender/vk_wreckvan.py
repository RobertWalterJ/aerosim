# AeroSim vehicle kit, lane/wreckvan: the two endgame vehicles of docs/story/CLAUDE-ENDGAME-ASSETS.md that were missing.
#   anne_car_wreck_a   Anne Voss's car: a 1970s pale blue estate (ARDEN 1300, fictional) that has lain in the lake for forty
#                      years: sunk into the silt to the sills, nose down and listing, the front left corner crumpled, the
#                      roof sagged, the windows broken out, lake weed growing round it and dried weed draped over it, rust
#                      through the paint. The silt bed is part of the model (bone root); the origin is the silt surface.
#   police_dive_van_a  a fictional Halloway Provincial Police dive team van: high-roof panel van, blue and yellow livery,
#                      roof rack with cases and a rescue board, lightbar, rear beacons and an amber bar, rear ladder,
#                      diver-down flag on its own bone, barn doors and sliding door that open onto a lined cargo bay
#                      (cylinder rack, bench, drysuits, crates, rope).
# Both are ordinary vk recipes (rigged, three LODs, AO, actions, manifest, defect checks); registered on import.
import bmesh, math, random
from mathutils import Vector as V, Matrix
from mathutils.bvhtree import BVHTree
import vk_build
import vk_details as det
import vk_interior as inter
import vk_extras as X
from vk_core import Part, bm_box, bm_rbox, bm_cyl, bm_tube, text_bm, smoothstep
from vk_body import section, R_SILL, R_SH, R_BELT, R_GL0, R_CANT, R_TOP, R_MID
from vk_recipes import add, tyre
from vk_recipes_cars import modern, rust_cond, van, police_livery


def _add(parts, name, bone, bm, mat):
    for q in parts:
        if q.name == name and q.bone == bone:
            q.add_bm(bm, mat); bm.free(); return
    p = Part(name, bone)
    p.add_bm(bm, mat)
    parts.append(p)
    bm.free()


def _ribbon(pts, widths, sides, mat_part, mat):
    """A flat strip through pts (V), half width widths[i] along sides[i] (unit V)."""
    bm = bmesh.new()
    left = [bm.verts.new(p - s * w) for p, w, s in zip(pts, widths, sides)]
    right = [bm.verts.new(p + s * w) for p, w, s in zip(pts, widths, sides)]
    for i in range(len(pts) - 1):
        try:
            f = bm.faces.new([left[i], right[i], right[i + 1], left[i + 1]])
            f.smooth = True
        except ValueError:
            pass
    return bm


# =============================================================================================== Anne Voss's car, the wreck
WRECK_SINK = 0.34          # how far the car has settled into the silt (m, at the middle)
WRECK_PITCH = -2.5         # nose down (degrees)
WRECK_ROLL = -3.0          # listing to the left (driver's side)
WRECK_SILT_LINE = 0.38     # the old water line on the body, metres above the silt surface (the model's origin)
WRECK_HOLE = (0.34, 1.12, 0.2)     # the hole through the windscreen, passenger side (x, z, radius)


def _wreck_matrix():
    return (Matrix.Translation((0, 0, -WRECK_SINK)) @ Matrix.Rotation(math.radians(WRECK_PITCH), 4, 'X') @
            Matrix.Rotation(math.radians(WRECK_ROLL), 4, 'Y'))


def _plane_of(n, c):
    if abs(n.x) >= 0.6:
        return "right" if c.x > 0 else "left"
    if abs(n.y) >= 0.22:
        return "front" if c.y > 0 else "rear"
    return "top"


def shatter(parts, holes, lod, seed=5):
    """Break the glass: subdivide every pane so a hole has a ragged edge, then delete the faces inside each hole.
    hole: {"plane": left/right/front/rear, "c": (u, v), "r": radius} (u, v = y, z on the sides and x, z front and rear)
    or {"plane", "box": (u0, u1, v0, v1)} (the whole pane gone, a few shards left in the frame)."""
    rnd = random.Random(seed)
    for p in parts:
        if "glass" not in p.mats:
            continue
        gi = p.mats.index("glass")
        bm = p.bm
        if lod <= 1:
            target = 0.05 if lod == 0 else 0.11
            for _ in range(5):
                edges = list({e for f in bm.faces if f.material_index == gi for e in f.edges if e.calc_length() > target})
                if not edges:
                    break
                bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=True)
        bm.normal_update()
        kill = []
        for f in bm.faces:
            if f.material_index != gi:
                continue
            c = f.calc_center_median()
            pl = _plane_of(f.normal, c)
            for h in holes:
                if h["plane"] != pl:
                    continue
                u, v = (c.y, c.z) if pl in ("left", "right") else (c.x, c.z)
                if "box" in h:
                    u0, u1, v0, v1 = h["box"]
                    if u0 <= u <= u1 and v0 <= v <= v1:
                        # leave a ragged fringe of shards along the bottom and one side of the frame
                        edge = min(v - v0, u1 - u)
                        if edge > 0.035 or rnd.random() < 0.55:
                            kill.append(f)
                        break
                else:
                    du, dv = u - h["c"][0], v - h["c"][1]
                    ang = math.atan2(dv, du)
                    rr = h["r"] * (0.85 + 0.12 * math.sin(ang * 3 + seed) + 0.07 * math.sin(ang * 7 + 2 * seed) + 0.05 * math.sin(ang * 13 + seed))
                    d = math.hypot(du, dv)
                    if d < rr * 0.86 or (d < rr and rnd.random() < 0.6):
                        kill.append(f)
                        break
        if kill:
            bmesh.ops.delete(bm, geom=kill, context='FACES')


def cracks(parts, surf, impacts, lod, seed=7):
    """Crazed glass round an impact on the windscreen: radiating cracks and broken rings, thin pale strips on the glass."""
    if lod > 1:
        return
    rnd = random.Random(seed)
    for (x0, z0, reach, r_in) in impacts:
        lines = []
        nrad = 9 if lod == 0 else 5
        for k in range(nrad):
            a = k / nrad * math.tau + rnd.uniform(-0.25, 0.25)
            ln = r_in + (reach - r_in) * rnd.uniform(0.55, 1.0)
            pts = []
            wob = rnd.uniform(-0.6, 0.6)
            for i in range(8):
                t = r_in + i / 7 * (ln - r_in)
                aa = a + wob * (t - r_in)
                pts.append((x0 + math.cos(aa) * t, z0 + math.sin(aa) * t * 0.85))
            lines.append(pts)
        for rad in (r_in + (reach - r_in) * 0.22, r_in + (reach - r_in) * 0.45):
            a0 = rnd.uniform(0, math.tau)
            for seg in range(3):
                a1 = a0 + seg * 2.1
                pts = [(x0 + math.cos(a1 + j * 0.16) * rad, z0 + math.sin(a1 + j * 0.16) * rad * 0.85) for j in range(7)]
                lines.append(pts)
        for pts2 in lines:
            hits = surf.project(pts2, 'front', 0.0035)
            run = [h for h in hits if h is not None]
            if len(run) < 2:
                continue
            P = [h[0] for h in run]
            N = [h[1] for h in run]
            sides = []
            for i in range(len(P)):
                t = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)])
                s = t.cross(N[i])
                sides.append(s.normalized() if s.length > 1e-9 else V((1, 0, 0)))
            w = [0.0016 * (1.0 - 0.6 * i / len(P)) for i in range(len(P))]
            bm = _ribbon(P, w, sides, None, None)
            bm.normal_update()
            for f in bm.faces:
                if f.normal.y < 0:
                    f.normal_flip()
            _add(parts, "cracks", "body", bm, "crack")


def dents(parts, s):
    """Forty years in the lake: the front left corner crumpled where it went in, the roof sagging under ice and silt."""
    L, W, H = s.L, s.W, s.H
    cx, cy = -W * 0.5 + 0.06, L * 0.5 - 0.04
    push = V((0.72, -0.62, -0.08)).normalized()
    ry0 = L * 0.5 - 2.65             # the middle of the sag (over the rear seats)
    for p in parts:
        if p.bone.startswith("wheel_") or p.bone.startswith("steer_"):
            continue
        for v in p.bm.verts:
            co = v.co
            d = math.hypot(co.x - cx, co.y - cy)
            if d < 0.88 and co.z < 1.0:
                k = (1.0 - d / 0.88) ** 1.6 * (1.0 - smoothstep(0.8, 1.0, co.z))
                rip = 0.032 * k * math.sin(co.y * 33.0 + co.z * 19.0) * math.sin(co.x * 29.0 - co.z * 13.0)
                co = co + push * (0.17 * k) + V((0.75, -0.3, 0.2)) * rip
            if co.z > H - 0.34:
                g = math.exp(-((co.y - ry0) / 0.85) ** 2) * max(0.0, 1.0 - (co.x / (W * 0.5 - 0.1)) ** 2)
                top = smoothstep(H - 0.34, H - 0.04, co.z)
                co = co + V((0, 0, -(0.085 * g + 0.007 * g * math.sin(co.y * 12.0) * math.cos(co.x * 9.0)) * top))
            v.co = co


def smash_lamp(parts, side=-1):
    """The headlamp on the crumpled corner: lens gone, the chrome bowl left."""
    for p in parts:
        if "lamp_front" not in p.mats:
            continue
        li = p.mats.index("lamp_front")
        kill = [f for f in p.bm.faces if f.material_index == li and f.calc_center_median().x * side > 0.1]
        if kill:
            bmesh.ops.delete(p.bm, geom=kill, context='FACES')


def _bvh(parts):
    bm = bmesh.new()
    for p in parts:
        if p.bone.startswith("wheel_") or p.bone.startswith("steer_") or p.name == "cracks":
            continue
        tmp = p.bm.copy()
        mesh_vmap = {}
        tmp.verts.index_update()
        for v in tmp.verts:
            mesh_vmap[v.index] = bm.verts.new(v.co)
        for f in tmp.faces:
            try:
                bm.faces.new([mesh_vmap[v.index] for v in f.verts])
            except ValueError:
                pass
        tmp.free()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


def draped_weed(parts, s, lod, seed=11):
    """Dried lake weed left on the car when the water went down: strands lying over the roof and bonnet, running off the
    edges and hanging down the sides, and a few matted clumps."""
    if lod > 1:
        return
    rnd = random.Random(seed)
    tree = _bvh(parts)
    L, W, H = s.L, s.W, s.H
    n_str = 16 if lod == 0 else 8
    step = 0.05 if lod == 0 else 0.1
    for k in range(n_str):
        on_roof = k % 3 != 0
        if on_roof:
            x = rnd.uniform(-0.45, 0.45); y = L * 0.5 - rnd.uniform(1.95, 3.6)
            ang = rnd.choice((0.0, math.pi)) + rnd.uniform(-0.5, 0.5)       # across the roof, off one side
        else:
            x = rnd.uniform(-0.55, 0.55); y = L * 0.5 - rnd.uniform(0.25, 0.9)
            ang = rnd.choice((0.0, math.pi, math.pi * 0.5)) + rnd.uniform(-0.4, 0.4)
        dirv = V((math.cos(ang), math.sin(ang), 0))
        pts, nrms = [], []
        prev_z = None
        hang = False
        length = rnd.uniform(0.5, 1.2)
        travelled = 0.0
        while travelled < length:
            loc, nrm, _, _ = tree.ray_cast(V((x, y, 4.0)), V((0, 0, -1)), 8.0)
            if loc is None or (prev_z is not None and loc.z < prev_z - 0.07):
                hang = True
                break
            if nrm.z < 0:
                nrm = -nrm
            pts.append(loc + nrm * 0.006); nrms.append(nrm)
            prev_z = loc.z
            jit = rnd.uniform(-0.35, 0.35)
            dirv = V((dirv.x * math.cos(jit * 0.3) - dirv.y * math.sin(jit * 0.3), dirv.x * math.sin(jit * 0.3) + dirv.y * math.cos(jit * 0.3), 0))
            x += dirv.x * step; y += dirv.y * step
            travelled += step
        if hang and pts:
            # down the face it ran off: cast back in toward the car at falling heights
            z = pts[-1].z
            drop = rnd.uniform(0.12, 0.38)
            zz = z
            while zz > z - drop:
                zz -= step
                o = V((x, y, zz)) + dirv * 2.0
                loc, nrm, _, _ = tree.ray_cast(o, -dirv, 3.0)
                if loc is None:
                    break
                if nrm.dot(dirv) < 0:
                    nrm = -nrm
                pts.append(loc + nrm * 0.008); nrms.append(nrm)
        if len(pts) < 3:
            continue
        sides, widths = [], []
        w0 = rnd.uniform(0.012, 0.03)
        for i in range(len(pts)):
            t = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
            sv = t.cross(nrms[i])
            sides.append(sv.normalized() if sv.length > 1e-9 else V((1, 0, 0)))
            widths.append(w0 * (0.6 + 0.4 * math.sin(i * 0.9 + k)) * (1.0 - 0.5 * i / len(pts)))
        # a strand is a loose bundle of three or four fronds lying side by side
        for c in range(3 if lod == 0 else 1):
            off = (c - 1) * w0 * 1.6 + rnd.uniform(-0.004, 0.004)
            cut = len(pts) - rnd.randint(0, max(1, len(pts) // 4))
            P2 = [pts[i] + sides[i] * (off * (0.6 + 0.4 * math.sin(i * 0.7 + c))) + nrms[i] * 0.001 * c for i in range(cut)]
            if len(P2) < 2:
                continue
            bm = _ribbon(P2, [w * rnd.uniform(0.5, 0.9) for w in widths[:cut]], sides[:cut], None, None)
            bm.normal_update()
            for f in bm.faces:
                if f.normal.dot(nrms[0]) < 0:
                    f.normal_flip()
            _add(parts, "weed_draped", "body", bm, "weed_dry" if (k + c) % 4 else "weed")
    # matted clumps on the bonnet and roof
    for k in range(7 if lod == 0 else 3):
        x = rnd.uniform(-0.5, 0.5)
        y = L * 0.5 - (rnd.uniform(0.3, 1.0) if k < 3 else rnd.uniform(1.9, 3.5))
        r = rnd.uniform(0.06, 0.13)
        n = 16
        bm = bmesh.new()
        ring = []
        ok = True
        c, cn, _, _ = tree.ray_cast(V((x, y, 4.0)), V((0, 0, -1)), 8.0)
        if c is None:
            continue
        for j in range(n):
            a = j / n * math.tau
            rr = r * (rnd.uniform(0.35, 0.7) if j % 2 else rnd.uniform(0.8, 1.4))      # ragged, fringed edge
            loc, nrm, _, _ = tree.ray_cast(V((x + math.cos(a) * rr, y + math.sin(a) * rr * 1.4, 4.0)), V((0, 0, -1)), 8.0)
            if loc is None or abs(loc.z - c.z) > 0.08:
                ok = False; break
            ring.append(bm.verts.new(loc + V((0, 0, 0.004))))
        if not ok:
            bm.free(); continue
        mid = bm.verts.new(c + V((0, 0, 0.012)))
        for j in range(n):
            f = bm.faces.new([mid, ring[j], ring[(j + 1) % n]])
            f.smooth = True
        bm.normal_update()
        for f in bm.faces:
            if f.normal.z < 0:
                f.normal_flip()
        _add(parts, "weed_mat", "body", bm, "weed_dry")


def _silt_h(x, y, a, b, rnd_phase):
    """Height of the silt bed at (x, y) (the model's frame, after the car has settled). a, b: half width and half length
    of the car's footprint (a little inside the skin, so the step under the sills is hidden by the body)."""
    qx = abs(x) - (a - 0.25); qy = abs(y) - (b - 0.25)
    out = math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - 0.25      # signed distance to a rounded box
    ripple = 0.012 * math.sin(x * 9.0 + y * 2.0 + rnd_phase) * math.sin(y * 3.1 - x * 1.3)
    swell = 0.035 * math.sin(x * 1.3 + 0.5) * math.cos(y * 0.9 + rnd_phase) + 0.02 * math.sin(x * 3.7 - y * 2.9)
    if out < 0:
        return 0.06 + 0.02 * math.sin(x * 5.0 + y * 4.0) + 0.5 * ripple, out
    lip = 0.17 * math.exp(-out / 0.22) + 0.05 * math.exp(-out / 0.9)
    return lip + swell * min(1.0, out / 0.3) + ripple, out


def _silt_edge(x, y, X1, Y1):
    """0 at the middle, 1 at the edge of the bed: an elliptical, wavering outline (not the grid's rectangle)."""
    ang = math.atan2(y / Y1, x / X1)
    wob = 1.0 + 0.1 * math.sin(ang * 3.0 + 0.7) + 0.06 * math.sin(ang * 7.0 + 2.1)
    return math.hypot(x / X1, y / Y1) ** 1.6 * 0.92 / wob + 0.1 * max(abs(x) / X1, abs(y) / Y1) ** 6


def silt_bed(parts, s, lod, margin=0.95, seed=3):
    """The lake bed the car sits in: a heightfield round the body that rises in a lip against the panels, fills the cabin
    to the seat bases, ripples, and tucks under the ground at its edge. On the root bone (it does not ride the body)."""
    a, b = s.W * 0.5 - 0.07, s.L * 0.5 - 0.05
    X0, X1 = -a - margin, a + margin
    Y0, Y1 = -b - margin, b + margin
    step = {0: 0.1, 1: 0.2, 2: 0.42}[lod]
    nx = int(math.ceil((X1 - X0) / step)); ny = int(math.ceil((Y1 - Y0) / step))
    bm = bmesh.new()
    rows = []
    for j in range(ny + 1):
        y = Y0 + (Y1 - Y0) * j / ny
        row = []
        for i in range(nx + 1):
            x = X0 + (X1 - X0) * i / nx
            h, out = _silt_h(x, y, a, b, seed)
            e = _silt_edge(x, y, X1, Y1)
            h = h * (1.0 - smoothstep(0.62, 0.95, e)) - 0.05 * smoothstep(0.8, 1.0, e)
            row.append(bm.verts.new((x, y, h)))
        rows.append(row)
    for j in range(ny):
        for i in range(nx):
            f = bm.faces.new([rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]])
            f.smooth = True
    bm.normal_update()
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    _add(parts, "silt", "root", bm, "silt")
    return a, b


def silt_weed(parts, s, a, b, lod, seed=21):
    """Lake weed growing out of the silt: blades round the car, leaning with the old current, and a few up through the
    silt in the cabin."""
    if lod > 1:
        return
    rnd = random.Random(seed)
    segs = 4 if lod == 0 else 2
    drift = V((0.8, 0.35, 0)).normalized()
    X1, Y1 = a + 0.95, b + 0.95

    def ground(x, y):
        h0, out = _silt_h(x, y, a, b, 3)
        e = _silt_edge(x, y, X1, Y1)
        return h0 * (1.0 - smoothstep(0.62, 0.95, e)) - 0.05 * smoothstep(0.8, 1.0, e), out, e

    def blade(base, lean, ht, w, droop, mat):
        side = V((-lean.y, lean.x, 0))
        pts, ws, sd = [], [], []
        for i in range(segs + 1):
            t = i / segs
            # rises, then the tip arches over and droops with its own weight
            up = ht * (t - droop * t * t)
            pts.append(base + V((0, 0, max(up, -0.01))) + lean * (ht * (0.25 + droop) * t ** 1.5))
            ws.append(w * (1.0 - 0.75 * t))
            sd.append(side)
        bm = _ribbon(pts, ws, sd, None, None)
        _add(parts, "weed_silt", "root", bm, mat)

    # sedge tufts: a fan of leaves from one root, in clumps against the car and scattered out on the bed
    n_tuft = 46 if lod == 0 else 18
    made = tries = 0
    while made < n_tuft and tries < 4000:
        tries += 1
        x = rnd.uniform(-X1, X1); y = rnd.uniform(-Y1, Y1)
        h0, out, e = ground(x, y)
        if out < 0.12 or e > 0.85:
            continue
        if rnd.random() > 0.25 + 0.75 * math.exp(-out / 0.35):
            continue
        n_leaf = rnd.randint(7, 13) if lod == 0 else rnd.randint(3, 5)
        tall = rnd.uniform(0.22, 0.55) * (0.7 + 0.5 * math.exp(-out / 0.5))
        dry = rnd.random() < 0.35
        for k in range(n_leaf):
            ang = rnd.uniform(0, math.tau)
            lean = V((math.cos(ang), math.sin(ang), 0)) * 0.7 + drift * 0.45
            lean = lean.normalized()
            base = V((x + math.cos(ang) * 0.025, y + math.sin(ang) * 0.025, h0 - 0.015))
            blade(base, lean, tall * rnd.uniform(0.5, 1.0), rnd.uniform(0.006, 0.011), rnd.uniform(0.15, 0.55),
                  "weed_dry" if dry or rnd.random() < 0.2 else "weed")
        made += 1
    # limp pondweed left lying on the silt when the water went down: long strands, mostly flat, drifting one way
    n_limp = 70 if lod == 0 else 22
    made = tries = 0
    while made < n_limp and tries < 4000:
        tries += 1
        x = rnd.uniform(-X1, X1); y = rnd.uniform(-Y1, Y1)
        h0, out, e = ground(x, y)
        if out < 0.05 or e > 0.8 or rnd.random() > math.exp(-out / 0.5):
            continue
        lean = (drift + V((rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), 0))).normalized()
        side = V((-lean.y, lean.x, 0))
        pts, ws, sd = [], [], []
        ln = rnd.uniform(0.25, 0.7)
        w = rnd.uniform(0.012, 0.025)
        for i in range(segs * 2 + 1):
            t = i / (segs * 2)
            px = x + lean.x * ln * t + side.x * 0.04 * math.sin(t * 7 + made)
            py = y + lean.y * ln * t + side.y * 0.04 * math.sin(t * 7 + made)
            gz, _, _ = ground(px, py)
            pts.append(V((px, py, gz + 0.008 + 0.02 * math.sin(t * math.pi) * (1 - t))))
            ws.append(w * (0.5 + 0.5 * math.sin(t * 9 + made) ** 2) * (1 - 0.6 * t))
            sd.append(side)
        bm = _ribbon(pts, ws, sd, None, None)
        bm.normal_update()
        for f in bm.faces:
            if f.normal.z < 0:
                f.normal_flip()
        _add(parts, "weed_silt", "root", bm, "weed" if rnd.random() < 0.55 else "weed_dry")
        made += 1
    # a few shoots up through the silt in the cabin, seen through the broken windows
    for k in range(10 if lod == 0 else 4):
        x = rnd.uniform(-a + 0.25, a - 0.25); y = rnd.uniform(-1.1, 0.5)
        h0, out, e = ground(x, y)
        if out > -0.2:
            continue
        ang = rnd.uniform(0, math.tau)
        blade(V((x, y, h0 - 0.01)), V((math.cos(ang), math.sin(ang), 0)), rnd.uniform(0.12, 0.3), 0.008, 0.3, "weed")


def cull_buried(parts, below=-0.1):
    """Faces entirely under the silt (the wheels, the floor pan, the lower doors) can never be seen: drop them."""
    for p in parts:
        if p.name.startswith("silt") or p.name.startswith("weed"):
            continue
        kill = [f for f in p.bm.faces if all(v.co.z < below for v in f.verts)]
        if kill:
            bmesh.ops.delete(p.bm, geom=kill, context='FACES')


def wreck_maker(rc, lod):
    parts, info = vk_build.car_parts(rc, lod)
    s = info["spec"]
    # the glass: windscreen holed on the passenger side and crazed round an impact on the driver's side; driver's window
    # and the right rear quarter light gone; a hole in the right rear door glass; the tailgate glass mostly out
    W, L = s.W, s.L
    d_a = rc["_doors"][0]; d_b = rc["_doors"][1]; d_c = rc["_doors"][2]
    holes = [
        {"plane": "front", "c": WRECK_HOLE[:2], "r": WRECK_HOLE[2]},
        {"plane": "left", "box": (L * 0.5 - d_b + 0.02, L * 0.5 - d_a - 0.02, 0.0, 2.0)},
        {"plane": "right", "box": (L * 0.5 - (rc["_roof_end"] - 0.05), L * 0.5 - d_c - 0.02, 0.0, 2.0)},
        {"plane": "right", "c": (L * 0.5 - (d_b + d_c) * 0.5, 1.1), "r": 0.17},
        {"plane": "rear", "c": (0.05, 1.08), "r": 0.42},
    ]
    shatter(parts, holes, lod)
    cracks(parts, info["surf"], [(-0.3, 1.12, 0.36, 0.0), (WRECK_HOLE[0], WRECK_HOLE[1], 0.34, WRECK_HOLE[2] * 1.1)], lod)
    smash_lamp(parts, -1)
    dents(parts, s)
    draped_weed(parts, s, lod)
    M = _wreck_matrix()
    for p in parts:
        bmesh.ops.transform(p.bm, matrix=M, verts=p.bm.verts)
    cull_buried(parts)
    a, b = silt_bed(parts, s, lod)
    silt_weed(parts, s, a, b, lod)
    return parts, info


def wreck_bones(rc, info):
    bones = vk_build.car_bones(rc, info)
    M = _wreck_matrix()
    for bn in bones:
        if bn["name"] == "root":
            continue
        bn["head"] = tuple(M @ V(bn["head"]))
        bn["tail"] = tuple(M @ V(bn["tail"]))
    info["hubs"] = [(nm, tuple(M @ V(h)), st) for (nm, h, st) in info["hubs"]]
    return bones


def _wreck():
    L, W = 4.30, 1.66
    head = {"x": W * 0.5 - 0.21, "z": 0.60, "w": 0.175, "h": 0.175, "r": 0.085, "slant": 0.0, "bowls": 1, "bezel": True,
            "auto": True, "turn": 0.7}
    tail = {"x": W * 0.5 - 0.09, "z": 0.72, "w": 0.13, "h": 0.30, "r": 0.012, "auto": True, "turn": 0.5,
            "layout": [("lamp_ind", 0.0, 1.0, 0.72, 1.0), ("lamp_tail", 0.0, 1.0, 0.34, 0.72), ("lamp_brake", 0.0, 1.0, 0.12, 0.34),
                       ("lamp_reverse", 0.0, 1.0, 0.0, 0.12)]}
    grille = {"z": 0.60, "w": 0.70, "h": 0.13, "slats": 4, "vbars": 0, "frame": "chrome", "r": 0.006, "slat": "chrome", "back": "trim"}
    extras = [X.bumpers(0.40, 0.43, h=0.10, depth=0.09, mat="chrome", wrap=0.28), X.gutters("chrome")]
    rc = modern("anne_car_wreck_a", "estate", L, W, 1.40, 2.52, 0.80, tyre(165, 80, 13), (0.60, 0.71, 0.78), "ARDEN",
                style="steel_cap", nose=0.70, cowl_d=1.20, cowl_z=0.90, roof_d=1.80, roof_end=L - 0.30, belt0=0.80, belt1=0.84,
                sill=0.30, gc=0.16, plan_rf=0.10, mirror_mat="chrome", handle_mat="chrome", boxy=True, head=head, tail=tail,
                grille=grille, cond=rust_cond(0.8, seed=11), extras=extras,
                body_over={"th": 0.15, "sh_drop": 0.025, "belt_in": 0.02, "side_bulge": 0.004,
                           "front_face": [(0.0, 0.04), (0.3, 0.02), (0.45, 0.0), (0.62, 0.0), (0.68, 0.01), (0.74, 0.03)],
                           "rear_face": [(0.0, 0.05), (0.3, 0.02), (0.45, 0.0), (0.85, 0.0), (0.95, 0.03), (1.05, 0.06)],
                           "seal_mat": "chrome", "frame_mat": "chrome", "pillar_mat": "trim"})
    d = rc["detail"]
    d["front_panels"] = []
    d["strips"] = [{"d0": 0.35, "d1": L - 0.3, "z": 0.56, "h": 0.022, "mat": "chrome", "off": 0.005}]
    d["wipers"] = {"pivots": (0.34, -0.2), "length": 0.46}
    d.pop("exhaust", None)
    d["badge"]["text"] = "ARDEN 1300"
    rc["wheel"]["cap_mat"] = "chrome"
    rc["interior"]["shelf"] = None
    rc["mat_colours"] = {"seat": (0.11, 0.085, 0.06), "interior": (0.075, 0.065, 0.05), "dash": (0.05, 0.045, 0.04),
                         "trim": (0.03, 0.03, 0.028), "plate": (0.55, 0.52, 0.44)}
    # the door stations (as modern() works them out) for the glass holes
    cowl_d, roof_end = 1.20, L - 0.30
    sc = min(1.1, max(0.9, 2.52 / 2.64))
    d_a = cowl_d + 0.08
    d_b = d_a + 1.20 * sc
    R = tyre(165, 80, 13)[0]
    d_c = min(0.80 + 2.52 - (R + 0.045) + 0.18, roof_end - 0.08)
    rc["_doors"] = (d_a, d_b, d_c)
    rc["_roof_end"] = roof_end
    rc["maker"] = wreck_maker
    rc["bones_fn"] = wreck_bones
    rc["dirt"] = 0.9
    rc["ao_dist"] = 0.6

    def colliders(lo, hi):
        # the body (game frame: x, y up, z back); the silt bed carries none
        top = 1.40 - WRECK_SINK
        return [[(-W * 0.5, 0.0, -L * 0.5), (W * 0.5, round(0.86 - WRECK_SINK, 3), L * 0.5)],
                [(-W * 0.5 + 0.12, round(0.86 - WRECK_SINK, 3), -L * 0.5 + 1.1), (W * 0.5 - 0.12, round(top, 3), L * 0.5 - 0.35)]]
    rc["colliders_fn"] = colliders
    rc["manifest_extra"] = {"sunk": 0.5, "wreck": {"silt_line": WRECK_SILT_LINE, "paint_tex": "wreck_paint_diff",
                                                   "paint_nor": "wreck_paint_nor", "paint_scale": 1.1, "paint_amount": 0.75,
                                                   "silt_tex": "wreck_silt_diff", "silt_scale": 0.77}}
    return rc


add(_wreck())


# ======================================================================================== the police dive team van
def _rear_text(parts, surf, txt, x, z, size, mat, bone):
    """Lettering on the rear face that reads left to right from behind (standing behind, the viewer's right is +x)."""
    bm = text_bm(txt, size, 0.0)
    for v in bm.verts:
        a, b = v.co.x, v.co.y
        o, dr = V((x + a, -20, z + b)), V((0, 1, 0))
        loc, nrm = surf.hit(o, dr, 40)
        v.co = (loc + V((0, -0.004, 0))) if loc is not None else o
    bm.normal_update()
    for f in bm.faces:
        if f.normal.y > 0:
            f.normal_flip()
    _add(parts, "letters_rear", bone, bm, mat)


def van_dressing(cfg):
    """Everything the dive van adds to the panel van: roof rack and its load, lamps, ladder, flag, lettering on the rear,
    the lined cargo bay and its kit, door cards on the barn doors."""
    def ex(parts, s, surf, lod, info):
        L, W, H = s.L, s.W, s.H
        rnd = random.Random(4)
        # ---------------------------------------------------------------- roof rack
        d0, d1 = cfg["rack"]
        zr = H + 0.11
        P0 = section(s, (d0 + d1) * 0.5)
        xr = P0[R_CANT][0] - 0.03
        seg = 10 if lod == 0 else 6
        for sx in (1, -1):
            _add(parts, "rack", "body", bm_tube((sx * xr, L * 0.5 - d0, zr), (sx * xr, L * 0.5 - d1, zr), 0.016, seg), "metal")
        n_x = 7
        for k in range(n_x):
            d = d0 + (d1 - d0) * k / (n_x - 1)
            y = L * 0.5 - d
            _add(parts, "rack", "body", bm_tube((-xr, y, zr), (xr, y, zr), 0.013, seg), "metal")
            if k % 2 == 0:
                P = section(s, d)
                for sx in (1, -1):
                    leg = bm_tube((sx * (P[R_CANT][0] - 0.02), y, P[R_CANT][1] - 0.01), (sx * xr, y, zr), 0.014, seg)
                    _add(parts, "rack", "body", leg, "metal")
                    _add(parts, "rack", "body", bm_rbox((0.07, 0.09, 0.03), 0.008, 1, (sx * (P[R_CANT][0] - 0.02), y, P[R_CANT][1])), "trim")
        # front wind deflector
        _add(parts, "rack", "body", bm_rbox((2 * xr, 0.02, 0.09), 0.006, 1, (0, L * 0.5 - d0 + 0.02, zr + 0.02)), "trim")
        # the load: two aluminium cases, a yellow rescue board, a bundle of poles
        _add(parts, "rack_load", "body", bm_rbox((0.62, 1.1, 0.32), 0.02, 2 if lod == 0 else 1, (-0.42, L * 0.5 - (d0 + 0.9), zr + 0.175)), "rim")
        _add(parts, "rack_load", "body", bm_rbox((0.62, 0.85, 0.28), 0.02, 2 if lod == 0 else 1, (-0.42, L * 0.5 - (d0 + 2.05), zr + 0.155)), "rim")
        for (y, x) in ((L * 0.5 - (d0 + 0.9), -0.42), (L * 0.5 - (d0 + 2.05), -0.42)):
            if lod == 0:
                for sx in (-0.2, 0.2):
                    _add(parts, "rack_load", "body", bm_box((0.05, 0.02, 0.03), (x + sx, y + 0.0, zr + 0.34)), "trim")
        board = bm_rbox((0.55, 2.3, 0.07), 0.03, 2 if lod == 0 else 1, (0.42, L * 0.5 - (d0 + 1.35), zr + 0.05))
        _add(parts, "rack_load", "body", board, "kit_yellow")
        for k in range(4 if lod == 0 else 2):
            xx = 0.2 + k * 0.035
            _add(parts, "rack_load", "body", bm_tube((xx, L * 0.5 - d0 + 0.1, zr + 0.11), (xx, L * 0.5 - d1 + 0.2, zr + 0.11), 0.014, 6), "metal")
        # straps
        for yy in (L * 0.5 - (d0 + 0.6), L * 0.5 - (d0 + 2.1)):
            _add(parts, "rack_load", "body", bm_box((0.62, 0.03, 0.006), (0.42, yy, zr + 0.088)), "trim")
        # ---------------------------------------------------------------- lamps
        yb = L * 0.5 - d1 + 0.08
        for sx, mat in ((-1, "lightbar_red"), (1, "lightbar_blue")):
            _add(parts, "lamps_extra", "body", bm_rbox((0.13, 0.1, 0.1), 0.02, 1, (sx * (xr - 0.02), yb, zr + 0.06)), mat)
            _add(parts, "lamps_extra", "body", bm_box((0.1, 0.06, 0.04), (sx * (xr - 0.02), yb, zr - 0.0)), "trim")
        # amber rear traffic bar on the rear rack bar
        _add(parts, "lamps_extra", "body", bm_rbox((0.9, 0.08, 0.06), 0.01, 1, (0, yb - 0.02, zr + 0.045)), "trim")
        for k in range(4):
            _add(parts, "lamps_extra", "body", bm_rbox((0.19, 0.03, 0.045), 0.008, 1, (-0.33 + k * 0.22, yb - 0.065, zr + 0.045)), "lamp_beacon")
        # grille flashers
        for sx, mat in ((-1, "lightbar_red"), (1, "lightbar_blue")):
            h = surf.project([(sx * 0.48, 0.76)], 'front', 0.0)[0]
            if h:
                loc, n = h
                _add(parts, "lamps_extra", "body", bm_cyl(0.035, 0.035, 0.03, 12, 'Y', (loc.x, loc.y + 0.012, loc.z)), mat)
        # ---------------------------------------------------------------- the diver-down flag, on its own bone
        fx, fy = -(xr - 0.02), L * 0.5 - d1 + 0.22
        staff_top = zr + 0.78
        _add(parts, "flag", "dive_flag", bm_tube((fx, fy, zr - 0.02), (fx, fy, staff_top), 0.011, 8), "metal")
        _add(parts, "flag", "dive_flag", bm_cyl(0.02, 0.02, 0.02, 8, 'Z', (fx, fy, staff_top + 0.01)), "trim")
        _add(parts, "flag", "dive_flag", bm_rbox((0.06, 0.06, 0.05), 0.01, 1, (fx, fy, zr + 0.02)), "trim")
        fw, fh = 0.5, 0.36
        nu = 10 if lod == 0 else 4
        def flag_pt(u, v, off=0.0):
            # u along the fly (+y, toward the front), v down from the top; a gentle wave
            yy = fy + 0.015 + u * fw
            xx = fx + 0.03 * math.sin(u * 5.0) * u + off
            return V((xx, yy, staff_top - 0.03 - v * fh))
        bm = bmesh.new()
        grid = [[bm.verts.new(flag_pt(i / nu, j / 2)) for i in range(nu + 1)] for j in range(3)]
        for j in range(2):
            for i in range(nu):
                f = bm.faces.new([grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]])
                f.smooth = True
        _add(parts, "flag", "dive_flag", bm, "flag_a")
        # the white diagonal, both faces, a hair proud of the cloth
        for off in (0.0025, -0.0025):
            bm = bmesh.new()
            sw = 0.075
            top, bot = [], []
            for i in range(nu + 1):
                u = i / nu
                vc = u                          # from the hoist top to the fly bottom
                v0 = max(0.0, vc - sw / fh); v1 = min(1.0, vc + sw / fh)
                top.append(bm.verts.new(flag_pt(u, v0, off)))
                bot.append(bm.verts.new(flag_pt(u, v1, off)))
            for i in range(nu):
                f = bm.faces.new([top[i], top[i + 1], bot[i + 1], bot[i]])
            bm.normal_update()
            for f in bm.faces:
                if f.normal.x * off < 0:
                    f.normal_flip()
            _add(parts, "flag", "dive_flag", bm, "sheet_white")
        # ---------------------------------------------------------------- ladder on the right barn door
        yl = -L * 0.5 - 0.055
        x0l, x1l = 0.66, 0.92
        zl0, zl1 = 0.62, H - 0.12
        for xx in (x0l, x1l):
            _add(parts, "ladder", "door_rear_r", bm_tube((xx, yl, zl0), (xx, yl, zl1), 0.014, 8), "metal")
            for zz in (zl0 + 0.1, zl1 - 0.1):
                _add(parts, "ladder", "door_rear_r", bm_tube((xx, yl, zz), (xx, yl + 0.06, zz), 0.01, 6), "metal")
        nr = int((zl1 - zl0) / 0.28)
        for k in range(1, nr + 1):
            zz = zl0 + k * (zl1 - zl0) / (nr + 1)
            _add(parts, "ladder", "door_rear_r", bm_tube((x0l, yl, zz), (x1l, yl, zz), 0.012, 6), "metal")
        # ---------------------------------------------------------------- rear lettering
        _rear_text(parts, surf, "POLICE", -0.4, 1.0, 0.1, "lettering2", "door_rear_l")
        _rear_text(parts, surf, "DIVE UNIT", 0.38, 1.0, 0.09, "lettering2", "door_rear_r")
        if lod == 0:
            _rear_text(parts, surf, "CORVAN", 0.36, 0.72, 0.04, "chrome", "door_rear_r")
        if lod <= 1:
            _cargo(parts, s, cfg, lod)
    return ex


def _cargo(parts, s, cfg, lod):
    """The cargo bay behind the partition: ply floor, lined walls and roof (with wheel boxes), door cards on the barn
    doors, and the dive kit."""
    L, W, H = s.L, s.W, s.H
    zf = cfg["floor"]
    d0, d1 = cfg["cargo"][0], L - 0.07
    ds_slide = cfg["slide"]
    arch = cfg["rear_arch"]          # (d centre, half length, x inner, z top)
    step = 0.25 if lod == 0 else 0.5
    stations = sorted(set([d0 + i * step for i in range(int((d1 - d0) / step) + 1)] + [d1, ds_slide[1], arch[0] - arch[1], arch[0] + arch[1]]))
    stations = [d for d in stations if d0 <= d <= d1]

    def ring(d):
        P = section(s, d)
        xs = P[R_SH][0] - 0.045
        return [(xs, zf), (xs, P[R_SH][1]), (P[R_BELT][0] - 0.045, P[R_BELT][1]), (P[R_CANT][0] - 0.05, P[R_CANT][1] - 0.05),
                (0.0, P[R_TOP][1] - 0.05)]
    for i in range(len(stations) - 1):
        da, db = stations[i], stations[i + 1]
        ya, yb = L * 0.5 - da, L * 0.5 - db
        ra, rb = ring(da), ring(db)
        dm = (da + db) * 0.5
        in_arch = abs(dm - arch[0]) < arch[1]
        for sx in (1, -1):
            bone = "door_slide_r" if (sx > 0 and ds_slide[0] - 1e-4 <= da and db <= ds_slide[1] + 1e-4) else "body"
            bm = bmesh.new()
            for k in range(len(ra) - 1):
                (xa0, za0), (xa1, za1) = ra[k], ra[k + 1]
                (xb0, zb0), (xb1, zb1) = rb[k], rb[k + 1]
                if k == 0 and in_arch:
                    za0 = zb0 = arch[3]
                vs = [bm.verts.new((sx * xa0, ya, za0)), bm.verts.new((sx * xa1, ya, za1)), bm.verts.new((sx * xb1, yb, zb1)),
                      bm.verts.new((sx * xb0, yb, zb0))]
                bm.faces.new(vs)
            bm.normal_update()
            for f in bm.faces:
                c = f.calc_center_median()
                if f.normal.dot(V((-c.x, 0, (H * 0.5) - c.z))) < 0:
                    f.normal_flip()
            _add(parts, "cargo_lining", bone, bm, "interior")
            if in_arch:
                # the wheel box: top and inner face
                xin = arch[2]
                xa = ra[0][0]
                bm = bm_box((xa - xin, yb - ya if yb > ya else ya - yb, 0.01), (sx * (xin + xa) * 0.5, (ya + yb) * 0.5, arch[3]))
                _add(parts, "cargo_lining", "body", bm, "interior")
                bm = bmesh.new()
                vs = [bm.verts.new((sx * xin, ya, zf)), bm.verts.new((sx * xin, ya, arch[3])), bm.verts.new((sx * xin, yb, arch[3])),
                      bm.verts.new((sx * xin, yb, zf))]
                bm.faces.new(vs)
                bm.normal_update()
                for f in bm.faces:
                    if f.normal.x * sx > 0:
                        f.normal_flip()
                _add(parts, "cargo_lining", "body", bm, "interior")
        # floor (ply)
        xa, xb = ra[0][0], rb[0][0]
        bm = bmesh.new()
        f = bm.faces.new([bm.verts.new((-xa, ya, zf)), bm.verts.new((xa, ya, zf)), bm.verts.new((xb, yb, zf)), bm.verts.new((-xb, yb, zf))])
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
        _add(parts, "cargo_floor", "body", bm, "wood")
    # door cards on the barn doors (facing in), with the window left open on each
    P = section(s, L - 0.05)
    yd = -L * 0.5 + 0.06
    z_lo, z_hi = P[R_SILL][1] + 0.04, P[R_CANT][1] - 0.04
    g0, g1 = P[R_GL0][1], P[R_CANT][1]
    wx0, wx1 = 0.07, cfg["rear_win_x1"]
    xo = P[R_SH][0] - 0.06
    for sx, bone in ((1, "door_rear_r"), (-1, "door_rear_l")):
        rects = [(0.012, xo, z_lo, g0), (0.012, wx0, g0, g1), (wx1, xo, g0, g1), (0.012, xo, min(g1, z_hi), z_hi)]
        for (xa, xb, za, zb) in rects:
            if xb - xa < 0.01 or zb - za < 0.01:
                continue
            bm = bm_box((xb - xa, 0.012, zb - za), (sx * (xa + xb) * 0.5, yd, (za + zb) * 0.5))
            _add(parts, "door_card", bone, bm, "interior")
    # ---------------------------------------------------------------- the kit
    yc0 = L * 0.5 - (d0 + 0.95)
    # cylinder rack on the left wall
    n_cyl = 6 if lod == 0 else 4
    xcyl = -(ring(d0 + 1.2)[0][0] - 0.12)
    for k in range(n_cyl):
        y = yc0 - k * 0.2
        _add(parts, "kit", "body", bm_cyl(0.09, 0.09, 0.62, 16 if lod == 0 else 8, 'Z', (xcyl, y, zf + 0.33)), "kit_yellow")
        _add(parts, "kit", "body", bm_cyl(0.06, 0.03, 0.06, 10 if lod == 0 else 6, 'Z', (xcyl, y, zf + 0.67)), "kit_yellow")
        _add(parts, "kit", "body", bm_cyl(0.022, 0.022, 0.07, 8, 'Z', (xcyl, y, zf + 0.73)), "chrome")
        _add(parts, "kit", "body", bm_box((0.05, 0.03, 0.03), (xcyl + 0.03, y, zf + 0.75)), "trim")
        _add(parts, "kit", "body", bm_cyl(0.093, 0.093, 0.06, 16 if lod == 0 else 8, 'Z', (xcyl, y, zf + 0.04)), "rubber")
    for zz in (zf + 0.3, zf + 0.55):
        _add(parts, "kit", "body", bm_tube((xcyl - 0.1, yc0 + 0.12, zz), (xcyl - 0.1, yc0 - (n_cyl - 1) * 0.2 - 0.12, zz), 0.012, 6), "metal")
    # shelf with cases above the cylinders
    zsh = zf + 1.05
    xsh = xcyl + 0.04            # shelf and cases kept inside the lining (it leans in above the belt)
    _add(parts, "kit", "body", bm_box((0.3, 1.5, 0.02), (xsh, yc0 - 0.5, zsh)), "metal")
    for k, (ww, hh) in enumerate(((0.32, 0.22), (0.3, 0.18), (0.32, 0.26))):
        _add(parts, "kit", "body", bm_rbox((0.26, 0.42, hh), 0.015, 1, (xsh, yc0 + 0.05 - k * 0.5, zsh + 0.01 + hh * 0.5)),
             "trim_grey" if k != 1 else "kit_yellow")
    # bench on the right behind the sliding door, drysuits and fins on it
    xb_in = ring(d0 + 0.6)[0][0]
    yb0 = L * 0.5 - (d0 + 0.15); yb1 = L * 0.5 - (d0 + 1.05)
    _add(parts, "kit", "body", bm_box((0.38, yb0 - yb1, 0.42), (xb_in - 0.19, (yb0 + yb1) * 0.5, zf + 0.21)), "trim_grey")
    _add(parts, "kit", "body", bm_rbox((0.36, yb0 - yb1 - 0.02, 0.06), 0.02, 1, (xb_in - 0.19, (yb0 + yb1) * 0.5, zf + 0.45)), "seat")
    for k in range(2):
        y = yb0 - 0.25 - k * 0.42
        suit = bm_rbox((0.3, 0.34, 0.12), 0.05, 2 if lod == 0 else 1, (xb_in - 0.2, y, zf + 0.54))
        _add(parts, "kit", "body", suit, "canvas")
    for k in range(2):
        fin = bm_rbox((0.2, 0.55, 0.02), 0.01, 1, (xb_in - 0.22 + k * 0.03, yb1 + 0.35, zf + 0.49 + k * 0.025))
        _add(parts, "kit", "body", fin, "trim")
    # crates and a coil of rope at the back right, over the wheel box
    yr = L * 0.5 - (cfg["rear_arch"][0])
    xr_in = cfg["rear_arch"][2]
    for k, mat in enumerate(("kit_yellow", "trim_grey")):
        _add(parts, "kit", "body", bm_rbox((0.42, 0.55, 0.3), 0.02, 1, (xr_in - 0.24, yr + 0.3 - k * 0.6, zf + 0.15)), mat)
    rope = bmesh.new()
    bmesh.ops.create_cone(rope, cap_ends=False, segments=14 if lod == 0 else 8, radius1=0.2, radius2=0.2, depth=0.1)
    bmesh.ops.translate(rope, vec=V((-0.25, yr - 0.6, zf + 0.05)), verts=rope.verts)
    _add(parts, "kit", "body", rope, "flag_b")
    rope2 = bmesh.new()
    bmesh.ops.create_cone(rope2, cap_ends=True, segments=14 if lod == 0 else 8, radius1=0.12, radius2=0.12, depth=0.1)
    bmesh.ops.translate(rope2, vec=V((-0.25, yr - 0.6, zf + 0.05)), verts=rope2.verts)
    _add(parts, "kit", "body", rope2, "trim")


def _dive_van():
    L, W, H = 5.93, 2.02, 2.50
    wb, fo = 3.66, 0.98
    R = tyre(235, 65, 16)
    rc = van("police_dive_van_a", L, W, H, wb, fo, R, (0.93, 0.93, 0.91), "CORVAN", rear_glass=True, slide=True,
             cond=lambda co, n: 0.95, paint2=(0.05, 0.12, 0.38),
             body_over={"cap_glass": [{"front": False, "r0": R_GL0, "r1": R_CANT, "x0": 0.07, "x1": 0.6}]})
    # door stations as van() works them out
    cowl_d = 0.82
    d_a = cowl_d + 0.12
    d_b = d_a + 0.95
    d_c = d_b + 1.0
    lv = police_livery(L, 0.62, L - 0.12, 0.95, band=0.22)      # starts behind the nose's curve
    d = rc["detail"]
    d["strips"] = lv["strips"]
    d["lightbar"] = {"d": 1.72, "style": "modern", "w": 1.35}
    d["aerial"] = {"d": 2.0, "x": 0.35}
    d["lettering"] = [
        {"text": "HALLOWAY PROVINCIAL POLICE", "d": 3.78, "z": 0.95, "size": 0.085, "mat": "sheet_white", "off": 0.0046},
        {"text": "UNDERWATER SEARCH AND RECOVERY", "d": 3.78, "z": 1.33, "size": 0.062, "mat": "lettering2"},
        {"text": "DIVE UNIT", "d": 3.7, "z": 1.66, "size": 0.2, "mat": "lettering2"},
        {"text": "POLICE", "d": 1.42, "z": 0.95, "size": 0.085, "mat": "sheet_white", "off": 0.0046},
    ]
    d.pop("badge", None)          # the marque goes on with the other rear lettering (reads left to right from behind)
    rc["mat_colours"] = {"lettering2": (0.05, 0.12, 0.38), "lettering": (0.95, 0.76, 0.1), "sheet_white": (0.92, 0.92, 0.9),
                         "flag_a": (0.78, 0.06, 0.05), "kit_yellow": (0.88, 0.62, 0.05), "canvas": (0.035, 0.035, 0.04),
                         "wood": (0.5, 0.38, 0.24), "flag_b": (0.9, 0.62, 0.1)}
    rc["interior"]["d_end"] = d_b + 0.12
    ra = R[0] + 0.05
    rax = fo + wb
    cfg = {"rack": (1.98, L - 0.1), "floor": 0.5, "cargo": (d_b + 0.13,), "slide": (d_b + 0.06, d_c),
           "rear_arch": (rax, ra + 0.06, 0.6, 0.86), "rear_win_x1": 0.6}
    rc["extras"].append(van_dressing(cfg))
    # the flag's bone at the foot of its staff (the rear left corner of the rack), pointing up the staff
    zr = H + 0.11
    fx = -(W * 0.5 - 0.15 - 0.05 - 0.02)
    fy = -L * 0.5 + 0.1 + 0.22
    rc["bones_extra"] = [{"name": "dive_flag", "head": (fx, fy, zr - 0.02), "tail": (fx, fy, zr + 0.3), "parent": "body"}]
    rc["dirt"] = 0.3
    return rc


add(_dive_van())
