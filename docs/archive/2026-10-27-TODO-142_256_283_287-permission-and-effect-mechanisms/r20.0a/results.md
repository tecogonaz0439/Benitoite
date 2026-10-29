# R20.0a: パスの純粋な検査・射影の登録

## 作業と状態

B_WORK と開始時 HEAD は `538090391ea48a833ddd824f4b732e599616d48c`、作業ブランチは `m013/r20.0a` である。開始時の差分は空だった。`private/`、そこを指すスキル、`docs/todo/` は読んでいない。git の状態を変える操作は行っていない。

標準署名の範囲変数の登録、三つの直接読者とコアへの接続、純粋なパス検査・射影の宣言と実行本体、通常 export の確認、設計書と生成物を実装した。作業末の W-R と H は、ともに check.sh 自身の終了0で完了した。非 Top の範囲選択・呼び出しごとの範囲の列・拡大は R20.3、要求の検査・射影は R20.0b、新 IO は R30 の担当を保つ。

## 範囲変数の登録と具体化

`builtins/table.rs::builtin_range_positions` を対象位置の表とし、実在する組み込み番号から二つの純粋 API を認定する。`checkPathIn` は戻り値 `Result` の型引数0にある `PathIn`、`pathInValue` は引数0の `PathIn` が対象である。この表から `builtin_range_signature` の種類列を作る。`parameterize_builtin_signature` は種類・個数・対象の標準型・型引数なし・元の Top を照合し、対象位置へ `rvar 0` を置く。

宣言検査は、範囲変数を持つ標準二署名を書き換えてから `builtin_signature_valid` を通し、未具体化の署名を `decl_types`、範囲情報を `TypeckOutput.range_signatures` に保存する。利用者宣言には従来どおり範囲変数0個の条件を課す。新しい構文は加えていない。`RangeSignature` と `types::Scheme` の構造は変えていない。

| 読者 | 接続 |
|---|---|
| 通常の `Body::instantiate` | 共通の `Body::signature_at_top` で範囲を Top へ具体化し、その後に型／行を代入する |
| `typeck/effects/handle.rs` の節の署名 | `signature_at_top` を通す。節の範囲を推論した本体から選ぶ拡張は R20.4 |
| `typeck/traits/solve.rs` の辞書の期待個数 | 宣言の直接参照を `signature_at_top` へ移した |
| `ir/desugar/decls.rs` の `schemes` の写し | 未具体化の `schemes` と同じ束縛番号の `Program.range_signatures` を組で保持する。判定の木への変換でも両表を写す |
| `ir::check::instantiate` | 宣言の束縛番号で範囲情報を引き、Top 具体化を型／行代入より先に行う。組み込み・関数・操作・外部関数と操作の節の経路を追随させた |

各ノードの確定した型と効果には範囲変数を残さない。署名に範囲変数を保持することと、プログラムの型を閉じることを分けた。旧 `Scope.checkPath` のラッパーと内部の `inspectPath` に新規則を付けていない。

## 登録した入口と実行本体

| 入口 | 未具体化の標準署名 | 現在の呼び出し |
|---|---|---|
| `Scope.checkPathIn` | `function(pattern: String, path: String) -> Result[Scope.PathIn[R], Scope.ScopeError]`、種類 path 一個、純粋 | R は常に Top |
| `Scope.pathInValue` | `function(path: Scope.PathIn[R]) -> String`、種類 path 一個、純粋 | R は常に Top |

公開宣言は `src/prelude/stdlib/Scope.bnt`、型付きの実行本体は `src/builtins/funcs/scope.rs` に同時に登録した。`checkPathIn` は既存の `builtins/checked_scope::check_path` を呼ぶ。この共通演算は R10 の `PathPattern::parse`・`Path::parse`・`matches` で形式と所属を検査する。パターンの形式不良、対象の形式不良、所属不良の順で `InvalidPattern`・`InvalidTarget`・`OutsideScope` を返す。失敗値には元の入力と理由を保持する。静的な Top を理由に動的検査を省かず、所属を確認した場合だけ `Result.Ok` を作る。

`pathInValue` は成功値に保存した同じ String の `Value` を直接返す。旧 `CheckedPath` から検査なしで変換する入口と `widenPathIn` は登録していない。

## 値の表現と安全条件

`PathIn` は既存の `FieldsKind::Ctor`・`tags::RECORD` の一欄に、検査した入力の String の `Value<'epoch>` をそのまま保持する。VM 専用の新しい値種は作っていない。参照実行器も既存の Ctor と Str の橋渡しを通るため、その実装は変更していない。

