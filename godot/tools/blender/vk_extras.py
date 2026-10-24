# AeroSim vehicle kit: extra pieces that some recipes add after the body: chrome or black bumpers on older cars, a pickup
# bed, a van's box body, broken glass, stickers, spotlights, push bars, roof signs, rain gutters. Each is a function
# returning a closure extra(parts, spec, surf, lod, info) that appends Parts.
import bmesh, math
from mathutils import Vector as V, Matrix
from vk_core import Part, bm_rbox, bm_box, bm_cyl, bm_tube, bm_sweep, decal, rounded_rect, text_bm, material, Surface
from vk_body import BodySpec, Body, section, cut_arches, R_SH, R_BELT, R_CANT, R_TOP, R_SILL, R_LOW, R_MID, R_GL0
import vk_details as det


def _add(parts, name, bone, bm, mat):
    for q in parts:
        if q.name == name and q.bone == bone:
            q.add_bm(bm, mat); bm.free(); return
    p = Part(name, bone)
    p.add_bm(bm, mat)
    parts.append(p)
    bm.free()


def bumpers(front_z, rear_z, h=0.13, depth=0.12, mat="chrome", wrap=0.38, ends="trim", proud=0.05, rub=True):
    """Separate bumper bars (1970s-80s): a bar across the nose and tail, wrapping round the corners, with rubber strips."""
    def ex(parts, s, surf, lod, info):
        for front, z in ((True, front_z), (False, rear_z)):
            if z is None:
                continue
            y0 = s.L * 0.5 if front else -s.L * 0.5
            sg = 1.0 if front else -1.0
            # the path round the end in plan: along x at the face, bending back at the corners
            path = []
            n = 14 if lod == 0 else 6
            hw = s.W * 0.5 + 0.01
            for k in range(n + 1):
                t = -1.0 + 2.0 * k / n
                x = t * hw
                # bend back over the outer `wrap` metres
                e = max(0.0, abs(x) - (hw - wrap)) / wrap
                yb = y0 + sg * (proud - 0.02 * t * t) - sg * (e ** 2) * wrap * 0.9
                xb = x - math.copysign(e ** 2 * 0.06, x)
                path.append((xb, yb, z))
            sec = [(-depth * 0.5, -h * 0.5), (depth * 0.5, -h * 0.5), (depth * 0.5, h * 0.5), (-depth * 0.5, h * 0.5)]
            bm = bm_sweep(sec, path, True, up=(0, 0, 1))
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.012, segments=1 if lod == 0 else 0, affect='EDGES', clamp_overlap=True) if lod == 0 else None
            _add(parts, "bumpers", "body", bm, mat)
            if rub and lod <= 1:
                path2 = [(p[0] * 0.98, p[1] + sg * 0.004, p[2] - 0.005) for p in path]
                bm2 = bm_sweep([(-0.01, -0.022), (0.01, -0.022), (0.01, 0.022), (-0.01, 0.022)], path2, True, up=(0, 0, 1))
                # push it out to the bar's face
                for v in bm2.verts:
                    v.co.y += sg * depth * 0.5
                _add(parts, "bumpers", "body", bm2, "trim")
            # brackets back to the body
            for sx in (-0.45, 0.45):
                bb = bm_box((0.06, proud + 0.04, 0.05), (sx * s.W, y0 + sg * (proud * 0.5 - 0.02), z))
                _add(parts, "bumpers", "body", bb, "trim")
    return ex


