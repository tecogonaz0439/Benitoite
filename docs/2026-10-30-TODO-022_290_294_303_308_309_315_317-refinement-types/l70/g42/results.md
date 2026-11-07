# 群 G の L70.42 の実装結果（処理系の試験の側の書き出し）

作業木は L70.42 専用の worktree、ブランチは `m014/l70.g42`、基準は `eb4f0ef9b4a95e92d09d194d88d8eb38f7024c4f`（群 G の途中の保存）である。git の書き込み操作はしていない。群 G の残り（L70.40b・.41・.44・.45）は、別の担当が別の作業木で行う。`<tmp>` はリポジトリの外の一時領域を表す。

本書は初回の結果に、独立レビュー [RV-L70.g42](../../reviews/RV-L70.g42.md) の処置と、取りまとめが足した `Scope.ScopeError` の照合を追補して改めたものである。初回の照合は版の番号と空の欄をどこでも伏せていた。その照合とその記録は、下の「新旧の照合」に置き換えた。

## 時刻

時刻は JST、所要は待ちを含む外側の時間である。

| 区間 | 開始 | 終了 | 所要 |
|---|---|---|---|
| 初回（資料読みから報告まで） | 2026-11-07 07:15:42 | 10:00 | 2時間44分（取りまとめによる一時停止 約50分を含む） |
| 　全コーパスの書き出し（初回） | 07:31:31 | 07:58:38 | 27分07秒 |
| 追補（レビューの処置と `ScopeError` の照合） | 10:03:09 | 11:20 | 約1時間17分 |
| 　旧版の書き出しの作り直し（基準版の木） | 10:12:24 | 10:46:13 | 33分49秒（新しい版の書き出しと並行） |
| 　全コーパスの書き出し（追補の後。1回は直す前に止めて起動し直した） | 10:25:28 | 10:56:15 | 30分47秒（`real` 1846.63秒、主コーパス 1826.254秒） |
| 　区間の比較器の読者（全コーパスの書き出し） | 10:58:46 | 11:08:37 | 9分51秒 |
| 　Lean の読者での全件の読み込み（分割を含む） | 10:57 | 11:11 | 分割約5分、読み込み 403.29秒 |
| 　位置を限った新旧の照合（6並列） | 11:08:12 | 11:10:32 | 2分20秒 |

## 変えたもの

### 書き出し（Rust の試験）

交換の新しい版はコーパス16・付随の表8である（[群 G の交換の契約](../g/exchange-contract.md)と、Lean の `Exchange.Syntax`・`Exchange.Builtins`・`Exchange.Version`）。旧版の番号（コーパス15・表7・独立の網羅性4と7）の書き出しは残していない。

- 版の番号: `desugar_export.rs`・`coverage_export.rs` と `desugar_export/` の全ての書き出しを 16/8 に改めた。独立の網羅性も、Lean の `exchangeJson "coverage"` が要求する 8 で書く。区間の交換の `surfaceVersion` は 16 である。
- 直列化の補助（`desugar_export/exchange.rs` の `ExchangeJson`）: 書き出しの各所が、文書の種類（`Document`）を名指しして書く。補う欄は、文書の種類ごとに Lean の構造の位置で決める（追補でレビューの中2に従って改めた）。
  - コーパス: 入力の `aliases`・`records`・`testers`・`externals`・`logicCertificates`・`candidates`、定義の `annotations`、頭部の `rangeParams`・`proofSteps`、関数の参照（`funName`・`funDicts`・`fnRef`）の `ranges` を補う。組込みの参照（`prim`・`primName`）の範囲の実引数は、範囲の位置（`{"fixed": …}`）の形で書く。
  - 組込みの表: data の宣言の `variances`（不変）・`requirements`・`publicBoundary` を補う。
  - stdlib: 頭部の欄を補う。
  - 網羅性: 何も補わない。
  - 区間の交換と、その式の断片を持つ文書: 頭部と参照の欄だけを補う。対象は `interval-manifest-corpus`・`reader-corpus`・`point`・material・manifest・対応表・VM の地点である。理由は下の「止めずに進めた変更」の2行目に書く。
  - 交換でない文書（`Record`）: 数の書き方だけを揃え、欄を補わない。対象は区間の要約・観測、範囲の束縛、範囲の予算と範囲の出どころの記録である。
  - 補う規則の集合は、試験 `exchange_fields_follow_the_document_kind` が文書の種類ごとに固定する。
