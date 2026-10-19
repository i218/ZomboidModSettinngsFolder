"""Read-only pre-push scan of tracked files and all locally reachable commits.

Reports locations/categories only, never matched secrets. No network or dependencies.
This is a targeted check, not a guarantee against every possible secret format.
"""
from pathlib import Path
import json
import re
import subprocess
import struct
import zlib
import sys

ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


RULES = {
    "credential": re.compile(
        r"(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
        r"AKIA[0-9A-Z]{16}|(?:sk-|xox[baprs]-)[A-Za-z0-9_-]{20,}|"
        r"-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----|"
        r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})"
    ),
    "secret-assignment": re.compile(
        r"(?:password|passwd|api[_-]?key|access[_-]?token|client[_-]?secret)"
        r"\s*[=:]\s*[\"'][^\"']{6,}", re.I
    ),
    "machine-path": re.compile(r"(?:[A-Z]:[/\\](?:Users|SteamLibrary)|/(?:home|Users)/)", re.I),
    "ip-address": re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"),
    "embedded-url-credential": re.compile(r"https?://[^/\s:]+:[^/\s@]+@", re.I),
}
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
SENSITIVE = re.compile(
    r"(?:^|/)(?:\.env(?:\..*)?|credentials\..*|secrets\..*|\.codex(?:/.*)?)$|"
    r"\.(?:pem|key|pfx|p12|log|cfg|ini|sqlite\w*|db|dmp|jar|class|exe|dll|lnk|zip)$", re.I
)
findings = set()


def scan(label, raw):
    if label.endswith("/workshop/preview.png"):
        # This one project asset is a rasterized vector cover. Reject metadata chunks.
        valid = raw.startswith(b"\x89PNG\r\n\x1a\n")
        offset = 8
        chunks = []
        while valid and offset < len(raw):
            if offset + 12 > len(raw):
                valid = False
                break
            size = struct.unpack(">I", raw[offset:offset+4])[0]
            kind = raw[offset+4:offset+8]
            end = offset + 12 + size
            if end > len(raw) or kind not in (b"IHDR", b"IDAT", b"IEND"):
                valid = False
                break
            data = raw[offset+8:offset+8+size]
            crc = struct.unpack(">I", raw[offset+8+size:end])[0]
            if zlib.crc32(kind + data) & 0xffffffff != crc:
                valid = False
                break
            if kind == b"IHDR" and (len(data) != 13 or struct.unpack(">II", data[:8]) != (512,512)):
                valid = False
                break
            chunks.append(kind)
            offset = end
        if not valid or offset != len(raw) or len(raw) > 1024000 or not chunks or chunks[0] != b"IHDR" or chunks[-1] != b"IEND":
            findings.add((label, 0, "invalid-cover-or-image-metadata"))
        return
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        findings.add((label, 0, "unexpected-non-text-file"))
        return
    for line_number, line in enumerate(text.splitlines(), 1):
        for category, pattern in RULES.items():
            candidate = line
            if category == "ip-address" and label.endswith("/installer/app.manifest"):
                # A Windows assembly identity requires a four-part version, not an IP.
                candidate = re.sub(r'\bversion="[0-9]+(?:\.[0-9]+){3}"', 'version=""', line)
            if pattern.search(candidate):
                findings.add((label, line_number, category))
        for match in EMAIL.finditer(line):
            if not match.group().endswith("@users.noreply.github.com"):
                findings.add((label, line_number, "personal-email"))


paths = git("ls-files", "-z").decode().split("\0")[:-1]
for path in paths:
    if SENSITIVE.search(path):
        findings.add((path, 0, "sensitive-file-name"))
    scan("working/" + path, (ROOT / path).read_bytes())

seen_blobs = set()
commits = git("rev-list", "--all").decode().splitlines()
for commit in commits:
    # Also scan commit messages and identity fields; noreply is intentionally public.
    scan(commit[:8] + "/metadata", git("show", "-s", "--format=%an%n%ae%n%cn%n%ce%n%B", commit))
    for entry in git("ls-tree", "-rz", "--full-tree", commit).split(b"\0"):
        if not entry:
            continue
        info, raw_path = entry.split(b"\t", 1)
        mode, kind, oid = info.decode().split()
        path = raw_path.decode()
        if SENSITIVE.search(path):
            findings.add((commit[:8] + "/" + path, 0, "sensitive-file-name"))
        if kind != "blob" or mode not in ("100644", "100755"):
            findings.add((commit[:8] + "/" + path, 0, "unexpected-link-or-submodule"))
        elif oid not in seen_blobs:
            seen_blobs.add(oid)
            scan(commit[:8] + "/" + path, git("cat-file", "blob", oid))

print(json.dumps({
    "trackedFiles": len(paths), "reachableCommits": len(commits),
    "uniqueHistoryBlobs": len(seen_blobs),
    "findings": [{"location": p, "line": n, "category": c} for p, n, c in sorted(findings)],
}, indent=2))
sys.exit(1 if findings else 0)
