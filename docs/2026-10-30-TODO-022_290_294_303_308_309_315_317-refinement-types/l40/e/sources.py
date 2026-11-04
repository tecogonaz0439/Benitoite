"""実標準ソース328行とRust内の組込み名を再収集する。証明済みの分類には使わない。"""
from pathlib import Path
import re,json,hashlib,collections
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
OUT=HERE
BASE=HERE.parent
INV=json.loads((BASE/'a/inventory.json').read_text())
MODULES=[x['module'] for x in INV['api']]
STDLIB=ROOT/'crates/benitoite/src/prelude/stdlib'
inputs={}
def read(p):
 b=p.read_bytes();inputs[str(p.relative_to(ROOT))]={'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()};return b.decode()
def top_split(s):
 out=[];n=0;start=0
 for i,c in enumerate(s):
  if c in '[(':n+=1
  if c in '])':n-=1
  if c==',' and n==0:out.append(s[start:i].strip());start=i+1
 if s[start:].strip():out.append(s[start:].strip())
 return out
rows=[];decls={};allbodies={}
for module in MODULES:
 text=read(STDLIB/(module+'.bnt'));lines=text.splitlines()
 for i,line in enumerate(lines):
  m=re.match(r'(public )?function (\w+)(.*)',line)
  if not m:continue
  public=bool(m[1]);name=m[2];tail=m[3];generics=[]
  if tail.startswith('['):
   depth=0
   for j,c in enumerate(tail):
    if c=='[':depth+=1
    elif c==']':
     depth-=1
     if not depth:break
   generics=top_split(tail[1:j]);tail=tail[j+1:]
  assert tail[0]=='('
  depth=0
  for j,c in enumerate(tail):
   if c=='(':depth+=1
   elif c==')':
    depth-=1
    if not depth:break
  parameters=[v.split(':',1) for v in top_split(tail[1:j])]
  parameters=[[a.strip(),b.strip()] for a,b in parameters]
  ret=tail[j+1:].strip();assert ret.startswith('->');ret=ret[2:].strip()
  # uses in the outer return type; declarations have no function-valued returns here.
  result,sep,effect=ret.partition(' uses ')
  builtin=None
  if i and (bm:=re.match(r'@builtin\("([^"]+)"\)',lines[i-1])):builtin=bm[1]
  body=[]
  if not builtin:
   for k in range(i+1,len(lines)):
    if lines[k]=='end function':break
    body.append(lines[k])
   assert k<len(lines)
  sourcebody='\n'.join(body)
  calls=[]
  for c in re.findall(r'(?<![\w.])([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\s*\(',sourcebody):
   if c not in calls:calls.append(c)
  decl={'module':module,'name':name,'line':i+1,'signature':line,'generics':generics,'parameters':parameters,'result':result,'effect':effect if sep else '', 'builtin':builtin,'calls':calls,'body':sourcebody}
  decls[module+'.'+name]=decl;allbodies[module+'.'+name]=sourcebody
  if public:rows.append(decl)
assert len(rows)==328,len(rows)
for m in INV['api']:assert sum(r['module']==m['module'] for r in rows)==m['count']
RUST=['mod.rs','byte.rs','character.rs','float.rs','float32.rs','decimal.rs','bytes.rs','integer.rs','narrow_integer.rs','unsigned_integer64.rs','width.rs','width_bits.rs','list.rs','map.rs','set.rs','string.rs','operators.rs','operators/unsigned.rs','operators/float32.rs','operators/signed.rs']
rust={}
for file in RUST:
 p=ROOT/'crates/benitoite/src/builtins/funcs'/file
 if not p.exists():continue
 for i,line in enumerate(read(p).splitlines(),1):
  for lit in re.findall(r'"([%A-Za-z][%A-Za-z0-9_.]+)"',line):
   if '.' in lit or lit in ['%eq','%ne']:rust.setdefault(lit,[]).append([file,i])

RELATIONS={'Byte.fromInteger': ['S04', 'S34'], 'Byte.toInteger': ['S04', 'S34'], 'Byte.toString': [], 'Byte.bitwiseAnd': ['S36'], 'Byte.bitwiseOr': ['S36'], 'Byte.bitwiseExclusiveOr': ['S36'], 'Byte.bitwiseNot': ['S36'], 'Byte.shiftLeft': ['S36'], 'Byte.shiftRight': ['S36'], 'Character.toInteger': ['S05', 'S34'], 'Character.fromInteger': ['S05', 'S34'], 'Character.toString': [], 'Character.isASCIIDigit': [], 'Character.isASCIIWhitespace': [], 'Character.isAlphabetic': [], 'Character.isNumeric': [], 'Character.isWhitespace': [], 'Character.isUppercase': [], 'Character.isLowercase': [], 'Character.toUppercase': [], 'Character.toLowercase': [], 'Float.toString': [], 'Float.parse': [], 'Float.truncate': [], 'Float.isNaN': ['S06'], 'Float.absolute': [], 'Float.floor': [], 'Float.ceiling': [], 'Float.round': [], 'Float.squareRoot': [], 'Float32.fromFloat': [], 'Float32.toFloat': [], 'Float32.parse': [], 'Float32.toString': [], 'Float32.truncate': [], 'Float32.isNaN': ['S06'], 'Float32.isInfinite': ['S06'], 'Float32.absolute': [], 'Float32.floor': [], 'Float32.ceiling': [], 'Float32.round': [], 'Float32.squareRoot': [], 'Decimal.round': ['S07'], 'Decimal.absolute': ['S07'], 'Decimal.fromInteger': ['S07', 'S34'], 'Decimal.truncate': ['S07', 'S34'], 'Decimal.toFloat': [], 'Decimal.fromFloat': ['S07', 'S34'], 'Decimal.toString': [], 'Decimal.parse': [], 'Integer.toString': [], 'Integer.parse': [], 'Integer.toFloat': [], 'Integer.floorDivide': ['S35'], 'Integer.floorModulo': ['S35'], 'Integer.absolute': ['S36'], 'Integer.minimum': ['S36'], 'Integer.maximum': ['S36'], 'Integer.bitwiseAnd': ['S36'], 'Integer.bitwiseOr': ['S36'], 'Integer.bitwiseExclusiveOr': ['S36'], 'Integer.bitwiseNot': ['S36'], 'Integer.shiftLeft': ['S36'], 'Integer.shiftRight': ['S36'], 'Integer.shiftRightUnsigned': ['S36'], 'Integer8.fromInteger': ['S34'], 'Integer8.toInteger': ['S34'], 'Integer8.parse': [], 'Integer8.toString': [], 'Integer8.toFloat': [], 'Integer8.absolute': ['S36'], 'Integer8.minimum': ['S36'], 'Integer8.maximum': ['S36'], 'Integer8.floorDivide': ['S35'], 'Integer8.floorModulo': ['S35'], 'Integer8.bitwiseAnd': ['S36'], 'Integer8.bitwiseOr': ['S36'], 'Integer8.bitwiseExclusiveOr': ['S36'], 'Integer8.bitwiseNot': ['S36'], 'Integer8.shiftLeft': ['S36'], 'Integer8.shiftRight': ['S36'], 'Integer8.shiftRightUnsigned': ['S36'], 'Integer16.fromInteger': ['S34'], 'Integer16.toInteger': ['S34'], 'Integer16.parse': [], 'Integer16.toString': [], 'Integer16.toFloat': [], 'Integer16.absolute': ['S36'], 'Integer16.minimum': ['S36'], 'Integer16.maximum': ['S36'], 'Integer16.floorDivide': ['S35'], 'Integer16.floorModulo': ['S35'], 'Integer16.bitwiseAnd': ['S36'], 'Integer16.bitwiseOr': ['S36'], 'Integer16.bitwiseExclusiveOr': ['S36'], 'Integer16.bitwiseNot': ['S36'], 'Integer16.shiftLeft': ['S36'], 'Integer16.shiftRight': ['S36'], 'Integer16.shiftRightUnsigned': ['S36'], 'Integer32.fromInteger': ['S34'], 'Integer32.toInteger': ['S34'], 'Integer32.parse': [], 'Integer32.toString': [], 'Integer32.toFloat': [], 'Integer32.absolute': ['S36'], 'Integer32.minimum': ['S36'], 'Integer32.maximum': ['S36'], 'Integer32.floorDivide': ['S35'], 'Integer32.floorModulo': ['S35'], 'Integer32.bitwiseAnd': ['S36'], 'Integer32.bitwiseOr': ['S36'], 'Integer32.bitwiseExclusiveOr': ['S36'], 'Integer32.bitwiseNot': ['S36'], 'Integer32.shiftLeft': ['S36'], 'Integer32.shiftRight': ['S36'], 'Integer32.shiftRightUnsigned': ['S36'], 'Integer64.toString': [], 'Integer64.parse': [], 'Integer64.toFloat': [], 'Integer64.floorDivide': ['S35'], 'Integer64.floorModulo': ['S35'], 'Integer64.absolute': ['S36'], 'Integer64.minimum': ['S36'], 'Integer64.maximum': ['S36'], 'Integer64.bitwiseAnd': ['S36'], 'Integer64.bitwiseOr': ['S36'], 'Integer64.bitwiseExclusiveOr': ['S36'], 'Integer64.bitwiseNot': ['S36'], 'Integer64.shiftLeft': ['S36'], 'Integer64.shiftRight': ['S36'], 'Integer64.shiftRightUnsigned': ['S36'], 'UnsignedInteger.fromInteger': ['S34'], 'UnsignedInteger.toInteger': ['S34'], 'UnsignedInteger.parse': [], 'UnsignedInteger.toString': [], 'UnsignedInteger.toFloat': [], 'UnsignedInteger.toDecimal': ['S07', 'S34'], 'UnsignedInteger.fromDecimal': ['S07', 'S34'], 'UnsignedInteger.absolute': ['S36'], 'UnsignedInteger.minimum': ['S36'], 'UnsignedInteger.maximum': ['S36'], 'UnsignedInteger.floorDivide': ['S35'], 'UnsignedInteger.floorModulo': ['S35'], 'UnsignedInteger.bitwiseAnd': ['S36'], 'UnsignedInteger.bitwiseOr': ['S36'], 'UnsignedInteger.bitwiseExclusiveOr': ['S36'], 'UnsignedInteger.bitwiseNot': ['S36'], 'UnsignedInteger.shiftLeft': ['S36'], 'UnsignedInteger.shiftRight': ['S36'], 'UnsignedInteger8.fromInteger': ['S04', 'S34'], 'UnsignedInteger8.toInteger': ['S04', 'S34'], 'UnsignedInteger8.toString': [], 'UnsignedInteger8.bitwiseAnd': ['S36'], 'UnsignedInteger8.bitwiseOr': ['S36'], 'UnsignedInteger8.bitwiseExclusiveOr': ['S36'], 'UnsignedInteger8.bitwiseNot': ['S36'], 'UnsignedInteger8.shiftLeft': ['S36'], 'UnsignedInteger8.shiftRight': ['S36'], 'UnsignedInteger16.fromInteger': ['S34'], 'UnsignedInteger16.toInteger': ['S34'], 'UnsignedInteger16.parse': [], 'UnsignedInteger16.toString': [], 'UnsignedInteger16.toFloat': [], 'UnsignedInteger16.absolute': ['S36'], 'UnsignedInteger16.minimum': ['S36'], 'UnsignedInteger16.maximum': ['S36'], 'UnsignedInteger16.floorDivide': ['S35'], 'UnsignedInteger16.floorModulo': ['S35'], 'UnsignedInteger16.bitwiseAnd': ['S36'], 'UnsignedInteger16.bitwiseOr': ['S36'], 'UnsignedInteger16.bitwiseExclusiveOr': ['S36'], 'UnsignedInteger16.bitwiseNot': ['S36'], 'UnsignedInteger16.shiftLeft': ['S36'], 'UnsignedInteger16.shiftRight': ['S36'], 'UnsignedInteger32.fromInteger': ['S34'], 'UnsignedInteger32.toInteger': ['S34'], 'UnsignedInteger32.parse': [], 'UnsignedInteger32.toString': [], 'UnsignedInteger32.toFloat': [], 'UnsignedInteger32.absolute': ['S36'], 'UnsignedInteger32.minimum': ['S36'], 'UnsignedInteger32.maximum': ['S36'], 'UnsignedInteger32.floorDivide': ['S35'], 'UnsignedInteger32.floorModulo': ['S35'], 'UnsignedInteger32.bitwiseAnd': ['S36'], 'UnsignedInteger32.bitwiseOr': ['S36'], 'UnsignedInteger32.bitwiseExclusiveOr': ['S36'], 'UnsignedInteger32.bitwiseNot': ['S36'], 'UnsignedInteger32.shiftLeft': ['S36'], 'UnsignedInteger32.shiftRight': ['S36'], 'UnsignedInteger64.fromInteger': ['S34'], 'UnsignedInteger64.toInteger': ['S34'], 'UnsignedInteger64.parse': [], 'UnsignedInteger64.toString': [], 'UnsignedInteger64.toFloat': [], 'UnsignedInteger64.toDecimal': ['S07', 'S34'], 'UnsignedInteger64.fromDecimal': ['S07', 'S34'], 'UnsignedInteger64.absolute': ['S36'], 'UnsignedInteger64.minimum': ['S36'], 'UnsignedInteger64.maximum': ['S36'], 'UnsignedInteger64.floorDivide': ['S35'], 'UnsignedInteger64.floorModulo': ['S35'], 'UnsignedInteger64.bitwiseAnd': ['S36'], 'UnsignedInteger64.bitwiseOr': ['S36'], 'UnsignedInteger64.bitwiseExclusiveOr': ['S36'], 'UnsignedInteger64.bitwiseNot': ['S36'], 'UnsignedInteger64.shiftLeft': ['S36'], 'UnsignedInteger64.shiftRight': ['S36'], 'Float64.toString': [], 'Float64.parse': [], 'Float64.truncate': [], 'Float64.isNaN': ['S06'], 'Float64.absolute': [], 'Float64.floor': [], 'Float64.ceiling': [], 'Float64.round': [], 'Float64.squareRoot': [], 'String.byteLength': ['S08'], 'String.byteSlice': [], 'String.characterCount': ['S08'], 'String.characterAt': [], 'String.characterSlice': [], 'String.isEmpty': [], 'String.contains': [], 'String.startsWith': [], 'String.endsWith': [], 'String.byteIndexOf': [], 'String.split': [], 'String.lines': [], 'String.join': [], 'String.trim': [], 'String.replace': [], 'String.repeat': [], 'String.characters': ['S05'], 'String.fromCharacters': ['S05'], 'String.toUppercase': [], 'String.toLowercase': [], 'String.toUTF8': [], 'String.fromUTF8': [], 'String.displayWidth': [], 'String.displayWidthCJK': [], 'String.displayWidthPadStart': [], 'String.displayWidthPadEnd': [], 'String.displayWidthPadStartCJK': [], 'String.displayWidthPadEndCJK': [], 'Bytes.empty': [], 'Bytes.fromList': ['S09'], 'Bytes.fromIntegers': [], 'Bytes.fromHex': [], 'Bytes.fromBinary': [], 'Bytes.toList': ['S09'], 'Bytes.toHex': [], 'Bytes.toBinary': [], 'Bytes.length': ['S09'], 'Bytes.get': [], 'Bytes.slice': [], 'Bytes.concatenate': [], 'Bytes.readUnsigned': [], 'Bytes.readSigned': [], 'Bytes.fromUnsigned': [], 'Bytes.fromSigned': [], 'List.length': ['S10'], 'List.isEmpty': ['S10'], 'List.head': ['S16'], 'List.tail': ['S16'], 'List.get': ['S16'], 'List.prepend': ['S11'], 'List.append': ['S11'], 'List.concatenate': ['S12'], 'List.reverse': ['S13'], 'List.take': [], 'List.drop': [], 'List.range': [], 'List.contains': [], 'List.sort': [], 'List.map': ['S14', 'S31'], 'List.filter': ['S15', 'S31'], 'List.fold': ['S31'], 'List.forEach': ['S31'], 'List.any': ['S31'], 'List.all': ['S31'], 'List.find': ['S31'], 'Map.empty': ['S17'], 'Map.fromList': ['S17'], 'Map.toList': ['S17'], 'Map.get': ['S19'], 'Map.set': ['S19'], 'Map.remove': ['S19'], 'Map.contains': ['S19'], 'Map.size': ['S17'], 'Map.keys': ['S18'], 'Map.values': ['S18'], 'Map.map': ['S20', 'S31'], 'Map.filter': ['S20', 'S31'], 'Map.fold': ['S31'], 'Map.forEach': ['S31'], 'Set.empty': ['S21'], 'Set.fromList': ['S21'], 'Set.toList': ['S21'], 'Set.contains': [], 'Set.add': ['S22'], 'Set.remove': ['S22'], 'Set.size': ['S21'], 'Set.union': ['S23'], 'Set.intersection': ['S23'], 'Set.difference': ['S23'], 'Set.map': ['S22', 'S31'], 'Set.filter': ['S22', 'S31'], 'Set.fold': ['S31'], 'Set.forEach': ['S31'], 'Range.checkInteger': ['S26'], 'Range.minimum': ['S26'], 'Range.maximum': ['S26'], 'Range.value': ['S26'], 'Range.checkLength': ['S27'], 'Range.lengthMinimum': ['S27'], 'Range.lengthMaximum': ['S27'], 'Range.checkedLength': ['S27'], 'Range.lengthValues': ['S27'], 'Range.checkIndex': ['S28'], 'Range.indexValue': ['S28'], 'Range.indexValues': ['S28'], 'Range.get': ['S28'], 'NonEmptyList.fromList': ['S30'], 'NonEmptyList.toList': ['S30'], 'NonEmptyList.head': ['S30'], 'NonEmptyList.tail': ['S30'], 'NonEmptyList.map': ['S30', 'S31']}

def digest(path):
 data=path.read_bytes()
 return {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}

for x in rows:
 x['rust_literal_sites']=rust.get(x['builtin'],[]) if x['builtin'] else []
assert {r['module']+'.'+r['name'] for r in rows}==set(RELATIONS)
assert sum(bool(r['builtin']) for r in rows)==244
assert all(not r['builtin'] or r['rust_literal_sites'] for r in rows)
for m in INV['api']:
 source=STDLIB/(m['module']+'.bnt')
 expected={k:m[k] for k in ['bytes','sha256'] if k in m}
 if expected: assert all(digest(source)[k]==v for k,v in expected.items())
artifacts={}
for part,subset in [('numeric',[r for r in rows if r['module'] not in ['String','Bytes','List','Map','Set','Range','NonEmptyList']]),('collections',[r for r in rows if r['module'] in ['String','Bytes','List','Map','Set','Range','NonEmptyList']])]:
 path=OUT/('api-'+part+'.json')
 path.write_text(json.dumps(subset,ensure_ascii=False,separators=(',',':'))+'\n')
 assert path.stat().st_size<=100000
 artifacts[path.name]=digest(path)
columns=['api','line','tparams_with_constraints','named_parameters','ordinary_result','effect','actual_builtin','actual_core_calls','additional_S','L40_status']
compact=[[r['module']+'.'+r['name'],r['line'],r['generics'],r['parameters'],r['result'],r['effect'],r['builtin'],r['calls'],RELATIONS[r['module']+'.'+r['name']],'未完'] for r in rows]
result={'status':'停止時の実ソース照合。全量化したF06の証明完了分類は未実施。各行の未完は後段への移管を意味しない。',
 'counts':{'modules':len(MODULES),'apis':len(rows),'builtin':244,'core':84,'L40_closed':0,'L40_unfinished':328,'transferred_L40_obligations':0},
 'limits':['Rust内の名前の出現は全244行で確認した。登録スキーマ・ABI・意味の一致の証明とは区別する。',
 'S行は追加関係の対象を示す。S指定のない行も通常結果型の証明は未完である。',
 'L50のFile/Http対象行は23モジュールの外にある。L60のモデル充足とR40/R50の本体・交換は未完のL40義務を代替しない。',
 'List四本の静的BodyTypedは現在のLean入力で証明した。実表の全APIへの照合と正常返却の関係は未完である。'],
 'columns':columns,'rows':compact,'source_modules':MODULES,'inputs':inputs,'artifacts':artifacts}
path=OUT/'sources.json';path.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
assert path.stat().st_size<=100000
print(json.dumps(result['counts'],ensure_ascii=False))
