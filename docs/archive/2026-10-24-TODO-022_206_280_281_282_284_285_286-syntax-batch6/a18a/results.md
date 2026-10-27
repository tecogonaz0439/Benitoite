# A18a の結果

- 再開の着手: 2026-10-26 06:39:05 JST（2026-10-25 21:39:05 UTC）。
- 終了: 2026-10-26 07:06:35 JST（2026-10-25 22:06:35 UTC）。再開後の所要時間は27分30秒である。
- B_WORK・HEAD: `d7edb402458ce5d8d223f9fee02d476c178a389f`。枝は `mod012/A18a`。

**状態: 指定範囲の実装と検査を完了した。独立レビューと受け入れは取りまとめへ引き渡す。** 最初の起動の型の不一致は、取りまとめの L21T・L21U・L21V の後の定義を期待値として解消を確認した。元の記録は末尾の「最初の起動の確認」に残す。実 VM と小モデルの実行比較は今回実施しておらず、X03b が閉じるまで実本体との接続は未完である。

## 範囲と変更

plan.md「計画の変更（2026-10-26、RV-C3 を受けて）」の A18a と、再開の依頼に従った。指定された計画・判断・レビュー・各結果の申し送りと取りまとめのレビューを読んだ。private/ とそこを指すリンクは読まず、git の変更操作、委任、docs/todo の変更、コミット・取り込み・公開は行っていない。rtk・test-audit・japanese-tech-writing を使用した。

| 対象 | 変更と確認する契約 |
|---|---|
| `tests/desugar_export/interval.rs` と `interval/` | Range の実ソース・独立期待値・元 Surface の書き出しと番号対応を追加した。解決済み標準宣言と実交換から RangeNames の八つの同定を得る。新しい比較用テストは一件であり、既存の六入口や入力は削除していない |
| `testdata/interval-budget/` の生成元二入力・再生成器・三表・README | Range の8形を追加し、実交換の同定だけを Lean へ渡す。費用・保持・停止・分類の期待値は Lean の実行値から生成する |
| `src/typeck/interval/tests/budget_reference.rs` | 既存の本体・全体の表形式の比較へ同じ8形を追加した。全列・全選択行を比較し、集計も同じ全体入力で確認する |
| 本ディレクトリ | 型の全件の照合、実交換・番号対応・ログ・ハッシュと本結果を保存した |

**本番の Rust、A16a〜A17b の認定・計上・保存・区間、Range.bnt、formal/ は変更していない。** 型とエフェクトの規則、公開の型・署名、Lean の主要定理の前提・結論、公理を変更する必要は生じていない。ヒープの不変条件・安全点を越える値の保持・依存・ツールチェーンの固定版も不変である。

## 実交換からの型・構成子の照合

[check-surface-types.py](check-surface-types.py) を今の `StandardRule.argumentType`・`resultType` に合わせ、[保存した11入力の実交換](resume-surface-export/corpus.json)へ実行した。既存の batch3/range.bnt も対象へ含めた。**91呼び出しの364箇所がすべて一致した。** [確認結果](resume-surface-types.json)には、各入力・定義・元 Surface の番号・解決済み callee・実際の式と引数の型・期待型・四つの判定を保存した。

| 呼び出し | 戻り値の期待型 | 引数の期待型 |
|---|---|---|
| checkInteger | `.data result [.data owner [], .data error []]` | 三つとも `.base .integer` |
| value | `.base .integer` | `.data owner []` |

各呼び出しで、実際の call の型、実際の引数の型、標準署名の戻り値型、標準署名の引数型を照合した。型の番号は各実交換から読み、固定した番号を注入していない。呼び出しのソース順と契約位置も分け、checkInteger の `[2,1,0]` と value の `[0]` を保存した。型が不一致の入力を未知に変えて通す処理はない。

[range-bindings.json](resume-surface-export/range-bindings.json) は、解決済みの標準宣言の ID で `dataDecls` の所有元を探し、構成子宣言との同一性を照合して作る。CheckedInteger は、所有元の宣言にある唯一のレコード構成子から名前を取り出し、三欄の順と型を確認する。Result と RangeError の各構成子も、解決済み宣言の所有元・tag と交換の構成子宣言を対応させる。型名・構成子の表示名で検索したり、CheckedInteger の型名から構成子を組み立てたりしない。表示名を置換した交換でも同じ RangeNames になることを、書き出しの同じテストで確かめる。

