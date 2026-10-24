# The animation clips shared by every person (keyed by people_anims.py onto the male, female and child libraries).
# Each clip: name -> (seconds, function(t) -> pose dict), t runs 0..1 and the clip loops (t=0 and t=1 give the same pose).
import math

TAU = math.tau
def s(t, k=1, ph=0.0):
    return math.sin(TAU * (k * t + ph))
def c(t, k=1, ph=0.0):
    return math.cos(TAU * (k * t + ph))
def pos(x):
    return max(0.0, x)

def base(t, breath=1.0, sway=1.0):
    """Relaxed standing: arms by the sides, soft knees, breathing and a slow sway."""
    b = s(t, 1) * breath
    w = s(t, 1, 0.1) * sway
    return {
        "hips": (0.006 * w, 0, 0), "hips_rot": (0, 1.2 * w, -1.0 * w),
        "spine": (1.5 + 0.8 * b, -0.8 * w, 1.0 * w), "neck": (2 - 0.4 * b, 0, 0), "head": (-2, 1.5 * s(t, 1, 0.3), 0),
        "shoulder_l": (0.8 * b, 0), "shoulder_r": (0.8 * b, 0),
        "arm_l": (3, 8 + 0.6 * b, 8), "arm_r": (3, 8 + 0.6 * b, 8), "elbow_l": 14, "elbow_r": 14,
        "wrist_l": (6, 0, 0), "wrist_r": (6, 0, 0), "fingers_l": 0.28, "fingers_r": 0.28, "thumb_l": 0.25, "thumb_r": 0.25,
        "leg_l": (0, 4, 4), "leg_r": (0, 4, 4), "knee_l": 4 + 2 * pos(w), "knee_r": 4 + 2 * pos(-w),
        "ground": ["feet"],
    }

def idle(t):
    return base(t)

def idle_shift(t):
    # weight onto one leg, then the other
    P = base(t, 1.0, 0.0)
    w = s(t, 1)
    P["hips"] = (0.035 * w, 0, 0)
    P["hips_rot"] = (0, 2 * w, -3.5 * w)
    P["spine"] = (1.5, -1.5 * w, 3.0 * w)
    P["knee_l"] = 3 + 12 * pos(-w); P["knee_r"] = 3 + 12 * pos(w)
    P["leg_l"] = (4 * pos(-w), 3 + 3 * pos(w), 5); P["leg_r"] = (4 * pos(w), 3 + 3 * pos(-w), 5)
    P["foot_l"] = 0; P["foot_r"] = 0
    return P

def walk(t):
    P = base(0, 0.3, 0)
    sw = s(t)
    P["leg_l"] = (24 * sw - 2, 3, 4); P["leg_r"] = (-24 * sw - 2, 3, 4)
    P["knee_l"] = 6 + 55 * pos(c(t)) ** 1.6 + 8 * pos(sw); P["knee_r"] = 6 + 55 * pos(-c(t)) ** 1.6 + 8 * pos(-sw)
    P["foot_l"] = 12 * sw + 8 * pos(c(t)) - 6 * pos(-c(t)) * pos(-sw)
    P["foot_r"] = -12 * sw + 8 * pos(-c(t)) - 6 * pos(c(t)) * pos(sw)
    P["toes_l"] = 25 * pos(-sw) * pos(-c(t)) ; P["toes_r"] = 25 * pos(sw) * pos(c(t))
    P["hips_rot"] = (2, -6 * sw, 2.5 * c(t, 2) * 0)
    P["hips"] = (0.012 * s(t, 1, 0.25), 0, 0)
    P["spine"] = (4, 5 * sw, 0)
    P["head"] = (-3, -2 * sw, 0)
    P["arm_l"] = (-20 * sw, 9, 10); P["arm_r"] = (20 * sw, 9, 10)
    P["elbow_l"] = 18 + 14 * pos(-sw); P["elbow_r"] = 18 + 14 * pos(sw)
    return P

def walk_torch(t):
    P = walk(t)
    P["arm_r"] = (62, 12, 0); P["elbow_r"] = 25; P["wrist_r"] = (-5, 0, 0); P["fingers_r"] = 0.8; P["thumb_r"] = 0.7
    P["arm_l"] = (25 + 6 * s(t), 32, -10); P["elbow_l"] = 30
    P["head"] = (-14, 4 * s(t, 0.5), 0); P["spine"] = (6, 3 * s(t), 0)
    return P

