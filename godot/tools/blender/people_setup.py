# One-off setup for the Blender people pipeline (models10 / lane people).
# Installs the MPFB 2 extension (GPL-3 code; the MakeHuman base mesh, targets, rigs, skins and proxies it uses are CC0)
# into a PRIVATE Blender user folder, and unpacks the MakeHuman CC0 system assets pack into MPFB's user data.
# Run with the private user folder so nothing touches the shared Blender config used by other lanes:
#   set BLENDER_USER_RESOURCES=...\_tools\people\bluser
#   blender.exe -b --factory-startup --python people_setup.py -- <mpfb zip> <system assets zip>
import bpy, sys, os, zipfile

argv = sys.argv[sys.argv.index("--") + 1:]
mpfb_zip, assets_zip = argv[0], argv[1]

bpy.ops.extensions.package_install_files(filepath=mpfb_zip, repo="user_default", enable_on_install=True)
bpy.ops.wm.save_userpref()
import addon_utils
print("MPFB enabled:", [m.__name__ for m in addon_utils.modules() if "mpfb" in m.__name__])
user_home = bpy.utils.extension_path_user("bl_ext.user_default.mpfb", create=True)
data = os.path.join(user_home, "data")
os.makedirs(data, exist_ok=True)
with zipfile.ZipFile(assets_zip) as z:
    z.extractall(data)
print("assets unpacked to", data, os.listdir(data))