この手順は `tests/desugar_export` に置いた。実ソースの比較入力を既にここで作っているため、X02・X03b の入力と固定表の生成元が同じ書き出しの同定を使えるからである。固定表の再生成器は既定で専用の出力先へこのテストを実行し、得た同定を一時的な Lean の生成入力へ渡す。`--range-export` で直前の保存済み交換を指定する経路もある。生成器の既定の再書き出しと今回保存した交換の同定は全件一致した。

## 独立例・元の番号と X02・X03b への入力

独立期待値は [range-expectations.json](../../../../crates/benitoite/tests/desugar_export/interval/range-expectations.json)、再作成の手順は [入力の README](../../../../crates/benitoite/tests/desugar_export/interval/README.md) にある。15例を11入力・65定義として保存し、[range-inputs.json](resume-surface-export/range-inputs.json) に元ソースのハッシュ、解決済み同定、定義ごとの出現表、元 Surface の演算番号、L21 の固定番号と実ソースの番号の対応を残した。

| 形 | L21 の演算番号 | 実ソースの演算番号・評価順 |
|---|---|---|
| check 単独 | `[1]` | `[2]` |
| 成功後の直接 value | `[1,6]` | `[3,8]` |
| Error の腕 | `[1]` | `[3]`。value の8は未到達 |
| 入れ子の二検査 | `[1,7,12]` | `[3,9,14]`。内側と外側を別の関数で射影する |
| 由来のない別個体 | `[1,6]`、外部の由来キー90 | `[3,8]`。引数の別個体を射影する。90はL21の番号として区別する |
| 射影後の加算 | `[1,7,6]` | `[3,9,8]`。先行順では8の加算より先に9の射影を評価する |

両端・一点・Integer64 の両端、逆転の内側と外側、範囲外の両側、入れ子の内側・外側の成功値、引数の別個体、射影後の加算とあふれ、偽の同名関数を含めた。成功の5例には minimum・maximum・value を順に観察する閉じた `Fields` の入力も置いた。最小値はソースの直接負号であり、正の範囲外リテラルとして型検査させていない。名前付き引数のソース順は value・maximum・minimum の順である。

`OnlyOk` の Error の腕は明示的な return で抜ける。独立期待値の成功側の区間は、`intervalObservation` が示す match 式の normal 成分であり、Error の早期 return も含む関数全体の returned 成分とは区別する。三欄の観察のために minimum/maximum を Lean の標準規則へ加えていない。`unrelatedCaller` は閉じた別個体の作成を受け持ち、`unrelated` 本体の解析へ呼び出し元の由来を渡さない。偽の同定は `evalClosed = none` の対象であり、実行の一致件数へ含めない。

`range-inputs.json` は X01 の最終 interval-corpus へ接続するための入力一覧である。X01 の読者が受理した入力、X02 の全関係状態の比較結果、X03b の VM 比較結果を先取りした成果とは扱わない。元 Surface の全体は既存の交換へ保存済みであり、番号を wrapper の数から推測していない。

## 固定表と作成時の関門

既存の比較テストへ、認定した call、一保存、Result の Ok の guard・Error・wildcard の全腕、別個体の直接 value、偽の同定、動的な端点、射影を除数とする後続算術、未認定の call の子の独立解析を追加した。Rust は実際の型検査を通す同じ bnt 入力を本体・全体と書き出しで共有する。Lean の構文の形は独立に記述し、型と構成子の同定だけを実交換から渡す。

関門で守る契約は、標準束縛・Result・射影を含む任意の小予算での費用・保持・停止位置・分類と保存済み接頭辞である。走査順・auxiliary の確保・親と独立入力の混同・停止分類のずれで失敗する。旧表は標準表が空であり、これらの Range の経路を通らないため、通常の診断のテストでは不足する。本番の差し込み口を増やさず、既存の本体・全体の比較テストに行を追加した。交換には、実際の式の型と構成子の取り違えという別の危険があるため、その持ち主のテストを一件追加した。

期待値には Rust の計上を使っていない。二つの Lean の生成元は既存と同じ評価器による実行だけを使い、解析器を `decide`・`decide +kernel`・`rfl` で kernel に展開する証明は追加していない。Lean は各単体実行に `-M 12288` を指定し、一プロセスずつ終了を待った。背景のビルドを残して別の作業へ進めていない。

