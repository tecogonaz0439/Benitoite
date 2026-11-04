"""再開1の328行を、再開2の通常契約の証拠へ更新する。"""
from pathlib import Path
from datetime import datetime, timezone
from collections import Counter
import hashlib,json
HERE=Path(__file__).resolve().parent
def digest(p):
 b=p.read_bytes();return {"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
def main():
 d=json.loads((HERE/"sources-r1-u28.json").read_text())
 changed=[]
 for r in d["rows"]:
  if r[8]:
   r[8]=["実Rust登録型/ABIと全交換の独立な照合は通常F06とは別"]
  if r[9]:
   r[9]=[p for p in r[9] if p not in {"ordinary-F06","既存の外側アルゴリズム境界"}]
  if r[7]=="boundary-wait":
   r[7]="refinement-open"
   r[9]=["篩付きtel/本体の接続。mapFromのNone枝の含意の不足で指定どおり停止"]
  if r[4]!="open":continue
  name=r[0]; module,api=name.split(".",1)
  r[4]="pure-local" if r[2] else "core-local"
  if r[1]=="C-alias": evidence=["StandardAliasBodies.declarations_typed"]
  elif r[1]=="C-other": evidence=["StandardOrdinaryCoreProgram.declarations_typed","StandardOrdinaryCoreProgram.all_lookup_typed"]
  elif module=="Byte": evidence=["StandardByteStringResponse.table_response"]
  elif module=="Character":evidence=["StandardCharacterResponse.table_response"]
  elif module in {"Integer","Integer8","Integer16","Integer32","UnsignedInteger16","UnsignedInteger32","UnsignedInteger64"}:
   evidence=["StandardIntegerTextResponse.table_response"]
  elif module in {"Float","Float32"} and api in {"truncate","absolute","floor","ceiling","round","squareRoot"}:
   evidence=["StandardFloatMathResponse.table_response"]
  elif module in {"Float","Float32","Decimal"}:
   evidence=["StandardNumericRemainingResponse.table_response"]
   if name=="Decimal.fromFloat":evidence+=["StandardNumericRemainingResponse.fromFloat_parsed"]
  elif module=="String":evidence=["StandardStringOrdinaryResponse.table_response"]
  elif module=="Bytes":evidence=["StandardBytesOrdinaryResponse.table_response"]
  elif module=="List":evidence=["StandardListRemainingResponse.table_range_response" if api=="range" else "StandardListRemainingResponse.table_response"]
  else:raise AssertionError(name)
  r[5]+=evidence
  r[9]=[p for p in r[9] if not any(x in p for x in ["未接続","未実装","ordinary","alias","静的本体"])]
  if not r[6] and r[7] in {"core-open","core-static-open"}:r[7]="none"
  changed.append({"api":name,"ordinary":r[4],"evidence":evidence})
 assert len(changed)==179
 d["updated_utc"]=datetime.now(timezone.utc).isoformat()
 counts=Counter(r[4] for r in d["rows"])
 assert counts=={"pure-local":244,"core-local":84}
 d["counts"].update({"pure-local":244,"core-local":84,"open":0})
 d["resumed_ordinary"]={"closed":179,"remaining":0}
 d["resumed_breakdown"]={"builtin":100,"Decimal.fromFloat_parsed":1,"aliases":51,"other_core":27}
 d["status_definitions"]["core-local"]="原公開署名の同じ実Comp/通常型を有限P/BでDef.WellTypedへ接続。精密な正常篩と全モデルは別"
 d["status_definitions"].pop("boundary-wait",None)
 d["status_definitions"]["refinement-open"]="telの正常篩の方式は合意済み。既存含意の不足で指定どおり試行を停止し未完を保持"
 d["additional_relation_counts"]=dict(Counter(r[7] for r in d["rows"]))
 d["limits"]=[
  "全328通常F06は有限な具体表/Programの全BuiltinArgs又はDef.WellTypedであり、全モデル/全Programの充足ではない",
  "正常篩の7公開行はmapFromのNone枝の含意の不足で停止。CallRunや追加公理で補わない",
  "精密getter06〜14の9行は、開いた束縛と欄の等号の規則を要する経路で停止",
  "実Rust登録型/ABI/鍵の全比較と全交換は未実施。通常型契約と全APIの意味の閉鎖を区別する",
  "%eq/%neは328外。List.containsの具体構造比較を全Equalityの標準表へ収集したとは数えない",
  "List.sortのorderedは閉じた型のadmissionで表し、篩付きの元型を保持する。開いた型変数の全翻訳は新設しない",
  "現行Range/NonEmptyListの原nominal署名と内部safe19を区別する"]
 d["scope"]="全328実名の通常契約を有限の具体表へ接続。pureは全ts/es/rs/ws/Ψ/a/eのBuiltinArgsから同じδの型/Ground/Adequate/非exit、coreは同じComp/Def.WellTyped。追加Sと全API閉鎖は別"
 d["previous"]= {"file":"sources-r1-u28.json",**digest(HERE/"sources-r1-u28.json")}
 (HERE/"sources-r2-u28.json").write_text(json.dumps(d,ensure_ascii=False,separators=(",",":"))+"\n")
 (HERE/"ordinary-closed-r2.json").write_text(json.dumps({"closed":179,"remaining":0,"rows":changed},ensure_ascii=False,indent=2)+"\n")
 print(json.dumps({"counts":d["counts"],"additional":d["additional_relation_counts"],"bytes":(HERE/"sources-r2-u28.json").stat().st_size},ensure_ascii=False))
if __name__=="__main__":main()

