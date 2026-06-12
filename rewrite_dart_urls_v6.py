
import os
import re
import argparse
from pathlib import Path

HOSTS = [
    r"10\.0\.2\.2",
    r"127\.0\.0\.1",
    r"localhost",
    r"api\.share\.it\.com",
    r"share\.it\.com",
    r"api\.shareit\.it\.com",
    r"shareit\.it\.com",
]

LITERAL_URL = re.compile(
    r'(?P<q>["\'])'
    r'(?P<scheme>https?)://'
    r'(?P<host>(' + "|".join(HOSTS) + r'))'
    r'(?::(?P<port>\d+))?'
    r'(?P<path>/[^"\']*)?'
    r'(?P=q)'
)

BASE_ASSIGN = re.compile(
    r'(?P<prefix>\b(?:static\s+)?(?:const|final|var)\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*)'
    r'(?P<q>["\'])https?://(' + "|".join(HOSTS) + r')(?::\d+)?/?(?P=q)\s*;'
)

BASE_INTERP = re.compile(
    r'(?P<prefix>\b(?:static\s+)?(?:const|final|var)\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*)'
    r'["\']\$\{Env\.apiBase\}["\']\s*;'
)

URI_HTTP = re.compile(
    r'Uri\.(?:http|https)\s*\(\s*'
    r'(?P<q1>["\'])'
    r'(?P<host>(' + "|".join(HOSTS) + r'))'
    r'(?::(?P<port>\d+))?'
    r'(?P=q1)\s*,\s*'
    r'(?P<q2>["\'])(?P<path>[^"\']*)(?P=q2)'
    r'(?:\s*,\s*[^)]*)?'
    r'\)'
)

BASE_BARE = re.compile(
    r'(?P<name>_?baseUrl)\s*=\s*(?P<q>["\'])https?://(' + "|".join(HOSTS) + r')(?::\d+)?/?(?P=q)\s*;'
)

INTERP_BASE_STR = re.compile(
    r'(?P<q>["\'])\s*\$\{?_?baseUrl\}?(?P<slash>/[^"\']*)\s*(?P=q)'
)

IMPORT_ENV = re.compile(r'^\s*import\s+[\'"][^\'"]*env\.dart[\'"]\s*;\s*$', re.MULTILINE)

def rel_import(from_file: Path, env_file: Path) -> str:
    rel = os.path.relpath(env_file, start=from_file.parent).replace(os.sep, "/")
    if not rel.startswith("."):
        rel = "./" + rel
    return rel

def ensure_env(lib_dir: Path, default_api: str, dry_run: bool) -> Path:
    env_path = lib_dir / "env.dart"
    if not env_path.exists():
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

def add_env_import(text: str, file_path: Path, env_path: Path) -> str:
    if IMPORT_ENV.search(text):
        return text
    line = f"import '{rel_import(file_path, env_path)}';\n"
    imports = list(re.finditer(r'^\s*import\s+[^;]+;\s*$', text, re.MULTILINE))
    if imports:
        pos = imports[-1].end()
        if pos < len(text) and text[pos-1] != "\n":
            line = "\n" + line
        return text[:pos] + line + text[pos:]
    return line + text

def rewrite_text(text: str) -> (str, int):
    changes = 0

    def sub_literal(m):
        nonlocal changes
        q = m.group('q')
        path = m.group('path') or ""
        if path and not path.startswith('/'):
            path = '/' + path
        changes += 1
        return f"{q}" + "${{Env.apiBase}}" + f"{path}{q}"
    text = LITERAL_URL.sub(sub_literal, text)

    def sub_base(m):
        nonlocal changes
        changes += 1
        return m.group('prefix') + "Env.apiBase;"
    text = BASE_ASSIGN.sub(sub_base, text)

    text = BASE_INTERP.sub(lambda m: m.group('prefix') + "Env.apiBase;", text)

    def sub_uri(m):
        nonlocal changes
        path = m.group('path') or ""
        if path and not path.startswith('/'):
            path = '/' + path
        changes += 1
        return "Uri.parse('${Env.apiBase}" + f"{path}')"
    text = URI_HTTP.sub(sub_uri, text)

    def sub_bare(m):
        nonlocal changes
        changes += 1
        return f"{m.group('name')} = Env.apiBase;"
    text = BASE_BARE.sub(sub_bare, text)

    def sub_interp(m):
        nonlocal changes
        q = m.group('q')
        slash = m.group('slash') or ""
        changes += 1
        return f"{q}${{Env.apiBase}}{slash}{q}"
    text = INTERP_BASE_STR.sub(sub_interp, text)

    # Cleanup double ')'
    text = re.sub(r"(Uri\.parse\((?:\"[^\"]*\"|'[^']*')\))\)", r"\1", text)

    return text, changes

def process_file(path: Path, env_path: Path, dry_run: bool) -> int:
    original = path.read_text(encoding='utf-8')
    new_text, n = rewrite_text(original)

    cleaned = re.sub(r"(Uri\.parse\((?:\"[^\"]*\"|'[^']*')\))\)", r"\1", new_text)
    if cleaned != new_text:
        n += 1
        new_text = cleaned

    if n > 0:
        new_text = add_env_import(new_text, path, env_path)
        if dry_run:
            print(f"[dry-run] Would update {path} (+{n})")
        else:
            path.with_suffix(path.suffix + ".bak").write_text(original, encoding='utf-8')
            path.write_text(new_text, encoding='utf-8')
            print(f"[updated] {path} (+{n})")
    else:
        print(f"[skip] {path}")
    return n

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", default=".", help="Flutter project root (contains lib/)")
    ap.add_argument("--default-api", default="https://api.share.it.com")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    root = Path(args.project).resolve()
    lib = root / "lib"
    if not lib.exists():
        print(f"[error] lib/ not found under {root}")
        raise SystemExit(1)

    env_path = ensure_env(lib, args.default_api, args.dry_run)

    total = 0
    for p in lib.rglob("*.dart"):
        if p.name == "env.dart":
            continue
        if any(seg in {".dart_tool", "build"} for seg in p.parts):
            continue
        total += process_file(p, env_path, args.dry_run)

    print(f"\nDone. Total changes across files: {total}")

if __name__ == "__main__":
    main()
