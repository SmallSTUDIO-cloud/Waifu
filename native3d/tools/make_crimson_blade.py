#!/usr/bin/env python3
"""Generate native3d/assets/crimson_blade.glb — the CRIMSON BLADE sword.

Pure-Python glTF 2.0 binary writer (no Blender needed). Convention matches
the existing grip node in player.gd: origin at the hand, handle along +Y,
blade along -Y (tip near y=-0.88), overall length ~1.05 m.

Parts: tapered beveled blade, dark fuller grooves, luminous scarlet energy
channel, angular crossguard with crimson crystals, wrapped leather grip,
pommel with gem, red cloth ornament.
Materials: dark metal / edge metal / scarlet energy (emissive) / crystal
(emissive) / leather / cloth. Flat normals, < 1k triangles total.

Run: python3 native3d/tools/make_crimson_blade.py
"""
import json, struct, math, os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "crimson_blade.glb")

# palette (linear-ish sRGB factors as glTF expects)
DARK_METAL = (0.075, 0.078, 0.095, 1.0)
EDGE_METAL = (0.45, 0.48, 0.56, 1.0)
ENERGY_BASE = (0.30, 0.004, 0.03, 1.0)
ENERGY_EMISSIVE = (1.0, 0.090, 0.267)      # #FF1744
CRYSTAL_BASE = (0.35, 0.0, 0.07, 1.0)
CRYSTAL_EMISSIVE = (1.0, 0.216, 0.365)     # #FF375D-ish
LEATHER = (0.20, 0.045, 0.06, 1.0)
CLOTH = (0.474, 0.0, 0.094, 1.0)            # #790018

tris = []          # list of (v0, v1, v2, material_index)
materials = []     # glTF material dicts

def mat(name, base, metallic, rough, emissive=None, estr=1.0, double=False):
    m = {"name": name, "pbrMetallicRoughness": {
        "baseColorFactor": list(base), "metallicFactor": metallic, "roughnessFactor": rough}}
    if emissive is not None:
        m["emissiveFactor"] = list(emissive)
        m["extensions"] = {"KHR_materials_emissive_strength": {"emissiveStrength": estr}}
    if double:
        m["doubleSided"] = True
    materials.append(m)
    return len(materials) - 1

M_METAL = mat("DarkMetal", DARK_METAL, 0.9, 0.30)
M_EDGE = mat("EdgeMetal", EDGE_METAL, 0.95, 0.22)
M_ENERGY = mat("ScarletChannel", ENERGY_BASE, 0.1, 0.4, ENERGY_EMISSIVE, 2.6)
M_CRYSTAL = mat("CrimsonCrystal", CRYSTAL_BASE, 0.2, 0.25, CRYSTAL_EMISSIVE, 3.2)
M_LEATHER = mat("GripLeather", LEATHER, 0.0, 0.9)
M_CLOTH = mat("ClothOrnament", CLOTH, 0.0, 1.0, None, 1.0, double=True)

def tri(a, b, c, m):
    tris.append((a, b, c, m))

def quad(a, b, c, d, m):
    tri(a, b, c, m); tri(a, c, d, m)