def sit_pose(t, seat=0.44):
    b = s(t)
    return {
        "hips": (0, 0.06, 0), "hips_z": seat + 0.115, "hips_rot": (-6, 0, 0), "ground": None,
        "spine": (10 + 0.8 * b, 0, 0), "neck": (4, 0, 0), "head": (-4, 3 * s(t, 1, 0.2), 0),
        "leg_l": (84, 5, 4), "leg_r": (84, 5, 4), "knee_l": 88, "knee_r": 88, "foot_l": 2, "foot_r": 2,
        "arm_l": (28, 10, 25), "arm_r": (28, 10, 25), "elbow_l": 55, "elbow_r": 55,
        "wrist_l": (10, 0, 0), "wrist_r": (10, 0, 0), "fingers_l": 0.3, "fingers_r": 0.3,
        "shoulder_l": (0.6 * b, 0), "shoulder_r": (0.6 * b, 0),
    }

def sit_idle(t):
    return sit_pose(t)

def sit_mug(t):
    P = sit_pose(t)
    lift = pos(s(t, 1, -0.1)) ** 3
    P["arm_r"] = (32 + 18 * lift, 14, 30); P["elbow_r"] = 105 + 18 * lift; P["wrist_r"] = (-10, 0, 0)
    P["fingers_r"] = 0.62; P["thumb_r"] = 0.55
    P["head"] = (-4 - 8 * lift, 0, 0)
    return P

def sit_hug_knees(t):
    b = s(t)
    return {"hips": (0, 0.05, 0), "hips_z": 0.36 + 0.10, "hips_rot": (-14, 0, 0), "ground": None,
            "spine": (30 + b, 0, 0), "neck": (8, 0, 0), "head": (-12, 6 * s(t, 0.5), 0),
            "leg_l": (112, 6, 4), "leg_r": (112, 6, 4), "knee_l": 128, "knee_r": 128, "foot_l": 18, "foot_r": 18,
            "arm_l": (55, 18, 30), "arm_r": (55, 18, 30), "elbow_l": 95, "elbow_r": 95,
            "bend_l": (-1, -0.4, 0), "bend_r": (1, -0.4, 0), "fingers_l": 0.5, "fingers_r": 0.5}

def talk(t):
    P = base(t, 1.0, 0.4)
    g = pos(s(t, 2, 0.1))
    P["arm_r"] = (28 + 12 * g, 14, 20); P["elbow_r"] = 60 + 20 * g; P["wrist_r"] = (-15 * g, 0, 0); P["fingers_r"] = 0.2
    P["arm_l"] = (14 + 6 * pos(s(t, 1, 0.6)), 10, 15); P["elbow_l"] = 40
    P["head"] = (-3 + 4 * s(t, 4), 6 * s(t, 1), 2 * s(t, 2))
    return P

def wave(t):
    P = base(t, 1.0, 0.2)
    P["arm_r"] = (20, 85, -40); P["elbow_r"] = 70 + 18 * s(t, 3); P["bend_r"] = (0, 0, 1)
    P["wrist_r"] = (0, 15 * s(t, 3), 0); P["fingers_r"] = 0.05; P["thumb_r"] = 0.05
    P["shoulder_r"] = (8, 0); P["head"] = (-6, -6, 0); P["spine"] = (0, -3, -3)
    return P

def wave_up(t):
    """Both arms high, waving at something above (the drone)."""
    P = wave(t)
    P["arm_l"] = (25, 80, -40); P["elbow_l"] = 70 + 18 * s(t, 3, 0.5); P["bend_l"] = (0, 0, 1)
    P["wrist_l"] = (0, 15 * s(t, 3, 0.5), 0); P["fingers_l"] = 0.05
    P["head"] = (-28, 0, 0); P["neck"] = (-8, 0, 0); P["spine"] = (-4, 0, 0)
    return P

def look_around(t):
    P = base(t, 1.0, 0.5)
    y = 50 * s(t, 1) ; y2 = 15 * s(t, 1, -0.05)
    P["head"] = (-4 + 4 * s(t, 2), y * 0.55, 0); P["neck"] = (2, y * 0.25, 0); P["spine"] = (1.5, y2, 0)
    P["hips_rot"] = (0, y2 * 0.3, 0)
    return P

