# A01a の結果

状態: 実装案を作成したが、未完了として停止する。通常の型検査経路へ接続する前の内部入力に dead_code 警告が12件発生し、`.cargo/config.toml` の `build.warnings = "deny"` によってビルドが失敗する。A01a の対象ファイルだけで実際の呼び出し元を接続できず、AGENTS.md「`#[allow]` を書いてよい箇所」は許可表にない lint の許可が必要になったら止めて報告するよう定めている。例外は追加していない。

## 基準と範囲

- 作業日: 2026-10-25。
- ブランチ: `mod012/A01a`。B_WORK と開始時の HEAD はともに `31960eb28c2003ce01fe4195e7808b2c1c7bb4c9`。開始時の差分はなかった。
- 対象: plan.md「作業群 A01」の枝 A01a。`interval/mod.rs`・`input.rs`、`typeck/mod.rs` と設計書 02-05 を変更した。
- private/ とそれを指すスキルは読んでいない。git の変更操作は行っていない。

## 実装

`BodyInput::collect` は、型解決後・finish 前の `Body` を読み取り専用で受け取り、式・演算子・局所束縛の型を solver.finalize して本体内の疎な表へ保存する。AST は借用し、solver と Body の参照は保存しない。呼び出し側が渡す valid 条件に加え、本体の誤り、所属と持ち主の不一致、誤りの型・未解決の型、定数の値式と引数の型の欠落を入力作成の失敗として返す。Top や予算停止には置き換えない。

元定義の候補は、入力のモジュール順・ast.decls 順・impl の i.fns 順に列挙する。定数は値式を Block.last として読む本体と空の引数、impl のメソッドは function として扱う。外部宣言と型クラスの署名を除き、検査用の生成関数は通常の Item::Fn として含む。定義名は解決済みの名前から作り、impl の識別名には宣言とメソッドの元の位置を含める。定数の評価順と型検査の完了順を入力順には使わない。

`InputTables` は全定数の評価後に読む共有の名前解決・定数・リテラル表である。収集時点で未完成の定数表を本体ごとに複製しない。`SurfaceForm` は Surface.Expr の53構成子を区別し、C1 の伝播・未知・独立入力・別本体の分類を持つ。予算・番号・元 NodeId/span の対応の作成は含めない。

## 検査

| コマンド・確認 | 終了状態 | 外側の時間・記録 |
|---|---|---|
| `cargo fmt --all`（rtk 経由） | 0 | 約2秒 |
| `cargo test -p benitoite --lib typeck::tests::records_aliases_constants_and_output_tables --no-default-features --features gc-mark-sweep`（rtk 経由、既定 CARGO_HOME） | 101 | 依存の取得前に停止。既定キャッシュへ未取得の Wasmtime 49.0.4 の依存を書けず Operation not permitted |
| 同じ局所テストを `CARGO_HOME=<tmp>/benitoite-a01a-cargo` で再試行 | 101 | 外側の時間は未計測（依存の取得と初回ビルドを含む）。コードの型の誤りは報告されず、内部入力の dead_code 警告12件を build.warnings が拒否。テストは実行されていない |
| `git diff --check`（読み取り、rtk 経由） | 0 | 1秒未満 |
| `scripts/check.sh --level work --base 31960eb28c2003ce01fe4195e7808b2c1c7bb4c9 --dry-run` | 0 | 1秒未満。fmt、examples 込み lint_default、lib_default、全統合 tests_related、source_rules、skill_generated、spec_tally を選択 |
| `/usr/bin/time -l env CARGO_HOME=<tmp>/benitoite-a01a-cargo scripts/check.sh --level work --base 31960eb28c2003ce01fe4195e7808b2c1c7bb4c9`（rtk proxy 経由） | 1 | real 28.17秒、user 105.89秒、sys 6.89秒。fmt 成功、lint_default で停止。[生ログ](work.log) |
| Surface.Expr と SurfaceForm の一時 Python スクリプトによる照合 | 0 | 1秒未満。53構成子が対応し、余分・欠落なし。構文の意味や変換の正しさの検査ではない |

