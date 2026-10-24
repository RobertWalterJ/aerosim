"""Architectural parts for bldg_lib: shell walls with openings, sash and casement windows, panelled doors, quoins and
bands, pitched roofs (slate or corrugated) with fascia, soffit, bargeboards, ridge tiles, gutters and downpipes, chimney
stacks with corbelling, flashing and pots, shopfronts with fascia lettering and awnings, grime streaks.

Dimensions follow British and Ontario small-town practice: 75 mm brick courses, 2.8 m ground and 2.6 m first storeys,
sash windows about 0.9 x 1.6 m set 100 mm back in the reveal, stone sills 75 mm deep projecting 50 mm, 300 mm eaves,
200 mm verges, 112 mm half-round gutters, 68 mm downpipes, chimney stacks two bricks by one and a half with clay pots."""
import math, bpy
from mathutils import Vector
from bldg_lib import V, UP, G, prism_obj, box_obj, bisect_y, boolean_cut, text_obj, text_width, mesh_obj

WHITE = (0.90, 0.89, 0.85)
CREAM = (0.88, 0.83, 0.70)
IRON = (0.08, 0.085, 0.09)
LEAD = (0.42, 0.44, 0.45)
CLAY = (0.66, 0.36, 0.24)
STONE = (0.86, 0.82, 0.72)
SLATE = (0.80, 0.82, 0.86)
GLASS = (1.0, 1.0, 1.0)
INTERIOR = (0.58, 0.55, 0.50)
BRASS = (0.78, 0.62, 0.30)


def ccw(pts):
    """Orders 4 points counter-clockwise seen from above (+y)."""
    a, b, c = pts[0], pts[1], pts[2]
    if (b - a).cross(c - b).y < 0:
        return list(reversed(pts))
    return pts


class Facade:
    """A wall face: O the outer face at ground at the left end seen from outside, r along it, n outward, L long."""

    def __init__(self, O, r, n, L):
        self.O, self.r, self.n, self.L = Vector(O), Vector(r), Vector(n), L

    def P(self, u, y, d=0.0):
        """u from the middle (+ to the viewer's right), y up, d into the wall (negative stands proud)."""
        return self.O + self.r * (self.L * 0.5 + u) + UP * y - self.n * d

    def axes(self):
        return (self.r, UP, self.n)


def facades(W, D):
    return {
        "front": Facade(V(-W / 2, 0, D / 2), V(1, 0, 0), V(0, 0, 1), W),
        "back": Facade(V(W / 2, 0, -D / 2), V(-1, 0, 0), V(0, 0, -1), W),
        "left": Facade(V(-W / 2, 0, -D / 2), V(0, 0, 1), V(-1, 0, 0), D),
        "right": Facade(V(W / 2, 0, D / 2), V(0, 0, -1), V(1, 0, 0), D),
    }


# ============================================================================ shell
class Shell:
    """Collects the openings; build() makes the hollow walls (with gables) by boolean and reads them into the kit."""

    def __init__(self, kit, W, D, WH, RH, ridge="x", t=0.3, mat="bld_brick", tint=(1, 1, 1), interior=True, gable_mat=None,
                 offset=V(0, 0, 0), y_base=0.0):
        self.kit, self.W, self.D, self.WH, self.RH, self.ridge, self.t = kit, W, D, WH, RH, ridge, t
        self.mat, self.tint, self.interior = mat, tint, interior
        self.off = V(offset[0], offset[1], offset[2])
        self.y_base = y_base
        self.cuts = []      # [facade, u, y0, w, h, shape, depth]
        self.F = facades(W, D)
        for f in self.F.values():
            f.O = f.O + self.off

    def hole(self, side, u, y0, w, h, shape="rect", depth=None):
        self.cuts.append((side, u, y0, w, h, shape, depth))

    def build(self, extra_heights=()):
        W, D, WH, RH, t = self.W, self.D, self.WH, self.RH, self.t
        o, yb = self.off, self.y_base
        if self.ridge == "x":
            # prism_obj's x axis maps the profile's a to -z
            prof = [(-D / 2 - o.z, yb), (D / 2 - o.z, yb), (D / 2 - o.z, WH), (-o.z, WH + RH), (-D / 2 - o.z, WH)] if RH > 0 else [(-D / 2 - o.z, yb), (D / 2 - o.z, yb), (D / 2 - o.z, WH), (-D / 2 - o.z, WH)]
            outer = prism_obj("shell", prof, -W / 2 + o.x, W / 2 + o.x, self.mat, axis="x")
        else:
            prof = [(-W / 2 + o.x, yb), (W / 2 + o.x, yb), (W / 2 + o.x, WH), (o.x, WH + RH), (-W / 2 + o.x, WH)] if RH > 0 else [(-W / 2 + o.x, yb), (W / 2 + o.x, yb), (W / 2 + o.x, WH), (-W / 2 + o.x, WH)]
            outer = prism_obj("shell", prof, -D / 2 + o.z, D / 2 + o.z, self.mat, axis="z")
        cutters = []
        if self.interior:
            cutters.append(box_obj("inner", V(o.x, (WH + RH) * 0.5 + 1.0, o.z), V(W - 2 * t, WH + RH + 4.0, D - 2 * t), "bld_plaster_int"))
        for side, u, y0, w, h, shape, depth in self.cuts:
            F = self.F[side]
            if y0 <= self.y_base + 0.001:
                # an opening down to the ground: start the cutter well below it (coplanar faces upset the boolean)
                h += (y0 - self.y_base) + 0.3; y0 = self.y_base - 0.3
            dd = (depth if depth else t) + 0.4
            if shape == "rect":
                c = F.P(u, y0 + h / 2, dd / 2 - 0.2)
                # box_obj takes game axes and turns them to Blender's (y up -> z); the matrix below then maps the
                # Blender local axes (x, y, z) to (along, up, out), so the size is given as (w, dd, h) here
                ob = box_obj("cut", V(0, 0, 0), V(w, dd, h), self.mat)
                rot = _basis_obj(F.r, UP, F.n)
                ob.matrix_world = _mat4(rot, c)
                cutters.append(ob)
            else:
                prof2 = arch_profile(w, h, shape)
                pts = [(F.P(u + s, y0 + yy, -0.2)) for s, yy in prof2]
                cutters.append(_extrude_obj("cut", pts, -F.n * dd, self.mat))
        boolean_cut(outer, cutters, "cuts")
        # apply the boolean, then cut the result level at a few heights so the weathering in the vertex colour can grade
        # up the wall (cutting before the boolean left coplanar faces that made it skip parts of some openings)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(outer.evaluated_get(dg))
        solid = bpy.data.objects.new("shell_solid", me)
        bpy.context.scene.collection.objects.link(solid)
        solid.matrix_world = outer.matrix_world
        yb = self.y_base
        bisect_y(solid, [h for h in [yb + 0.15, yb + 0.45, yb + 0.9] + list(extra_heights) + [WH - 0.5] if h > yb + 0.01])
        self.kit.take(solid, {self.mat: self.tint, "bld_plaster_int": INTERIOR})
        return outer


