from pathlib import Path
p=Path('docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/study/language-rules.md')
s=p.read_text()
def replace(old,new):
 global s
 assert old in s, old[:100]
 s=s.replace(old,new)
def section(start,end,new):
 global s
 a=s.index(start); b=s.index(end,a)
 s=s[:a]+new.rstrip()+'\n\n'+s[b:]
replace('最後の R1〜R23 が設計者への問いである。','末尾の Q1〜Q14 が設計者への問いである。RV-S8 に従う S8b の修正版であり、旧 R 番号との対応と指摘への対応を末尾に示す。')
section('作業ツリーの基準は','[README]', '''言語規則と計画の開始版は `san_benito` の `3597b310ea0d91fb3a3bb3fcf281c7aa57ac9a34` とする。S8b の文書修正を始めた HEAD は `b0675576470e52bc81de4e840ee75d4b71bb260e` で、作業ツリーに差分はなかった。S8 初版の調査基準 `80d1eead` から開始版まで、および開始版からこの HEAD まで、設計書・Rust・Lean・検査スクリプトの差はないことを読み取り専用の git diff で確認した。S8 の集計はこの同一性に基づいて引用する。

`AGENTS.md` を読み、今回の依頼を優先して `private/` とそこを指すスキルのリンクを読んでいない。公開の `japanese-tech-writing` に従った。S8b では本文と `work/m013/scratch/S8b/` の下だけを変更し、ビルド、Cargo のテスト・測定、`scripts/check*.sh`、Lean の実行、LLM を呼ぶ評価、状態を変える git の操作は行っていない。勧告については既存記録の「今回は組み込まない」を C1 に引き継ぐ。新しい勧告照合を行ったとはしない。''')
replace('declassification と endorsement は原語で書く。','非機密化（declassification）とエンドースメント（endorsement。信頼の付与、または完全性レベルの引き上げ）は、README「設計者の決定（2026-10-27、訳語）」に従って書く。')
replace('根拠の記録は `<repo>/work/m013/scratch/S8/` にある。','S8 初版の根拠の記録は `work/m013/scratch/S8/` にある。S8b の追加の検索結果、参照位置、作業枠の算術、文書の点検結果は `work/m013/scratch/S8b/` に置く。以下の表のファイル名は S8 の記録を指す。')
replace('（R1・R2・R16〜R18）','（Q1・Q11・決定済みの旧 R18）')
replace('（R2〜R4）','（Q1・Q3）')
replace('（R5）','（Q12・Q13）')
replace('（R6〜R11・R15）','（Q2・Q4〜Q7）')
replace('（R8・R12・R13）','（Q5・決定済みの旧 R12・R13）')
replace('（R14・R23）','（Q8・Q9）')
replace('（R9・R15・R18）','（Q2）')
replace('（R19・R21）','（Q3・Q10）')
replace('従って R3 は','従って Q3 は')
replace('追加の判断 R8・R9','追加の判断 Q2・Q5')
replace('declassification/endorsementの契約','非機密化（declassification）とエンドースメント（endorsement）の契約')
replace('List.bnt:68','List.bnt:67')
replace('1232・1244','1231・1244')
replace('`Lemmas/Basic.lean:88・94`','`Release/Lemmas/Basic.lean:88・94`')
replace('06-01、06-04、06-06。方針側','06-01、06-03、06-04、06-06。方針側')
anchor='この区別は構文解析と名前解決の両方の契約にする。'
replace(anchor,anchor+'''

範囲引数の EBNF の案を次に示す。字句の分類は既存の `Type` と文字列・整数の字句を使い、型名を解決してから引数の種類を検査する。`StringLit` は補間のない文字列リテラル、`IntLit` は既存の整数リテラルであり、ポートとしての値域は A2 で検査する。ここでの `ScopeArgs` 等は生成規則の名前である。

```ebnf
EffectRef   = QualUpper [ EffectArgs ] .
EffectArgs  = "[" CommaList(Type) "]" | ScopeArgs .
ScopeArgs   = "[" ScopeArg { "," ScopeArg } [ "," ] "]" .
ScopeArg    = StringLit | PortArg .
PortArg     = IntLit [ ".." IntLit ] .
```

`File.Read`・`File.Write` は StringLit 一つ、`Http.Connect` は StringLit と PortArg の二つを要求する。新しい値型の角括弧も同じ ScopeArgs を使い、PathIn は前者、RequestIn は後者の個数と種類を要求する。HostIn・EndpointIn を後から加えるなら、それぞれ一文字列、文字列とポートとする。裸の新型は Top、部分的な省略は不正とする。型の別名の展開先にもこの区別を保つ。

型引数は型を始める字句、範囲引数は文字列・整数の字句で分ける。`1..5` は IntLit・DotDot・IntLit となる（`crates/benitoite/src/lexer/tests.rs:996`）。ただし `File.Write[Integer]` のような構文上は型引数の入力も保持し、名前解決後に範囲引数が必要だと診断する。`Failure.Fail["x"]` も、範囲の構文として読んだ後で Fail が型を必要とすると診断できる形にする。空の角括弧や式などの不正入力を受け取る回復処理は、受理する生成規則を広げる意味にはしない。診断の分担は A3・Q12 で比較する。''')
replace('| 範囲引数の形式・個数・対象種が不正 | 新 E0520 候補。Fail の型引数の E0513 を範囲専用エラーへ改変しない |','| 範囲を取る標準名の引数の形式・個数・対象種が不正 | 新 E0520 候補。名前解決後の期待する引数の種類で分け、Fail の型引数の E0513 を保つ |')
anchor='E0519 の `reason` は'
replace(anchor,'''E0513 と E0520 の境界は、推す案では「その名前が何を引数に要求するか」で決める。`File.Write[Integer]` は範囲を取る名前への型の入力なので E0520、`Failure.Fail["x"]` は型を取る名前への範囲の入力なので E0513 とする。`Failure.Fail` の引数なし・複数も E0513、引数を取らない利用者エフェクトへの角括弧も既存どおり E0513 とする。現行 E0513 の宣言は `crates/benitoite/src/diag/codes.rs:951`、非 Fail の角括弧も拒否する検査は `typeck/decls.rs:296〜313` にある。代案は、型と範囲の取り違え・個数を共通の E0513、解析できた範囲の不良だけを E0520 とする方式である。前者は利用者が必要な引数の種類をコードで判別でき、後者は既存の分類を広く保てる。推す案では範囲を新しく認める三種について分類の変更を案内し、構文自体を回復できない場合の既存の構文診断と区別する（Q12）。

E0519 の `reason` は''')
replace('**旧型を保ち、新型を並存させる案を推す。**','旧型を保ち、新型を並存させる案を推す。初段の新型は PathIn と RequestIn に絞る。')
replace('| `Scope.HostIn["*.example.com"]` | そのホスト原子への所属を保証する値 |','| `Scope.HostIn["*.example.com"]`（追加候補） | そのホスト原子への所属を保証する値。初段には入れない |')
replace('| `Scope.EndpointIn["api.example.com", 443..445]` | ホスト原子と閉区間の積への所属を保証する値 |','| `Scope.EndpointIn["api.example.com", 443..445]`（追加候補） | ホスト原子と閉区間の積への所属を保証する値。初段には入れない |')
anchor='新型の引数省略は Top の略記にする案である。'
replace(anchor,'''HostIn・EndpointIn を直接受ける IO は後述の7入口にない。RequestIn は endpoint を内部に保持でき、別の公開 EndpointIn を要求しない。従って初段では両公開型・生成・射影を外す案を推す（Q6）。同時に入れる代案には、検査済み対象を利用者の純粋関数へ渡す用途があるが、型・値の所属・交換と文書の費用が増える。旧 CheckedHost・CheckedEndpoint の入口は保ち、後の追加に備えて中心の対象定義は host/endpoint を扱える形にしておく。

新型の引数省略は Top の略記にする案である。''')
section('値型の添字は不変とし、','新しい純粋な検査入口の候補', '''値型の添字は不変とし、`Ty.Le` へ非関数の共変変換を加えない案を推す。`PathIn["/data/a/**"]` は `PathIn["/data/**"]` と構造上異なる。IO のエフェクトが `/data/a/**` から `/data/**` へ含まれることとは別である。これにより現行の「非関数の型の包含なら等号」という補題の結論を保てる（`Release/Typing.lean:195`、`Release/Lemmas/Basic.lean:88・94`）。同じ狭い値から呼んだ IO 自体は、広いエフェクト契約の本体で使える。

一方、値を広い添字の引数へ渡すたびに、失敗しうる Result の再検査を要求する必要はない。Q4 では次を比べる。

| 方式 | 利用者への影響 | 形式化と推奨 |
|---|---|---|
| 不変、拡大も check*In で再検査 | 広い型や裸の Top の引数へ渡すたびに Result の処理が要る | 追加の変換規則は少ないが、既に包含を確認できる場合にも失敗の分岐が増える |
| 不変、失敗しない明示の拡大関数を追加 | `Scope.widenPathIn`・`Http.widenRequestIn`（候補名）で広い添字へ渡せる。戻り型の明示注釈から行き先 S を一意に決める | 推す。R を S が一原子で被覆することを静的に確かめ、同じ対象の所属を被覆の健全性から導く。Ty.Le は変えない |
| 添字の暗黙の共変 | 呼び出し時の明示変換が減る | 非関数の包含から等号を導く既存15定理の群などを変更する。今回推さない |

拡大関数は認定した標準の直接呼び出しとして、R と S が確定し、被覆が成立するときだけ型を付け、Result を返さない。対象を変えず、RequestIn では同じ要求を保ち、必要な内部の範囲情報だけを S に対応させる。Top への拡大も含む。狭小化や、包含を確認できない場合は従来どおり再検査が要る。利用者が範囲変数を宣言する多相を追加する意味にはしない。これは新しい署名の表の項目と所属保存の補題の仕事として計画へ割り当てる。''')
replace('| `Scope.checkHostIn(pattern: String, host: String)` | `Result[Scope.HostIn[R], Scope.ScopeError]`。同じ規則 |','| `Scope.checkHostIn(pattern: String, host: String)`（初段外） | `Result[Scope.HostIn[R], Scope.ScopeError]`。追加するなら同じ規則 |')
replace('| `Scope.checkEndpointIn(hostPattern: String, host: String, minimumPort: Integer, maximumPort: Integer, port: Integer)` |','| `Scope.checkEndpointIn(hostPattern: String, host: String, minimumPort: Integer, maximumPort: Integer, port: Integer)`（初段外） |')
replace('`Result[Http.RequestIn[H,P], NetworkError]`。URL の解析と所属を純粋に検査し、同じ request を保存する','`Result[Http.RequestIn[H,P], Http.RequestCheckError]`。URL の解析と所属を純粋に検査し、同じ request を保存する')
replace('| 射影 `Scope.pathInValue`・`hostInValue`・`endpointInHost`・`endpointInPort` | 普通の String・Integer を返す。射影だけで旧 String IO を狭い操作へ変えない |','| 射影 `Scope.pathInValue`・`Http.requestInValue` | 普通の String・ClientRequest を返す。射影だけで旧 IO を狭い操作へ変えない。HostIn・EndpointIn の射影は初段外 |')
anchor='既知の範囲は型検査で閉じた具体化引数として固定し、'
replace(anchor,'''`checkRequestIn` の誤りの型は、候補 `Http.RequestCheckError` を公開のデータ型として置き、`InvalidUrl(message: String)` と `Scope(error: Scope.ScopeError)` を区別する案を推す。範囲パターン・端点・所属の失敗は後者、URL の構文・非対応 scheme・要求から endpoint を得られない失敗は前者にする。既知定数の静的な拒否と、動的な入力の Result.Error には同じ分類を使う。代案は NetworkError に両方を分類して追加する方式、または ScopeError に URL 不良を足す方式である。専用型なら純粋な検査失敗を sendIn の通信失敗（引き続き NetworkError）から区別でき、Scope の誤りへ HTTP 固有の分類を加えずに済む。新しい公開型の費用を含めて Q7 で判断する。

既知の範囲は型検査で閉じた具体化引数として固定し、''')
anchor='新 `check*In` と `checkRequestIn` は、初段では認定できる直接呼び出しに限る案を推す。'
replace(anchor,anchor+''' pattern・hostPattern とポート端点はリテラルだけでなく、既存の定数評価で値を得られる `const` の直接参照も認める。const の連鎖は既存の評価と予算の範囲に従い、局所 bind の伝播や任意の純粋関数の実行は加えない。これは既存の Regex.compile と Scope の追加検査（01-06:203〜211）に揃える案である。const は新検査の値引数に使えるのであり、A1 の範囲注釈内の式・const 参照を認める意味ではない（Q5）。''')
replace('推論できない局所値は Top とし、狭い注釈を書いただけでは受理しない案を推す。','推論できない局所値は Top とし、狭い注釈を書いただけでは受理しない。これは既存の保証と決定済みの閉じた範囲からの制約であり、旧 R12 として再度の選択を求めない。')
section('新操作の節の引数を何型で束縛するかは、','利用者定義エフェクトへの範囲引数', '''新操作の節の引数の添字は、名前全体の捕捉とは別の判断 Q8 である。節に渡す値の型と、節が実行した IO の上限を次のように比べる。

| 方式 | 記録して同じ値を転送する節の上限 | 証明・制限と推奨 |
|---|---|---|
| 節の入口で必ず Top へ忘却 | 常に Top となり、狭い uses の関数では再検査なしに使えない | 同じ閉じた値が R から Top の型を持つ専用補題で済むが、記録・転送の用途の精度を失う |
| 保護本体の ε に同名の閉じた原子が一つだけなら、その原子 S を節の添字とする。複数・同名 Top・行変数があれば Top | 一原子の本体ならその S を保てる。複数・未知なら Top | 推す。捕捉した呼び出しの R が S で被覆されることから、同じ値に S の型を付ける専用補題へ一般化する |
| 内部の剛な範囲束縛で節を全称検査 | 各呼び出しの R を保持できる | 型・行・署名の束縛と代入が増える。初段には推さない |
| 有限な呼び出し出現ごとに節を複製 | 各出現の R を使える | 呼び出し追加で節の検査が変わる。初段には推さない |

推す案の S は、節の本体や期待される出力から逆算せず、節を検査する前の保護本体の ε から決める。部分ハンドラの場合も同じであり、同名原子がない場合も Top とする。Top を併記した行は冗長原子を消さない決定に従って Top にする。範囲を保持した行変数の具体化と、未確定の行変数とは区別する。

呼び出し側の具体化済み署名 `opSigAt(b,R)` と節側の `opSigAt(b,S)` を分け、捕捉直前の代入済みの閉じた実引数について「同じ値の R への所属と R の S への被覆から S への所属を導く」専用補題を証明する。これは一般の Ty.Le の共変でも、任意の局所変数の暗黙変換でもない。明示拡大（Q4）も同じ所属補題を使える。7 IO の戻り型は範囲添字を含まないため、両署名の結果型・型引数数・引数の契約名の一致を IOShape で確かめれば、resume の入力型も一致する。新しい操作は署名の表へ加え、このために値型や評価関係の構成子を追加しない（B1）。

一原子の本体では、捕捉した path の記録・転送は元の狭い S を使える。複数の範囲や行変数から捕捉する節は、固定の狭い範囲で再検査するか、既知の添字を持つ別の値を使う。節が元の対象と違う対象へ書くなら、その対象のエフェクトを出力へ加える規則は変わらない。''')
section('ただし、新 IO を File.Read/Write/Http.Connect','構成の境界は AGENTS.md', '''新 IO を File.Read・File.Write・Http.Connect の新しい操作として加えると、従来の全操作の節だけでは名前全体を除けなくなる。現行の型規則は一部の節だけを持つハンドラからその名前を除かない（01-06:592、`formal/Benitoite/Release/Typing.lean:120〜135`）。本体が旧操作しか呼ばなくても、節の網羅は名前の全操作の一覧で判定するためである。

特に Http.Connect は今は send 一操作だけである（`crates/benitoite/src/prelude/stdlib/Network/Http.bnt:23〜26`）。従って `case Http.send(r)` を持つハンドラは、今は名前全体を処理する。sendIn を追加すると、同じコードは部分ハンドラとなり Http.Connect が残る。外側が純粋な契約なら拒否され、許す契約があれば main の宣言上限の一覧や `effects.expanded` へ名前が新しく現れ、従来の `--allow-effects` に追加が必要になりうる。サーバの承認は未実装だが、その上限を承認に使うときにも説明すべき差である。実際の呼び出しが増えたと断定したり、自動で許可を追加したりせず、操作一覧の追加による表示の拡大と示す（00-01 原則2・3、`cli/check_report.rs:105`、`cli/effect_limit.rs:15`）。この帰結は規則から確定し、新構文の実行で再現済みという意味ではない。

Q2 では7入口の範囲と、この互換性の扱いを合わせて選ぶ。

| 案 | 互換性 | 形式化の手間 | 利用者に見える振る舞いと推奨 |
|---|---|---|---|
| (a) 新操作を追加し、移行を案内する | 従来の完全ハンドラに新節が必要 | 元 b と範囲実引数を分ける署名を証明し、既存の網羅規則を保つ | 推す。不足節、残る名前、main・allow-effects の差を明示し、元の上限を保つ移行例を示す。契約や許可を自動で広げない |
| (b) 表層で旧節から新節を合成する | 旧 send 節だけで新 sendIn も捕捉でき、従来の名前消去を保つ | 同じ要求の射影を挟んで `case Http.send(r)` の本体を新節にも使う。コアの操作 ID は別のまま。引数・結果・再開・束縛の保存と脱糖の型保存が要る | 利用者が書いていない新操作も旧節へ入る。明示した sendIn 節を優先し、二重節を作らない規則が必要。実 IO へ転送する旧節の Top はそのまま残す。初段には推さない |
| (c) 範囲付きの入口を新操作にせず、既存操作の具体化として登録する | 操作一覧を保ち、全操作ハンドラを維持できる可能性がある | 旧 String/ClientRequest の節と新しい検査済み引数の署名を、同じ b で対応させる関係が要る。入力の射影、節への変換、結果と同一対象の保存を証明する。範囲を操作 ID に埋め込まない | 旧節が新入口も捕捉することになる。単なる旧 IO のラッパーでは Top を消せない。署名の複数形を持つ規則の費用が増すため初段には推さない |

(b) は File の対応する旧節にも射影を挟んで適用できる。ただし旧 File.Read・File.Write の全操作が揃うときだけ名前を消す。File.Read は11操作、File.Write は12操作である（`IO/File.bnt:6〜29・32〜61`）。一般の利用者が全操作を処理していれば同じ互換性の問題がある。一操作だけの節は既に部分ハンドラなので、追加により初めて名前が残るという変化はない。

取りまとめの14ファイルの検索を、開始版の crates・tools・docs/design・docs/reference で再確認した。すべて一操作だけの節またはその要求の記述であり、case Http.send は0件、File の全操作ハンドラも0件であった。14には評価課題の task.json と task.md の2ファイルを含むため、実行可能なハンドラ14個とは数えない。翻訳と改造の検討文書の追加一致は別に記録した。検索式、ファイル・行、範囲と限界は `work/m013/scratch/S8b/evidence.md`・`handlers.json` にある。既存利用者の外部コードの件数は不明であり、「旧コードはすべて変更不要」とはしない。

(a) を推す理由は、今回調べた例に名前消去の変更対象がなく、合成・同一操作の複数署名という新規則を増やさずに範囲付きの入力を保てるためである。外部の完全ハンドラへの変更は移行案内に明記する。D00 で別名も含む棚卸しと生成物の更新先を固定し、R30・R40 で新節の不足と表示の差を照合する。新しい節を実 IO へ無条件に転送して空の上限とする移行は認めない。''')
# B1 is replaced in a separate step below.
p.write_text(s)
