# L1b: Releaseの型・効果と代入の移行

L1bはL1bc7で完了した。[最新の完了記録](#l1bc7-complete) を読む。以前の節と保存差分は当時の記録であり、representation-b.patchを再適用しない。

## L1b1: 切り替え前の順序と整列の補題

基準 B は `b60c306f4f8508d3db595710d2a56aa724eac5b6`（開始時 HEAD）である。開始時の作業ツリーは空であった。plan.md の L1b1・共通の関門 K、design.md「エフェクトに型を保持するLeanの表現」、decisions.md の R13・R15・R16 に従った。

### 変更

- `formal/Benitoite/Release/Order/Atoms.lean`: 基数1114113の文字列の符号と、名前を偶数・行変数を奇数にする `Atom.code` の単射性を証明した。最小符号の相違点を選ぶ `atomsCompare` について、eq と関数の等号の同値性、外延性、反転、推移性、反対称性、全域性を証明した。任意の支持を持つ関数を扱い、有限支持は仮定しない。
- `Order/Labels.lean`: 構成子の順位・Nat・String・List String・原子の関数をラベルにした。文字列は Unicode スカラー値列の辞書式順とし、各ラベルの比較に `Std.LawfulEqCmp` と `Std.TransCmp` の証明を与えた。
- `Order/Tree.lean`: ラベル付きの多分木と子の列を構造再帰で比較する。eq と生の等号の同値性、反転、推移性、全域性を証明し、同じ二つの比較のクラスへ接続した。
- `Order/SortUnique.lean`: 汎用の挿入ソートを置き、所属の保存・狭義昇順・集合による出力の一意性・冪等性を証明した。0・1要素では比較を評価しないことを、任意の比較関数について `rfl` で証明した。
- `formal/Benitoite.lean`: 四モジュールを既定ビルドへ登録した。

Ty・Eff の表現、既存の規則・定理・例・テストは変更していない。新しい公理・仮定・sorry は加えていない。定義での非計算的な選択は `atomsCompare` だけであり、`labelCompare` の noncomputable はその依存による。Rust、現行設計の規則の写し、docs/todo/ は変更していない。コミットは行っていない。

### 検査

途中は formal/ で次の関係ターゲットだけを確認した。執筆中の `lake env lean Benitoite/Release/Order/{SortUnique,Atoms,Tree}.lean` はファイルごとに実行した。初回には、証明での展開不足・Boolの比較の簡約・利用できないタクティク・simpの循環を検出し、命題を保って修正した。不要な補助と警告も整理した。途中の外側の時間は計測していない。

```sh
lake build Benitoite.Release.Order.Atoms Benitoite.Release.Order.Labels \
  Benitoite.Release.Order.Tree Benitoite.Release.Order.SortUnique
```

最終の局所ビルドは終了0、警告なしであった。`lake env lean /private/tmp/l1b-audit.lean` による一時的な確認も終了0であり、`treeCompare labelCompare` の比較の二クラスが得られた。主要な定理の `#print axioms` は Lean 標準の `propext`・`Classical.choice`・`Quot.sound` の範囲で、`sorryAx` や追加の公理を含まなかった。`#print` で木と列の比較・整列が構造再帰に展開されることも確認した。

作業末には、同じ B と選択へ `--dry-run` を付け、`formal_build` だけが選ばれることを確認した。外側の時間は `/usr/bin/time -p` の real である。

| コマンド（リポジトリの根） | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `scripts/check.sh --level work --base b60c306f4f8508d3db595710d2a56aa724eac5b6 --only formal_build` | 0 | 0.68秒 | 一度だけ実行。formal/ の既定の `lake build` と sorry の検出が成功。ライブラリと六入口を含む |
| `git diff --check` | 0 | 0.01秒 | 空白の診断なし |

L1b全体の割り当てのうち、今回のL1b1に当たる `formal_build` を実行した。仕様の本文・例・対応表を変更していないため、`spec_examples`・`spec_tally` はL1b2へ残す。Rustの検査、gc-stress、check-formal.sh の全比較は今回の範囲に含めず、実行していない。

### 計画からのずれと申し送り

実装範囲と数学上の順序に計画からのずれはなく、Rの判断の追加は不要であった。L1b1の区切りは完了した。Tyから木への単射、表現の切り替え、正規化と代入、整形式・ストアWF、検査器と六入口の移行はL1b2へ残す。

比較と整列の汎用部は `Benitoite.Release.Order`、原子の比較は `Benitoite.Release` に置いた。`Order/Atoms.lean` は現在のAtomを使うため `Release/Syntax.lean` をimportしている。L1b2でSyntaxから順序を使う際は、Atomの定義を別モジュールへ切り出すなどしてimportの循環を避ける必要がある。正規化による既存例の簡約の維持と、検査器の計算できる写しへの接続は、今回のビルドだけでは確認したことにならない。

## L1b2: 依存の分離と現行の共有型の順序（未完の区切り）

今回は **L1b2を完了していない**。依頼文の申し送りに従い、表現の切り替え前で、既定の全体ビルドがsorryなしで通る区切りまで進めて止める。今回の開始版は `ee6fcc04843dc36ebfd96befde1c96e3bd3b04b4`（L1b1の取り込み、開始時HEAD）であり、開始時の作業ツリーは空であった。L1b全体のworkの基準は、前節のL1a取り込み `b60c306f4f8508d3db595710d2a56aa724eac5b6` である。コミットとdocs/todo/の変更は行っていない。

### できたこと

- `Release/Atom.lean` と `Release/Types.lean` へ原子と共有する型・効果を分離した。Syntaxの移動元の本文と移動先、残った項・宣言の本文はPythonで完全一致を確認した。既存の効果のAPI・型付け・実行の規則・定理の前提は変えていない。
- `Order/Atoms.lean` が原子だけを読み、`Order/Types.lean` が共有型を読み、Syntaxがその順序を読む形にした。Syntaxから順序を使う際の循環を解き、既存のRelease/Surface/Exchangeの読者を同じ共有型へ接続した。
- `Order/Types.lean` に全15構成子の木への写像と型列の写像、両方の単射性を証明した。基本型・型構成子の宣言順、型変数の番号、文字列、契約名列、引数列、戻り値、潜在効果、辞書のクラス名を区別する。直接の `tyCompare` / `tysCompare` は構造的な相互再帰とし、木の比較との一致からeqと生の等号の同値性・全域性・推移性・反対称性を導いた。型と型列の双方を `Std.LawfulEqCmp` / `Std.TransCmp` へ接続した。有限支持は仮定しない。
- `Order/SortUnique.lean` に、比較を保つ写像と挿入・整列の可換性、整列済みの列の固定、連結前の整列の吸収、像での順序逆転と重複を許す写像の前の重複除去の吸収を証明した。整列の定義とL1b1の既存の補題は変えていない。
- `Order/Shift.lean` に、cutoff以降の番号の移動の狭義単調性から `Ty.shift_compare`・型列版・`Ty.sortUnique_shift` を証明した。現在のEff.shiftは恒等であり、この証明はまだFail内の型を扱わない。
- 新しいモジュールを既定ビルドへ登録した。formal/README.mdのファイル表と07-04の基本型の定義先を更新した。01-12の規則と07-04の前提はまだ変えていない。

新しい公理・Builtins.Assumptionsの欄・sorry・admitは追加していない。既存のassert・期待値・ignore・rfl/decideの例は変更していない。Rustと処理系のテストファイルは変更していない。

### 検査と執筆中の修正

途中は対象ファイルを `lake env lean Benitoite/Release/Order/Types.lean` / `Order/Shift.lean` で確認し、接続後は `lake build Benitoite.Release.Order.Shift` を実行した。原子の分離直後には `lake build Benitoite.Release.Syntax Benitoite.Release.Order.Labels` も通した。いずれも最終の局所検査は終了0・警告なしである。途中の外側の時間は計測していない。

執筆中には、利用できない補助名・simpの展開不足・番号の比較の簡約・潜在効果のラベルの単射性の扱い・余分な型クラスの仮定による警告を修正した。構成子が異なる場合の木の比較の一致はrflで先に閉じ、不要なmatchの内部までsimpを進めない形にした。言明を弱める修正はしていない。

`lake env lean /private/tmp/l1b2-audit.lean` による追加確認は終了0（real 0.31秒）であった。10例のうち、新しい比較の構成子順・名前順・型の欄・空の型列・singletonの整列・重複除去等の8例はrfl（または列のcases後のrfl）で確認した。shiftのcutoff境界の2例は `Ty.shift_compare` とrflで確認した。最初に追加確認のshift例も直接rflで試したところ失敗し、`#print Ty.shift` で既存の定義が `@[irreducible]` の整礎再帰であることを確認した。既存の例を書き換えたものではない。後のrawShiftの構造再帰化とFail内部の簡約の確認は未実施である。

同じ追加確認で、型と型列の比較の二クラスを取得でき、主要な7定理の `#print axioms` に `sorryAx` や新しい公理がなく、Lean標準の `propext`・`Classical.choice`・`Quot.sound` の範囲であることを確認した。`#print tyCompare` / `tysCompare` はTyの `brecOn` / `brecOn_1` であり、整礎再帰のfixではない。定義で選択を直接使う箇所は引き続きatomsCompareだけである。

追加確認は本体の新しい比較が簡約できることと、公理・構造再帰の点検を目的とする一時的なLeanファイルであり、処理系の新しいテストは加えていない。新表現のnormが簡約できることの検査や、L1bの完了検査の代用にはしていない。

### 計画からのずれと残り

表現を切り替えた後に順序を接続する予定に対し、現行の共有型へ順序を先行接続して区切った。判断と理由はdecisions.mdのR18（推す案）に記録した。並行する別モデルは加えていない。今回はL1b全体のworkを実行していない。完了時の `formal_build,spec_examples,spec_tally` と同じ基準・指定のdry-runは、続きのL1b2で一度だけ行う。

残りは、Ty/EffRの相互帰納表現Bへの切り替え、Fail内部を含む比較と正規化・shift・代入・一般の合成、R14の整形式とストアWFと保存補題、既存の代入補題群と進行・保存・効果の健全性への接続、R15のLegacy検査と計算できる写し・健全性11件・六入口への接続、01-12の写しと07-04の前提の更新である。今回証明した順序とshiftは、まだ現在のFailを持たない表現についてのものである。

### 次に続ける手順

1. `Release/Types.lean` 内のTy/Effを、l0/statements.md「生の表現と型の全構成子」のTy/EffRへ置き換える。Atomは独立しているため、そのままOrder/Labelsを使える。EffのAPIの既存の等式は、Fail列を含める外延性と必要な正規形・包含の条件へ移す。
2. `Order/Types.lean` のTyの木への写像と直接比較にEffの木・比較を加え、Fail列まで同時に辿る。単射と木の比較との一致を同時再帰に拡張し、今の全順序の証明へ戻す。別のTyモデルを作らない。
3. 構造再帰でTy/EffのnormとrawShiftを実装し、0/1要素で原子の選択に届かないrfl/decideを直接確認する。今回の `sortUnique_eq_self` / `sortUnique_map` / `sortUnique_map_sortUnique` / `sortUnique_append` を使い、正規化の保存・冪等性と比較を保つshiftを証明する。現在の `Order/Shift.lean` はEff側の再帰を加えた証明へ移す。
4. plan.mdのL1b2の残りの順序に従い、代入・整形式・既存証明・Legacyの一時的な拒否と計算できる写しを接続する。R14の範囲外の仮定は加えず、sorryなしでビルドが通る区切りを守る。

### 区切り末の検査

| コマンド・確認 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| formal/で `/usr/bin/time -p lake build` | 0 | 79.67秒 | 一度だけ実行。178 jobs、警告なし。Releaseの性質・Surfaceの健全性・既存例、desugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAllの六入口が成功 |
| `git diff --check` | 0 | 0.01秒 | 空白の診断なし |
| Pythonによる変更文書4件のローカルリンク検査 | 0 | 未計測 | 74件、参照する見出しを含めて成功 |
| ビルド出力とformal/のLeanソースの点検 | 0 | 未計測 | ビルドに警告・エラー・sorryの診断なし。`.lake/`を除く123ファイルにsorry/sorryAx/admitなし |

これは未完の区切りの全体ビルドである。work L1b、Rustの検査、gc-stress、check-formal.shの全比較は実行していない。新表現の型の比較・正規化・整形式・検査器の保証を完了した結果として引用しない。

## L1b2b: 型の操作の構造再帰化（未完の区切り）

**区切りで止めて報告する。L1b2bとL1b全体は未完である。** 今回の開始版は `36913eac5ad55425a22edcc9cb546c7fb8412237`（R18の区切りの取り込み、開始時HEAD）であり、開始時の作業ツリーは空であった。L1b全体のworkの基準は引き続き `b60c306f4f8508d3db595710d2a56aa724eac5b6` である。依頼文の途中の区切りの指示に従い、現行表現の構造再帰化を先行し、既定の全体ビルドがsorryなしで通るところで止める。判断はdecisions.mdのR19（推す案）に記録した。

### できたこと

- `Release/Subst.lean` の `Ty.shift` / `Ty.substAt` を、それぞれ型列の `Ty.shiftTys` / `Ty.substTysAt` と相互再帰にした。四つとも `termination_by structural` を明示し、整礎再帰へ自動的に戻らないようにした。型変数のcutoff・像のshift・型構成子への適用・範囲より外の番号を詰める規則は変えていない。
- `Ty.shiftTys_eq_map` / `Ty.substTysAt_eq_map` を証明し、従来のmap表記へ接続した。ReleaseのTyLemmas・Regularity・Closed・TySubst・TySubstMain・Dict、SurfaceのShiftClean・Invariants・SubstClean・Records、計算できる写しとの等式に、この変換を必要な箇所だけ加えた。型・規則・定理の言明と前提は変えていない。構造再帰の簡約で不要になったDictの `List.map_nil` のsimp引数だけを除いた。
- `Order/Shift.lean` の順序保存を接続した。tvarの形を整えるsimpを先に行い、その後で構造再帰の定義を展開する。全順序やshiftの補題の言明は保った。
- `Release/SubstExamples.lean` に、cutoff付きの入れ子の関数型のshiftと、型構成子への適用・像のshift・番号の詰め直しを含む型代入の二例を加え、既定ビルドへ登録した。いずれもrflである。既存の例の結論・rfl・decideは保った。Surface/Typing.leanの既存のsimpa一箇所には、型列の変換とmapの合成の展開だけを追加した。

Effはまだ名前と行の関数である。新表現・Failの再帰・正規化・整形式の強化・Legacy検査は実装していない。並行する型モデル、公理、Builtins.Assumptionsの欄は加えていない。Rust・現行設計の規則の写し・docs/todo/は変更せず、コミットも行っていない。

### 局所の確認とテストの関門

途中は `lake env lean Benitoite/Release/Subst.lean` / `Order/Shift.lean` と、関係ターゲットだけを直接ビルドした。主な対象は次のとおりである。局所の外側の時間は計測していない。

```sh
lake build Benitoite.Release.Lemmas.TyLemmas Benitoite.Release.Order.Shift
lake build Benitoite.Release.Lemmas.TySubstMain Benitoite.Surface.CheckLemmas
lake build Benitoite.Release.SubstExamples Benitoite.Release.Lemmas.TySubstMain Benitoite.Release.Order.Shift
lake build Benitoite.Release.Lemmas.Closed
lake build Benitoite.Surface.Lemmas.SubstClean Benitoite.Surface.Lemmas.Records Benitoite.Release.Lemmas.Dict
lake build Benitoite.Surface.Lemmas.Records Benitoite.Release.Lemmas.Dict
```

構築中の失敗は、型列の補助がmapと定義上は同じでないために既存のsimp onlyの展開が足りないことと、tvarのsimpの順序によるものであった。上の等式を追加して接続し、不要なsimp引数の警告を整理した。最後の各対象は終了0・警告なしである。既定ビルドで後から見つかった接続漏れについては次節に記す。

test-auditの四問: 守る契約は、計画のR15とR18が求める型の操作のカーネル簡約である。整礎再帰へ戻す退行で二つのrflが失敗する。既存の実行例やsimpによる代入補題は、cutoff付きのこれらの型の操作をrflだけで検査していない。期待値はde Bruijn番号の規則から直接書き、対象の関数で生成していない。テスト専用の本番APIや差し込み口は要しない。既存テストは削除・無効化していない。型の操作と証明・既定ビルドへの登録は差し引き35行増、例の専用モジュールは23行増である（Rustの本体とテストは増減なし）。

追加の二例を `/private/tmp/l1b2b-kernel-old.lean` で開始版のSubst.leanの本文に接続すると、両方ともrflの型不一致で終了1になった。変更後のSubstをimportする `/private/tmp/l1b2b-kernel-new.lean` は終了0であった。この比較の時間は未計測である。Pythonでも、型列の補助を証明済みのmap表記へ戻した後のshift/substAtの全15構成子の本文が開始版と一致することを確認した。

### 区切り末の検査

既定ビルドは終了0を得るまでに二回失敗した。最初はClosedの型列の変換漏れ、二回目は、その依存先のShiftCleanとDictの同じ変換漏れである。失敗箇所と同種の表層の補題を局所ビルドで修正し、最後は古くなった依存先だけをLakeの増分ビルドで確認した。失敗の修正以外の理由で成功した全体ビルドを繰り返していない。外側の時間は `/usr/bin/time -p` のrealである。

| コマンド・確認 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| formal/で `/usr/bin/time -p lake build`（初回） | 1 | 49.22秒 | Closedの型列の変換漏れ。六入口と健全性11件の構築は成功 |
| 同コマンド（Closedの修正後） | 1 | 2.58秒 | ShiftClean・Dictの型列の変換漏れ |
| 同コマンド（残る接続漏れの修正後） | 0 | 15.90秒 | 179 jobs、警告なし。Releaseの性質・Surfaceの健全性・既存例と新しい二例・六実行ファイルを含む |
| formal/で `/usr/bin/time -p lake env lean /private/tmp/l1b2b-final-audit.lean` | 0 | 0.58秒 | 四定義がTyのbrecOn/brecOn_1を使う構造再帰であること、主要10定理の公理への依存を点検 |
| formal/のLeanソースの点検 | 0 | 未計測 | .lake/を除く124ファイルにsorry/sorryAx/admitとaxiom宣言なし |
| `/usr/bin/time -p git diff --check` | 0 | 0.02秒 | 空白の診断なし |

公理への依存の点検は、型列の二つの等式、shift_compare、shift_substAt、HasTypeC.substTy、preservation、CheckToolsのshiftTy_eq/substTyAt_eq、desugar_typed、checkExpr_soundを対象にした。依存はLean標準のpropext・Classical.choice・Quot.soundの範囲である。一時ファイルの執筆中にはSurfaceの名前空間を誤記し、その名前を修正して再実行した。定義や言明を変える修正ではない。

### 残りと次に続ける手順

1. `Release/Types.lean` をl0/statements.mdのTy/EffRへ切り替える。並行する型モデルを作らず、Order/Typesの木・単射・比較へEffとFail列の同時再帰を加える。
2. 今回の型と型列の構造再帰をrawShift/rawSubstAtへ拡張し、EffのFail型への再帰と、束縛下で行の置換像をshiftしてから合流する処理を加える。現在のEff.shift/substAtは旧表現のままである。新しい二例は旧型についての簡約の証拠であり、Fail内部の簡約を確かめたことにはしない。
3. normとCanonical、冪等性・shift/代入との交換・一般の合成・Legacy・意味保存を証明する。R14の整形式・ストアWFとその保存を既存の証明へつなぎ、01-12と07-04を同じ変更で更新する。
4. R15のLegacyの一時的な拒否・計算できる写し・健全性11件・六入口の接続を終える。その時点で、固定したBと `formal_build,spec_examples,spec_tally` のdry-runとwork L1bを一度行う。

今回はL1b全体のwork、Rustの検査、gc-stress、check-formal.shの全比較は実行していない。現行設計の意味は変えていないため、01-12と07-04の更新も表現切り替えの後へ残す。この区切りを新表現の保証の完了として引用しない。

## L1bc1: 一般の代入の接続とR14の障害（設計者に相談）

**設計者に相談する。L1b全体は未完である。** 今回の開始版は `3fa25b2f7bd5f92273cd15b014ecb0589ba01242`（開始時HEAD）であり、開始時の作業ツリーは空であった。L1b全体のworkの基準は引き続き `b60c306f4f8508d3db595710d2a56aa724eac5b6` である。plan.mdにL1bc1という独立した節はないため、依頼文の申し送りどおりL1b2の続きとして扱った。「共通の関門K」は従前と同じ「作業に共通する条件」である。コミットとdocs/todo/の変更は行っていない。

### できたこと

- `Release/SubstEnv.lean` に、列の範囲外では恒等となる行の像、長さを両列の最大値とする行の合成、範囲の前提のない合成の証明を加えた。型変数の像と行置換を `SubstEnv` にまとめ、共有型の構造再帰による `Ty.bind` / `bindTys` と `Eff.bind`、型構成子への適用との可換性、型・効果・型列での合成を証明した。cutoff付きの既存の代入とshiftが、このbindに一致することも証明した。
- `Lemmas/TyLemmas.lean` の既存の `Eff.substRho_comp` は、一般の行の合成と入力に現れる行の像の一致から導く形へ移した。言明と前提は変えていない。`Eff.substRho_nil` は、型・効果の基礎から使うため `Lemmas/TySubst.lean` から `Types.lean` へ移した。定理を削除したものではない。
- 新モジュールを既定ビルドとformal/README.mdへ登録した。一般の合成を先行した判断はdecisions.mdのR20へ記録した。
- R14を既存の整形式の定理へ接続する障害を確認し、R21へ相談事項と候補を記録した。`l1b/regularity-obstruction.lean` は共有する型と型付けの規則を使い、任意の潜在効果へのTy.Leとラムダの型付けを証明する。さらに、R13の正規化をFail列だけに限って、意味上の包含が正規形を前向きにも逆向きにも保存しないことを証明する。新しいTyや実行のモデルは定義していない。

ここまでのbindと合成は、Failを持たない現行の共有型についての証明である。表現B、Fail内への再帰と正規化、R14のWF・ストアWF、R15のLegacy検査、01-12・07-04の規則の変更はまだ行っていない。新しい公理・Builtins.Assumptionsの欄・sorry・admitは加えず、既存の定理の前提や既存例・assert・期待値・ignoreも変えていない。Rustと処理系のテストは変更していない。

### 止まる理由と必要な判断

R14の「Ty.WFに埋め込まれた効果のCanonicalを含める」と「C_Sub/Ty.Leを変えない」を、既存の `Ty.Le.wf` / `wf_rev`・`HasTypeV.wf` / `HasTypeC.wf` へそのまま接続できない。

atomsが空の効果について、空列から `[Unit, Unit]` への包含と、`[Unit, Unit]` から `[Unit]` への包含は成立する。後者二列は同じFailの集合だが、重複列だけが非正規形である。したがって、潜在効果の包含が整形式を両方向に保存するという既存の言明は、新しいWFでは成り立たない。さらに、`V_Lam` と `C_Sub` はUnitを返すだけのラムダに任意の潜在効果を付けられ、その効果は項の注釈・引数には現れない。注釈・環境・ストアのWFを強めるだけでは排除できない。

推す候補は、型付けで得る型の整形式を規則の条件として要求し、計算の最上位の効果と区別する方式である。その場合も `Ty.Le.wf` / `wf_rev` に必要な条件を明示し、保存の利用先まで見直す必要がある。R14の規則を保つという決定を越えるため、今回は実装しない。WFとCanonicalを別述語へ分ける代替案もR14の変更を要する。R21を設計者が決め、関係する定義・言明と計画を直してから再開する。これは依頼文の停止条件による相談であり、文脈の残量による途中の区切りではない。

### 局所の検査と再現

途中は `lake env lean Benitoite/Release/SubstEnv.lean`、`lake build Benitoite.Release.Subst`、`lake build Benitoite.Release.SubstEnv`、`lake env lean Benitoite/Release/Lemmas/TyLemmas.lean` を変更に応じて実行した。最初の生成スクリプトでは作業ディレクトリをformal/と根で取り違えたためファイル作成に失敗し、根で実行し直した。証明の作成中にはgetElem?の長さの証拠の指定、存在量化の簡約、applyToの展開の順序、tappの定義の展開を修正した。言明を変えず、最後は各対象が終了0・警告なしである。局所の外側の時間は未計測である。

障害の再現はformal/で次のコマンドを実行し、終了0・警告なしであった。これはBの全体実装の検査ではない。

```sh
lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1b/regularity-obstruction.lean
```

test-auditの四問: 再現資料が守る独立した条件は、R13の集合としての包含と正規形、R14の整形式、既存の型付け・整形式の定理の両立である。重複列の正規化が包含だけで保存できると仮定する誤りを検出する。既存の例はFailの重複を持たず、この矛盾を確かめない。期待する一要素列はR13から直接書き、包含とラムダの導出は既存の本物の規則から構成した。テスト用の本番APIや差し込み口は加えない。処理系のテストは追加・削除とも0行、Leanの本体・証明・ビルド登録は差し引き207行増、検討用の再現資料は67行増である。

### 再開手順と残り

1. R21について、型付けの規則で型の整形式を要求するか、WFとCanonicalを分けるかを設計者が決める。Ty.Leの補助定理だけでなく、V_Sub・V_Lam・C_SubとHasTypeV/C.wf、PresMainのwf_revの利用先を含めて定義・言明を確定する。未証明の前提として加えない。
2. 前節のR19後の手順へ戻り、共有型そのものをTy/EffRのBへ切り替える。今回のSubstEnvもFail内の再帰、正規化とその合同性、行の像のshiftを含めて拡張する。現在のbind_compを新表現の証明として引用しない。
3. R14の追加判断を反映した整形式と既存の証明、R15のLegacy条件付きの計算できる写し・健全性11件・六入口、01-12・07-04を接続する。L1bを完了した時点で、計画のworkと同じ指定のdry-runを一度実行する。


### 停止時の検査

外側の時間は `/usr/bin/time -p` のrealである。

| コマンド・確認 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| formal/で `/usr/bin/time -p lake build` | 0 | 78.21秒 | 一度だけ実行。181 jobs、警告なし。既存のReleaseの性質・Surfaceの健全性11件・既存のrfl/decideの例・六実行ファイルを含む |
| formal/で `/usr/bin/time -p lake env lean /private/tmp/l1bc1-audit.lean` | 0 | 0.33秒 | 一般の行合成・像の合同性・型の合成・cutoff代入との一致・shiftとの一致の五定理の公理依存を点検。propext・Quot.soundの範囲で、sorryAxや追加の公理なし。bindとbindTysはbrecOn/brecOn_1による構造再帰 |
| `git diff --check` | 0 | 未計測 | 空白の診断なし |
| 変更文書3件のローカルリンク検査 | 0 | 未計測 | 参照するファイルと見出しを確認 |
| formal/のLeanソースとビルド出力の点検 | 0 | 未計測 | .lake/を除く125ファイルにsorry/sorryAx/admitとaxiom宣言なし。既存のAssumptions.leanの説明コメントにあるaxiomの語は宣言ではない |

これは停止時に現行のモデルが保たれていることの確認である。L1bの完了検査ではなく、Bへの移行やR14の障害の解消を示す結果として引用しない。L1b全体のwork、Rustの検査、gc-stress、check-formal.shの全比較は実行していない。


## L1bc2: R21の規則条件と旧表現での証明の接続（未完の区切り）

**区切りで止めて報告する。L1bc2とL1b全体は未完である。** 開始版は `9cca6b8892275a80f6d8fb14cd90c649f6292f4b`（開始時HEAD）であり、開始時の作業ツリーは空であった。L1b全体のworkの基準は引き続き `b60c306f4f8508d3db595710d2a56aa724eac5b6` である。依頼文のR21の決定を受けて再開した。コミットとdocs/todo/の変更は行っていない。

### できたこと

- decisions.mdのR21を設計者の決定へ改めた。`Release/Typing.lean` のV_Lamに作る関数型、V_Sub・C_Subに広げた先の型の `Ty.WF C.length` を加えた。型を変えず最上位の計算のエフェクトだけを広げるC_Effを分けた。この具体化をR22（推す案）に記録した。C_Effは結果の型の整形式を元の導出から引き継ぎ、最上位の効果のCanonicalは要求しない。
- 逆転・変数移動・値代入・ストア拡大・型代入・外側の制約の追加・型の正しさ・閉じた値の形・保存・進行へ新しい規則を接続した。`inv_lam_wf` は元のラムダの関数型のWFを保持し、従来の `inv_lam` の結論はそのまま保った。`ret_value` はC_SubのWFを値の型付けへ移す。`stE_ret` に結果の型のWFを明示し、既存の型付け、継続の枠、ストアの証拠から渡した。
- メソッドの保存にあった `Ty.Le.wf_rev` の利用を除き、具体化して値を代入した本体の型付けと、その本体の範囲条件からWFを得る形へ改めた。包含だけが将来のCanonicalを保存するという性質に頼らない。
- Surfaceの脱糖では既存の `HasType.clean`・`HasBlock.clean` から結果の型のWFを得た。関数と構成子の穴を脱糖する二つの補助定理には、作る関数型のWFを明示して主定理から渡す。呼び出しの頭の補助関係は、関数値の潜在効果を変えず、呼び出しの最上位の効果への包含を保持する。`desugar_typed`、健全性11件、`checkProgram_sound` の言明は保った。
- 01-12の規則の写し、07-04の前提と対応表、design.mdとl0/statements.mdのR21に先行する指定を合わせた。現行設計には、現在のWFが実装する型変数の範囲と契約名の条件だけを書いた。Fail・Canonicalを実装済みとは記していない。
- Model.leanへ、未束縛の型変数を引数に持つラムダを拒む例と、その型変数を束縛した位置で同じラムダを受け入れる例を加えた。変更したLeanファイル内の既存のexampleの命題15件はすべて保ち、既存のrfl/decideも変更していない。

既存の名前付き定理331件の宣言を開始版と照合した。前提が増えたのは `stE_ret`・`HasType.desugar_partialCall`・`HasType.desugar_partialCon` の三つで、いずれも型付けを組み立てる補助定理の結果型のWFである。R21で了承された範囲であり、結論は変えていない。新しい公理・Builtins.Assumptionsの欄・sorry・admitは加えていない。Rustの本体とテストは変更していない。Leanの規則・証明・例の差分は256行追加、153行削除である。

### テストの関門と途中の確認

追加した正負の二例が守る契約は、ラムダで作る関数型がその位置の型変数の範囲を満たすことである。V_LamからWFの条件を落とす退行で否定例が成り立たなくなる。既存のラムダの例は契約名を検査し、この範囲条件を検査していない。型とde Bruijn番号を直接書き、期待値を対象の関数で生成していない。テスト用の本番の差し込み口は加えず、既存のassert・期待値・ignoreも変えていない。

開始版の本物のTyping.leanを `git show HEAD:formal/Benitoite/Release/Typing.lean` で一時ディレクトリへ取り出し、変更していないSubst以下を使ってLeanでコンパイルした。その旧規則では、型パラメータが空なのに引数が `.tvar 0` である同じラムダの導出が得られることを確認した。変更後はModelの否定例がその導出の不在を示し、束縛がある正例も通る。旧導出を変更後の規則へ直接渡す一時的な確認は、追加されたWFの位置で失敗した。いずれも検査用の別のTyモデルは作っていない。

途中は関係ターゲットだけを直接ビルドした。主なまとまりは `Release.Lemmas.Regularity`・`SubstTyping`・`OuterC`、`TySubstMain`、`Theorems`・`Model`、`Surface.Lemmas.Typing`・`BlockSequence`・`CheckLemmas` である。規則を変えた直後の失敗は、構成子の新しい引数、C_Effの逆転の分岐、結果型のWFを渡す箇所の不足であった。機械的な編集で生じた束縛名の誤り、補助名の誤記、作業ディレクトリの取り違えも修正した。証明と接続の修正後は各対象が成功した。途中の外側の時間は未計測である。

### 区切り末の確認

全体のworkの基準と `formal_build,spec_examples,spec_tally` の指定へ `--dry-run` を付け、上の三単位だけが選ばれることを確認した。L1b全体の完了検査の実行とは区別し、今回は同じ単位の実コマンドを直接実行した。外側の時間は `/usr/bin/time -p` のrealであり、rtkは `rtk proxy` でコマンドをそのまま通した。

| コマンド・確認 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| formal/で `/usr/bin/time -p rtk proxy lake build` | 0 | 76.34秒 | 一度だけ実行。181 jobs、警告なし。Releaseの性質、表層の型保存、健全性11件、既存の例と新しい二例、六実行ファイルを含む |
| `/usr/bin/time -p rtk proxy cargo test -q -p benitoite --test spec_examples` | 0 | 8.45秒 | 7件成功、失敗・ignoreなし |
| `/usr/bin/time -p rtk proxy python3 tools/spec-coverage/spec_coverage.py --self-test` | 0 | 0.05秒 | 自己検査成功 |
| `/usr/bin/time -p rtk proxy python3 tools/spec-coverage/spec_coverage.py` | 0 | 0.12秒 | 仕様の集計成功、未記入の初回リリースの完了条件なし |
| formal/で `/usr/bin/time -p rtk proxy lake env lean /private/tmp/l1bc2-audit.lean` | 0 | 0.32秒 | 主要9定理の公理への依存を確認。Lean標準のpropext・Classical.choice・Quot.soundの範囲で、sorryAxや追加の公理なし |
| `git diff --check` | 0 | 0.02秒 | 空白の診断なし |
| Leanソース・ビルド出力の点検 | 0 | 未計測 | sorry/sorryAx/admit・axiom宣言なし。ビルドの警告・エラー・sorryの診断なし |
| 変更文書のローカルファイルへのリンク検査 | 0 | 未計測 | 結果記録を加える前の175リンクを確認。見出しは変更していない |

公理の依存を確認した定理は `inv_lam_wf`・`ret_value`・`HasTypeV.wf`・`HasTypeV.substTy`・`preservation`・`effect_soundness`・`desugar_typed`・`checkExpr_sound`・`checkProgram_sound` である。一時的な監査の初回は、並行していた全体ビルドの完了前に実行して未作成の依存oleanで失敗した。全体ビルドの終了後に順序を直して成功した。定義や定理を変える修正ではない。リンク検査の初回はコード中の記法をリンクと誤認したので、コードを除いて検査し直した。

### 残りと次に続ける手順

今回は文脈の残量による途中の区切りである。R21の範囲外の前提や、結論の弱化を必要として止めたものではない。共有型の表現は依然として `Eff := Atom → Bool` である。表現Bの切り替えを始めて全証明・検査器まで移し、既定ビルドを回復するだけの文脈が残らないため、旧表現でR21の規則を接続した状態で引き継ぐ。

1. **R21の採否は再確認しない。** 決定は記録済みであり、V_Lam・V_Sub・C_SubのWFの条件とC_Eff、それらを使う既存の証明は接続済みである。`inv_lam_wf` と `ret_value` は包含の途中で整形式の証拠を失わない入口として使える。`Ty.Le.wf`・`wf_rev` 自体は、現在のFailのないWFでは成立する従来の言明のままである。表現Bへ替える際に、必要な潜在効果の整形式の条件を明示する。
2. `Release/Types.lean` の共有型そのものをTy/EffRのBへ切り替え、`Order/Types.lean` の木・単射・直接比較へEffとFail列の同時再帰を加える。並行する型モデルは作らない。既存のSubst/SubstEnvはまだFailのない型についての定義と証明であり、新表現の合成を証明したものとして引用しない。
3. normとCanonical、Fail内部へのrawShift/rawSubstAt/bind、束縛下での行の像のshift、正規化の冪等性・意味保存・shift/代入との交換・一般の合成を接続する。R14のWF/VarsIn等とストアWFを強め、今回の規則のWFにCanonicalを含ませる。現行の01-12・07-04はまだFail内部の整形式を記していないので、切り替えと同じ変更で更新する。
4. R15のLegacyの一時的な拒否、計算できる写し、健全性11件、六実行ファイルを移す。L1cのnormWithとFail捕捉の新規則は先取りしない。
5. **L1bを完了した時点**で、固定したBと `formal_build,spec_examples,spec_tally` のdry-runとworkを一度行う。今回はその入口での完了検査、Rustのlib/clippy/fmt、gc-stress、check-formal.shの全比較は実行していない。現在のビルドの成功を表現Bと正規化の保証の完了として扱わない。


## L1bc3: 表現Bの基礎の実装差分を保存し、開始状態へ戻した区切り

**区切りで止めて報告する。L1b全体は未完である。** 開始版は `45482df9f536f1cb3e4fdda9cd880e021c3e4445`（開始時HEAD）であり、開始時の作業ツリーは空であった。L1b全体のworkの基準は引き続き `b60c306f4f8508d3db595710d2a56aa724eac5b6` である。依頼文のR21は開始版ですでに実装済みであり、その採否を再確認していない。コミットとdocs/todo/の変更は行っていない。

### 正式なモデルと継続用差分の区別

今回は共有型をBへ替えて下記の基礎を実装し、関係ターゲットの局所ビルドを通した。しかし、残りの文脈では既存の全証明と六入口まで接続し切る見通しが立たなかった。依頼文の「既定のlake buildがsorryなしで通る区切りに戻す」に従い、**正式なformal/のソースは開始版へ完全に戻した**。正式なモデルはまだ `Eff := Atom → Bool` である。差分を保存したことを、Bへの移行が完了したこととして扱わない。

実装した差分は [representation-b.patch](representation-b.patch) に保存した。これは開始版への一つの差分であり、別のTyモデルや、既存の証明を除いた既定ビルドを追加するものではない。[representation-b-state.json](representation-b-state.json) に開始版、全対象のSHA-256、差分のSHA-256を記録した。差分は94,245バイト、17ファイル、1,635行追加・238行削除である。差分のSHA-256は `8c42146aeced24130b1c200a0b4f2cb59827111bea1d4dbf5cfe07a179debc2e` である。次回は基礎を再実装せず、この差分から続ける。**差分を適用しただけの状態は、既定の全体ビルドを通らない。**

判断と理由はdecisions.mdのR23（推す案）に記録した。01-12・07-04は開始版のモデルに対応する記述を保ち、未接続のBを正式な実装として追記していない。

### 保存した差分でできたこと

- 共有するTypesをTy/EffRの相互帰納表現へ替え、atoms/failsと、両方の欄を要求する外延性を実装した。型と効果の木への写像・単射・直接比較を相互再帰へ広げ、既存の木の全順序から等号・推移性等を導いた。
- NormalizeでTy・型列・Effの構造再帰による正規化、冪等性、Failの所属の保存、Legacyでの恒等、すべての深さでFailが高々一つならCanonicalとなることを証明した。Eff.Subは名前と行の包含と、正規形で比較するFailの所属の包含の連言である。unionとsingleFailは正規化を通す。
- TypeShiftでFail内部までのrawShift、比較の保存、正規化との交換、Canonicalの保存を証明した。公開するTy.shiftも構造再帰とし、rawShift後の正規化との一致を証明した。非正規な型の量0の移動を、元の型との恒等式にしていない。
- TypeSubstで型と行の像を持つSubstEnvと、構造再帰のrawBindを実装した。元のFail型には代入し、選んだ行の像は束縛数だけ移動して合流する。同じ代入を挿入した像へ再適用しない。公開する構造再帰のTy.substAtが、rawBind/rawSubstAt後の正規化と一致することを証明した。
- TypeSubstLemmasで、入力の正規化と置換像の正規化をそれぞれ吸収すること、Ty.norm_substAt・Eff.norm_substAt、効果の包含の保存、Legacyの保存、Legacyの条件のもとで公開するshift/substAtが計算できるraw操作と一致することを証明した。一般のbind_compはまだ証明していない。
- TypingでTy.WF/WFListとEff.WFをFail内部まで広げ、埋め込んだ効果のCanonicalを要求した。最上位のEff.WFは列自体のCanonicalを要求しない。TypeRegularityで型のWFからCanonicalを導いた。Ty.Le.wf/wf_revには、包含だけから得られない潜在効果の整形式を明示した。TypeBoundsのRawWFは正規化前の範囲・契約名の補助述語であり、型付けのWFには使わない。RawWFから正規化後のWF、一般のbind・shift・有限列のsubstAtのWF保存を証明した。
- Basic・Inversion・RenameとSemanticsの定義を新しいAPIへ接続した。fnTy_eqの効果には型引数も代入するEff.substAtを使う。SemanticsでストアWFまで強化したものではない。公開する型の操作をSubstから新しい共通モジュールへ移し、計算できない操作への依存をnoncomputableとして明示した。

新しい公理・Builtins.Assumptionsの欄・sorry・admitは加えていない。正式なソースとテストの最終差分は0行であり、既存のassert・期待値・ignore・rfl/decideの例はすべて開始版のままである。Rustは変更していない。

### テストの関門と局所の検査

[representation-b-audit.lean](representation-b-audit.lean) は、差分を適用した同じ共有モデルだけをimportする局所の確認である。別のTyや実行規則は定義しない。正式なモデルを戻した後の状態では実行せず、次回の差分適用後に使う。

作成時の四問: 守る契約はR15のカーネル簡約と、R13のFail列の整列・重複除去、行の像を束縛数だけ移動して一度だけ挿入する規則である。整礎再帰への退行、像の移動漏れ、像への再代入、和での整列・重複除去漏れで対応するrflが失敗する。旧例はFailを持たず、これらを確かめない。期待する型変数の番号と列は規則から直接書き、対象の関数で生成しない。テスト専用の本番APIは加えない。今回の確認は不具合修正の退行テストではなく、新表現の計画上の条件の確認である。

局所の執筆中は、Order.Types、Normalize、TypeShift、Effect、TypeSubstLemmas、TypeRegularity、TypeBounds、Basic、Inversion、Rename等を直接ビルドした。初期の失敗は相互再帰内のEffRのフィールド参照、simpの展開の順序、利用できない補助名、構成子の新しい欄によるもので、最終の対象はすべて成功した。公開する操作は構造再帰の形を保ち、raw操作後の正規化との一致を別に証明した。

途中の `lake build Benitoite.Release.Theorems` と `lake build Benitoite.Release.Lemmas.Rename Benitoite.Release.Lemmas.SubstTyping` は終了1であった（時間未計測）。Basic・Renameの接続漏れは修正したが、古いSubstEnvに新しい共通定義との重複があることと、残る代入・正規化の証明は未完である。これは新たな公理や設計者の判断を必要とする反例を確認したものではない。修正前の失敗を、正式なモデルを戻した後のビルドの失敗としては記録しない。

以下の最初の二行は、**差分を適用していた局所状態**での実行である。後の開始状態へ検査結果を引用していない。外側の時間は `/usr/bin/time -p` のrealである。

| コマンド・確認 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| formal/で `lake build Benitoite.Release.TypeBounds Benitoite.Release.Lemmas.Basic Benitoite.Release.Lemmas.Inversion Benitoite.Release.Lemmas.Rename Benitoite.Release.Semantics` | 0 | 5.96秒 | 23 jobs、警告なし。[局所ビルドの出力](representation-b-local-build.log) |
| formal/で `lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1b/representation-b-audit.lean` | 0 | 0.33秒 | 9件のrfl、主要12定理の公理の依存、四つの構造再帰の定義を確認。[確認の出力](representation-b-audit.log) |
| 差分を開始版の一時ディレクトリへ適用し、全17ファイルのバイトを保存前と比較 | 0 | 未計測 | 全件一致。新しい信頼する仮定やsorryを追加する差分なし |
| 正式のformal/を開始版へ戻した後の `git apply --check` | 0 | 未計測 | 継続用差分を再適用できる |

公理への依存はLean標準のpropext・Classical.choice・Quot.soundの範囲であり、sorryAxや追加の公理を含まなかった。Ty.norm・Eff.norm・Ty.rawBind・Ty.substAtのprintはbrecOnによる構造再帰であった。定義で選択を直接使う箇所は、従来のatomsCompareだけである。

### 戻した開始状態の区切り末の検査

これはBの局所状態とは別の実行である。正式なformal/の差分が空であることを確認してから、既定の全体ビルドを一度実行した。

| コマンド・確認 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| formal/で `/usr/bin/time -p rtk proxy lake build` | 0 | 9.72秒 | 一度だけ実行。181 jobs、警告なし。既存の証明・例・健全性11件・六入口を含む。[区切り末の出力](l1bc3-boundary-build.log) |
| .lake/を除く正式なLeanソースの点検 | 0 | 未計測 | 125ファイル。sorry/sorryAx/admitとaxiom宣言なし |
| `git diff --check` | 0 | 0.01秒 | 空白の診断なし |
| 追加した結果記録のローカルリンクと差分の保存内容の確認 | 0 | 未計測 | リンク6件、差分17ファイルの件数と行数、SHA-256、三つの出力に警告・エラーがないことを確認。formal/・crates/は開始版と一致 |

今回の正式なソース・仕様の本文・例・対応表は開始版のままであり、Rustの検査・spec_examples・spec_tally・gc-stress・check-formal.shの全比較は実行していない。L1b全体の完了検査のdry-runとworkも実行していない。開始状態の全体ビルドの成功は、Bへの移行の保証には使わない。

### 残りと次に続ける手順

1. 開始版と、今回の正式なformal/の差分が空であることを確認する。リポジトリの根で `git apply --check docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1b/representation-b.patch` の後、同じパスを `git apply` へ渡す。別の開始版に移っていれば先に差分を比較する。開始版とSHA-256はstate.jsonにある。R21を再確認せず、基礎の定義を作り直さない。
2. まずTypeBoundsとBasic/Inversion/Rename/Semanticsの局所ターゲットを作り、上のauditを実行できる状態にする。差分だけでは既定ビルドが通らないことを前提に、旧SubstEnvからTypeSubstへ移した定義の重複を整理する。`SubstEnv.shift` もTypeSubstへ移動済みである。一般の合成はTypeSubstに定義だけがあり、`bind_comp`・行の合成の全証明はまだ必要である。
3. TypeRegularity/TypeBoundsへ移したWFの補題と、TyLemmas/Regularityの同名の旧補題を整理し、既存の代入補題群へ新表現の証明を接続する。Ty.substAt_wf・Ty.subst_wfは新しいEff.WFの行の像の条件を明示している。呼び出し側はFail内部を含む範囲の保存から導き、外部の仮定を増やして通さない。元の無条件の恒等式を非正規な入力へ適用しない。
4. Fail内部のTy.VarsIn・Eff.RhosIn等、NamesWF・ClosedNoEffVars・Supportとその保存、LocTy/StoreTyの継続の効果のWFとCanonical、既存の進行・保存・効果の健全性をつなぐ。Semanticsの差分はnoncomputableの指定だけで、ストアWFの強化は未実装である。最上位の効果にCanonicalを要求しない。
5. R15のLegacy入力の一時的な拒否と、計算できる写しの条件付きの一致を健全性11件・六入口へつなぐ。rawShift/rawSubstAtは計算でき、Legacyのもとで公開操作と等しいことは上の補題で得られる。既存の写しと結ぶか、これらへ定義を接続するかを最小の変更で選ぶ。L1cのnormWithやFail捕捉の新規則は先取りしない。
6. Bを正式なモデルとして接続した同じ変更で01-12と07-04を更新する。既存の全性質・例・六入口を含む既定ビルドをsorryなしで回復し、L1bを完了した時点で、固定したBと `formal_build,spec_examples,spec_tally` のdry-runとworkを一度行う。

正式な状態の文書と差分を保存した時点での区切りであり、設計者への新しい相談による停止ではない。Builtins.Assumptionsの追加、了承済みのR14/R21の範囲外の前提の追加、結論の弱化を認める判断はしていない。

## L1bc4: 行置換の一致条件の反例を確認し、設計者へ相談

**設計者に相談。L1b全体は未完である。** 開始版は `9e77334c1fc3bbd71c965c2471450fca78355bdd`（開始時HEAD）であり、開始時の作業ツリーは空であった。L1b全体のworkの基準は引き続き `b60c306f4f8508d3db595710d2a56aa724eac5b6` である。R21は開始版へ反映済みであり、採否を再確認していない。コミットとdocs/todo/の変更は行っていない。

### 確認した停止条件

R23の保存差分を再適用した。開始版のformal/が差分の作成元 `45482df9f536f1cb3e4fdda9cd880e021c3e4445` と一致することと、`git apply --check` の成功を確認してから適用した。TypeBoundsまでの局所ビルドを通し、旧SubstEnvの重複と補題の移行を調べたところ、既存の `Eff.substRho_congr_rows` の前提だけでは表現Bの結論が成り立たないことを確認した。

反例は `e = Fail[() → Unit ! ρ0]`、`es = [∅]`、`fs = []` である。最外に行はないので、既存の `∀ i, Eff.mem e (.rho i) → Eff.rowImage es i = Eff.rowImage fs i` は満たす。eはEff.WF 0とCanonicalを満たし、唯一の置換像の∅も整形式で正規形である。それでも代入結果のFail型は、左では潜在効果にρ0を持たず、右では持つ。

[row-congruence-obstruction.lean](row-congruence-obstruction.lean) に、同じ共有モデルの既存の型・代入だけを使う再現を追加した。既存の一致条件、WF、Canonical、左右の内部のρ0の所属、不一致、WFとCanonicalを加えた旧言明の否定を証明した。主要な否定の証明の公理への依存はLean標準のpropext・Classical.choice・Quot.soundの範囲であった。

これは、型と行の同時代入がFail型の内部にも再帰するという決定と、最外のEff.memだけを使う既存補題との不一致である。WFとCanonicalの追加だけでは直らない。最外だけの一致条件を再帰的に現れる行にも要求することは、整形式以外の既存定理の前提の強化なので、依頼文の停止条件に従って止めた。推す案と代替案をdecisions.mdのR24へ記録し、採用済みとはしていない。

### 追加した確認の関門と途中の修正

test-auditの作成時の四問: 守る契約は、行置換の結果が一致すると結論できる条件である。Fail型の内部の行を見落とすと、具体例の左右が等しいという誤った主張を許してしまう。旧表現にはFailの型を保持する欄がなく、既存の例もこの前提不足を確かめない。既存の補題を使う証明は触らず、共有モデルの公開するsubstRhoの結果で反例を示した。新しい本番APIや別の代入モデルは加えていない。不具合修正の退行テストではなく、移行する言明の成立条件を調べる資料である。

初回の再現では、左右の効果の全体を具体的な効果とrflで等置しようとして失敗した。原子の関数が外延的に等しくても、定義上の等号とは限らないためである。必要な観察である内部のρ0の所属をrflで確かめ、結果全体の不一致は等号からその所属の等号を導いて示す形へ直した。反例の入力、旧補題の前提、不一致の結論は変えていない。

### 検査と最終状態

以下の最初の二行は保存差分を適用していた局所状態、三行目以降は正式なformal/を開始時HEADへ戻した状態である。局所状態の結果を最終状態へ引用していない。外側の時間は `/usr/bin/time -p` のrealである。

| コマンド・確認 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| formal/で `rtk proxy lake build Benitoite.Release.TypeBounds` | 0 | 未計測 | 18 jobs。保存差分のTypeBoundsまでの依存を確認 |
| formal/で `/usr/bin/time -p rtk proxy lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1b/row-congruence-obstruction.lean` | 0 | 0.32秒 | 修正後の反例の全証明が成功。公理の追加・sorryなし |
| formal/で `/usr/bin/time -p rtk proxy lake build` | 0 | 9.29秒 | 一度だけ実行。181 jobs、警告なし。既存の証明・例・健全性11件・六入口を含む。[出力](l1bc4-boundary-build.log) |
| `git diff --exit-code HEAD -- formal crates docs/design` | 0 | 未計測 | 正式なソース・テスト・現行設計は開始時HEADと一致 |
| `git apply --check` に保存済みrepresentation-b.patchを指定 | 0 | 未計測 | 戻した状態へ引き続き再適用できる |
| .lake/を除くLeanソースの点検 | 0 | 未計測 | 125ファイル。コメントを除きsorry/sorryAx/admit・axiom宣言なし |
| `/usr/bin/time -p rtk proxy git diff --check` | 0 | 0.01秒 | 空白の診断なし |
| 追加した記録のローカルリンクと出力の確認 | 0 | 未計測 | 3リンクの実在、再現資料のsorry不在、全体ビルドの成功と警告・エラーの不在を確認 |

途中にはTypeBoundsとBasic/Inversion/Rename/Semanticsの局所ターゲットをまとめたビルドも開始したが、その呼び出しの終了状態は取得していない。成功の証拠には数えず、上のTypeBoundsの終了0と、復元後の既定ビルドを記録した。ソース点検の初回はコメント中の `axiom` の説明も検出したため、コメントを除いて再確認した。

正式なformal/は保存差分の逆適用で開始状態へ戻した。既存のassert・期待値・ignore・rfl/decide・定理・Builtins.Assumptionsは変更していない。処理系と正式なテストの最終差分は0行である。01-12・07-04に未接続のBを書き加えていない。

L1bが未完のため、planの完了検査である `formal_build,spec_examples,spec_tally` のdry-runとworkは未実施である。今回の最終差分は文書と再現資料だけなので、Rustのlib・統合・clippy・fmt、gc-stress、check-formal.shは実行していない。既定ビルドの成功をBの移行完了の証拠とはしない。

### 残りと再開手順

1. R24の一致条件の強化を認めるか、設計者が判断する。R21を再確認する必要はない。
2. 保存済みrepresentation-b.patchをcheck後に再適用し、TypeBoundsをビルドしてから今回の反例を実行する。反例は旧言明の移行を調べる資料なので、正式な旧表現のままでは実行しない。
3. R24を採る場合は、行の出現と像の一致をFail型の内部まで再帰させる。旧SubstEnvとTypeSubstの重複を整理し、`Eff.substRho_comp` では再帰化したRhosInから一致条件を導く。Releaseの保証をLegacyだけへ制限しない。
4. 以後の既存証明・ストアWF・R15の検査器と六入口・01-12と07-04の更新・L1b完了時の一度の検査は、L1bc3の続行手順のままである。

## L1bc5: 一般の合成とReleaseの主要三性質の移行（未完の区切り）

**区切りで止めて報告する。L1b全体は未完である。** 開始版は `daadf1c32d2f50fad940dea9f8471d7437506357`（開始時HEAD）であり、開始時の作業ツリーは空であった。L1b全体のworkの基準は引き続き `b60c306f4f8508d3db595710d2a56aa724eac5b6` である。依頼文で決定済みのR24をdecisions.mdへ反映し、R21を再確認せずに続行した。コミットとdocs/todo/の変更は行っていない。

### できたこと

保存されていた17ファイルの差分をcheck後に再適用し、同じ共有Ty/EffR上で次の接続を進めた。新旧二つの型モデルは作っていない。

- `TypeRows`・`TypeComposition`: Fail内部の潜在効果まで行の範囲を再帰する。R24の `Eff.substRho_congr_rows`、型・型列・効果の一般の `bind_comp`、範囲外を恒等像で補う行の合成を証明した。生のFail列の順序・重複は、意味上の所属と正規形の一意性で扱う。Legacyだけへ制限していない。
- `SubstEnv`・`TypeCongruence`・`TypeScopedSubst`: 移動済みの定義の重複を除き、一般の代入からcutoff付きの合成、閉じた型の恒等性、型と効果のshift・代入の交換を導いた。行の像のFail型にも閉性を要求する。型代入を合成するときの行の像も同時に型代入する。判断はR25・R26に記録した。
- `TypeVariables`・`WellFormed`: Ty.VarsIn・新しいEff.VarsInはFail内部の型変数と行をともに検査する。型の潜在効果にはCanonicalを要求し、最上位の効果には要求しない。宣言の効果と項の行引数も接続した。WF・行の範囲・単調性・正規化による保存を証明した。
- `TyLemmas`・`Regularity`・`Closed`・`TySubst`・`TySubstMain`: 基礎へ移した同名の旧補題を整理し、型付けの結果の整形式、項の閉性、型・行の同時代入による型付け保存を接続した。既存の等号を包含へ弱めていない。
- `Typing`・`Semantics`と継続・辞書の補題: メソッドの効果も型引数で具体化し、節の型パラメータを束縛するときは外側の効果もshiftする。節が構築する継続型とlet枠の環境の型の整形式を明示した。ストアの継続の効果にはWFとCanonicalを要求し、捕まえた継続の型へ効果を正規化して保存する。実装のメソッドの効果にも型クラスの対象の代入を接続した。判断はR27〜R30である。
- `PresMain`・`Progress`・`EffectSound`: 進行・保存・エフェクトの健全性を含む `Release.Theorems` の局所ビルドを回復した。`Assumptions.lean` と `Theorems.lean` 自体の差分は空であり、Builtins.Assumptionsの欄と主な定理の言明は保った。整形式・状態の型付け・ストアWFの意味の強化はR14/R21の範囲である。

Surface・Coverage・交換の六入口への接続はまだ終えていない。残る文脈でそれらと写しの更新を終え、既定の全体ビルドを回復する見通しが立たなくなったため、依頼文の保存差分の方式で区切った（R31）。表現Bの進捗を正式なformal/へ未接続のまま残していない。

### 保存差分と局所の検査

[representation-b.patch](representation-b.patch) を今回の開始版に対する40ファイル（既存28・新規12）、332088バイトへ更新した。SHA-256は `21c7cbcfd583aa2cdaa2a6f98f9339dc9cd22eced400575e69c91435c2003b47` である。[state.json](representation-b-state.json) に開始版・ファイル一覧・各ファイルのSHA-256を保存した。以前の17ファイルの差分を置き換えているので、再開時は本節と新しいstate.jsonを使う。

開始版の対象ファイルを一時ディレクトリへ読み出して差分を適用し、全40ファイルが保存前の内容とバイト単位で一致することを確認した。正式なformal/は同じ差分の逆適用で開始時HEADへ戻し、再適用の `git apply --check` の成功も確認した。

途中は関係するLeanターゲットだけを直接ビルドした。執筆中の主な失敗は、移動済み宣言の重複、正規化前の恒等式、同時代入での行の像の扱い、束縛数を加えるときの効果のshift、型付けで構築する環境のWF、simpの展開順序・関数の部分適用・構造再帰の認識によるものであった。R24〜R30の範囲で修正し、下表の局所ターゲットは警告なしで通した。途中の外側の時間は計測していない。

一度、リポジトリの根からlakeを呼んで作業ディレクトリを誤り終了1になった。また、局所ビルドの記録先の相対パスを根から指定してリダイレクトに失敗し、コマンドを実行できなかった。いずれもformal/で実行し直した。実行していない呼び出しを検査の成功に数えていない。

次の三行は、**保存差分を適用していた状態**での確認であり、復元した正式モデルへ結果を引用していない。外側の時間は `/usr/bin/time -p` のrealである。

| コマンド・確認（formal/） | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `lake build Benitoite.Release.Theorems` | 0 | 0.48秒 | 最終の増分確認、50 jobs。進行・保存・エフェクトの健全性を含む。[出力](l1bc5-local-build.log) |
| `lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1b/representation-b-audit.lean` | 0 | 0.36秒 | 既存の9件のrflと構造再帰の確認を変更せず実行。[出力](l1bc5-kernel-audit.log) |
| `lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1b/l1bc5-axioms.lean` | 0 | 0.34秒 | 合成・整形式・主な定理16件の公理への依存を確認。[確認ファイル](l1bc5-axioms.lean)、[出力](l1bc5-axioms.log) |

公理への依存は16件ともLean標準のpropext・Classical.choice・Quot.soundだけであった。差分を適用した137ファイルにsorry/sorryAx/admitとaxiom宣言はなかった。既存のassert・期待値・ignore・rfl/decideの例は削除・変更していない。新しい退行テストは加えず、既存の確認をそのまま実行した。

途中の `lake build Benitoite.Surface.CheckSound` は終了1である。[未接続箇所の出力](l1bc5-surface-blockers.log) に残した。主な先頭の失敗はCoverage.leanのsubstTys（59行）のTy.applyToへの非計算的な依存と、substTys_eq_substの証明（89行以降）である。これは途中の調査の出力であり、保存差分全体の最終検査ではない。Coverage全体をnoncomputableにして六入口から外す修正はしていない。

### 戻した開始状態の区切り末の検査

正式なformal/の差分が空であることを確認してから、既定の全体ビルドを一度実行した。

| コマンド・確認 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| formal/で `/usr/bin/time -p rtk proxy lake build` | 0 | 22.85秒 | 181 jobs、警告なし。既存の証明・例・健全性11件・六入口を含む。[出力](l1bc5-boundary-build.log) |
| `git diff --exit-code HEAD -- formal crates docs/design` | 0 | 未計測 | 正式なソース・テスト・現行設計は開始時HEADと一致 |
| 更新した保存差分を `git apply --check` へ指定 | 0 | 未計測 | 引き続き再適用できる |

空白と記録のリンク・ハッシュ・出力も点検した。通常のgit diff --checkの初回は保存差分の空の文脈行とhunk見出しの末尾の空白を検出したため、その差分の記法だけを整えた。開始版への再適用と全40ファイルのSHA-256一致を再確認し、通常のgit diff --checkも終了0になった。文書のローカルリンク80件と成功出力4件の警告・エラーの不在を確認した。復元後の正式なLeanソース125ファイルにもsorry/sorryAx/admitとaxiom宣言はない。正式なソースとテストの最終差分は0行である。01-12・07-04はBを正式に接続した同じ変更で更新するため、今回は開始版のままである。Rustのlib・統合・clippy・fmt、spec_examples・spec_tally、gc-stress、check-formal.shの全比較は実行していない。L1b全体の完了検査のdry-runとworkも未実施である。開始状態の全体ビルドの成功を、Bの移行完了や新機能の証拠にはしない。

### 残りと再開手順

1. 正式なformal/が開始版と一致することを確認し、更新した保存差分へ `git apply --check` の後、同じ差分を適用する。今回の差分は40ファイルであり、以前の17ファイルの基礎を作り直さない。R21・R24を再確認しない。
2. `Release.Theorems` までが今回の局所ビルドの成功範囲である。新しい補題はTypeRows・TypeComposition・TypeCongruence・TypeScopedSubst・TypeVariablesにあり、既存のReleaseの補題群から接続している。Assumptions/Theoremsのファイルの言明は変えていない。R25〜R30と、今回の局所の確認を先に読む。
3. CoverageのsubstTysとその一致の補題を、R15の計算できる写しと接続する。Legacyでの条件付き等式はTypeSubstLemmasのrawShift/rawSubstAtとの一致を使える。数学上の新しいTy.applyToを計算する入口へ残すこと、Coverage全体をnoncomputableにして実行対象から逃がすこと、網羅性の主な定理を弱めることは避ける。
4. Surfaceの型付け・脱糖・既存の証明を、同時代入・節の効果のshift・節の継続型とlet枠の環境のWF・実装のメソッドの効果へそろえる。R15の入力全体のLegacy検査と、計算できる写しの条件付きの一致を健全性11件・六入口へ接続する。L1cのnormWithやL2のFail捕捉を先取りしない。
5. NamesWF・ClosedNoEffVars・Supportの残る読者と再帰的な条件、正規化による保存を点検する。Ty.VarsIn/Eff.VarsInとRelease側の項の閉性は移行済みだが、Surface/交換の対応や全体の有限支持の接続は今回の成功範囲に含まない。
6. Bを正式に接続した同じ変更で01-12・07-04と必要なファイル表を更新する。既存例・健全性11件・六入口を含む既定ビルドをsorryなしで回復し、L1b完了時に固定したBと `formal_build,spec_examples,spec_tally` のdry-runとworkを一度だけ行う。

<a id="l1bc6-resume"></a>

## L1bc6: 網羅性と計算する検査本体への接続（未完の区切り）

**区切りで止めて報告する。L1b全体は未完である。** 開始版は `3ac2063d3cfa95f98f3a25f452de772d887fbeb5`、開始時の作業ツリーは空であった。L1b全体のworkの基準は引き続き `b60c306f4f8508d3db595710d2a56aa724eac5b6` である。R21・R24は決定済みとして続行し、再確認していない。コミットとdocs/todo/の変更は行っていない。

### できたことと保存した差分

L1bc5の40ファイルの保存差分をcheck後に再適用した。次の接続を加え、[representation-b.patch](representation-b.patch) を54ファイル（既存38・新規16）、408693バイトへ更新した。SHA-256は `3fa67737594dcb90afa2b4a7cd93379dbfe2099b9157f93bef5d123b93f38880` である。[state.json](representation-b-state.json) に開始版・ファイル一覧・各ファイルのSHA-256を保存した。開始版から対象を読み出した一時ディレクトリへの再適用後、全54ファイルのSHA-256一致を確認した。以前の40ファイルの差分を置き換えている。

- `Release/CoverageTypes`・Coverage・CoverageExtension: 計算用の型代入を同じ共有型のrawSubstAtへ接続した。潜在効果を消した型の等しさから値の所属を移す証明を置き、一般の網羅性の主定理の前提・結論を保った。Legacyのもとでの公開する代入との等式も残した。判定をnoncomputableにして六入口から外していない。判断はR32。
- `Release/TypeSupport`: 型・型列・効果・Fail内部の型を再帰する支持の条件を加え、正規化・shift・型と行の同時代入による保存を一般の入力について証明した。従来のCheckTools.AtomsInの最外の原子の条件とは別に置いた。後のnormWithへの接続はこの再帰的な支持を使う。
- `Release/LegacyCheck`・Surface/CheckTools: 型と潜在効果を辿る計算できるLegacy検査と、その仕様との同値性を証明した。shiftTy・substTyAt・applyToTy・shiftEff・substEffAtをraw操作へ接続し、正規化する数学上の操作との等式にLegacyを明示した。原子集合の保存はLegacyへ制限せず証明した。型の等しさの判定の成功から両側のLegacyを導く補題も加えた。判断はR33。
- Surface/CheckPredicates・CheckPatterns・CheckSupport: 型の整形式の判定の成功はLegacyとWFを意味する。構成子の型引数と宣言の欄を検査し、計算用の代入の等式の条件を成功から取り出す。型の結びには両側の効果のLegacyを検査する。diffEffは名前を除いても元のFail列を保持し、包含と単調性の結論を保つ。判断はR34。
- Surface/Typing・Check: メソッドの効果も型と行の同時代入へ移し、節の継続型と許容エフェクトにはshiftを、実装メソッドの効果には対象型の代入を使った。検査本体Checkは計算できるままビルドできる。既存のTypingの例は入力と結論を保ち、包含の証拠と空代入の証明だけを直した。
- `Release/Lemmas/VariableBind`・Surface/Lemmas/ShiftClean: 開いた型・行の像からの代入後のVarsInを証明した。ShiftCleanはFail内部も再帰して移動し、正規形を保つ。VariableBindの各補題は局所ビルド済みだが、Invariantsの旧subst_cleanへの接続は未完である。

新旧二つの型モデルは作っていない。CoverageTypesのeraseは同じTy上の証明用の写像であり、実行時の型や別の網羅性判定を追加するものではない。ReleaseのAssumptions.leanとTheorems.leanの差分は空である。Builtins.Assumptionsの欄、公理、sorry、主な定理の結論の弱化は加えていない。

### 局所の検査と途中の修正

以下は**保存差分を適用していた状態**の確認であり、復元後の正式モデルへ結果を引用していない。外側の時間は `/usr/bin/time -p` のrealである。途中は変更に関係するLeanターゲットだけをビルドした。

| コマンド（formal/） | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `lake build Benitoite.Release.Theorems Benitoite.Surface.Check Benitoite.Release.CoverageExtension Benitoite.Release.Lemmas.VariableBind` | 0 | 0.16秒 | 最終の増分確認、65 jobs、警告なし。[出力](l1bc6-local-build.log) |
| `lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1b/l1bc6-audit.lean` | 0 | 0.32秒 | [確認ファイル](l1bc6-audit.lean)。Legacy制限、Fail内部の計算、一般の値の所属の接続7件と公理の依存9件。[出力](l1bc6-audit.log) |
| `lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1b/representation-b-audit.lean` | 0 | 0.29秒 | 既存の9件のrflと構造再帰の確認を変更せず実行。[出力](l1bc6-kernel-audit.log) |
| `lake build Benitoite.Surface.CheckSound` | 1 | 0.46秒 | 未接続の先頭はCheckLemmas。[出力](l1bc6-sound-blockers.log) |
| `lake build Benitoite.Surface.Theorems` | 1 | 4.11秒 | 未接続の先頭はLemmas/Invariants。[出力](l1bc6-desugar-blockers.log) |

test-auditの作成時の四問: 守る契約はR15の入力の制限と、Fail内部の型代入・shiftの計算可能性、一般の網羅性の型代入と値の所属の接続である。潜在効果の内部のFailを見落とす、効果の型変数を置き換えない、網羅性の保証をLegacyだけへ制限する変更を検出する。既存の旧入力の例にはFailを持つ型がないため、その対照だけを確認資料へ追加した。本番で使う共有型と検査の入口を使い、テスト専用のAPIは加えていない。既存のテストは削除・ignore・期待値の緩和をしていない。今回の7件はR15等の移行条件の確認であり、改造前に不具合があったと主張する退行テストではない。

執筆中は、型の略称Effと実体EffRの名前空間、効果の包含が連言になった箇所、構造再帰の子の指定、raw操作と正規化の違い、simpの展開順序、原子の関数の定義上の等号を修正した。新しい確認の初回は、生の効果全体をrflで等置したため失敗した。等号の結論は保ち、原子は構成子ごとのrflと外延性、Fail列はrflで示す形へ直した。存在しない名前空間の参照も修正した。Checkの節だけを直すべき一括置換がラムダの許容効果も変えていた箇所は、そのラムダの行を元へ戻した。最終の成功は上表で確認した範囲に限る。

今回確認した9件の公理への依存はLean標準のpropext・Classical.choice・Quot.soundだけである。差分を適用した141ファイルのLeanソースを、入れ子のコメントと文字列を除いて点検し、sorry/sorryAx/admitとaxiom宣言がないことを確認した。

### 復元した正式な状態

正式なformal/は保存差分の逆適用で開始時HEADへ戻した。`git diff --exit-code HEAD -- formal crates docs/design` と保存差分の `git apply --check` はいずれも終了0であった。復元後に既定の全体ビルドを一度だけ実行した。

| コマンド（formal/） | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `/usr/bin/time -p rtk proxy lake build` | 0 | 30.83秒 | 181 jobs、警告なし。既存の証明・例・健全性11件・六入口を含む。[出力](l1bc6-boundary-build.log) |

01-12・07-04の写しは、Bを正式に接続した同じ変更で更新するため、開始版のままである。Rustは変更していない。Rustのlib・統合・clippy・fmt、spec_examples・spec_tally、gc-stress、check-formal.shの全比較は実行していない。L1b全体の完了検査 `formal_build,spec_examples,spec_tally` のdry-runとworkも未実施である。復元後の成功をBの移行完了の証拠にはしない。区切りの判断はR35へ記録した。

### 次に続ける手順

1. 新しいstate.jsonと本節を使う。開始時HEADのformal/が今回の開始版と一致すること、保存差分の `git apply --check` を確認して再適用する。40ファイル版から基礎を作り直さない。R21・R24の再確認も不要である。
2. CheckToolsまではLegacy付きの等式と一般の原子保存が通り、Check本体まで計算できる。次はCheckLemmasを移す。旧い関数全体の無条件の等式 `shiftTy_fun_eq` 等を、実際に使う型・環境・並びのLegacyを条件とする等式へ直し、条件を検査の成功から受け渡す。健全性11件やInput.Soundの外部の前提にLegacyを追加して済ませない。wfTy_spec/wfTys_specは成功からLegacyとWFの組を返すため、旧利用側は必要な証拠をそれぞれ取り出す。unionの包含の補題もFailの所属とLegacyの条件を扱う必要がある。型引数と効果を持つすべての入力・宣言の入口のLegacy検査は未完である。
3. 次にInvariantsを移す。旧clean_leは包含だけから移動先の潜在効果のVarsInとCanonicalを導こうとして失敗する。R21の条件をSurfaceの型付け・範囲・構築する型へつなぎ、任意の効果に正規形を仮定しない。旧subst_cleanは行の像を無条件に受け取っている。新しいRelease/Lemmas/VariableBindのTy.subst_clean・Eff.subst_cleanは、開いた型と行の像のVarsInを条件に、正規化後の結果を証明済みである。この補題を使い、Surface.WellFormedのEff.RhosInだけの旧箇所をR14のEff.VarsInへ広げ、効果の型の範囲を導く。EnvCleanの継続のshiftでは効果もshiftする。最上位の効果にCanonicalを求めない。
4. SurfaceのHasClausesは節の内部の効果をshiftする形へ移行済みである。HasType/HasBlockの不変条件・脱糖の型保存・checkClauses/checkMethodsの健全性を同じ形へそろえる。必要なら07-04に列挙するR21の整形式の条件を具体化する。主な定理の新しい前提、公理、Builtins.Assumptionsの追加や、既存の結論の弱化はしない。
5. SurfaceCheck/Batch・Exchange/Convertと六入口を接続する。L1cのnormWithとL2bのFailの捕捉は先取りしない。Coverageの一般の健全性は今回接続済みであり、Legacyへ制限しない。
6. Bを正式に接続した同じ変更で01-12・07-04を更新する。既存の例・健全性11件・六入口を含む既定ビルドをsorryなしで回復し、L1b完了時に固定したBとplanの名指しのdry-runとworkを一度だけ行う。

記録末の確認として、変更文書のローカルリンク90件の参照先、保存差分のハッシュと再適用した全54ファイルのハッシュ、成功出力4件の警告・エラーの不在、正式なソースの差分の不在と再適用のcheckを確認した。`git diff --check` も終了0であった。

<a id="l1bc7-complete"></a>

## L1bc7: 表現Bの正式な接続とL1bの完了

計画で固定した作業全体の基準Bは `b60c306f4f8508d3db595710d2a56aa724eac5b6`、今回の開始時HEADは `e12129bad43c3a5ec31dbe95e4013b3f5b20120e` である。開始時の作業ツリーは空で、正式なformal/が前回の保存前の開始版と一致することを確認し、54ファイル版の保存差分を適用した。R21・R24の決定に従い、未接続だった部分から再開した。コミットとdocs/todo/の変更は行っていない。

### 変更と完了した範囲

- 保存していた表現B、型・効果の正規化と一般の同時代入、整形式とストアWF、Releaseの既存の証明を正式なformal/に接続した。型・効果の構造再帰、正規化の所属保存・冪等性・shift/代入との交換、Fail内部の再帰的な範囲と支持を保つ。Coreは変更していない。
- Surfaceの型の構築・包含と範囲条件をR21の整形式へ接続した。ラムダと部分適用の潜在効果、穴の引数と包含の移動先、節の継続を組み立てるときのWFを具体化した。行の像にもFail内部を含む範囲を要求し、既存のbind_cleanから脱糖の型保存を証明した。メソッドの効果には型と行の同時代入、実装の本体には対象型の代入を使う。
- CheckLemmasから健全性11件、全プログラムの健全性へLegacyと整形式の証拠を接続した。受け入れと結びの移動先の型はcleanTyで検査する。型・効果・使わない注釈・環境・戻り先・有限の宣言材料を再帰検査し、参照する外部の宣言も検査する。成功から条件を取り出し、健全性の外部の前提へ追加していない。入力の注釈の正規化で元のプログラムを置き換えてはいない。
- Exchange.Convertの実装メソッドの型と効果は、Legacyを検査してから計算できるraw代入を使う。SurfaceCheck.Batchの既存のsubstTyAtも同じ写しを使う。六実行ファイルに数学上の非計算的な操作を残していない。参考用のRelease.Examples.execだけにnoncomputableを明示し、既存のdecide/rflによる確認を保った。
- 01-12・07-04の写し、前提の一覧と対応の説明、formal/README.mdの構成を同じ変更で更新した。未接続の失敗の構文・捕捉と一般の計算できる正規化は、実装済みとして説明していない。

Release.Theorems・Surface.Theorems・Surface.CheckSoundとRelease.Assumptionsの各ファイルに差分はない。主要定理の言明を保ち、Builtins.Assumptionsの欄や公理を足していない。既定ビルドから証明・例・実行ファイルを除外していない。

### 検査と結果

執筆中は、変更に関係するLeanターゲットだけを直接ビルドした。初めの接続成功の記録は [脱糖](l1bc7-desugar-build.log)（0.68秒）と [健全性](l1bc7-sound-build.log)（0.77秒）にある。その後に入力全体の検査と例を追加したため、この二つを最終状態へ引用せず、最終状態は下表のworkで確認した。途中の主な失敗は、Failの包含が連言になった箇所、正規化前の恒等式、raw操作との条件付き等式、節の環境と効果のshift、型の構築の整形式、相互再帰の展開とsimpの順序によるものであった。R36〜R39の範囲で証拠と補助補題を修正し、主要定理の言明と具体例の結論を保った。一括編集の一時的な構文誤り、作業ディレクトリを誤った呼び出しも修正し、失敗を成功に数えていない。

外側の時間は `/usr/bin/time -p` のrealである。最終のworkは、同じ基準・名指しのdry-runの後に一度だけ実行した。

| コマンド（特記以外はリポジトリの根） | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `scripts/check.sh --level work --base b60c306f4f8508d3db595710d2a56aa724eac5b6 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.02秒 | [選択](l1bc7-work-dry-run.log)。分類を使わず計画の三単位だけを選択 |
| 同じ指定から `--dry-run` を外して実行 | 0 | 16.40秒 | [出力](l1bc7-work.log)。spec_tallyの自己検査と集計、仕様例7件、sorryを拒む既定のlake buildが成功。六実行ファイルと全証明・既存例を含む |
| `python3 -B formal/tests/test_named_exchange.py` | 0 | 3.67秒 | [出力](l1bc7-named-exchange.log)。12件、六入口の名前付きの独立入力 |
| `python3 -B formal/tests/test_try_exchange.py` | 0 | 5.72秒 | [出力](l1bc7-try-exchange.log)。8件、既存try/dieの独立入力 |
| `python3 -B formal/tests/test_extensible_exchange.py` | 0 | 8.02秒 | [出力](l1bc7-extensible-exchange.log)。22件、旧版の互換入力と本体ごとのview |
| `python3 -B formal/tests/test_width_exchange.py` | 0 | 2.76秒 | [出力](l1bc7-width-exchange.log)。4件、幅付きの型の独立入力 |
| formal/で `lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1b/l1bc7-axioms.lean` | 0 | 0.33秒 | [確認ファイル](l1bc7-axioms.lean)、[出力](l1bc7-axioms.log)。主要三性質・脱糖・網羅性・健全性11件・プログラム全体の計24件。標準のpropext・Classical.choice・Quot.soundだけ |
| formal/で `lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1b/representation-b-audit.lean` | 0 | 0.41秒 | [出力](l1bc7-representation-audit.log)。既存の9件のrflと、正規化・移動・代入の構造再帰を変更せず再確認 |
| formal/で `lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1b/l1bc6-audit.lean` | 0 | 0.40秒 | [出力](l1bc7-legacy-audit.log)。既存のLegacy対照とFail内部の計算、一般の網羅性の接続7件を変更せず再確認 |

新しい入口の正負例は [CheckExamplesの確認出力](l1bc7-input-examples.log) で局所確認し、最終のworkにも含めた。追加のtest-auditの四問は次のとおりである。

1. 守る契約は、R15の制限が推論した結果だけでなく、使わない環境・注釈・期待型・未参照の有限宣言にも及ぶことと、Failのない対応する入力を受理することである。
2. 結果のLegacyだけを検査して入力走査を落とす、末尾returnの使わない注釈を飛ばす、空の式列の期待型を飛ばす、有限宣言を参照時だけ検査する変更を検出する。
3. 従来の例はFailを持たず、l1bc6の確認は型の判定までだった。既存のCheckExamplesの入力と公開入口に5件を加えた。正常な全プログラムの対照は既存のcheckPointProgramを使い、準備を重複させていない。
4. 本番の型と公開入口だけを使い、テスト専用の差し込み口は加えていない。今回は新たな移行条件の例であり、改造前の不具合を修正したと主張する退行テストではない。

既存のassertの削除、期待値の緩和、ignoreはない。唯一、SubstExamplesの任意の新しいEffを持つ例では、現在の意味どおりFail内部も移動した潜在効果を期待する形へ直した。R39に理由を記し、旧表現の任意の名前・行の関数について元の結論を保つrflの例も追加した。具体例のdecide/rflを別の信頼する判定へ置き換えていない。142ファイルのLeanソースにはsorry/sorryAx/admitと新しいaxiom宣言はない。

### 計画からの具体化と申し送り

R36〜R39は、R14/R21/R24とR15を具体化したものである。補助の恒等式・比較保存には必要なCanonicalとLegacyを明示し、公開する主要定理の前提・結論は変えない。C_Effによる最上位の効果の拡大と、通常のハンドラが扱う名前の効果は保った。Rustのソースは変更しておらず、計画どおり全lib・clippy・fmt、gc-stress、all-targetsとcheck-formal.sh全体は実行していない。独立入力46件を追加確認したが、Rustの全書き出しとの最終の全比較は後の割り当てへ残す。

L1bは正式な表現Bの状態で完了した。`representation-b.patch` と `representation-b-state.json` の元のハッシュと対象一覧は、L1bc6末の保存物の記録として保つ。stateに正式な接続済みであることを記し、保存差分を再適用する手順は終了する。L1cでは、この正式な状態からnormWithと再帰的な支持を接続し、Legacyでない入力への一時的な拒否を外す。対象はLegacyInput、各公開入口とlookupの制限、Materials.isLegacy、計算した型・効果のガード、条件付きのraw等式である。一般の数学上の網羅性の健全性はLegacyへ制限していない。Failの新しい捕捉とNoFailの規則はL2へ残す。

記録末の確認では、変更文書のローカルリンク200件に切れた参照先・見出しがなく、コメントと文字列を除いて確認したLeanソース142件に未完の証明とaxiom宣言がなかった。git diff --checkも終了0であった。保存差分の元のハッシュは変更せず、正式な接続済みというstateの印と本節への参照だけを加えた。