def arch_profile(w, h, shape, seg=10):
    """2D outline (s across, y up), counter-clockwise, of an opening whose top is an arch: 'seg' (segmental, rise w/8),
    'round', 'pointed' (an equilateral lancet)."""
    hw = w / 2
    pts = [(-hw, 0.0), (hw, 0.0)]
    if shape == "round":
        spring = h - hw
        pts += [(hw * math.cos(math.pi * k / seg), spring + hw * math.sin(math.pi * k / seg)) for k in range(seg + 1)]
    elif shape == "seg":
        rise = w * 0.125
        spring = h - rise
        R = (hw * hw + rise * rise) / (2 * rise)
        cy = spring + rise - R
        a0 = math.asin(hw / R)
        pts += [(R * math.sin(a0 - 2 * a0 * k / seg), cy + R * math.cos(a0 - 2 * a0 * k / seg)) for k in range(seg + 1)]
    elif shape == "pointed":
        spring = h - w * math.sqrt(3) / 2
        right = [(-hw + w * math.cos(math.radians(60) * k / seg), spring + w * math.sin(math.radians(60) * k / seg)) for k in range(seg + 1)]
        left = [(-x, y) for x, y in reversed(right)]
        pts += right + left[1:]
    return pts


def _basis_obj(r, u, n):
    from mathutils import Matrix
    gr, gu, gn = G(r), G(u), G(n)
    return Matrix(((gr[0], gu[0], gn[0]), (gr[1], gu[1], gn[1]), (gr[2], gu[2], gn[2])))


def _mat4(rot3, c_game):
    from mathutils import Matrix
    M = rot3.to_4x4()
    M.translation = G(c_game)
    return M


def _extrude_obj(name, pts, off, mat):
    """A prism from a planar outline (game points) pushed along off."""
    n = len(pts)
    vs = list(pts) + [p + off for p in pts]
    faces = [(list(range(n - 1, -1, -1)), 0), (list(range(n, 2 * n)), 0)]
    for k in range(n):
        k2 = (k + 1) % n
        faces.append(([k, k2, n + k2, n + k], 0))
    import bmesh
    ob = mesh_obj(name, vs, faces, [mat])
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data); bm.free()
    return ob


# ============================================================================ windows
def sash_window(kit, sh, side, u, y0, w, h, frame=WHITE, panes=(2, 2), head="lintel", reveal=0.10, curtains=True,
                lit=True, sill=True, shape="rect", style="sash", glass_node="body", cut=True, sill_mat="bld_stone",
                head_mat="bld_stone", bars=True):
    """A box-sash window (style 'sash': two sashes, the upper in front), a casement ('case') or a fixed light ('fixed')
    in an opening cut through the shell. panes: (columns, rows) per sash. head: 'lintel' (stone), 'arch' (gauged brick
    segmental arch), 'none'."""
    F = sh.F[side]
    if cut:
        sh.hole(side, u, y0, w, h, shape)
    r, n = F.r, F.n
    ax = (r, UP, n)
    lod = kit.lod
    # stone sill, sloped a little, projecting 50 mm with a drip
    if sill:
        sw = w + 0.22
        c = F.P(u, y0 - 0.04, -0.02 + reveal * 0.0)
        kit.box(F.P(u, y0 - 0.04, (reveal + 0.06) * 0.5 - 0.06), V(sw, 0.08, reveal + 0.06), sill_mat, STONE if sill_mat == "bld_stone" else frame, ax)
    if head == "lintel":
        kit.box(F.P(u, y0 + h + 0.1, -0.012), V(w + 0.3, 0.2, 0.05), head_mat, STONE, ax, skip=("-z",))
    elif head == "arch" and lod < 2:
        _brick_arch(kit, F, u, y0 + h, w, sh.tint)
    elif head == "keystone":
        kit.box(F.P(u, y0 + h + 0.1, -0.012), V(w + 0.3, 0.2, 0.05), head_mat, STONE, ax, skip=("-z",))
        kit.box(F.P(u, y0 + h + 0.13, -0.03), V(0.16, 0.26, 0.05), head_mat, STONE, ax)
    d0 = reveal
    fw = 0.06
    # the box frame: head, jambs, sill
    top = y0 + h
    if shape == "rect":
        kit.box(F.P(u, top - fw / 2, d0 + 0.06), V(w, fw, 0.12), "bld_paint", frame, ax)
        for s in (-1, 1):
            kit.box(F.P(u + s * (w / 2 - fw / 2), y0 + h / 2, d0 + 0.06), V(fw, h, 0.12), "bld_paint", frame, ax)
        kit.box(F.P(u, y0 + 0.03, d0 + 0.05), V(w, 0.06, 0.14), "bld_paint", frame, ax)
        iw, ih = w - 2 * fw, h - fw - 0.06
        ib = y0 + 0.06
    else:
        iw, ih, ib = w - 0.04, h - 0.04, y0 + 0.02
    if style == "sash" and shape == "rect":
        sash_h = ih / 2 + 0.015
        for k, (sy, dz) in enumerate(((ib + ih - sash_h / 2, d0 + 0.035), (ib + sash_h / 2, d0 + 0.08))):
            _sash(kit, F, u, sy, iw, sash_h, dz, frame, panes, upper=(k == 0), bars=bars and lod == 0)
            _glass(kit, F, u, sy, iw - 0.08, sash_h - 0.08, dz, glass_node)
    elif style == "case" and shape == "rect":
        # two side-hung casements with a transom light above
        th = ih * 0.25
        kit.box(F.P(u, ib + ih - th, d0 + 0.06), V(iw, 0.05, 0.06), "bld_paint", frame, ax)
        kit.box(F.P(u, ib + (ih - th) / 2, d0 + 0.06), V(0.05, ih - th, 0.06), "bld_paint", frame, ax)
        for s in (-1, 1):
            _sash(kit, F, u + s * iw / 4, ib + (ih - th) / 2, iw / 2 - 0.02, ih - th, d0 + 0.06, frame, (panes[0], panes[1]), bars=bars and lod == 0)
            _glass(kit, F, u + s * iw / 4, ib + (ih - th) / 2, iw / 2 - 0.1, ih - th - 0.08, d0 + 0.06, glass_node)
        _glass(kit, F, u, ib + ih - th / 2, iw - 0.04, th - 0.05, d0 + 0.06, glass_node)
    else:
        # a fixed light (shop window or church lancet): the glass in the opening's outline, with leading or bars
        if shape == "rect":
            _glass(kit, F, u, ib + ih / 2, iw, ih, d0 + 0.07, glass_node)
            if bars and lod < 2:
                for i in range(1, panes[0]):
                    kit.box(F.P(u - iw / 2 + iw * i / panes[0], ib + ih / 2, d0 + 0.065), V(0.03, ih, 0.04), "bld_paint", frame, ax)
                for j in range(1, panes[1]):
                    kit.box(F.P(u, ib + ih * j / panes[1], d0 + 0.065), V(iw, 0.03, 0.04), "bld_paint", frame, ax)
        else:
            pts = [F.P(u + s, y0 + yy, d0 + 0.07) for s, yy in arch_profile(w, h, shape)]
            acc = kit.nodes[glass_node]
            acc.poly(pts, "bld_glass", GLASS)
            # stone frame round the arch and leaded lights
            prof = arch_profile(w, h, shape)
            for k in range(len(prof)):
                a, b = prof[k], prof[(k + 1) % len(prof)]
                pa, pb = F.P(u + a[0], y0 + a[1], d0 + 0.05), F.P(u + b[0], y0 + b[1], d0 + 0.05)
                _bar(kit, pa, pb, 0.05, 0.08, F.n, "bld_stone", STONE)
            if lod < 2:
                for j in range(1, int(h / 0.45)):
                    yy = y0 + j * 0.45
                    if yy > y0 + h - w * 0.6:
                        break
                    kit.box(F.P(u, yy, d0 + 0.068), V(w - 0.02, 0.012, 0.012), "bld_iron", IRON, ax)
                kit.box(F.P(u, y0 + (h - w * 0.5) / 2, d0 + 0.068), V(0.012, h - w * 0.5, 0.012), "bld_iron", IRON, ax)
    # curtains and a lit room behind (window_light: shown at night)
    if curtains and lod == 0 and shape == "rect":
        cc = kit.rng.choice([(0.55, 0.18, 0.15), (0.75, 0.68, 0.52), (0.22, 0.30, 0.42), (0.82, 0.80, 0.74), (0.35, 0.42, 0.30)])
        for s in (-1, 1):
            cw = w * (0.18 + 0.1 * kit.rng.random())
            kit.box(F.P(u + s * (w / 2 - cw / 2), y0 + h / 2, d0 + 0.32), V(cw, h + 0.1, 0.04), "bld_cloth", cc, ax)
        kit.box(F.P(u, y0 + h + 0.02, d0 + 0.3), V(w + 0.2, 0.04, 0.04), "bld_brass", BRASS, ax)
    if lit:
        acc = kit.node("window_light", V(0, 0, 0))
        hw2, hh2 = w * 0.47, h * 0.47
        cc = F.P(u, y0 + h / 2, d0 + 0.45)
        rr, uu = F.r, UP
        acc.poly([cc - rr * hw2 - uu * hh2, cc + rr * hw2 - uu * hh2, cc + rr * hw2 + uu * hh2, cc - rr * hw2 + uu * hh2], "warm", (1, 1, 1))


