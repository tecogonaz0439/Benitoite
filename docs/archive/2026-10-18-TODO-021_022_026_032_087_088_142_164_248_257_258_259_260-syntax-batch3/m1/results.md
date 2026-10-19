# M1の実装結果

## 基準と変更

B_WORKと段4開始版は `6f60cd229ac37806b179709c6083e1d8eac3df24`。開始時の作業ツリーに差分はなかった。コミットとdocs/todo/の変更は行っていない。

Trait.bntへFunctor2・Applicative2・Monad2の宣言とResultの三実装を追加した。mapはResult.map、flatMapはResult.andThen、pureはResult.Okを使う。applyは関数側のErrorを優先し、両方Okの場合だけ中の関数を一度呼ぶ。型検査・辞書の脱糖・VM・フォーマッタの本番コードを変えず、既存の二引数の型構成子・上位辞書・メソッド値化の規則を使う。

01-06・02-06・03-06、英語リファレンス、手書きSkillとidiomsを更新し、gen_skillでTraitの参照を作り直した。具体型の関数と汎用関数に必要な制約、成功値の連結とtryの処置、型付きFailの値への変換、表示・比較の意味の違いを記した。日本語訳と版の切り替えは計画どおりV1へ残す。

## テストの関門とL2との対応

| 持ち主の境界 | 守る契約と捕まえる退行 | 既存の検査では足りない点 |
|---|---|---|
| CLIのgolden `traits/monad2-minimal.bnt` | 裸のResultへの二引数クラスの実装、汎用呼び出し、成功とErrorの保存。VMと参照実行器を比較する | 二引数の種類の負例だけでは、受理後の辞書と実行を確認できない |
| CLIのgolden `traits/monad2-result.bnt` | 三クラスの標準実装、二段の上位射影、map/flatMap/pureの値化、applyの四分岐とError優先、引数のソース順とコールバック0/1回、純粋な法則の有限例 | 既存のOption/Listの一引数クラスは第二の型Xを保つ契約を通らない |
| CLIのgolden `traits/monad2-user.bnt` | 利用者の二引数dataの三実装、汎用関数とエフェクトを持つコールバック、上位射影と値化、成功とErrorの各分岐 | Resultの標準実装だけでは利用者型と上位実装の接続漏れを検出できない |
| 公開checkの `binary_traits_preserve_error_types_kinds_and_callback_names` | X不一致、種類、所属と重複、コールバックの引数名、完全適用した別名の受理と裸の別名の拒否。9例の診断列全体を固定する | 新しいクラス名への接続と第二の型の保持は従来の一引数の例では未確認 |
| `fmt_command`の `fmt_keeps_parenthesized_effectful_function_type_arguments` | 型引数の関数型の括弧を保持し、整形後のCLI checkと再整形を通す | 既存のフォーマッタの例には、usesの行と第二の型引数の区切りを実際に検査するものがない |
| `desugar_export`の `export_batch3_monad2` と局所比較 | 上の三実ソースを既存の五形式へ書き出し、型付き表層・辞書位置・コアをLeanの独立した規則で照合する | VMの値だけでは書き出しの欠落・辞書の型や番号の不一致を検出できない |

新しい差し込み口や本番のテスト専用コードはない。既存のassertの削除・ignoreの追加はない。既存の標準クラス・実装の厳密な件数だけをR165に従って三件ずつ増やし、メソッド・上位辞書・束縛の対応のassertはすべて保った。Pythonの局所比較はR163に従ってコアと表層の検査単位を区別し、全件一致と対象外・不一致0件を保つ。

最小例を先に型検査・コア検査・VM/参照比較・六入口の交換へ通した。その後、Surface.Monad2Examplesの独立期待に合わせ、ResultとUserResultでmapのOk(7)→Ok(42)・Error(input)保存、flatMapのOk(7)保存・Error(callback)・Error(input)、pureのOk(7)、applyのOk(42)・Error(input)・Error(function)・両ErrorでError(function)を固定した。二段上位のmapと値化したflatMapも実行する。ResultLawsのmap恒等・合成・flatMap左右単位元と結合・map/flatMapの対応・apply/flatMapの対応は、純粋な有限例を実行する。任意の実装の法則の証明や、本体の全形式化比較の成功へ拡張して扱わない。

## 検査

途中は変更箇所に関係する次の検査だけを実施した。局所テストの外側の時間は未計時である。

- `BENITOITE_GOLDEN_FILTER=monad2-minimal cargo test -p benitoite --test golden` と、修正後の同指定に `golden_suite` を加えた検査: 最終は0。最初は新規入力の.exitとConsoleのimportが欠けており、それぞれ追加した。
- `BENITOITE_GOLDEN_FILTER=monad2-result cargo test -p benitoite --test golden golden_suite`、同じ指定のmonad2-user: いずれも0。
- `cargo test -p benitoite --test named_arguments binary_traits_preserve`: 最終は0。下書きの診断番号と現行の診断列の違いはR164に記録し、新規例を既存の優先順へ合わせた。既存の期待値は変えていない。
- `cargo test -p benitoite --test fmt_command fmt_keeps_parenthesized`: 0。
- `cargo test -p benitoite --test desugar_export export_batch3_monad2`: 最終は0。最小入力のimport修正後と、三実ソースへの拡張後に関係する書き出しだけを確認した。
- `python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/m1 --report /private/tmp/benitoite-m1-minimal-exchange.json`: R163の集計修正後は0、最小の4定義・表層3件を六入口で照合した。拡張後の関係する開発時の比較も0、31定義・表層26件が一致した。

