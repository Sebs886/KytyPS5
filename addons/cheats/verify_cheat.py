#!/usr/bin/env python3
"""Verify a KytyPS5 / GoldHEN ("etaHEN mods") cheat file against a game's eboot.bin.

kyty_emulator.exe --game-patch <file.json> does not blindly write at the offsets of
the cheat file.  It replicates the loader in src/loader/gamePatch.cpp exactly:

  1. LoadPlan()    - every *enabled* mod's `memory` entries are appended, in mod
                     order, to ONE flat list of writes.  The mod names are kept
                     only so the log can print them afterwards.
  2. Matches()     - the anchor is the FIRST write of that flat list whose `off`
                     bytes are not all zero.  The anchor's bytes are then searched
                     across every PT_LOAD / PT_OS_RELRO segment, in program-header
                     order.  For each occurrence: source_base = anchor.offset - rva.
  3. TranslateAndValidate() - EVERY write whose `off` is not all zero must satisfy
                     memcmp(base_vaddr + offset - source_base, off) == 0.
  4. The first occurrence that validates all of them wins; ApplyWrites() then
                     memcpy()s each `on` in flat-list order (so on an overlap the
                     LAST write wins).

The consequence that matters when you *write* cheats: there is ONE global anchor and
ONE global source_base for the whole file - not one per mod.  A file can therefore be
"individually fine" mod by mod and still fail as a whole, which is exactly what the
[OK ] / [no ] lines below are meant to catch.

Usage:
    python verify_cheat.py <cheat.json> <game folder | eboot.bin>

The game's eboot.bin should be a plain ELF. If only the encrypted SELF `eboot.bin` is
present, point this script at the decrypted ELF (e.g. <game>/decrypted/eboot.bin).
"""

import json
import os
import struct
import sys

PT_LOAD = 1
PT_OS_RELRO = 0x61000000
PAGE = 0x4000


# --------------------------------------------------------------------------- ELF

def read_segments(path):
    """Return (data, segments). Segments keep program-header order."""
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:4] != b"\x7fELF":
        raise SystemExit(
            "%s is not a plain ELF (it looks like a SELF/encrypted eboot).\n"
            "Point this script at the decrypted ELF, e.g. <game>/decrypted/eboot.bin."
            % path
        )
    e_phoff, = struct.unpack_from("<Q", data, 0x20)
    e_phentsize, = struct.unpack_from("<H", data, 0x36)
    e_phnum, = struct.unpack_from("<H", data, 0x38)
    segments = []
    for index in range(e_phnum):
        offset = e_phoff + index * e_phentsize
        p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = \
            struct.unpack_from("<IIQQQQQQ", data, offset)
        if p_type in (PT_LOAD, PT_OS_RELRO):
            segments.append({
                "type": p_type,
                "flags": p_flags,
                "offset": p_offset,
                "vaddr": p_vaddr,
                "filesz": p_filesz,
                "memsz": p_memsz,
            })
    if not segments:
        raise SystemExit("no loadable segment in %s" % path)
    return data, segments


def find_eboot(game):
    if os.path.isfile(game):
        return game
    for candidate in ("decrypted/eboot.bin", "eboot.bin"):
        path = os.path.join(game, *candidate.split("/"))
        if os.path.isfile(path):
            try:
                with open(path, "rb") as handle:
                    if handle.read(4) == b"\x7fELF":
                        return path
            except OSError:
                pass
    raise SystemExit("no decrypted ELF eboot.bin under %s" % game)


def read_vaddr(segments, data, vaddr, size):
    """Read `size` bytes at virtual address `vaddr`, or None if unmapped."""
    for segment in segments:
        if segment["vaddr"] <= vaddr and vaddr + size <= segment["vaddr"] + segment["filesz"]:
            start = segment["offset"] + (vaddr - segment["vaddr"])
            return data[start:start + size]
    return None


# ------------------------------------------------------------------------- cheat

