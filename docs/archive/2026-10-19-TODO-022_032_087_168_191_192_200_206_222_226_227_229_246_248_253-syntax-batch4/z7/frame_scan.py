"""arm64 の決定木の再帰経路の枠を、関数の入口の命令から読み取る。"""

import json
import re
import subprocess
import sys


FUNCTION = re.compile(
    r"[0-9a-f]+ <<benitoite::ir::decision::Lowerer>::([a-z_]+)>:\n"
)
SELECTED = {
    "emit", "emit_node", "emit_jump", "emit_length", "finish_length",
    "emit_gets", "finish_gets", "tree", "build_tree", "list_tree", "list_branch",
}


def scan(binary):
    command = ["xcrun", "llvm-objdump", "--demangle", "--disassemble", binary]
    process = subprocess.Popen(command, stdout=subprocess.PIPE, text=True)
    frames = {}
    frame = None
    lines = 0
    for line in process.stdout:
        if line.strip().endswith(">:"):
            match = FUNCTION.fullmatch(line)
            name = match[1] if match else None
            frame = None
            lines = 0
            if name in SELECTED:
                frame = {"bytes": 0, "prologue": []}
                frames[name] = frame
        elif frame is not None and lines < 10:
            # 対象の関数は先頭10命令までに枠を確保する。元の命令も記録する。
            lines += 1
            frame["prologue"].append(line.strip())
            subtract = re.search(r"sub\s+sp, sp, #0x([0-9a-f]+)(, lsl #12)?", line)
            if subtract:
                frame["bytes"] += int(subtract[1], 16) * (4096 if subtract[2] else 1)
            save = re.search(r"\[sp, #-0x([0-9a-f]+)\]!", line)
            if save:
                frame["bytes"] += int(save[1], 16)
    if process.wait() != 0:
        raise RuntimeError("llvm-objdump failed")
    if not {"emit", "emit_length", "emit_gets"}.issubset(frames):
        raise RuntimeError("missing decision emission functions")
    return {"binary": binary, "command": command, "frames": frames}


if __name__ == "__main__":
    print(json.dumps(scan(sys.argv[1]), indent=2))