def box(cx, cy, cz, sx, sy, sz, m, chamfer=0.0):
    x0, x1 = cx - sx / 2, cx + sx / 2
    y0, y1 = cy - sy / 2, cy + sy / 2
    z0, z1 = cz - sz / 2, cz + sz / 2
    if chamfer > 0:  # bevel the vertical edges slightly
        c = chamfer
        x0 += c if sx > sz else 0; x1 -= c if sx > sz else 0
        z0 += c if sz > sx else 0; z1 -= c if sz > sx else 0
    v = [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),
         (x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
    quad(v[0],v[1],v[2],v[3], m)  # -z... winding outward
    quad(v[5],v[4],v[7],v[6], m)
    quad(v[4],v[0],v[3],v[7], m)
    quad(v[1],v[5],v[6],v[2], m)
    quad(v[3],v[2],v[6],v[7], m)
    quad(v[4],v[5],v[1],v[0], m)

def cylinder_y(cx, cy, cz, r, h, m, seg=10, r2=None):
    r2 = r if r2 is None else r2
    y0, y1 = cy - h / 2, cy + h / 2
    for i in range(seg):
        a0 = 2 * math.pi * i / seg
        a1 = 2 * math.pi * (i + 1) / seg
        p00 = (cx + r * math.cos(a0), y0, cz + r * math.sin(a0))
        p01 = (cx + r * math.cos(a1), y0, cz + r * math.sin(a1))
        p10 = (cx + r2 * math.cos(a0), y1, cz + r2 * math.sin(a0))
        p11 = (cx + r2 * math.cos(a1), y1, cz + r2 * math.sin(a1))
        quad(p00, p01, p11, p10, m)
    # caps
    for i in range(seg):
        a0 = 2 * math.pi * i / seg; a1 = 2 * math.pi * (i + 1) / seg
        tri((cx, y0, cz), (cx + r * math.cos(a0), y0, cz + r * math.sin(a0)),
            (cx + r * math.cos(a1), y0, cz + r * math.sin(a1)), m)
        tri((cx, y1, cz), (cx + r2 * math.cos(a1), y1, cz + r2 * math.sin(a1)),
            (cx + r2 * math.cos(a0), y1, cz + r2 * math.sin(a0)), m)

def extrude_y(poly_xz, y0, y1, m, scale1=1.0, tip=None):
    """Extrude a 2D polygon (list of (x,z)) between y0..y1, scaling the top
    ring by scale1; if tip=(y) given, close the top with a point fan."""
    n = len(poly_xz)
    ring0 = [(x, y0, z) for (x, z) in poly_xz]
    ring1 = [(x * scale1, y1, z * scale1) for (x, z) in poly_xz]
    for i in range(n):
        j = (i + 1) % n
        quad(ring0[i], ring0[j], ring1[j], ring1[i], m)
    # bottom cap
    c0 = (0, y0, 0)
    for i in range(n):
        j = (i + 1) % n
        tri(c0, ring0[j], ring0[i], m)
    if tip is None:
        c1 = (0, y1, 0)
        for i in range(n):
            j = (i + 1) % n
            tri(c1, ring1[i], ring1[j], m)
    else:
        t = (0, tip[0], 0)
        for i in range(n):
            j = (i + 1) % n
            tri(t, ring1[i], ring1[j], m)

def octahedron(cx, cy, cz, s, m):
    v = [(cx+s,cy,cz),(cx-s,cy,cz),(cx,cy+s,cz),(cx,cy-s,cz),(cx,cy,cz+s),(cx,cy,cz-s)]
    for a, b in [(0,2),(2,1),(1,3),(3,0)]:
        tri(v[4], v[a], v[b], m)
    for a, b in [(2,0),(1,2),(3,1),(0,3)]:
        tri(v[5], v[b], v[a], m)

# ---------------- blade ----------------
# octagonal cross-section (flat faces + center ridge), tapered to a point
w0, t0 = 0.034, 0.011   # base half-width / half-thickness
w1, t1 = 0.030, 0.010   # at shoulder
y_base, y_shoulder, y_tip = 0.048, -0.66, -0.885
def ring(w, t, y):
    return [(-w, y, -t), (-w*0.35, y, -t), (w*0.35, y, -t), (w, y, -t),
            (w, y, t), (w*0.35, y, t), (-w*0.35, y, t), (-w, y, t)]

def blade():
    r0 = ring(w0, t0, y_base); r1 = ring(w1, t1, y_shoulder); n = len(r0)
    for i in range(n):
        j = (i + 1) % n
        quad(r0[i], r0[j], r1[j], r1[i], M_METAL)
    c0 = (0, y_base, 0)
    for i in range(n):
        j = (i + 1) % n
        tri(c0, r0[j], r0[i], M_METAL)
    t = (0, y_tip, 0)
    for i in range(n):
        j = (i + 1) % n
        tri(t, r1[i], r1[j], M_EDGE)
    # fuller grooves (dark) + scarlet energy channel (emissive) on both faces
    for s in (-1, 1):
        box(0, (0.02 + -0.78) / 2, s * (t0 + 0.0005), 0.012, 0.80, 0.0015, M_METAL)
        box(0, (0.02 + -0.78) / 2, s * (t0 + 0.0028), 0.0055, 0.80, 0.0012, M_ENERGY)

def guard():
    poly = [(-0.098, 0.050), (-0.076, 0.066), (0.076, 0.066), (0.098, 0.050),
            (0.076, 0.038), (-0.076, 0.038)]
    # extrude along z
    z0, z1 = -0.016, 0.016
    n = len(poly)
    r0 = [(x, y, z0) for (x, y) in poly]
    r1 = [(x, y, z1) for (x, y) in poly]
    for i in range(n):
        j = (i + 1) % n
        quad(r0[i], r0[j], r1[j], r1[i], M_METAL)
    for i in range(n):
        j = (i + 1) % n
        tri((0, 0, z0), r0[j], r0[i], M_METAL)
        tri((0, 0, z1), r1[i], r1[j], M_METAL)
    for s in (-1, 1):
        octahedron(0.046 * s, 0.070, 0, 0.009, M_CRYSTAL)

def handle():
    cylinder_y(0, 0.090, 0, 0.0155, 0.092, M_LEATHER, seg=10)
    for i in range(6):  # wrap rings
        cylinder_y(0, 0.050 + i * 0.016, 0, 0.0188, 0.0042, M_METAL, seg=10)
    # pommel
    cylinder_y(0, 0.142, 0, 0.020, 0.012, M_METAL, seg=10)
    octahedron(0, 0.156, 0, 0.011, M_CRYSTAL)
    # red cloth ornament hanging from the pommel
    pts = [(0, 0.150, 0.004), (0.006, 0.185, 0.008), (0.002, 0.220, 0.004), (0.010, 0.250, 0.010)]
    wdt = 0.011
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        dx, dz = b[0] - a[0], b[2] - a[2]
        ln = math.hypot(dx, dz) or 1.0
        px, pz = -dz / ln * wdt / 2, dx / ln * wdt / 2
        quad((a[0] - px, a[1], a[2] - pz), (a[0] + px, a[1], a[2] + pz),
             (b[0] + px, b[1], b[2] + pz), (b[0] - px, b[1], b[2] - pz), M_CLOTH)

blade(); guard(); handle()

# ---------------- pack GLB ----------------
# flat normals: expand triangles to vertices; one mesh per material, each with
# its own index buffer selecting into the shared flat vertex arrays.
positions = []
normals = []
mat_tris = {}
for (a, b, c, m) in tris:
    u = (b[0]-a[0], b[1]-a[1], b[2]-a[2]); v = (c[0]-a[0], c[1]-a[1], c[2]-a[2])
    n = (u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0])
    ln = math.sqrt(n[0]**2 + n[1]**2 + n[2]**2) or 1.0
    n = (n[0]/ln, n[1]/ln, n[2]/ln)
    base = len(positions)
    for p in (a, b, c):
        positions.append(p); normals.append(n)
    mat_tris.setdefault(m, []).extend([base, base+1, base+2])

