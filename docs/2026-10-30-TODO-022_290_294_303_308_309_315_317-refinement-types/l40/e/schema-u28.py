"""全量化した純粋143行の実原署名をLeanの有限表と照合する。"""
from pathlib import Path
import json
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
KINDS = {"Integer": "integer64", "Integer8": "integer8", "Integer16": "integer16", "Integer32": "integer32", "UnsignedInteger16": "unsignedInteger16", "UnsignedInteger32": "unsignedInteger32", "UnsignedInteger64": "unsignedInteger64"}
BASES = {"Integer": "integer", "Integer8": "integer8", "Integer16": "integer16", "Integer32": "integer32", "UnsignedInteger16": "unsignedInteger16", "UnsignedInteger32": "unsignedInteger32", "UnsignedInteger64": "unsignedInteger64", "Byte": "byte", "Character": "character", "Float": "float", "Float32": "float32", "Decimal": "decimal", "String": "string", "Boolean": "boolean"}
SCALARS = {"Byte.fromInteger": "byteFrom", "Byte.toInteger": "byteTo", "Byte.bitwiseAnd": "byteAnd", "Byte.bitwiseOr": "byteOr", "Byte.bitwiseExclusiveOr": "byteXor", "Byte.bitwiseNot": "byteNot", "Byte.shiftLeft": "byteLeft", "Byte.shiftRight": "byteRight", "Character.fromInteger": "characterFrom", "Character.toInteger": "characterTo", "Float.isNaN": "floatNaN", "Float32.isNaN": "float32NaN", "Float32.isInfinite": "float32Infinite"}
BYTES = {"String.byteLength": "stringBytes", "String.characterCount": "stringCharacters", "Bytes.length": "bytesLength", "Bytes.fromList": "bytesFromList", "Bytes.toList": "bytesToList"}
def split(s):
    out=[];depth=0;start=0
    for i,c in enumerate(s):
        if c == "[": depth += 1
        elif c == "]": depth -= 1
        elif c == "," and not depth: out.append(s[start:i].strip());start=i+1
    out.append(s[start:].strip());return out

def ty(s, generics):
    if s in generics: return f"(.tvar {generics.index(s)})"
    if s in BASES: return f"(.base .{BASES[s]})"
    if s == "Bytes": return ".bytes"
    if s == "RoundingMode": return '(.data "RoundingMode" [])'
    name,params=s.split("[",1);xs=[ty(x,generics) for x in split(params[:-1])]
    if name in ["List","Set"]: return f"(.{name.lower()} {xs[0]})"
    if name == "Map": return f"(.map {xs[0]} {xs[1]})"
    return f'(.data "{name}" ['+','.join(xs)+'])'

def expressions(api, profile):
    module,method=api.split(".")
    if profile == "P-integer":
        k=KINDS[module]
        if method in ["minimum","maximum"]:
            return f"StandardIntegerResponse.minMaxSig .{k}", f"StandardIntegerResponse.minMaxName .{k} {'true' if method == 'maximum' else 'false'}"
        return f"StandardIntegerAPI.API.signature .{k} .{method}", f"StandardIntegerAPI.API.name .{k} .{method}"
    if profile == "P-scalar-option":
        k=KINDS[module];direction='true' if method=='fromInteger' else 'false'
        return f"StandardConversionResponse.signature .{k} {direction}",f"StandardConversionResponse.name .{k} {direction}"
    if api in SCALARS:
        tag=SCALARS[api];return f"StandardScalarResponse.API.signature .{tag}",f"StandardScalarResponse.API.name .{tag}"
    if profile in ["P-decimal","P-decimal-option"]:
        return f"StandardDecimalResponse.API.signature .{method}",f"StandardDecimalResponse.API.name .{method}"
    if api in BYTES:
        tag=BYTES[api];return f"StandardBytesResponse.API.signature .{tag}",f"StandardBytesResponse.API.name .{tag}"
    if module == "List": return f"StandardListResponse.API.signature .{method}",f"StandardListResponse.API.name .{method}"
    if module in ["Map","Set"]: return f"StandardCollections.{module}API.signature B.sat .{method}",f"StandardCollections.{module}API.name .{method}"
    raise ValueError(api)

def main():
    catalogue=json.loads((HERE/'sources-r1-u28.json').read_text())
    full=json.loads((HERE/'api-numeric.json').read_text())+json.loads((HERE/'api-collections.json').read_text())
    actual={r['module']+'.'+r['name']:r for r in full}
    lines=['import Benitoite.Release.Refinement.StandardActualListBodies','',
           '/-! # 標準ソースの原署名と具体の純粋応答表の対応 -/',
           'namespace Benitoite.Release.Refinement.StandardSignatureExamples', '']
    count=0
    for api,profile,_,_,status,*_ in catalogue['rows']:
        if status != 'pure-local':continue
        r=actual[api];signature,name=expressions(api,profile)
        generics=[x.split(':')[0].strip() for x in r['generics']]
        assert not r['effect']
        tparams=[];constraints=[]
        for spec in r['generics']:
            if ': key' in spec: tparams.append('⟨TParam.keyC,.value⟩');constraints.append('TParam.keyC')
            else: assert ':' not in spec;tparams.append('TypeCtx.valueParam');constraints.append('{}')
        if profile == 'P-key-collections':
            admits=f"(fun C ts => ts.length = {len(generics)} ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → ["+','.join(constraints)+"][i]? = some p → B.sat C t p)"
        elif generics: admits=f"(fun _ ts => ts.length = {len(generics)})"
        else: admits="(fun _ ts => ts = [])"
        names='['+','.join(json.dumps(x[0]) for x in r['parameters'])+']'
        params='['+','.join(ty(x[1],generics) for x in r['parameters'])+']'
        expected='⟨['+','.join(tparams)+f'],0,{names},{params},{ty(r["result"],generics)},Eff.empty,{admits},.pure,none,[],.untargeted⟩'
        lines += [f'-- {api}: {r["signature"]}',f'example {"(B : Builtins) " if profile == "P-key-collections" else ""}: ({signature}) = ({expected} : PrimSig) ∧',f'    {name} = "{api}" := ⟨rfl,rfl⟩','']
        count+=1
    assert count==143
    lines += ['end Benitoite.Release.Refinement.StandardSignatureExamples','']
    path=ROOT/'formal/Benitoite/Release/Refinement/StandardSignatureExamples.lean'
    path.write_text('\n'.join(lines)); assert path.stat().st_size<=100000
    print(json.dumps({'rows':count,'bytes':path.stat().st_size}))
if __name__ == '__main__':main()