def _bar(kit, a, b, wdt, dep, n, mat, tint, node="body"):
    """A square bar from a to b, wdt across (in the wall plane), dep deep along n."""
    d = (b - a)
    L = d.length
    if L < 1e-5:
        return
    d /= L
    s = d.cross(n).normalized()
    kit.box((a + b) * 0.5, V(wdt, L, dep), mat, tint, (s, d, s.cross(d)), node=node)


def _sash(kit, F, u, cy, w, h, d, frame, panes, upper=False, bars=True):
    ax = (F.r, UP, F.n)
    st, rail_t, rail_b = 0.045, 0.045, (0.03 if upper else 0.075)
    if upper:
        rail_t, rail_b = 0.045, 0.03
    else:
        rail_t, rail_b = 0.03, 0.075
    kit.box(F.P(u, cy + h / 2 - rail_t / 2, d), V(w, rail_t, 0.045), "bld_paint", frame, ax)
    kit.box(F.P(u, cy - h / 2 + rail_b / 2, d), V(w, rail_b, 0.045), "bld_paint", frame, ax)
    for s in (-1, 1):
        ext = 0.05 if upper else 0.0     # horns on the upper sash
        kit.box(F.P(u + s * (w / 2 - st / 2), cy - ext / 2, d), V(st, h + ext, 0.045), "bld_paint", frame, ax)
    if bars:
        cols, rows = panes
        iw = w - 2 * st
        ih = h - rail_t - rail_b
        base = cy - h / 2 + rail_b
        for i in range(1, cols):
            kit.box(F.P(u - iw / 2 + iw * i / cols, base + ih / 2, d), V(0.018, ih, 0.03), "bld_paint", frame, ax)
        for j in range(1, rows):
            kit.box(F.P(u, base + ih * j / rows, d), V(iw, 0.018, 0.03), "bld_paint", frame, ax)


def _glass(kit, F, u, cy, w, h, d, node="body"):
    acc = kit.nodes[node] if node in kit.nodes else kit.node(node)
    c = F.P(u, cy, d)
    r = F.r * (w / 2); up = UP * (h / 2)
    acc.poly([c - r - up, c + r - up, c + r + up, c - r + up], "bld_glass", GLASS)


def _brick_arch(kit, F, u, spring, w, tint):
    """A gauged-brick segmental arch over an opening: voussoirs fanned round the arch centre."""
    rise = w * 0.12
    hw = w / 2
    R = (hw * hw + rise * rise) / (2 * rise)
    cy = spring + rise - R
    a0 = math.asin(hw / R)
    nv = max(7, int(w / 0.075) | 1)
    depth = 0.23
    for k in range(nv):
        a = -a0 + (2 * a0) * (k + 0.5) / nv
        dr = V(math.sin(a), math.cos(a), 0)
        rr = F.r * dr.x + UP * dr.y
        c = F.P(u, 0, -0.008) + F.r * (R + depth / 2) * math.sin(a) + UP * (cy + (R + depth / 2) * math.cos(a))
        tang = rr.cross(F.n).normalized()
        wv = 2 * R * math.sin(a0) / nv * 0.93
        kit.box(c, V(wv, depth, 0.05), "bld_brick", tuple(x * (0.93 + 0.08 * (k % 2)) for x in (0.86, 0.62, 0.52)), (tang, rr, F.n), skip=("-z",))