| 表 | 基準の形・行数 | 追加後の形・行数 | 既存行の変更・削除 | 追加行 |
|---|---:|---:|---:|---:|
| body | 102形・16,410行 | 110形・18,336行 | 0 | 1,926 |
| whole | 11形・3,330行 | 19形・6,304行 | 0 | 2,974 |
| summary | 11形・3,330行 | 19形・6,304行 | 0 | 2,974 |

[差分の確認](resume-reference-impact.json)で、基準の全キー・全列・全選択行が不変だった。新しい Range の全体と集計は、完走境界が旧走査上端200を超えるため0〜600で走査する。既存形と新しい本体は0〜200のままである。動かす資源以外の1,000・fuel 200、本体と全体の実際の解析上限、保存する完走境界の直前・ちょうど・直後という選択は保った。小予算や保持の境界を除外していない。

[生成のログ](reference-fourth.log)・[生成時の Lean 出力](resume-reference-output/budget-reference.lean.log)と[集計の出力](resume-reference-output/summary-reference.lean.log)、[再生成の照合](reference-check.log)・[照合時の出力](resume-reference-check-output/budget-reference.lean.log)を保存した。Rust の既存の比較の四件も成功し、表の全行と全列・集計が一致した。全構文・任意深さ・全関係状態の全比較を完了したとは扱わない。

## 実行した検査と修正

実行場所は `<repo>`。Cargo は既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。[run.py](run.py) がコマンド・終了状態・外側の時間を保存し、手元のパスを伏せる。固定版は Rust/Cargo 1.98.1、Lean 4.34.1 である。

| コマンド・検査 | 終了・結果 | 外側の時間・記録 |
|---|---|---|
| `cargo test -p benitoite --test desugar_export interval::export_interval_range -- --exact --nocapture` の初回・診断・コンパイル修正 | 101。下記の準備の誤り | 69.130・2.526・0.502秒。`resume-export.log`・`resume-export-second.log`・`resume-export-third.log` |
| 同じ書き出し、修正後 | 0、10入力で一件成功 | [3.622秒](resume-export-fourth.log) |
| 既存 Range と追加の観察入力を含む最終の書き出し | 0、11入力で一件成功 | [3.462秒](resume-export-final.log) |
| `cargo test -p benitoite --lib typeck::interval::tests::budget_reference -- --nocapture` | 0、四件成功。三表の全選択行・全列を含む | [31.481秒](budget-first.log) |
| `cargo test -p benitoite --test call_allocations bounded -- --nocapture --test-threads=1` | 0、二件成功。442,822,829バイト／512 MiB、254,937,092バイト／256 MiB | [11.232秒](resume-allocations.log) |
| 再生成器の初回 | 1、ログのディレクトリ作成漏れ。Lean 未実行 | [0.033秒](reference-first.log) |
| 再生成器の二回目 | 1、Lean の実行0。走査上端200では Range の全体が完走しなかった | [60.832秒](reference-second.log) |
| 再生成器の三回目 | 1、走査上端の条件式で Lean の String の型推論に失敗 | [56.833秒](reference-third.log) |
| 再生成器、修正後 | 0、三表を生成 | [87.914秒](reference-fourth.log) |
| 再生成器 `--check`、既定の専用出力への実交換から | 0、三表の全バイト一致 | [90.722秒](reference-check.log) |
| `check-surface-types.py`、保存済みの全11入力 | 0、364箇所すべて一致 | [0.034秒](resume-surface-types.log) |
| 指定 work の dry-run | 0、七単位・全統合を選択 | [0.090秒](resume-work-dry-run.log) |
| 最初の指定 work、`/usr/bin/time -l` で計測 | 検査本体1。整形成功、lint で停止。lib・統合は未着手 | [36.203秒](resume-work.log) |
| 修正後、同じ指定の dry-run | 0、同じ七単位・全統合 | [0.096秒](resume-work-fixed-dry-run.log) |
| 修正後の work、同じ自動選択 | **検査本体0、七単位成功。計測器1** | [444.218秒](resume-work-fixed.log) |

