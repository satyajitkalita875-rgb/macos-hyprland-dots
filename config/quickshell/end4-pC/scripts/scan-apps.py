#!/usr/bin/env python3
"""Fast live XDG + Flatpak desktop application & original icon scanner."""
import configparser
import json
import os
import shlex
import shutil
import sys

EXTENSIONS = ("png", "svg", "xpm")
HICOLOR_SIZE_ORDER = (
    "256x256/apps",
    "128x128/apps",
    "512x512/apps",
    "scalable/apps",
    "96x96/apps",
    "64x64/apps",
    "48x48/apps",
    "32x32/apps",
    "256x256/categories",
    "128x128/categories",
    "scalable/categories",
    "scalable/mimetypes",
    "scalable/places",
    "scalable/status",
    "64x64/categories",
    "48x48/categories",
)
FIELD_CODES = {"%f", "%F", "%u", "%U", "%d", "%D", "%n", "%N", "%i", "%c", "%k", "%v", "%m"}


def xdg_data_dirs():
    home = os.path.expanduser("~")
    data_home = os.environ.get("XDG_DATA_HOME", os.path.join(home, ".local/share"))
    raw = [
        data_home,
        os.path.join(home, ".local/share/flatpak/exports/share"),
        "/var/lib/flatpak/exports/share",
    ]
    env_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    raw.extend(d for d in env_dirs if d)
    raw.extend(["/usr/local/share", "/usr/share"])

    seen = set()
    out = []
    for d in raw:
        norm = os.path.normpath(d)
        if norm not in seen and os.path.isdir(norm):
            seen.add(norm)
            out.append(norm)
    return out


def build_hicolor_index(data_dirs):
    """Build {icon_basename: full_path} preferring original hicolor app icons."""
    index = {}
    home = os.path.expanduser("~")
    icon_roots = [os.path.join(home, ".icons", "hicolor")] + [
        os.path.join(d, "icons", "hicolor") for d in data_dirs
    ]
    for subdir in HICOLOR_SIZE_ORDER:
        for root in icon_roots:
            folder = os.path.join(root, subdir)
            if not os.path.isdir(folder):
                continue
            try:
                with os.scandir(folder) as it:
                    for entry in it:
                        if not (entry.is_file() or entry.is_symlink()):
                            continue
                        stem, ext = os.path.splitext(entry.name)
                        ext_clean = ext.lstrip(".").lower()
                        if ext_clean not in EXTENSIONS:
                            continue
                        if stem not in index:
                            index[stem] = entry.path
            except OSError:
                continue
    return index


def build_theme_index(theme, data_dirs):
    """Fallback index from active icon theme (e.g. breeze, Adwaita) for system utilities."""
    if not theme:
        return {}
    home = os.path.expanduser("~")
    icon_bases = [os.path.join(home, ".icons")] + [os.path.join(d, "icons") for d in data_dirs]
    visited = set()
    queue = [theme]
    theme_roots = []

    while queue:
        current = queue.pop(0)
        if not current or current in visited or current == "hicolor":
            continue
        visited.add(current)
        for base in icon_bases:
            troot = os.path.join(base, current)
            idx_file = os.path.join(troot, "index.theme")
            if not os.path.isfile(idx_file):
                continue
            theme_roots.append((troot, idx_file))
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            parser.optionxform = str
            try:
                parser.read(idx_file, encoding="utf-8")
                if parser.has_section("Icon Theme"):
                    for inh in parser["Icon Theme"].get("Inherits", "").split(","):
                        inh = inh.strip()
                        if inh and inh not in visited:
                            queue.append(inh)
            except configparser.Error:
                pass

    preferred_subdirs = (
        "apps/scalable",
        "apps/64",
        "apps/48",
        "apps/32",
        "scalable/apps",
        "64x64/apps",
        "48x48/apps",
        "preferences/32",
        "categories/32",
        "devices/64",
        "places/64",
        "mimetypes/64",
    )
    index = {}
    for troot, _ in theme_roots:
        for sub in preferred_subdirs:
            folder = os.path.join(troot, sub)
            if not os.path.isdir(folder):
                continue
            try:
                with os.scandir(folder) as it:
                    for entry in it:
                        if not (entry.is_file() or entry.is_symlink()):
                            continue
                        stem, ext = os.path.splitext(entry.name)
                        if ext.lstrip(".").lower() not in EXTENSIONS:
                            continue
                        if stem not in index:
                            index[stem] = entry.path
            except OSError:
                continue
    return index


def build_pixmaps_index(data_dirs):
    index = {}
    for d in data_dirs:
        folder = os.path.join(d, "pixmaps")
        if not os.path.isdir(folder):
            continue
        try:
            with os.scandir(folder) as it:
                for entry in it:
                    if not (entry.is_file() or entry.is_symlink()):
                        continue
                    stem, ext = os.path.splitext(entry.name)
                    if ext.lstrip(".").lower() not in EXTENSIONS:
                        continue
                    if stem not in index:
                        index[stem] = entry.path
        except OSError:
            continue
    return index


