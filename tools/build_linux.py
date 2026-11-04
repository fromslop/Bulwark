"""Build the Linux release: export it with Godot and pack it for handing out.

    python tools/build_linux.py [--godot PATH] [--skip-export]

Writes build/linux/Bulwark.x86_64 (the "Linux" export preset, pack embedded) and
build/Bulwark-v<version>-linux-x86_64.tar.gz: a Bulwark/ folder with the executable
(mode 755, so it runs straight out of the archive) and a short README. The version comes
from application/config/version in project.godot (the one on the placard at home).

The same script runs locally and in .github/workflows/linux.yml, so the two can't drift.
Godot is found from --godot, then $GODOT, then the usual desktop install.
"""
import argparse
import io
import os
import re
import subprocess
import sys
import tarfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BINARY = os.path.join(ROOT, "build", "linux", "Bulwark.x86_64")
DEFAULT_GODOT = os.path.expanduser(r"~\Desktop\Godot_v4.7.2-stable_win64_console.exe")

RUN_TXT = """Bulwark {version} (Linux x86_64)

Run it:
    ./Bulwark.x86_64

If it won't start, make sure it's executable:
    chmod +x Bulwark.x86_64

Needs a GPU with Vulkan (or it falls back to OpenGL with --rendering-driver opengl3).
Saves go to ~/.local/share/godot/app_userdata/Bulwark/
The version is on the wooden placard in the home, under the trophy board.
"""


def version() -> str:
    with open(os.path.join(ROOT, "project.godot"), encoding="utf-8") as f:
        m = re.search(r'^config/version="([^"]+)"', f.read(), re.M)
    if not m:
        sys.exit("project.godot has no application/config/version")
    return "v" + m.group(1)


def export(godot: str) -> None:
    os.makedirs(os.path.dirname(BINARY), exist_ok=True)
    if os.path.exists(BINARY):
        os.remove(BINARY)
    # import first: a fresh checkout (CI) has no .godot/ cache yet
    subprocess.run([godot, "--headless", "--path", ROOT, "--import"], check=False)
    subprocess.run([godot, "--headless", "--path", ROOT, "--export-release", "Linux", BINARY], check=False)
    if not os.path.exists(BINARY):
        sys.exit("export failed: no " + BINARY)
    with open(BINARY, "rb") as f:
        if f.read(4) != b"\x7fELF":
            sys.exit("export failed: not a Linux executable")
    if os.path.getsize(BINARY) < 20_000_000:
        sys.exit("export looks too small (%d bytes): is the pack embedded?" % os.path.getsize(BINARY))


def package(ver: str) -> str:
    out = os.path.join(ROOT, "build", "Bulwark-%s-linux-x86_64.tar.gz" % ver)
    now = int(time.time())
    with tarfile.open(out, "w:gz") as tar:
        info = tar.gettarinfo(BINARY, "Bulwark/Bulwark.x86_64")
        info.mode = 0o755
        info.uid = info.gid = 0
        info.uname = info.gname = ""
        with open(BINARY, "rb") as f:
            tar.addfile(info, f)
        txt = RUN_TXT.format(version=ver).encode()
        info = tarfile.TarInfo("Bulwark/README.txt")
        info.size = len(txt)
        info.mode = 0o644
        info.mtime = now
        tar.addfile(info, io.BytesIO(txt))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=os.environ.get("GODOT", DEFAULT_GODOT))
    ap.add_argument("--skip-export", action="store_true", help="just repack build/linux/Bulwark.x86_64")
    args = ap.parse_args()
    ver = version()
    if not args.skip_export:
        export(args.godot)
    out = package(ver)
    print("Bulwark %s: %s (%.1f MB)" % (ver, os.path.relpath(out, ROOT), os.path.getsize(out) / 1e6))
    gh_out = os.environ.get("GITHUB_OUTPUT")
    if gh_out:
        with open(gh_out, "a") as f:
            f.write("version=%s\narchive=%s\n" % (ver, os.path.relpath(out, ROOT).replace("\\", "/")))


if __name__ == "__main__":
    main()