書き出しの初回の失敗は、RangeError の構成子の標準名の階層を一段省いたことによる。診断の後に `Benitoite.Range.RangeError.InvalidBounds`・OutOfRange へ直した。次のコンパイルの失敗は AST のモジュール節点の NodeId を ModuleId として使ったもので、AST 配列のモジュール位置から ModuleId を得る形へ直した。型・署名・言語規則の変更ではない。

最初の work は、新しい交換の型抽出の Expr の分岐で将来の列挙子も拾う wildcard と、まとめられる二重の if が lint に拒否された。未対応の列挙子をすべて明示し、if をまとめた。lint の許可属性や本番の差し込み口を増やしていない。整形はその修正で古くなり、lib・全統合以後は未実施だったため、同じ自動 work を再実行した。成功済みの検査を範囲変更なしで繰り返したものではない。

作業末は次の指定であり、`--test`・`--only` を加えていない。

```sh
scripts/check.sh --level work --base d7edb402458ce5d8d223f9fee02d476c178a389f --dry-run
scripts/check.sh --level work --base d7edb402458ce5d8d223f9fee02d476c178a389f
```

[run-work.sh](run-work.sh) を `/usr/bin/time -l /bin/zsh` で包み、検査本体の終了を `A18A_CHECK_EXIT_STATUS` へ保存する。最初の work の計測器は `sysctl kern.clockrate: Operation not permitted` で最大常駐量（maximum resident set size）が取得不能だった。修正後も同じ制約で最大常駐量は取得不能だった。検査本体は `A18A_CHECK_EXIT_STATUS=0`、末尾は `selected checks passed` である。real/user/sys は444.21/1342.52/53.51秒であり、計測器の終了1を検査本体の不合格とは扱わない。

| 修正後の work の内訳 | 結果 |
|---|---|
| fmt・examples を含む lint | 成功 |
| 既定の lib 全件 | **1,325件成功・失敗0・21件 ignored**（72.03秒） |
| 全統合 | **40ターゲット・388件成功・失敗0・10件 ignored**。割り当て量二件、仕様・リファレンス・Skill・標準ライブラリの例を含む |
| ソース規約・生成 Skill の一致 | 成功、生成物の差分なし |
| 仕様集計の自己検査と集計 | 成功。初回リリースの完了条件の未記入は none |

件数とターゲット別の結果は [resume-test-counts.json](resume-test-counts.json) に保存した。

## 最終点検・計画との差と申し送り

実装の範囲に拡張はなく、新しい固定表の全体形の完走境界を含めるための走査上端の追加と、検査準備・lint の修正を行った。言語の規則、Lean の主要定理・公開の Rust の型と署名についての判断待ちはない。8時間の時間上限による中断はない。

修正後の work を始める前に、関係入力25ファイルのハッシュを [resume-final-inputs-sha256.json](resume-final-inputs-sha256.json) に保存した。最初の work の入力は [resume-work-first-inputs-sha256.json](resume-work-first-inputs-sha256.json) に区別した。検査後も25件すべてが一致した。作業末の検査を始めてから、以後の編集は結果と点検の記録だけである。

| 担当・時期 | 残る検査・レビュー・受け入れ | 見込み |
|---|---|---|
| 取りまとめ、A18b の前 | A18a の独立レビューと受け入れ。構成子の抽出、型の全件の一致、三表と費用・保持・停止の一致、元の番号を確認する | 不明 |
| A18b、受け入れ後 | 設計書・生成参照・A1 の限界の全体整合、割り当てられた検査・レビュー・受け入れ | 計画の1.5〜3時間 |
| X01・X02・X03b、計画の依存を満たした後 | 最終 interval-corpus への接続、全関係状態の型・区間・候補・費用の比較、実 VM の三欄・成否・逆転優先・射影・あふれ・到達の比較、レビュー・受け入れ | 計画に従う。今回未実施のため不明 |
| 取りまとめ、各区切り | S-A3 の段、改造全体と公開候補の検査、コミット・取り込み | 計画に従う |

[最終点検](resume-final-review.json)で、入力ハッシュ・実交換の同定・Python の構文・相対リンク・記録のパスの伏せ方、formal と本番 Rust・依存・index に変更がないことを確認した。TSV の空の最終列のタブを手で削らず、TSV 以外の `git diff --check` と、空の最終列を許す `git -c core.whitespace=-blank-at-eol diff --check` が成功した。テストの削除・ignore の追加、入力・期待値・解析上限・割り当て量の上限の緩和はない。

