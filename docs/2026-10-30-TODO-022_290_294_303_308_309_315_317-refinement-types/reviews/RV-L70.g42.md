# RV-L70.g42: L70 群 G の L70.42（処理系の試験の側の書き出しを新しい版へ）の独立レビュー

2026-11-07。対象はブランチ `m014/l70.g42` の作業木の未コミットの差分と未追跡のファイルである。基準は `eb4f0ef9b4a95e92d09d194d88d8eb38f7024c4f` で、`git log -1` の一致を確かめた。本書の `<repo>` は対象の worktree、`<tmp>` は実装担当の一時領域（results.md の `<tmp>` と同じ）、C は本書を置く改造ディレクトリを表す。本レビューは本レビュー一回である。

読んだもの:

- 本体の作業木の依頼文 `work/m014/L70.g42-claude-prompt.md` と報告 `L70.g42-claude-report.md`、[L70.42 の結果](../l70/g42/results.md)と同じディレクトリの台本（`compare_relocated.py`・`routing.py`・`prepare.py`・`Validate.lean`）と保存された集計（`compare-desugar.json`・`compare-coverage.json`・`new-desugar-summary.json`）。
- [群 G の交換の契約](../l70/g/exchange-contract.md)、群 G の [compare_exports.py](../l70/g/compare_exports.py)・`stream_json.py`・[old-desugar-summary.json](../l70/g/old-desugar-summary.json)。
- [detail.md](../l70/detail.md) の F08、L70.41・L70.42 の行、第8.2節、検査の割り当ての W-R と F-REG の行。記録の形は [RV-L70.k2](RV-L70.k2.md) の初回の部分に倣った。
- 差分の全体（`routing-manifest.json` は版の行の置き換えだけであることを `git diff -U0` の集計で確かめた）。照合のために、Lean の `Exchange/Syntax.lean`（`Header`・`Definition`・`ClassEntry`・`DataTypeInfo`・`Input` と新しい欄の構造）、`Exchange/Builtins.lean`、`Exchange/Version.lean`（`exactFields`・`validateSyntaxFields`・`validateRanges`）、`Exchange/Convert.lean` の `operationProgram`、`Exchange/CanonicalNames.lean`、`Interval/Exchange.lean` の版と欄の検査、`formal/tests/test_batch3_exchange.py`・`test_batch2_exchange.py`・`interval_*.py` の版の要求、`scripts/check/test_policy.py` の該当の試験、`scripts/check/formal_interval.py` の区間の要約の読み方を読んだ。基準の一つ前の本線（`d9cf242d`）の `Exchange/Syntax.lean`・`Version.lean` も、旧版の欄の有無を見るために読んだ。

したことは、差分と Lean の交換の構造の欄の照合、旧版の番号の残りの `grep`、保存された集計の読み合わせ、正規化の台本の読解、`<tmp>` の新しい書き出しの読み取り（小さい文書の新しい欄の中身、構成子の種類の出現の数、交換でない文書に補われた欄の数）、`cargo test -p benitoite --test desugar_export --test coverage_export` の一回の実行である。

`lake build`・Lean の検査・`scripts/check.sh`・書き出しの実行・git の書き込み操作は行っていない。台本は読んで判定し、実行していない。変更したリポジトリのファイルは本書だけである。

## 結論

**可。重0件、中3件、軽2件、情報4件である。**

処理系の本体（`crates/benitoite/src/`）に差分はない。試験の側の全ての書き出しはコーパス16・付随の表8（区間の `surfaceVersion` 16）で書き、旧版の番号の書き出しは残っていない。補った欄は全て Lean の新しい版の構造にある欄であり、篩・`@proofSteps`・別名・レコード・tester・外部宣言・論理の証明書は空か null で、新機能を書いていない。Lean の読者は `exactFields` と往復の一致で知らない欄を断るので、全229文書を読めたという記録は、交換の文書について契約どおりであることの十分な裏付けになる。主コーパスの件数・除外の理由・外部の除外は、保存された集計で旧版と一致する。

