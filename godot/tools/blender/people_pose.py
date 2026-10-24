# Posing for the people rig (Godot humanoid bone names). A pose is a dict of joint angles in degrees, described in body
# terms (swing forward, out to the side, flex), turned into bone rotations here. Used by people_anims.py to key clips.
#
# Frame (Blender, before glTF export): the person faces -Y, up is +Z, their left is +X.
# Keys (l/r versions for limbs):
#   hips: (x, y, z) metres offset          hips_rot: (pitch fwd, yaw left, roll left)
#   spine / neck / head: (pitch fwd, yaw left, bend left), spine is spread over Spine, Chest, UpperChest
#   shoulder_l: (raise, forward)           arm_l: (swing fwd, out to side, twist)   elbow_l: flex   bend_l: (x,y,z) elbow bend dir
#   wrist_l: (flex to palm, toward thumb, twist)   fingers_l: curl 0..1   thumb_l: curl 0..1   index_l: curl override
#   leg_l: (swing fwd, out to side, twist) knee_l: flex   foot_l: toes up (deg, from flat)   toes_l: toes bend up
#   ground: list of contact points to keep on the floor ("feet", "knees") or None
import bpy, math
from mathutils import Vector, Quaternion, Matrix, Euler

FWD = Vector((0, -1, 0))
UP = Vector((0, 0, 1))
FINGERS = ("Index", "Middle", "Ring", "Little")

def eul(p, y, s):
    """pitch forward, yaw left, bend left (degrees) as a quaternion in body axes."""
    return (Quaternion((0, 0, 1), math.radians(y)) @ Quaternion((0, 1, 0), math.radians(s)) @ Quaternion((1, 0, 0), math.radians(p)))

def limb_dir(swing, out, side):
    """Direction of a limb hanging down, moved out to its side then swung forward. side: +1 left, -1 right."""
    d = Vector((0, 0, -1))
    d = Quaternion((0, 1, 0), -side * math.radians(out)) @ d
    d = Quaternion((1, 0, 0), -math.radians(swing)) @ d
    return d.normalized()

