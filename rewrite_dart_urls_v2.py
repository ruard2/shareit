
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

# 1) Literal URLs in quotes
LITERAL_URL = re.compile(
    r'(?P<q>["\'])'
    r'(?P<scheme>https?)://'
    r'(?P<host>(' + "|".join(HOSTS) + r'))'
    r'(?::(?P<port>\d+))?'
    r'(?P<path>/[^"\']*)?'
    r'(?P=q)'
)

# 2) Base URL constants like: static const _baseUrl = 'http://10.0.2.2:8000';
BASE_CONST = re.compile(
    r'(static\s+const\s+_baseUrl\s*=\s*)(["\'])https?://(' + "|".join(HOSTS) + r')(?::\d+)?/?(\2)\s*;'
)

# 3) Uri.http('10.0.2.2:8000', '/path') or Uri.https('10.0.2.2', 'path')
URI_HTTP = re.compile(
    r'Uri\.(http|https)\s*\(\s*'
    r'(?P<q>["\'])'
    r'(?P<host>(' + "|".join(HOSTS) + r'))'
    r'(?::(?P<port>\d+))?'
    r'(?P=q)\s*,\s*'
    r'(?P<q2>["\'])\s*(?P<path>[^"\']*)\s*(?P=q2)'
    r'(?:\s*,\s*[^)]*)?'
    r'\)'
)

IMPORT_ENV = re.compile(r'^\s*import\s+[\'"][^\'"]*env\.dart[\'"]\s*;\s*$', re.MULTILINE)

def rel_import(file_path: Path, env_path: Path) -> str:
    rel = os.path.relpath(env_path, start=file_path.parent).replace(os.sep, "/")
    if not rel.startswith("."):
        rel = "./" + rel
    return rel

def ensure_env(lib_dir: Path, default_api: str, dry_run: bool) -> Path:
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
        env_path.write_text(content, encoding="utf-8")
        print(f"[created] {env_path}")
    return env_path

def add_import_if_needed(text: str, file_path: Path, env_path: Path) -> str:
    if IMPORT_ENV.search(text):
        return text
    # insert after last import
    import_lines = list(re.finditer(r'^\s*import\s+[^;]+;\s*$', text, re.MULTILINE))
    line = f"import '{rel_import(file_path, env_path)}';\n"
    if import_lines:
        insert_at = import_lines[-1].end()
        if insert_at < len(text) and text[insert_at-1] != "\n":
            line = "\n" + line
        return text[:insert_at] + line + text[insert_at:]
    return line + text

def replace_in_text(text: str) -> (str, int):
    total = 0

    def sub_literal(m: re.Match) -> str:
        nonlocal total
        q = m.group("q")
        path = m.group("path") or ""
        if path and not path.startswith("/"):
            path = "/" + path
        total += 1
        return f"{q}${{Env.apiBase}}{path}{q}"

    text = LITERAL_URL.sub(sub_literal, text)

    def sub_base(m: re.Match) -> str:
        nonlocal total
        total += 1
        return m.group(1) + "'${Env.apiBase}';"

    text = BASE_CONST.sub(sub_base, text)

    def sub_uri(m: re.Match) -> str:
        nonlocal total
        path = m.group("path") or ""
        if path and not path.startswith("/"):
            path = "/" + path
        total += 1
        return f"Uri.parse('\${{Env.apiBase}}{path}')"

    text = URI_HTTP.sub(sub_uri, text)

    return text, total

def process_file(path: Path, env_path: Path, dry_run: bool) -> int:
    orig = path.read_text(encoding="utf-8")
    new, n = replace_in_text(orig)
    if n > 0:
        new = add_import_if_needed(new, path, env_path)
        if dry_run:
            print(f"[dry-run] Would update {path} (+{n} changes)")
        else:
            # backup
            path.with_suffix(path.suffix + ".bak").write_text(orig, encoding="utf-8")
            path.write_text(new, encoding="utf-8")
            print(f"[updated] {path} (+{n} changes)")
    else:
        print(f"[skip] {path}")
    return n

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--project", default=".", help="Flutter project root (folder containing lib/)")
    p.add_argument("--default-api", default="https://api.share.it.com")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    root = Path(args.project).resolve()
    lib = root / "lib"
    if not lib.exists():
        print(f"[error] lib/ not found under {root}")
        raise SystemExit(1)

    env_path = ensure_env(lib, args.default_api, args.dry_run)

    total = 0
    for dart in lib.rglob("*.dart"):
        if dart.name == "env.dart":
            continue
        if any(seg in {".dart_tool", "build"} for seg in dart.parts):
            continue
        total += process_file(dart, env_path, args.dry_run)

    print(f"\nDone. Total file-change operations: {total}")

if __name__ == "__main__":
    main()