def look_up(t):
    P = base(t, 1.0, 0.3)
    P["head"] = (-30, 8 * s(t), 0); P["neck"] = (-12, 0, 0); P["spine"] = (-4, 0, 0)
    return P

def clap(t):
    P = base(0, 0.4, 0)
    k = c(t, 2)
    P["arm_l"] = (38, 6, 30); P["arm_r"] = (38, 6, 30)
    P["elbow_l"] = 85; P["elbow_r"] = 85
    P["bend_l"] = (-0.3, -1, 0.2); P["bend_r"] = (0.3, -1, 0.2)
    P["arm_l"] = (38, 6 + 9 * (k + 1) / 2, 32); P["arm_r"] = (38, 6 + 9 * (k + 1) / 2, 32)
    P["wrist_l"] = (-10, 0, 40); P["wrist_r"] = (-10, 0, 40); P["fingers_l"] = 0.1; P["fingers_r"] = 0.1
    P["head"] = (-4, 3 * s(t), 0)
    return P

def sway(t):
    P = base(t, 0.6, 0.0)
    w = s(t)
    P["hips"] = (0.03 * w, 0, 0); P["hips_rot"] = (0, 0, -4 * w); P["spine"] = (1, 0, 6 * w); P["head"] = (-2, 0, -4 * w)
    P["knee_l"] = 4 + 8 * pos(-w); P["knee_r"] = 4 + 8 * pos(w)
    P["arm_l"] = (4, 10 + 3 * w, 8); P["arm_r"] = (4, 10 - 3 * w, 8)
    return P

def cheer(t):
    P = base(t, 0.6, 0.3)
    k = s(t, 2)
    P["arm_l"] = (15, 150 + 8 * k, 0); P["arm_r"] = (15, 150 - 8 * k, 0)
    P["elbow_l"] = 25 + 10 * k; P["elbow_r"] = 25 - 10 * k
    P["fingers_l"] = 0.1; P["fingers_r"] = 0.1; P["head"] = (-10, 0, 0)
    P["hips"] = (0, 0, 0.015 * pos(k))
    return P

def point(t):
    P = base(t, 1.0, 0.3)
    P["arm_r"] = (78, 18, 0); P["elbow_r"] = 6; P["fingers_r"] = 0.85; P["index_r"] = 0.0; P["thumb_r"] = 0.6
    P["wrist_r"] = (-8, 0, 0); P["head"] = (-6, -10, 0); P["spine"] = (1, -8, 0)
    P["arm_l"] = (6, 10, 8)
    return P

def pockets(t):
    """Hands in the trouser pockets (Ellis standing)."""
    P = base(t)
    for side in ("l", "r"):
        P["arm_" + side] = (-4, 14, 30); P["elbow_" + side] = 32; P["wrist_" + side] = (20, 0, 0)
        P["fingers_" + side] = 0.55; P["thumb_" + side] = 0.4
    return P

def hands_hips(t):
    P = base(t)
    for side in ("l", "r"):
        P["arm_" + side] = (-12, 42, 35); P["elbow_" + side] = 100; P["bend_" + side] = (0, 1, 0)
        P["wrist_" + side] = (-10, 0, 0); P["fingers_" + side] = 0.25
    return P

def crouch(t):
    b = s(t)
    return {"hips": (0, 0.05, 0), "hips_rot": (12, 0, 0), "ground": ["feet"],
            "spine": (16 + b, 0, 0), "neck": (-4, 0, 0), "head": (-14, 8 * s(t, 0.5), 0),
            "leg_l": (100, 12, 10), "leg_r": (96, 10, 10), "knee_l": 122, "knee_r": 118, "foot_l": 10, "foot_r": 12,
            "toes_l": 15, "toes_r": 15,
            "arm_l": (55, 20, 20), "arm_r": (55, 20, 20), "elbow_l": 95, "elbow_r": 95,
            "bend_l": (-1, -0.3, 0), "bend_r": (1, -0.3, 0), "fingers_l": 0.55, "fingers_r": 0.55,
            "shoulder_l": (4 + b, 6), "shoulder_r": (4 + b, 6)}

