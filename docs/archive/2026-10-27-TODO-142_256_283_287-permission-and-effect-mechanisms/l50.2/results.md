# L50.2 の結果: 観測・拒否の理由・入力の検査と六つの入口（型検査器の入口への受理の組み込みを含む）

2026-10-28。plan-l10-l50「L50」の表の L50.2 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l50.2`）で行った。担当は Claude のサブエージェントである。git の状態は変えていない（コミットは取りまとめが行う）。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L50.2（依頼の 1〜8） |
| B_WORK | `71400d98f04fd8e726960ed65be72b6f35093db3`（L50.1 と L40.6c の取り込みの後の本線） |
| 閉じた範囲 | 依頼の 1〜8 の全て |
| 未完 | なし（計画の行の範囲で）。Rust との全比較（`check-formal.sh`）は K10 であり、実行していない |
| 適用した前提の変更の行 | なし。主定理（Release・Surface）の前提・結論・字面は L40.6c の後と同じである。表層の検査器の受け入れ方を変えたが、検査器の健全性の定理の言明は変えていない |
| 停止条件 | 該当しない（下の「停止条件の点検」） |

## 変更と接続

### 1. 交換に加えたもの（観測と拒否の理由）

新しいモジュール `Exchange/Observe.lean`（既定の import に追加）に置いた。

| 対象 | 交換の形 | 定理 |
|---|---|---|
| 観測（IO の事象の `obs`） | 対象 `{"path":語}`・`{"host":{"name":語}\|{"ip":A}}`・`{"endpoint":{"host":…,"port":n}}` の配列。読み込みは余りの欄を拒否する（`decodeTargetStrict`） | `decodeHostTarget_encode`・`decodeTarget_encode`・`decodeTargetStrict_ok` |
| 観測の許可の判定 `observationAllowed` | 名前の原子の閉じた範囲の列が、種類 `κ l` に相対的に観測の各対象を含むか | `observationAllowed_sound`（判定が真なら `Release.Eff.Allows`） |
| 拒否の理由（DET-05） | `"notCovered"`・`"atomicCoverOnly"`・`"unknownSource"`・`"budgetExceeded"` | `decodeCoverFailure_encode`・`encodeCoverFailure_injective` |
| 入口の拒否 | `{"typing":{path,reason}}` か `{"cover":{"key":{definition,surfacePreorder},"reason":…}}`（`encodeEntryError`。`surfaceCheck` の報告は `result.cover` に鍵と理由を書く） | — |
| 必須の判定の入力 `scopeAcceptance`（corpus 15 の入力ごとに必須） | `patterns`（リテラルのパスのパターンの綴りと範囲）・`hosts`（ホストのパターンの綴りとパターン）・`limits`（本体と全体の操作数・保持数）。欄の余りと綴りの重複を拒否する | `ScopeAcceptanceEntry.acceptInput_sound`（交換の入力から作る規則の表は健全。条件なし）・`acceptInput_none_noRules` |

`scopeAcceptance` から作る受理の入力は、本番の実例の表の δ による六項目 `ScopeSound.productionRules`（パターンとホストのパターンの解析は表を引く関数）である。受理は規則の添字と事実の転送だけを読む。文字列の解析は形式化の外側であり、Lean は表を信頼する。旧版の corpus は `scopeAcceptance` を置かせず（`rangeFields` に追加）、`null` を加えて規則のない受理の入力（旧の像）で読む。

観測は交換の形と判定を置いたが、六入口のどれも観測を読まない（観測を含む事象を交換する入口は今ない）。VM の事象との比較で読むのは K10 である。

### 2. 入力の検査（問3・問4）

| 検査 | 置き場所 | 一つの節点の健全性 |
|---|---|---|
| 範囲が整形式で正規形（`Range.WF ∧ Range.Canonical`）。全ての `ix` の閉じた範囲、全ての `ranges` の要素、`scopeAcceptance` のパターンとホストのパターン | `Exchange/Version.lean` の `validateRanges`・`validateScopeAcceptance`、一つの節点は `checkRangeInput` | `checkRangeInput_sound`・`checkRangeInput_complete` |
| プログラムと表の型に範囲の変数がない（上限 0） | 同上（corpus・stdlib・coverage・coverage-program の全体、型表の項目の外） | `checkIxInput_sound`・`checkIxInput_zero` |
| 型表の署名の範囲の変数の番号 < その項目の `rkinds` の個数。`admitsR` の `covers i j` の番号も同じ | `validateBuiltinRanges`、一つの節点は `checkIxInput n`・`checkAdmitsRuleInput` | `checkIxInput_sound`・`checkAdmitsRuleInput_sound` |

検査は新版（corpus 15・sidecar 7）の `exchangeJson` の中で行うので、六入口が同じ検査を通る。JSON の全体を辿る部分は `partial` で、証明していない（L50.1 と同じ扱い）。L50.1 の「型表なら項目の外にも `rvar` を置ける」という緩い JSON の規則は、項目の外の `rvar` を拒否する形に締めた（`RangeExamples.lean` の例を直した）。

### 3. 型検査器の入口への受理の組み込みと、プログラム全体の述語（RV-L40 中3）

新しいモジュール `Surface/CheckAccept.lean`（既定の import に追加）に置いた。

- `AcceptInput`（Ok の構成子の名前、規則の表、上限、実装のメソッドの本体の鍵の名前）と、規則のない入力 `AcceptInput.noRules`（旧の像）。
- 出現の解決 `primResolve`: 本体の出現のうち、組み込みの名前を頭に持つ直接の呼び出しを標準の所有元のその名前へ解決する。本体の表 `tableFor A key body := standardTable (primResolve key body) A.rules`。
- 本体の始まり: 鍵 `bodyKey name = ⟨name, 0⟩`（区間解析と同じく番号 0 から）、束縛番号の土台 `entryScope n = ⟨List.range n, n⟩`（引数の位置。辞書の引数を含む）。
- `acceptDef`・`acceptMethod`・`acceptProgram`（全ての定義と、全ての実装の全てのメソッドの本体）。
- プログラム全体の受理の述語 `Accepted A m`。
- 入口 `checkProgramAccepted q A m names : Except EntryError Unit`。型付けの検査 `checkProgram` が成功したら `acceptProgram` を行う。

| 定理 | 内容 |
|---|---|
| `acceptProgram_sound`・`acceptProgram_sound_names` | 全体の受理が成功すれば `Accepted` |
| `checkProgramAccepted_ok` | 入口の成功は型付けの検査と全体の受理の両方の成功 |
| `checkProgramAccepted_sound` | `checkProgram_under` と同じ前提で `CheckedUnder m.program q ∧ Accepted A m` |
| `checkProgramAccepted_empty` | `checkProgram_empty` と同じ前提で `m.program.WellTyped B op ∧ Accepted A m` |
| `acceptFn_noRules`・`acceptProgram_noRules`・`checkProgramAccepted_noRules` | 規則のない表では受理は常に成功し、入口は型付けの検査と同値（旧の像） |
| `tableFor_sound`・`Accepted.def_body`・`accepted_check_connection` | 健全な規則の項目で受理したプログラムの定義の本体に、接続定理 `scope_check_connection` が当たる |

`checkProgram` の名前と言明は変えず（型付けの検査の部分として残す）、受理を組み込んだ入口を `checkProgramAccepted` として加えた。交換の入口 `surfaceCheck`（全体と選んだ定義の両方）と `surfaceCheckAll`（定義と実装ごと）はこの入口を使う。理由: `checkProgram` の字面に依存する既存の定理と例（約 15 箇所）を変えずに済み、型付けの結論と受理の結論を別々の定理で取り出せるためである。

コアの実行と表層の評価（`ReachBlock`）の対応の補題は置いていない（設計者の決定）。07-04「証明する性質」に、受理を主定理の前提に入れず、対象健全性は型付けと δ・応答の信頼条件から別に示しているので、受理は精度の説明にとどまることを書いた。

### 4. 六つの入口の変更

| 入口 | 変更 |
|---|---|
| `surfaceCheck`・`surfaceCheckAll` | 型検査器の入口 `checkProgramAccepted`（全体）、`checkDef` と `acceptDef`（選んだ定義）、`checkImpl` と `acceptMethod`（実装）を使う。拒否は `result.cover`（`surfaceCheck`）か、理由付きの不一致（`surfaceCheckAll` の `required check is not covered: <番号> "<理由>"`）として報告する。`surfaceCheckAll` の報告に `nonTopRanges` を加えた |
| `desugarDiff` | 報告に `nonTopRanges`（`countNonTopRanges`）を加えた。候補の決定は下 |
| `builtinCheck`・`coverageDiff`・`coverageProgramDiff` | コードの変更なし。`exchangeJson` の新版の検査（上の 2）を通る |
| `intervalDiff`（`Interval/Exchange.lean`） | 埋め込みの Surface 15 を受理する。版14は corpus 全体で範囲の欄を拒否してから欠けた欄に明示の Top を加え（`legacyRangesMissing`）、版15は範囲の欄を必須とし、`rvar` を拒否し、範囲の正規形を確かめる（`validateRanges 0`）。版15では `legacyRangesMissing` が入力を変えないこと（欠けた欄がないこと）を確かめる |
| 準備 `CheckInput.prepare` | `Prepared` に欄 `accept` を加えた（`scopeAcceptance` から作る受理の入力。実装のメソッドの本体の鍵は、その本体の定義の名前を関数の鍵と同じく変換したもの） |

`desugarDiff` の書き出しの候補は型表から作らないと決めた。理由: 脱糖の比較は corpus の表層と期待のコアだけを読み、型表を入口の引数に加えると Rust の書き出しと比較の手順の引数が変わる。一方、脱糖は新しい原子を作らず範囲を項の範囲の列にだけ書くので、候補を型表の原子まで広げても書き出しの結果は変わらない。具体化した範囲の原子を書く経路（検査器の入力）は型表から作る候補 `q.atoms` を使う（L50.1 の `Prepared.writeEffNames_complete`）。07-04「交換の形式の版」に書いた。

### 5. 検査器の効果の包含（L40.6c の申し送り）

推す案で直した。

- `Finite.effCovers s a b`（b が a を一原子ずつ覆う。`Atom.covers?` を使う。Top を覆うのは Top だけ、和では覆わない。Fail は従来どおり構造上の所属）と、`effCovers_sound`（`Eff.Covers b a`）・`effCovers_of_effSub`（構造上の包含なら被覆でも受理）を `Surface/FiniteTools.lean` に置いた。
- `tyLe`（関数の型の潜在効果）を `effCovers` にした。`tyLe_sound` の言明（`Ty.Le`）は変わらない。
- `Check.acceptEffCover` を置き、ラムダの本体、`resume` の引数、関数の本体、メソッドの本体の四つの位置を被覆の受理にした（表層の型付けがそこで E_Sub・B_Sub を使う位置）。健全性 `acceptEffCover_sound`・`accept_block_effCover` で証明を追随させた（`CheckSoundControl.lean`・`CheckInduction.lean`・`CheckSoundDicts.lean`）。
- `handle` の保護本体と節、Fail の節、純粋の要求（空の上限）、部分適用の潜在効果は構造上の包含の `acceptEff` のまま保った。前の三つは C-Handle・C-Handle-Fail と同じ、空の上限では二つが同じ、部分適用は表層の型付けの `E_PartialCall` が構造上の包含（`Eff.Sub`）を求めるためである。直せない形はなく、照合の対象から外す範囲もない。

### 6. 範囲の Lean の側の独立入力

- Lean の既定ビルドの例: `Surface/CheckAcceptExamples.lean`（出現の解決、入口の受理・`notCovered`・`unknownSource`・`budgetExceeded`・型付けの誤りの先行、規則のない入力の同値、被覆だけの効果の上限の受理と、構造上の `acceptEff` の不受理、Top の原子を範囲付きの上限が覆わないこと）と、`Exchange/ObserveExamples.lean`（種類別の対象と観測の往復、範囲外のポートの拒否、四つの理由の名前と往復、観測の許可（パス・ホスト名の endpoint・IP の endpoint・Top・種類違い・対象を持たない名前・範囲の変数）、範囲の入力の検査（正規形でない CIDR・host bits・範囲の変数の上限・`admitsR` の番号・`scopeAcceptance` の欠落・旧版への混入・欄の余り・綴りの重複））。
- 交換の独立入力: `formal/tests/test_range_exchange.py`（新規）。corpus 15・sidecar 7 の五形式を手で書き、Rust の書き出しや Lean の脱糖から作っていない（期待のコアも手書き）。
  - 二つの入力（上限の広い `range-paths` の 8 定義、上限 0 の `range-budget` の 3 定義）。原子の種類別（パスの `File.Write`、endpoint のホスト名と IP の CIDR）、Top でない範囲、受理と拒否の理由（`notCovered`・`unknownSource`・`budgetExceeded`）、予算の停止による由来の忘却（局所のパターンは Top になり狭い契約を拒否する。リテラルのパターンは事実によらず既知なので予算の超過の後も受理する）、被覆だけの効果の上限の受理を六入口で確かめる。
  - `surfaceCheckAll` は拒否を期待する 4 定義を不一致として数えるので終了 1 であり、定義ごとの分類と理由を確かめる。
  - 入力の検査の拒否（正規形でない CIDR、host bits、`scopeAcceptance` の欠落、プログラムの型の `rvar`、型表の範囲の変数の番号、`admitsR` の番号、旧版への混入）。
  - 全 Top だけを成功に数えない: 入力の Top でない範囲の数を確かめ（20 以上）、`desugarDiff`・`surfaceCheckAll` の報告の `nonTopRanges` が入力の数と一致すること、範囲を全て Top にした入力では 0 と報告することを確かめる。
  - `intervalDiff`: `test_interval_exchange.py` の domain の入力（組み込みの呼び出し 80 個）に明示の Top と空の範囲の列を書いた Surface 15 の形が、版14と同じ報告と終了状態になること、版14への範囲の欄・版15の欠けた欄・版15の `rvar` を拒否することを確かめる。
- `atomicCoverOnly` は効果の上限の原子の受理（`acceptAtom`）の理由であり、Lean の型検査器の入口は効果の上限の拒否を型付けの誤り（`effect exceeds the allowed effect`）として報告するので、交換の独立入力には現れない。Lean の例は `ScopeAcceptExamples` にある（L40.4）。

### 7. Python の検査の修正（L50.1 の推す案）

- `test_named_exchange.py` の `test_legacy_effect_order_and_membership`: 期待値に明示の Top `{"ix":{"fixed":"top"}}` を加えて比べる。
- `test_batch3_exchange.py` の `test_corpus11_batch2_and_sidecar_versions`: 受理しない版の一覧の corpus 15 を 16 に、sidecar の 7 を外した。

### 8. 設計書

- 01-12「型の情報を付けた表層の構文と型付け」: 検査器が四つの位置と `tyLe` を被覆で受け入れ、ほかを構造上の包含で受け入れることに直した（L40.6c が書いた「検査器は構造上の包含で受け入れ、被覆だけで型付くプログラムを受理しない」を置き換えた）。
- 01-12「Scope の必須の判定の受理と拒否の理由」: 入口 `checkProgramAccepted` と述語 `Accepted` の【決定】を加えた。同じ節の古い文（「Release の `Eff.Sub` と C-Sub は構造上の包含のまま」は L40.6c の後は誤り、「交換の材料は判定を持たない」は L50.1 の後は不足）を直した。
- 07-04「証明する性質」: 検査器の被覆による受理の文を直し、入口への受理の組み込みの【決定】（主定理の前提に入れない、受理は精度の説明、`ReachBlock` の対応は置かない）を加えた。
- 07-04「道具と置き場所」「交換の形式の版」「区間解析の独立交換の読者」と「01-12 との対応」（新しい行「初回リリース版の拡張: 型検査器の入口の必須の判定の受理」、既存の三つの行の更新）。全て「Rust は未接続」である。
- `formal/README.md`: 区間の独立交換の Surface 14・15、範囲の独立入力の説明と実行の方法。
- 見出しは足していない。

### 変更したファイル

- 新規: `formal/Benitoite/Surface/CheckAccept.lean`・`CheckAcceptExamples.lean`、`formal/Benitoite/Exchange/Observe.lean`・`ObserveExamples.lean`、`formal/tests/test_range_exchange.py`
- 変更: `formal/Benitoite.lean`（既定の import に 4 モジュール）、`Surface/FiniteTools.lean`・`Check.lean`・`CheckLemmas.lean`・`CheckSoundControl.lean`・`CheckInduction.lean`・`CheckSoundDicts.lean`、`Exchange/Syntax.lean`（`Input.scopeAcceptance`）・`Version.lean`・`Range.lean`（`legacyRangeNodeMissing`）・`CheckInput.lean`・`RangeExamples.lean`、`Interval/Exchange.lean`、`formal/SurfaceCheck/Main.lean`・`Batch.lean`・`Validation.lean`、`formal/DesugarDiff/Main.lean`、`formal/tests/test_named_exchange.py`・`test_batch3_exchange.py`、`formal/README.md`、01-12、07-04
- 変えていない: `Release/`（主定理・`Builtins.Assumptions` を含む全て）、`Scope/`、`Surface/Theorems.lean`、Rust（`crates/`）、`scripts/`

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 最初の全体のビルド（本線の L40.6・L40.6b・L40.6c の分を作り直した） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0（509 ジョブ） | 180.79 秒（排他の待ち 0 秒） | [lake-build-first.log](lake-build-first.log) |
| 途中の全体のビルド（15 回） | 同上 | b1・b2・b4〜b6・b8・b10・b12 は 1、ほかは 0 | 0.45〜41.70 秒 | [builds/](builds/) |
| 局所の単一ファイル（約 12 回） | `cd <wt>/formal && lake env lean -M 12288 <相対パス>` | 途中に 1 が 5 回、最後は 0 | 各 1 秒以内 | 本書 |
| 作業末の全体のビルド | 排他の道具 | 0。`Build completed successfully (571 jobs)`、`declaration uses 'sorry'` 0 件、警告 88 件（最初のビルドと同数。新しいファイルと変えたファイルの警告なし） | 0.14 秒（組み立て済み） | [lake-build-final.log](lake-build-final.log) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l50.2>/axioms.lean`（`#print axioms` 56 件） | 0 | 0.58 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |
| formal/tests の Python の検査（10 件） | `python3 -B formal/tests/test_{width,named,extensible,try,batch2,batch3,batch4,batch5,range,interval}_exchange.py`（既定の独立入力だけ。`--rust-dir` なし）。`test_range_exchange.py` と `test_named_exchange.py` は `python3 -I` でも通ることを確かめた | 全て 0 | 計 29 秒 | [python-tests.log](python-tests.log) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 71400d98f04fd8e726960ed65be72b6f35093db3 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更）と `formal_build` | 数秒 | [check-work-dry-run.log](check-work-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 71400d98f04fd8e726960ed65be72b6f35093db3` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7 件成功、`formal_build` 成功、`selected checks passed` | 3.80 秒 | [check-work.log](check-work.log) |

`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。work の `formal_build` は排他の道具を通らないが、作業末の全体のビルドの直後で組み立て済みである。Rust の lib 全件・clippy・fmt は選ばれず、加えていない。

公理: 56 件（新しい定理 34 件、証明を変えた既存の定理 9 件、主定理 10 件と接続定理 3 件）とも標準の三公理の部分集合だけに依存する（三つ全て 50 件、`propext`・`Quot.sound` 3 件、`propext` だけ 2 件、公理なし 1 件）。`sorryAx` と独自の公理はない。`native_decide` と `maxHeartbeats` の追加はない。例の確かめは `#guard` で、カーネルの `decide` に大きな計算を展開していない。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。全体のビルドの値は、排他の道具が包んだ `lake build` の計時の木の中の最大のプロセスの値である。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 最初の全体のビルド | 3587080192 | 3420.9 | 3.34 |
| 途中のビルドの最大（b3。`Surface/Check` 以降を組み立て直した） | 3578003456 | 3412.2 | 3.33 |
| 作業末の全体のビルド（組み立て済み） | 71041024 | 67.7 | 0.07 |
| 公理の確かめ（`import Benitoite` の全体を読む単一ファイル） | 1527201792 | 1456.5 | 1.42 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、組み立て済みの `formal_build` を含む一括の値） | 78364672 | 74.7 | 0.07 |

本作業で観測した最大は 3.34 GiB（最初の全体のビルド）である。局所の単一ファイルと Python の検査は計時していない。`-M 12288` は変えていない。

## 失敗と修正

- b1: `acceptEffCover_of_acceptEff` の証明が `pure () = Except.ok ()` で閉じなかった。`rfl` を足した。
- b2: `CheckSoundDicts.lean` のメソッドの本体の検査の述語が `acceptEff` のままで型が合わなかった。`acceptEffCover` に直した。
- b4〜b6: `CheckAcceptExamples` の `#guard` が偽になった。原因は、例の鍵の番号を 1 から数えたこと（本体の始まりは 0）、書き込みの例の戻りの型（`Result[Unit, IOError]` が要る）、本体を `return` の形にしていなかったこと（`function body does not exit`）。例を直した。
- b8: `RangeExamples.lean` の二つの `#guard` が偽になった。新版の入力の検査が `inputs` の配列を必須にしていたことと、型表の項目の外の `rvar` を拒否するようにしたことによる。前者は配列がない形を各形式の読者に任せる形にし、後者は例を新しい規則に合わせた（項目の中の `rvar` は個数の上限で受理・拒否する例を足した）。
- b10: `Except.isError` がない。`!(… ).isOk` に直した。
- b12: `ObserveExamples` で `Except` の `BEq` がない。`toOption`・`isOk` で比べる形に直した。
- Python の範囲の検査の初回: 不透明型の名前は交換では「識別番号:型引数の JSON」の形であることを知らず `Scope.PathIn` と書いて準備で拒否された。番号の名前（`101:[]` など）に直した。型表の等値と鍵の要約の期待値を直した（`Result` は二つの型引数に依存、`Http.RequestCheckError` は等値が常に導出でき鍵は導出できない）。予算の例のリテラルのパターンは事実によらず既知なので予算の超過の後も受理されると分かり、予算の拒否の例を局所のパターンに替え、リテラルの受理を別の例にした。区間の Surface 15 の例は、範囲の位置を持つ節点のない base の入力では何も確かめないと分かり、組み込みの呼び出しを持つ domain の入力に替えた。
- 設計書の書き換えを Python の標準入力の台本で当てたとき、台本の読み込みで符号化の誤りが出て止まった（ファイルは変わっていない）。台本をファイルにして UTF-8 で読み込んで当てた。

## ずれと申し送り

### 計画からのずれ

1. 依頼の「型検査器の入口（`checkProgram`）に組み込み」は、`checkProgram` を型付けの検査の部分として残し、受理を組み込んだ入口 `checkProgramAccepted` を加える形にした（上の 3 の理由）。交換の入口は全てこちらを使う。
2. 観測は交換の形と判定を置いたが、六入口のどれも読まない（上の 1）。
3. 01-12 は計画の L50 の行では「—」だが、検査器の受け入れ方（L40.6c の文）と、入口・述語の定義の写しを 01-12 に書いた。L40.6c・L50.1 の後に古くなっていた同じ節の二つの文も直した。
4. 型表の項目の外の `rvar` を拒否する（L50.1 の JSON の規則を締めた）。

### 停止条件の点検

- `Release/` と `Scope/` の採用定義、`Builtins.Assumptions` の欄、主定理（`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`step_target_sound`・`reachable_target_sound`・`desugar_typed`・`surface_effect_soundness`・`surface_target_sound`）と接続定理のファイルと言明は変えていない。前提・結論の内容の変更、結論の弱化、公理の追加はない。
- 表層の検査器（段階 E2 の Lean の検査の関数）の受け入れは広がったが、健全性の定理（`checkExpr_sound`・`checkDef_sound`・`checkProgram_sound` など）の言明は同じで、受け入れた効果が型付けの E_Sub・B_Sub の被覆の前提を満たすことを示して通した。主定理の前提ではない。

### 後の枝への申し送り

- L50.3:
  - `CheckAccept.AcceptInput.noRules` と `ScopeAcceptanceEntry.acceptInput none` は旧の像の互換の層であり、Rust の書き出しが corpus 15 に移った後に旧版の読み込みと合わせて整理の対象にする。
  - 01-12「Scope の必須の判定の受理と拒否の理由」のほかの文と 07-04 の L40.4〜L40.6 の行に、L40.6c・L50.1 の後に古くなった記述が残っていないかを全体の照合で確かめる（本枝は同じ節の二つの文だけを直した）。
- L50.4:
  - 入口の述語 `Accepted` と `checkProgramAccepted_sound` の言明・仮定（`names = m.names`、メソッドの本体の鍵の名前の決め方 `methodKey`、`entryScope` の番号の割り当て）をレビューの観点にする。
  - `primResolve` は組み込みの名前を頭に持つ呼び出しを全て標準の所有元へ解決する。名前の解決が型の情報を付けた表層の構文で終わっていること（同じ綴りの利用者の関数は `funName`）を前提にしている。
- K10:
  - Rust の書き出しを corpus 15 に切り替えるとき、各入力に `scopeAcceptance`（処理系の解析器が読んだリテラルのパターンとホストのパターンの表、本体と全体の上限）を書き、旧版の `null` との違いを扱う。
  - `test_range_exchange.py` を `check-formal.sh` に加える（`scripts/` は本枝の編集範囲の外）。Rust の書き出しの比較では `desugarDiff`・`surfaceCheckAll` の報告の `nonTopRanges` が 0 でないことを全 Top だけの一致と区別する条件にする。
  - `surfaceCheck`・`surfaceCheckAll` の報告の形が変わった（`result.cover`、`required check is not covered: …` の不一致、`nonTopRanges`）。Rust 側の検査の台本の読み方を合わせる。
  - 観測（`encodeObservation`・`observationAllowed`）を VM の IO の事象との比較で読む。
  - 区間の独立交換の Surface 15 への切り替え（Rust の区間の書き出し）。
  - 交換の不透明型の名前は「識別番号:型引数」の形なので、表のデータ `valKinds`・`valContents` の名前も同じ形で書く必要がある（Lean の `TargetTable` の `Scope.PathIn` などの名前とは別である）。
- R20:
  - Rust の型検査器の効果の上限の受理を、Lean の検査器と同じ位置（ラムダの本体、`resume` の引数、関数とメソッドの本体、関数の型の潜在効果）で判断 5 の被覆にし、`handle` の保護本体と節、Fail の節、部分適用の潜在効果は構造上の包含に保つ。違えるなら Lean の側を直す。
  - 必須の判定の上限の値（`limits`）を測定で決め、交換に書く。
  - `atomicCoverOnly` を効果の上限の拒否の理由として報告するなら（E0519）、Lean の型検査器の入口は効果の上限の拒否を理由なしの型付けの誤りとして報告するので、K10 の比較で理由を照合する方法を決める。

## 時間

| 区分 | 時刻（2026-10-28） | 所要 |
|---|---|---|
| 文書を読む | 10:14〜10:22 頃 | 約 8 分 |
| 検査器の被覆による受理（FiniteTools・Check・証明の追随） | 10:22〜10:28 頃 | 約 6 分 |
| 入口への受理の組み込みと例（CheckAccept・CheckAcceptExamples） | 10:28〜10:35 頃 | 約 7 分 |
| 交換（Observe・入力の検査・prepare・入口・区間） | 10:35〜10:42 頃 | 約 7 分 |
| 独立入力と Python の検査 | 10:40〜10:47 頃 | 約 7 分（上と重なる） |
| 設計書・公理・作業末の検査・本書 | 10:47〜10:57 頃 | 約 10 分 |

外側の所要は約 43 分（最初の全体のビルド約 3 分を含む）。能動時間は約 37 分、ビルドと検査の待ちは計 約 6 分（最初のビルド 181 秒、途中のビルド計 約 120 秒、Python の検査 29 秒、work 4 秒）。見込み（0.6〜5.5 時間）の下端付近であり、上端の 2 倍（11 時間）には近づいていない。時刻は記録のログの時刻（ビルドの開始時刻）と外側の時計から推定した。
