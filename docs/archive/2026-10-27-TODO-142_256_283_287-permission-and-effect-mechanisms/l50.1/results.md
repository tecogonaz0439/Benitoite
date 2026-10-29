# L50.1 の結果: 交換の形式の版と署名・表の交換

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L50.1（plan-l10-l50「L50」の表の L50.1 の行）。取りまとめの追加の依頼（RV-L40 軽6: 候補に検査器の原子の集合 `q.atoms` を渡し、`AtomsIn q.atoms` から欠落がないことを示す）を含む |
| B_WORK | `ce6d22ff7b9ae827ac564147f5a9e68926fdfefe`（L40.6 の取り込みの後） |
| 閉じた範囲 | 依頼の 1〜6 の全て。形式の版 corpus 15・sidecar 7、範囲・範囲の位置・範囲付きの原子と不透明型・項 `.prim` と表層 `primName` の範囲の列・署名の `rkinds` と `shape`・表のデータ `effKind`・`valKind`・`admitsR`・`valContent` の読み書き、旧版の明示の Top での読み込み、交換の原子の一覧の作り方、候補 `q.atoms` での欠落なしの定理、07-04 の反映 |
| 未完 | なし（計画の行の範囲で）。ただし formal/tests の Python の独立交換の検査の二つが新しい版に合わない（「ずれと申し送り」2）。編集してよい範囲の外なので直していない |

## 変更と接続

### 形式の版と変えた読み書き

| 項目 | 新版（corpus 15・sidecar 7） | 旧版（corpus 8〜14・sidecar 2〜6） |
|---|---|---|
| 名前の原子 | `{"name":{"value":l,"ix":I}}`。I は `{"fixed":R}` か `{"rvar":i}` | `{"name":{"value":l}}` に明示の Top `{"fixed":"top"}` を加えてから読む |
| 不透明型 | `{"opaque":{"name":o,"ix":I}}` | 明示の Top を加えてから読む |
| 範囲 R | `"top"`、`{"path":{"exact"\|"tree":語}}`、`{"host":{"name":{"exact"\|"one"\|"many":語}}}`、`{"host":{"ip":{"exact":A}\|{"cidr":C}}}`、`{"endpoint":{"host":…,"ports":{"lo":n,"hi":n}}}`。A は `{"family":"v4"\|"v6","bits":n}`、C はそれに `network`・`prefixLen` | （なし） |
| 項 `prim`・表層 `primName` | 欄 `ranges`（範囲の列）を必須 | 空の列を加えてから読む |
| 型表の項目 | `rkinds`（種類の列）と `shape`（`"untargeted"`・`{"topTargeted":{"kind":k}}`・`{"single":{"kind":k,"position":p}}`）を必須 | `rkinds: []`・`shape: "untargeted"` を加える |
| 型表の入力 | `effKinds`・`valKinds`（名前と種類）、`admitsR`（名前と規則 `"any"`・`{"covers":{"inner":i,"outer":j}}`）、`valContents`（名前と要求の型の名前）を必須 | 空の表を加える（`Builtins` の既定の値） |
| 範囲の変数 `rvar` | 型表の署名にだけ置ける。corpus・stdlib・coverage・coverage-program では拒否 | 範囲の欄は全て拒否 |

新版の欄の欠落は誤りにし、Top で補わない。範囲・範囲の位置・形・規則の余りの欄は、書き戻した形と比べて拒否する。アドレス族の幅を超える値と 65535 を超えるポートは誤りにする。旧版は先に範囲の欄（`ix`・`ranges`・`rkinds`・`shape`・`effKinds`・`valKinds`・`admitsR`・`valContents`）を拒否し、それから明示の Top を加える。明示の Top を加える処理は、型を読む検査（`validateBatch2` など）より前に置いた。

書き出しの変更:

