"""版の候補・除外・依存ハッシュ案を読み取りだけで列挙する。"""
from pathlib import Path
import hashlib
import json
import re
V=Path(__file__).resolve().parent
ROOT=V.parents[2]
TD=ROOT/'crates/benitoite/testdata'
def sha(b): return hashlib.sha256(b).hexdigest()
def rel(p): return str(p.relative_to(ROOT))
def fixture(p):
 for a in [p,*p.parents]:
  if a==TD.parent: break
  if a.with_suffix('.mode').is_file(): return rel(a)
 return None
bnts=list(TD.rglob('*.bnt'))
paths={}
for p in bnts:
 text=p.read_bytes().decode('utf-8',errors='replace')
 for ref in re.findall(r'^\s*path "([^"]+)"',text,re.M):
  target=(p.parent/ref).resolve()
  if target in p.parents: continue  # 親への不正な依存は読込み前の重複拒否で止まる
  paths.setdefault(str(target),[]).append(p)
rows=[]
for p in sorted(bnts):
 b=p.read_bytes()
 if b'language "0.0.12"' not in b: continue
 consumers=set()
 f=fixture(p)
 if f: consumers.add(f)
 for a in p.parents:
  for source in paths.get(str(a),[]):
   consumers.add(fixture(source) or rel(source))
  if a==TD: break
 reader='golden（元の受理・拒否目的を保持）; export_desugar_corpus → corpus/builtins/stdlib/coverage・区間三出力 → 変更出力を読むdesugarDiff/builtinCheck/surfaceCheckAll/coverageProgramDiff/check_named、区間collect・実ソース比較、manifest/verify'
 if any('/json-wasm-same' in c or '/wasm-regex-same' in c for c in consumers):
  reader+='; export_interval_manifestのjson-wasm-same/wasm-regex-same'
 if any('/d6c-' in c for c in consumers): reader+='; named::export_extensible_source'
 rows.append(dict(path=rel(p),sha256=sha(b),lines=[i for i,line in enumerate(b.decode('utf-8').splitlines(),1) if 'language "0.0.12"' in line],change='language "0.0.13"へ。旧版拒否を狙う入力でなく、既存の検査段へ到達させるheaderである',reason='登録後のE0908による早期拒否・比較範囲減少を防ぐ',consumers=sorted(consumers),readers=reader))
assert len(rows)==50,len(rows)
files=['tests/cli_process.rs','tests/package_command.rs','tests/spec_examples.rs','tests/test_command.rs','tests/desugar_export/named.rs','src/modules/tests.rs','src/modules/hash.rs','src/external/tests.rs','src/typeck/tests/diagnostics_batch4.rs']
tests=[]
for f in files:
 p=ROOT/'crates/benitoite'/f;s=p.read_text();occ=[]
 for i,line in enumerate(s.splitlines(),1):
  if '0.0.12' not in line:continue
  if '0.0.12: each WASM' in line or 'see the 0.0.12 section' in line or '"0.0.11" => "0.0.12"' in line:
   action='保持。過去の0.0.12の変更説明・最初の互換変更の対応である。0.0.13のnote/helpは別行へ追加する'
  elif 'Some(DiagCode' in line or '("0.0.12", None)' in line:
   action='旧0.0.12の行を残しE0908へ。受理0.0.13・将来0.0.14を別行へ（差分案）'
  elif 'this file needs' in line:
   action='将来版0.0.14、現在版0.0.13へ（差分案）'
  else:action='成功用header・編集結果の0.0.12を0.0.13へ。境界表と過去の説明は上記別扱い'
  occ.append(dict(line=i,text=line.strip(),action=action))
 if f=='tests/desugar_export/named.rs':reader='named::export_extensible_packageの根とDepのheader二つ。六入口/check_named。export_extensible_sourceはtestdata d6c経由'
 elif f=='tests/spec_examples.rs':reader='spec_examples（01-03等の独立MemFs）。全比較の直接入力ではない'
 elif f.startswith('tests/'):reader=Path(f).stem+'。全比較の交換入力を直接作らない'
 else:reader='lib_default。loaderの版登録が全比較全般の受理へ影響する。MemFsの文字列自体は交換に収集されない'
 tests.append(dict(path=rel(p),sha256=sha(p.read_bytes()),reason='版登録後も検査本来の目的へ到達させる。過去の版の説明を保つ',readers=reader,occurrences=occ))
