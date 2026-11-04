# RV-L50.e: L50 群 E（L50.21〜.25）の独立レビュー

2026-11-04。対象はブランチ `m014/l50.e` の未コミットの作業木、基準 `7ece2393f5585203556d07d4851b6b946abb0e92`（HEAD と一致）。本番の変更6ファイル（`git diff 7ece2393 -- formal docs/design` は追加138行・削除0行）、新規4モジュール（`ScopeSignatures`・`ScopeSignatureFormation`・`ScopeDelta`・`RequestDelta`）、根の import、01-12 と 07-04 の写し、`l50/e/` の記録を見た。

読んだもの: 担当への依頼と報告、`l50/detail.md` の第2節（範囲付きの13 API の表と標準表16行）、第3節 F06・F07、第5節の L50.21〜.25 と群 E の完了条件、第9節、`l50/u02-options.md` の公開エラーの節、`l50/e/` の results.md・signatures.md・coverage.md・obligations.md・contracts.lean、`reviews/RV-L50.d.md`、`l40/stage-results.md` の `table_response` の行。Lean は新規4モジュールの全文、`ScopeDeclarations.lean` の全文、`Checked/Scope.lean` の `ScopeError`・`makePath`・`makeEndpoint`、`AtInput.lean` の `parseAtInput`・`parseUrlTarget`・`parseHost`、`ScopeLegacyContracts.lean` の `pathInput`、`Scope/Domain.lean` の `PathPattern.WF`・`IPPattern`、`BuiltinResponse.lean` の `BuiltinArgs`。処理系は `builtins/checked_scope.rs`（全文）、`builtins/funcs/scope.rs`（全文）、`builtins/funcs/http_client/checked_request.rs`（全文）、`builtins/table.rs` の範囲の位置・範囲の署名、`types/scope.rs` の `Path::parse`・`PathPattern::parse`・`Range`、`types/scope/ip_text.rs` の `parse_pattern`、`typeck/checked_args.rs` の対象の表、`prelude/stdlib/Scope.bnt`・`Network/Http.bnt`・`IO/File.bnt`・`Reference.bnt`、`tests/runtime_builtins.rs` の checkPathIn・checkRequestIn の関門のテストを読んだ。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l50-e/` に置いた。

## 結論

**条件付き可**（重0・中3・軽3・情報5）。

形式の側の完了条件は満たす。共通16署名は `ScopeSignatures.entries` に一行ずつあり、同じ有限の P（`ScopeDeclarations.program`）について `program_hasHttp`・`program_wellFormed`・`entries_scoped` が全行・全構成子を量化して成り立つ。全7 IO の ShapeOk（`io_op`）、発行の八欄（`pathBases_shape`）と IO 応答からの除外（`pathBases_no_io`）も全引数を量化する。二つの `response` は任意の P・B（前提は `HasFile`／`HasHttp` と `valKind`・`valContent` の等号だけ）、任意の Ψ と全 `BuiltinArgs` について、同じ δ の応答・`Outcome.Typed`・`AdequateResult`・Ground・非 exit を示す。主な十言明・型付けの規則・既存の定義は差分になく、公理は既定の三つの範囲に収まる。

条件は、二つの δ が処理系の振る舞いを写していない点の処置である。食い違いは理由の文字列（中1）、要求の失敗の payload と構成子（中2）、射影形の IPv6 の URL の受理（中3）の三つである。中3 は、処理系が Error を返す入力に Lean の δ が Ok を返す。中1・中2 は値の中身の違いで、Result の Ok/Error の別は一致する。いずれも群 E の言明の形を変えずに δ の定義の小さな変更で直せるか、少なくとも R30/R50 への申し送りとして記録すべきものである。どちらにするかは取りまとめの判断に委ねる。

取りまとめが気づいた点（パスの対象の理由の文字列）は本物である。処理系の `check_path` は `Path::parse` の失敗をすべて一つの理由 `text::PATH` の `InvalidTarget` にする。Lean は相対形・home 形とその他を別の理由に分ける。パターンの失敗の理由、ホスト条件の失敗の理由、要求の失敗の payload にも同じ種類の食い違いがある（中1・中2）。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 中1 | 中 | `ScopeDelta.lean` の `errorValue`（82〜85行）・`invalidPattern`（151行）・`run`（200〜202行）、`RequestDelta.lean` 98行、01-12・07-04 の ScopeDelta の段落 | パスの失敗の理由の文字列が処理系と違う。処理系（`checked_scope.rs` の `check_path`）は、パターンの解析失敗を `InvalidPattern(pattern, text::PATH_PATTERN)`、対象の解析失敗を区別せず `InvalidTarget(path, text::PATH)` にする（`scope.rs` の `path_in_result` が元の入力とこの理由を欄へ写す）。Lean はパターンの失敗に `"invalid pattern"` を使い、対象では相対形・home 形に `"absolute path required"`、その他に `"invalid path"` を使う。相対形・home 形とその他の区別は処理系にない。要求のホスト条件の失敗も、処理系の理由 `text::ENDPOINT_PATTERN` に対し、Lean は `ScopeDelta.invalidPattern` の `"invalid pattern"` を使う。01-12・07-04 の写しは、処理系にない理由と区別を δ の性質として書いている。構成子は一致する | 処理系の理由の文字列を Lean の定数にし（PATH_PATTERN・PATH・ENDPOINT_PATTERN）、対象の解析失敗の二枝を同じ理由にまとめる。`input_errors` は同じ値を返す形へ直し、相対形・home 形の拒否は値ではなく分岐の場合分けとして残す。理由を模型の外とするなら（`Checked.Scope.Pattern` の docstring は reason を模型の外と書く）、写しから具体の理由の字句を除き、results.md に処理系との違いを一行書く | 読めば確定 |
| 中2 | 中 | `RequestDelta.lean` の `urlText`（34〜36行）・`invalidUrl`・`run`（95〜108行）、01-12・07-04 の RequestDelta の段落 | 要求の失敗の payload と構成子が処理系と違う。(a) 処理系の `InvalidUrl` の欄は固定の説明 `text::INVALID_URL` であり、Lean は URL の原文を入れる。(b) URL は形式として正しくホストが不正な場合（`http://127.1/`、`https://example.com./` など）、処理系は `Scope(InvalidTarget(host, text::INVALID_HOST))` を返す（関門のテストの期待3の行）。Lean は `Val.reqTarget = none` になるので `InvalidUrl` を返す（検査2で両 URL の `parseUrlTarget = none` を確かめた）。(c) `OutsideScope` の第2欄は、処理系ではホストの綴り（角括弧を除く）、Lean では `urlText req`（URL 全体）である。`PortOutsideScope`・`InvalidPortRange` の整数の欄と、URL→ホスト条件→ポート範囲→ホスト所属→ポート所属の順は一致する | (a)(c) は欄に入れる文字列を処理系に揃える（ホストの綴りは解析済みの端点から作れないので、URL から authority のホストを切り出す補助を固定して使う）。(b) は `parseUrlTarget` が `Option` しか返さないため、δ だけではホストの不正と URL の不正を分けられない。URL の形だけを判定する段を固定の関数として前に置くか、R30/R50 への申し送りとして記録する | 読めば確定（(b) は実行で確定） |
| 中3 | 中 | `AtInput.lean` の `parseUrlTarget`（群 C で固定）を使う `RequestDelta.run` | 処理系は IPv4 射影形の IPv6 アドレスを対象として常に拒否する（`checked_scope.rs` の `host_target`、理由 `MAPPED_TARGET`。`checked_request.rs` の `endpoint` が URL のホストに適用する）。Lean の `parseUrlTarget "http://[::ffff:127.0.0.1]/"` は v6 の端点を返し、`RequestDelta.run (.absolute .top)` は条件 `"::/0"`・ポート 0〜65535・URL `http://[::ffff:127.0.0.1]:18081/` に `Result.Ok` を返す（検査3）。処理系の関門のテストは同じ入力を期待3（`Scope(InvalidTarget)`）とする。成功と失敗が逆になる唯一の食い違いである。原因は固定の `Val.reqTarget` にあり、`Http.sendIn` と At の対象にも同じ受理が及ぶ | `parseUrlTarget`（又は `parseHost` の URL 側）で射影形を拒否するか、δ の端点の取得の後に射影形の拒否を固定して置く。前者は群 C〜D の言明の再検査を要する。直さないなら、R30/R50 で比べる入力の差として results.md と obligations.md の H05 の行に記録する | 実行で確定 |
| 軽1 | 軽 | `ScopeDelta.parsePattern`（166〜174行）、`RequestDelta.parseHostPattern`（21〜26行） | 群 E で新しく書いた二つの解析が処理系より広い。`"//**"` を Lean は `tree []` として受理する（検査1）。処理系の `PathPattern::parse` は幹が `"/"` の木を拒否する。ホスト条件の CIDR の prefix の前置の 0（`"10.0.0.0/08"`）を Lean は受理する（`String.toNat?` が `"08"` を 8 と読む。検査2）。処理系の `ip_text::parse_pattern` は拒否する。計画は文字列の字句を外側とする（plan.md の範囲の表、パス変数の行）が、この二つは δ のために書いた固定の関数であり、揃える費用は小さい | `parsePattern` で `tree` かつ幹が `"/"`（`raw = "//**"`）を拒否し、`parseHostPattern` で長さ2以上の `"0"` 始まりの prefix と長さ4以上の prefix を拒否する。揃えないなら、字句の差として results.md に記録する | 実行で確定 |
| 軽2 | 軽 | `ScopeDelta.run` 194〜199行、`RequestDelta.run` 102〜106・108〜109行、results.md・coverage.md の δ の表 | 静的上限への不所属を、処理系は `OutsideScope(pattern, target)` で返す（`scope.rs` の `path_in_result`、`checked_request.rs` の `check`）。Lean は内部の `At staticIndex` を返す。処理系のテスト `scope_path_in_checks_static_membership_and_widen_preserves_the_object` のコメントのとおり、通常のソースからこの分岐は観測できない。検査器が結果の範囲を既知のパターン又は Top にするからである（`Scope.bnt`・`Http.bnt` の docstring）。一方、Lean の `BuiltinArgs` は任意の r を許すので、Lean ではこの分岐に到達する。引数の形の不一致（`"invalid arguments"`）と `groundVal = false` も、処理系では `Stop::Internal`、Lean では型付きの Error であり、型付きの入力では起きない。記録はこれらを「静的不所属」「その他の値列」とだけ書き、処理系との対応と到達の可否を書いていない | results.md の「同じ宣言と二つのチェック」に、処理系の三つの分岐との対応と、通常のソースから到達しないこと、Lean では任意の r で到達することを一行ずつ書く。これがあれば、内部の At の使用は U02 の公開形の選択に当たらないことも記録から読める | 読めば確定 |
| 軽3 | 軽 | 07-04 の篩の対応表（973〜974行） | 加えた行 `ScopeDelta・RequestDelta` の後に空行があり、表が二つに切れる。後半の `TargetModelConditions` 以下の行は見出しのない表になる。またこの行は節名「篩を含む状態の型付け」を書くが、「篩の正規形と制約の読み方」の「同節」の行の並びの途中にある。直後の `TargetModelConditions`・`CanonicalCells` の「同節」が指す節が読み違えられる | 空行を除き、この行を `PreparationTargets・PathBasesTargets・AtTargets・ScopeLegacyContracts` の行（1050行）の後へ移す。01-12 の二か所の段落の後の二重の空行も一つにする | 読めば確定 |
| 情報1 | 情報 | `ScopeSignatures.entries` と処理系の表 | 16署名の引数の名前・型・結果・効果・対象の位置は、`.bnt` の宣言と `table.rs` の `builtin_range_positions`・`builtin_range_signature` と一致する。checkPathIn・checkRequestIn は結果の型引数0（`ReturnArgument(0)`）、射影は引数0、拡大は引数0と結果、許容は `Covers { outer: 1, inner: 0 }`（Lean の `rs = [r,s] ∧ s.Covers r`）である。参照の2行は `reference`・`value` の名前と State の効果を持つ。IO 7行の実名は Lean の旧 `TargetTable` の略記（`File.readTextIn`・`Http.sendIn`）であり、処理系の `Benitoite.IO.File.readTextIn`・`Benitoite.Network.Http.sendIn` とは綴りが違う。前例どおりで、群 E の変更ではない。参照2行と発行の `admitsR` は第2の枝で偽になるが、`rs = []` なので `RangeAdmissible` の全 Top の枝で許される | なし | 読めば確定 |
| 情報2 | 情報 | `ScopeSignatures.pathBasesName` | 処理系には起点の発行がなく（detail 第11節が `PathBases` の名前の不在を確かめている）、比べる名前はない。既存の内部例と同じ `Example.pathBases` を使い、公開名を選んでいないので、公開形を先取りしていない。ただし共通表の行として L60 以降へ渡るので、接頭辞の `Example` が例の名前に見える。U02 と R30 で公開名を決めるときに置き換える前提を、取りまとめが承知していればよい | なし | 判断 |
| 情報3 | 情報 | `ScopeDelta.response`・`RequestDelta.response` | 任意の P・B を量化し、表への適用は既定ビルドの例（`builtins delta io` の lookup から）である。L40 の `response`（任意の P/B の元の全 BuiltinArgs）と同じ立ち位置で、`table_response` に当たる単独の表の定理は置いていない。群 F の `delta_typed` へ渡す受け口は results.md の受け渡しの表と obligations.md の O062 にある。`BuiltinArgs` を実際に構成する例はなく、前提が満たせることを実証してはいない。ただし `HasFile` は `program` で、`valKind`・`valContent` は表で `rfl` で満たされ、`BuiltinArgs` の欄は文字列二つと範囲一つで構成できる形であり、空疎ではないと判断する | なし | 判断 |
| 情報4 | 情報 | `ScopeDeclarations.program` | 13構成子と arity は `.bnt` と一致する（Result・Pair が2、ScopeError・ClientRequest・RequestCheckError が0。ClientRequest の五欄の型、RequestCheckError の `InvalidUrl(String)`・`Scope(Scope.ScopeError)`、ScopeError の6構成子の欄）。`ClientRequest` は `.bnt` では record、Lean では一構成子の data であり、群 A の有限宣言の形のままである。ScopeError の第7構成子 `At`（String×7）は群 A・D の内部形のままで、群 E は変えていない。処理系にはこの構成子がなく、軽2のとおり到達しない分岐でだけ使う | なし | 読めば確定 |
| 情報5 | 情報 | 既存の定義と公理 | 差分は既存3ファイルへの追加（`TargetTable.valKind`、`ScopeDeclarations.program` と三つの定理、`parseAtInput_host_loopback`）と根の import だけで、削除は0行である。主な十言明のファイルと `Typing.lean` は差分にない。`#print axioms` の7件はすべて `propext`・`Classical.choice`・`Quot.sound` の範囲内で、`sorryAx` はない。private と生成の宣言を含む521宣言の監査は担当の記録を引用し、再実行していない | なし | 実行で確定 |

