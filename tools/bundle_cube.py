#!/usr/bin/env python3
"""Bundle the Drift arcade cube page into one self-contained HTML file.

Two problems made the cube screen render blank teal on the phone:

1. The Flutter WebView loads index.html via loadFlutterAsset(), i.e. as a raw
   string with no base URL. Any relative script reference (the import-map entry,
   "./RoundedBoxGeometry.js") therefore fails to resolve and the module never
   runs.
2. The three.module.js that had been copied into assets/cube/ was only the npm
   re-export shim: it does `import/export ... from './three.core.js'`, and
   three.core.js was never copied. Even over HTTP the page could never load
   three.js.

The npm r186 build is two files that must stay separate modules (they share
minified internal names, so concatenating them causes duplicate declarations):
three.module.js imports/re-exports ~hundreds of names from ./three.core.js.

This script inlines all three JS files as data: URLs in the import map and
rewrites three.module.js's './three.core.js' specifiers to the bare specifier
'three-core' (import maps resolve bare specifiers without needing a base URL,
which a relative specifier would require). The result,
assets/cube/cube_bundle.html, has zero external dependencies and renders under
loadHtmlString.

Run:  python3 tools/bundle_cube.py
Input:  assets/cube/index.html (+ portfolio node_modules three r186 build,
        assets/cube/RoundedBoxGeometry.js)
Output: assets/cube/cube_bundle.html
"""
import base64
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CUBE = ROOT / "assets" / "cube"
# Vendored three.js r186 build (MIT, Three.js authors). three.module.js must be
# the matching build; both are read from here so regeneration needs nothing
# outside this repo.
VENDOR = ROOT / "tools" / "vendor"
THREE_CORE = VENDOR / "three.core.js"
THREE_MODULE = VENDOR / "three.module.js"

# Every THREE.* name the cube page touches. Checked against three.module.js's
# export surface so a three.js upgrade can't silently drop one.
NEEDED_EXPORTS = [
    "WebGLRenderer", "Scene", "Color", "Fog", "PerspectiveCamera",
    "HemisphereLight", "DirectionalLight", "PointLight", "Group",
    "TorusGeometry", "MeshBasicMaterial", "Mesh", "MeshPhysicalMaterial",
    "MeshStandardMaterial", "PlaneGeometry", "Raycaster", "Vector2",
    "Vector3", "Ray", "Plane", "Clock", "MathUtils", "BoxGeometry",
]


def data_url(js_text: str) -> str:
    b64 = base64.b64encode(js_text.encode("utf-8")).decode("ascii")
    return "data:text/javascript;base64," + b64


def main() -> int:
    core = THREE_CORE.read_text(encoding="utf-8")
    if re.search(r"^import ", core, flags=re.MULTILINE):
        print("ERROR: three.core.js has imports; not self-contained", file=sys.stderr)
        return 1

    module = THREE_MODULE.read_text(encoding="utf-8")
    if "./three.core.js" not in module:
        print("ERROR: three.module.js does not reference ./three.core.js as expected", file=sys.stderr)
        return 1
    # Bare specifier: import maps resolve these without a base URL, unlike the
    # relative './three.core.js' (unresolvable from inside a data: URL module).
    module = module.replace("'./three.core.js'", "'three-core'")

    # Sanity: three.module.js's export surface must cover every needed name.
    export_names = set()
    for m in re.finditer(r"^export \{(.*?)\} from 'three-core';\s*$", module, flags=re.MULTILINE | re.DOTALL):
        export_names.update(n.strip().split(" as ")[-1].strip() for n in m.group(1).split(",") if n.strip())
    for m in re.finditer(r"^export \{(.*?)\};\s*$", module, flags=re.MULTILINE | re.DOTALL):
        export_names.update(n.strip().split(" as ")[-1].strip() for n in m.group(1).split(",") if n.strip())
    missing = [n for n in NEEDED_EXPORTS if n not in export_names]
    if missing:
        print(f"ERROR: three.module.js does not export: {missing}", file=sys.stderr)
        return 1
    print(f"exports OK: three.module.js exports all {len(NEEDED_EXPORTS)} names the cube page needs")

    rounded = (CUBE / "RoundedBoxGeometry.js").read_text(encoding="utf-8")

    html = (CUBE / "index.html").read_text(encoding="utf-8")
    imports = {
        "three": data_url(module),
        "three-core": data_url(core),
        "./RoundedBoxGeometry.js": data_url(rounded),
    }
    importmap = '<script type="importmap">\n' + json.dumps({"imports": imports}) + "\n</script>"

    new_html, n = re.subn(
        r'<script type="importmap">.*?</script>', lambda _m: importmap, html, count=1, flags=re.DOTALL
    )
    if n != 1:
        print("ERROR: importmap block not found in index.html", file=sys.stderr)
        return 1

    out = CUBE / "cube_bundle.html"
    out.write_text(new_html, encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
