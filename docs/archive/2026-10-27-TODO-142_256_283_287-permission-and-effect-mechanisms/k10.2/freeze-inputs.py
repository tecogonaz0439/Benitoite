"""比較より先に、公開契約から手書きの入力・期待値を固定する。処理系を呼ばない。"""
import hashlib
import json
from pathlib import Path
import shutil
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
DEST = ROOT / 'crates/benitoite/tests/desugar_export/range-sources'
FROZEN = HERE / 'independent'
if (FROZEN/'expected.json').exists():
    raise SystemExit('初稿の固定後は再生成しない。訂正は入力と理由を別記録に残す')
DEST.mkdir(exist_ok=True)
FROZEN.mkdir(exist_ok=True)
S = 'import Benitoite.Unofficial.Scope as S\n'
H = 'import Benitoite.Unofficial.Network.Http\n'
F = 'import Benitoite.Unofficial.IO.File\n'
cases = []
def add(name, source, **expected):
    source = source.rstrip() + '\n'
    path = DEST / (name + '.bnt')
    path.write_text(source)
    shutil.copy2(path, FROZEN / path.name)
    cases.append({'name': name, 'file': path.name, 'sha256': hashlib.sha256(source.encode()).hexdigest(), **expected})
for name, host, scope in [
    ('host-one', '*.example.com', '"*.example.com", 443'),
    ('host-many', '**.example.com', '"**.example.com", 443'),
    ('ipv4-exact', '192.0.2.7', '"192.0.2.7", 443'),
    ('ipv4-cidr', '192.0.2.0/24', '"192.0.2.0/24", 443'),
    ('ipv6-exact', '2001:db8::7', '"2001:db8::7", 443'),
    ('ipv6-cidr', '2001:db8::/32', '"2001:db8::/32", 443'),
    ('port-range', 'api.example.com', '"api.example.com", 80..443'),
]:
    lo = 80 if name == 'port-range' else 443
    add(name, H + f'''function sample(raw: Http.ClientRequest) -> Unit
 bind checked: Result[Http.RequestIn[{scope}], Http.RequestCheckError] <- Http.checkRequestIn(hostPattern: "{host}", minimumPort: {lo}, maximumPort: 443, request: raw)
end function''', exit=0, definitions=1, nonTopRangesMinimum=1,
        required=[{'definition':'sample','surfacePreorder':0, 'declaration':'Http.checkRequestIn', 'index':scope}],
        surface={'ok': True})
add('path-tree', S + '''function sample(raw: String) -> Unit
 bind checked: Result[S.PathIn["/data/**"], S.ScopeError] <- S.checkPathIn(pattern: "/data/**", path: raw)
end function''', exit=0, definitions=1, nonTopRangesMinimum=1,
 required=[{'definition':'sample','surfacePreorder':0,'declaration':'Scope.checkPathIn','index':'"/data/**"'}], surface={'ok':True})
add('request-retained', H + '''function sample(raw: Http.ClientRequest) -> Http.ClientRequest
 bind checked: Result[Http.RequestIn["api.example.com", 443], Http.RequestCheckError] <- Http.checkRequestIn(hostPattern: "api.example.com", minimumPort: 443, maximumPort: 443, request: raw)
 return match checked with
 case Result.Ok(value) ->
  bind wide: Http.RequestIn["**.example.com", 80..443] <- Http.widenRequestIn(request: value)
  bind projected <- Http.requestInValue(request: wide)
  bind changed <- Http.ClientRequest(..projected, method: "DELETE", timeoutMilliseconds: 12)
  bind original <- Http.requestInValue(request: value)
  original
 case Result.Error(_) -> raw
 end match
end function''', exit=0, definitions=1, nonTopRangesMinimum=1, surface={'ok':True})
add('path-widen', S + '''function sample(raw: String) -> String
 bind checked: Result[S.PathIn["/data/a"], S.ScopeError] <- S.checkPathIn(pattern: "/data/a", path: raw)
 return match checked with
 case Result.Ok(value) ->
  bind wide: S.PathIn["/data/**"] <- S.widenPathIn(path: value)
  bind projected <- S.pathInValue(path: wide)
  projected
 case Result.Error(_) -> raw
 end match
end function''', exit=0, definitions=1, nonTopRangesMinimum=1, surface={'ok':True})
add('shorthand-location', S + F + '''function sample(value: S.PathIn["/data/a"]) -> Result[String, IOError] uses File.Read["/data/**", "/backup/**"]
 return File.readTextIn(path: value)
end function''', exit=0, definitions=1, nonTopRangesMinimum=1, surface={'ok':True},
    bounds=['"/backup/**"','"/data/**"'], sourceLine=4)