作業用の Cargo キャッシュを `<tmp>/benitoite-a01a-cargo` に作成した。既存の公開レジストリのキャッシュを `cp -cR` で複製し、以後の検査には `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を指定する。リポジトリの manifest・lock・検査設定は変更していない。

作業末の work は一度実行した。直前の [dry-run](dry-run.log) も同じ基準・指定で終了0である。work は lint_default の dead_code 警告12件で停止し、lib_default・全統合 tests_related・source_rules・skill_generated・spec_tally は未実施である。Lean の定義を変えていないため、Lean のビルドと Rust/Lean の比較は実行していない。

最大常駐量（maximum resident set size）: 取得不能。`/usr/bin/time -l` は時間を出した後、`time: sysctl kern.clockrate: Operation not permitted` と報告し、最大常駐量の行を出さなかった。サンドボックスによる制限であり、0としては記録しない。

## 計画からのずれと申し送り

言語の規則、Lean の定義・定理・公理、型検査の出力と診断の署名は変更していない。A01a の指定どおり、この内部入力を通常の型検査経路と利用者向けの警告へは接続していない。

取りまとめの判断が必要な点: A01a〜A02 を実際の収集位置まで接続して検査できる区切りへ再分割するか、この区切りに限る未使用の許可を設計者が明示するかを決める必要がある。後者は現行の AGENTS.md の許可表の外であり、実装担当では決めない。公開 API の拡大、検査用だけの呼び出し、設定やコマンドによる警告の無視では回避しない。この失敗を A01a の成功として後続へ渡さない。

- A01b: AST から正規化した形を作り、Surface のフィールド順・列順で番号と NodeId/span 対応を作る。定数の根の block と値式、直接の負号、return、名前付き引数、合成節点の対応を閉じる。`SurfaceForm` 自体は AST から Surface への変換器ではない。
- A02: consts::check と generate::check_function の valid 条件の下で finish 前に入力を収集する。全本体の型検査後に SourceOrder 順へ並べ、完成した定数表とともに全体駆動へ渡す。標準モジュールを除く既存の境界と全体予算を接続する。入力の型の保存も予算の対象へ含める。
- A11: 型・局所環境・同定表等の保持項目と操作の計上を Lean の規則へ照合する。
- 独立レビューと受け入れは取りまとめが担当する。

未実施の検査は、取りまとめが作業の区切りまたは例外を決めた後、再依頼を受けた実装担当が行う。fmt と差分の空白検査の成功だけで受け入れを閉じない。

新しいテストは追加していない。test-audit の作成時の関門を確認した結果、現段階では公開の振る舞いが変わらず、追加すると非公開の入力と分類表の検査だけになるためである。未使用を避けるだけの公開範囲の拡大、仮の呼び出し、lint の許可は追加しない。入力の実経路での振る舞いと識別は、A01b・A02 と計画の X の比較で確認する。

## 再開の結果（2026-10-25）

現在の状態: A01a の実装と担当する work 検査を完了した。上の停止記録は前回の状態として残す。独立レビューと受け入れは取りまとめが担当する。

### 基準と変更

- 今回指定された B_WORK と開始時の HEAD: `caadeaa397ba46a29f76ab83948a48aac90e6016`。ブランチは `mod012/A01a`。
- 開始時から残っていた `typeck/interval/`、`typeck/mod.rs`、設計書 02-05、前回の結果とログを引き継いだ。
- README「設計者の決定（2026-10-25、処理系の作業の途中）」、AGENTS.md の許可の表、plan.md「計画の変更（2026-10-25、A01a の停止を受けて）」を確認し、`typeck/interval/mod.rs` の先頭だけに `#![allow(dead_code)]` を追加した。コメントに設計者の決定日・理由・A07 が削除することを記した。
- `BodyInput` の確定済み型の保存、定義の列挙範囲、53構成子の分類を現行のソース・契約・01-12 と照合した。入力の実装と 02-05 の記述は前回の内容を引き継ぎ、`cargo fmt --all` で整形した。
- 言語の規則、Lean の定義・定理・公理、既存の型検査の署名は変更していない。private/ とそれを指すスキルは読まず、git の変更操作も行っていない。

