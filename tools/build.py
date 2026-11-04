"""Build Hoardsman for handing out: export it with Godot and pack it for players.

    python tools/build.py [linux] [windows] [--godot PATH] [--skip-export]

With no platform named, builds both. Each is a single file in build/, ready to send:

- linux:   build/Hoardsman-v<version>-linux-x86_64.tar.gz  (Hoardsman/Hoardsman.x86_64, mode 755,
           and a README)
- windows: build/Hoardsman-v<version>-windows.zip  (Hoardsman/Hoardsman.exe and "How to play.txt":
           unzip, double-click; no Godot, no console window, nothing else to install)

Both are release exports (the "Linux" and "Windows Desktop" presets, pack embedded), so the
developer keys (F1, F4, F5-F9) are off. The version comes from application/config/version in
project.godot (the one on the placard at home).

The same script runs locally and in .github/workflows/build.yml, so the two can't drift.
Godot is found from --godot, then $GODOT, then the usual desktop install. A platform needs
Godot's export templates for it (Editor > Manage Export Templates); CI installs them all.
"""
import argparse
import io
import os
import re
import subprocess
import sys
import tarfile
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_GODOT = os.path.expanduser(r"~\Desktop\Godot_v4.7.2-stable_win64_console.exe")

LINUX_TXT = """Hoardsman {version} (Linux x86_64)

Run it:
    ./Hoardsman.x86_64

If it won't start, make sure it's executable:
    chmod +x Hoardsman.x86_64

Needs a GPU with Vulkan (or it falls back to OpenGL with --rendering-driver opengl3).
Saves go to ~/.local/share/godot/app_userdata/Hoardsman/
The version is on the wooden placard in the home, under the trophy board.
"""

WINDOWS_TXT = """Hoardsman {version}

HOW TO START
  1. Unzip this first: right-click the zip and choose "Extract All...", then "Extract".
     (Running it from inside the zip won't work properly.)
  2. Open the Hoardsman folder and double-click Hoardsman.exe.

  If Windows shows "Windows protected your PC": that's because the game is new and
  unsigned, not because anything is wrong. Click "More info", then "Run anyway".
  You only have to do this once.

HOW TO PLAY
  Left mouse     grab things and drag them
  Space          swing what you're holding / brace a shield / use an item / punch
  Q / E          turn what you're holding
  Hold Alt       look closely at things (what they are, what they do)
  Right mouse    use your rings
  Esc            pause menu: settings, controls, volume, quit
  F11            fullscreen

  Drag your gear into the glowing area where the enemy is about to strike to block it.
  Swing your weapon at the enemy to hit it. Punch the gong to start a run.

Your progress saves on its own (in %APPDATA%\\Godot\\app_userdata\\Hoardsman).
The version is on the wooden placard in the home, under the trophy board.
"""

PLATFORMS = {
    "linux": {"preset": "Linux", "binary": os.path.join("build", "linux", "Hoardsman.x86_64"), "magic": b"\x7fELF"},
    "windows": {"preset": "Windows Desktop", "binary": os.path.join("build", "windows", "Hoardsman.exe"), "magic": b"MZ"},
}


def version() -> str:
    with open(os.path.join(ROOT, "project.godot"), encoding="utf-8") as f:
        m = re.search(r'^config/version="([^"]+)"', f.read(), re.M)
    if not m:
        sys.exit("project.godot has no application/config/version")
    return "v" + m.group(1)


def export(godot: str, plat: str) -> str:
    p = PLATFORMS[plat]
    binary = os.path.join(ROOT, p["binary"])
    os.makedirs(os.path.dirname(binary), exist_ok=True)
    if os.path.exists(binary):
        os.remove(binary)
    subprocess.run([godot, "--headless", "--path", ROOT, "--export-release", p["preset"], binary], check=False)
    if not os.path.exists(binary):
        sys.exit("%s export failed: no %s (are Godot's %s export templates installed?)" % (plat, binary, plat))
    with open(binary, "rb") as f:
        if not f.read(4).startswith(p["magic"]):
            sys.exit("%s export failed: not a %s executable" % (plat, plat))
    if os.path.getsize(binary) < 20_000_000:
        sys.exit("%s export looks too small (%d bytes): is the pack embedded?" % (plat, os.path.getsize(binary)))
    return binary


def pack_linux(ver: str) -> str:
    binary = os.path.join(ROOT, PLATFORMS["linux"]["binary"])
    out = os.path.join(ROOT, "build", "Hoardsman-%s-linux-x86_64.tar.gz" % ver)
    with tarfile.open(out, "w:gz") as tar:
        info = tar.gettarinfo(binary, "Hoardsman/Hoardsman.x86_64")
        info.mode = 0o755
        info.uid = info.gid = 0
        info.uname = info.gname = ""
        with open(binary, "rb") as f:
            tar.addfile(info, f)
        txt = LINUX_TXT.format(version=ver).encode()
        info = tarfile.TarInfo("Hoardsman/README.txt")
        info.size = len(txt)
        info.mode = 0o644
        info.mtime = int(time.time())
        tar.addfile(info, io.BytesIO(txt))
    return out


def pack_windows(ver: str) -> str:
    binary = os.path.join(ROOT, PLATFORMS["windows"]["binary"])
    out = os.path.join(ROOT, "build", "Hoardsman-%s-windows.zip" % ver)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.write(binary, "Hoardsman/Hoardsman.exe")
        z.writestr("Hoardsman/How to play.txt", WINDOWS_TXT.format(version=ver).replace("\n", "\r\n"))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("platforms", nargs="*", choices=list(PLATFORMS), default=None)
    ap.add_argument("--godot", default=os.environ.get("GODOT", DEFAULT_GODOT))
    ap.add_argument("--skip-export", action="store_true", help="just repack what's already exported")
    args = ap.parse_args()
    plats = args.platforms or list(PLATFORMS)
    ver = version()
    if not args.skip_export:
        # import first: a fresh checkout (CI) has no .godot/ cache yet
        subprocess.run([args.godot, "--headless", "--path", ROOT, "--import"], check=False)
    outs = []
    for plat in plats:
        if not args.skip_export:
            export(args.godot, plat)
        out = pack_linux(ver) if plat == "linux" else pack_windows(ver)
        outs.append(os.path.relpath(out, ROOT).replace("\\", "/"))
        print("Hoardsman %s %s: %s (%.1f MB)" % (ver, plat, outs[-1], os.path.getsize(out) / 1e6))
    gh_out = os.environ.get("GITHUB_OUTPUT")
    if gh_out:
        with open(gh_out, "a") as f:
            f.write("version=%s\n" % ver)
            f.write("archives<<EOF\n%s\nEOF\n" % "\n".join(outs))


if __name__ == "__main__":
    main()