- `fromTy` は範囲付きの不透明型を拒否せず、範囲の位置を書く。
- `fromVal` の `.prim` の腕は、L40.5 が置いた `rs ≠ []` の `throw` を、範囲の列の書き出しに置き換えた。
- `fromEff` は名前と行の原子を全域の `fromEffNames`（候補の検査と `writeAtoms`）で書き、Fail の列を続ける。原子の並べ方（原子の符号の順・重複なし）は変えていない。
- `Expr.toSurface` は表層の `primName` の範囲の列を写す（L40.4 が置いた空の列の中間状態を終えた）。
- 検査済みの対象の値（`Val.checked`）と検査済みの要求の値（`Val.checkedRequest`）は交換の形式に現れない。書き出しは既存の既定の腕で `unsupported "Release.Val"` にする（表層の構文と脱糖はこれらの値を作らないので、脱糖の出力には現れない）。

### 置いた定理

| ファイル | 定理 |
|---|---|
| `Exchange/Range.lean`（新規） | `decodeNat_encodeNat`・`decodeWord_encodeWord`・`decodeKind_encodeKind`・`decodeFamily_encodeFamily`・`decodeIPAddr_encodeIPAddr`・`decodeCIDR_encodeCIDR`・`decodePathPattern_encode`・`decodeNamePattern_encode`・`decodeIPPattern_encode`・`decodeHostPattern_encode`・`decodePort_encodePort`・`decodeEndpointPattern_encode`・`decodeRange_encodeRange`・`decodeIx_encodeIx`・`decodeIOShape_encode`（範囲の符号化の往復）、`legacy_name_atom_top`・`legacy_opaque_top`（旧版の一つの節点を明示の Top で読む）、`AdmitsRule.check_sound`・`AdmitsEntry.admitsRDec_sound`（表の `admitsR` の判定の健全性） |
| `Exchange/Convert.lean` | `Atom.toRelease_fromAtom`・`filterMap_toRelease_fromAtom`・`Atom.toRelease_top`、`legacy_atom_toRelease`・`legacy_opaque_toRelease`（旧版の読み込みが `Atom.nameTop`・`Ty.opaqueTop` に写る。Top の対応の補題）、`mem_writeAtoms_iff`・`readAtoms_writeAtoms`・`writeAtoms_readAtoms_writeAtoms`（書き出しの往復）、`fromEffNames_ok`・`fromEffNames_error_of_unlisted`（一覧にある効果は書け、候補の中の一覧にない原子は誤りにする）、`support_of_atomsIn`・`fromEffNames_complete_of_atomsIn`（`AtomsIn univ` から `unlistedAtom?_complete` の前提を得て、成功した書き出しに欠落がない）、`top_eff_roundtrip`（原子が全て Top の効果は読んで書き戻すと同じ効果を表し、Top の原子だけを持つ。RV-L10 中2） |
| `Exchange/Builtins.lean` | `BuiltinInput.admitsRDec_sound`（表のデータを入れた組み込みの表について `CheckRanges.AdmitsRDecSound`） |
| `Exchange/CheckInput.lean` | `Prepared.writeEffNames_complete`（候補 `q.atoms` の書き出しは、`AtomsIn q.atoms` を満たす効果を必ず書き、書いた列を読むと元に戻る。RV-L40 軽6） |
| `Exchange/RangeExamples.lean`（新規、既定の import） | `#guard` の小例: 範囲と範囲の位置の往復、余りの欄・幅を超える値・範囲外のポートの拒否、新版の欄の欠落の拒否、旧版の綴りの明示の Top での読み込み、旧版への範囲の欄と corpus への `rvar` の拒否、旧版の `prim` の空の列、`fromVal` の範囲の列、範囲付きの原子の書き出しと一覧にない原子の拒否、Top の効果の往復、`admitsR` の判定（拡大の被覆）、`instAtoms` |

JSON の全体を辿る変換（`legacyRanges`・`collectAtoms`・`collectPrimRanges`）と、`decodeAtom`・`decodeTy` などの `partial def` は証明していない（既存の交換と同じ扱い）。定理は、これらが呼ぶ全域の部分（一つの節点の変換、本体と範囲の読み込み、原子の列の書き出しと候補の検査）について述べる。

### 旧版の読み込みの対応（Rust が書き出す旧版を同じ意味で読む根拠）

