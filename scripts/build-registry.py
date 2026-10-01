#!/usr/bin/env python3
"""Builds registry.json, the index Octet's Marketplace reads.

Each plugin here is a folder in plugins/<id>/ with a plugin.json; it's
listed with every file and its SHA-256, which Octet checks before
installing. Plugins published from other repositories go in
community.json, one entry each ({"id", "name", "repo", "ref", "path",
"files": [...]}, the same shape); --fetch fills in their checksums.

  scripts/build-registry.py           rebuild registry.json
  scripts/build-registry.py --check   fail if registry.json is stale (CI)
  scripts/build-registry.py --fetch   also re-read community checksums
"""
import hashlib, json, os, re, sys, urllib.request

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
plugins_dir = os.path.join(root, "plugins")
REPO, REF = "JackTPatterson/octet-plugins", "main"
PLATFORMS = {"macos", "linux", "windows"}
problems = []


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def check_manifest(folder, manifest, files):
    """What would make Octet refuse the plugin, or its commands fail."""
    if manifest.get("id") != folder:
        problems.append(f"{folder}: its manifest id is {manifest.get('id')}")
    if not re.fullmatch(r"[a-z0-9][a-z0-9._-]*", folder):
        problems.append(f"{folder}: ids are lowercase letters, digits, dots, dashes or underscores")
    for platform in manifest.get("platforms", []):
        if platform not in PLATFORMS:
            problems.append(f"{folder}: unknown platform {platform}")
    contributes = manifest.get("contributes", {})
    runs = [c.get(key) for kind in ("statusItems", "completions", "menuItems", "panels", "workspaceIcons")
            for c in contributes.get(kind, []) for key in ("run", "act") if c.get(key)]
    for run in runs:
        commands = [run] if isinstance(run, str) else list((run or {}).values())
        for command in commands:
            # Every script a command names ships with the plugin.
            for script in re.findall(r"OCTET_PLUGIN_DIR[/\\\\]+([\w./\\\\-]+)", command or ""):
                if script.replace("\\\\", "/") not in files:
                    problems.append(f"{folder}: runs {script}, which isn't in the plugin")
    for icon in [c.get("icon") for kind in ("statusItems", "runtimes", "panels") for c in contributes.get(kind, [])]:
        if icon and icon not in files:
            problems.append(f"{folder}: icon {icon} is missing")


def local_entry(folder):
    base = os.path.join(plugins_dir, folder)
    manifest = json.load(open(os.path.join(base, "plugin.json")))
    files = []
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
        for name in sorted(filenames):
            if name.startswith("."):
                continue
            full = os.path.join(dirpath, name)
            files.append({"path": os.path.relpath(full, base), "sha256": sha256(open(full, "rb").read())})
    check_manifest(folder, manifest, {f["path"] for f in files})
    return {
        "id": manifest["id"],
        "name": manifest["name"],
        "description": manifest.get("description", ""),
        "author": manifest.get("author", ""),
        "version": manifest.get("version", "0.0.0"),
        "keywords": manifest.get("keywords", []),
        # Plain-string commands are sh: macOS and Linux unless it says.
        "platforms": manifest.get("platforms", ["macos", "linux"]),
        "repo": REPO,
        "ref": REF,
        "path": f"plugins/{folder}",
        "files": files,
    }


def fetched(entry):
    """Checksums for a community entry's files, read from GitHub."""
    files = []
    prefix = entry.get("path", "").strip("/")
    for f in entry["files"]:
        path = f["path"] if isinstance(f, dict) else f
        url = f"https://raw.githubusercontent.com/{entry['repo']}/{entry.get('ref', 'main')}/{prefix + '/' if prefix else ''}{path}"
        files.append({"path": path, "sha256": sha256(urllib.request.urlopen(url).read())})
    return {**entry, "files": files}


entries = [local_entry(d) for d in sorted(os.listdir(plugins_dir)) if not d.startswith(".")]
community_path = os.path.join(root, "community.json")
if os.path.exists(community_path):
    community = json.load(open(community_path))
    if "--fetch" in sys.argv:
        community = [fetched(e) for e in community]
        with open(community_path, "w") as out:
            json.dump(community, out, indent=2)
            out.write("\n")
    entries += community
ids = [e["id"] for e in entries]
if len(ids) != len(set(ids)):
    problems.append("two plugins share an id")
if problems:
    sys.exit("\n".join(problems))

text = json.dumps({"version": 1, "plugins": entries}, indent=2, ensure_ascii=False) + "\n"
index = os.path.join(root, "registry.json")
if "--check" in sys.argv:
    current = open(index).read() if os.path.exists(index) else ""
    if current != text:
        sys.exit("registry.json is out of date: run scripts/build-registry.py and commit it")
    print(f"registry.json is current ({len(entries)} plugins)")
else:
    open(index, "w").write(text)
    print(f"{len(entries)} plugins -> registry.json")
