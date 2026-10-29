# L50.3 の結果: 旧の互換層の整理と 01-12・07-04 の全体の照合

2026-10-28。Claude のサブエージェント（Opus 5.5）が担当した。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L50.3（plan-l10-l50 の L50 の表の L50.3 の行） |
| B_WORK | `c219281b2c8d05d710b2cc433d4d19814380ccdd`（L50.2 の取り込みの後） |
| 閉じた範囲 | 依頼の 1〜5 の全て。互換層の整理、実例の整理（成功値の形・`hc` の系・重複の除去）、「模型」の修正、01-12・07-04 の照合と修正、既定ビルド・work・公理・Python の検査 |
| 未完の範囲 | なし。残したものと後続へ回したものは下の「残したもの」「ずれと申し送り」に書く |
| 主定理の字面 | 変えていない。`Release/Theorems.lean`・`Release/Lemmas/TargetStep.lean`・`Surface/Theorems.lean`・`Surface/CheckAccept.lean` は差分なし。`Surface/ScopeSound.lean` は定理を加えただけで、既存の接続定理の言明は変えていない |
| 停止条件 | 該当なし。主定理・接続定理の前提と結論、`Builtins.Assumptions` の欄、`Scope/` の採用定義の意味は変えていない。公理の追加なし |

## 変更したファイル

- Lean: `Release/Atom.lean`・`SubstEnv.lean`・`TypeComposition.lean`・`TypeScopedSubst.lean`・`EffectCover.lean`（互換の系の除去とコメント）、`Release/RangeInst.lean`（`PrimSig.scoped_iff`）、`Release/Lemmas/ClauseIx.lean`（`ContTyOld` の docstring）、`Release/ModelTargets.lean`・`ModelHttp.lean`（重複の除去）、`Surface/ScopeState.lean`・`DesugarRange.lean`・`ScopeSound.lean`（成功値の形と `hc` の系）、`Scope/TopCompat.lean`（本番での扱いのコメント）、`Scope/` の L00 のモデルと `Scope/Inference.lean`・`Signature.lean`（「模型」→「モデル」）。
- 設計書: `docs/design/01-spec/01-12-core-calculus.md`、`docs/design/07-quality/07-04-formal-semantics.md`。
- `formal/Benitoite.lean`・`formal/README.md`・`formal/tests/` は変えていない（下の照合で直す箇所がなかった）。Rust と `scripts/` は変えていない。

## 互換層: 消したもの

| 消したもの | 置いた枝 | 理由 |
|---|---|---|
| `Eff.mem_rawBind_rowImage_top`・`Eff.mem_bind_top`（`TypeComposition.lean`）、`Eff.mem_substRho_rowImage_top`（`SubstEnv.lean`）、`Eff.substRho_true_scoped_top`・`Eff.substAt_nameTop`（`TypeScopedSubst.lean`） | L10.2 | 代入の5補題の旧の言明を Top の構築関数の系として残したもの。利用側は0（全利用側が一般化した言明へ移った）。一般化した言明を Top の原子に当てれば得られる |
| `Atom.exists_name_iff_top`（`Atom.lean`） | L10.2 | 上の系を作るためだけの補題。利用側は上の系だけ |
| `Eff.eq_of_sub_of_sub_top`・`Eff.norm_ext_top`・`Eff.ext_canonical_top`（`EffectCover.lean`） | L10.5 | 構造の等号の補題の旧の言明の系。利用側は0。採用定義 `Scope.TopCompat` の `old_ext_canonical`・`old_norm_ext` と内容が重なっていた（RV-L10 軽6）。旧の言明は残した `Eff.mem_iff_of_topAtoms`・`Eff.sub_iff_of_topAtoms` との合成で得る |

消した宣言は 9。どれも主定理の旧の像での同値の根拠ではなく、07-04 は根拠として挙げていなかった（07-04 の二つの行の「系で残す」「系を示す」の記述は、除いたことに直した）。

## 互換層: 残したもの

