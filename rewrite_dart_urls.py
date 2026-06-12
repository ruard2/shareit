
import os
import re
import argparse
from pathlib import Path

HOST_PATTERNS = [
    r"10\.0\.2\.2",
    r"127\.0\.0\.1",
    r"localhost",
    r"api\.shareit\.it\.com",
    r"share\.it\.com",
]

URL_REGEX = re.compile(
    r'(?P<q>["\'])'                                  # opening quote
    r'(?P<scheme>https?)://'                         # scheme
    r'(?P<host>(' + "|".join(HOST_PATTERNS) + r'))'  # host
    r'(?::(?P<port>\d+))?'                           # optional port
    r'(?P<path>/[^"\']*)?'                           # optional path
    r'(?P=q)'                                        # closing quote equals opening
)

IMPORT_REGEX = re.compile(r'^\s*import\s+[\'"][^\'"]*env\.dart[\'"]\s*;\s*$', re.MULTILINE)

def rel_import_path(file_path: Path, env_path: Path) -> str:
    rel = os.path.relpath(env_path, start=file_path.parent)
    rel = rel.replace(os.sep, "/")
    if not rel.startswith("."):
        rel = "./" + rel
    return rel

def ensure_env_file(lib_dir: Path, default_api: str, dry_run: bool) -> Path:
    env_path = lib_dir / "env.dart"
    if env_path.exists():
        return env_path
    content = (
        "class Env {\n"
        "  static const apiBase = String.fromEnvironment(\n"
        "    'API_BASE',\n"
        f"    defaultValue: '{default_api}',\n"
        "  );\n"
        "}\n"
    )
    if dry_run:
        print(f"[dry-run] Would create {env_path}")
    else:
        env_path.write_text(content, encoding='utf-8')
        print(f"[created] {env_path}")
    return env_path

def rewrite_file(file_path: Path, env_path: Path, dry_run: bool) -> int:
    original = file_path.read_text(encoding='utf-8')
    changed = original

    # 1) Replace URLs
    def _sub(m: re.Match) -> str:
        q = m.group('q')
        path = m.group('path') or ""
        # Build '${Env.apiBase}/rest/of/path' (avoid double '//')
        if path and not path.startswith('/'):
            path = '/' + path
        return f"{q}${{Env.apiBase}}{path}{q}"

    changed, n_subs = URL_REGEX.subn(_sub, changed)

    total_changes = n_subs

    # 2) Add import if needed and if we actually made replacements
    if n_subs > 0 and not IMPORT_REGEX.search(changed):
        rel_path = rel_import_path(file_path, env_path)
        import_line = f"import '{rel_path}';\n"
        # Insert after last import, else at top
        import_positions = [m.end() for m in re.finditer(r'^\s*import\s+[^;]+;\s*$', changed, re.MULTILINE)]
        if import_positions:
            insert_at = import_positions[-1]
            # ensure spacing
            if insert_at < len(changed) and changed[insert_at-1] != '\n':
                import_line = "\n" + import_line
            changed = changed[:insert_at] + import_line + changed[insert_at:]
        else:
            changed = import_line + changed
        total_changes += 1  # count the import add as a change

    if total_changes > 0 and not dry_run:
        # backup
        backup_path = file_path.with_suffix(file_path.suffix + ".bak")
        backup_path.write_text(original, encoding='utf-8')
        file_path.write_text(changed, encoding='utf-8')
        print(f"[updated] {file_path} (+{n_subs} URL repl, +{'1 import' if total_changes>n_subs else '0 import'})")
    elif total_changes > 0 and dry_run:
        print(f"[dry-run] Would update {file_path} (+{n_subs} URL repl, +{'1 import' if total_changes>n_subs else '0 import'})")
    else:
        print(f"[skip] {file_path} (no matches)")
    return total_changes

def main():
    parser = argparse.ArgumentParser(description="Replace hardcoded base URLs in Dart files with Env.apiBase and add env.dart import.")
    parser.add_argument("--project", default=".", help="Flutter project root (folder containing lib/)")
    parser.add_argument("--default-api", default="https://api.shareit.it.com", help="Default API base to write in lib/env.dart")
    parser.add_argument("--dry-run", action="store_true", help="Show what would change without writing")
    args = parser.parse_args()

    project = Path(args.project).resolve()
    lib_dir = project / "lib"
    if not lib_dir.exists():
        print(f"[error] lib/ not found under {project}")
        raise SystemExit(1)

    env_path = ensure_env_file(lib_dir, args.default_api, dry_run=args.dry_run)

    total = 0
    for path in lib_dir.rglob("*.dart"):
        if path.name == "env.dart":
            continue
        # ignore build/generated folders just in case
        if any(seg in {".dart_tool", "build"} for seg in path.parts):
            continue
        total += rewrite_file(path, env_path, dry_run=args.dry_run)

    print(f"\nDone. Files changed (total ops): {total}")

if __name__ == "__main__":
    main()