A18a が受け持つ未実施・不合格の検査、停止条件に当たる判断待ちは残っていない。Rust と Lean・VM の全関係状態の比較、check-formal.sh 全体、stage・change・release、32ビットでの実行・クロスビルドは本枝で実施していない。最初の起動の停止記録を取り消して削除するのではなく、その後の修正を期待値とした全件の照合を今回の証拠とした。

## 最初の起動の確認

以下は最初の起動の時点の確認・停止・取りまとめのレビューである。保存した実交換と不一致の証拠はそのまま残した。当時の確認器と work の実行器は `check-surface-types-first.py`・`run-work-first.sh` に保存し、現在の確認器・基準と区別した。


- 着手: 2026-10-26 05:16:51 JST（2026-10-25 20:16:51 UTC）。
- 終了: 2026-10-26 05:23:30 JST（2026-10-25 20:23:30 UTC）。所要時間は6分39秒である。
- B_WORK: `56726f2ef44b05d2a3ce32f238aec3c708f0798a`。

**状態: 指定された型の不一致の停止条件に当たり、A18a は未完である。** 実交換の `Range.CheckedInteger` は `.data owner []` であり、Lean の `StandardRule` が要求する `.opaque owner` と一致しない。固定表や Range 解析を変更せず、証拠を保存して取りまとめへ戻す。見込み時間を理由とする中断ではない。

### 基準と変更範囲

B_WORK と HEAD は同じで、枝は `mod012/A18a`。着手時の作業ツリーに差分はなかった。plan.md「計画の変更（2026-10-26、RV-C3 を受けて）」の A18a と、依頼の「一致しなければ止めて報告する」を優先した。private/ とそこを指すリンクは読まず、git の変更操作、担当の委任、docs/todo の変更、コミット・取り込み・公開は行っていない。rtk・test-audit・japanese-tech-writing を使用した。

変更は本ディレクトリの結果・検査記録・実交換の保存・再確認用スクリプトだけである。Rust の本番とテスト、Range.bnt、設計書、固定表と生成元、formal/、依存とツールチェーンの固定版は変更していない。A16a〜A17b の認定・計上・保存・区間も変更していない。新しいテストや本番の差し込み口は加えていない。

### 確かめた入力と不一致

既存の `crates/benitoite/tests/desugar_export/batch3/range.bnt` を、本物の pipeline の型検査・脱糖・交換を通す `batch3::export_batch3_range` で書き出した。確認した入力の写しは [surface-export/range.bnt](surface-export/range.bnt)、その実行で得た型付き Surface の全体は [corpus.json](surface-export/corpus.json)、標準宣言の型は [stdlib.json](surface-export/stdlib.json)、型と構成子の同定は [builtins.json](surface-export/builtins.json) に保存した。

主に使ったソースは次の二箇所である。

```text
function upperEndpoint() -> Result[Range.CheckedInteger, Range.RangeError]
  return Range.checkInteger(minimum: 0, maximum: 10, value: 10)
end function

function recheck(value: Range.CheckedInteger) -> Result[Range.CheckedInteger, Range.RangeError]
  return Range.checkInteger(minimum: Range.minimum(value), maximum: Range.maximum(value), value: Range.value(value))
end function
```

`upperEndpoint` の戻り値の文脈と、そこから参照する checkInteger の標準宣言の戻り値型は一致する。`recheck` の局所引数の型と、`Range.value(local 0)` が参照する標準宣言の引数型も一致する。callee は型引数のない解決済み funName であり、同名の利用者関数ではない。標準宣言・型の番号は保存した実交換から読み、固定した番号を入力へ注入していない。

以下の `owner` は、この実行で CheckedInteger の型宣言に割り当てた `data:525` を指す。Result は `data:212`、RangeError は `data:529` である。番号の値を変えても、`.data` と `.opaque` という型構成子の違いは残る。

| 照合箇所 | 実ソースからの Surface・標準宣言 | Lean の StandardRule | 判定 |
|---|---|---|---|
| checkInteger の戻り値 | `.data result [.data owner [], .data error []]` | `.data result [.opaque owner, .data error []]` | 不一致 |
| checkInteger の三引数 | 三つとも `.base .integer` | `argumentType = .base .integer` | 一致 |
| value の戻り値 | `.base .integer` | `resultType = .base .integer` | 一致 |
| value の引数 | `.data owner []` | `argumentType = .opaque owner` | 不一致 |

