"""Render a single-file, offline HTML patcher around a BPS patch.

    python tools/webpatch.py PATCH.bps OUT.html --title "Game: My Hack"         [--game "Game (USA)"] [--subtitle "v1.0"] [--out-name "Game - My Hack v1.0"]
        [--template tools/patcher_template.html]

From the Phantasy Star II retranslation (same author), for the Master System:
the page runs entirely in the player's browser from a local file: drop a ROM
on it, it verifies the source CRC32 the patch carries (a 512-byte copier
header, if the dump has one, is dropped first), applies the patch and offers
the result for saving as .sms. Alternates (other dumps the page accepts) carry
a small BPS that turns them into the main patch's source.

The expected source size and CRC32 come from the patch itself.  Everything
else is a @TOKEN@ in the template; see TOKENS for what a caller may set.
"""
import base64
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bps

DEFAULT_TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "patcher_template.html")

# Caller-settable tokens and what the page uses them for.
TOKENS = {
    "TITLE": "page heading and browser tab",
    "SUBTITLE": "line under the heading (version, language...)",
    "GAME": "how the expected ROM is named in the drop zone and error text",
    "PATCH": "file name of the .bps shipped beside the page, for the footnote",
    "OUT_NAME": "saved file name without extension (.sms is appended)",
    "README_NOTE": "optional sentence appended to the footnote (may be empty)",
    "HINT": "optional sentence appended to the wrong-ROM error (may be empty)",
}


def render_patcher(patch: bytes, out_path: str, template: str = DEFAULT_TEMPLATE,
                   tokens: dict | None = None, alternates: list | None = None) -> None:
    """alternates: (name, bps) pairs for other dumps the page should accept; each
    bps must turn that dump into the main patch's source (checked here)."""
    hdr = bps.info(patch)
    values = {"README_NOTE": "", "HINT": "", "PATCH": "the .bps file"}
    values.update(tokens or {})
    values.setdefault("SUBTITLE", "")
    values.setdefault("GAME", "the original")
    values["PATCH_B64"] = base64.b64encode(patch).decode("ascii")
    values["SRC_CRC32"] = "%08X" % hdr["source_crc"]
    values["SRC_SIZE"] = "{:,}".format(hdr["source_size"])
    alts, notes = [], []
    for name, alt in alternates or []:
        a = bps.info(alt)
        if a["target_crc"] != hdr["source_crc"] or a["target_size"] != hdr["source_size"]:
            raise SystemExit("alternate %r does not produce the patch's source ROM" % name)
        alts.append({"name": name, "b64": base64.b64encode(alt).decode("ascii")})
        notes.append("%s (CRC32 %08X)" % (name, a["source_crc"]))
    values["ALT_JSON"] = json.dumps(alts)
    values["ALT_NOTE"] = (" Also accepted: %s." % ", ".join(notes)) if notes else ""
    text = open(template, encoding="utf-8").read()
    for k, v in values.items():
        text = text.replace("@%s@" % k, v)
    left = sorted(set(re.findall(r"@[A-Z][A-Z0-9_]*@", text)))
    if left:
        raise SystemExit("%s: unfilled token(s): %s" % (os.path.basename(template), ", ".join(left)))
    open(out_path, "w", encoding="utf-8", newline="\n").write(text)


def main(argv):
    if len(argv) < 2 or argv[0].startswith("-"):
        sys.exit(__doc__)
    patch_path, out_path = argv[0], argv[1]

    def opt(name, default=None):
        flag = "--" + name
        return argv[argv.index(flag) + 1] if flag in argv else default

    stem = os.path.splitext(os.path.basename(patch_path))[0]
    tokens = {
        "TITLE": opt("title", stem),
        "SUBTITLE": opt("subtitle", ""),
        "GAME": opt("game", "the original"),
        "PATCH": os.path.basename(patch_path),
        "OUT_NAME": opt("out-name", stem),
    }
    patch = open(patch_path, "rb").read()
    render_patcher(patch, out_path, opt("template", DEFAULT_TEMPLATE), tokens)
    hdr = bps.info(patch)
    print("%s: %d bytes; expects a %s-byte source with CRC32 %08X"
          % (out_path, os.path.getsize(out_path), "{:,}".format(hdr["source_size"]), hdr["source_crc"]))


if __name__ == "__main__":
    main(sys.argv[1:])