- 処理系が値を持つ欄は補わず、書き出しの各所が書く。欠けた文書は、直列化の補助が誤りとして書き出しを止める。
  - 型パラメータの種類（`tparamKinds`）: `header` と `export_prim` が `ParamKind` の実値を書く。
  - 型クラスの引数の種類（`argumentKind`）。
  - data の型の構成子の対応（`constructors`）: `attach_metadata` が `dataDecls` の構成子から書く。
  - 不透明型の公開名（`opaqueNames`）: `builtins.rs` の `collect_opaque_names` が書く。
- 手で書いた表と独立の期待値:
  - t1 の表に表のデータの欄を足した。
  - `scope_tables` の表は `opaqueNames` を書く。
  - `scope-tables-expected.json` に、`tparamKinds` と data の型の `constructors` を足した。
  - 追補で `scope_tables` の合成の署名を直した（下の「`Scope.ScopeError` の照合」）。
- 照合の補助と固定記録: 次の版の要求を 16/8 にした。件数・除外・範囲の欄は変えていない。
  - `check_named.py`・`check_batch3.py`。範囲の実引数の数え方を範囲の位置の形に合わせ、旧版の期待値を版15へ移す `explicit_top_ranges` を除いた。
  - `exchange-manifest.json`・`routing-manifest.json`（1,792入力）・`batch3/manifest.json`・`interval/prepare-range.py`。
- 本体の lib 試験が取り込む `desugar_export/lib.rs` の `typed_try_exchange_matches_independent_corpus_ten` は、corpus 10 の固定入力と照らす。追補でその読み方を改め、固定入力を版16の空の欄と既定の値（値の種類・範囲パラメータなし・関数の参照の空の範囲の列）で読む。
  - 初回は `cargo test --lib` を実行しておらず、この試験が新しい書き出しで失敗することを見落としていた。追補で見つけて直した。

処理系の本体（`crates/benitoite/src/`）は変えていない。

### 版に依存する `formal/tests` の読者（追補。レビューの中3）

Rust の書き出しの版だけを読み、Lean の入口の文言に依存しないものを直した。

- `test_batch2_exchange.py`: `check_rust` と、その版の拒否の試験の版を 16/8 にした。
- `test_batch3_exchange.py`: `rust_inputs` と、その対応の試験の版を 16/8 にした。
- `interval_range_vm.py`・`interval_shift_vm.py`・`interval_source_compare.py`・`interval_vm_compare.py`: `surfaceVersion` を 16 にした。
- `interval_vm_compare.py`: 対応の式の頭を `ranges` 付きで照らす2箇所を、関数の参照も範囲の列を持つ形に合わせた（固定入力の候補と同じ形）。
- `batch4-exchange/` の固定入力6ファイル: 固定入力の候補をそのまま当てた（`README.md` は当てていない）。`check_batch3.py` の `check_builder_sources` が、この期待コアを新しい書き出しと照らすためである。
  - `manifest.json` の指紋5件は、当てたファイルと一致する。
  - [Validate.lean](Validate.lean) で5文書を読めた。
- Lean の入口の文言を確かめる残りの固定入力の候補は、当てていない（L70.41 の後に群 G の本体の担当が当てる）。

方針の自己検査 `scripts/check/test_policy.py` は、batch3 の照合の偽の入力の版を 16/8 にした。

### Lean

旧版の読み分け（`Exchange/Version.lean` の版8〜15・2〜7）は、群 G の L70.40a が既に除いていた。現在の `exchangeJson` はコーパス16・表8だけを受け、ほかを `unsupported … exchange version` で断る。区間の交換は、`Refined.corpusVersion`（16）でない `surfaceVersion` を断る。