`ValueCtx::alloc_fields` で PathIn と Result を同じ回収しない区間の中で構築する。構築中に安全点へ戻らず、返した結果は通常の VM の結果レジスタへ保存される。以後は構成子の既存の子の走査で元の String まで辿る。射影は新しい文字列を確保しない。失敗の短い理由は既存の上限検査付き `alloc_str` を通し、欄の個数は1または2の固定値である。

新しい確保の呼び出しは加えたが、確保器・確保 API・根・書き込みの障壁・安全点・回収の不変条件は変更していない。ホスト側に言語の値を保存する領域や、寿命を外した値は加えていない。したがって H-full の停止条件に該当しない。指定の H は終了0で閉じた。`ScopeError` の三つの既存構成子の順に対応するタグ定数を表へ追加したが、PathIn 専用の固定タグは追加していない。

確認点 (6) の Top の不透明定数と実装の成功値の対応を 07-04 に記した。実装の成功値は対象を持つ `Val.checked t` に対応させる。`shapeAt` が対象を持たない不透明定数を旧 Top の形として読む条件を、実装の所属検査・対象保持を省く理由にはしていない。

## テストの関門と export

公開 `test-audit` の作成時の関門を通した。本番の差し込み口と公開範囲は増やしていない。

| 境界とテスト | 守る契約、捕まえる退行、既存検査で足りない理由 |
|---|---|
| `runtime_builtins::scope_path_in_checks_dynamic_inputs_and_preserves_the_same_ok` | 通常ソースから動的・直接の検査、同じ Result の受け渡し、別の文字列の確保後の射影、所属外・不正 pattern・不正 path・失敗順を確認する。木の幹・根・完全一致と対象の `*` の字面も含む。二つの VM モードの stress 環境と参照実行器の差分比較を通す。旧 Checked の検査は新入口を通らず、Top を見て検査を省く退行や新値の保持漏れを捕まえない |
| `scope_annotations::opaque_standard_value_types_keep_their_invariant_scope` の二入力追加 | `pathInValue` が旧 `CheckedPath` と非 Top の `PathIn` を E0401 で拒否する。一般の型の不変性の比較だけでは、標準署名の誤登録・誤具体化を捕まえないため、既存の表へ実呼び出しを追加した |
| `desugar_export::scope_tables::exports_used_path_checks_with_range_variables_only_in_signatures` | 実ソースを `check_text` → `desugar_checked` → `named_definitions` → `named_builtin_tables` へ通す。型表に使用された二純粋 API が存在し、`rkinds = [path]`・`rvar 0`・純粋・正しい引数名を保つこと、定義が `inScope` のままであること、プログラムの型に rvar が残らないことを確認する。合成した署名だけの既存テストは、標準宣言からの登録経路や通常 export の除外への退行を捕まえない |

通常 export の対象を除外したり、未具体化の署名を Top に丸めたりする変更は行っていない。書き出しの既存コードはそのままで、新しい実ソースの確認を追加した。小さい書き出しの証拠を [path-in-export/](path-in-export/) に保存した。保存済みの三出力と最終 W-R の再生成出力の SHA-256 は全件一致した（[照合](export-evidence-comparison.json)）。通常の `desugar_export` と独立の `coverage_export` は W-R 全統合で確認し、それぞれ41成功・既存1無視、3成功・既存1無視だった。`scopeAcceptance`・limits・項の範囲列などの本番接続と、Rust/Lean 全比較は K10 の未完を保つ。

## 裸の注釈の棚卸しと後続

新しいテストに裸の `Scope.PathIn` の型注釈は追加していない。実行と export の例は推論した成功値を照合して射影する。拒否例は非 Top の明示注釈であり、R20.3 で非 Top の射影を接続したときに受理例へ改訂する必要がある。