### 検査と環境の制限

今回も前回作成した Cargo キャッシュを使用した。以下の `<tmp>` は `/private/tmp` を表し、保存ログ内の手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。前回の `work.log` に残っていたリポジトリの絶対パスも伏せ、停止内容は維持した。

| コマンド・確認 | 終了状態 | 外側の時間・記録 |
|---|---|---|
| `cargo fmt --all`（rtk 経由） | 0 | 2.5秒以内（同じ呼び出し内の読み取りを含む） |
| `scripts/check.sh --level work --base caadeaa397ba46a29f76ab83948a48aac90e6016 --dry-run` | 0 | 0.078秒。[保存ログ](dry-run-resumed.log)。fmt、examples 込み lint_default、lib_default、全統合 tests_related、source_rules、skill_generated、spec_tally を選択 |
| `/usr/bin/time -l env CARGO_HOME=<tmp>/benitoite-a01a-cargo /bin/zsh -c 'scripts/check.sh --level work --base caadeaa397ba46a29f76ab83948a48aac90e6016; check_exit=$?; print -r -- "A01A_CHECK_EXIT_STATUS=$check_exit"; exit "$check_exit"'`（rtk proxy 経由） | **check.sh は0**、time を含む外側は1 | real **561.94秒**、user 1633.15秒、sys 46.09秒。[保存ログ](work-resumed.log)。選択した検査は全て成功。外側の1は検査後の time の計測制限による |
| `git diff --check`（読み取り、rtk 経由） | 0 | 1秒未満 |

作業末の work は今回の基準で一度実行した。fmt と examples を含む clippy が成功し、前回の dead_code による停止を解消した。既定 lib は **1,272件成功・失敗0件・既存の除外21件**、全40統合ターゲットは合計 **378件成功・失敗0件・既存の除外10件** だった。ソース規約、Skill 生成物の一致、仕様集計も成功し、ログ末尾に `selected checks passed` と `A01A_CHECK_EXIT_STATUS=0` がある。

最大常駐量（maximum resident set size）は取得不能である。`/usr/bin/time -l` は時間を出した後に `time: sysctl kern.clockrate: Operation not permitted` と報告し、最大常駐量の行を出さなかった。サンドボックスによる制限として記録し、0とは扱わない。計測だけを目的とした work の再実行はしていない。

新しいテストの追加・変更はない。前回の test-audit の判断を維持し、型検査へまだ接続しない内部入力を呼ぶためだけのテストや差し込み口は作らなかった。Lean の変更がないため、Lean のビルドと Rust/Lean の全比較は今回実施していない。

### 計画からのずれと申し送り

前回止まった未使用警告は、設計者が認めた一時的な許可で解消した。A01a が担当する work の未実施項目は残っていない。主定理・公理や言語の規則について、新たに取りまとめの判断を要する点はない。

- A01b: 正規化した Surface の先行順、元 NodeId/span の対応、合成節点・負号・return・名前付き引数・番号超過を閉じる。`SurfaceForm` は分類であり、変換器や番号付け器ではない。
- A02: valid 条件の下で finish 前に入力を収集し、全本体の型検査後にソース順で全体駆動へ渡す。A01a では通常の型検査経路と利用者向けの警告へ接続していない。
- A07: 型検査への接続を終えた時点で、`interval/mod.rs` の一時的な許可と理由のコメント、および AGENTS.md の表の一時的な行を消し、未使用警告なしで検査を通す。
- A11: 型・環境・同定表等の操作と保持項目の計上を Lean の規則へ照合する。
- 取りまとめ: 今回の未コミットの差分と記録を独立レビューし、受け入れを判断する。