編集の手順として既存CLIのfmtで標準ソースと新規goldenを整形し、`cargo fmt --all` と `cargo run -p benitoite --example gen_skill` を実行した。

作業末の初回workは一度実行した。libの1210件が成功し、追加前のクラス・実装の件数を期待する既存の一件だけが失敗した。R165のとおり厳密な件数を9→12・60→63・62→65へ更新した。失敗した一件の直接の再実行は終了0、1件成功、外側5.280秒である。成功済みのlib全件を重ねず、古くなったfmt/lintと未実施の単位を補完し、すべて成功した。

| コマンド | 終了状態・結果 | 外側の時間 |
|---|---|---|
| `scripts/check.sh --level work --base 6f60cd229ac37806b179709c6083e1d8eac3df24 --test '*' --dry-run` | 0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tallyを選択 | 未計時 |
| 同じ指定（`--dry-run`なし） | 1。fmt/lint成功、lib1210件成功・1件失敗・既存ignored 21件。上記の件数更新で修正 | 75.667秒 |
| `cargo test -p benitoite --lib standard_library_sources_and_dictionary_contracts` | 0。1件成功 | 5.280秒 |
| 補完のwork（planのM1補完行）のdry-run | 0。fmt・lint_default・tests_related・source_rules・skill_generated・spec_tallyを選択 | 未計時 |
| `scripts/check.sh --level work --base 6f60cd229ac37806b179709c6083e1d8eac3df24 --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally --test '*'` | 0。六単位すべて成功。全39統合ターゲットは283件成功・失敗0・既存ignored 7件 | 314.618秒 |
| `cargo clippy --all-targets` | 0。警告なし | 10.397秒 |
| `python3 -B formal/tests/test_batch3_exchange.py --rust-dir target/formal-batch3/m1` | 0。独立入力11テストとRust入力の六入口比較に成功 | 5.92秒 |
| `python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/m1 --report <D>/m1/exchange-results.json` | 0。三実ソース・コア31定義・表層26件、六入口で一致 | 0.35秒 |

`<D>`は本改造のディレクトリである。最終の局所比較はworkのdesugar_exportが生成した五形式をそのまま使い、PythonからCargoを起動していない。入力ハッシュと六入口の結果は [exchange-results.json](exchange-results.json) に保存した。初回の書き出しではメソッドと上位辞書も別のコア定義として数える一方、表層は実装を一件として検査するため、R163で比較する件数を分けた。全コア定義と全表層の一致を保持している。

通常workのlintは `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`、libは `cargo test -p benitoite --lib`、全統合は `cargo test -p benitoite --test '*'`、fmtは `cargo fmt --all --check` である。既定のgc-mark-sweep構成を使い、作業末の検査にはテストのフィルタを付けていない。spec_examplesの7件・reference_examplesの1件・skill_docsの8件・skill_examplesの3件も全統合に含まれる。spec_tallyは既存の未参照の節を表示したが終了0、初回リリースの完了条件の未記入は0件だった。`git diff --check`も0。全件の特殊構成・gc-stress・check-formal.sh・全ターゲットのテストは追加していない。formal/を編集していないのでlake buildは追加していない。

本番Rustコードの増減は0行である。Rustのテストは127行追加・3行削除（うち3対3は厳密な件数の更新）、比較用Pythonは11行追加・1行削除。標準ソースTrait.bntは47行、新規goldenのソース三つは計218行追加した。生成参照・文書・結果の記録はこの行数へ含めない。

## 計画との差と申し送り

R163は局所交換の集計単位とB_WORK・追加clippy、R164は拒否例の診断番号の具体化、R165は既存の標準クラス・実装の厳密な件数の更新と検査の補完である。公開シグネチャ・入力の保持・評価順に計画との差はない。型の部分適用、新しいVMの検索、formal/の規則・主定理・公理・Builtins.Assumptions、安全点を越える値の保存は変更していない。

取りまとめ用の交換の増分は、Traitのクラス宣言3・メソッドの署名4・Resultの実装3（メソッド4と上位辞書の定義3）。goldenの追加は次のとおりである。

| 入力 | コアの定義数 | 通常関数 | 実装 | 表層の検査数 | match | パターン束縛 |
|---|---:|---:|---:|---:|---:|---:|
| traits/monad2-minimal.bnt | 4 | 2 | 1 | 3 | 2 | 0 |
| traits/monad2-result.bnt | 13 | 13 | 0 | 13 | 1 | 0 |
| traits/monad2-user.bnt | 14 | 7 | 3 | 10 | 4 | 0 |
| 合計 | 31 | 22 | 4 | 26 | 7 | 0 |

UserResultはdata宣言1・構成子2、最小例のBinaryはクラス宣言1・メソッド署名1も追加する。局所書き出しはこの三goldenと同じソースを使い、別のglobal corpus入力は増やしていない。Traitを読む既存入力には三クラス・三実装の宣言表が加わる。exchange-manifest.jsonとrouting-manifest.jsonの最終再集計は計画どおり取りまとめへ渡す。日本語訳・0.0.9の版・同梱物の最終照合はV1、構築器との接続とstage4はB1〜B3と取りまとめへ残す。
