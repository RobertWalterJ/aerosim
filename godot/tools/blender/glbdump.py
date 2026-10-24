"""Minimal glb reader for checking geometry: prints per mesh/material the bounds and the triangles above a height.
Usage: python glbdump.py file.glb [ymin]"""
import json, struct, sys
import numpy as np

CT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def load(path):
    data = open(path, "rb").read()
    jl = struct.unpack_from("<I", data, 12)[0]
    js = json.loads(data[20:20 + jl])
    bin_ = data[20 + jl + 8:]
    def acc(i):
        a = js["accessors"][i]
        bv = js["bufferViews"][a["bufferView"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        n = a["count"] * NC[a["type"]]
        arr = np.frombuffer(bin_, dtype=CT[a["componentType"]], count=n, offset=off)
        return arr.reshape(a["count"], NC[a["type"]]) if NC[a["type"]] > 1 else arr
    return js, acc


def node_mats(js):
    """world matrices per node index"""
    out = {}
    def mat(n):
        m = np.eye(4)
        if "matrix" in n: return np.array(n["matrix"]).reshape(4, 4).T
        t = n.get("translation", [0, 0, 0]); r = n.get("rotation", [0, 0, 0, 1]); s = n.get("scale", [1, 1, 1])
        x, y, z, w = r
        R = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)], [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)], [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
        m[:3, :3] = R * np.array(s)
        m[:3, 3] = t
        return m
    def walk(i, parent):
        w = parent @ mat(js["nodes"][i]); out[i] = w
        for c in js["nodes"][i].get("children", []): walk(c, w)
    for sc in js.get("scenes", []):
        for r in sc["nodes"]: walk(r, np.eye(4))
    return out


def triangles(path):
    """yields (node name, material name, tris[N,3,3] world)"""
    js, acc = load(path)
    W = node_mats(js)
    for ni, n in enumerate(js["nodes"]):
        if "mesh" not in n: continue
        for p in js["meshes"][n["mesh"]]["primitives"]:
            pos = acc(p["attributes"]["POSITION"]).astype(np.float64)
            pos = (W[ni] @ np.c_[pos, np.ones(len(pos))].T).T[:, :3]
            idx = acc(p["indices"]) if "indices" in p else np.arange(len(pos))
            mname = js["materials"][p["material"]].get("name", "?") if "material" in p else "?"
            yield n.get("name", "?"), mname, pos[np.asarray(idx).reshape(-1, 3)]


if __name__ == "__main__":
    ymin = float(sys.argv[2]) if len(sys.argv) > 2 else -1e9
    for nn, mn, t in triangles(sys.argv[1]):
        print(nn, mn, len(t), "min", t.reshape(-1, 3).min(0).round(2), "max", t.reshape(-1, 3).max(0).round(2))