## 観点ごとの根拠

### 1. 二つの δ と処理系

- パスの分け方: 処理系の `check_path_in` は、`check_path`（パターンの形式→対象の形式→動的な所属）の後に、`Path::parse` をやり直して静的範囲の所属を見る。Lean の `run` は `parsePattern`→`parseAtInput`→`makePath`→静的上限の順であり、検査の順は一致する。`makePath` の `invalidPattern`・`invalidTarget` の枝は、`parsePattern` が `WF` を、`parseAtInput` が `PathWordWF` を保証するので到達しない。到達するのは `outsideScope` だけで、payload（元の pattern と target）は処理系と一致する。成功値は、処理系では元の String を一欄の record に保存し、Lean では解析済みの語の `checked` にする。値の表現の違いで、射影は群 F の担当である。
- 要求の分け方: 処理系の `check` は、URL の解析（URL の形→ホスト→射影形の拒否）→ホスト条件の解析→最小・最大のポート→範囲の大小→ホスト所属→ポート所属→静的範囲の順である。Lean は `groundVal`→`reqTarget`→`parseHostPattern`→`makeEndpoint`（パターン形式・ホスト形式・ポート範囲・ポート形式・ホスト所属・ポート所属）→静的上限の順で、順は一致する。食い違いは中2・中3のとおりである。成功時の保持は、処理系が同じ要求の record・正規化したホスト・ポートの三欄、Lean が `checkedRequest (.endpoint endpoint) req` であり、同じ要求を作り直さない点は一致する。
- 静的な不所属と内部の At: 軽2のとおりである。処理系では型検査を通ったプログラムで起きず、テストは raw の呼び出しでだけ確かめている。