ただし、照合の正規化は、値を持つ新しい欄（型パラメータの種類・型クラスの引数の種類・構成子の対応・不透明型の公開名）を形だけ確かめて除く。そのため「新旧の差は形式の欄・範囲の実引数の書き方・版の番号だけ」は言い過ぎで、これらの欄の中身はどこでも照合されていない（中1）。直列化の補助は、交換でない文書にも欄の組だけで欄を補っており、正規化と Lean の読み込みのどちらもこれを検出しない（中2）。版の番号に依存する `formal/tests` の読者を直していないので、W-R の検査（方針の自己検査を含む）と `check_named.py` は、固定入力の候補を当てるまで失敗する（中3）。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | C/l70/g/compare_exports.py の `normalize`（`tparamKinds`・`argumentKind`・`opaqueNames`・`constructors` の枝）、results.md「新旧の照合」の最後の段落、`Exchange/CanonicalNames.lean` の `ofInputs` | 正規化は四欄の形（個数・`value` か `{"constructor":{"arity":n}}`・文字列の組）だけを確かめて除く。基準の一つ前の本線の Lean の交換はこれらの欄を持たなかったので、新しい書き出しで初めて Lean へ渡る情報である。中身も空ではない。新しい書き出しには `"argumentKind":{"constructor"` が 1,646 回、先頭の型パラメータが構成子の種類の `tparamKinds` が 2,122 回現れる（後者は下限）。四欄の中身の正しさを確かめたのは次の三つだけである。(a) Lean の読者の個数の一致（`type parameter kind count mismatch`）。(b) `scope_tables` の組込みの表と独立の期待値の一致（`tparamKinds` は全て空）。(c) 本レビューで見た小さい文書。`path-in` 等の `opaqueNames` が `Benitoite.Scope.PathIn`・`Benitoite.Network.Http.RequestIn` を含み、`CanonicalNames` の `knownOpaque` の名と合うこと、`constructorName` が null の構成子がないこと。`constructors` と `opaqueNames` を名前の対応へ写す `CanonicalNames.ofInputs` は、既定のビルドのどのモジュールからも import されず、`Validate.lean` も呼ばない | results.md と報告の結論を「新旧の差は、形式の欄・範囲の実引数の書き方・版の番号と、旧版が持たなかった値の欄（四欄。中身は Lean の読者の個数と形の検査だけを通った）である」に改める。四欄の中身の照合を L70.41 か F-REG の確認の対象として記録する。例えば、構成子の種類の型パラメータを持つ入力が新しい7入口で受理されること、`ofInputs` を全ての組込みの表に当てて誤りがないことである | 読めば確定（正規化の台本と Lean の構造）。出現の数は `grep` で数えた |
| 中2 | 中 | `crates/benitoite/tests/desugar_export/exchange.rs` の `exchange_fields`、results.md「Lean の読者での読み込み」の「交換の文書でない…58ファイルは読まない」 | `ExchangeJson` は欄の組だけで交換の構成子を見分けるので、`exchange::to_vec` と流れの書き出しを通る全ての文書に欄を補う。新しい書き出しの交換でない文書には、次の欄が補われていた。<br>- `interval-summary.json`: 要約の各項目（`group`・`excluded` を持つ）に `aliases`・`records`・`testers`・`externals`・`logicCertificates`・`candidates` が各24。<br>- `range/original/interval-manifest.json`: 同じ6欄が各1、`ranges` が481。<br>- `known-scope-failures.json`: 同じ6欄が各10。<br>- `range-bindings.json`: `variances`・`requirements`・`publicBoundary` が各33。<br>- `correspondence.json`: `candidates` 270、`ranges` 700。<br>- `interval-material.json`: `ranges` 149。<br>- `range/vm-sites.json`・`shifts/vm-sites.json`: `ranges` が85・108。<br>このうち `interval-summary.json` の項目は交換の `Input` ではないので、補った欄は意味を持たない。表層の式の断片（vm-sites・material の `funName` など）に `ranges` を補うのは、新しい版の断片として正しい可能性がある。照合の正規化は空の `candidates`・`ranges` をどこでも除き、6欄は空であることを確かめて除くので、補われたことを検出しない。`Validate.lean` はこれらの文書を読まない。読者（`scripts/check/formal_interval.py`、`formal/tests/interval_*.py`、区間の比較器）が受けるかは確かめていない。results.md は `scope-tables-expected.json` だけを「交換の文書ではないので補わない」として扱い、ほかの文書の扱いを述べていない | 次のどちらかにする。(i) 欄を補う対象を交換の文書（コーパス・表・stdlib・網羅性・区間の交換）に限り、要約・manifest・material・observations・vm-sites・correspondence・bindings は `serde_json` で書く。式の断片を交換の形で書く必要があるものは、その旨を記録する。(ii) 現状のまま補う場合は、交換でない文書の一覧・補われた欄・読者が受けることの確認を results.md に置き、F-REG の前に読者の試験で確かめる | 読めば確定（補助の判定と書き出しの中身）。読者が受けるかは未確認 |
| 中3 | 中 | `scripts/check/test_policy.py` の `test_formal_remaining_batch3_profiles_and_failure_propagation`、`formal/tests/test_batch3_exchange.py:177`（`rust_inputs` が版12〜15だけを受ける）、`formal/tests/test_batch2_exchange.py` の `check_rust`（版15/7を要求し、`check_named.py` の `main` が呼ぶ）、`formal/tests/interval_*.py` の `surfaceVersion=15`、detail.md の検査の割り当ての W-R の行 | 失敗の理由は記録どおりで妥当である。方針の自己検査は実物の `test_batch3_exchange.py` を写して呼ぶので、偽の入力を16/8へ改めた本単位の変更の後は、その読者が版15までしか受けないために失敗する。偽の入力を15/7のまま残すと、旧版を前提にした自己検査が残る。そのため、自己検査を改めた判断も妥当である。ただし帰結として、W-R（`check.sh --level work … --test desugar_export --test coverage_export`）は `scripts/check/` の変更で方針の自己検査を選ぶ見込みが高く、失敗する。`check_named.py` も新しい書き出しで失敗し、F-REG はこれらが直るまで走らない。三つの読者は Lean の入口の文言に依存せず、本単位の書き出しの版だけを読む。L70.41 の切替を待つ理由がない | 三つの読者の版の要求（`rust_inputs` の版の表、`check_rust` の版、`interval_*.py` の `surfaceVersion`）と `batch4-exchange/corpus.json` を、固定入力の候補の該当の部分だけ本単位の追補として当て、W-R と `check_named.py` の Lean を呼ばない部分を通す。入口の文言を確かめる残りの候補は L70.41 に回す。当てない場合は、W-R の dry-run で方針の自己検査が選ばれることを確かめ、W-R を L70.41 の後へ移すことを detail.md の割り当てに書く | 失敗の理由は読めば確定。W-R が方針の自己検査を選ぶことは dry-run を実行しておらず、推定 |
| 軽1 | 軽 | C/l70/g/compare_exports.py の `normalize` の `version`・空の欄の枝 | `version` は1以外の全ての値を伏せる。旧→新の対応（15→16、7→8、4→8）以外の版の変化も隠す。空の `candidates`・`annotations`・`ranges` は位置を問わず除くので、誤った位置に補われた空の欄を検出しない（中2が検出されなかった原因）。意味のある違い（脱糖の結果・網羅性の判定・型の本体）を隠す枝は見当たらない | 版は旧→新の既知の対応だけを伏せ、空の欄は Lean の構造の位置（入力・定義・参照）に限って除く。群 G の台本を直すなら、L70.41 か F-REG の前の照合で使う | 読めば確定 |
| 軽2 | 軽 | results.md「取りまとめに判断を求める点」の4、報告の判断の3 | 旧版の複製 `<tmp>/old/`（2.5 GB）が一時領域にあると書く。本レビューの時点で、`<tmp>` には `new/`・`parts/`・`backup/` と記録だけがあり、`old/` はない。保存された集計と指紋（`compare-desugar.json`・`compare-desugar.files.json` の SHA-256）は残るので、照合の結果は引用できる。照合をやり直すには旧版の書き出しを作り直す必要がある | 取りまとめが消した経緯を確かめ、results.md の記述を現状に合わせる | 実行で確定（一覧） |
| 情1 | 情報 | 差分の全体、Lean の `Exchange/Syntax.lean`・`Builtins.lean`・`Version.lean` | 重点1と2の確認である。`crates/benitoite/src/` に差分はない。旧版の番号の書き出しを `grep` で探したが、`tests/` に残るのは無関係な derive の設定の版2の拒否の例（`declarations.rs:425`）だけである。`routing-manifest.json` の差は1,792行の版15→16だけである。補った欄はどれも Lean の構造の欄で、Lean の既定値と同じ値である（`variances` は `ntys` 個の `invariant`、ほかは空か null）。処理系に変性はなく（`src/` に variance の語がない）、不変の補いは現行の検査と合う。範囲パラメータは空で、`validateRanges` は宣言の外の `rvar` を断るので、空にしたことで実値を落としていれば Lean の読み込みが失敗したはずである。値を持つ四欄の欠落を誤りにする判断（止めずに進めた変更の1行目）と、メソッドの参照に `ranges` を補わない判断（2行目）は、Lean の `ClassEntry`・`Header` の検査と往復の一致に合う。Lean の変更は docstring 2箇所だけである | なし | 読めば確定 |
| 情2 | 情報 | C/l70/g42/compare-desugar.json・new-desugar-summary.json と群 G の old-desugar-summary.json | 重点3の確認である。脱糖側の照合は263ファイル、入力4,809、除外618、除外の理由212種、そのうち `external function` 34・`externalType` 48 である。網羅性側は3ファイルで、新旧のバイト数は同じ 60,687,255 である。新旧の要約の `counts`・`reasons`・`main_corpus` は一致する。主コーパスは `source_inputs` 1,792、`excluded_inputs` 419（書き出しは1,373）、`external function` 30 である。照合の台本の構造は、根の欄と配列の要素ごとに事象の列（種類・鍵・位置）の一致を要求し、正規化の後の値の一致を要求する。そのため、入力の省略と新しい除外は正規化を通っても検出される。作業木のパスの置き換え（`compare_relocated.py`）は `NoMainFile` の理由の文字列だけに効く | なし | 読めば確定（保存された集計） |
| 情3 | 情報 | `cargo test -p benitoite --test desugar_export --test coverage_export` | 重点5の確認である。本レビューで一回実行し、網羅性 3通過・1無視、脱糖 48通過・1無視で終了0、外側16.7秒であった。clippy・fmt・全コーパスの書き出しは記録（results.md「試験の結果」）を読んだだけで、実行していない | なし | 実行で確定 |
| 情4 | 情報 | L70.41 と F-REG の受け口（detail.md 第8.2節） | 重点6の確認である。新しい書き出しは、L70.41 が切り替える先の Lean の読者（`readCorpus`・`readBuiltins`・`operationProgram`・区間の `readCorpus`）を全て通っている。残るのは中1の値の欄の中身、中2の交換でない文書の読者、中3の版の要求である。また、`Version.sidecarVersion` の使わない引数と、旧版の読み方を述べるコメント（`Observe.lean`・`CheckInput.lean`・`DesugarDiff/Main.lean`）は報告の指摘どおり残る。これらは L70.41 の受け持ちのファイルであり、本単位で直さなかった判断は妥当である | L70.41 の依頼文に、中1〜中3の残りと報告の判断の点3を写す | 読めば確定 |