# ============================================================================ doors
def door(kit, sh, side, u, w, h, leaf=(0.12, 0.2, 0.32), frame=WHITE, node="body", pivot=None, open_deg=0.0,
         fanlight=0.4, step=True, surround=None, panels=4, glazed=False, reveal=0.12, step_h=0.15, number=None):
    """A panelled door in a cut opening. The leaf goes in `node` (pivot at the hinge: left jamb as seen from outside);
    open_deg swings it inwards. surround: None, 'pilaster' (a timber doorcase with a cornice hood)."""
    F = sh.F[side]
    ax = (F.r, UP, F.n)
    total_h = h + (fanlight if fanlight else 0.0) + 0.06
    y0 = step_h if step else 0.0
    sh.hole(side, u, y0, w + 0.12, total_h)
    d0 = reveal
    # frame and the transom bar
    for s in (-1, 1):
        kit.box(F.P(u + s * (w / 2 + 0.03), y0 + total_h / 2, d0 + 0.05), V(0.06, total_h, 0.1), "bld_paint", frame, ax)
    kit.box(F.P(u, y0 + total_h - 0.03, d0 + 0.05), V(w + 0.12, 0.06, 0.1), "bld_paint", frame, ax)
    if fanlight:
        kit.box(F.P(u, y0 + h + 0.03, d0 + 0.05), V(w, 0.06, 0.1), "bld_paint", frame, ax)
        _glass(kit, F, u, y0 + h + 0.06 + fanlight / 2, w, fanlight, d0 + 0.06)
        if kit.lod == 0:
            for i in range(1, 3):
                kit.box(F.P(u - w / 2 + w * i / 3, y0 + h + 0.06 + fanlight / 2, d0 + 0.055), V(0.02, fanlight, 0.03), "bld_paint", frame, ax)
    # the leaf: in its own node about the hinge (left jamb seen from outside)
    hinge = F.P(u - w / 2, y0, d0 + 0.02)
    if pivot is not None:
        hinge = pivot
    acc = kit.node(node, hinge) if node != "body" else kit.nodes["body"]
    _leaf(kit, F, u, y0, w, h, d0 + 0.045, leaf, acc, panels, glazed, hinge, open_deg, number)
    if step:
        kit.box(F.P(u, step_h / 2, -0.17), V(w + 0.5, step_h, 0.36 + d0), "bld_stone", STONE, ax)
    # a dark hall inside so the open door shows depth
    kit.box(F.P(u, y0 + 1.2, d0 + 1.6), V(w + 0.6, 2.4, 0.05), "bld_plaster_int", (0.32, 0.29, 0.25), ax)
    if surround == "pilaster":
        for s in (-1, 1):
            kit.box(F.P(u + s * (w / 2 + 0.2), y0 + total_h / 2, -0.03), V(0.16, total_h, 0.08), "bld_paint", frame, ax, skip=("-z",))
            kit.box(F.P(u + s * (w / 2 + 0.2), y0 + 0.12, -0.04), V(0.2, 0.24, 0.1), "bld_paint", frame, ax, skip=("-z",))
        kit.box(F.P(u, y0 + total_h + 0.14, -0.06), V(w + 0.66, 0.26, 0.12), "bld_paint", frame, ax, skip=("-z",))
        kit.box(F.P(u, y0 + total_h + 0.3, -0.1), V(w + 0.8, 0.07, 0.2), "bld_paint", frame, ax, skip=("-z",))
        kit.box(F.P(u, y0 + total_h + 0.345, -0.1), V(w + 0.8, 0.02, 0.2), "bld_lead", LEAD, ax)


def _leaf(kit, F, u, y0, w, h, d, col, acc, panels, glazed, hinge, open_deg, number):
    """Builds the leaf closed, then turns it about the hinge (inwards) if open_deg."""
    from mathutils import Matrix
    start = len(acc.verts)
    nf0 = len(acc.faces)
    ax = (F.r, UP, F.n)
    t = 0.045
    kit.box(F.P(u, y0 + h / 2, d + 0.005), V(w - 0.01, h - 0.01, t - 0.01), "bld_paint", col, ax, node=acc)
    # stiles and rails stand 12 mm proud of the panels
    st, tr, lr, br = 0.11, 0.11, 0.18, 0.2
    pf = -t / 2 - 0.006
    for s in (-1, 1):
        kit.box(F.P(u + s * (w / 2 - st / 2), y0 + h / 2, d + pf), V(st, h, 0.012), "bld_paint", col, ax, node=acc, skip=("-z",))
    kit.box(F.P(u, y0 + h - tr / 2, d + pf), V(w - 2 * st, tr, 0.012), "bld_paint", col, ax, node=acc, skip=("-z",))
    kit.box(F.P(u, y0 + br / 2, d + pf), V(w - 2 * st, br, 0.012), "bld_paint", col, ax, node=acc, skip=("-z",))
    lock_y = y0 + 1.0
    kit.box(F.P(u, lock_y, d + pf), V(w - 2 * st, lr, 0.012), "bld_paint", col, ax, node=acc, skip=("-z",))
    kit.box(F.P(u, y0 + h * 0.72, d + pf), V(0.08, h * 0.5, 0.012), "bld_paint", col, ax, node=acc, skip=("-z",)) if panels >= 4 and not glazed else None
    kit.box(F.P(u, y0 + (br + lock_y - lr / 2) / 2 + 0.0, d + pf), V(0.08, lock_y - lr / 2 - br, 0.012), "bld_paint", col, ax, node=acc, skip=("-z",)) if panels >= 4 else None
    # raised fields in the panels
    if kit.lod == 0:
        pw = (w - 2 * st - 0.08) / 2
        for s in (-1, 1):
            ylo = (y0 + br, lock_y - lr / 2)
            yhi = (lock_y + lr / 2, y0 + h - tr)
            for (a, b) in (ylo,) + (() if glazed else (yhi,)):
                kit.box(F.P(u + s * (pw / 2 + 0.04), (a + b) / 2, d - t / 2 - 0.003), V(pw - 0.07, (b - a) - 0.07, 0.006), "bld_paint", tuple(c * 0.96 for c in col), ax, node=acc, skip=("-z",))
    if glazed:
        a, b = lock_y + lr / 2, y0 + h - tr
        c = F.P(u, (a + b) / 2, d - 0.004)
        acc.poly([c - F.r * (w / 2 - st) - UP * (b - a) / 2, c + F.r * (w / 2 - st) - UP * (b - a) / 2, c + F.r * (w / 2 - st) + UP * (b - a) / 2, c - F.r * (w / 2 - st) + UP * (b - a) / 2], "bld_glass", GLASS)
    # ironmongery: knob, letter plate, knocker, three butt hinges
    if kit.lod == 0:
        kn = F.P(u + w / 2 - 0.08, lock_y, d - t / 2 - 0.03)
        kit.cyl(F.P(u + w / 2 - 0.08, lock_y, d - t / 2), kn, 0.008, 0.008, 6, "bld_brass", BRASS, node=acc)
        kit.lathe(kn - F.n * 0.0, [(0.0, -0.028), (0.026, -0.02), (0.03, 0.0), (0.026, 0.02), (0.0, 0.028)], 10, "bld_brass", BRASS, node=acc) if False else kit.box(kn, V(0.05, 0.05, 0.03), "bld_brass", BRASS, ax, node=acc)
        kit.box(F.P(u, lock_y + 0.0, d - t / 2 - 0.006), V(0.28, 0.075, 0.008), "bld_brass", BRASS, ax, node=acc)
        kit.box(F.P(u, lock_y, d - t / 2 - 0.0105), V(0.22, 0.025, 0.002), "bld_iron", (0.02, 0.02, 0.02), ax, node=acc)
        kc = F.P(u, y0 + 1.45, d - t / 2 - 0.02)
        kit.box(F.P(u, y0 + 1.52, d - t / 2 - 0.01), V(0.06, 0.06, 0.02), "bld_brass", BRASS, ax, node=acc)
        for k in range(10):
            a0, a1 = math.tau * k / 10, math.tau * (k + 1) / 10
            p0 = kc + F.r * (0.05 * math.cos(a0)) + UP * (0.05 * math.sin(a0))
            p1 = kc + F.r * (0.05 * math.cos(a1)) + UP * (0.05 * math.sin(a1))
            kit.cyl(p0, p1, 0.007, 0.007, 5, "bld_brass", BRASS, node=acc, caps=0)
        for y in (0.25, h / 2, h - 0.25):
            kit.box(F.P(u - w / 2 + 0.01, y0 + y, d - t / 2 + 0.01), V(0.02, 0.1, 0.05), "bld_brass", BRASS, ax, node=acc)
    if number and kit.lod == 0:
        ob = text_obj(number, "PlayfairDisplaySC-Bold.ttf", 0.09, 0.004, "bld_brass", F.P(u, y0 + 1.68, d - t / 2 - 0.006), F.n, res=2)
        kit.take(ob, {"bld_brass": BRASS}, node=acc)
    if open_deg:
        a = math.radians(open_deg)
        # inwards: about +y, turning the free edge away from the street
        sgn = 1.0
        rot = Matrix.Rotation(sgn * a, 3, (0, 1, 0))
        # rotation about y in game coords: (x, z) -> (x cos + z sin, -x sin + z cos)
        for i in range(start, len(acc.verts)):
            p = acc.verts[i] - hinge
            # the free edge (+r) must go to -n (indoors): rotate r towards -n
            r, n = F.r, F.n
            pr, pn, py = p.dot(r), p.dot(n), p.y
            ca, sa = math.cos(a), math.sin(a)
            q_r = pr * ca + pn * sa
            q_n = -pr * sa + pn * ca
            acc.verts[i] = hinge + r * q_r + n * q_n + UP * py