### 2. 共通16署名

情報1のとおり、処理系の表と `.bnt` の宣言に一致する。`Example.pathBases` の名前の選び方は情報2のとおりで、公開名を選んでいないことは妥当である。

### 3. 同じ宣言の形成

`program_arity` は5つのデータ宣言それぞれについて、同じデータ名を持つ全構成子の arity の一意性を lookup の所属から示す。`program_wellFormed` は13構成子のすべての欄について `SourceScoped`・`WF`・`HasKind`・`Declared` を場合分けで示し、関数・操作・型クラス・実装・外部宣言が空であることを示す。`ScopeError` の具体化は、群 A の `scopeError` 宣言と `AtContracts.atErrorType`（`.data "Scope.ScopeError" []`）をそのまま使い、群 D の内部保存（`Detail`）と矛盾しない。旧表の opaqueTop の略記をやめた理由は signatures.md にある。公開形の選択には当たらない（情報4、軽2）。

### 4. 応答の契約

`response` は `BuiltinArgs` から ts・es が空、rs が一要素、結果型が `.data "Result" (checkTys r)` であることを、署名の依存列の具体化（`instantiated`）から導く。前提に δ の結果の型付けや CoreAssumptions を置いていない。`RequestDelta.run_safe` の値列の型付けは `response` が `BuiltinArgs.arguments` から取り出すので、独立の前提ではない。`contracts.lean` は群 A の `F07Pure`・`F07Ground` の全称形へ二つの δ を当て、同じ表で通ることを示している。空疎でないことの判断は情報3のとおりである。