def broken_glass(bone="tailgate", centre=(0.15, 1.15), radius=0.32, seed=3):
    """A smashed rear window: the glass of that panel holed in a ragged outline with shards left at the edge."""
    def ex(parts, s, surf, lod, info):
        import random
        rnd = random.Random(seed)
        for p in parts:
            if p.bone != bone or "glass" not in p.mats:
                continue
            gi = p.mats.index("glass")
            kill = []
            for f in p.bm.faces:
                if f.material_index != gi:
                    continue
                c = f.calc_center_median()
                ang = math.atan2(c.z - centre[1], c.x - centre[0])
                rr = radius * (0.75 + 0.35 * math.sin(ang * 5 + seed) + 0.15 * math.sin(ang * 13))
                if math.hypot(c.x - centre[0], c.z - centre[1]) < rr:
                    kill.append(f)
            bmesh.ops.delete(p.bm, geom=kill, context='FACES_ONLY')
            # a few hanging shards
            if lod == 0:
                for k in range(9):
                    a = rnd.uniform(0, math.tau)
                    r0 = radius * rnd.uniform(0.75, 1.0)
                    x, z = centre[0] + math.cos(a) * r0, centre[1] + math.sin(a) * r0
                    hit = surf.project([(x, z)], 'rear', 0.002)[0]
                    if not hit:
                        continue
                    loc, n = hit
                    t = V((-math.sin(a), 0, math.cos(a)))
                    rad = V((math.cos(a), 0, math.sin(a)))
                    tip = loc - rad * rnd.uniform(0.05, 0.12)
                    bm = bmesh.new()
                    vs = [bm.verts.new(loc + t * 0.03), bm.verts.new(loc - t * 0.03), bm.verts.new(tip)]
                    bm.faces.new(vs)
                    bm.normal_update()
                    for f in bm.faces:
                        if f.normal.dot(n) < 0:
                            f.normal_flip()
                    p.add_bm(bm, "glass")
                    bm.free()
            break
    return ex


def sticker(text, side, d, z, w=0.12, h=0.12, mat="lettering", bg="paint2", bone=None):
    """A square sticker on the side glass or body, with lettering (the tow sticker)."""
    def ex(parts, s, surf, lod, info):
        if lod > 1:
            return
        plane = 'right' if side > 0 else 'left'
        y = s.L * 0.5 - d
        b = decal(surf, lambda u, v: (y - w * 0.5 + w * u, z - h * 0.5 + h * v), plane, 2, 2, 0.003, 0.001, None, rim=False)
        bn = bone or "body"
        _add(parts, "sticker", bn, b, bg)
        if lod == 0:
            pt = Part("sticker_t", bn)
            import vk_core
            for li, line in enumerate(text.split("\n")):
                vk_core.text_on_side(surf, line, side, y, z + h * 0.18 - li * h * 0.32, h * 0.2, mat, pt, offset=0.0045)
            parts.append(pt)
    return ex


def spotlight(side=-1, d=None, chrome=True):
    """An A-pillar spotlight (older police cars)."""
    def ex(parts, s, surf, lod, info):
        dd = d if d is not None else s.windscreen[0] + 0.08
        P = section(s, dd)
        x = side * (P[R_BELT][0] + 0.02)
        z = P[R_BELT][1] + 0.12
        y = s.L * 0.5 - dd
        body = bm_cyl(0.075, 0.06, 0.13, 16 if lod == 0 else 8, 'Y', (x + side * 0.05, y + 0.02, z + 0.05))
        _add(parts, "spot", "body", body, "chrome" if chrome else "trim")
        lens = bm_cyl(0.068, 0.068, 0.006, 16 if lod == 0 else 8, 'Y', (x + side * 0.05, y + 0.09, z + 0.05))
        _add(parts, "spot", "body", lens, "lamp_front")
        arm = bm_tube((x, y, z - 0.05), (x + side * 0.05, y + 0.0, z + 0.03), 0.012, 6)
        _add(parts, "spot", "body", arm, "chrome")
    return ex


def push_bar(z0=0.35, z1=0.85, w=0.9):
    """A black push bar on the front (police SUV)."""
    def ex(parts, s, surf, lod, info):
        y = s.L * 0.5 + 0.06
        for sx in (-1, 1):
            up = bm_tube((sx * w * 0.5, y, z0), (sx * w * 0.5, y + 0.02, z1), 0.022, 8)
            _add(parts, "pushbar", "body", up, "trim")
        for z in (z0 + 0.12, z1 - 0.05):
            bar = bm_tube((-w * 0.5, y + 0.01, z), (w * 0.5, y + 0.01, z), 0.02, 8)
            _add(parts, "pushbar", "body", bar, "trim")
        pad = bm_rbox((w * 0.6, 0.05, 0.12), 0.015, 1, (0, y + 0.03, (z0 + z1) * 0.5))
        _add(parts, "pushbar", "body", pad, "rubber")
    return ex