# ============================================================================ trim
def quoins(kit, W, D, WH, tint=STONE, mat="bld_stone", course=0.075, long=0.34, short=0.22, proud=0.015):
    """Alternating long and short dressed blocks up each corner, three courses tall, a joint between them."""
    ch = course * 3
    n = int(WH / ch)
    for cx in (-1, 1):
        for cz in (-1, 1):
            corner = V(cx * W / 2, 0, cz * D / 2)
            for k in range(n):
                y = k * ch + ch / 2
                if y + ch / 2 > WH - 0.05:
                    break
                a, b = (long, short) if k % 2 == 0 else (short, long)
                tnt = kit.jit(tint, 0.05)
                # block on the x face (runs along z) and on the z face (runs along x)
                kit.box(corner + V(cx * proud / 2, y, -cz * (b / 2 - proud / 2)), V(proud * 2, ch - 0.012, b + proud), mat, tnt)
                kit.box(corner + V(-cx * (a / 2 - proud / 2), y, cz * proud / 2), V(a + proud, ch - 0.012, proud * 2), mat, tnt)


def band(kit, W, D, y, h, proud, mat, tint, sides=("front", "back", "left", "right"), skip_u=None):
    """A course running round the walls (a plinth, string course or eaves band)."""
    for s in sides:
        if s in ("front", "back"):
            kit.box(V(0, y + h / 2, (1 if s == "front" else -1) * (D / 2 + proud / 2)), V(W + 2 * proud, h, proud), mat, tint, skip=("-z", "+z")[0:0])
        else:
            kit.box(V((1 if s == "right" else -1) * (W / 2 + proud / 2), y + h / 2, 0), V(proud, h, D + 2 * proud), mat, tint)


# ============================================================================ roofs
class Roof:
    """A double-pitched roof over a W x D shell (ridge along x or z), its underside on the wall plates: through the outer
    eave line at WH and the ridge at WH + RH. Overhang `oe` at the eaves, `ov` at the verges, thickness `T` (rafters,
    battens, slates)."""

    def __init__(self, kit, W, D, WH, RH, ridge="x", oe=0.3, ov=0.22, T=0.12, mat="bld_slate", tint=SLATE, offset=V(0, 0, 0)):
        self.kit, self.W, self.D, self.WH, self.RH, self.ridge = kit, W, D, WH, RH, ridge
        self.off = V(offset[0], offset[1], offset[2])
        self.oe, self.ov, self.T, self.mat, self.tint = oe, ov, T, mat, tint
        self.half = (D if ridge == "x" else W) / 2      # across the ridge
        self.length = (W if ridge == "x" else D) / 2    # half along the ridge
        self.th = math.atan2(RH, self.half)

    def g(self, l, y, a):
        """(along the ridge, up, across) -> game"""
        return (V(l, y, a) if self.ridge == "x" else V(a, y, -l)) + self.off

    def under_y(self, a):
        return self.WH + self.RH * (1 - abs(a) / self.half)

    def top_y(self, a):
        return self.under_y(a) + self.T / math.cos(self.th)

    def build(self, strips=4, ridge_tiles=True, fascia=WHITE, barge=WHITE, gutters=True, finial=False, verge_mat="bld_paint",
              holes=()):
        k, T = self.kit, self.T
        L = self.length + self.ov
        tanth = math.tan(self.th)
        a_e = self.half + self.oe
        y_ue = self.WH - self.oe * tanth           # underside at the eave edge
        dy = T / math.cos(self.th)
        for s in (-1, 1):
            # the slab in strips up the slope (each strip a hexahedron with plumb-cut ends)
            for i in range(strips):
                f0, f1 = i / strips, (i + 1) / strips
                a0 = s * (a_e - (a_e) * f0)
                a1 = s * (a_e - (a_e) * f1)
                yu0 = y_ue + (self.WH + self.RH - y_ue) * f0
                yu1 = y_ue + (self.WH + self.RH - y_ue) * f1
                # holes: (side, l0, l1, f0, f1) knock a strip segment out
                segs = [(-L, L)]
                for hs, hl0, hl1, hf0, hf1 in holes:
                    if hs == s and hf0 <= f0 + 1e-6 and hf1 >= f1 - 1e-6:
                        segs = [(lo, hi) for lo, hi in ((-L, hl0), (hl1, L)) if hi - lo > 0.01]
                for (l0, l1) in segs:
                    bot = [self.g(l0, yu0, a0), self.g(l1, yu0, a0), self.g(l1, yu1, a1), self.g(l0, yu1, a1)]
                    top = [p + V(0, dy, 0) for p in bot]
                    bot = ccw(bot); top = ccw(top)
                    tint = k.jit(self.tint, 0.04)
                    if i == 0:
                        tint = tuple(c * 0.9 for c in tint)       # damper, darker at the eaves
                    skip = ()
                    k.hexa(bot, top, self.mat, tint, skip=skip)
            # fascia board on the plumb cut, soffit under the overhang
            ae = s * a_e
            k.box(self.g(0, y_ue + dy / 2 - 0.03, ae + s * 0.012), _sz(self, 2 * L + 0.02, 0.24, 0.025), "bld_paint", fascia, _ax(self))
            ys = self.WH - 0.02
            soffit = [self.g(-L, ys, s * self.half), self.g(L, ys, s * self.half), self.g(L, ys, ae), self.g(-L, ys, ae)]
            k.quad(*ccw(soffit)[::-1], "bld_paint", fascia)
            if gutters:
                self._gutter(s, L, y_ue - 0.02, ae + s * 0.08)
        # ridge: half-round tiles in 330 mm lengths (one long piece at lod 2)
        yr = self.WH + self.RH + dy - 0.02
        if ridge_tiles:
            if k.lod >= 1:
                k.cyl(self.g(-L - 0.02, yr, 0), self.g(L + 0.02, yr, 0), 0.12, 0.12, 8, "bld_clay", (0.42, 0.40, 0.40), caps=3, ang0=0.0, ang1=math.pi) if False else \
                    k.sweep(_half_round(0.12, 0.02, 8), self.g(-L - 0.02, yr, 0), self.g(L + 0.02, yr, 0), UP, "bld_clay", (0.42, 0.40, 0.40))
            else:
                n = max(2, int(2 * L / 0.33))
                for i in range(n):
                    l0 = -L - 0.02 + (2 * L + 0.04) * i / n
                    l1 = -L - 0.02 + (2 * L + 0.04) * (i + 1) / n - 0.006
                    k.sweep(_half_round(0.12, 0.018, 8), self.g(l0, yr, 0), self.g(l1, yr, 0), UP, "bld_clay", k.jit((0.44, 0.42, 0.42), 0.06))
        # bargeboards under the verges, following each pitch
        for e in (-1, 1):
            lb = e * (L - 0.015)
            for s in (-1, 1):
                p_eave = self.g(lb, y_ue - 0.04, s * a_e)
                p_ridge = self.g(lb, self.WH + self.RH - 0.04, 0)
                along = (p_ridge - p_eave)
                Lb = along.length
                d = along.normalized()
                out = self.g(e, 0, 0) - self.g(0, 0, 0)
                side = d.cross(out).normalized()
                c = (p_eave + p_ridge) * 0.5 - side * 0.1 * (1 if side.y > 0 else -1)
                # side should point down-ish so the board hangs below the verge
                down = side if side.y < 0 else -side
                k.box((p_eave + p_ridge) * 0.5 + down * 0.11, V(0.03, Lb, 0.22), verge_mat, barge,
                      _orth(out, d))
            if finial and k.lod < 2:
                tip = self.g(e * (L - 0.015), self.WH + self.RH + dy, 0)
                k.cyl(tip - V(0, 0.4, 0), tip + V(0, 0.35, 0), 0.04, 0.03, 8, verge_mat, barge)
                k.lathe(tip + V(0, 0.35, 0), [(0.0, 0.0), (0.06, 0.02), (0.05, 0.1), (0.0, 0.2)], 8, verge_mat, barge)

    def _gutter(self, s, L, y, a):
        k = self.kit
        if k.lod >= 2:
            return
        prof = _half_round_gutter(0.056, 0.004, 8)
        p0, p1 = self.g(-L, y, a), self.g(L, y, a)
        # the gutter profile is (across, up); its across axis must point away from the wall
        out = self.g(0, 0, s) - self.g(0, 0, 0)
        if UP.cross(p1 - p0).dot(out) < 0:
            p0, p1 = p1, p0          # so the profile's outer bead faces away from the wall
        k.sweep(prof, p0, p1, UP, "bld_iron", IRON)
        if k.lod == 0:
            n = int(2 * L / 0.9)
            for i in range(n + 1):
                l = -L + 2 * L * i / max(n, 1)
                k.box(self.g(l, y - 0.03, a - s * 0.03), _sz(self, 0.025, 0.012, 0.12), "bld_iron", IRON, _ax(self))

    def downpipe(self, l, s, wall_face, ground=0.0, shoe=True):
        """A 68 mm cast-iron downpipe from the gutter at (l along the ridge, side s) down the wall to the ground."""
        k = self.kit
        if k.lod >= 2:
            return
        tanth = math.tan(self.th)
        y_g = self.WH - self.oe * tanth - 0.06
        a_g = s * (self.half + self.oe + 0.08)
        a_w = s * (wall_face + 0.06)
        top = self.g(l, y_g, a_g)
        k1 = self.g(l, y_g - 0.25, a_g)
        k2 = self.g(l, y_g - 0.55, a_w)
        bot = self.g(l, ground + 0.12, a_w)
        r = 0.034
        k.cyl(top, k1, r, r, 10, "bld_iron", IRON, caps=0)
        k.cyl(k1, k2, r, r, 10, "bld_iron", IRON, caps=0)
        k.cyl(k2, bot, r, r, 10, "bld_iron", IRON, caps=1)
        if shoe:
            k.cyl(bot, bot + (self.g(0, 0, s) - self.g(0, 0, 0)) * 0.16 - V(0, 0.08, 0), r, r * 1.1, 10, "bld_iron", IRON)
        if k.lod == 0:
            yy = y_g - 0.8
            while yy > ground + 0.4:
                c = self.g(l, yy, a_w)
                k.cyl(c - V(0, 0.03, 0), c + V(0, 0.03, 0), r + 0.008, r + 0.008, 10, "bld_iron", IRON)
                k.box(self.g(l, yy, s * (wall_face + 0.012)), V(0.03, 0.05, 0.03), "bld_iron", IRON)
                yy -= 1.8