### 5. ShapeOk と効果の表

`io_op` は16行を場合分けし、IO 以外の9行を kind の矛盾で除き、File の6行を `single .path 0`、`Http.sendIn` を `single .endpoint 0` とする。効果の登録（`effects`）は処理系の効果（`File.Read` に読み取り2、`File.Write` に書き込み・追記4、`Http.Connect` に `sendIn`）と一致する。`State` の空の登録は、参照の2行が操作効果を持たない（`opEff = none`）ことと合う。`PathBasesShape` の八欄は `pathBases_shape` が同じ効果表から示す。`builtins` の `ioResponse` は lookup の種類が io 又は exit の行に限るので、発行は全引数で除かれる（`pathBases_no_io`）。三形の適用例は別の表（`shapeTable`）で示し、件数に足していない。

### 6. 既存の定義・言明・公理

情報5のとおりである。

### 7. 設計書の写しと記録

01-12 の追加6段落と 07-04 の追加3段落・表の2行は、本番の宣言名・前提・結論と一致する。理由の字句と区別の記述が処理系と違う点は中1、表の切れ目は軽3である。01-12 の冒頭（25行）は「篩を含むコア計算の形式化」から「篩を含む状態の型付け」までを処理系の実装との対応から除くので、写しの記述は規範として処理系に課すものではない。ただし δ は後の段で処理系と比べる対象であり（plan.md の R30/R50、detail の H05）、食い違いの記録はその比較のために要る。段名・工程の ID・未実装の作業・変更前との比較の文は、本番のコメントと写しのどちらにもない。`#eval`・`sorry`・`axiom`・`native_decide` は本番にない。