bin_parts = []
def push(arr, fmt):
    data = struct.pack("<%d%s" % (len(arr), fmt), *arr)
    while sum(len(p) for p in bin_parts) % 4:
        bin_parts.append(b"\x00")
    off = sum(len(p) for p in bin_parts)
    bin_parts.append(data)
    return off, len(data)

buffer_views = []; accessors = []
def acc(off, length, ct, count, ty, mn=None, mx=None):
    buffer_views.append({"buffer": 0, "byteOffset": off, "byteLength": length})
    a = {"bufferView": len(buffer_views) - 1, "componentType": ct, "count": count, "type": ty}
    if mn is not None: a["min"] = mn; a["max"] = mx
    accessors.append(a)
    return len(accessors) - 1

pos_all = [c for p in positions for c in p]
nor_all = [c for p in normals for c in p]
pos_off, pos_len = push(pos_all, "f")
nor_off, nor_len = push(nor_all, "f")
pa = acc(pos_off, pos_len, 5126, len(positions), "VEC3",
         mn=[min(pos_all[0::3]), min(pos_all[1::3]), min(pos_all[2::3])],
         mx=[max(pos_all[0::3]), max(pos_all[1::3]), max(pos_all[2::3])])
na = acc(nor_off, nor_len, 5126, len(normals), "VEC3")
meshes = []; nodes = []
for m in sorted(mat_tris.keys()):
    flat = mat_tris[m]
    ioff, ilen = push(flat, "I")
    ia = acc(ioff, ilen, 5125, len(flat), "SCALAR")
    meshes.append({"name": materials[m]["name"], "primitives": [{
        "attributes": {"POSITION": pa, "NORMAL": na}, "indices": ia, "material": m}]})
    nodes.append({"mesh": len(meshes) - 1, "name": materials[m]["name"]})

gltf = {
    "asset": {"version": "2.0", "generator": "make_crimson_blade.py"},
    "scene": 0,
    "scenes": [{"nodes": [0], "name": "CrimsonBlade"}],
    "nodes": [{"name": "CrimsonBlade", "children": list(range(1, len(nodes) + 1))}] + nodes,
    "meshes": meshes,
    "materials": materials,
    "accessors": accessors,
    "bufferViews": buffer_views,
    "buffers": [{"byteLength": sum(len(p) for p in bin_parts)}],
}

js = json.dumps(gltf, separators=(",", ":")).encode()
while len(js) % 4: js += b" "
bin_data = b"".join(bin_parts)
while len(bin_data) % 4: bin_data += b"\x00"
total = 12 + 8 + len(js) + 8 + len(bin_data)
glb = struct.pack("<4sII", b"glTF", 2, total)
glb += struct.pack("<II", len(js), 0x4E4F534A) + js
glb += struct.pack("<II", len(bin_data), 0x004E4942) + bin_data
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "wb") as f:
    f.write(glb)
print("wrote", os.path.abspath(OUT), len(glb), "bytes,", len(tris), "triangles,", len(materials), "materials")