def _sz(roof, l, y, a):
    return V(l, y, a) if roof.ridge == "x" else V(a, y, l)


def _ax(roof):
    return (V(1, 0, 0), V(0, 1, 0), V(0, 0, 1))


def _orth(x, y):
    x = x.normalized(); y = (y - x * y.dot(x)).normalized()
    return (x, y, x.cross(y))


def _half_round(r, t, seg):
    """Closed profile (across, up) of a half-round ridge tile: the outer arc then the inner arc back (CCW)."""
    pts = [(r * math.cos(math.pi * i / seg), r * math.sin(math.pi * i / seg)) for i in range(seg + 1)]
    inner = [((r - t) * math.cos(math.pi * i / seg), (r - t) * math.sin(math.pi * i / seg)) for i in range(seg, -1, -1)]
    return pts + inner


def _half_round_gutter(r, t, seg):
    """A half-round gutter section opening upwards, with a bead on the outer lip."""
    outer = [(r * math.cos(math.pi + math.pi * i / seg), r * math.sin(math.pi + math.pi * i / seg)) for i in range(seg + 1)]
    inner = [((r - t) * math.cos(math.pi + math.pi * i / seg), (r - t) * math.sin(math.pi + math.pi * i / seg)) for i in range(seg, -1, -1)]
    pts = outer + [(r + 0.008, 0.0), (r + 0.008, 0.012), (r - t, 0.012)] + inner[1:]
    # CCW check
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    return pts if area > 0 else list(reversed(pts))