`l50/e/` の最大のファイルは declarations-part-01.json の75,667バイトで、全体は約224 KB である。手元の絶対パス・`private/` の内容・docs/todo へのリンクは、verify.py の検出の正規表現を除いて0件だった。

## 実行した検査

| # | 検査 | 結果 |
|---|---|---|
| 1 | `ScopeDelta.parsePattern "//**" = some (.tree [])` を `simp` で示す。`#print axioms` を `ScopeDelta.response`・`RequestDelta.response`・`ScopeDelta.run_safe`・`RequestDelta.run_safe`・`ScopeSignatures.entries_scoped`・`ScopeDeclarations.program_wellFormed`・`ScopeSignatures.io_op` に実行 | 前者は通る（軽1）。公理はすべて `propext`・`Classical.choice`・`Quot.sound` の範囲内 |
| 2 | `parseUrlTarget "http://127.1/" = none`・`parseUrlTarget "https://example.com./" = none`・`"08".toNat? = some 8` を `native_decide` で確かめ、`parseHostPattern "10.0.0.0/08"`・`parseHostPattern "10.0.0.0/8"`・`parsePattern "/**"`・`parseHostPattern "API.Example.com"` の `isSome` を `#eval` で見る | 前の三つは通る。後の四つはすべて `true`（中2(b)、軽1） |
| 3 | `parseUrlTarget "http://[::ffff:127.0.0.1]/"` の値と、`RequestDelta.run (.absolute .top)` に条件 `"127.0.0.1"`・URL `https://[::ffff:127.0.0.1]/`、条件 `"::/0"`・URL `http://[::ffff:127.0.0.1]:18081/`（いずれもポート 0〜65535）を与えた結果が Ok かを `#eval` で見る | v6 の端点を返す。前者は Ok でない（v4 の条件に所属しない枝。処理系は射影形の拒否の InvalidTarget）、後者は Ok（中3） |