Rust の今の書き出しは corpus 14・sidecar 6 である（`crates/benitoite/tests/desugar_export/named.rs` の `"version":14`・`"version":6`）。名前の原子は `{"name":{"value":…}}`、不透明型は `{"opaque":{"name":…}}`、`prim`・`primName` は範囲の欄を持たない。

- L40.6 の後の読み込みは、名前の原子を `Atom.nameTop`、不透明型を `Ty.opaqueTop`、表層の `primName` を空の範囲の列として読んでいた。
- 新しい読み込みは、旧版に明示の Top と空の列を加えてから読み、同じ値になる（`legacy_atom_toRelease`・`legacy_opaque_toRelease`、`RangeExamples` の旧版の `prim` の例）。
- 型表の項目は `rkinds = []`・`shape = untargeted`、表のデータは空で読む。これは L40.6 の後の `PrimMaterial.toPrimSig`（範囲の欄を置かず既定の値）と、`CheckTables.builtins`（表のデータを置かず既定の値）と同じ値である。`admitsRDec` は空の表で常に偽であり、L40.6 の後の `Materials.input` の既定（`fun _ _ => false`）と同じ判定になる。
- 期待のコアの JSON も同じ変換を通るので、比較の両辺は同じ形（新版の形）で並ぶ。

既存の固定の旧版の入力で、ビルドした入口を走らせた（`fixtures.log`）。width・extensible・try・batch2・batch4 の独立交換の検査は全て通った。named と batch3 は、読み込みの意味でなく、報告の形と版の一覧の違いで失敗した（「ずれと申し送り」2）。この実行は `check-formal.sh` の独立交換の部分を個別に走らせたものであり、Rust の書き出しとの比較（K10）ではない。

### 原子の一覧の作り方（依頼の 4 と RV-L40 軽6）

- `CheckInput.atomsFor` は、入力・型表・標準ライブラリの宣言の JSON に現れる原子を集める。型表の署名の範囲の変数の原子（`File.Write[rvar 0]` など）もここに入る。
- これに `State`、エフェクトの名前、操作のエフェクト、行の原子を加える（従来どおり。名前は明示の Top）。
- さらに、入力の各呼び出し（`prim`・`primName`）の範囲の列で署名の原子の範囲の変数を具体化した原子（`instAtoms`。`Ix.inst` と同じ）を加える。
- `prepare` は検査器の原子の集合 `q.atoms` をこの一覧の像にし、等式を `Prepared.atoms_eq` に持つ。書き出し `Prepared.writeEffNames` は、この一覧を書き出しの一覧に、`q.atoms` を候補に使う。`Prepared.writeEffNames_complete` は、検査器の不変条件 `AtomsIn q.atoms` を満たす効果をこの経路が必ず書き、黙って落とす原子がないことを示す。
- 一覧にない原子を持つ効果は、その原子が候補にあれば `throw` する（`fromEffNames_error_of_unlisted`）。
- 今の入口で効果を実際に書き出す経路は `desugarDiff` の脱糖の出力だけである。`desugarDiff` は型表を読まず、`q` を作らない。そこで、版の変換の後の corpus の原子の一覧を、書き出しの一覧と候補の両方に使う。この経路の候補では何も拒否しない。書く効果の原子が一覧にあることは、入力から読んだ効果と一覧の上の代入だけを書くことに依り、Lean では証明していない。07-04 の「交換の形式の版」に、そのまま書いた。

### 設計書

- 07-04 に節「交換の形式の版」を加えた（「書式付き補間の交換形式」の後）。`git grep` で参照を確かめた。参照は 07-04 の本文と、`Exchange/Version.lean`・`Exchange/Range.lean`・`Interval/Exchange.lean` のコメントである。
- 「道具と置き場所」の受理する版の一覧に 15・7 を加えた。
- 「01-12 との対応」に「交換の形式の版」の行を足した（「Rust は未接続」）。表層の組み込みの名前の範囲の列・表層の節の添字と脱糖の範囲・表記と構文・検査済みの値・組み込みの呼び出しの範囲の列の各行にあった交換の記述（範囲の列を持たない、範囲付きの不透明型の書き出しを拒否する、`fromVal` が誤りにする、検査の入力は判定を持たない）を、今の実装に直した。
- 01-12 は変えていない（plan-l10-l50 の L50 の行のとおり）。

