#!/usr/bin/env python3
"""Builds what the site serves from the addons in this repository.

    python tools/build.py

* docs/downloads/<AddonFolder>.zip     one archive per addon, the folder inside it ready to drop into Interface/AddOns
                                       (the tests/ folder is left out: it is only for the people who work on the addon)
* docs/downloads/wowvision-forever-addons.zip   every addon except the retired one, in one archive
* docs/downloads/SHA256SUMS.txt        checksums of all of them
* docs/js/data.js                      the catalogue the page shows (tools/catalog.json + what is read from the .toc files
                                       and from the archives)

The archives are reproducible: the same sources give the same bytes (fixed dates, sorted entries).
"""
import hashlib
import json
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOWNLOADS = os.path.join(ROOT, "docs", "downloads")
DATA_JS = os.path.join(ROOT, "docs", "js", "data.js")
ALL_NAME = "wowvision-forever-addons.zip"
FIXED_DATE = (2026, 11, 11, 0, 0, 0)
SKIP_DIRS = {"tests", ".git"}
SKIP_FILES = {".gitignore", ".DS_Store", "Thumbs.db"}


def read_toc(folder, name):
    values = {}
    with open(os.path.join(folder, name + ".toc"), encoding="utf-8") as handle:
        for line in handle:
            match = re.match(r"^##\s*([\w-]+)\s*:\s*(.*?)\s*$", line)
            if match:
                values[match.group(1)] = match.group(2)
    return values


def addon_files(folder):
    """Every file of the addon that goes into the archive, as (path on disk, path inside the folder), sorted."""
    found = []
    for base, dirs, files in os.walk(folder):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for file in sorted(files):
            if file in SKIP_FILES:
                continue
            path = os.path.join(base, file)
            found.append((path, os.path.relpath(path, folder).replace(os.sep, "/")))
    return found


def add_to_zip(archive, name, files):
    for path, relative in files:
        info = zipfile.ZipInfo(name + "/" + relative, date_time=FIXED_DATE)
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o644 << 16
        with open(path, "rb") as handle:
            archive.writestr(info, handle.read(), compresslevel=9)
    # every archive carries the licence of the repository, and the notice about what was taken from WowVision
    for extra in ("LICENSE", "NOTICE"):
        info = zipfile.ZipInfo(name + "/" + extra, date_time=FIXED_DATE)
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o644 << 16
        with open(os.path.join(ROOT, extra), "rb") as handle:
            archive.writestr(info, handle.read(), compresslevel=9)


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    with open(os.path.join(ROOT, "tools", "catalog.json"), encoding="utf-8") as handle:
        catalog = json.load(handle)
    os.makedirs(DOWNLOADS, exist_ok=True)
    for old in os.listdir(DOWNLOADS):
        if old.endswith(".zip") or old == "SHA256SUMS.txt":
            os.remove(os.path.join(DOWNLOADS, old))

    sums = []
    addons = []
    everything = []
    for name in catalog["order"]:
        entry = catalog["addons"][name]
        folder = os.path.join(ROOT, *entry["path"].split("/"))
        toc = read_toc(folder, name)
        files = addon_files(folder)
        size = sum(os.path.getsize(path) for path, _ in files)
        zip_path = os.path.join(DOWNLOADS, name + ".zip")
        with zipfile.ZipFile(zip_path, "w") as archive:
            add_to_zip(archive, name, files)
        if entry["group"] != "retired":
            everything.append((name, files))
        sums.append((sha256(zip_path), name + ".zip"))
        addons.append({
            "id": name,
            "group": entry["group"],
            "icon": entry["icon"],
            "featured": bool(entry.get("featured")),
            "title": entry["title"],
            "tagline": entry["tagline"],
            "description": entry["description"],
            "status": entry["status"],
            "note": entry.get("note"),
            "keys": entry["keys"],
            "commands": entry["commands"],
            "preview": entry["preview"],
            "requires": entry["requires"],
            "optional": entry["optional"],
            "mergedPr": entry.get("mergedPr"),
            "version": toc.get("Version", ""),
            "interface": toc.get("Interface", ""),
            "files": len(files),
            "sourceBytes": size,
            "tests": catalog["tests"].get(name),
            "zip": {
                "file": "downloads/" + name + ".zip",
                "bytes": os.path.getsize(zip_path),
                "sha256": sums[-1][0],
            },
            "links": {
                "source": "https://github.com/" + catalog["repo"] + "/tree/main/" + entry["path"],
                "readme": "https://github.com/" + catalog["repo"] + "/blob/main/" + entry["path"] + "/README.md",
            },
        })

    all_path = os.path.join(DOWNLOADS, ALL_NAME)
    with zipfile.ZipFile(all_path, "w") as archive:
        for name, files in everything:
            add_to_zip(archive, name, files)
    sums.append((sha256(all_path), ALL_NAME))

    with open(os.path.join(DOWNLOADS, "SHA256SUMS.txt"), "w", encoding="utf-8", newline="\n") as handle:
        for digest, file in sorted(sums, key=lambda item: item[1]):
            handle.write("%s  %s\n" % (digest, file))

    data = {
        "repo": catalog["repo"],
        "repoUrl": "https://github.com/" + catalog["repo"],
        "site": catalog["site"],
        "wowvision": catalog["wowvision"],
        "testsAsOf": catalog["testsAsOf"],
        "all": {
            "file": "downloads/" + ALL_NAME,
            "bytes": os.path.getsize(all_path),
            "sha256": sums[-1][0],
            "count": len(everything),
        },
        "addons": addons,
        "upstream": [
            dict(item, url="https://github.com/%s/pull/%d" % (item["repo"], item["number"]))
            for item in catalog["upstream"]
        ],
    }
    os.makedirs(os.path.dirname(DATA_JS), exist_ok=True)
    with open(DATA_JS, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("// Generated by tools/build.py from tools/catalog.json: do not edit by hand.\n")
        handle.write("window.WVA = ")
        json.dump(data, handle, ensure_ascii=False, indent=2)
        handle.write(";\n")

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import readme
    readme.write(catalog, ROOT)

    for addon in addons:
        print("%-28s %-8s %3d files  zip %6d bytes" % (addon["id"], addon["group"], addon["files"], addon["zip"]["bytes"]))
    print("%-28s %-8s %3d addons zip %6d bytes" % (ALL_NAME, "all", len(everything), data["all"]["bytes"]))


if __name__ == "__main__":
    sys.exit(main())