検査1〜3は `<tmp>/rv-l50-e/check1.lean`〜`check3.lean` の三つの入力で行った。`native_decide` と `#eval` は確かめのファイルだけで使い、本番には置いていない。最初の実行は名前空間の開き方と `decide` の簡約の誤りで失敗し、`open Benitoite …`・`decide +kernel`・`native_decide` に直して再実行した。値はいずれも短い文字列と小さい整数で、大きな具体値を作る評価はしていない。外側の時間は各約1秒である。レビュー全体の外側の時間は約20分（21:14〜21:35）である。

## 再レビュー（再開1）

2026-11-04。対象は担当の再開1の処置（`l50/e/results.md` の「再開1」、`work` の報告）と、今の作業木の差分である。基準は前回と同じ `7ece2393`。本番で再開1が変えたのは `AtInput.lean`・`ScopeDelta.lean`・`RequestDelta.lean` と、01-12・07-04 の写しである。`git diff 7ece2393 --stat` では、`Typing.lean`・`AtPrepare.lean`・`ModelHttp.lean` などの前の群のファイルと、主な十言明のファイルは差分に含まれない。

確かめのビルドは別に走っていた既定の `lake build`（22:03〜22:07）の終了を待って行った。レビュー側では `lake build` も cargo も実行していない。

### 結論

**可**（重0・中0・軽2・情報3）。

前回の中1〜3は解消した。処理系の関門のテスト（`http_request_in_checks_endpoints_and_retains_the_same_request` と `scope_path_in_checks_dynamic_inputs_and_preserves_the_same_ok`）の入力を、要求側は51件、パス側は境界の5件、Lean の δ で評価した（検査4）。構成子・payload・理由の文字列は、処理系の期待とすべて一致した。