add('old-ip', S + '''function sample(raw: String) -> Result[S.CheckedHost, S.ScopeError]
 return S.checkHost(pattern: "192.0.2.0/24", host: raw)
end function
function endpoint(raw: String) -> Result[S.CheckedEndpoint, S.ScopeError]
 return S.checkEndpoint(hostPattern: "2001:db8::/32", minimumPort: 80, maximumPort: 443, host: raw, port: 443)
end function''', exit=0, definitions=2, nonTopRangesMinimum=0, surface={'ok':True}, compatibility='旧ScopeのIP/CIDR・正規化したパターンの保存')
add('user-spelling', '''function checkPathIn(pattern: String, path: String) -> String
 return path
end function
function sample(raw: String) -> String
 return checkPathIn(pattern: "relative/**", path: raw)
end function''', exit=0, definitions=2, nonTopRangesMinimum=0, surface={'ok':True}, compatibility='同じ綴りの利用者関数は標準規則として認定しない')
add('all-top', S + '''function sample(raw: String, pattern: String) -> Result[S.PathIn, S.ScopeError]
 return S.checkPathIn(pattern: pattern, path: raw)
end function''', exit=0, definitions=1, nonTopRangesMinimum=0, nonTopRanges=0, surface={'ok':True}, compatibility='動的条件のTop')
# 拒否の必須判定は独立した交換も手で作る。rawは動的なので既知不良診断へ流れない。
add('required-not-covered', S + '''function sample(raw: String) -> Unit
 bind checked: Result[S.PathIn["/data/a"], S.ScopeError] <- S.checkPathIn(pattern: "/data/**", path: raw)
end function''', exit=2, codes=['E0519'], reason='notCovered', comparison='required', leanCase='path',
    requiredIndex={'path':{'tree':['data']}}, contract={'path':{'exact':['data','a']}}, key={'definition':'sample','surfacePreorder':0})
add('required-unknown', S + '''function sample(pattern: String, raw: String) -> Unit
 bind checked: Result[S.PathIn["/data/**"], S.ScopeError] <- S.checkPathIn(pattern: pattern, path: raw)
end function''', exit=2, codes=['E0519'], reason='unknownSource', comparison='required', leanCase='unknown-path',
 requiredIndex='top', contract={'path':{'tree':['data']}}, key={'definition':'sample','surfacePreorder':0})
add('request-widen-rejected', H + '''function sample(value: Http.RequestIn["api.example.com", 443]) -> Unit
 bind wide: Http.RequestIn["**.example.com", 80..443] <- Http.widenRequestIn(request: value)
end function''', exit=2, codes=['E0519'], reason='unknownSource', comparison='required', leanCase='widen-request',
 requiredIndex='top', contract={'endpoint':{'host':{'name':{'exact':['api','example','com']}},'ports':{'lo':443,'hi':443}}},
 key={'definition':'sample','surfacePreorder':0})
