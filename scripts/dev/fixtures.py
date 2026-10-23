#!/usr/bin/env python3
"""Records and checks the shared fixtures (tests/fixtures/shared/): the
cases the JS helpers and the axiom binary (Go) must agree on, byte for
byte (docs/dev/backend/README.md › Shared fixtures).

  scripts/dev/fixtures.py record     re-record every JS-owned suite: runs
                                     tst_Config, tst_ConfigExamples,
                                     tst_SchemaValidation and tst_Shared's
                                     corpus with recording on, and writes the
                                     calls they make as cases
  scripts/dev/fixtures.py ensure     record only when what the cases are
                                     made from changed since the last
                                     recording (scripts/generate.sh runs it)
  scripts/dev/fixtures.py check      the index lists exactly the cases on
                                     disk, each with its expected file, and
                                     every blob is used (CI)

The whole directory is generated and gitignored: CI records it before the
tests that replay it (both the JS and the Go side). Recording needs Qt 6's
qmltestrunner and the whole git history (the corpus is read from past
commits).

A case is <suite>/<test>/<name>.json ({op, args}) plus <name>.expected.json
(the exact bytes the JS helper produced). Arguments larger than BLOB_SIZE
are stored once under blobs/<hash>.json and referenced as {"$blob": hash}.
The expected bytes come from the JS engine the shell runs (V4, through
qmltestrunner) and are written untouched; arguments only need to parse to
the same values, so they are re-serialized here.

The legacy suites' goldens come from frozen code (ConfigMigration.qml, its
hash checked by the binary's tests) and the frozen v75 schema, so recording
them again always gives the same bytes.
"""
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHARED = ROOT / "tests/fixtures/shared"
# Suites recorded from the JS helpers (the rest are written by Go's tests)
JS_SUITES = ("legacy", "schema", "share", "corpus")
RECORD_TESTS = ("Config", "ConfigExamples", "SchemaValidation", "Shared")
BLOB_SIZE = 2048
SCHEMA_PATHS = ("config/json/config.schema.json", "config/schemas/config.schema.json")
# Old configs the corpus loads whole, besides each schema version's defaults
CORPUS_CONFIGS = ("tests/fixtures/configs/v1.json", "tests/fixtures/configs/v30.json")
# The frozen format-1 schema the legacy cases run against: the binary's own
# copy (backend/internal/migrate/legacy, hash-checked by its tests)
LEGACY_SCHEMA = (ROOT / "backend/internal/migrate/legacy/schema-v75.json", "schemas/legacy-v75.schema.json")
# What the recorded cases are made from: a change to any re-records them
STAMP_INPUTS = ("components/methods/*.qml", "tests/Shared.qml", "tests/RepoFiles.qml",
                "backend/internal/migrate/legacy/schema-v75.json",
                "tests/tst_Config.qml", "tests/tst_ConfigExamples.qml",
                "tests/tst_SchemaValidation.qml", "tests/tst_Shared.qml",
                "config/json/config.schema.json", "scripts/dev/fixtures.py",
                "scripts/qml_modules.py", "scripts/run_tests.sh",
                "tests/fixtures/configs/*.json", "examples/*.json")


def main(argv):
    if len(argv) != 2 or argv[1] not in ("record", "ensure", "check"):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    if argv[1] == "ensure":
        if (SHARED / ".stamp").exists() and (SHARED / ".stamp").read_text() == stamp():
            return 0
        return record()
    return record() if argv[1] == "record" else check()


def stamp():
    """A hash of everything the cases are made from, and of the history the
    corpus is read from."""
    h = hashlib.sha256()
    for pattern in STAMP_INPUTS:
        for path in sorted(ROOT.glob(pattern)):
            h.update(path.relative_to(ROOT).as_posix().encode() + b"\0" + path.read_bytes() + b"\0")
    h.update(subprocess.run(["git", "log", "HEAD", "--format=%H", "--", *SCHEMA_PATHS],
                            cwd=ROOT, capture_output=True, check=True).stdout)
    return h.hexdigest() + "\n"


def legacy_schema():
    """Writes the frozen v75 schema into schemas/."""
    source, target = LEGACY_SCHEMA
    out = SHARED / target
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(source.read_bytes())