### 変更したファイル

- `formal/Benitoite/Exchange/`: `Range.lean`（新規）・`RangeExamples.lean`（新規）・`Syntax.lean`・`Version.lean`・`Convert.lean`・`Builtins.lean`・`CheckInput.lean`
- `formal/Benitoite.lean`: 既定の import に `Exchange.Range`・`Exchange.Version`・`Exchange.RangeExamples` を加えた
- 交換の追随: `formal/Benitoite/Interval/Exchange.lean`（埋め込みの Surface 版14 を明示の Top で読む）・`formal/DesugarDiff/Main.lean`（原子を版の変換の後の JSON から集める）・`formal/BuiltinCheck/Main.lean`（操作の効果の照合で、範囲の位置を `shape` から決める）・`formal/SurfaceCheck/Validation.lean`（`Prepared` の新しい欄）
- `docs/design/07-quality/07-04-formal-semantics.md`
- 表層の `Surface/Typing.lean`・`Desugar.lean`・`Check*.lean` は変えていない。途中で `Surface/CheckTables.lean` の `PrimMaterial` に欄を足したが、`CheckExamples.lean`・`LogExamples.lean` の無名の構築子が壊れたので戻した。代わりに、交換の側で署名に範囲の欄を入れる（`BuiltinEntry.withRanges`）。L40.6b と重なる表層のファイルはない。
- Rust（`crates/`）と `Scope/` の採用定義は変えていない。主定理のファイルにも差分はなく、主定理の字面は L40.6 の後と同じである。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 最大常駐量 | 記録 |
|---|---|---|---|---|---|
| 局所の単一ファイル | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Exchange/Range.lean` ほか、一時ファイルの試行 4 件 | 途中は 1（「失敗と修正」）、最後は 0 | 各 0.6〜1 秒（一回は 120 秒を超えて止めた） | 未記録 | 本書 |
| モジュールの途中のビルド | `cd <wt>/formal && lake-build-locked.sh <log> Benitoite.Exchange.RangeExamples`（排他の道具。3 回） | 1・1・0 | 2〜6 秒 | 1,670,987,776 bytes（1593.6 MiB、1.56 GiB）が最大 | `lake-build-b1.log`〜`b3.log` |
| 既定の全体のビルド（途中） | `lake-build-locked.sh <log>`（3 回） | 1・0・0 | 11.8・15.4・7.1 秒 | 3,577,790,464 bytes（3412.1 MiB、3.33 GiB）が最大（b5） | `lake-build-b4.log`〜`b6.log` |
| 既定の全体のビルド（作業末） | `cd <wt>/formal && lake-build-locked.sh l50.1/lake-build-final.log` | 0（`Build completed successfully (504 jobs)`、`declaration uses 'sorry'` なし） | 0.14 秒（全て最新） | 70,647,808 bytes（67.4 MiB、0.07 GiB） | `lake-build-final.log` |
| work の選択 | `scripts/check.sh --level work --base ce6d22ff7b9ae827ac564147f5a9e68926fdfefe --dry-run` | 0 | 数秒 | 計時なし | `check-work-dry-run.log` |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base ce6d22ff7b9ae827ac564147f5a9e68926fdfefe` | 0（`formal_build` だけを選択、`selected checks passed`） | 0.22 秒 | 70,139,904 bytes（66.9 MiB、0.07 GiB） | `check-work.log` |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l50.1>/axioms.lean`（`#print axioms` 45 件） | 0 | 0.59 秒 | 1,526,153,216 bytes（1455.4 MiB、1.42 GiB） | `axioms.lean`・`axioms.log`・`axioms-time.txt` |
| 旧版の固定の入力 | `python3 -I formal/tests/test_{width,named,extensible,try}_exchange.py`・`python3 -B formal/tests/test_batch{2,3,4}_exchange.py` | width・extensible・try・batch2・batch4 は 0、named・batch3 は 1 | 計 約 40 秒 | 計時なし | `fixtures.log` |