- 要求側の受理: 16行がすべて Ok である。
- InvalidUrl の11行: 欄は INVALID_URL である。
- InvalidTarget の行: ホストの綴りと INVALID_HOST を持つ。射影形の行は MAPPED_TARGET を持つ。
- InvalidPattern の行: 理由は ENDPOINT_PATTERN である。
- InvalidPortRange の行: 元の整数の欄を持つ。
- OutsideScope の行: 第2欄はホストの綴りである。

前回の軽1〜3も処置された。ただし 01-12 の一か所に二重の空行が残る（軽R2）。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 軽R1 | 軽 | `AtInput.lean` の `parseUrlTarget`、results.md の再開1 | 根の修正で `Val.reqTarget` が射影形の IPv6 に `none` を返すようになった。そのため、型付けの規則 `V_CheckedRequest` と At の保持の規則（`Typing.lean` 197・418行の前提 `req.reqTarget = some target`）で型付く値の集合が狭まる。At の endpoint 入力（`parseAtInput .endpoint`）も射影形を拒否する。規則の字面とファイルのハッシュは変わらず、前の群の言明の型（`parseUrlTarget_kind`・`Val.reqTarget_kind`・`parseUrlTarget_https_loopback` を `#check` で確かめた）も同じである。既定ビルドも通るので、前の群の言明は弱まっていない。狭まるのは、処理系で作れない値（射影形の端点を持つ保持値）だけであり、処理系と揃う方向である。一方、results.md は「型付け規則の変更は0件」とだけ書き、定義の変更が規則の前提を通じて型付く集合を狭めることを書いていない | results.md の再開1に、「`parseUrlTarget` の変更は V_CheckedRequest と At の保持の前提を通じて、射影形の端点の保持値を型付く集合から除く。規則の字面は変わらない。処理系では作れない値である」と一行加える | 読めば確定 |
| 軽R2 | 軽 | 01-12 の 3329〜3330行 | `ScopeSignatureFormation.entries_scoped` の段落の後に、二重の空行が残る（もう一か所の 4012行付近は直っている） | 空行を一つにする | 読めば確定 |
| 情報R1 | 情報 | `parseUrlShape` | 処理系の URL の形の検査に対応する範囲を、関門の51件の入力で確かめた。対応は次のとおりで、境界の扱いも一致した。<br>・文字集合と percent は `urlAlphabet`・`validPercent` に対応する。<br>・scheme の大小文字は `toLower` に対応する。<br>・authority の欠如・空ホスト・`@` は none に対応する。<br>・ポートの "" と ":" は既定の値、範囲外と非数字は none に対応する。<br>・角括弧の対、非角括弧の `:` の数も対応する。<br>境界は、`http:///path` が InvalidUrl、`HTTP://…:/` が受理、`[::1/`（閉じ括弧なし）が InvalidUrl、`[fe80::1%25eth0]` が InvalidTarget である。ただし処理系は `http` クレートの `Uri` の解析を使う。関門にない入力（たとえば、文字集合に含まれる記号を authority に置いた URL）で受理の範囲が一致することは、Lean と処理系の両方の実行でしか確かめられない。R50 の比較で扱う範囲である | なし | 実行で確定（関門の範囲）・判断（その外） |
| 情報R2 | 情報 | 射影形の IP パターン | `parseHostPattern "::ffff:0.0.0.0/96"` は受理し、v4 の対象には OutsideScope を返す（検査4）。処理系の関門の行（パターン `::ffff:0.0.0.0/96`・`::ffff:127.0.0.1` と射影形の URL）は期待3（InvalidTarget）であり、パターンの不正（期待2）ではない。`checked_scope.rs` の `host_target` は対象の入口だけに適用され、パターンの代数を変えない。したがって射影形のパターンを受理し続けることは処理系と合う | なし | 読めば確定・実行で確定 |
| 情報R3 | 情報 | パスの δ | `parsePattern` は `//**` と `/a//**` を拒否し、`/**` を受理する（検査4）。対象の解析失敗は相対形・home 形を含めて同じ PATH の InvalidTarget であり、`input_errors` も同じ値を返す。PATH_PATTERN・PATH・ENDPOINT_PATTERN・MAPPED_TARGET・INVALID_URL・INVALID_HOST の6つの字句は、`checked_scope.rs`・`checked_request.rs` の定数と一字ずつ同じである。軽2の処置（静的不所属・引数形の不一致・groundVal=false の三分岐の対応と到達性）は results.md にあり、内容は処理系のソースと合う | なし | 読めば確定 |

