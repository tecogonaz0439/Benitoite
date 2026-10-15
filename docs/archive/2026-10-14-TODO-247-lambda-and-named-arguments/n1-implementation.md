# N1 移行前の基準と分類の固定

## 対象と基準

2026-10-14、段 1 の L4 を取り込んだ HEAD `10effc6d19a13faa1d51306b74087a6372a32fbe` を基準とする。クレートは `0.0.4`、Rust は `rustc 1.98.1 (48a229cea 2026-09-01)`、Cargo は `cargo 1.98.1 (797e8a9bc 2026-08-05)` である。study の旧基準 `fe20b76f6a83f65fc7ea7e679380418b14bbd7a3` と区別する。

N1 は記録だけを追加した。処理系・テスト・入力・期待値・formal・docs/todo は変更していない。コミットは作成していない。記録の集計は [n1/summary.json](n1/summary.json) に置く。

## 成功・診断・終了状態の基準

フィルタ、期待値の再生成、件数・種の上書きをせず、既定の構成で検査した。以下は全て終了状態 0 で成功した。

| コマンド | 結果 | テスト本体の所要時間 |
|---|---|---:|
| `cargo test -p benitoite --lib` | 1,128 成功、失敗 0、既存の ignore 21 | 74.35 秒 |
| `cargo test -p benitoite --test golden` | 2 成功、失敗 0 | 51.48 秒 |
| `cargo test -p benitoite --test random_programs` | 3 成功、失敗 0 | 41.61 秒 |
| `cargo test -p benitoite --test reference_examples` | 1 成功、失敗 0 | 1.22 秒 |
| `cargo test -p benitoite --test skill_examples` | 3 成功、失敗 0 | 2.62 秒 |
| `cargo fmt --all --check` | 成功 | — |
| `cargo clippy --all-targets` | 成功 | — |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 | — |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 | — |

四つの統合テストは一つの Cargo コマンドの複数の `--test` で実行した。実行したコマンド、出力のハッシュ、結果行は [n1/checks.json](n1/checks.json) に置く。新しい ignore は追加していない。依頼の指定により `scripts/check.sh`（`--dry-run` を含む）と gc-stress 構成の検査は実行していない。formal に変更がないため `lake build` と形式化の検査は実行していない。

[golden-baseline.json](n1/golden-baseline.json) は `.mode` を持つ 715 ケースについて、方式、期待する終了状態、診断コードの順序、入力と各期待値の SHA-256 を固定する。終了状態別では 0 が 282、1 が 95、2 が 337、7 が 1 ケースである。これらの負の終了状態は意図した検査の結果であり、テストの失敗ではない。golden の成功により、出力・診断 JSON・終了状態の厳密な比較、対象入力の整形の性質、対象範囲のコア検査と VM／参照インタプリタの比較を維持したことを確認した。

基準のテストの失敗と環境による失敗はともに見つからなかった。下記の断片を単独で検査した際の解析・依存・型の誤りを、本番や基準テストの不具合として数えない。

## 呼び出し候補の分類

study の `count-calls.py` をそのまま利用して字句上の候補を再収集し、現行入力と除外対象を分類した。[call-candidates.json](n1/call-candidates.json) の各行はパス、断片番号、位置の目安、引数数、パイプの有無、分類と抜粋を持つ。golden に属する場合は持ち主のケース、終了状態、診断コードも持つ。構成子・パターン・レコードは一般の関数候補と別に数える。

| 分類 | 一般の関数候補 | 構成子・パターン・レコードも含む候補 |
|---|---:|---:|
| 成功入力 | 2,103 | 2,456 |
| 意図した失敗入力 | 165 | 191 |
| 生成入力・組み立てる断片 | 1,010 | 1,342 |
| 歴史資料・除外対象 | 1,287 | 1,604 |
| 合計 | 4,565 | 5,593 |