## 観点ごとの根拠

### 1. 処理系の本体

`git diff --stat` の21ファイルは、`crates/benitoite/tests/` の19ファイル、`formal/Benitoite/Exchange/Builtins.lean`、`scripts/check/test_policy.py` である。未追跡は C/l70/g42/ だけである。

### 2. 契約との照合

[群 G の交換の契約](../l70/g/exchange-contract.md)は、論理の証明書の位置と番号を定める文書である。欄の一覧は Lean の構造が正である。新しい版の欄は次のとおりである。

- `Header`: `tparamKinds`・`rangeParams`・`proofSteps`。
- `Definition`: `annotations`。
- `ClassEntry`: `argumentKind`。
- `DataTypeInfo`: `constructors`。
- `Input`: `candidates`・`aliases`・`records`・`testers`・`externals`・`logicCertificates`。
- `DataEntry`: `variances`・`requirements`・`publicBoundary`。
- `BuiltinInput`: `opaqueNames`。

これらは `exchange_fields` が補う欄、または書き出しの各所が書く欄と一致する。`validateSyntaxFields` は頭部・入力・型クラスを `exactFields` と往復の一致で検査し、区間の読者も欄の一覧と往復の一致で検査する。そのため、交換の文書に知らない欄があれば読み込みが失敗する。本単位の候補の段階で、メソッドの参照の `ranges` が12文書で断られた経緯（results.md）も、この検査が働いていることを示す。