# --- record ---

def record():
    SHARED.mkdir(parents=True, exist_ok=True)
    (SHARED / ".stamp").unlink(missing_ok=True)
    legacy_schema()
    corpus = SHARED / ".corpus"
    marker = SHARED / ".recording"
    shutil.rmtree(corpus, ignore_errors=True)
    corpus.mkdir(parents=True)
    write_corpus_list(corpus)
    marker.write_text("1\n")
    try:
        out = run_tests()
    finally:
        marker.unlink(missing_ok=True)
        shutil.rmtree(corpus, ignore_errors=True)

    records = [decode(line) for line in out.splitlines() if "@@FIXTURE " in line]
    if not records:
        print("no calls were recorded (did the tests run?)", file=sys.stderr)
        return 1
    for suite in JS_SUITES:
        shutil.rmtree(SHARED / suite, ignore_errors=True)
    blobs = SHARED / "blobs"
    shutil.rmtree(blobs, ignore_errors=True)
    blobs.mkdir()

    seen = {}  # (suite, case text) → name, so a repeated call is one case
    counters = {}
    written = 0
    for rec in records:
        spec = json.loads(rec["case"])
        spec["args"] = [store_blobs(arg, blobs) for arg in spec["args"]]
        case_text = dump(spec)
        key = (rec["suite"], case_text)
        if key in seen:
            continue
        name = case_name(rec, counters)
        seen[key] = name
        path = SHARED / rec["suite"] / name
        path.parent.mkdir(parents=True, exist_ok=True)
        (path.parent / (path.name + ".json")).write_text(case_text, encoding="utf-8")
        # The JS text exactly; a lone surrogate (which V4 writes unescaped)
        # can't be stored, so such a case must not be a JS-owned golden
        (path.parent / (path.name + ".expected.json")).write_bytes(rec["expected"].encode("utf-8"))
        written += 1
    write_index()
    (SHARED / ".stamp").write_text(stamp())
    print(f"recorded {written} cases ({len(records)} calls) into {SHARED.relative_to(ROOT)}")
    return 0


def run_tests():
    """Runs the recording tests, failing if any of them fails."""
    proc = subprocess.run([str(ROOT / "scripts/run_tests.sh"), *RECORD_TESTS],
                          cwd=ROOT, capture_output=True, text=True, errors="surrogateescape")
    output = proc.stdout + proc.stderr
    if proc.returncode != 0:
        print("\n".join(l for l in output.splitlines() if "@@FIXTURE" not in l)[-4000:], file=sys.stderr)
        raise SystemExit("the recording tests failed; nothing was written")
    return output


def decode(line):
    """A @@FIXTURE line's payload: hex UTF-16 code units → the JSON object."""
    hexed = line.split("@@FIXTURE ", 1)[1].strip()
    units = bytes.fromhex(hexed)
    # big-endian units, 4 hex digits each
    text = units.decode("utf-16-be", errors="surrogatepass")
    rec = json.loads(text)
    for field in ("case", "expected"):
        try:
            rec[field].encode("utf-8")
        except UnicodeEncodeError:
            raise SystemExit(f"{rec['test']}.{rec['function']}: a lone surrogate can't be a JS golden")
    return rec


def case_name(rec, counters):
    """<test>/<function or label>[.<tag>].<n>, n counting from 0."""
    base = rec["label"] or rec["function"] or "case"
    if rec["tag"]:
        base += "." + rec["tag"]
    base = rec["test"] + "/" + re.sub(r"[^A-Za-z0-9_.\-/]+", "_", base)
    n = counters.get((rec["suite"], base), 0)
    counters[(rec["suite"], base)] = n + 1
    return f"{base}.{n}"


def store_blobs(value, blobs):
    """value with every object/array larger than BLOB_SIZE stored as a blob."""
    if isinstance(value, dict) and set(value) <= {"$fixtureSchema", "pointer"} and "$fixtureSchema" in value:
        return value
    if isinstance(value, (dict, list)):
        if isinstance(value, dict):
            value = {k: store_blobs(v, blobs) for k, v in value.items()}
        else:
            value = [store_blobs(v, blobs) for v in value]
        compact = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        if len(compact) > BLOB_SIZE:
            digest = hashlib.sha256(compact.encode("utf-8")).hexdigest()[:20]
            path = blobs / f"{digest}.json"
            if not path.exists():
                path.write_text(dump(value), encoding="utf-8")
            return {"$blob": digest}
    return value