class Poser:
    def __init__(self, arm):
        self.arm = arm
        self.bones = arm.data.bones
        self.rest = {b.name: b.matrix_local.to_quaternion() for b in self.bones}
        self.rest_dir = {b.name: (b.tail_local - b.head_local).normalized() for b in self.bones}
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
        self.total = {}
        # finger curl sign and palm normal per side, from the rest geometry
        self.curl_sign = {}
        for S in ("Left", "Right"):
            h = self.bones[S + "Hand"]
            lat = self.bones[S + "IndexProximal"].head_local - self.bones[S + "LittleProximal"].head_local
            n = self.rest_dir[S + "Hand"].cross(lat).normalized()
            knuck = (self.bones[S + "IndexProximal"].head_local + self.bones[S + "LittleProximal"].head_local) / 2
            thumb_tip = self.bones[S + "ThumbDistal"].tail_local
            if n.dot(thumb_tip - knuck) < 0:
                n = -n
            self.palm = getattr(self, "palm", {})
            self.palm[S] = n
            b = self.bones[S + "MiddleProximal"]
            ax = b.matrix_local.to_3x3().col[0]
            tip = b.tail_local - b.head_local
            moved = Quaternion(ax, 0.5) @ tip
            self.curl_sign[S] = 1.0 if (moved - tip).dot(n) > 0 else -1.0

    # -------------------------------------------------------------- low level
    def parent_total(self, name):
        b = self.bones[name]
        q = Quaternion()
        while b.parent is not None:
            if b.parent.name in self.total:
                return self.total[b.parent.name]
            b = b.parent
        return q

    def set_total(self, name, R):
        """Give a bone an armature-space rotation R relative to its rest (R=identity: rest)."""
        Rp = self.parent_total(name)
        M = self.rest[name]
        local = M.inverted() @ Rp.inverted() @ R @ M
        self.arm.pose.bones[name].rotation_quaternion = local
        self.total[name] = R

    def set_rel(self, name, Q):
        """Rotate a bone by Q (body axes) on top of its parent's rotation."""
        self.set_total(name, self.parent_total(name) @ Q)

    def aim(self, name, target_dir, twist=0.0, base=None):
        """Point a bone at target_dir (armature space) with the smallest swing from where its parent carried it."""
        Rp = self.parent_total(name) if base is None else base
        cur = Rp @ self.rest_dir[name]
        R = cur.rotation_difference(target_dir) @ Rp
        if twist:
            R = Quaternion(target_dir, math.radians(twist)) @ R
        self.set_total(name, R)

    def local_axis(self, name, axis_idx, angle_deg):
        """Rotate a bone about one of its own rest axes (0=x, 1=y along the bone, 2=z), on top of its parent."""
        Rp = self.parent_total(name)
        ax = self.rest[name].to_matrix().col[axis_idx]
        self.set_total(name, Rp @ Quaternion(ax, math.radians(angle_deg)))

    # -------------------------------------------------------------- the pose
    def reset(self):
        for pb in self.arm.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = Vector()
            pb.scale = Vector((1, 1, 1))
        self.total = {}

    def apply(self, P):
        self.reset()
        pose_hips = Vector(P.get("hips", (0, 0, 0)))
        if P.get("hips_z") is not None:
            pose_hips.z = P["hips_z"] - (self.arm.matrix_world @ self.bones["Hips"].head_local).z
        self.set_total("Hips", eul(*P.get("hips_rot", (0, 0, 0))))
        sp = P.get("spine", (0, 0, 0))
        for nm, k in (("Spine", 0.3), ("Chest", 0.35), ("UpperChest", 0.35)):
            self.set_rel(nm, eul(sp[0] * k, sp[1] * k, sp[2] * k))
        self.set_rel("Neck", eul(*P.get("neck", (0, 0, 0))))
        self.set_rel("Head", eul(*P.get("head", (0, 0, 0))))
        for S, s, side in (("Left", "l", 1.0), ("Right", "r", -1.0)):
            sh = P.get("shoulder_" + s, (0, 0))
            self.set_rel(S + "Shoulder", Quaternion((0, 0, 1), -side * math.radians(sh[1])) @ Quaternion((0, 1, 0), -side * math.radians(sh[0])))
            chest = self.total["UpperChest"]
            a = P.get("arm_" + s, (0, 10, 0))
            U = chest @ limb_dir(a[0], a[1], side)
            self.aim(S + "UpperArm", U, side * a[2])
            fl = math.radians(P.get("elbow_" + s, 10))
            bend = Vector(P.get("bend_" + s, (0, -1, 0.25)))
            bend = chest @ bend
            W = (bend - U * bend.dot(U))
            if W.length < 1e-4:
                W = chest @ Vector((0, -1, 0))
            W.normalize()
            F = (U * math.cos(fl) + W * math.sin(fl)).normalized()
            self.aim(S + "LowerArm", F, side * P.get("forearm_twist_" + s, 0))
            wr = P.get("wrist_" + s, (0, 0, 0))
            self.local_axis(S + "Hand", 0, wr[0] * self.curl_sign[S])
            if wr[1]:
                self.local_axis(S + "Hand", 2, wr[1] * side)
                self.total[S + "Hand"] = self.total[S + "Hand"]
            if wr[2]:
                Rp = self.total[S + "Hand"]
                axis = Rp @ self.rest_dir[S + "Hand"]
                self.set_total(S + "Hand", Quaternion(axis, math.radians(wr[2] * side)) @ Rp)
            cu = P.get("fingers_" + s, 0.15)
            for f in FINGERS:
                c = P.get(f.lower() + "_" + s, cu)
                for j, k in (("Proximal", 1.0), ("Intermediate", 1.15), ("Distal", 0.8)):
                    self.local_axis(S + f + j, 0, self.curl_sign[S] * c * 80 * k)
            th = P.get("thumb_" + s, 0.2)
            for j, k in (("Metacarpal", 0.4), ("Proximal", 0.8), ("Distal", 0.9)):
                self.local_axis(S + "Thumb" + j, 0, self.curl_sign[S] * th * 55 * k)
            # legs
            hips = self.total["Hips"]
            l = P.get("leg_" + s, (0, 3, 0))
            T = hips @ limb_dir(l[0], l[1], side)
            self.aim(S + "UpperLeg", T, side * l[2])
            kn = math.radians(P.get("knee_" + s, 3))
            hinge = hips @ Quaternion((0, 0, 1), math.radians(side * l[2])) @ Vector((1, 0, 0))
            hinge = (hinge - T * hinge.dot(T)).normalized()
            Sh = (Quaternion(hinge, kn) @ T).normalized()
            self.aim(S + "LowerLeg", Sh)
            ft = P.get("foot_" + s, 0)
            yaw = Quaternion((0, 0, 1), math.radians(P.get("hips_rot", (0, 0, 0))[1] + l[2] * side * 0.5))
            if P.get("foot_follow_" + s):
                Rf = self.total[S + "LowerLeg"] @ Quaternion((1, 0, 0), -math.radians(ft))
            else:
                Rf = yaw @ Quaternion((1, 0, 0), -math.radians(ft))
            self.set_total(S + "Foot", Rf)
            self.local_axis(S + "Toes", 0, -P.get("toes_" + s, 0))
        # hips location (bone-local)
        M = self.rest["Hips"].to_matrix()
        self.arm.pose.bones["Hips"].location = M.inverted() @ Vector(pose_hips)
        bpy.context.view_layer.update()
        g = P.get("ground", ["feet"])
        if g:
            dz = self.ground_error(g)
            off = Vector(pose_hips) - Vector((0, 0, dz))
            self.arm.pose.bones["Hips"].location = M.inverted() @ off
            bpy.context.view_layer.update()

    def ground_error(self, kinds):
        """How far the lowest contact point is above (positive) the floor, compared with the rest pose."""
        a = self.arm
        mw = a.matrix_world
        errs = []
        for S in ("Left", "Right"):
            if "feet" in kinds:
                pts = [(a.pose.bones[S + "Foot"].head, self.bones[S + "Foot"].head_local),
                       (a.pose.bones[S + "Toes"].tail, self.bones[S + "Toes"].tail_local),
                       (a.pose.bones[S + "Toes"].head, self.bones[S + "Toes"].head_local)]
                # heel: below the ankle by the rest ankle height
                for pp, rp in pts:
                    errs.append((mw @ pp).z - (mw @ rp).z)
            if "knees" in kinds:
                k = a.pose.bones[S + "LowerLeg"].head
                errs.append((mw @ k).z - 0.06)
            if "toes" in kinds:
                errs.append((mw @ a.pose.bones[S + "Toes"].tail).z - (mw @ self.bones[S + "Toes"].tail_local).z)
        return min(errs)