| 残したもの | 理由 |
|---|---|
| `Ty.WFOld`・`Ty.VarsInOld`・`PrimSig.ScopedOld`（`RangeWF.lean`） | `Ty.wf_iff_old`・`varsIn_iff_old`・`PrimSig.scoped_iff_old`・`sig_scoped_iff_old_of_rangeFree` が使う旧の定義の写し。07-04「証明する性質」が P1 の前提の変更の根拠に挙げる |
| `PrimSig.ScopedRanges`・`PrimSig.TargetRangesOnly`（L20.3・L20.5 の申し送りの「二つの形」） | 互換の層ではなく、具体化の補題（`PrimSig.inst_nil`・`inst_wf_zero` ほか）が使う部分の条件。`sig_scoped` の `PrimSig.Scoped` を三つの連言へ分解する同値 `PrimSig.scoped_iff` を加えて二本立ての関係を一つの補題にした（定義は変えていない） |
| `Builtins.FieldOld`・`DeltaTypedOld`・`IOTypedOld`・`IOExistsOld`・`PrimSig.StoreShapeOld`・`opSigOld`（`PrimRanges.lean`） | `delta_typed_iff_old`・`io_typed_iff_old`・`io_exists_iff_old`・`storeShape_iff_old`・`opSig_eq_old` が使う。07-04 が根拠に挙げる |
| `StringAddOkOld`・`DieExitOkOld`（`Surface/RangeFree.lean`） | `stringAddOk_iff_old`・`dieExitOk_iff_old` が使う。07-04 が根拠に挙げる |
| `*NoObs` の族と `liftNoObs`・`Oracle.ofNoObs`（`Observation.lean`） | `ioKind_iff_noObs` ほか観測の同値と `horacle_noObs`・`horacle_of_noObs` が使う。07-04 が根拠に挙げる |
| `BuiltinOnlyOld`（`Semantics.lean`）・`Builtins.IoOpOld`（`ShapeOk.lean`） | `BuiltinOnly.iff_old`・`stateTy_of_old`・`ioOp_iff_old` が使う。`ModelTargets` の反例 `not_builtinOnlyOld_write` も使う |
| `ContTyOld`（`ClauseIx.lean`） | `ContTy.toOld`・`ContTyOld.toNew`・`contTy_exists_iff_old` が使う。docstring を「節の型付けは新しい関係で読む旧の形であり、L30.1 の前の字面どおりの写しではない」に直した（RV-L30 軽4）。`opSig` で書いた写しは置いていない |
| `Ty.LeOld`・`Ty.LatentTopAtoms`（`CoverCompat.lean`） | `Ty.le_iff_leOld`・`Ty.LeOld.le` が使う。07-04 が根拠に挙げる |
| `Atom.TopImage`・`Eff.TopAtoms` と `Eff.covers_iff_sub_of_topAtoms`・`mem_iff_of_topAtoms`・`sub_iff_of_topAtoms`・`TopAtoms.*` | 本番の旧の像の述語。上の同値の前提に使う。`Atom.TopImage` の docstring を、消した系でなく同値の補題の条件として書き直した |
| 採用定義 `Scope.TopCompat`（`TopEmbedding`・`GEff`・`lift`・`old_*`） | 採用定義であり意味を変えない。本番の原子で具体化すると恒等になるので本番では使わず、L00 のモデル（`Scope.CompatExamples`・`SwitchExamples`）だけが使う。本番と重なっていた旧の言明の系は本番の側（上の `*_top`）を除いて解消した。ファイルの先頭に本番での扱いを書いた（RV-L10 軽6） |
| 旧版の交換の入力の読み込み（`legacyRanges`・`legacyRangeNode`・`legacy_*` の補題）と `AcceptInput.noRules`・`ScopeAcceptanceEntry.acceptInput none` | Rust の書き出しが新しい版へ移るのは K10 の後（依頼の指定）。`checkProgramAccepted_noRules` も残る |
| `Exchange/Convert.lean` の `fromEffNames` の既定の候補（`unlistedAtom?` に渡す一覧の像） | 交換の入口の多くの呼び出し（`fromTy`・`fromVal`・`fromEff` の再帰）が候補を渡していない。全ての呼び出しが候補を渡すようになるまで残す（L50.1 の申し送り） |
| `Release.Ty.opaqueTop`・`Atom.nameTop` | 互換の別名ではなく、問1 の明示の Top の構築関数（採用した決定） |
| L00 のモデルのファイル（`Scope/*Examples.lean`・`RepresentationExamplesI.lean`） | 比較の記録として既定の import に残す（依頼が「模型」の修正の対象に挙げた）。本番の定理は使わない |

