#!/usr/bin/env python3
"""samply のプロファイル（`--unstable-presymbolicate` で保存したもの）を関数ごとに集計する。

使い方: python3 tools/bench/profile_summary.py <profile.json.gz> [上位の件数]
各関数について、その関数自身で使った時間の割合（self）と、呼び出した先を含む割合（total）を示す。
性能の測定（設計書 07-02「測る項目」の実行時間の内訳）で、プロファイルを読む手がかりにする。
Python 3 の標準ライブラリだけで動く。
"""

import bisect
import gzip
import json
import sys
from collections import Counter
from pathlib import Path


def load_symbols(syms_path: Path) -> dict[str, tuple[list[int], list[tuple[int, int, str]]]]:
    data = json.loads(syms_path.read_text(encoding="utf-8"))
    strings = data["string_table"]
    tables: dict[str, tuple[list[int], list[tuple[int, int, str]]]] = {}
    for entry in data["data"]:
        rows = sorted((row["rva"], row["size"], strings[row["symbol"]]) for row in entry["symbol_table"])
        tables[entry["debug_name"]] = ([row[0] for row in rows], rows)
    return tables


def symbol_for(tables, lib_name: str, address: int) -> str:
    table = tables.get(lib_name)
    if table is None:
        return f"<{lib_name}>"
    starts, rows = table
    index = bisect.bisect_right(starts, address) - 1
    if index >= 0:
        start, size, name = rows[index]
        if address < start + max(size, 1):
            return name
    return f"<{lib_name}+{address:#x}>"


def summarize(profile_path: Path, limit: int) -> None:
    profile = json.load(gzip.open(profile_path))
    syms_path = Path(str(profile_path).removesuffix(".gz") + ".syms.json")
    tables = load_symbols(syms_path)
    libs = profile["libs"]
    self_counts: Counter[str] = Counter()
    total_counts: Counter[str] = Counter()
    sample_total = 0
    for thread in profile["threads"]:
        frames = thread["frameTable"]
        funcs = thread["funcTable"]
        resources = thread["resourceTable"]
        stacks = thread["stackTable"]
        names: list[str] = []
        for frame_index in range(frames["length"]):
            func = frames["func"][frame_index]
            resource = funcs["resource"][func]
            lib_index = resources["lib"][resource] if resource is not None and resource >= 0 else None
            address = frames["address"][frame_index]
            if lib_index is None or address is None or address < 0:
                names.append(thread["stringArray"][funcs["name"][func]])
            else:
                names.append(symbol_for(tables, libs[lib_index]["debugName"], address))
        samples = thread["samples"]
        weights = samples.get("weight") or [1] * samples["length"]
        for stack, weight in zip(samples["stack"], weights):
            if stack is None:
                continue
            weight = weight or 1
            sample_total += weight
            seen: set[str] = set()
            leaf = True
            while stack is not None:
                name = names[stacks["frame"][stack]]
                if leaf:
                    self_counts[name] += weight
                    leaf = False
                if name not in seen:
                    total_counts[name] += weight
                    seen.add(name)
                stack = stacks["prefix"][stack]
    print(f"{profile_path.name}: {sample_total} samples")
    print(f"{'self':>6} {'total':>6}  function")
    for name, count in self_counts.most_common(limit):
        print(f"{100 * count / sample_total:5.1f}% {100 * total_counts[name] / sample_total:5.1f}%  {name[:110]}")


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(__doc__, file=sys.stderr)
        return 2
    summarize(Path(sys.argv[1]), int(sys.argv[2]) if len(sys.argv) == 3 else 15)
    return 0


if __name__ == "__main__":
    sys.exit(main())