registry=dict(path='crates/benitoite/src/modules/package.rs',reason='BREAKING_CHANGESへVersion(0,0,13)を追加し、登録表を読むテストのnotes/helps/change_versions/current/end/firstを追随。旧版の文言は保持',test='version_check_reports_all_applicable_changes_in_version_order',readers='lib_default。登録自体はcheck_header経由で全比較のloaderに影響',proposal='j2-registration-proposal.patch')
text=dict(path='crates/benitoite/src/modules/text.rs',reason='J2再現に対応する事実だけのsummary/helpを追加。節の変更手順・移行例は含めない',readers='登録表経由のE0908。corpusの受理へはpackage.rsの登録を通して影響',proposal='j2-registration-proposal.patch')
diags=[]
for name in ['dependency-settings','newer-config','newer-language','older-language']:
 p=TD/'packages'/(name+'.diag.json')
 action='E0907の現在版表示だけ0.0.12から0.0.13へ。99.0.0の入力・位置・コードは保持'
 if name=='dependency-settings': action+='。E0914/E0915は保持。transitive/package.bntのheader更新も別途必要'
 if name=='older-language':action='入力の0.0.4と最初の互換変更0.0.5・既存note/helpを保持し、末尾に0.0.13のnote/help（各1件）を追加。現在版表示の置換はない'
 diags.append(dict(path=rel(p),sha256=sha(p.read_bytes()),change=action,reason='新版の診断をgoldenで照合',readers='golden。export_desugar_corpusは.diag.jsonを読まない'))
# 06-09の規則をそのまま独立に実装し、変更後のバイトをメモリ上で要約する。
def digest(files):
 return 'sha256:'+sha(b''.join((sha(b)+'  '+p+'\n').encode() for p,b in sorted(files.items(),key=lambda kv:kv[0].encode())))
def variant(files):return {p:b.replace(b'language "0.0.12"',b'language "0.0.13"') for p,b in files.items()}
hashkit=TD/'packages/hash-match/deps/hashkit'
hf={p.name:p.read_bytes() for p in hashkit.iterdir() if p.is_file()}
modulef={'package.bnt':b'language "0.0.12"\npackage Textkit\nend package\n','Z.bnt':b'abc\r\n','A/Sub.bnt':b'abc\n','License.md':b'MIT\n','readme.md':b'example\n','COPYING':b'copy\n','wasm/x.wasm':bytes([0,97,115,109,255])}
packagef={'package.bnt':b'language "0.0.12"\n\npackage Words\nend package\n','Value.bnt':b'import Benitoite.Unofficial.IO.File\n\npublic function read() -> Unit uses File.Read\n  ()\nend function\n'}
hashes=[]
for name,fs,targets in [
 ('hashkit',hf,['crates/benitoite/testdata/packages/hash-match/package.bnt','crates/benitoite/testdata/packages/hash-mismatch.diag.json']),
 ('modules-hash',modulef,['crates/benitoite/src/modules/hash.rs::FIXED']),
 ('package-command',packagef,['crates/benitoite/tests/package_command.rs::add_and_update_record_hashes_effect_deltas_and_unchanged_state'])]:
 old=digest(fs);new=digest(variant(fs));hashes.append(dict(name=name,old=old,proposed=new,targets=targets,inputs=[dict(path=p,oldSha256=sha(b),proposedSha256=sha(variant(fs)[p])) for p,b in fs.items()],rule='06-09「中身のハッシュ」。各fileのSHA-256小文字hex＋空白二つ＋相対path＋LFをUTF-8のpath順に連結し、全体SHA-256へsha256:を付ける。バイト列の改行は変更しない'))
 assert any(old in (ROOT/t.split('::')[0]).read_text() for t in targets),name