| 位置 | 目的と R20.3 での扱い |
|---|---|
| `src/prelude/stdlib/Scope.bnt` の `checkPathIn` の戻り値、`pathInValue` の引数 | 公開ソースには範囲変数が書けないため裸の PathIn を置き、登録時に内部 rvar 0 にする生成元である。範囲の列へ接続しても、この内部登録の役割を保持する |
| `skill/references/stdlib/Scope.md` の同二署名と説明 | 上記生成元からの生成物。現在の静的 Top の説明は R20.3 で型接続と同じ変更で改訂する |
| 03-06「Scope」の同二署名・静的 Top の説明、01-06・02-05/02-06/02-08・07-04 の現在の Top 具体化の説明 | 現在実装した範囲を記した。R20.3 で既知の入力に対する非 Top の選択と未知の Top に改訂する |
| `tests/scope_annotations.rs::opaque_standard_value_types_keep_their_invariant_scope` の `Scope.PathIn["/data/**"]` を `pathInValue` へ渡す追加入力 | 現在の Top の引数への不変性による拒否。R20.3 で非 Top の射影を接続したときに受理へ改訂する。旧 CheckedPath の拒否は保持する |

R20.0b は対象位置の表へ要求側二署名を追加できる。ただし `Http.ClientRequest` の表現と Lean の `valContent` の対応は取りまとめの事前判断が必要であり、この枝で解決済みにしていない。R20.3 は Top 具体化を確定した範囲の列へ拡張し、実行時にもその範囲を照合する。R20.4 は節の範囲を推論した保護本体から選ぶ。R30.2 は File の新操作を旧前置き分類より先に明示登録する既存の申し送りを保つ。

## 設計書・生成物と計画との差

指定の 01-06・02-08・02-09・03-06・07-04 に実装済みの内容を反映した。追随のため 02-05 に標準署名の登録・直接読者、02-06 にコアの両表と具体化順を追記した。`text` のコード例と見出しの名前は変更していない。標準宣言と同じ枝で `cargo run -p benitoite --example gen_skill` を実行し、Scope の生成参照を作り直した。生成した bundle の内容には差分がなかった。

主要な配置は計画どおりである。`RangeSignature` と Scheme 自体は変えず、コアの Program に範囲情報の表を追加した。判定の木への変換とその構築テスト、02-05/02-06 の追随は依頼の追加許可範囲である。確保器の変更は不要だったため runtime/heap と参照実行器のコードは変更していない。Lean・scripts・依存・本線のディレクトリは変更していない。新しい CARGO_TARGET_DIR と target 外の一時ビルド・基準版の展開は作っていないため、削除対象はない。

追跡済みの変更は22ファイル、484行追加・63行削除である。src は同居する lib テストの追随を含め270行追加・56行削除、統合テストは169行追加・削除0、設計書は33行追加・7行削除、Skill の生成参照は12行追加である。テストの削除は行っていない。[変更ファイルと SHA-256](changed-files.json)、[行数](line-counts.json)、[実装差分](implementation.patch)、[環境](environment.json)を保存した。

範囲の意味、対象の範囲、公開契約、安全条件を変える必要は生じなかった。動的検査・同じ値の保持を省いておらず、停止条件への該当はない。新しいネットワーク依存、64ビット専用の整数変換、実行時の権限制御・情報フロー制御は加えていない。32ビットと機能を外した構成の実ビルドを確認済みとはしない。最初の勧告照合の「組み込まない」という判断を引き継ぎ、新規照合・依存更新は実行していない。

## 計画の義務の対応

| R20.0a が受け持つ義務 | 状態と証拠、残る担当 |
|---|---|
| 範囲の正規形・WF・種類と静的／動的の共通演算 | パスは既存の R10 の共通演算を用いる。runtime_builtins の完全一致・木・幹・根・所属外・不正形式を確認した。端点の実行は R20.0b |
| 純粋四入口の先行登録と六宣言の規則との一致 | この枝のパス二入口を、Lean の `ruleDeclarations`・`TargetTable` の署名と照合した。要求二入口は R20.0b、拡大二入口と非 Top は R20.3 |
| 最初の範囲変数の登録、三読者とコアの接続 | 上の対応表の経路を実装した。実ソースの export とコア検査で確認し、署名担当とは別の担当が読み取りで相互点検した |
| 表と具体化の分類を集め、利用者に rvar を許さない | 認定した組み込みの対象位置だけを書き換える。従来の利用者宣言の変数0個の条件を保持した。export は署名の文脈にだけ rvar を許す |
| 成功値の同一性、一度の保存、直接射影 | 元 String を一欄に保存し、同じ欄を返す実装である。同じ Result の受け渡し・確保後の射影を通常ソースで確認した。const と局所解析の忘却境界の接続は R20.1/.2/.3 |
| 四入口の Top から非 Top への型変更と既存利用の追随 | 新しい裸のテスト注釈は0。上の棚卸しを R20.3 に渡す。現在の非 Top の射影の拒否例は同枝で受理へ改訂する |
| 検査済み値の WF と非 Top の不透明型の照合 | この枝の静的 Top の値にも形式・所属の実行時検査を行う。旧型の変換と非 Top→Top の暗黙変換は E0401 で拒否した。非 Top の成功値の作成と射影は R20.3 |
| 新値と安全点、doc・局所 heap/stress | 確保・根・障壁の不変条件を変更せず、H を終了0で閉じた。確定値は末尾。H-full を要する変更はない |
| 通常 export の維持とプログラム型の閉性 | 新しい実ソースの定義を inScope に保ち、使用された二署名の rvar/rkinds と項側の閉じた添字を確認した。全通常 export の結果は W-R の確定値へ記す。全比較は K10 |
| 章・用語・生成物を実装済みの状態へそろえる | 上記7章と Scope の生成物を更新した。新しい術語は加えていない。最終訳・利用者文書の全体照合は V10 |