def kneel(t):
    b = s(t)
    return {"hips": (0, 0.0, -0.35), "hips_rot": (6, 0, 0), "ground": ["knees", "toes"],
            "spine": (12 + b, 0, 0), "head": (-6, 5 * s(t, 0.5), 0),
            "leg_l": (88, 8, 4), "knee_l": 92, "foot_l": 2,
            "leg_r": (-8, 8, 4), "knee_r": 95, "foot_r": -60, "toes_r": 40, "foot_follow_r": False,
            "arm_l": (40, 12, 20), "elbow_l": 70, "arm_r": (20, 10, 10), "elbow_r": 30}

def toolbox_kneel(t):
    P = kneel(t)
    reach = pos(s(t, 1)) ** 2
    P["spine"] = (30 + 6 * reach, 18, 0); P["head"] = (12, 10, 0)
    P["arm_r"] = (70 + 12 * reach, 18, 10); P["elbow_r"] = 20; P["fingers_r"] = 0.5 + 0.2 * reach
    P["arm_l"] = (55, 20, 15); P["elbow_l"] = 60
    return P

def lie_creeper(t):
    """On his back on a mechanic's creeper (0.10 m), head and arms up under the bus behind him, knees up."""
    w = s(t)
    return {"hips": (0, 0.0, 0), "hips_z": 0.10 + 0.13, "hips_rot": (-90, 0, 0), "ground": None,
            "spine": (2, 0, 0), "neck": (8, 0, 0), "head": (6, 0, 0),
            "leg_l": (55, 14, 8), "leg_r": (35, 18, 8), "knee_l": 105, "knee_r": 70, "foot_l": 45, "foot_r": 30,
            "foot_follow_l": True, "foot_follow_r": True,
            "arm_l": (150, 15 + 3 * w, 0), "arm_r": (160, 10 - 3 * w, 0), "elbow_l": 50 + 8 * w, "elbow_r": 40 - 8 * w,
            "bend_l": (0, 1, 0), "bend_r": (0, 1, 0), "fingers_l": 0.6, "fingers_r": 0.6}

def clipboard_hold(t):
    P = base(t)
    P["arm_l"] = (30, 10, 30); P["elbow_l"] = 95; P["bend_l"] = (0.3, -1, 0.3); P["wrist_l"] = (5, 0, -20)
    P["fingers_l"] = 0.6; P["thumb_l"] = 0.3
    P["head"] = (6, 0, 0)
    return P

def clipboard_write(t):
    P = clipboard_hold(t)
    m = s(t, 3)
    P["arm_r"] = (32, 6, 30); P["elbow_r"] = 98 + 4 * m; P["bend_r"] = (-0.3, -1, 0.3); P["wrist_r"] = (10, 8 * m, 0)
    P["fingers_r"] = 0.55; P["head"] = (16, 0, 0); P["neck"] = (8, 0, 0)
    return P

def notebook_hold(t):
    return clipboard_hold(t)

def knock(t):
    P = base(t, 0.6, 0.0)
    k = pos(s(t, 3)) ** 3 if t < 0.5 else 0.0
    P["arm_r"] = (55 + 10 * k, 12, 0); P["elbow_r"] = 105 - 20 * k; P["bend_r"] = (0, 0, 1)
    P["fingers_r"] = 0.9; P["thumb_r"] = 0.8; P["wrist_r"] = (-10, 0, 0)
    P["arm_l"] = (30, 10, 30); P["elbow_l"] = 90; P["fingers_l"] = 0.55
    return P

def phone_hold(t):
    P = base(t)
    P["arm_r"] = (40, 8, 35); P["elbow_r"] = 100; P["bend_r"] = (-0.2, -1, 0.4); P["wrist_r"] = (-20, 0, -30)
    P["fingers_r"] = 0.55; P["thumb_r"] = 0.25
    P["arm_l"] = (20, 12, 20); P["elbow_l"] = 50 + 6 * s(t, 2)
    P["head"] = (18, 0, 0); P["neck"] = (6, 0, 0)
    return P

def flag_wave(t):
    P = base(t, 0.6, 0.4)
    k = s(t, 2)
    P["arm_r"] = (40, 70, -30); P["elbow_r"] = 50 + 20 * k; P["bend_r"] = (0, 0, 1)
    P["wrist_r"] = (0, 25 * k, 0); P["fingers_r"] = 0.8; P["thumb_r"] = 0.7
    P["head"] = (-8, -5, 0)
    return P