この単位で変えた Lean は、`Exchange/Builtins.lean` の docstring 2箇所だけである。旧版を空の表で読むという、現在は成り立たない記述を除いた。`lake env lean -M 12288 Benitoite/Exchange/Builtins.lean` で終了0であった。

## 既存コーパスの書き出し

`cargo test -p benitoite --test desugar_export --test coverage_export -- --include-ignored --nocapture` を、旧版の基準と同じく `BENITOITE_DESUGAR_DIFF_DIR`・`BENITOITE_COVERAGE_DIFF_DIR` を作業木の生成物の下に指定して実行した。終了0であった（網羅性 4試験、脱糖 50試験）。合成の署名の修正（下の「`Scope.ScopeError` の照合」）は、全コーパスの書き出しの起動の後に入れた。そのため、`export_scope_tables_smoke` だけを同じ出力先へ書き出し直した。

生の書き出しは `<tmp>/new/` に移した。記録は `<tmp>/full-export2.log`（5,276バイト、SHA-256 `ba4dd3a7d9be78475317a033ab598d2806c06c38433735f244bda40628809b72`）である。

| 対象 | 旧版（群 G の基準） | 新しい版 |
|---|---|---|
| 脱糖側の全生成 JSON | 263ファイル、2,693,127,889バイト | 263ファイル、2,721,772,209バイト（+28,644,320、+1.06%） |
| 脱糖の主コーパス | 1,792入力、1,373書き出し、0範囲外、419検査上の除外 | 同じ |
| 外部関数によるプログラム全体の除外 | 主コーパス30入力（全ファイルで34）、理由 `external function` | 同じ |
| 区間交換の外部型による除外 | 理由 `externalType` の48件（4入力の12定義の重複を含む全ファイルの件数） | 同じ |
| 独立した網羅性の生成 JSON | 3ファイル、60,687,255バイト、20,058 cases | 同じ |
| 所要（外側） | 1477.325秒 | 1846.63秒（旧版の作り直しと並行） |

新しい書き出しの要約は [new-desugar-summary.json](new-desugar-summary.json)（群 G の `summarize_exports.py` の出力。10,864バイト、SHA-256 `51d45fc053808799563085563eab291d30683eb493f751c52cabd24ed906b3b1`）である。旧版の要約（[old-desugar-summary.json](../g/old-desugar-summary.json)）との比較の結果は次のとおりである。

- 除外の理由（`reasons`、205種）と主コーパスの件数・理由は一致した。
- 件数（`counts`）の差は、`root_dataDecls`・`root_dataTypes`・`root_summaries` の4→5だけである。合成の署名の期待値 `scope-tables-expected.json` に data の宣言を一つ足したためである。

### 固定記録の照合

[routing.py](routing.py) は、`check_named.py` の固定記録の照合のうち Lean の入口を呼ばない部分を、新しい書き出しに当てる。終了0であった。

- 1,792入力の識別・除外・定義の範囲・網羅性の件数が、`routing-manifest.json`（版の番号だけを16に改めたもの）と一致した。
- 主コーパスの419入力の除外の理由が一致した。定義73,853・表層の検査51,762・網羅性の項目22,483も `programReports` と一致した。
- 独立の網羅性・名前付きの9入力・幅の3入力の件数も一致した。

### Lean の読者での読み込み

[Validate.lean](Validate.lean) は、書き出した文書を交換の版16/8の Lean の読者で読み、表層への変換まで行う。種類ごとの処理は次のとおりである。