## 初回の失敗と修正

| 実行 | 原因、修正、確認 |
|---|---|
| 署名担当の最初の `cargo check -p benitoite --lib` | 機械的な置換で clause の外から `clause.op` を参照して終了101。呼び出しごとに適切な宣言を渡す位置へ直し、終了0となった。最初の出力は担当のツール記録だけであり、生ログを保存していない。最終の lib check は [signature-final-check.log](signature-final-check.log) に保存し、W-R でも全体を確認した |
| 新しい export テストの初回 | 追加した Bnt 例で束縛に `let` を書き、E0230 により終了101となった。`bind result <- ...` に修正し、同じ検査が終了0となった。[初回](export-path.log)と[修正後](export-path-retry.log)を保存した |
| W-R の初回 | fmt 成功後、追加した署名の対象位置の分岐の `_` が `clippy::wildcard_enum_match_arm` に違反して終了1となった。Ty の全構成子の列挙へ変更し、整形した。初回に lib と統合テストは未実行であり、修正で古くなった fmt・clippy と未実行の後続を同じ指定で続行した。[初回](work.log)を保存した |
| W-R の続行1 | fmt・clippy 成功後、lib は1,358成功・1失敗・21無視となった。Scope の登録が3件から5件へ増えたのに、組み込み表の既存テストの期待件数を追随し忘れていた。Scope 部分を5、名前の総数を512、純粋項目の総数を437へ更新した。登録した二入口に対応する期待値の追随であり、名前の重複・能力・署名等の既存の assertion は保持した。[失敗](work-retry.log)を保存し、同じ指定で続行2を実行した |

期待値、検査対象、ignore、時間制限を実行時間のために緩めていない。

## 検査のコマンドと計時

作業末は [run_logged.py](run_logged.py) が `/usr/bin/time -p` の内側でコマンドを実行し、コマンド直後の終了状態を `command_exit` に書いて同じ状態を返す。check.sh の終了状態を直接保存し、time 自体の見かけの成功を代用しない。外側の秒は単調時計でも計測する。`time -l` は使用していない。

最大常駐量は macOS の `getrusage(RUSAGE_CHILDREN).ru_maxrss` の補助値で、原単位は bytes、MiB は 2^20 bytes で換算する。終了した子孫の資源情報を伝える実行器であり、並行プロセスの同時常駐量の合計ではない。未捕捉の0を実使用0と扱わない。

局所検査と生成には次のコマンドを使った。保存したログと計時は同名の log/json にあり、[checks-summary.json](checks-summary.json)に集める。署名担当の最初の三実行は生ログなしで、最終の W-R に同じ対象を含めた。

```sh
cargo check -p benitoite --lib
cargo test -p benitoite --test scope_annotations opaque_standard_value_types_keep_their_invariant_scope
cargo test -p benitoite --lib ir::check::tests
cargo test -p benitoite --test runtime_builtins scope_path_in_checks_dynamic_inputs_and_preserves_the_same_ok -- --exact
cargo test -p benitoite --test desugar_export exports_used_path_checks_with_range_variables_only_in_signatures -- --nocapture
cargo run -p benitoite --example gen_skill
```

W-R の指定は次のとおりである。同じ指定に `--dry-run` を付け、fmt・既定の lib/tests/examples の clippy・既定 lib 全件・全統合ターゲット・source_rules・skill_generated・spec_tally の7項目が選択された。仕様例は全統合に含まれるため重複選択されなかった。[初回の選択](work-dry-run.log)・[修正後の選択](work-retry-dry-run.log)に保存した。