def sing(t):
    P = base(t, 1.2, 0.6)
    P["arm_r"] = (40, 10, 25); P["elbow_r"] = 110; P["bend_r"] = (-0.2, -1, 0.4); P["fingers_r"] = 0.7; P["thumb_r"] = 0.6
    P["arm_l"] = (20 + 15 * pos(s(t, 1, 0.2)), 18, 20); P["elbow_l"] = 30 + 20 * pos(s(t, 1, 0.2))
    P["head"] = (-6 + 3 * s(t, 2), 5 * s(t), 0)
    return P

def play_guitar(t):
    P = base(t, 0.8, 0.5)
    k = s(t, 4)
    # left hand up the neck, right hand strumming at the body
    P["arm_l"] = (35, 30, 10); P["elbow_l"] = 95; P["bend_l"] = (0.2, -1, 0.2); P["wrist_l"] = (25, 0, 0); P["fingers_l"] = 0.6
    P["arm_r"] = (22 + 4 * k, 22, 40); P["elbow_r"] = 85 + 6 * k; P["bend_r"] = (0.6, -1, 0); P["wrist_r"] = (8 * k, 0, 0); P["fingers_r"] = 0.5
    P["head"] = (10, 12, 0)
    return P

def play_fiddle(t):
    P = base(t, 0.8, 0.4)
    k = s(t, 2)
    P["arm_l"] = (70, 35, 20); P["elbow_l"] = 115; P["bend_l"] = (0.6, -0.4, 0.5); P["wrist_l"] = (20, 0, 0); P["fingers_l"] = 0.5
    P["arm_r"] = (40, 50 + 15 * k, -20); P["elbow_r"] = 70 - 25 * k; P["bend_r"] = (-0.5, -1, 0.3); P["fingers_r"] = 0.6
    P["head"] = (10, 20, -18)
    return P

def play_drum(t):
    P = sit_pose(t)
    k = s(t, 4)
    P["arm_l"] = (35, 20, 20); P["elbow_l"] = 80 - 18 * k; P["wrist_l"] = (-25 * k, 0, 0)
    P["arm_r"] = (35, 20, 20); P["elbow_r"] = 80 + 18 * k; P["wrist_r"] = (25 * k, 0, 0)
    P["fingers_l"] = 0.75; P["fingers_r"] = 0.75; P["thumb_l"] = 0.6; P["thumb_r"] = 0.6
    P["head"] = (8, 4 * s(t, 2), 0)
    return P

def play_cornet(t):
    P = base(t, 0.6, 0.3)
    P["arm_l"] = (55, 30, 15); P["elbow_l"] = 110; P["bend_l"] = (0.4, -1, 0.3); P["fingers_l"] = 0.7
    P["arm_r"] = (50, 22, 25); P["elbow_r"] = 105; P["bend_r"] = (-0.4, -1, 0.3); P["fingers_r"] = 0.35 + 0.15 * pos(s(t, 4))
    P["head"] = (-4 + 3 * s(t, 1), 0, 0)
    return P

CLIPS = {
    "idle": (4.0, idle), "idle_shift": (6.0, idle_shift), "walk": (1.1, walk), "walk_torch": (1.2, walk_torch),
    "sit_idle": (4.0, sit_idle), "sit_mug": (6.0, sit_mug), "sit_hug_knees": (5.0, sit_hug_knees),
    "talk": (4.0, talk), "wave": (2.0, wave), "wave_up": (2.0, wave_up), "look_around": (6.0, look_around), "look_up": (4.0, look_up),
    "clap": (0.8, clap), "sway": (3.0, sway), "cheer": (1.6, cheer), "point": (3.0, point),
    "pockets": (4.0, pockets), "hands_hips": (4.0, hands_hips),
    "crouch": (4.0, crouch), "kneel": (4.0, kneel), "toolbox_kneel": (5.0, toolbox_kneel), "lie_creeper": (4.0, lie_creeper),
    "clipboard_hold": (4.0, clipboard_hold), "clipboard_write": (3.0, clipboard_write), "notebook_hold": (4.0, notebook_hold),
    "knock": (2.0, knock), "phone_hold": (4.0, phone_hold), "flag_wave": (1.4, flag_wave), "sing": (4.0, sing),
    "play_guitar": (2.0, play_guitar), "play_fiddle": (2.0, play_fiddle), "play_drum": (1.0, play_drum), "play_cornet": (4.0, play_cornet),
}