- コーパス: `readCorpus`（版・欄の完全性・往復の一致・整数・範囲・view の検査を含む）で読む。除外でない入力ごとに `operationProgram`・`constantCache` を作り、範囲内の定義ごとに `SurfaceDef.toSurface` で表層へ変換する。
- 組込みの表: `readBuiltins` で読む。builtinCheck と同じく、不透明型の引数と型クラスの制約を持つ項目は、印の一致だけを見る。それ以外の項目と data の宣言は材料にする。
- stdlib: `exchangeJson "stdlib"` と入口の構造で、往復の一致を確かめる。
- 網羅性: `exchangeJson` と入口の構造で読む。
- 区間の交換: `Interval.Exchange.readCorpus` で読む。

[prepare.py](prepare.py) は、40 MB を超える文書を入力の列で分ける。分けた入力の件数の和は元と照合した。

全229文書を読めた（終了0、403.29秒、最大常駐 2.48 GB）。記録は `<tmp>/validate-full2.log`（25,167バイト、SHA-256 `b13e8a73e56f997956bbc8645fecdaeb19ee2214c6956b463b7982aa8e0da1cd`）である。種類ごとの文書数と件数は次のとおりである。

| 種類 | 文書 | 件数 |
|---|---:|---|
| コーパス | 58 | 範囲内の定義 62,263 |
| 組込みの表 | 50 | 材料にした項目 117,763 |
| stdlib | 47 | 関数 1,454 |
| プログラムの網羅性 | 40 | 照合と束縛 22,566 |
| 独立の網羅性 | 12 | cases 20,067 |
| 区間の交換 | 22 | 入力 1,656 |

交換の文書の種類に当たらない文書（区間の manifest・material・観測・要約、試験の期待値・記録）は、Lean の読者では読まない。これらは下の「区間の比較器の読者」と「新旧の照合」で確かめた。

### 新旧の照合（追補。レビューの中1・軽1）

旧版の書き出しは、取りまとめが一時領域の複製（`<tmp>/old/`）を消したので、作り直した（レビューの軽2）。作り直しには、基準版（`eb4f0ef9`）の木を `git archive` で一時領域へ展開し、同じ試験を実行した。

- 群 G の基準の263ファイルの指紋（`old-desugar-files.json`）と比べると、260ファイルが一致した。
- 残る3ファイル（主コーパス・区間の manifest・区間の要約）の差は、`NoMainFile` の理由の作業木のパスの長さだけである（+9バイト）。

[compare_positions.py](compare_positions.py) は、群 G の `compare_exports.py` の正規化に代えて、新しい欄を交換の構造の位置だけで許す照合である。

- 判定の単位: 新旧の全ファイルを、JSON の構造の列（根の欄・入力ごとの事象）で比べる。
- 新しい書き出しにだけある欄: 文書の種類と構造の位置で決めた欄だけを許し、その中身も確かめる（空・null・不変の変性・個数）。
- 範囲の実引数: 組込みの参照の位置でだけ、`{"fixed": …}` を旧版の形に戻す。
- 版の番号: 根の版の欄だけを、旧→新の既知の対応（コーパス 15→16、表・stdlib・プログラムの網羅性 7→8、独立の網羅性 4→8・7→8、区間の `surfaceVersion` 15→16）に限って許す。
- 交換でない文書: 作業木と出力先のパスのほかは完全な一致を要求する。
- 照合から外した文書: 意図して変えた合成の署名の3文書（`scope-tables-*`）は、大きさと指紋だけを記した。

照合は終了0であった。要約は [compare-positions.json](compare-positions.json)（8,187バイト、SHA-256 `0588185c825a04eb51c1f1d95fa9303da4fe4eb227208307bced5aa568ebfca5`）で、ファイルごとの一覧は `<tmp>/compare-positions.files.json`（125,093バイト、SHA-256 `6087804e89062ea2113c16e9f06d171aed034bd0c109eb5513cf4f9ca759047b`）にある。

- 対象: 263ファイル。内訳はコーパス48、組込みの表47、stdlib 47、プログラムの網羅性40、独立の網羅性12、区間の交換13、区間の断片26、交換でない文書30である。
- 件数: 入力4,808、除外618（理由212種）、外部関数34、外部型48 が新旧で同じである。入力の件数は、照合から外した合成の1入力を除く。
- 交換でない文書30: 新しい欄が一つもなく、一致した。
- 新しい欄の出現: 種類と位置ごとの件数は要約の `newFields` にある。例えば、コーパスの頭部の `tparamKinds` が149,255件、data の型の `constructors` が76,373件である。