期待型の根拠は `formal/Benitoite/Interval/Eval.lean` の `StandardRule.argumentType`（380〜382行）と `resultType`（385〜388行）である。checkInteger は不透明な成功値を含む Result、value は不透明型の引数を要求する。対して実交換の `exchange.rs:568` は `TyCon::Adt` を一律に `data` として符号化する。Range.bnt の `@opaque public record CheckedInteger` もこの経路に入り、builtins.json では三欄を持つ通常の record の宣言として保存される。

Lean の JSON 読み込み `formal/Benitoite/Exchange/Syntax.lean:71-72` は、`data` を `.data`、`opaque` を `.opaque` として別々に読む。この不一致を単なる表示や型名の正規化で解消したことにはできない。07-04 の A1 の限界に記された、実 Surface と標準規則の型の一致という条件を、現行の交換では満たさない。

[check-surface-types-first.py](check-surface-types-first.py) は保存した実交換を読み、四箇所を照合して [surface-types.json](surface-types.json) を出す。期待型は上記の Lean の二定義から記述し、Rust の型の符号化から生成していない。Lean の解析器・評価器は実行していない。不一致があるため、この確認器は意図どおり終了1となる。これは A18a の成功ではなく、停止条件の再現である。

### 実行した検査

実行場所は `<repo>`。Cargo は既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使用した。[run.py](run.py) がコマンド・終了・外側の時間を保存し、手元のパスを伏せる。

| コマンド・操作 | 終了・結果 | 外側時間・記録 |
|---|---|---|
| `cargo test -p benitoite --test desugar_export batch3::export_batch3_range -- --exact --nocapture`（初回） | 101。下記の出力先の競合 | [68.110秒](surface-range.log) |
| 同じ確認の再実行 | 0、1件成功 | [17.773秒](surface-range-confirm.log) |
| 同じ確認を専用の `BENITOITE_DESUGAR_DIFF_DIR=<repo>/target/a18a-surface` へ逐次実行 | 0、1件成功 | [0.419秒](surface-range-isolated.log) |
| `python3 <本ディレクトリ>/check-surface-types.py` | 1、二箇所一致・二箇所不一致 | [0.022秒](surface-types.log) |
| 専用出力の保存後、同じ型の照合 | 1、同じ二箇所が不一致 | [0.024秒](surface-types-final.log) |
| 指定 work と同じ基準・指定の dry-run | 0、文書だけの変更として検査対象なし | [0.080秒](work-dry-run.log) |
| 指定 work（一度、`/usr/bin/time -l` で計測） | 検査本体0、検査対象なし。計測器1 | [0.085秒](work.log) |

初回の確認が終了する前に、同じ出力先への確認をもう一度開始した。これは確認手順の誤りである。同じ `stdlib-decls.json` を二実行が rename し、片方が `NotFound` になった。両実行の終了後に専用の出力先を指定して一件だけ逐次実行し、成功を確認した。その出力を保存した。先の出力との corpus・builtins・stdlib 三ファイルの全バイト一致も [isolated-export-comparison.json](isolated-export-comparison.json) に記録した。型の不一致と、この書き出し先の競合は別の問題である。

作業末は次の指定を使い、`--test`・`--only` を足していない。

```sh
scripts/check.sh --level work --base 56726f2ef44b05d2a3ce32f238aec3c708f0798a --dry-run
scripts/check.sh --level work --base 56726f2ef44b05d2a3ce32f238aec3c708f0798a
```

[run-work-first.sh](run-work-first.sh) を `/usr/bin/time -l /bin/zsh` で包み、検査本体の終了を `A18A_CHECK_EXIT_STATUS=0` として保存した。出力は `nothing to check: only documents changed` であり、成功した検査単位は0件である。**全統合・lib 全件・lint・fmt を実施した結果ではない。** 計測器は `sysctl kern.clockrate: Operation not permitted` で終了1となり、最大常駐量（maximum resident set size）はサンドボックスで取得不能だった。real/user/sys は0.08/0.03/0.11秒である。