成功入力は、golden の持ち主の成功または復元した一つのソースの型検査成功を根拠とする。意図した失敗入力は golden の期待値を根拠とする。Rust のリテラル・生成器のテンプレート・単独では依存や宣言が足りない説明断片は生成入力に分類し、単独検査の成否を別表に残す。後者を成功入力や本番の不具合と断定しない。Rust の文字列の `line` はエスケープを展開した行数を含むため、元ファイルの正確な行番号ではない。識別にはパスと断片番号を併用する。

現行 `.bnt` の一般の関数候補は、複数の明示引数 2,046、パイプ右辺の一つの明示引数 12 である。study の 2,045・12 は段 1 より前の見積もりとして保持する。短いラムダの終わりを理解しない字句集計の限界も維持する。いずれの数も変更件数や独立したテスト件数ではない。

除外対象は design.md の分類に従う。`docs/archive/`、`reference/`、過去のベンチマーク記録、構文の測定の比較資料、最小実行版リファレンスは移行しない。この改造の文書と生成済み Skill の参照文書も手で移行する対象にしない。Skill の手書きの例は現行対象とする。docs/todo は読まず、一覧にも含めていない。追跡されていない fuzz の生の corpus と測定の生の記録は集計しない。現行のベンチマーク入力、Skill 評価の参照解、生成元と fuzz のソースは対象から除かない。測定・LLM 評価は実行していない。

## Q10 の宣言と R2 の変更範囲

標準ライブラリ 52 モジュールを `SourceKind::Prelude` で字句解析・改行判定・構文解析した。解析の誤りは 0、宣言は 563、モジュールと外側の名前の組は 235 であり、design.md の付録の全 235 行と名前・順・宣言数を照合して一致した。宣言の内訳は通常の関数 436、実装の関数 60、操作 57、メソッド 10 である。通常の `@builtin` 312 宣言も維持されている。

[q10-declarations.json](n1/q10-declarations.json) は全 563 宣言のパス、位置、名前、種別、外側のパラメータ名を保持する。コンテナの内側を含め、内側の関数型 55 箇所を再帰的に抽出し、Q10 の候補名と個数を照合した。個数の不一致は 0 である。Map の二引数は `key, value`、三引数は `acc, key, value`、Regex は `matched`、HTTP は `request`、Result.mapError は `error`、その他の一引数は `value`、畳み込みは `acc, value`、Task 系のゼロ引数は空の並びとする。Trait の宣言・実装・補助宣言も含む。外側の公開名を変える必要は見つからなかった。

生成する契約は Q10・R13 の表を維持する。レコードの取り出す関数は `value`、位置フィールドの構成子値は宣言位置の `argN`、レコード構成子値は宣言順の欄名とする。これらはソースの `function` 宣言 563 件には加えない。内部の組み込みは `builtins/table.rs::builtin_scheme` と Q10 の内部名の表を正とし、Rust の本体の変数名から公開名を作らない。

R2 の変更表と現行の場所を次のように照合した。N1 ではいずれも変更していない。表外の公開の型・シグネチャを変える必要は見つからなかった。

| 予定の変更 | 現行の場所・確認した境界 |
|---|---|
| `Arg`・`NamedArg`・`ArgValue`、`FnType` の名前と origin | `syntax/ast.rs`。位置引数の二種と現在の型引数の並びを保持する |
| `FnTy`・`Scheme` の名前と origin、Eq・Hash・表示 | `types/mod.rs`。パラメータの型の並びと置き換えを保持する |
| `IFnTy.contract`・契約変数・保留呼び出し | `typeck/infer.rs`、`solve.rs` の Solver。名前を型変数・エフェクト変数と区別する |
| 呼び出し計画の表 | `typeck/context.rs` の非公開の Body、`typeck/mod.rs` の TypeckOutput。呼び出しノード単位に対応する |
| `Lambda<C>`・`Def<C>`・`OpDef` の静的な名前 | `ir/core_ir.rs`。辞書の引数と利用者の引数を区別する。下位 IR への写像でも保持する |
| 位置命令への変換 | `bytecode/codegen/`。VM の関数・クロージャ・値の実行時レイアウトは変更対象にしない |
| 移行中の Legacy と旧適合 | 同じ表現と制約の理由の記録。型の Eq・Hash から名前を消す方式にはしない |