比較専用の import の残りはなかった。既定の入口（`Benitoite.lean` と七つの実行ファイル）の import の閉包から外れるモジュールは `Release/LegacyCheck.lean` だけであり、0.0.8 からある旧のファイルで今回の改造の新しいモジュールではない（単独の `lake env lean -M 12288` は終了0）。新しいモジュールと旧主定理はすべて既定の import に入る。

## 実例の整理

- 成功値の形（RV-L40 軽7、L40.6 の申し送り 5）: `ScopeState.checkDelta` に成功値を作る関数 `okVal` を引数として加え、パスの検査は `checkedOk`（`.checked t`）、要求の検査は `requestOk`（四番目の引数の定数 req を保持する `.checkedRequest t req`）を渡す形にした。`Boundary.rules` の要求の検査の成功値は、これで `ModelHttp.checkRun` と同じ形になった。`checkDelta_contract` は成功値が対象を保持すること（`checkedOk_target`・`requestOk_target`）を前提に取り、`checkDelta_ok_mem`・`desugar_checkDelta_mem` の結論は `w = okVal vs t` になった。Release の実例の表の δ の成功値が同じ形であることを `ScopeSound.modelTargets_checkRun_checkedOk`・`modelHttp_checkRun_requestOk` で示した。`requestOk` の四番目の引数が定数でない腕は `.checked t` を返すが、`reqEndpoint` のように定数だけを読む表ではその場合に対象がなく `Err` になるので、成功値にならない（docstring に書いた）。
- `hc` の系（RV-L40 軽7）: `ScopeSound.scope_local_typed_of_typed` を置いた。`scope_local_typed` の前提 `hc` を、引数の値が名前 name の不透明型（範囲の位置は任意）を持つことから `HasTypeVQ.inv_checkedRequest` で得る。
- 三つの実例の表（L40.3b の申し送り 7、L20.7 の申し送り 12）: `Model`・`ModelTargets`・`ModelHttp` の三つの表は役割が違うので一つにまとめず残し、役割を `ModelTargets.lean` の先頭に書いた。`ModelHttp` が `ModelTargets` と同じ形で持っていた `okDecl`・`errDecl`・`ok_typed`・`err_typed`・`singleton_of_admissible`・`ref_scoped_get`・`ref_scoped_set` を消し、`ModelTargets` の宣言を使う形にした。`ok_typed`・`err_typed` は表によらない形（任意の `B` と `P.cons "Ok" = some okDecl`）、`singleton_of_admissible` は任意の `B` に一般化した。
- `productionRules` と `Boundary.rules` の並び: 二つとも残す。`Boundary.rules` は形式化の外側の関数を欄に持つ汎用の表、`productionRules` は実例の表の δ を規則にした表であり、接続定理と例はそれぞれを使う。成功値の形はそろった。`productionRules` のパスの射影は実例の表に `Scope.pathInValue` の δ がないので値を返さないまま残した（射影の規則は事実を作らず、健全性は実行によらない）。`ModelTargets.firstTarget` と `ModelHttp.firstTarget` は定義の形が違う（前者は構成子ごと、後者は `Val.target?`）が、仮定の証明が定義の展開に依るので統一していない。

## 全体の照合で見つけた食い違いと直した箇所