停止条件により、call_allocations の途中測定と固定表の生成・`--check` は未実施である。上限・入力・期待値は変更しておらず、過去の測定値を今回の測定値として引用していない。Lean のビルド・単体実行・生成・解析器の kernel 展開は行っていない。

### 残る範囲と取りまとめへの申し送り

A18a の実装完了・受け入れへ進める状態ではない。実交換と Range の区間モデルの間で、CheckedInteger の型の符号化を一致させる判断が必要である。既存の脱糖交換を変えるか、区間用の独立交換で解決済み型を対応させるか、Lean のモデル側を変えるかを、取りまとめが範囲と保証への影響を確認して決める。現行の型・署名・主要定理を変える修正は本枝で進めていない。Rust だけ精密化して警告を消す修正もしていない。

| 担当・時期 | 残る作業、検査・レビュー・受け入れ | 見込み |
|---|---|---|
| 取りまとめ、A18a 再開前 | 二箇所の不一致と修正の境界をレビューし、交換とモデルの型の対応を確定する | 不明 |
| 再開後の A18a 担当 | L21 の条件に従う全 Range 独立入力と元 Surface・番号を保存する。生成元二入力へ Range の形を加え、Lean の実行値から固定表を再生成・`--check` し、Rust の計上・保持・停止・分類と比較する。既存形の不変を確認する。割り当て量二件と全統合を含む work を実行し、取りまとめのレビューへ渡す | 元の見込みは2〜4時間。型の対応の修正費用は不明 |
| A18b、A18a の受け入れ後 | 設計書・生成参照・A1 の限界の全体整合、割り当てられた検査・レビュー | 計画の1.5〜3時間 |
| X02・X03b、計画の依存を満たした後 | 全関係状態と型・区間・候補・費用の比較、実 VM の三欄・成否・失敗優先・射影・到達の比較と受け入れ | 計画に従う。今回未実施 |

実 VM と小モデルの比較は未実施であり、接続未完である。今回保存したものは既存の脱糖交換の入力と不一致の証拠であり、L21 の全ケースを追加した A18a の interval 入力の完成物ではない。固定表にも Range の形はまだない。stage・change・release、独立レビュー・受け入れ、コミット・取り込みは取りまとめと計画の担当へ引き渡す。


### 最終点検

本番・テスト・Lean・固定表など関係入力13ファイルは B_WORK と全バイト一致した。[unchanged-inputs.json](unchanged-inputs.json) に SHA-256 を保存した。追跡ファイルと index に差分はなく、新しいファイルは本ディレクトリ内だけである。記録中の手元の絶対パス、結果からのリンク、Python の構文を点検した。[final-review.json](final-review.json) に結果を残した。作業末の work 後は結果・証拠・確認用スクリプトだけを編集し、実装・固定表・生成元・設計書は変更していない。

### 取りまとめのレビュー（2026-10-26、最初の起動）

停止は正当である。実交換の `@opaque public record CheckedInteger` は `.data owner []` であり、Lean の Range のモデルは `.opaque owner` を求めるので、実ソースの Range の呼び出しに標準の評価規則が当てはまらない（RV-C3 の軽1 の再現）。取りまとめは読み取りだけの調べ（[opaque-study.md](opaque-study.md)）を頼み、01-12「構文」が `@opaque` の data・レコードを内部構造を持つ D に含め、`O` を組み込みの不透明型とする契約に今の交換が合っていることから、Lean の側を `data` に合わせる案を採った。最初の段階として、既存の証拠付きの値 `checkedRange` を残して型を `.data owner []` に揃える Lean の作業 L21T を置き（plan.md「計画の変更（2026-10-26、A18a の停止を受けて）」）、その受け入れの後に A18a を再開する。

## 取りまとめのレビュー（2026-10-26、再開後）

固定表は三表とも追加だけで、既存の行の変更・削除はない（Range の8形を追加）。生成元は Lean の実行値から作り直し、`--check` と Rust の比較が全列一致した。実交換の91呼び出し・364箇所の型が今の Lean の定義と一致し、RV-C3 の軽1 の型の一致を全 Range 入力で確かめた。`RangeNames` は解決済みの標準宣言と交換の構成子宣言から取り出し、表示名を置き換えても同じ同定になる（RV-L21U の軽5）。本番の解析コードと formal は変えていない。`call_allocations` は A17b と同じ値。実 VM と小モデルの比較は X03b まで未完である。A18b へ進む。