```sh
scripts/check.sh --level work --base 538090391ea48a833ddd824f4b732e599616d48c
```

H の指定は次のとおりである。[選択](heap-dry-run.log)は `cargo test --workspace --doc`、heap-verify の指定四統合ターゲット、heap-verify と gc-stress の指定四統合ターゲットの3項目で、W-R と重ならない。

```sh
scripts/check.sh --level work --base 538090391ea48a833ddd824f4b732e599616d48c --only doc_default,heap_local,stress_local --test runtime_builtins --test vm_handlers --test io_modes --test l32_http_client
```

`check-formal.sh`、Lean のビルド、short の性能比較は実行していない。これらの未実施を成功に数えていない。独立レビュー・受け入れ・取り込みと short は取りまとめの担当であり、担当内の相互点検で代用しない。

## 検査の確定値と時間

| 実行と記録（同名 JSON に正確なコマンド・時刻） | 終了 | 外側の秒 | 最大常駐量の原値 bytes | MiB |
|---|---:|---:|---:|---:|
| [Skill 再生成](gen-skill.log) | 0 | 3.513 | 11,386,880 | 10.859 |
| [パスの実行・参照比較の局所検査](runtime-path.log) | 0 | 17.573 | 4,033,282,048 | 3,846.438 |
| [実ソース export の初回](export-path.log) | 101 | 3.241 | 687,046,656 | 655.219 |
| [実ソース export の修正後](export-path-retry.log) | 0 | 2.386 | 688,209,920 | 656.328 |
| [署名の最終 lib check](signature-final-check.log) | 0 | 1.717 | 920,748,032 | 878.094 |
| [W-R 初回](work.log) | 1 | 11.839 | 2,384,543,744 | 2,274.078 |
| [W-R 続行1](work-retry.log) | 1 | 102.364 | 3,369,418,752 | 3,213.328 |
| [W-R 続行2・全7項目完了](work-retry2.log) | 0 | 464.593 | 2,320,056,320 | 2,212.578 |
| [H・指定3項目完了](heap.log) | 0 | 137.115 | 3,958,046,720 | 3,774.688 |

W-R は lib が1,359成功・0失敗・21既存無視、全統合41ターゲットが424成功・0失敗・10既存無視である。[ターゲット別件数](work-test-counts.json)を保存した。`spec_examples`・`reference_examples`・`skill_docs` と通常の両 export もこの全統合に含む。fmt、lib/tests/examples の clippy、規約、生成物、仕様の集計も成功した。

H は通常の doc が17成功・1既存無視、compile_fail の doc が17成功・無視0、heap-verify と heap-verify＋gc-stress の四統合ターゲットが各49成功・0失敗・無視0である（各構成で io_modes 11、l32_http_client 9、runtime_builtins 24、vm_handlers 5）。[構成・ターゲット別件数](heap-test-counts.json)を保存した。新しいパスの実行テストも両構成で成功した。H は指定の部分選択の完了であり、H-full や work 全体を指す名称にはしていない。

全検査の後、保存した22ファイルの SHA-256 と実装差分、最終 HEAD と空の index 差分、変更範囲、結果内のローカル絶対パスと禁止リンクの不在を照合した。検査後の編集は結果記録だけで、処理系・テスト・設計書・生成物は変更していない。独立レビューと受け入れは取りまとめの担当である。

最初の時計は2026-10-28 15:21:05 UTC（2026-10-29 00:21:05 JST）、終了の時計は2026-10-28 15:45:06 UTC で、外側の所要は約24.0分である。親担当の能動時間は約16分、ビルド・検査だけを待った区間は約8分の概算である。検査と並行して記録・差分点検を行った区間があるため、表の検査時間を能動時間へ単純に加算しない。分担した実装・点検もこの外側の時計に含む。性能測定・Lean ビルド・回答待ちはなく、上端の2倍の8時間の条件には達していない。

## R20.0a2: RV-R20.0a 軽1〜軽3への対応

B_WORK は `538090391ea48a833ddd824f4b732e599616d48c`、ブランチは `m013/r20.0a` のままである。R20.0a の未コミット差分を保ち、軽1〜軽3を対応済みとした。