def gutters(mat="chrome"):
    """Rain gutters along the roof edge (older cars)."""
    def ex(parts, s, surf, lod, info):
        if lod > 1:
            return
        d0, d1 = s.windscreen[0] + 0.12, (s.backlight[0] if s.backlight else s.L - 0.3) + 0.05
        for sx in (1, -1):
            path = []
            for k in range(13):
                d = d0 + (d1 - d0) * k / 12
                P = section(s, d)
                path.append((sx * (P[R_CANT][0] + 0.012), s.L * 0.5 - d, P[R_CANT][1] - 0.01))
            bm = bm_sweep([(-0.006, -0.009), (0.006, -0.009), (0.006, 0.009), (-0.006, 0.009)], path, True)
            _add(parts, "gutters", "body", bm, mat)
    return ex


def aux_body(spec_kw, d_front, bone="body", tub=None, tailgate=None, mats_paint="paint"):
    """A second lofted body behind the first (a pickup bed, a van's box). spec_kw: BodySpec arguments in its own frame
    (d from its own front). tub: (x_inset, z_floor) opens the top as a load bed (black liner)."""
    def ex(parts, s, surf, lod, info):
        import bpy
        from vk_core import Part as P_
        sb = BodySpec(**spec_kw)
        sb.wheel_R = s.wheel_R
        B = Body(sb, lod)
        bm = B.build()
        me = bpy.data.meshes.new("aux")
        bm.to_mesh(me)
        bm.free()
        for m in B.mats:
            me.materials.append(material(m))
        ob = bpy.data.objects.new("aux", me)
        bpy.context.scene.collection.objects.link(ob)
        cut_arches(ob, sb, lod)
        if tub is not None:
            xin, zf = tub[0], tub[1]
            open_back = tub[2] if len(tub) > 2 else False
            cut = bmesh.new()
            L2 = sb.L
            yb = -L2 * 0.5 + (0.0 if open_back else 0.05)
            bmesh.ops.create_cube(cut, size=1.0)
            y0, y1 = (-L2 * 0.5 - 0.3 if open_back else -L2 * 0.5 + 0.05), L2 * 0.5 - 0.05
            for v in cut.verts:
                v.co = V((v.co.x * (sb.W - 2 * xin), (y0 + y1) * 0.5 + v.co.y * (y1 - y0), zf + 1.5 + v.co.z * 3.0))
            cme = bpy.data.meshes.new("tubcut")
            cut.to_mesh(cme)
            cut.free()
            cme.materials.append(material("trim"))
            co = bpy.data.objects.new("tubcut", cme)
            bpy.context.scene.collection.objects.link(co)
            mod = ob.modifiers.new("tub", 'BOOLEAN')
            mod.operation = 'DIFFERENCE'; mod.solver = 'EXACT'; mod.object = co
            try:
                mod.material_mode = 'TRANSFER'
            except Exception:
                pass
            dg = bpy.context.evaluated_depsgraph_get()
            nme = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
            ob.modifiers.clear()
            old = ob.data; ob.data = nme; bpy.data.meshes.remove(old)
            bpy.data.objects.remove(co); bpy.data.meshes.remove(cme)
        dy = (s.L * 0.5 - d_front) - sb.L * 0.5
        bm2 = bmesh.new()
        bm2.from_mesh(ob.data)
        bmesh.ops.transform(bm2, matrix=Matrix.Translation((0, dy, 0)), verts=bm2.verts)
        mats = [m.name for m in ob.data.materials]
        pt = P_("aux_" + bone, bone)
        pt.add_bm(bm2, keep_mats=mats)
        parts.append(pt)
        info.setdefault("aux_surf", []).append(bm2.copy())
        bm2.free()
        dme = ob.data
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(dme)
        if tailgate is not None:
            # a tailgate panel at the open back, hinged at its bottom edge
            zt0, zt1, xw = tailgate
            yb = (s.L * 0.5 - d_front) - sb.L + 0.02
            tg = bm_rbox((xw, 0.05, zt1 - zt0), 0.012, 1, (0, yb, (zt0 + zt1) * 0.5))
            _add(parts, "tailgate", "tailgate", tg, mats_paint)
            info["tailgate_hinge"] = (0, yb, zt0)
    return ex