照合は、01-12 と 07-04 の逆引用符の名前を Lean の宣言（名前空間を含む）と機械で突き合わせ（`Eff.mem_substRho` 以外の不一致は、言語の名前・道具の名前・モジュール名などの Lean の宣言でないものだった）、各枝で変わった規則（C-Sub・C-Eff・`Ty.Le` の被覆、K-Handle・K-Handle-Fail、V-Prim、V-Checked・V-CheckedRequest、`BuiltinOnly`、`RangeAdmissible`）の写しを Lean の定義と読み比べ、L40.4〜L40.6・L40.6c・L50.1・L50.2 の後に古くなりうる語（「構造上の包含のまま」「まだ」「中間状態」「Top の列」など）を両章で探す方法で行った。

| 章・箇所 | 食い違い | 直した内容 |
|---|---|---|
| 01-12「エフェクトの名前と開始状態」の段階 B の写しの段落（`Eff.mem` の展開） | `Eff.mem_substRho` という宣言はない（B0 の時点からない） | `Eff.mem_substRho_rowImage` に直した |
| 01-12「操作の対象の範囲の領域と被覆」の最初の段落 | 「所属と被覆の定義は、まだ型付けと実行の規則から使わない。…前提と結論も変えない」は L20.4（V-Checked）・L40.6c（C-Sub の被覆）の後に古い | 所属と被覆を使う規則（葉の規則・具体化の許容・C-Sub などの被覆・許可の関係）を挙げ、本節の言明が型付けを前提にしないことに直した |
| 01-12 同節の効果の正規化の段落 | 「範囲の正規形を条件にする箇所はまだない（`RangeAdmissible` が求めるのは整形式性）」は L20.3 の後に古い（`Builtins.RangeAdmissible` は `Range.Canonical` を求め、L50.2 の入力の検査も正規形を確かめる） | 正規形を条件にするのは具体化の許容と交換の入力の検査であり、型の整形式性は求めないことに直した |
| 01-12「Scope の局所解析の状態と規則の表」の `checkDelta` の段落 | 成功値の形を変えた（本枝） | `okVal`・`checkedOk`・`requestOk` と同じ形の補題を書いた |
| 01-12「Scope の局所解析の接続定理」の表 | 本枝で補題を加えた | `scope_local_typed_of_typed`・`modelTargets_checkRun_checkedOk`・`modelHttp_checkRun_requestOk` を加えた |
| 07-04「01-12 との対応」の「表記・構文（名前の原子と不透明型の範囲の位置）」の行 | 「旧の言明は `*_top` と `Eff.substAt_nameTop` の系で残す」（本枝で除いた） | L50.3 で系を除いたことに直した |
| 07-04 同表の「エフェクトの名前と開始状態（構造上の包含・被覆・許可の関係）」の行 | 「`*_top` を示す」（本枝で除いた）。`Scope.TopCompat` の扱いが書かれていなかった | `Eff.mem_iff_of_topAtoms`・`sub_iff_of_topAtoms` に直し、`Scope.TopCompat` が本番で使われずモデルだけが使うことを書いた |
| 07-04 同表の「Scope の必須の判定の受理と拒否の理由」の行 | 「Release の `Eff.Sub` と C-Sub は構造上の包含のままである」は L40.6c の後に古い | `Eff.Sub` は構造上のまま、C-Sub などの被覆は型付けの規則の側の別の関係であることに直した |
| 07-04 同表の「型の情報を付けた表層の構文と型付けの組み込みの名前の範囲の列」の行 | 「交換の材料から作る検査の入力は … 判定を持つ」は 01-12 と食い違う（`CheckTables.Materials.input` は判定を持たず、`Exchange.CheckInput.prepare` が入れる） | `prepare` が作る入力に直した |
| 07-04 同表の「検査済みの値の独立した小モデル」の行 | 第2列に「Rust は未接続」がない（IP・CIDR への一般化は今回の改造） | 第2列に「IP アドレスと CIDR への一般化について Rust は未接続」を加えた。今回の改造で足した・変えた対応表の行は、これで全て「Rust は未接続」を持つ |
| 07-04「証明する性質」の節の添字の段落 | `ContTyOld` を以前の形とだけ書き、字面どおりの写しでないことを書いていなかった（RV-L30 軽4） | 節の型付けを新しい関係で読む旧の形であり、字面の写しとの同値は二つの補題との合成で得ることを書いた |
| 07-04「証明する性質」の接続定理の段落 | 本枝で `hc` の系を加えた | `scope_local_typed_of_typed` を書いた |