### 値を持つ四欄の中身（追補。レビューの中1）

[check_value_fields.py](check_value_fields.py) は、四欄の中身を照らす。照らす相手は、旧版から変わらないことを上の照合で確かめた欄（型・辞書の制約・実装の対象・組込みの表の data の宣言）と、処理系の組込みの型の登録表（`crates/benitoite/src/types/builtin.rs` の `BUILTIN_TYPES` の原文）である。終了0で、誤り0件であった（[value-fields.json](value-fields.json)）。

| 欄 | 照らした値 | 件数 |
|---|---|---|
| `tparamKinds` | 頭部の型の中の `tapp`（実引数の数）と辞書の制約の型クラスの種類から導いた種類 | 頭部256,368（値の種類112,900）。構成子の種類2,122件は全て導けた |
| `argumentKind` | メソッドの頭部での型クラスの引数の適用の実引数の数と、実装の対象（型構成子の頭の型引数の数） | 型クラス8,435（構成子の種類1,646は全て導けた）、構成子の型クラスの実装2,056 |
| `constructors` | 同じ入力の組込みの表の data の宣言の構成子（`name`・`constructorName`） | data の型76,378、構成子157,889 |
| `opaqueNames` | 登録表の番号ごとの公開名・型引数の数・分類（不透明型又は資源）。対応の過不足もない（表とコーパスに現れる不透明型の集合と一致） | 14,138 |

照合の感度は、壊した入力で確かめた。型クラスの種類、頭部の種類、構成子の順序、不透明型の公開名、不透明型の対応の欠落を一つずつ壊した入力で、それぞれ誤りを報告した。

旧版の欄と登録表から導けない値はなかった。Lean の読者がこれらの値を読んだ結果も照らした。

- [lean_kinds.py](lean_kinds.py) は、Validate.lean が `SurfaceDef.toSurface` の後の表層の型パラメータの種類と、読者が読んだ型クラスの引数の種類から数えた構成子の種類を、JSON の値と58のコーパスの文書ごとに照らす。全て一致した（[lean-kinds.json](lean-kinds.json)。表層の構成子の種類の型パラメータ1,021件・型引数の数の和1,039、構成子の種類の型クラス1,646件・型引数の数の和1,889）。
- `constructors` と `opaqueNames` を読む Lean の関数は `Exchange.CanonicalNames.ofInputs` だけである。これは群 G が採らない経路（標準名への写し）のためのもので、既定のビルドに読者がない。そのため、この二欄の Lean の側の読み取りは照らしていない。`ofInputs` を消すかどうかは、群 G の本体の担当の受け持ちである（下の申し送り）。

### 区間の比較器の読者（追補。レビューの中2）

[interval_readers.py](interval_readers.py) は、`formal/tests/test_interval_exchange.py` の `exercise` のうち、Rust の書き出しを読む部分を全コーパスの書き出しに当てる。

- 当てた部分: VM の比較（地点・範囲・シフト）、実ソースの対応（`exercise_source`）、10の書き出しのディレクトリの実ソースの全解析の比較（`interval_source_compare.exercise`）。
- 当てなかった部分: 固定入力の比較（`fixtures`）。
- 実行: 区間の比較器（`intervalDiff`）と処理系の CLI を使う。

全て終了0であった（9分51秒、区間の比較器の呼び出し1,707回）。記録は `<tmp>/readers-full.log`（1,143バイト、SHA-256 `8f140f88bb935cea324966caafd8474f2d8a3719bda0a6b49c422dd9c428e154`）である。これらの読者は、material から区間の交換の入力を作って比較器へ渡し、manifest の対応・対応表・VM の地点の式を material の式と照らす。そのため、四つの文書は区間の交換と同じ形で書く必要がある（下の「止めずに進めた変更」）。短い試験の書き出しにも、同じ読者を当てて通ることを確かめた。