## R11 の関数値の合流

既存の lexer・newline・parser、名前解決の表、TypeckOutput.expr_types を利用した。[typed-inputs.json](n1/typed-inputs.json) は現行の `.bnt` と抽出した Rust／Markdown の 4,024 入力の検査状態を記録する。うち標準ライブラリ 52 は上の宣言調査に分けた。単独で型検査に成功したものは 982、解析の誤りのある断片は 2,179 である。読み込みと名前解決を通り、型検査で誤りとなる 335 入力は、型検査の回復出力も読んだ。読み込みや名前解決に失敗した入力には型情報を創作していない。

無作為生成器は、既定テストと同じ `generate(seed, 6)` の種 0〜299 のソースを復元し、300 件全ての型検査成功を確認した。種・段・ソースの SHA-256 は [generated-snapshot.json](n1/generated-snapshot.json) に保持する。これは全ての種の列挙ではない。その他の生成元の場所とハッシュは [generators.json](n1/generators.json) に保持する。Rust の文字列の連結・format の展開や複数ファイルのハーネス全てをこの調査で再実装したものではない。

[joins.json](n1/joins.json) は関数型を直接またはコンテナ内に含む合流を、一般の呼び出し・旧い型注釈の候補と別に保持する。各行に種別、ソース内のバイト位置、パスと断片番号、所有する関数・ラムダ、型、元の契約名の出どころと候補名を記録した。早期 return の式自体には周囲から関数型が付く場合があるため、戻り値は返す値の型で数える。

| 合流の種類 | 現行ファイルの成功した単独入力 | 型エラーの回復出力 | 既定の生成ソース | 合計 |
|---|---:|---:|---:|---:|
| if の分岐 | 1 | 0 | 21 | 22 |
| match の分岐 | 0 | 0 | 0 | 0 |
| リスト（spread を含む） | 42 | 3 | 0 | 45 |
| Reference.set | 0 | 0 | 0 | 0 |
| レコードの欄 | 0 | 0 | 0 | 0 |
| 戻り値 | 14 | 7 | 106 | 127 |

ゼロ引数のタスク用関数もリストの合流に含める。Reference.set は名前の字面ではなく、解決した `Benitoite.Reference.set` の束縛で判定した。表のゼロは、型情報を得た今回の入力群で関数値の合流がなかったことを表す。型情報を得なかった断片や未列挙の生成ソースに、その種の合流がないことは主張しない。

候補の状態は、ソース先頭のラムダ名 162、宣言契約の確認が必要なもの 2、適合成分の解析が必要なもの 20、型エラー入力としての確認が必要なもの 10 である。最初のラムダの名前を候補にしても、そのまま適用済み manifest にはしない。N17 で同じ適合成分の宣言から期待契約を得られる場合はそちらを優先し、衝突・相反する契約・公開される関数値を確認する。未確定の 20 件やエラー入力を、仮名で確定させない。

## 仕様上の診断の旧→新対応表

以下は N28・G7 に向けた初期の対応表であり、新しい診断の実装結果ではない。既存の入力・assert・JSON を変更していない。位置の数値は移行後のソースで N19・N20・N28 が確認する。

