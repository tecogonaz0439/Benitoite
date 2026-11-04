"""固定Rust/crateの文脈分類と表示幅遷移を有限表へ変換する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, subprocess, tempfile, time
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]

RUST = r'''
use std::collections::{BTreeSet,VecDeque};
use std::io::{self,Write};
mod width {
 include!("tables.rs");
 pub fn transition(c:char,s:u16,cjk:bool)->(i8,u16) {
  let (delta,next) = if cjk {width_in_str_cjk(c,WidthInfo(s))}
                    else {width_in_str(c,WidthInfo(s))};
  (delta,next.0)
 }
}
fn compressed(values:&[(i8,u16)],base:Option<&[(i8,u16)]>)->Vec<(u32,u32,i8,u16)> {
 let mut result=Vec::new();
 let mut active:Option<(u32,u32,i8,u16)>=None;
 for (i,&(delta,next)) in values.iter().enumerate() {
  let valid=char::from_u32(i as u32).is_some();
  let changed=base.map_or(true,|b| b[i]!=(delta,next));
  if !valid || !changed {
   if let Some(run)=active.take(){result.push(run);}
   continue;
  }
  match &mut active {
   Some((_,hi,d,n)) if *d==delta && *n==next && *hi+1==i as u32 => *hi=i as u32,
   _ => {if let Some(run)=active.take(){result.push(run);}
         active=Some((i as u32,i as u32,delta,next));}
  }
 }
 if let Some(run)=active {result.push(run);}
 result
}
fn main(){
 let pilot=std::env::args().any(|a|a=="--pilot");
 let mut out=io::BufWriter::new(io::stdout().lock());
 for cjk in [false,true] {
  let make=|state:u16| ->Vec<(i8,u16)> {
   (0..=0x10ffff).map(|n| char::from_u32(n).map_or((0,0),|c|width::transition(c,state,cjk))).collect()
  };
  let base=make(0);
  let mut seen=BTreeSet::new();let mut queue=VecDeque::new();
  seen.insert(0u16);queue.push_back(0u16);
  while let Some(state)=queue.pop_front(){
   let values=if state==0 {base.clone()} else {make(state)};
   for (n,&(_,next)) in values.iter().enumerate() {
    if char::from_u32(n as u32).is_some() && seen.insert(next){queue.push_back(next);}
   }
   let ranges=compressed(&values,if state==0 {None}else{Some(&base)});
   writeln!(out,"W|{}|{}|{:?}",u8::from(cjk),state,ranges).unwrap();
   out.flush().unwrap();
   if pilot {break;}
  }
 }
 if !pilot {
  let mut runs:Vec<(u32,u32,u8)>=Vec::new();
  for n in 0..=0x10ffff {
   if let Some(c)=char::from_u32(n){
    let a=format!("AΣ{c}").to_lowercase().chars().nth(1).unwrap();
    let b=format!("AΣ{c}A").to_lowercase().chars().nth(1).unwrap();
    let class=if a=='σ' {1}else if b=='σ' {2}else{0};
    if class==0 {continue;}
    match runs.last_mut(){
     Some((_,hi,k)) if *hi+1==n && *k==class =>*hi=n,
     _=>runs.push((n,n,class)),
    }
   }
  }
  writeln!(out,"S|{:?}",runs).unwrap();
 }
}
'''

def digest(b): return {"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
def parse_tuples(s):
    return json.loads(s.replace("(","[").replace(")","]"))
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--pilot",action="store_true")
    args=ap.parse_args()
    version=subprocess.check_output(["rustc","--version"],cwd=ROOT).decode().strip()
    assert version.startswith("rustc 1.98.1 "),version
    paths=list((Path.home()/".cargo/registry/src").glob("*/unicode-width-0.2.2/src/tables.rs"))
    assert len(paths)==1,paths
    width=paths[0].read_bytes()
    started=datetime.now(timezone.utc).isoformat()
    clock=time.monotonic()
    with tempfile.TemporaryDirectory(prefix="benitoite-string-tables-") as tmp:
        tmp=Path(tmp)
        (tmp/"tables.rs").write_bytes(width)
        (tmp/"main.rs").write_text(RUST)
        cmd=["rustc","--edition=2024","--cfg",'feature="cjk"',"-O",str(tmp/"main.rs"),"-o",str(tmp/"tables")]
        subprocess.run(cmd,cwd=ROOT,check=True,capture_output=True)
        raw=subprocess.check_output([str(tmp/"tables")]+(["--pilot"] if args.pilot else []))
    elapsed=time.monotonic()-clock
    widths={}
    sigma=[]
    for line in raw.decode().splitlines():
        if line.startswith("W|"):
            _,mode,state,content=line.split("|",3)
            widths[int(mode),int(state)]=parse_tuples(content)
        else:
            sigma=parse_tuples(line.split("|",1)[1])
    summary={"compiler":version,"crate":"unicode-width 0.2.2","input_tables":digest(width),
        "generator":digest(Path(__file__).read_bytes()),"start":started,
        "end":datetime.now(timezone.utc).isoformat(),"seconds":elapsed,"raw":digest(raw),
        "pilot":args.pilot,"states":{str(mode):sum(m==mode for m,s in widths) for mode in [0,1]},
        "intervals":sum(len(v) for v in widths.values()),"sigma_intervals":len(sigma)}
    if not args.pilot:
        target=ROOT/"formal/Benitoite/Release/Refinement"
        modules=[]
        files={}
        chunks=[]
        for (mode,state),ranges in widths.items():
            parts=[]
            prefix=f"width{mode}State{state}"
            module=f"StandardStringWidth{mode}State{state}"
            lines=["/-! # 固定unicode-width 0.2.2から生成した表示幅の有限遷移 -/",
                "-- 入力はRust Project DevelopersのMIT/Apache-2.0のtables.rsである。",
                "set_option maxRecDepth 10000",
                "namespace Benitoite.Release.Refinement.StandardStringTables"]
            for offset in range(0,len(ranges),100):
                part=prefix+"Part"+str(offset//100)
                parts.append(part)
                lines.append(f"private def {part} : List (Nat × Nat × Int × Nat) := ["+
                    ",".join(f"({lo},{hi},{d},{n})" for lo,hi,d,n in ranges[offset:offset+100])+"]")
            lines.append(f"def {prefix} : List (Nat × Nat × Int × Nat) := "+
                (" ++ ".join(parts) if parts else "[]"))
            lines.append("end Benitoite.Release.Refinement.StandardStringTables\n")
            body="\n".join(lines)
            (target/(module+".lean")).write_text(body)
            modules.append(module)
            files[module]=digest(body.encode())
            chunks.append((mode,state,prefix))
        lines=["import Benitoite.Release.Refinement.StandardCharacterData"]+[
            "import Benitoite.Release.Refinement."+m for m in modules]
        lines+=["/-! # 文字列全体の文脈を追う有限表 -/",
            "namespace Benitoite.Release.Refinement.StandardStringTables",
            "set_option maxRecDepth 10000"]
        for mode in [0,1]:
            lines.append(f"private def states{mode} : List (Nat × List (Nat × Nat × Int × Nat)) := ["+
                ",".join(f"({s},{name})" for m,s,name in chunks if m==mode and s!=0)+"]")
        lines.append("private def rangesAt (n : Nat) : List (Nat × Nat × Int × Nat) → Option (Int × Nat)\n"+
            " | [] => none\n | (lo,hi,d,next)::xs => if lo≤n ∧ n≤hi then some (d,next) else rangesAt n xs")
        lines.append("def transition (cjk : Bool) (state : Nat) (c : Char) : Int × Nat :=\n"+
            " let defaults := if cjk then width1State0 else width0State0\n"+
            " let sparse := ((if cjk then states1 else states0).lookup state).getD []\n"+
            " ((rangesAt c.toNat sparse).orElse (fun _ => rangesAt c.toNat defaults)).getD (0,0)")
        parts=[]
        for offset in range(0,len(sigma),100):
            part="sigmaPart"+str(offset//100);parts.append(part)
            lines.append(f"private def {part} : List (Nat × Nat × Nat) := ["+
                ",".join(f"({lo},{hi},{k})" for lo,hi,k in sigma[offset:offset+100])+"]")
        lines.append("private def sigmaRanges : List (Nat × Nat × Nat) := "+(" ++ ".join(parts) if parts else "[]"))
        lines.append("def sigmaClass (c : Char) : Nat :=\n"+
            " ((sigmaRanges.find? (fun (lo,hi,_) => lo≤c.toNat && c.toNat≤hi)).map (fun (_,_,k) => k)).getD 0")
        lines.append("end Benitoite.Release.Refinement.StandardStringTables\n")
        body="\n".join(lines);(target/"StandardStringTables.lean").write_text(body)
        files["StandardStringTables"]=digest(body.encode());modules.append("StandardStringTables")
        summary.update({"modules":modules,"files":files})
    dest=HERE/("string-tables-pilot-r2.json" if args.pilot else "string-tables-r2.json")
    dest.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({k:v for k,v in summary.items() if k!="files"},ensure_ascii=False))
if __name__=="__main__":main()

