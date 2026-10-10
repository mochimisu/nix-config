#!/usr/bin/env python3
"""Guarded ASAR member replacement; preserve unpacked entries and integrity data."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile


# Match this complete upstream helper, including its final .mcp.json write.
# Never replace the similar cp calls used by other plugin installation paths.
EXECUTOR_COPY = "await v.default.cp(n.cwd,e,{recursive:!0})"
EXECUTOR_HELPER = (
    "async function Gc({executorPluginRoot:e,resourcesPath:t}){"
    "let n=await qc({useWsl:!1,resourcesPath:t});return n==null?null:("
    + EXECUTOR_COPY +
    ",process.platform!==`win32`&&(n.command=b.default.join(e,"
    "b.default.relative(n.cwd,n.command))),n.cwd=e,n.enabled=!0,"
    "n.env={...n.env,CODEX_APP_TOOLS_CALLER_HOST_ID:r.En},"
    "await v.default.writeFile(b.default.join(e,`.mcp.json`),"
    "`${JSON.stringify({mcpServers:{codex_app:n}},null,2)}\\n`,`utf8`),e)}"
)
EXECUTOR_REPLACEMENT = (
    "await codexNixCopyExecutorPlugin({fs:v.default,path:b.default,"
    "sourceRoot:n.cwd,pluginRoot:e})"
)


def entries(node, prefix=""):
    for name, entry in node.get("files", {}).items():
        member = f"{prefix}/{name}" if prefix else name
        if "files" in entry:
            yield from entries(entry, member)
        else:
            yield member, entry


def header(stream):
    first = stream.read(16)
    if len(first) != 16:
        raise ValueError("Truncated ASAR header")
    outer, size, payload, length = struct.unpack("<4I", first)
    if outer != 4 or size != payload + 4 or payload != 4 + ((length + 3) & ~3):
        raise ValueError("Unsupported ASAR header layout")
    encoded = stream.read(length)
    if len(encoded) != length or len(stream.read((-length) % 4)) != (-length) % 4:
        raise ValueError("Truncated ASAR header")
    index = json.loads(encoded)
    if not isinstance(index, dict) or not isinstance(index.get("files"), dict):
        raise ValueError("Unsupported ASAR file index")
    return index, 8 + size


def integrity(data, block_size):
    if type(block_size) is not int or block_size <= 0:
        raise ValueError("Unsupported ASAR integrity block size")
    return {
        "algorithm": "SHA256",
        "hash": hashlib.sha256(data).hexdigest(),
        "blockSize": block_size,
        "blocks": [hashlib.sha256(data[i:i + block_size]).hexdigest()
                   for i in range(0, max(1, len(data)), block_size)],
    }


def main(archive, helper):
    export = "\nmodule.exports = codexNixPrepareBundledCopy;\n"
    helper_text = helper.read_text()
    if not helper_text.endswith(export):
        raise ValueError("Unexpected permission helper export")
    helper_text = helper_text[:-len(export)]
    if any(helper_text.count("async function " + name + "(") != 1 for name in (
            "codexNixPrepareBundledCopy", "codexNixCopyExecutorPlugin")):
        raise ValueError("Expected both permission helper definitions exactly once")
    copy_call = "await kne(n,r),await nne({"
    replacement = ("await kne(n,r),await codexNixPrepareBundledCopy({"
                   "fs:v.default,path:b,pluginRoot:r,pluginName:t.name,"
                   "computerUseAudioEnabled:t.name===`computer-use`&&Eo()}),await nne({")
    definition = "async function nne(e){"
    with archive.open("rb") as src:
        index, body_start = header(src)
        candidates = [(p, e) for p, e in entries(index)
                      if p.startswith(".vite/build/main-") and p.endswith(".js")]
        if len(candidates) != 1:
            raise ValueError("Expected exactly one bundled main module")
        member, entry = candidates[0]
        if entry.get("unpacked") or "link" in entry:
            raise ValueError("Main module must be packed and regular")
        offset, size = int(entry["offset"]), entry["size"]
        # Check bounds and all packed intervals before producing a new archive.
        # Unpacked/link entries are opaque metadata and are never rewritten.
        body_size = archive.stat().st_size - body_start
        intervals = []
        for path, item in entries(index):
            if item.get("unpacked") or "link" in item:
                continue
            start, length = int(item["offset"]), item["size"]
            if (type(length) is not int or start < 0 or length < 0 or
                    start + length > body_size):
                raise ValueError("Invalid or truncated ASAR member: " + path)
            if length:
                intervals.append((start, start + length, path))
        intervals.sort()
        for previous, current in zip(intervals, intervals[1:]):
            # ASAR can deduplicate unchanged files into an identical interval.
            # An alias of main cannot be preserved when only main is patched.
            identical_unrelated = (previous[:2] == current[:2] and
                                   previous[2] != member and current[2] != member)
            if previous[1] > current[0] and not identical_unrelated:
                raise ValueError("Overlapping ASAR members")
        src.seek(body_start + offset)
        original = src.read(size)
        old_integrity = entry["integrity"]
        block_size = old_integrity["blockSize"]
        if old_integrity != integrity(original, block_size):
            raise ValueError("Original member failed its ASAR integrity check")
        text = original.decode("utf-8")
        if any(name in text for name in (
                "codexNixPrepareBundledCopy", "codexNixCopyExecutorPlugin")):
            raise ValueError("Archive already patched")
        if text.count(copy_call) != 1 or text.count(definition) != 1:
            raise ValueError("Upstream copy/customization code changed; review patch")
        if (text.count(EXECUTOR_HELPER) != 1 or
                text.count("async function Gc(") != 1):
            raise ValueError("Upstream executor copy helper changed; review patch")
        # Guard the narrow mutation paths that determine the writable-file list.
        expected = [
            'e.pluginName===`computer-use`&&Eo()',
            'e.pluginName===`visualize`',
            '(e.pluginRoot,`skills`,`computer-use`,`SKILL.md`)',
            '(e.pluginRoot,`.codex-plugin`,`plugin.json`)',
        ]
        customization = text.split(definition, 1)[1].split("var Do=", 1)[0]
        if any(fragment not in customization for fragment in expected):
            raise ValueError("Upstream customization targets changed; review patch")
        patched = text.replace(copy_call, replacement).replace(
            EXECUTOR_HELPER,
            EXECUTOR_HELPER.replace(EXECUTOR_COPY, EXECUTOR_REPLACEMENT),
        ).replace(definition, helper_text + "\n" + definition).encode("utf-8")
        subprocess.run(["node", "--check"], input=patched, check=True)
        delta = len(patched) - size
        for path, item in entries(index):
            if path == member:
                item["size"] = len(patched)
                item["integrity"] = integrity(patched, block_size)
            elif not item.get("unpacked") and "link" not in item and "offset" in item:
                start = int(item["offset"])
                if start >= offset + size:
                    item["offset"] = str(start + delta)
        encoded = json.dumps(index, ensure_ascii=False, separators=(",", ":")).encode()
        padding = (-len(encoded)) % 4
        payload = 4 + len(encoded) + padding
        fd, temporary = tempfile.mkstemp(prefix=".app.asar.", dir=archive.parent)
        try:
            with os.fdopen(fd, "wb") as dst:
                dst.write(struct.pack("<4I", 4, payload + 4, payload, len(encoded)))
                dst.write(encoded)
                dst.write(b"\0" * padding)
                src.seek(body_start)
                remaining = offset
                while remaining:
                    chunk = src.read(min(1024 * 1024, remaining))
                    if not chunk:
                        raise ValueError("Truncated ASAR body")
                    dst.write(chunk)
                    remaining -= len(chunk)
                dst.write(patched)
                src.seek(body_start + offset + size)
                shutil.copyfileobj(src, dst)
            os.chmod(temporary, archive.stat().st_mode & 0o7777)
            os.replace(temporary, archive)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    print(f"Patched {member}; preserved all other members and unpacked metadata")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: patch-bundled-copy.py APP.ASAR HELPER.CJS")
    main(Path(sys.argv[1]), Path(sys.argv[2]))