論理の証明書は全て空であり、契約の位置と番号の規則は今回の書き出しでは使われない。

### 3. 件数と除外

情2のとおりである。外部型の48件は、4入力の12定義の重複を含む全ファイルの件数であり、results.md の表の注記と合う。

### 4. 正規化

中1・軽1のとおりである。脱糖の結果・網羅性の判定・型の本体に当たる欄を除く枝はない。範囲の実引数の戻し（`{"fixed": x}` → `x`）は、範囲の位置の形でない旧版の値と、新しい版の `fixed` だけの値を同じにする。`rvar` を持つ値はそのまま比べる。

### 5. 試験

情3と中3のとおりである。

### 6. 後段の受け口

情4のとおりである。

## 処置の確認

2026-11-07。対象は同じ作業木の追補の後の未コミットの差分、報告 `work/m014/L70.g42-claude-report.md` の追補の節、[L70.42 の結果](../l70/g42/results.md)の追補の節と、同じディレクトリの追補の台本（`compare_positions.py`・`check_value_fields.py`・`lean_kinds.py`・`interval_readers.py`・`prim_signatures.py`）と集計（`compare-positions.json`・`value-fields.json`・`lean-kinds.json`）である。処置の確認は一回である。

したことは、差分と台本の読解、集計の読み合わせ、次の三つの一回ずつの実行である。