def parse_bytes(text):
    if not text or len(text) % 2:
        raise ValueError("byte strings must be even-length hex")
    return bytes(int(text[i * 2:i * 2 + 2], 16) for i in range(len(text) // 2))


class Write:
    __slots__ = ("mod", "offset", "off", "on")

    def __init__(self, mod, offset, off, on):
        self.mod = mod
        self.offset = offset
        self.off = off
        self.on = on

    @property
    def active(self):
        return any(self.off)


def load_plan(path):
    with open(path, "r", encoding="utf-8") as handle:
        root = json.load(handle)
    for key in ("id", "version", "process", "mods"):
        if key not in root:
            raise SystemExit("not a GoldHEN mods JSON: missing %r" % key)

    mods = []      # (name, [Write, ...]) for the report
    writes = []    # the flat list the emulator actually uses
    for mod in root["mods"]:
        name = mod.get("name", "?")
        if not mod.get("enabled", True):
            continue
        entries = []
        for entry in mod["memory"]:
            offset = int(entry["offset"], 16)
            off = parse_bytes(entry["off"])
            on = parse_bytes(entry["on"])
            if len(off) != len(on):
                raise SystemExit("mod %r: off and on differ in length" % name)
            write = Write(name, offset, off, on)
            entries.append(write)
            writes.append(write)
        mods.append((name, entries))
    return root, mods, writes


# ------------------------------------------------------------- emulator replica

def matches(writes, segments, data, mapped_size):
    """Exact port of Loader::GamePatch::Matches + TranslateAndValidate.

    Returns the winning source_base, None when there is nothing to patch (all `off`
    zero), or False when no anchor occurrence validates the whole flat list.
    """
    anchor = next((write for write in writes if write.active), None)
    if anchor is None:
        return None
    if mapped_size < len(anchor.off):
        return False

    for segment in segments:
        if segment["filesz"] < len(anchor.off):
            continue
        blob = data[segment["offset"]:segment["offset"] + segment["filesz"]]
        start = 0
        while True:
            index = blob.find(anchor.off, start)
            if index < 0:
                break
            rva = index + segment["vaddr"]
            if anchor.offset >= rva:
                source_base = anchor.offset - rva
                if translate_and_validate(writes, segments, data, mapped_size, source_base):
                    return source_base
            start = index + 1
    return False


def translate_and_validate(writes, segments, data, mapped_size, source_base):
    for write in writes:
        # Translate(): base_vaddr == 0 makes this `offset - source_base`, with the
        # underflow branch used when source_base is larger than the offset.
        target = write.offset - source_base
        if not write.active:
            continue
        # IsInsideProgram(): target + size must stay inside [0, mapped_size).
        if target < 0 or target + len(write.off) > mapped_size:
            return False
        if read_vaddr(segments, data, target, len(write.off)) != write.off:
            return False
    return True


def payload(writes, segments, data, mapped_size, source_base):
    """Return [(addr, bytes, write)] for every write that lands inside the program."""
    applied = []
    for write in writes:
        target = write.offset - source_base
        inside = 0 <= target and target + len(write.on) <= mapped_size
        applied.append((target, write.on, write, inside))
    return applied


def report_overlaps(applied):
    """Return a list of human-readable 'A overrides B' strings."""
    notes = []
    inside = [item for item in applied if item[3]]
    for i, (addr_a, on_a, write_a, _) in enumerate(inside):
        for addr_b, on_b, write_b, _ in inside[i + 1:]:
            if write_a is write_b:
                continue
            lo = max(addr_a, addr_b)
            hi = min(addr_a + len(on_a), addr_b + len(on_b))
            if lo < hi:
                notes.append(
                    "0x%X..0x%X written by BOTH %r and %r -> the latter in mod order wins"
                    % (lo, hi - 1, write_a.mod, write_b.mod)
                )
    return notes


# ---------------------------------------------------------------------------- UI

def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    cheat_path, game = sys.argv[1], sys.argv[2]
    eboot = find_eboot(game)
    data, segments = read_segments(eboot)
    mapped_size = max(s["vaddr"] + s["memsz"] for s in segments)
    root, mods, writes = load_plan(cheat_path)

    print("cheat file : %s" % cheat_path)
    print("eboot      : %s" % eboot)
    print("wants      : id=%s version=%s process=%s"
          % (root["id"], root["version"], root["process"]))

    param = os.path.join(os.path.dirname(os.path.abspath(eboot)), "..", "sce_sys", "param.json")
    version_ok = True
    if os.path.isfile(param):
        with open(param, "r", encoding="utf-8") as handle:
            info = json.load(handle)
        print("game is    : id=%s version=%s"
              % (info.get("titleId"), info.get("contentVersion")))
        version_ok = (info.get("titleId") == root["id"]
                      and info.get("contentVersion") == root["version"])
        if not version_ok:
            print("  -> MISMATCH: the emulator rejects the file "
                  "('cheat file does not match the loaded game').")

    anchor = next((w for w in writes if w.active), None)
    if anchor is not None:
        print("anchor     : first non-zero `off` of the flat list -> "
              "%r @ 0x%X (%s)" % (anchor.mod, anchor.offset, anchor.off.hex().upper()))
    print()

    result = matches(writes, segments, data, mapped_size)

    if result is None:
        print("  [skip]   nothing to patch (every `off` is all zero)")
        print()
        print("0 of %d enabled mod(s) apply to this build." % len(mods))
        return
    if result is False:
        for name, entries in mods:
            print("  [no ]    %s" % name)
        print()
        print("0 of %d enabled mod(s) apply to this build." % len(mods))
        print()
        print("No occurrence of the anchor validates the whole file. The emulator will")
        print("print 'Game cheat: waiting for the matching module' and patch nothing.")
        return

    applied = payload(writes, segments, data, mapped_size, result)
    of = {}
    for addr, on, write, inside in applied:
        of.setdefault(write.mod, []).append((addr, on, inside))

    ok = 0
    for name, entries in mods:
        hits = of.get(name, [])
        if hits and all(inside for _, _, inside in hits):
            ok += 1
            detail = ", ".join("0x%X" % addr for addr, _, _ in hits)
            print("  [OK ]    %-28s -> %s" % (name, detail))
        elif hits:
            inside = [("0x%X" % addr) for addr, _, flag in hits if flag]
            outside = [("0x%X" % addr) for addr, _, flag in hits if not flag]
            print("  [cave]   %-28s -> in-load %s, coded-cave %s"
                  % (name, ", ".join(inside) or "-", ", ".join(outside) or "-"))
            ok += 1
        else:
            print("  [empty]  %s (no memory entries)" % name)

    print()
    print("source base: 0x%X  (all writes validated against this build)" % result)
    print("%d of %d enabled mod(s) apply to this build." % (ok, len(mods)))

    notes = report_overlaps(applied)
    if notes:
        print()
        print("overlaps (the emulator applies the flat list in order, last wins):")
        for note in notes:
            print("  ! " + note)

    if not version_ok:
        print()
        print("version mismatch: even a fully matching file will be refused.")


if __name__ == "__main__":
    main()