最大常駐量はいずれも `/usr/bin/time -l` の値であり、排他の道具が包んだ `lake build` 全体（並列の lean のプロセスの合計ではなく、計時した木の最大）の値である。作業末の全体のビルドと work は全て最新の状態の再確認なので小さい。コンパイルを伴う全体のビルドの最大は b5 の 3.33 GiB である。

公理: 45 件のうち 43 件は標準の三公理の部分集合（`[propext, Classical.choice, Quot.sound]` 36 件、`[propext, Quot.sound]` 5 件、`[propext]` 2 件）に依存し、`Atom.toRelease_fromAtom`・`Atom.toRelease_top` の 2 件は公理に依存しない。`sorryAx` はない。

dry-run の選択は `formal_build` だけで、07-04 を変えたのに仕様例（`spec_examples`）と spec の集計を選ばなかった。07-04 の ` ```text ` のブロックと spec の印の見出しを変えていないので、自動分類がそれらの読者を選ばなかったと考える。名指しは足していない。

## 失敗と修正

1. `Range.lean` の往復の証明を `simp [..., Json.getObjVal?]` で書いたら、120 秒を超えても終わらず、止めた。また、変数の自然数の `if h : n < 2 ^ w` が `rfl` で簡約できなかった。`show` で do の形を与えて `rw` で閉じる形に直した（各 1 秒以内）。
2. `j == .str "top"` のような `Json` の `BEq`（`partial` の比較）は簡約できないので、文字列の照合の `if let .str "top" := j` に直した。本体の読み込みも、厳密な欄の検査（`!=`）を `decodeAtom` の側へ分けた。
3. `Json` の対象は `Std.TreeMap.Raw` であり、`insert compare`・`fold` の書き方が合わなかった。欄の並びを `toArray.toList` で照合する形に直した。
4. `fromEffNames_error_of_unlisted`・`top_eff_roundtrip` の書き換えが合わなかったので、直した。`validateClauses` の `Atom.name od.eff` に `Ix.top` を足した。構造体の更新の書き方を一行ずつにした。
5. 全体のビルド（b4）で、`PrimMaterial` の無名の構築子（`LogExamples`・`CheckExamples`）、`Prepared` の無名の構築子（`SurfaceCheck/Validation.lean`）、`BuiltinCheck` の `[.name l]` が壊れた。`CheckTables.lean` の変更を戻して交換の側の `withRanges` にし、`Validation.lean`・`BuiltinCheck/Main.lean` を直した。b5 から全体のビルドが通った。

## ずれと申し送り

### 計画からのずれ

1. 計画は「`Ix`（交換では `fixed` だけ）」と書くが、交換の範囲の位置は `fixed` と `rvar` の両方を持つ。`rvar` は型表の組み込みの署名にだけ置け、corpus と他の sidecar では JSON の段で拒否する。理由: 範囲の変数を持つ組み込みの署名（`File.writeTextIn` の `PathIn[R0]` と `File.Write[R0]`）を型表で交換できないと、`rkinds` を読む意味がない。プログラムの側で `fixed` だけに限ることは、`rvar` の拒否で保った。取りまとめの確認を求める。
2. formal/tests の Python の検査のうち二つが新しい読み込みで失敗する。どちらも `formal/tests/` にあり、依頼の編集範囲の外なので直していない。L50.2 の入口の切り替えか、取りまとめの判断で直す必要がある。直すまで `check-formal.sh` は通らない。
   - `test_named_exchange.py` の `test_legacy_effect_order_and_membership`（6 件）: 不一致の報告の `expectedDefinition` が新版の形（`ix` 付き）で出る。旧版の原子の列と JSON で比べているので失敗する。読み込みの意味は同じである。推す案: 期待値に明示の Top `{"ix":{"fixed":"top"}}` を加えて比べる。
   - `test_batch3_exchange.py` の `test_corpus11_batch2_and_sidecar_versions`: 受理しない版の一覧に corpus 15（sidecar の一覧では 7）を含む。corpus 15 は受理する版になったので、誤りの文が版でなく `property not found: ix` になる。推す案: 一覧の 15 を 16 に、sidecar の 7 を外す（8 と 13 が既にある）。
3. `desugarDiff` の書き出しの候補は corpus の原子の一覧そのものであり、この版の候補では何も拒否しない。`q.atoms` を候補にする経路は `Prepared.writeEffNames` として置いたが、今の入口から呼んでいない（`surfaceCheck` は効果を書き出さない）。07-04 にはこの通りに書いた。
4. `PrimSig.rkinds`・`shape` は `Surface/CheckTables.lean` の材料に欄を足さず、交換の側で署名へ入れた（L40.6b と表層のファイルを重ねないため）。
5. 区間解析の報告の型（`Interval/Exchange.lean` の `typeJson`）は `fromTy` で書くので、不透明型が現れれば `ix` 付きで出る。区間の警告の型は数の基本型なので今は現れない。K10 で区間の報告の比較を新版にするときに確かめる。

### 停止条件

該当しない。`Builtins.Assumptions` の欄は足していない。`effKind`・`valKind`・`admitsR`・`valContent` は既存の表のデータの欄であり、交換から値を入れただけである。主定理（`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`step_target_sound`・`reachable_target_sound`・`desugar_typed`・`surface_effect_soundness`）の言明は変えていない。前提・結論の内容の変更も、結論の弱化もない。

