#!/usr/bin/env python3
"""Records the app's bundled files (everything under assets/) in release_assets.json:
the list `test/design_system/asset_release_test.dart` holds the bundle to. Run it
deliberately (`just record-assets`) when a build goes out, after every removed or
renamed file is covered (an `ArtSet.retired` alias, or a dated "removedOnPurpose" line
in the file). The lines under removedOnPurpose are kept; a path that is in the bundle
again is dropped from them."""

import json
import pathlib

here = pathlib.Path(__file__).resolve().parent
frontend = here.parent
target = here / "release_assets.json"
files = sorted(
    p.relative_to(frontend).as_posix()
    for p in (frontend / "assets").rglob("*")
    if p.is_file()
)
old = json.loads(target.read_text()) if target.exists() else {}
removed = {
    path: why
    for path, why in old.get("removedOnPurpose", {}).items()
    if path not in files
}
target.write_text(
    json.dumps({"removedOnPurpose": removed, "files": files}, indent=2) + "\n"
)
print(f"recorded {len(files)} files in {target.relative_to(frontend)}")