def resolve_icon(icon_name, app_id, hicolor_idx, theme_idx, pixmaps_idx):
    if not icon_name:
        return ""
    if os.path.isabs(icon_name) and os.path.isfile(icon_name):
        return "file://" + icon_name

    # Strip extension if desktop file included .png/.svg
    clean_name = icon_name
    for ext in (".svg", ".png", ".xpm"):
        if clean_name.lower().endswith(ext):
            clean_name = clean_name[: -len(ext)]
            break

    candidates = [clean_name]
    if clean_name.lower() != clean_name:
        candidates.append(clean_name.lower())
    if app_id and app_id not in candidates:
        candidates.append(app_id)

    # 1. Prefer original app icon in hicolor
    for cand in candidates:
        if cand in hicolor_idx:
            return "file://" + hicolor_idx[cand]

    # 2. Fallback to active icon theme (system tools, KDE/GNOME themed utilities)
    for cand in candidates:
        if cand in theme_idx:
            return "file://" + theme_idx[cand]

    # 3. Fallback to pixmaps
    for cand in candidates:
        if cand in pixmaps_idx:
            return "file://" + pixmaps_idx[cand]

    # 4. Prefix-stripped fallback (e.g. foo-bar-baz -> foo-bar -> foo)
    parts = clean_name.split("-")
    while len(parts) > 1:
        parts = parts[:-1]
        short = "-".join(parts)
        if short in hicolor_idx:
            return "file://" + hicolor_idx[short]
        if short in theme_idx:
            return "file://" + theme_idx[short]
        if short in pixmaps_idx:
            return "file://" + pixmaps_idx[short]

    return ""


def parse_exec(exec_str):
    if not exec_str:
        return []
    try:
        tokens = shlex.split(exec_str)
    except ValueError:
        tokens = exec_str.split()
    out = []
    for tok in tokens:
        if tok in FIELD_CODES:
            continue
        cleaned = tok
        for code in FIELD_CODES:
            if code in cleaned:
                cleaned = cleaned.replace(code, "")
        if cleaned:
            out.append(cleaned)
    return out


def parse_desktop_file(filepath, app_id, hicolor_idx, theme_idx, pixmaps_idx):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        parser.read(filepath, encoding="utf-8")
    except (configparser.Error, OSError, UnicodeDecodeError):
        return None

    if not parser.has_section("Desktop Entry"):
        return None
    sec = parser["Desktop Entry"]

    if sec.get("Type", "").strip() != "Application":
        return None
    if sec.get("Hidden", "").strip().lower() == "true":
        return None
    if sec.get("NoDisplay", "").strip().lower() == "true":
        return None

    name = sec.get("Name", "").strip()
    exec_str = sec.get("Exec", "").strip()
    if not name or not exec_str:
        return None

    try_exec = sec.get("TryExec", "").strip()
    if try_exec and not (os.path.isabs(try_exec) and os.access(try_exec, os.X_OK)):
        if not shutil.which(try_exec):
            return None

    cmd = parse_exec(exec_str)
    if not cmd:
        return None

    icon = sec.get("Icon", "").strip()
    icon_file = resolve_icon(icon, app_id, hicolor_idx, theme_idx, pixmaps_idx)
    categories = [c.strip() for c in sec.get("Categories", "").split(";") if c.strip()]
    keywords = [k.strip() for k in sec.get("Keywords", "").split(";") if k.strip()]
    run_in_terminal = sec.get("Terminal", "").strip().lower() == "true"

    actions = []
    action_ids = [a.strip() for a in sec.get("Actions", "").split(";") if a.strip()]
    for aid in action_ids:
        asec_name = f"Desktop Action {aid}"
        if not parser.has_section(asec_name):
            continue
        asec = parser[asec_name]
        aname = asec.get("Name", "").strip()
        acmd = parse_exec(asec.get("Exec", "").strip())
        if aname and acmd:
            aicon = asec.get("Icon", "").strip() or icon
            actions.append({
                "name": aname,
                "icon": aicon,
                "command": acmd,
                "runInTerminal": asec.get("Terminal", "").strip().lower() == "true",
            })

    return {
        "id": app_id,
        "name": name,
        "genericName": sec.get("GenericName", "").strip(),
        "comment": sec.get("Comment", "").strip(),
        "icon": icon,
        "iconFile": icon_file,
        "command": cmd,
        "runInTerminal": run_in_terminal,
        "categories": categories,
        "keywords": keywords,
        "startupWMClass": sec.get("StartupWMClass", "").strip(),
        "actions": actions,
    }


def main():
    theme = sys.argv[1] if len(sys.argv) > 1 else ""
    dirs = xdg_data_dirs()
    hicolor_idx = build_hicolor_index(dirs)
    theme_idx = build_theme_index(theme, dirs)
    pixmaps_idx = build_pixmaps_index(dirs)

    seen_ids = set()
    apps = []

    for d in dirs:
        app_dir = os.path.join(d, "applications")
        if not os.path.isdir(app_dir):
            continue
        try:
            entries = sorted(os.scandir(app_dir), key=lambda e: e.name)
        except OSError:
            continue
        for entry in entries:
            if not entry.name.endswith(".desktop"):
                continue
            if not (entry.is_file() or entry.is_symlink()):
                continue
            app_id = entry.name[:-8]
            if app_id in seen_ids:
                continue
            seen_ids.add(app_id)
            parsed = parse_desktop_file(entry.path, app_id, hicolor_idx, theme_idx, pixmaps_idx)
            if parsed is not None:
                apps.append(parsed)

    json.dump(apps, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