def chimney(kit, roof, x, z, w=0.9, d=0.6, above=1.0, pots=2, tint=(1, 1, 1), mat="bld_brick"):
    """A brick stack rising through the roof at (x, z) to `above` m over the ridge: oversailing courses, a mortar
    flaunching, clay pots and lead flashing where it leaves the slates."""
    k = kit
    ridge_top = roof.WH + roof.RH + roof.T / math.cos(roof.th)
    y0 = roof.WH - 0.3
    y1 = ridge_top + above
    k.box(V(x, (y0 + y1) / 2, z), V(w, y1 - y0, d), mat, tint)
    if k.lod < 2:
        k.box(V(x, y1 - 0.25, z), V(w + 0.08, 0.075, d + 0.08), mat, tint)
        k.box(V(x, y1 - 0.11, z), V(w + 0.14, 0.075, d + 0.14), mat, tint)
    k.box(V(x, y1 + 0.03, z), V(w + 0.02, 0.07, d + 0.02), "bld_concrete", (0.62, 0.6, 0.56))
    # the flaunching: a mortar fillet round the pots
    if k.lod < 2:
        for i in range(pots):
            px = x + (i - (pots - 1) / 2) * (w / max(pots, 1))
            c = V(px, y1 + 0.065, z)
            k.lathe(c, [(0.0, 0.0), (0.16, 0.0), (0.12, 0.08), (0.0, 0.08)], 10, "bld_concrete", (0.6, 0.58, 0.54))
            prof = [(0.11, 0.0), (0.105, 0.08), (0.09, 0.46), (0.1, 0.52), (0.115, 0.56), (0.115, 0.6), (0.085, 0.6), (0.075, 0.2), (0.0, 0.2)]
            k.lathe(c + V(0, 0.04, 0), prof, 12 if k.lod == 0 else 8, "bld_clay", k.jit(CLAY, 0.08))
    # lead flashing: a sloped apron on each pitch round the base of the stack
    for s in (-1, 1):
        for (l0, l1, a0, a1) in [(-w / 2 - 0.1, w / 2 + 0.1, None, None)]:
            pass
    if roof.ridge == "x":
        a_c, l_c, hw, hd = z, x, w / 2, d / 2
    else:
        a_c, l_c, hw, hd = x, -z, d / 2, w / 2
    for s in (-1, 1):
        a_in = a_c + s * hd
        a_out = a_in + s * 0.12
        if abs(a_out) > roof.half:
            continue
        for (aa0, aa1) in ((min(a_in, a_out), max(a_in, a_out)),):
            pts = []
            for l in (l_c - hw - 0.1, l_c + hw + 0.1):
                pass
            yb0, yb1 = roof.top_y(aa0) + 0.006, roof.top_y(aa1) + 0.006
            bot = [roof.g(l_c - hw - 0.1, yb0, aa0), roof.g(l_c + hw + 0.1, yb0, aa0), roof.g(l_c + hw + 0.1, yb1, aa1), roof.g(l_c - hw - 0.1, yb1, aa1)]
            top = [p + V(0, 0.012, 0) for p in bot]
            k.hexa(ccw(bot), ccw(top), "bld_lead", LEAD)
        # side step flashing up the cheeks
        for e in (-1, 1):
            l = l_c + e * (hw + 0.05)
            aa0, aa1 = a_c - hd, a_c + hd
            ya, yb = roof.top_y(aa0), roof.top_y(aa1)
            p0, p1 = roof.g(l, ya + 0.08, aa0), roof.g(l, yb + 0.08, aa1)
            c = (p0 + p1) / 2
            k.box(c, _sz(roof, 0.1, 0.16, 2 * hd), "bld_lead", LEAD) if False else None
    return y1


# ============================================================================ shopfront
def shopfront(kit, sh, u0, u1, title, trim, letter=(0.86, 0.74, 0.42), awning=None, door_u=None, door_w=0.95,
              fascia_y=3.05, font_file="PlayfairDisplaySC-Bold.ttf", goods=None, subtitle=None):
    """A Victorian shopfront between u0 and u1 on the front: pilasters with console brackets, a fascia with real raised
    lettering, a cornice, a panelled stallriser, a display window with mullions and transom lights, a recessed door and
    an awning (striped canvas, scalloped valance, iron arms)."""
    F = sh.F["front"]
    ax = (F.r, UP, F.n)
    k = kit
    W = u1 - u0
    um = (u0 + u1) / 2
    pil = 0.32
    open0, open1 = u0 + pil, u1 - pil
    top = fascia_y - 0.05
    sh.hole("front", (open0 + open1) / 2, 0.0, open1 - open0, top, depth=0.3)
    # pilasters, plinths and capitals; console brackets
    for e, uu in ((-1, u0 + pil / 2), (1, u1 - pil / 2)):
        k.box(F.P(uu, fascia_y / 2, -0.06), V(pil, fascia_y, 0.14), "bld_paint", trim, ax, skip=("-z",))
        k.box(F.P(uu, 0.2, -0.08), V(pil + 0.06, 0.4, 0.18), "bld_paint", trim, ax, skip=("-z",))
        k.box(F.P(uu, fascia_y - 0.12, -0.08), V(pil + 0.05, 0.08, 0.18), "bld_paint", trim, ax, skip=("-z",))
        # a console: an S-scroll seen from the side, 0.6 tall, 0.26 proud
        prof = [(0.0, 0.0), (0.05, 0.0), (0.09, 0.06), (0.12, 0.18), (0.2, 0.38), (0.26, 0.5), (0.27, 0.62), (0.0, 0.62)]
        org = F.P(uu - 0.1, fascia_y - 0.05, 0.0)
        k.slab_poly([(p[0], p[1]) for p in prof], org, F.n, UP, -0.2, "bld_paint", trim) if False else \
            k.slab_poly([(-p[0], p[1]) for p in reversed(prof)], F.P(uu + 0.1, fascia_y - 0.05, 0.0), -F.n, UP, 0.2, "bld_paint", trim)
    # fascia board, its moulded frame, and the cornice above
    fh = 0.62
    fy = fascia_y + fh / 2
    k.box(F.P(um, fy, -0.12), V(W - 0.04, fh, 0.08), "bld_paint", trim, ax)
    for yy in (fascia_y + 0.02, fascia_y + fh - 0.02):
        k.box(F.P(um, yy, -0.165), V(W - 0.1, 0.035, 0.02), "bld_paint", letter if False else tuple(c * 0.8 for c in trim), ax)
    k.box(F.P(um, fascia_y + fh + 0.05, -0.12), V(W + 0.1, 0.1, 0.22), "bld_paint", trim, ax, skip=("-z",))
    k.box(F.P(um, fascia_y + fh + 0.13, -0.15), V(W + 0.2, 0.06, 0.3), "bld_paint", trim, ax, skip=("-z",))
    k.box(F.P(um, fascia_y + fh + 0.165, -0.15), V(W + 0.2, 0.012, 0.3), "bld_lead", LEAD, ax)
    # the lettering: real glyphs, raised 8 mm, centred on the fascia
    if k.lod < 2:
        size = 0.36
        avail = W - 0.9
        wt = text_width(title, font_file, size)
        if wt > avail:
            size *= avail / wt
        ob = text_obj(title, font_file, size, 0.008, "bld_paint", F.P(um, fy - size * 0.36, -0.16), F.n, res=4 if k.lod == 0 else 2)
        k.take(ob, {"bld_paint": letter})
        if subtitle:
            ob2 = text_obj(subtitle, "PTSansNarrow-Bold.ttf", 0.09, 0.005, "bld_paint", F.P(um, fascia_y + 0.05, -0.16), F.n, res=2)
            k.take(ob2, {"bld_paint": letter})
    # stallriser and display window
    du = door_u if door_u is not None else open0 + door_w / 2 + 0.1
    win0, win1 = (du + door_w / 2 + 0.06, open1) if du < um else (open0, du - door_w / 2 - 0.06)
    sr = 0.6
    wm = (win0 + win1) / 2
    ww = win1 - win0
    k.box(F.P(wm, sr / 2, 0.18), V(ww, sr, 0.1), "bld_paint", trim, ax)
    if k.lod == 0:
        for i in range(2):
            pw = ww / 2 - 0.12
            k.box(F.P(win0 + 0.06 + pw / 2 + i * (pw + 0.12), sr / 2, 0.125), V(pw, sr - 0.2, 0.012), "bld_paint", tuple(c * 0.92 for c in trim), ax)
    k.box(F.P(wm, sr + 0.04, 0.14), V(ww + 0.04, 0.08, 0.2), "bld_paint", trim, ax)        # the cill
    tr_y = top - 0.5
    gh = tr_y - sr - 0.08
    _glass(k, F, wm, sr + 0.08 + gh / 2, ww - 0.08, gh, 0.2)
    k.box(F.P(wm, tr_y, 0.2), V(ww, 0.07, 0.1), "bld_paint", trim, ax)
    k.box(F.P(wm, top - 0.03, 0.2), V(ww, 0.06, 0.1), "bld_paint", trim, ax)
    for i in (1, 2):
        k.box(F.P(win0 + ww * i / 3, (sr + top) / 2, 0.2), V(0.06, top - sr, 0.1), "bld_paint", trim, ax)
    for i in range(6):
        _glass(k, F, win0 + ww * (i + 0.5) / 6, (tr_y + top) / 2, ww / 6 - 0.05, top - tr_y - 0.08, 0.21)
        if i % 2 == 1 and k.lod == 0:
            k.box(F.P(win0 + ww * i / 6, (tr_y + top) / 2, 0.2), V(0.03, top - tr_y, 0.06), "bld_paint", trim, ax)
    for s in (-1, 1):
        k.box(F.P(win0 if s < 0 else win1, (sr + top) / 2, 0.2), V(0.08, top - sr, 0.12), "bld_paint", trim, ax)
    # the recessed door: lobby floor (tiles), side linings, a glazed door
    rd = 0.7
    k.box(F.P(du, 0.06, rd / 2 + 0.1), V(door_w + 0.1, 0.12, rd + 0.2), "bld_concrete", (0.42, 0.38, 0.36), ax)
    k.box(F.P(du - door_w / 2 - 0.03, 1.4, rd / 2 + 0.15), V(0.06, 2.8, rd + 0.1), "bld_paint", trim, ax) if du > um else None
    k.box(F.P(du + door_w / 2 + 0.03, 1.4, rd / 2 + 0.15), V(0.06, 2.8, rd + 0.1), "bld_paint", trim, ax) if du < um else None
    _shop_door(k, F, du, door_w, 2.1, rd + 0.18, trim)
    k.box(F.P(du, 2.1 + 0.06 + 0.04, rd + 0.18), V(door_w + 0.1, 0.08, 0.08), "bld_paint", trim, ax)
    _glass(k, F, du, (2.2 + top) / 2, door_w, top - 2.25, rd + 0.18)
    # inside: a back partition with shelves of goods, a counter, a warm light at night
    back = 1.6
    k.box(F.P(um, 1.5, back), V(W - 0.8, 3.0, 0.05), "bld_plaster_int", (0.62, 0.56, 0.46), ax)
    if goods and k.lod == 0:
        goods(k, F, (open0, open1), back)
    acc = k.node("window_light", V(0, 0, 0))
    c = F.P(wm, (sr + top) / 2, back - 0.1)
    acc.poly([c - F.r * (ww / 2) - UP * ((top - sr) / 2), c + F.r * (ww / 2) - UP * ((top - sr) / 2), c + F.r * (ww / 2) + UP * ((top - sr) / 2), c - F.r * (ww / 2) + UP * ((top - sr) / 2)], "warm", (1, 1, 1))
    if awning:
        _awning(k, F, (open0 + open1) / 2, open1 - open0 + 0.1, fascia_y - 0.02, awning, trim)