def dump(value):
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def write_corpus_list(corpus):
    """Every distinct past schema version (the last commit of each), from
    HEAD's history (not other branches, so every clone records the same),
    for tst_Shared to load the defaults of."""
    log = subprocess.run(["git", "log", "HEAD", "--format=%H %ct", "--", *SCHEMA_PATHS],
                         cwd=ROOT, capture_output=True, text=True, check=True).stdout.split("\n")
    by_version = {}
    for line in log:
        if not line.strip():
            continue
        commit, when = line.split()
        schema = None
        for path in SCHEMA_PATHS:
            show = subprocess.run(["git", "show", f"{commit}:{path}"], cwd=ROOT, capture_output=True, text=True)
            if show.returncode == 0:
                try:
                    schema = json.loads(show.stdout)
                except json.JSONDecodeError:
                    schema = None
                break
        version = (((schema or {}).get("properties") or {}).get("version") or {}).get("default")
        if not isinstance(version, int):
            continue
        # git log is newest first: the first commit seen per version is its last
        if version not in by_version:
            by_version[version] = (int(when), commit, schema)
    schemas = []
    for version in sorted(by_version):
        _, commit, schema = by_version[version]
        name = f"v{version}.schema.json"
        (corpus / name).write_text(json.dumps(schema, ensure_ascii=False), encoding="utf-8")
        schemas.append({"version": version, "commit": commit, "file": name})
    examples = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "examples").glob("*.json"))
    (corpus / "list.json").write_text(json.dumps({
        "schemas": schemas,
        "configs": list(CORPUS_CONFIGS) + examples,
    }, indent=2))


# --- index and check ---

def cases_on_disk():
    names = []
    for path in SHARED.rglob("*.json"):
        rel = path.relative_to(SHARED).as_posix()
        if rel.startswith(("schemas/", "blobs/", ".")) or rel == "index.json" or rel.endswith(".expected.json"):
            continue
        names.append(rel[:-len(".json")])
    return sorted(names)


def write_index():
    (SHARED / "index.json").write_text(dump({
        "_comment": "Every shared case, written by scripts/dev/fixtures.py (and by the axiom binary's tests for the suites Go owns). See docs/dev/backend/README.md.",
        "cases": cases_on_disk(),
    }), encoding="utf-8")


def check():
    if not (SHARED / "index.json").exists():
        print(f"{SHARED.relative_to(ROOT)} isn't recorded: scripts/generate.sh --fixtures (or scripts/dev/fixtures.py record)")
        return 1
    problems = []
    index = json.loads((SHARED / "index.json").read_text())
    listed, found = index["cases"], cases_on_disk()
    for name in sorted(set(found) - set(listed)):
        problems.append(f"{name}: not in index.json")
    for name in sorted(set(listed) - set(found)):
        problems.append(f"{name}: in index.json but missing")
    used = set()
    for name in found:
        if not (SHARED / (name + ".expected.json")).exists():
            problems.append(f"{name}: no .expected.json")
        text = (SHARED / (name + ".json")).read_text(encoding="utf-8")
        used.update(re.findall(r'"\$blob": "([0-9a-f]+)"', text))
    blob_dir = SHARED / "blobs"
    blob_names = {p.stem for p in blob_dir.glob("*.json")} if blob_dir.exists() else set()
    for blob in sorted(blob_names):
        nested = (blob_dir / f"{blob}.json").read_text(encoding="utf-8")
        used.update(re.findall(r'"\$blob": "([0-9a-f]+)"', nested))
    for blob in sorted(blob_names - used):
        problems.append(f"blobs/{blob}.json: unused")
    for blob in sorted(used - blob_names):
        problems.append(f"blobs/{blob}.json: missing")
    for p in problems:
        print(p)
    if problems:
        print(f"{len(problems)} problems in {SHARED.relative_to(ROOT)} (scripts/dev/fixtures.py record rewrites the JS suites)")
        return 1
    print(f"{len(found)} shared cases ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