| 実ファイル・元の入力 | 旧→新の方針と根拠 | 元の誤りの維持先 |
|---|---|---|
| `testdata/types/arity.bnt:11` の `add(1)` | E0402 → 旧位置指定を残すなら E0449、`add(left: 1)` へ移行するなら E0453（不足は `right`）。複数パラメータの名前必須と不足の優先順位による | 同じケースの引数不足の意味と終了状態 2 を維持する。一般の E0402 は下の一引数と構成子の検査で維持する |
| 同ファイル 12 行の `Shape.Rect(1)` | E0402 → E0402。直接の位置フィールドの個数検査を維持する | 同じケースの二つ目の診断を削除しない |
| `src/typeck/tests.rs:1174` の `f()`（一引数） | E0402 → E0402。一引数の位置呼び出しの個数検査を維持する | 同じ expect、個数と主文の assert を維持する |
| `src/typeck/tests.rs:1259`、`return_call_keeps_argument_position_diagnostics` の List.map と `lambda(n)` | 旧表記のままなら E0449、外側だけ名前付きにして `n` を残せば E0454 が先。元の E0401 は外側の `xs, f` とラムダの `value` を揃えて到達させる | 同じケースの E0401 と引数の位置の検査を維持する。E0454 だけに置き換えて合格させない |
| `testdata/syntax/c11-lambda-colon.diag.json` | E0243 → E0243。主文・ヘルプは L2 の記録にある変更済みの値を N1 の基準とする | [l2-implementation.md](l2-implementation.md) の旧→新の記録と既存の厳密な JSON 比較 |

design.md の `f(1, 2, 3)` は診断の例であり、その形の E0402 の golden は現行に存在しない。現行の E0402 の golden は `arity.diag.json` の二つである。過剰な名前の E0451 と名前付きの不足 E0453 は、対応する新規則のテストとして元の個数検査と区別する。一般の負のケース全体は golden の基準一覧で保持し、ラベル不足が先に出て元の診断を検査しなくなる移行を認めない。

## 型表示とヘルプを確認する JSON 11 件

旧 JSON の全内容とハッシュは [type-display-baseline.json](n1/type-display-baseline.json) に保持する。R22 に従い、検索で見つかった件数と表示を変える候補の件数を区別する。

| `crates/benitoite/testdata/` 以下のファイル | 現行の診断 | 旧→新の表示の方針 |
|---|---|---|
| `effects/effect_var_rigid.diag.json` | E0401 | `function() -> Unit uses E` と IO.All の表示を維持する |
| `effects/outermost_only.diag.json` | W0501・E0401 | `List[function() -> Unit …]` の表示を維持する |
| `names/uses_not_effect_later.diag.json` | E0316 | ヘルプの外側の二引数の関数型に名前を付ける。内側のゼロ引数と uses の境界の説明を維持する |
| `syntax/uses_then_bracket.diag.json` | E0209 | ヘルプの外側の二引数の関数型に名前を付ける。括弧の二つの編集と元の構文の誤りを維持する |
| `traits/c11-method-no-cascade.diag.json` | E0711 | `function(Integer)` → `function(x: Integer)`。戻り値の Integer／String の不一致を維持する |
| `traits/todo178-e0711-parameter-names.diag.json` | E0711 | 両側に `x, a, b` を表示する。型パラメータの A・B／Integer・Q の不一致を維持する |
| `traits/todo178-impl-target-cascade.diag.json` | E0712 | `function(Integer) -> Integer` の契約名は成分を移行して確定する。関数型への実装の拒否を維持する |
| `traits/todo178-impl-target-independent.diag.json` | E0712・E0705・E0705 | 同じ契約名の未確定箇所を残す。独立した型クラスの誤りも維持する |
| `types/equality_function.diag.json` | E0406 | `function() -> Integer` の表示を維持する |
| `types/equality_summary.diag.json` | E0406 | `Nest[function() -> Unit]` の表示を維持する |
| `types/f20-interpolation-no-show.diag.json` | E0422 | `function(Integer) -> Integer` → `function(x: Integer) -> Integer`。補間の拒否を維持する |

名前のない関数型を含む負の入力は、注釈を移行して元の診断に到達させる。名前必須そのものを試す E0257 の入力は別の新規則のケースとする。位置はラベル・注釈を加えたソースから再計算し、旧値と新値の確認表を残す。