| 指摘 | 対応 |
|---|---|
| 軽1 | `src/resolve/tests.rs::stdlib_source_and_table_contracts` の名前とタグの照合表に、`Scope.ScopeError.InvalidPattern`・`InvalidTarget`・`OutsideScope` と対応する三つのタグ定数の行を追加した |
| 軽2 | 操作の節で共通の具体化処理を使う現在の実装を保持し、02-06「コア IR の検査器」に再検査の対象を一文で明記した |
| 軽3 | `builtins/funcs/scope.rs` の先頭の `//!` に、`checkPathIn` が形式と所属を検査して同じパスを保持し、失敗時は ScopeError を作り、`pathInValue` が保持したパスを直接返す役割を一文で追加した |

軽2の、操作の節における型引数の数・種類・組み込みの制約、エフェクト引数の数、NoFail、具体化後の型に含まれる各エフェクト集合の失敗型が高々一つであることの再検査は、共通の署名の具体化処理へ統一するための意図した拡大である。範囲の Top 具体化だけに戻す変更は行っていない。範囲変数を持つ操作の節とメソッドを実際に通す検査は、レビューの申し送りどおり R20.4・R30.2 で名指しする必要があり、今回の lib 全件の成功をその代用とはしない。

軽1は公開 `test-audit` の作成時の関門を通した。標準ソースを実際に名前解決した構成子のタグと、実行本体が使う定数との一致を守る。構成子の順の変更やタグ定数の誤変更を捕まえるもので、従来の照合表にこの三項目がなかったため、既存テストの表へ行を加えた。本番の差し込み口や公開範囲は増やしていない。本番のコードはコメント1行追加、テストは既存の照合表12行追加、設計書は2行追加で、削除はない。

再検査は今回の指定に従い、次の部分選択を同じ指定の `--dry-run` の後に一度実行した。

```sh
scripts/check.sh --level work --base 538090391ea48a833ddd824f4b732e599616d48c --only fmt,lint_default,lib_default,source_rules
```

既存の [run_logged.py](run_logged.py) に `r20.0a2-work-dry-run` と `r20.0a2-work` を渡し、`/usr/bin/time -p` で包んだ。check.sh の直後に得た終了状態をログの `command_exit` に直接記録した。外側の時間は実行器の単調時計、最大常駐量は前述の `getrusage(RUSAGE_CHILDREN)` による補助値である。

| 再検査と記録（同名 JSON にコマンド・時刻） | check.sh の終了 | 外側の秒 | 最大常駐量 bytes | MiB |
|---|---:|---:|---:|---:|
| [dry-run](r20.0a2-work-dry-run.log) | 0 | 0.034 | 11,354,112 | 10.828 |
| [指定4項目](r20.0a2-work.log) | 0 | 107.444 | 3,146,399,744 | 3,000.641 |

dry-run は fmt、既定構成の lib・tests・examples の clippy、既定 lib 全件、ソース規約を選択した。本実行では4項目とも成功し、lib は1,359成功・0失敗・既存の無視21件で、軽1の照合表も成功した。time の表示は real 107.44秒・user 446.42秒・sys 22.83秒だった。検査に失敗・再実行はなく、今回の部分選択を work 水準全体の完了とはしていない。結果追記用の最初の一時スクリプトは入力の文字コードエラーで書き込み前に失敗したため、apply_patch で追記した。

今回の変更はテストの照合表と説明だけであり、値の保持・確保・根・障壁を変更していない。前の H の対象を変える差分はないため H を再実行していない。構文・標準宣言・診断表の変更もないため生成物の再生成は不要である。統合テスト・Lean・形式化の全比較・性能比較は今回の指定に含まれず、実行していない。

[今回の追加差分](r20.0a2.patch)と[作業前後の SHA-256・状態の照合](r20.0a2-state.json)を保存した。今回の3箇所の追加だけを除くと作業前の全対象の SHA-256 に一致し、レビュー本文・HEAD・ブランチ・index 差分も一致した。先の changed-files.json・implementation.patch 等は R20.0a 初回の記録として保持する。private・そこを指すスキル・docs/todo は読んでいない。git の状態を変える操作は行っていない。新しい CARGO_TARGET_DIR や target 外の一時ビルドは作っておらず、削除対象はない。軽4はレビューどおり R30.2 の申し送りのままとした。

時間の起点として最初に取得した時計は2026-10-28 15:59:44 UTC、結果記録の時計は2026-10-28 16:04 UTCで、この間の外側の所要は約5分である。能動時間は約4分、検査だけを待った時間は約1分の概算である。検査の外側107.44秒には、並行して差分点検と記録を準備した時間も含む。停止条件への該当はない。

