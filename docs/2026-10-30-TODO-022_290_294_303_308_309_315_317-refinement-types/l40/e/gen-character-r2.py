"""固定RustのUnicodeの有限表をLeanのデータとして生成する。"""
from pathlib import Path
import hashlib, json, subprocess, tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = r'''
fn main() {
    println!("{:?}", char::UNICODE_VERSION);
    for n in 0..=0x10ffff {
        if let Some(c) = char::from_u32(n) {
            let flags = (c.is_alphabetic() as u8)
                | ((c.is_numeric() as u8) << 1)
                | ((c.is_whitespace() as u8) << 2)
                | ((c.is_uppercase() as u8) << 3)
                | ((c.is_lowercase() as u8) << 4);
            let upper: Vec<u32> = c.to_uppercase().map(u32::from).collect();
            let lower: Vec<u32> = c.to_lowercase().map(u32::from).collect();
            if flags != 0 || upper != [n] || lower != [n] {
                println!("{}|{}|{:?}|{:?}", n, flags, upper, lower);
            }
        }
    }
}
'''

def digest(b):
    return {"bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}

def main():
    version = subprocess.check_output(["rustc", "--version"], cwd=ROOT).decode().strip()
    assert version.startswith("rustc 1.98.1 "), version
    with tempfile.TemporaryDirectory(prefix="benitoite-character-") as tmp:
        source = Path(tmp) / "character.rs"
        exe = Path(tmp) / "character"
        source.write_text(SOURCE)
        subprocess.run(["rustc", "--edition=2024", "-O", str(source), "-o", str(exe)], cwd=ROOT, check=True)
        raw = subprocess.check_output([str(exe)])
    lines = raw.decode().splitlines()
    sets = [[] for _ in range(5)]
    uppers, lowers = [], []
    for line in lines[1:]:
        number, flags, upper, lower = line.split("|")
        n, f = int(number), int(flags)
        for i, values in enumerate(sets):
            if f & (1 << i): values.append(n)
        u, l = json.loads(upper), json.loads(lower)
        if u != [n]: uppers.append((n, u))
        if l != [n]: lowers.append((n, l))
    out = ["/-! # 固定Rustから生成したUnicodeの有限表 -/", "set_option maxRecDepth 10000", "set_option maxHeartbeats 2000000", "namespace Benitoite.Release.Refinement.StandardCharacterData"]
    counts = {}
    for name, values in zip(["alphabetic", "numeric", "whitespace", "uppercase", "lowercase"], sets):
        ranges = []
        for n in values:
            if ranges and ranges[-1][1] + 1 == n: ranges[-1][1] = n
            else: ranges.append([n,n])
        out.append(f"def {name} : List (Nat × Nat) := [" + ",".join(f"({a},{b})" for a,b in ranges) + "]")
        counts[name] = {"scalars": len(values), "ranges": len(ranges)}
    for name, pairs in [("upper", uppers), ("lower", lowers)]:
        chunks = []
        for offset in range(0, len(pairs), 100):
            part = name + str(offset // 100)
            chunks.append(part)
            out.append(f"private def {part} : List (Nat × List Nat) := [" + ",".join(f"({n},[{','.join(map(str,v))}])" for n,v in pairs[offset:offset+100]) + "]")
        out.append(f"def {name} : List (Nat × List Nat) := " + " ++ ".join(chunks))
        counts[name] = len(pairs)
    out.append("end Benitoite.Release.Refinement.StandardCharacterData\n")
    target = ROOT / "formal/Benitoite/Release/Refinement/StandardCharacterData.lean"
    target.write_text("\n".join(out))
    summary = {"compiler": version, "unicode": lines[0], "generator": digest(Path(__file__).read_bytes()), "raw": digest(raw), "output": digest(target.read_bytes()), "counts": counts}
    (HERE / "character-data-r2.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps(summary, ensure_ascii=False))

if __name__ == "__main__": main()