照合で食い違いがなかったもの: 07-04「形式化で仮定するもの」の信頼の対象（`CoreAssumptions`・`TargetAgreement`・`io_target`・完全性の文言・`effKind`・`valKind`・`admitsR`・`valContent`・形の検査・解析器の正規形）と三つの実例の表の記述、「証明する性質」の L40.6c・L50.2 の段落（`acceptEffCover`・`effCovers`・`checkProgramAccepted`）、01-12 の C-Sub・`≤`・K-Handle・V-Prim・`BuiltinOnly` の写し、01-12「Scope の必須の判定の受理と拒否の理由」（L50.2 が直した後の全文）、07-04「交換の形式の版」（L50.1・L50.2）。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 最大常駐量（`/usr/bin/time -l`） |
|---|---|---|---|---|
| 全体のビルド 1回目 | `cd <wt>/formal && <排他の道具> <log>` | 1（下の「失敗と修正」） | 186.19秒 | 3577397248 バイト = 3411.7 MiB = 3.33 GiB |
| 全体のビルド 2回目 | 同上 | 1（同） | 3.48秒 | 834322432 バイト = 795.7 MiB = 0.78 GiB |
| 全体のビルド 3回目 | 同上 | 0、sorry なし、エラー0、変えたファイルの警告0 | 14.77秒 | 1641332736 バイト = 1565.3 MiB = 1.53 GiB |
| 作業末の全体のビルド | 同上（`lake-build-final.log`） | 0、571 ジョブ、sorry なし（全て構築済みで再構築なし） | 0.14秒 | 70942720 バイト = 67.7 MiB = 0.07 GiB |
| dry-run | `scripts/check.sh --level work --base c219281b2c8d05d710b2cc433d4d19814380ccdd --dry-run` | 0 | 数秒 | 計時なし |
| work | `/usr/bin/time -l scripts/check.sh --level work --base c219281b2c8d05d710b2cc433d4d19814380ccdd` | 0（spec_tally・spec_examples 7件・formal_build） | 9.90秒 | 1384857600 バイト = 1320.7 MiB = 1.29 GiB |
| 公理の依存 | `cd <wt>/formal && lake env lean -M 12288 ../docs/…/l50.3/axioms.lean` | 0 | 0.62秒 | 1529397248 バイト = 1458.5 MiB = 1.42 GiB |
| Python の検査（`--rust-dir` なし） | `python3 -I` か `-B`（`check-formal.sh` と同じ指定）で `formal/tests/test_*.py` の10件を順に | 10件とも0 | 計約36秒 | 計時なし |