- `cargo test -p benitoite --test desugar_export --test coverage_export`: 終了0。網羅性 3通過・1無視、脱糖 49通過・1無視。
- `cargo test -p benitoite --lib exchange_tests`: 終了0。4通過。
- `python3 -B -m unittest scripts.check.test_policy`: 終了0。32件。

`crates/benitoite/src/` に差分がないことも、もう一度確かめた。全コーパスの書き出し・照合の台本・Lean・`lake build`・`scripts/check.sh`・git の書き込み操作は行っていない。

**結論: 全ての所見の処置を可とする。** 新しい所見は軽1件（下の追1）で、処置を止める条件ではない。

| 所見 | 判定 | 根拠 |
|---|---|---|
| 中1 | 可 | `check_value_fields.py` は、値を持つ四欄を、旧版から変わらない欄と処理系の登録表から導いた値と照らす。照らす相手は次のとおりで、どれも意味のある照合である。<br>- `tparamKinds`: 頭部の型の中の `tapp` の実引数の数と、辞書の制約の型クラスの種類。適用された型パラメータが値の種類なら誤りになる。<br>- `argumentKind`: メソッドの頭部での引数の適用と、実装の対象の頭の型引数の数。<br>- `opaqueNames`: `BUILTIN_TYPES` の原文の公開名・型引数の数・分類と、出現の集合の過不足。<br>- `constructors`: 同じ入力の表の `dataDecls`。書き出しの `attach_metadata` 自身もこれを写すので、写しの正しさの確認である。`dataDecls` が旧版と一致することは、位置の照合が別に確かめている。<br>誤りは0件で、構成子の種類2,122件（頭部）と1,646件（型クラス）は全て導けた（`value-fields.json`）。`lean_kinds.py` は、Validate.lean の記録の行から、Lean が表層へ変換した後の種類の数と型引数の数の和を58文書ごとに取り、同じ文書の JSON と照らして全て一致させている。これは Lean が読んだ値と JSON の値が一致することの裏付けになる。ただし文書ごとの合計の一致であり、項目ごとの一致ではない。results.md の結論は「位置と中身を確かめた」に改められた。`constructors`・`opaqueNames` の Lean の側の読み取りを照らしていないことと、`CanonicalNames.ofInputs` に読者がないことも明記された。確かめた範囲に合う。壊した入力での感度の確認は、本文の記述だけで、入力と出力の記録がない（追1） |
| 中2 | 可 | `ExchangeJson` は文書の種類（`Document`）を持つ。補う規則は種類ごとに決まり、`Record` には補わない。`exchange_fields_follow_the_document_kind` の試験が、種類ごとの補う欄の集合を固定する。位置の照合では、交換でない30文書に新しい欄が一つもなく、新旧で一致した（`compare-positions.json` の `kinds.record` 30）。material・manifest・対応表・VM の地点の4種（照合の `fragments` 26文書）に、頭部の欄と関数の参照の `ranges` を補う理由は妥当である。読者は material から区間の交換を作って比較器へ渡し、ほかの三つの式を material の式と照らす。実際に `interval_vm_compare.py` は、関数の参照の形として `ranges=[]` を要求するように直されている。`interval_readers.py` で比較器の読者を全コーパスに当て、終了0、`intervalDiff` の呼び出しは1,707回であった（記録を読んだ）。`fragments` に補われたのは参照の欄だけで、頭部の欄の出現はなかった（`newFields`） |
| 中3 | 可 | 版に依存する読者は全て16/8に直された。`test_batch2_exchange.py` の `check_rust`、`test_batch3_exchange.py` の `rust_inputs`（版16だけを受ける）、`interval_*.py` の `surfaceVersion`、`interval_vm_compare.py` の参照の形である。`batch4-exchange` の6ファイルに候補を当てたこととあわせ、方針の自己検査32件の通過を本確認で実行して確かめた。入口の文言に依存する残りの候補は当てていない。L70.41 に回すという初回の勧めに合う |
| 軽1 | 可 | `compare_positions.py` は二つを改めた。版は根の版の欄だけを、種類ごとの旧→新の既知の対応に限って許す。根より下の `version` は完全な一致の照合に入る。新しい欄は `new_only` で、文書の種類と構造の位置（例 `("inputs","*")`・`…/header`・関数の参照の欄名）ごとに許す欄と中身を決めている。それ以外の位置に新しい欄があれば `unexpected new field` で止まる。交換でない文書は全て完全な一致の照合になる。そのため、初回に検出できなかった誤った位置の欄（中2の例）は検出できる。深い位置は最後の欄名（`header`・`funName` など）だけで見分けるので、同じ名の欄が別の構造に現れれば許してしまう。ただし、その欄の中身も空・null・個数で確かめるので、軽微と判断した。照合から外した3文書（`scope-tables-*`）は、意図した変更として指紋が記録されている |
| 軽2 | 可 | 取りまとめが消したことが results.md に記録された。旧版の書き出しは基準版の木から作り直され、群 G の基準の指紋と260ファイルが一致した。残りの3ファイルは作業木のパスの長さの差であることも記録されている |
| 追加: `Scope.ScopeError` | 可 | 出どころの調べは筋が通っている。標準の宣言（`prelude/stdlib/Scope.bnt` の `public data ScopeError`、`checkPathIn(...) -> Result[PathIn, ScopeError]`）を確かめ、処理系の書き出しで data として書けていることを確かめている。`prim_signatures.py` は、全ての組込み117,792件の署名を写して比べ、data 型を不透明型で書いた出現が0件であることを示した。食い違いは、試験の合成の署名 `scope_tables` の2箇所と、`formal/tests/test_range_exchange.py` の手書きの独立入力だけである。修正は合成の data の宣言（`BindingId(1005)`）を足して data で書く形であり、処理系の本体を変えていない。手書きの独立入力を直すかどうかは、群 G の本体の担当への申し送りとして記録されており、妥当である |
| 追加: lib 試験 | 可 | `typed_try_exchange_matches_independent_corpus_ten` の変更は、固定入力の側に版16の既定の値を補うだけである。補う値は、値の種類・範囲パラメータなし・証明探索の上限なし・関数の参照の空の範囲の列である。補う前に、固定入力がその欄を持たないことを `assert!` で確かめる。現在の出力との完全な一致の比較は残る。書き出しが構成子の種類や空でない範囲の列を出せば失敗するので、試験を弱めていない。本確認でも通過を確かめた |

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 追1 | 軽 | results.md「値を持つ四欄の中身」の「照合の感度は、壊した入力で確かめた」 | 壊した入力（5種）と、それぞれの誤りの出力が、台本にも記録にも残っていない。感度の主張を再現できない | 壊し方と報告された誤りの1行ずつを results.md に書く。又は、壊した入力を作って誤りを確かめる自己検査を `check_value_fields.py` に加える | 読めば確定 |

## 取りまとめの追記

- 2026-11-07: 処置の確認は可。追1（4欄を壊した入力での感度の確認が再現できない）は、`l70/g42/results.md` に、その確認が一度きりの手での確認であり、壊した入力と出力は残っていないことを注として書いた。群 G の作業末の照合の台本に感度の自己検査を加えるかは、段末の見直しで判断する。