### 後の枝への申し送り

- L50.2:
  - 六つの入口が新しい版（corpus 15・sidecar 7）を読み、書き出し元の版の組を照合するようにする。
  - 入力の検査に、範囲の正規形（問4）とプログラムの型の範囲の変数（問3）を加える。`rvar` の欄は JSON の段で拒否済みであり、残るのは `Range.Canonical`・`Range.WF` と型表の署名の範囲の変数の番号の上限である。
  - 拒否の理由 `CoverFailure` と観測を交換に加える。
  - 上の 2 の Python の検査を直す。
  - 範囲の独立入力を置く。原子の種類別の入力と、交換の原子の一覧が具体化した原子を含む入力（`instClosed`）を含める。
  - `desugarDiff` の候補を型表から作るかを決める。作るには型表を入口の引数に加える。
- L50.3: `Release.Ty.opaqueTop`・`Atom.nameTop` を返していた旧の交換の読み込みは、今は `opaqueToRelease`・`Atom.toRelease` の一つの形にまとまった。互換の層として残るものはない。`unlistedAtom?` の既定の候補（一覧の像）を残すかは、全ての呼び出しが候補を渡すようになってから整理する。
- K10:
  - Rust の書き出しを corpus 15・sidecar 7 へ切り替える。範囲・範囲の位置・`ranges`・`rkinds`・`shape`・表のデータの JSON の形は本書の表と 07-04「交換の形式の版」のとおりである。
  - 表のデータの正しさ（`effKind`・`valKind`・`admitsR`・`valContent`）を Rust の表と照合する。
  - 報告の形の変化（`ix` 付き）を、Rust 側の検査スクリプト（`check_named.py` など）と区間の報告の比較で扱う。
- R 段: Rust の型検査器が選んだ範囲の列を表層の `primName` の `ranges` に書く。`admitsR` の規則は `any` と `covers i j` の二つで足りるかを、標準の宣言の表（問22）で確かめる。

## 時間

| 区分 | 時刻・時間 |
|---|---|
| 開始と終了 | 開始は約 08:15（依頼文と計画を読み始めた時刻。記録していないので推定）、終了 約 09:15 |
| 外側の所要 | 約 1.0 時間 |
| 能動時間 | 約 0.9 時間（読む・設計・証明・実装・文書） |
| 検査・ビルドの待ち | 約 4 分（排他の道具のビルド 8 回、固定の入力の検査、公理、work） |
| 見込みとの比較 | 見込み 0.6〜5.5 時間の範囲内。上端の 2 倍（11 時間）には達していない |