def _shop_door(k, F, u, w, h, d, trim):
    ax = (F.r, UP, F.n)
    st = 0.1
    k.box(F.P(u, h / 2 + 0.12, d), V(w, h, 0.045), "bld_paint", trim, ax)
    a, b = 1.0, h - 0.12
    c = F.P(u, 0.12 + (a + b) / 2, d - 0.025)
    hw = w / 2 - st
    hh = (b - a) / 2
    k.nodes["body"].poly([c - F.r * hw - UP * hh, c + F.r * hw - UP * hh, c + F.r * hw + UP * hh, c - F.r * hw + UP * hh], "bld_glass", GLASS)
    if k.lod == 0:
        k.box(F.P(u + w / 2 - 0.09, 1.05, d - 0.04), V(0.025, 0.3, 0.025), "bld_brass", BRASS, ax)
        k.box(F.P(u, 0.12 + 0.5, d - 0.026), V(w - 0.25, 0.5, 0.01), "bld_paint", tuple(c * 0.9 for c in trim), ax)


def _awning(k, F, u, w, y, stripes, trim):
    """A retractable canvas blind: the box under the fascia, the canvas sloped 1.3 m out and down, a scalloped valance."""
    ax = (F.r, UP, F.n)
    k.box(F.P(u, y + 0.08, -0.12), V(w, 0.16, 0.18), "bld_paint", trim, ax)
    if k.lod >= 2:
        return
    out, drop = 1.3, 0.5
    n = max(4, int(w / 0.3))
    a0 = F.P(u - w / 2, y, -0.2)
    for i in range(n):
        s0, s1 = w * i / n, w * (i + 1) / n
        col = stripes[i % 2]
        p0 = a0 + F.r * s0; p1 = a0 + F.r * s1
        q0 = p0 + F.n * out - UP * drop; q1 = p1 + F.n * out - UP * drop
        k.quad(p0, p1, q1, q0, "bld_canvas", k.jit(col, 0.02), double=True)
        # valance: two scallops per stripe
        v0, v1 = q0, q1
        mid = (v0 + v1) / 2
        k.quad(v0, v1, v1 - UP * 0.18, v0 - UP * 0.18, "bld_canvas", k.jit(col, 0.02), double=True)
        if k.lod == 0:
            for (aa, bb) in ((v0, mid), (mid, v1)):
                m2 = (aa + bb) / 2 - UP * 0.26
                k.nodes["body"].poly([aa - UP * 0.18, bb - UP * 0.18, m2], "bld_canvas", col)
                k.nodes["body"].poly([m2, bb - UP * 0.18, aa - UP * 0.18], "bld_canvas", col)
    # front rail and folding arms
    e0 = a0 + F.n * out - UP * drop
    k.cyl(e0, e0 + F.r * w, 0.02, 0.02, 8, "bld_iron", IRON)
    if k.lod == 0:
        for s in (0.05, w - 0.05):
            base = F.P(u - w / 2 + s, y - 0.8, -0.02)
            k.cyl(base, a0 + F.r * s + F.n * out - UP * drop, 0.012, 0.012, 6, "bld_iron", IRON)


# ============================================================================ grime
def streak(kit, F, u, y_top, w, h, d=-0.004, alpha=0.55, node="body"):
    """A darker run-off streak on a wall (below a sill or a gutter joint): an alpha decal 4 mm proud."""
    c = F.P(u, y_top - h / 2, d)
    r = F.r * (w / 2); up = UP * (h / 2)
    kit.nodes[node].poly([c - r - up, c + r - up, c + r + up, c - r + up], "bld_grime", (0.16, 0.14, 0.11),
                         uvs=[(0, 0), (1, 0), (1, 1), (0, 1)], alpha=alpha)