for name,upper,reason in [('effect-not-covered','"/data/**"','notCovered'),('effect-atomic','"/data/**", "/backup/**"','atomicCoverOnly')]:
    add(name, F + f'''function callee() -> Unit uses File.Read["/**"]
end function
function sample() -> Unit uses File.Read[{upper}]
 callee()
end function''', exit=2,codes=['E0519'],reason=reason,comparison='typing',leanCase=name,leanReason='effect exceeds the allowed effect')
add('effect-top', F + '''function callee() -> Unit uses File.Read
end function
function sample() -> Unit uses File.Read["/**"]
 callee()
end function''',exit=2,codes=['E0519'],reason='unknownSource',comparison='typing',leanCase='effect-top',leanReason='effect exceeds the allowed effect',leanAtomReason='unknownSource')
for name,call,code,ty,err in [
 ('old-invalid-pattern','S.checkPath(pattern: "relative/**", path: raw)','E0459','S.CheckedPath','S.ScopeError'),
 ('old-invalid-target','S.checkHost(pattern: "::/0", host: "::ffff:192.0.2.7")','E0460','S.CheckedHost','S.ScopeError'),
 ('old-invalid-ports','S.checkEndpoint(hostPattern: "api.example.com", host: raw, minimumPort: 443, maximumPort: 80, port: 80)','E0461','S.CheckedEndpoint','S.ScopeError'),
 ('old-outside','S.checkPath(pattern: "/data/**", path: "/outside")','E0462','S.CheckedPath','S.ScopeError'),
 ('new-invalid-pattern','S.checkPathIn(pattern: "relative/**", path: raw)','E0459','S.PathIn','S.ScopeError'),
 ('new-invalid-target','S.checkPathIn(pattern: "/data/**", path: "relative")','E0460','S.PathIn','S.ScopeError'),
 ('new-invalid-ports','Http.checkRequestIn(hostPattern: "api.example.com", minimumPort: 443, maximumPort: 80, request: req)','E0461','Http.RequestIn','Http.RequestCheckError'),
 ('new-outside','S.checkPathIn(pattern: "/data/**", path: "/outside")','E0462','S.PathIn','S.ScopeError'),
]:
    add(name,S+H+f'function sample(raw: String, req: Http.ClientRequest) -> Result[{ty}, {err}]\n return {call}\nend function',exit=2,codes=[code],comparison='excluded',excluded=[f'Some({code})'])
# 実行時のInvalidTargetとInvalidUrlを混同しない。動的URLと動的条件からTopで検査する。
add('request-errors', S+H+'import Benitoite.Unofficial.IO.Console\n'+'''function classify(url: String) -> String
 bind raw <- Http.clientRequest(method: "GET", url: url)
 bind result <- Http.checkRequestIn(hostPattern: "**.example.com", minimumPort: 0, maximumPort: 65535, request: raw)
 return match result with
 case Result.Ok(_) -> "Ok"
 case Result.Error(Http.RequestCheckError.InvalidUrl(_)) -> "InvalidUrl"
 case Result.Error(Http.RequestCheckError.Scope(S.ScopeError.InvalidTarget(_, _))) -> "InvalidTarget"
 case Result.Error(_) -> "other"
 end match
end function
function main() -> Unit uses Console
 Console.writeLine(classify(url: "http://127.1/"))
 Console.writeLine(classify(url: "ftp://api.example.com/"))
 Console.writeLine(classify(url: "http://[::ffff:192.0.2.7]/"))
end function''', exit=0,definitions=2,nonTopRangesMinimum=1,surface={'ok':True},runStdout='InvalidTarget\nInvalidUrl\nInvalidTarget\n', runEffects='Console')
manifest={'version':1,'baseline':'c3ca4504dae42271df7336aca41d0a6d5447d0e3','basis':'公開契約とScope規則から比較実行前に手書き。Rust/Lean出力を期待値へ使わない','rule':'期待値だけを変更しない。誤りは初稿・不一致を保存して入力側を訂正するか停止する','cases':cases}
text=json.dumps(manifest,ensure_ascii=False,indent=2)+'\n'
(DEST/'expected.json').write_text(text)
(FROZEN/'expected.json').write_text(text)
# 報告側26入力は部分集合として別に保持する。
r40=HERE.parent/'r40.3'
shutil.copytree(r40/'inputs',FROZEN/'report-inputs',dirs_exist_ok=True)
shutil.copy2(r40/'handoff.json', FROZEN/'report-expected.json')
files={str(p.relative_to(HERE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(FROZEN.rglob('*')) if p.is_file()}
(HERE/'independent-sha256.json').write_text(json.dumps(files,indent=2)+'\n')
print(len(cases), '独立実ソースと期待値を比較前に固定した')