- dry-run の選択は計画の見込みどおり、01-12 の変更から `spec_tally`・`spec_examples`、formal の変更から `formal_build` だった。実行も同じ三つを選んだ。
- ビルドの最大常駐量は lake の子のプロセスの最大値であり、並行しない一つの Lean のプロセスの最大値を示す（計時は `lake-build*.log` の末尾）。作業末のビルドは再構築がないので、実際の構築の最大値は1回目（3.33 GiB）である。work の値は `formal_build` の lake を含む一括の実行全体の最大値である。
- 公理（`axioms.log`）: 本枝で加えた・言明を変えた定理と、証明を変えた宣言に依る実例の定理（`ModelTargets.assumptions`・`ModelHttp.assumptions`・`sendState_target_sound`・`ContTyOld.toNew`）の19件、主定理・接続定理の14件（`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`step_target_sound`・`reachable_target_sound`・`desugar_typed`・`surface_effect_soundness`・`surface_target_sound`・`scope_check_connection`・`scope_local_connection`・`scope_local_typed`・`checkProgramAccepted_sound`）の計33件は、どれも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依る。`sorryAx` はない。
- Python の検査の内訳（`python-tests.log`）: `test_batch2`〜`batch5`・`extensible`・`interval`・`named`・`range`・`try`・`width` の各 exchange。
- 生のログ: `lake-build1.log`〜`lake-build3.log`・`lake-build-final.log`・`dryrun.log`・`check-work.log`・`axioms.lean`・`axioms.log`・`python-tests.log`。手元の絶対パスは `<wt>`・`<home>`・`<tmp>` に置き換えた。

## 失敗と修正

1. 1回目のビルド: `Release/ModelTargets.lean:218` で構文の誤り。`ok_typed` の docstring を差し替えたとき、元の docstring（「結果の型の値の型付け。」）の後に新しい docstring を重ねた。一つにまとめて直した。
2. 2回目のビルド: `Release/ModelHttp.lean:36` で `open ModelTargets (okDecl …)` の名前が曖昧（`Benitoite.Release` の名前空間の中と `open Benitoite.Release` の二つの経路で同じ宣言を指した）になり、その後の利用が全て未知の名前になった（エラー21行）。`open Benitoite.Release.ModelTargets (…)` と完全な名前にして、3回目で通った。

どちらも失敗したのは本枝で書き換えた箇所だけであり、証明の内容の失敗ではない。

## ずれと申し送り

計画からのずれ: なし。`ContTyOld` は計画の二案のうち docstring を直す案を採った。`formal/README.md` と `formal/tests/` は直す箇所がなかった。

L50.4（全体レビュー）への申し送り:

1. 本枝で消した9宣言と残した互換の層の一覧（上の表）を、旧の像での同値の根拠が足りているかの観点でレビューする。消した系の旧の言明は一般化した言明から一行で得られるが、Lean の宣言としてはもうない。
2. `checkDelta` の成功値の形を引数にしたこと、`requestOk` の定数でない腕（`.checked t` を返す）の扱い、`scope_local_typed_of_typed` の前提（引数の値の型付けの文脈は任意）を、定義・言明のレビューの観点にする。
3. 既定の import の閉包の外に `Release/LegacyCheck.lean`（0.0.8 の旧入力の検査）が残る。今回の改造のモジュールではないので触れていない。消すか import に入れるかは全体レビューで決める。
4. 既存の申し送り（L40.6 の番号の一致の補題、RV-L40 軽8 の表層の例、RV-L30 軽3 の `WrongHandleTyped`）は本枝で扱っていない。

K10 への申し送り:

1. 旧版の交換の読み込み・`AcceptInput.noRules`・`fromEffNames` の既定の候補は、Rust の書き出しが corpus 15・sidecar 7 へ移った後に整理する（L50.1・L50.2 の申し送りのとおり）。
2. Rust の Scope の要求の検査の成功値が、渡された要求を保持する値（形式化の `requestOk`）であることを照合する。

R 段への申し送り:

1. R20: 必須の判定の受理の Rust の実装を、`checkDelta` の `okVal` の二つの形（パスは対象だけ、要求は要求を保持）に合わせる。
2. R30: `Http.RequestIn` の値が検査した同じ要求を保持すること（判断 7）の照合は、変わらず R30・K10 の担当である。

## 時間

| 区分 | 時刻（2026-10-28） | 所要 |
|---|---|---|
| 依頼文と文書を読む | 11:00〜11:05 頃 | 約5分 |
| 互換層の調べと整理、実例の整理、語の修正（ビルド待ちを除く） | 11:05〜11:15 頃 | 約10分 |
| 設計書の照合と修正（1回目のビルドと並行） | 11:12〜11:17 頃 | 約5分 |
| ビルド（排他の道具で4回）・公理・Python の検査・work | 11:11〜11:20 頃 | 計約4分（1回目 3.1分、ほかは数秒〜15秒）、排他の待ちは0秒 |
| 結果の記録 | 11:20〜11:23 頃 | 約3分 |

外側の所要は約23分、能動時間は約19分（検査と待ちの約4分は別）。見込みは0.5〜4.5時間であり、上端の2倍（9時間）には届いていない。