exclusions=[dict(path=rel(TD/'packages/older-language/main.bnt'),reason='0.0.4を狙うE0908。宣言は保持'),dict(path=rel(TD/'packages/newer-language/main.bnt'),reason='99.0.0を狙うE0907。宣言は保持'),dict(path=rel(TD/'packages/newer-config/package.bnt'),reason='99.0.0を狙うE0907。宣言は保持'),dict(path=rel(TD/'packages/dependency-settings/deps/future/package.bnt'),reason='99.0.0を狙う依存のE0907。宣言は保持'),dict(path='crates/benitoite/testdata/packages/hash-mismatch/main.bnt',reason='不一致を狙うゼロのhashは保持。computedだけ更新'),dict(path='crates/benitoite/src/modules/package.rs',reason='0.0.5〜0.0.12の登録・過去のnote/helpと旧版境界を保持。差分案で0.0.13だけ追加'),dict(path='crates/benitoite/src/modules/text.rs',reason='旧版のCHANGE/MIGRATIONは保持。新helpの事実だけの制約を過去の説明へ遡及しない'),dict(path='CHANGELOG.md',reason='過去の版の説明は一括置換しない。今回の移行手順・移行例を作らない')]
data=dict(base='bae86164de063a9807784513e8960e46536d9f4b',applied=False,testdata=rows,testFiles=tests,registry=registry,text=text,diagnostics=diags,hashProposals=hashes,exclusions=exclusions)
(V/'j2-rewrite-inventory.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
md=['# J2 の書き換え一覧（未適用）','', 'パスはリポジトリの根から省略せず記す。適用は V10.3a の版上げと同時である。各出現の行番号・内容・ハッシュは [JSON の全一覧](j2-rewrite-inventory.json) を正とする。','', '## testdata の50候補','', '| パス | 変更理由と依存して読む入力 |','|---|---|']
for r in rows:md.append('| `'+r['path']+'` | '+r['reason']+'。'+('、'.join('`'+c+'`' for c in r['consumers']) or '通常の発見対象')+' |')
md+=['','この50件は成功用の版宣言である。拒否を狙うfixtureにも、その目的の検査まで進めるための正常な依存headerがある。`.files` は独立に収集せず依存として読む。通常のfixtureは `export_desugar_corpus` が読み、出力が変わった場合は desugarDiff・builtinCheck・surfaceCheckAll・coverageProgramDiff・check_named と区間 collect・実ソース比較・manifest/verify を再確認する。`libraries.files/{wasm-json,pure-json,wasm-regex}` は `export_interval_manifest` の json-wasm-same/wasm-regex-same からも読まれる。d6c の三パッケージは `named::export_extensible_source` の入力でもある。単なるheaderの同じ長さの変更だけで出力不変としない。','', '## テストと登録・文言','', '| パス | 変更と読者 |','|---|---|']
for r in tests+[registry,text]:md.append('| `'+r['path']+'` | '+r['reason']+'。'+r['readers']+' |')
md+=['','統合5ファイル・src内4ファイルの計9ファイルに、登録表を含むpackage.rsとtext.rsの2ファイルを加えて11ファイルである。modules/tests.rs は境界テストだけを差分案に含め、残りの成功用headerは一覧に記した。named.rsの二header以外のテスト内MemFs文字列を全比較へ収集したとはしない。','', '## 診断期待値','', '| パス | 変更 |','|---|---|']
for r in diags:md.append('| `'+r['path']+'` | '+r['change']+'。'+r['readers']+' |')
md+=['','## 依存のハッシュ','', '06-09「中身のハッシュ」に従う独立した再計算案である。ファイルを変更せず、0.0.13のheaderのバイト列をメモリ上で用いた。旧値は既存の固定値と一致した。','', '| 対象 | 旧値 → 提案値 | 変更先 |','|---|---|']
for h in hashes:md.append('| '+h['name']+' | `'+h['old']+'` → `'+h['proposed']+'` | '+'、'.join('`'+t+'`' for t in h['targets'])+' |')
md+=['','hash-match の成功値と hash-mismatch の computed note を対で更新する。hash-mismatch の expected=全ゼロは保持する。package コマンドのadd/updateはCONFIG変更後の同じファイル集合で再計算し、動的に得るhashや包含条件の試験を固定文字列へ変えない。modules/hash.rsのFIXEDもCONFIGと同時に更新する。全比較はhash-match/mismatchのloaderを経るため一般corpusの再出力で受理と診断付き除外を照合する。テスト内の独立fixtureのhashはlib/package_commandが読者である。','', '## 一括置換から除くもの','', '| パス | 理由 |','|---|---|']
for r in exclusions:md.append('| `'+r['path']+'` | '+r['reason']+' |')
(V/'j2-rewrite-inventory.md').write_text('\n'.join(md)+'\n')
print('testdata',len(rows),'tests',len(tests),'登録/文言',2,'diag',len(diags),'hash案',len(hashes),'除外',len(exclusions))
for h in hashes: print(h['name'],h['old'],'->',h['proposed'])