### `Scope.ScopeError` の照合（追補。取りまとめの依頼）

原因:

- 処理系の書き出しでは、`Scope.checkPathIn` の結果型の誤りの側は data として書けている。全ての実際の組込みの表（9文書）で、`Result[PathIn, ScopeError]` である（`ScopeError` は data の宣言）。
- `opaque "102:[]"` は、`formal/tests/test_range_exchange.py` の手書きの独立入力にある。`SCOPE_ERROR_T = "102:[]"` を `opaque` として置いており、固定入力の候補の `add_table_metadata.py` が、その公開名を `Scope.ScopeError` と書いた。処理系の書き出しの経路ではない。
- `builtins/table.rs` は、`checkPathIn` の範囲の位置（`RangePosition::ReturnArgument(0)` と `PATH_IN`）だけを持つ。型の署名は、標準ライブラリの宣言（`Scope.bnt` の `checkPathIn(...) -> Result[PathIn, ScopeError]`）から来る。不透明型の番号で型を持っている箇所はない。

同じ種類の食い違いを、全コーパスの書き出しで数えた（[prim_signatures.py](prim_signatures.py)、[prim-signatures.json](prim-signatures.json)）。

- 方法: 全ての組込みの表の1,455入力の組込み117,792件について、data の型を宣言の型の名前へ、不透明型を公開名へ写した。そのうえで、同じ名前の組込みの署名を比べた。
- data 型として宣言された型を不透明型として書いた出現は0件、名前を写せない data と不透明型の出現も0件であった。
- 署名が分かれた組込みは、`Scope.checkPathIn`・`Http.checkRequestIn` の2つだけである。どちらも、試験の側の合成の署名 `scope_tables` の `fixtures()` から来る。
  - `checkPathIn` の誤りの側を、IOError（不透明型16）で書いていた。
  - 合成の data の宣言 `RequestCheckError.Scope` の実引数も、IOError で書いていた。
- 直したこと: 合成の data の宣言 `data:1005`（`ScopeError`。標準と同じ6構成子）を足し、二箇所を data で書くようにした（`scope_tables.rs` と `scope-tables-expected.json`）。直した後に残る違いは、合成の表の data の宣言の型の名前（`data:1001` などの仮の名前）だけで、形（data か不透明型か）は実際の表と同じである。
- 処理系の本体は変えていない。`formal/tests/test_range_exchange.py` の独立入力は、群 G の本体の担当の受け持ちとして申し送る。