### 観点ごとの根拠

1. 中1・中2: 失敗の構成子・payload・理由と検査の順序は、処理系と次のとおり一致する。
   - パス: パターンの解析失敗→対象の解析失敗→動的な所属→静的な上限。
   - 要求: URL の形（InvalidUrl）→ホスト（InvalidTarget。射影形を含む）→ホスト条件（InvalidPattern）→ポート範囲→ホスト所属→ポート所属→静的な上限。
   - `hostText` は同じ `parseUrlShape` から角括弧を除いた元の綴りを取り、大文字を保つ。処理系の `spelling` と同じである。
2. 中3: `isIPv4MappedHost` は上位96ビットが `0xffff` かを判定する（`bits / 2^32 == 65535`）。これは処理系の `bits >> 32 == 0xffff` と同値である。同じ入口を使うので、`Http.sendIn` の保持要求（`reqTarget`）と At の endpoint 入力も拒否する。処理系の `send_in` も `matches_endpoint` で同じ `endpoint` 解析を使い、射影形と一致しない。前の群の言明は軽R1のとおり弱まっていない。消えた宣言は private の `parseAuthority_kind` だけで、公開の言明の型は同じである。
3. 軽1〜3: 軽1（`//**`、prefix の前置の0と4桁以上）と軽2（記録）は処置された。軽3は 07-04 の表と 01-12 の一か所が直り、01-12 のもう一か所が残る（軽R2）。
4. 主な十言明・F03〜F05・型付けの規則のファイルは差分にない。公理は `RequestDelta.response`・`RequestDelta.run_safe`・`ScopeDelta.response`・`parseUrlTarget_kind`・`Val.reqTarget_kind` の5件が、propext・Classical.choice・Quot.sound の範囲内である。担当の572宣言の監査は引用し、再実行していない。

### 実行した検査（再開1）

| # | 検査 | 結果 |
|---|---|---|
| 4 | `<tmp>/rv-l50-e/check4.lean`。関門の受理16行・拒否35行の入力を `RequestDelta.run (.absolute .top)` で `#eval` し、構成子・欄を文字列にして見た。あわせて次を見た。<br>・`parseAtInput .endpoint` の射影形と `::1`<br>・`parsePattern` の `//**`・`/**`・`/a//**`<br>・`#print axioms` 5件と `#check` 3件 | 前述のとおりすべて処理系の期待と一致した。公理は既定の三つの範囲内である |

`#eval` は確かめのファイルだけで使った。値は短い文字列と小さい整数だけである。最初の待ちの台本は自分自身のコマンドの文字列に一致して終わらなかったので、プロセス名で待つ形に直した。Lean の実行の外側の時間は約1秒、再レビュー全体の外側の時間は約12分（22:05〜22:17。うち約4分は別のビルドの待ち）である。

## 取りまとめの追記

- 初回の中1〜3・軽1〜3は担当の再開1で処置し、再レビュー（再開1）で可とした。δ は R50 へ送らず処理系へ揃える方針は plan.md の 2026-11-04 の項に記した。中3は `parseUrlTarget` の根の修正で処置し、`Http.sendIn` と At の endpoint 入力も処理系と揃った。
- 再レビューの軽R1（型付く値の集合が射影形の分だけ狭まったことの記録）は、取りまとめが l50/e/results.md の再開1の段落に一文を足した。軽R2（01-12 の二重の空行）は取りまとめが直した。情報R1（関門にない URL の受理の範囲）は R50 の実行の比較で扱う。
- 群 E の作業末の work は終了0、447.05秒、最大常駐量 2,968,502,272 バイト（篩の部分の生成物を消して再ビルド。l50/e/results.md）。