## language 宣言の分類

[language-declarations.json](n1/language-declarations.json) は 113 記述箇所を、版と検査の目的で分類する。Rust では入力だけでなく期待する文字列や生成テンプレートも数えるため、実行する独立した宣言 113 件という意味ではない。Markdown はコードブロックの候補だけを読む。

| 目的 | 記述箇所 |
|---|---:|
| 通常の文書の例 | 5 |
| モジュール・パッケージの fixture | 45 |
| モジュール・パッケージのヘッダ・実行の検査 | 30 |
| 整形後の保持 | 4 |
| ヘッダの構文の検査 | 16 |
| ハッシュするバイト列 | 1 |
| E0907・E0908 の境界の検査 | 1 |
| 未来の版・探索範囲の検査 | 4 |
| fixture の生成元 | 1 |
| 歴史資料 | 6 |

版の文字列は `0.0.3` が 97、`0.0.4` が 2、`99.0.0` が 4、`0.0.2` が 2、不正な版の `01.2.3` が 1、補間 `${1}` が 1、生成の `{}` が 1、過去の比較表記が 5 箇所である。testdata の `.bnt` に限ると `0.0.3` は study と同じ 46 ファイル、`99.0.0` は 3 ファイルである。

N35 では公開する版を設計者が決めてから、通常の例・fixture の版を更新する。`modules/package.rs::version_check_reports_the_earliest_applicable_change` は 0.0.3・0.0.4・0.0.6 等で境界と最初の変更を検査しているため一括更新しない。`modules/tests.rs::root_settings_do_not_come_from_parent_directories` の 99.0.0 は、未来の版への拒否を直接検査する例ではなく、親の設定を読まない契約を検査する。整形・package の移動の期待する文字列とハッシュの入力も、その持ち主と一緒に更新する。

## 再現方法と後の作業

[n1/prepare.py](n1/prepare.py) と [n1/finalize.py](n1/finalize.py) は読み取った材料を記録へまとめる調査用スクリプトである。AST／型情報の読取器のソースは [collector.rs.txt](n1/collector.rs.txt)、種の復元のソースは [generator.rs.txt](n1/generator.rs.txt) に置く。移行する道具や処理系の新しい入口ではない。`prepare.py` はリポジトリの根で実行し、第 1 引数に一時ディレクトリを与えると、その中に `inputs.json` を作る。`finalize.py` は同じ一時ディレクトリを受け取る。

読取器はテストでビルドした `target/debug/deps/libbenitoite-a0d2dfecc11d6a62.rlib` と同じディレクトリの serde_json を `rustc --edition=2024 -L dependency=target/debug/deps --extern …` でリンクした。標準入力に inputs.json を与え、行ごとの JSON を ast.jsonl に保存した。型検査が失敗した 811 入力に絞って回復出力も読む版を実行し、recovered.jsonl を保存した。生成器は generated-inputs.json、読取器は generated.jsonl を出力する。ソースの `.txt` は一時ディレクトリに `.rs` として写してビルドする。rlib のハッシュ名はビルド環境で変わるため、その環境の同じ構成の成果物を使う。finalize.py はこの四つの読取結果から記録を再集計する。N1 の記録を上書きして後の版の基準にしない。

テストは追加・変更していないため、test-audit の作成時の関門を要する変更はない。後の作業では、元の観察可能な契約、具体的な退行、持ち主の境界、新しい本番の差し込み口を要しないことの四点を、テストを変える前に記録する。

計画とのずれは R22 の確認対象の分類だけである。N17 は未確定の契約候補と組み立てる入力を復元し、N19・N20 は型表示と位置、N27・N28 は負の入力の元の検査、N33 は旧適合の残数ゼロ、N35 は目的別の版の更新をこの基準と比較する。N1 の候補数だけを移行完了の条件にしない。