## 試験の結果（追補の後）

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --test desugar_export --test coverage_export` | 終了0。網羅性 3通過・1無視、脱糖 49通過・1無視 |
| 同 `-- --include-ignored --nocapture`（全コーパス） | 終了0。上の表 |
| `cargo test -p benitoite --lib exchange_tests` | 終了0（4通過）。初回は1件失敗していたのを直した |
| `cargo clippy -p benitoite --tests` | 終了0、警告0 |
| `cargo fmt --check` | 終了0 |
| `python3 -B -m unittest scripts.check.test_policy` | 終了0（32件） |
| `lake env lean -M 12288 Benitoite/Exchange/Builtins.lean` | 終了0、警告0（初回） |
| 既定の `lake build`（共有ロック下、初回 08:17:40〜08:17:53） | 終了1。失敗は作業の開始前と同じ5箇所（`Exchange.CheckInput` と入口4つ。L70.40b・.41 の未移植）だけである。追補では Lean を変えていないので、やり直していない |

`scripts/check.sh` と `scripts/check-formal.sh` の全体は実行していない。check-formal.sh の台本は変えていない。

## 止めずに進めた変更

型付けの規則・Step の規則・前段の固定署名・公開の関数の契約に関わる変更はない。書き出しの形式の決め方を記す。

| 理由・反例 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|
| 候補の直列化の補助は、値を持つ四欄も既定の値で補っていた。書き忘れが黙って交換される | 処理系が持たない機能の欄だけを補い、値を持つ欄が欠けたら書き出しを誤りで止める | 既定の値で補う | 型パラメータ・不透明型・構成子のない文書は、空の列で同じ交換になる |
| 欄の組だけで欄を補うと、交換でない文書（区間の要約・範囲の束縛など）にも欄が入る（レビューの中2）。一方で、区間の比較器は material から区間の交換の入力を作り、manifest の対応・対応表・VM の地点の式を material の式と照らす（`interval_range_vm.py` の末尾の照合、`interval_vm_compare.py` の地点の照合） | 文書の種類を書き出しの各所で名指しし、種類ごとに補う位置を決める。区間の式の断片を持つ4種の文書は、区間の交換と同じく頭部と参照の欄だけを補う。要約・観測・束縛・記録は補わない | 依頼の例示どおり material・対応表・VM の地点にも補わない案。比較器が作る区間の交換が Lean の読者に断られ、対応の照合も一致しなくなる | 範囲のない参照は空の列で、旧版の参照と同じ |
| 候補の補助はメソッドの参照にも範囲の実引数を補い、Lean の読者が往復の一致で断った | `dict` を持つメソッドの参照を除く | 補う構成子を名前で列挙する | 関数と組込みの参照は空の列で、元の参照と同じ |
| 独立の網羅性は旧版4（batch5 は7）、プログラムの網羅性は旧版7であった。新しい Lean の `exchangeJson` はコーパス以外の全ての種類に8を要求する | 独立の網羅性も8で書く。欄の構成は変えない | 別の版の番号を残す | 欄の内容は旧版と同じ |
| 試験の合成の署名が、標準の data 型 `ScopeError` を IOError（不透明型）で代用していた | 合成の data の宣言を足し、data として書く | 合成のまま残す | 不透明型の範囲の位置と効果の欄は変わらない |

## F-REG と後段への申し送り

- 四欄の値は、上の「値を持つ四欄の中身」で確かめた範囲（旧版の欄と登録表から導ける値の一致）を越えない。新しい7入口が受理するかは L70.41 と F-REG で確かめる。対象は、構成子の種類の型パラメータを持つ入力（表層の1,021件）と、構成子の種類の型クラスの実装（2,056件）である。
- `Exchange.CanonicalNames.ofInputs` は、群 G が採らない経路（標準名への写し）のためのもので、既定のビルドに読者がない。消すのは群 G の本体の担当の受け持ちである。
- `formal/tests/test_range_exchange.py` の独立入力は、`Scope.ScopeError` を `opaque "102:[]"` として置いている。標準の宣言（data）に合わせるかは、群 G の本体の担当が固定入力の候補を当てるときに決める。
- Lean の入口の文言を確かめる `formal/tests` の固定入力の候補（`batch4-exchange` の JSON と、上の版の読者を除く分）は当てていない。L70.41 の後に群 G の本体の担当が当てる。`batch4-exchange/README.md` の版の記述も同じである。
- `Exchange/Version.lean` の `sidecarVersion (_corpusVersion : Nat)` は、使わない引数を持つ旧版の名残である。入口が呼ぶので変えていない。旧版の読み方を述べるコメントも、`Exchange/Observe.lean`・`Exchange/CheckInput.lean`・`DesugarDiff/Main.lean` に残る（L70.41 の受け持ち）。
- 一時領域の生の書き出しは、新しい版の書き出し `<tmp>/new/`（2.6 GB）、作り直した旧版の書き出し `<tmp>/old/`（2.6 GB）、分割 `<tmp>/parts/`（839 MB）である。初回の旧版の複製は、取りまとめが初回の報告の後に消した。F-REG で使わないなら消してよい。

## 取りまとめの注（処置の確認の追1）

値を持つ4欄の照合の感度（4欄を一つずつ壊した入力で照合が失敗すること）は、担当が一度だけ手で確かめたもので、壊した入力と照合の出力は残していない。再現できる自己検査ではない。
