"""実際の標準ソースの署名と Rust の登録名を再収集し、数値表の名前を照合する。"""
from pathlib import Path
import hashlib, json, re
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
NEW = ["StandardInteger", "StandardByteCharacter", "StandardFloat", "StandardDecimal", "StandardFactExamples"]
MODULES = ["Integer", "Integer8", "Integer16", "Integer32", "Integer64", "UnsignedInteger",
           "UnsignedInteger8", "UnsignedInteger16", "UnsignedInteger32", "UnsignedInteger64",
           "Byte", "Character", "Float", "Float32", "Float64", "Decimal", "Bytes", "RoundingMode", "Option"]
RUST = ["narrow_integer.rs", "integer.rs", "unsigned_integer64.rs", "width_bits.rs", "width.rs",
        "byte.rs", "character.rs", "float.rs", "float32.rs", "decimal.rs", "bytes.rs", "operators.rs",
        "operators/unsigned.rs", "operators/float32.rs", "operators/signed.rs"]
def digest(p):
    b=p.read_bytes()
    return {"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
def main():
    catalog={}
    inputs={}
    for module in MODULES:
        p=ROOT/"crates/benitoite/src/prelude/stdlib"/(module+".bnt")
        inputs[str(p.relative_to(ROOT))]=digest(p)
        for line,source in enumerate(p.read_text().splitlines(),1):
            m=re.match(r"public function (\w+)(.*)",source)
            if m: catalog[module+"."+m[1]]={"line":line,"signature":source}
    checked=[]
    def check(name, parameters, result):
        actual=re.sub(r"\s+","",catalog[name]["signature"])
        expected="publicfunction"+name.split(".")[-1]+"("+parameters+")->"+result
        assert actual==expected,(name,actual,expected)
        checked.append(name)
    for module in ["Integer8","Integer16","Integer32","UnsignedInteger16","UnsignedInteger32","UnsignedInteger64"]:
        check(module+".fromInteger","n:Integer","Option["+module+"]")
        check(module+".toInteger","n:"+module,"Option[Integer]" if module=="UnsignedInteger64" else "Integer")
    for module in ["Integer","Integer8","Integer16","Integer32","UnsignedInteger16","UnsignedInteger32","UnsignedInteger64"]:
        for fun in ["minimum","maximum","floorDivide","floorModulo","bitwiseAnd","bitwiseOr","bitwiseExclusiveOr"]:
            check(module+"."+fun,"a:"+module+",b:"+module,module)
        check(module+".absolute","n:"+module,module)
        check(module+".bitwiseNot","a:"+module,module)
        for fun in ["shiftLeft","shiftRight"]+(["shiftRightUnsigned"] if not module.startswith("Unsigned") else []):
            check(module+"."+fun,"a:"+module+",n:Integer",module)
    check("Byte.fromInteger","n:Integer","Option[Byte]")
    check("Byte.toInteger","b:Byte","Integer")
    check("Character.fromInteger","n:Integer","Option[Character]")
    check("Character.toInteger","c:Character","Integer")
    check("Decimal.round","x:Decimal,places:Integer,mode:RoundingMode","Decimal")
    check("Decimal.absolute","x:Decimal","Decimal")
    check("Decimal.fromInteger","n:Integer","Decimal")
    check("Decimal.truncate","x:Decimal","Option[Integer]")
    check("Decimal.fromFloat","x:Float","Option[Decimal]")
    check("UnsignedInteger64.fromDecimal","x:Decimal","Option[UnsignedInteger64]")
    check("UnsignedInteger64.toDecimal","n:UnsignedInteger64","Decimal")
    check("Float.isNaN","x:Float","Boolean")
    check("Float32.isNaN","n:Float32","Boolean")
    check("Float32.isInfinite","n:Float32","Boolean")
    assert "Float.isInfinite" not in catalog
    check("Bytes.fromList","bs:List[Byte]","Bytes")
    check("Bytes.toList","b:Bytes","List[Byte]")
    # 別名のラッパーも実物から記録する。追加の builtin 名として扱わない。
    aliases={}
    for module in ["Integer64","UnsignedInteger","UnsignedInteger8","Float64"]:
        source=(ROOT/"crates/benitoite/src/prelude/stdlib"/(module+".bnt")).read_text()
        aliases[module]=re.findall(r"return ([A-Za-z0-9]+\.[A-Za-z0-9]+)\(",source)
        assert aliases[module],module
    rust_base=ROOT/"crates/benitoite/src/builtins/funcs"
    rust_text=""
    for name in RUST:
        q=rust_base/name
        inputs[str(q.relative_to(ROOT))]=digest(q)
        rust_text+=q.read_text()+"\n"
    for name in ["crates/benitoite/src/base/decimal.rs","crates/benitoite/src/runtime/equal.rs",
                 "crates/benitoite/src/builtins/table.rs", "crates/benitoite/src/typeck/context.rs",
                 "crates/benitoite/src/typeck/calls.rs"]:
        q=ROOT/name; inputs[name]=digest(q)
    registered=set(re.findall(r'"([%A-Za-z][%A-Za-z0-9_.]+)"',rust_text))
    actual_names={}
    for module in NEW:
        source=(ROOT/"formal/Benitoite/Release/Refinement"/(module+".lean")).read_text()
        literal=set(re.findall(r'"(%(?:eq|ne)|%?[A-Z][A-Za-z0-9]*\.[a-z][A-Za-z0-9]*)"',source))
        missing=literal-registered
        assert not missing,(module,missing)
        actual_names[module]=sorted(literal)
    for module in ["Integer","Integer8","Integer16","Integer32","UnsignedInteger16","UnsignedInteger32","UnsignedInteger64"]:
        for suffix in ["add","subtract","multiply","less","lessOrEqual","greater","greaterOrEqual"]:
            assert "%"+module+"."+suffix in registered
        for suffix in ["floorDivide","floorModulo","absolute","minimum","maximum",
                       "bitwiseAnd","bitwiseOr","bitwiseExclusiveOr","bitwiseNot","shiftLeft","shiftRight"]:
            assert module+"."+suffix in registered
        if not module.startswith("Unsigned"):
            assert "%"+module+".negate" in registered
            assert module+".shiftRightUnsigned" in registered
    output={"modules":MODULES,"api_count":len(catalog),"api":catalog,"inputs":inputs,
            "checked_signatures":checked,"aliases":aliases,"literal_names":actual_names,"name_mismatches":0}
    q=HERE/"sources.json";q.write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n")
    assert q.stat().st_size<=100000
    print(json.dumps({"api_count":len(catalog),"source_files":len(inputs),"name_mismatches":0}))
if __name__=="__main__": main()
