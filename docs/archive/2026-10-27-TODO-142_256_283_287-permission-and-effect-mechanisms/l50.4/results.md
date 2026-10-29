# L50.4 の結果: 全体レビュー（RV-L50）への対応

2026-10-28。plan-l10-l50「L50」の表の L50.4 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l50.4`）で行った。担当は Claude のサブエージェント（Opus 5.5）である。git の状態は変えていない（コミットは取りまとめが行う）。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L50.4（RV-L50 の「対応（取りまとめ）」の表の項目と、依頼の 1〜7） |
| B_WORK | `1b30f6f9fa5b76c6b3330152962ec13d8bd3475e`（RV-L50 の記録の後の本線） |
| 閉じた範囲 | 中1（表層の到達する例）、中4（出現の番号の一致の補題。見込みの2倍の前に閉じたので、信頼の対象に書く形には切り替えていない）、軽5〜軽10、中2 に合わせた 07-04 の L40.6c の段落、R 段が合わせるべき点の一覧 |
| 未完の範囲 | 中3 の検査器の変更は行っていない（下の「中3 について」。依頼の前提の検査器の不受理は再現せず、実際の差は節の添字の選び方だった。依頼どおりの変更は検査器の入力に上限を持たせる設計の変更を要する） |
| 主定理の字面 | L50.3 の後と同じ。`Release/Theorems.lean`・`Release/Lemmas/TargetStep.lean`・`Surface/Theorems.lean` は差分なし。`Surface/ScopeSound.lean`・`Surface/CheckAccept.lean` は系を加え、モジュールの説明の一文を直しただけである |
| 停止条件 | 該当しない（下の「停止条件の点検」）。中3 は依頼からのずれとして報告する |

## 指摘ごとの対応

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1 | main が `Scope.checkPathIn["/data/a.txt"]("/data/**", "/data/a.txt")` の結果を `match` で照合し、`Ok(p)` の腕で被覆の小例の `f`（上限 `{File.Write["/data/**"]}`、本体は `/data/a.txt` への書き込み）へ渡す表層のプログラムにした。脱糖したプログラムの開始状態から 18 回の事象のない遷移の後に書き込みの事象（観測 `[/data/a.txt]`）へ到達することを示し（`main_reach`）、`surface_target_sound` から、到達した観測を上限が許すこと（`main_reach_allowed`）と、到達したどの IO の事象の観測にも `/etc/passwd` が現れないこと（`main_never_passwd`）を導いた | `Surface/CoverExamples.lean` |
| 中2 | 停止の表は取りまとめが直した。07-04「証明する性質」の L40.6c の段落に、`delta_typed`・`io_typed`・`io_exists` の意味の変化（入力が広がる欄は強まり、出力が広がる欄は弱まる）と、それを α の例外に含めることを書いた | 07-04 |
| 中3 | 検査器は変えていない。依頼が挙げたプログラム（上限 `{File.Write["/data/**"]}` の関数の中で、`File.Write` を処理しない `handle` の保護本体で `/data/a.txt` へ書く）は、今の検査器が受理する（`#guard`）。検査器が型付けより狭いのは節の添字の選び方であり、その例（節が捕えたパスを `Scope.PathIn["/data/**"]` の引数へ渡すと拒否、`Scope.PathIn["/data/a.txt"]` なら受理）を置いた。01-12・07-04 に現状と差を書いた。推す案と代案は下の「中3 について」 | `Surface/CheckAcceptExamples.lean`、01-12、07-04 |
| 中4 | 到達した文の右辺を添字に持つ到達の関係 `ReachAtBlock`（`ReachBlock` の全ての構成子の写し）を置き、`ReachAtBlock.toReach`（`ReachBlock` の到達である）、`ReachBlock.toAt`（`ReachBlock` のどの到達にも右辺がある）、`reachAt_occurrences`（`(k, e)` は出現の一覧に入る）を証明した。接続定理の系 `*_at` は `hreach` と `hocc` の代わりに `ReachAtBlock` だけを前提に取る | 新 `Surface/ScopeOccurrence.lean`、`Surface/ScopeSound.lean`、`Surface/CheckAccept.lean` |
| 軽5 | 07-04 の BA の段落を「旧の `BuiltinOnly` を満たす末尾で新しい `StateTyE` が付く状態は `StateTy` に入る（`stateTy_of_old`）。旧の型付けの規則で型の付く状態との比較は示していない」に直した | 07-04 |
| 軽6 | 07-04 の信頼条件の分離の箇条と `CoreAssumptions` の docstring を「欄の名前と並びは以前と同じ。L20.7 で内容を変えたのは `io_op` だけで、ほかの欄の内容の変更は前の段落と『証明する性質』のとおり」にした | 07-04、`Release/Assumptions.lean`（docstring だけ） |
| 軽7 | 07-04「形式化で仮定するもの」の被覆の【決定】から `release_exists` を外し、入力が `.opaqueTop o` の値で `Ty.Le` が関数の型でない位置では等号なので影響しないことを書いた | 07-04 |
| 軽8 | `ModelTargets` の表に旧 Top の形の IO の項目 `File.readText`（`topTargeted .path`、効果 `{File.Read}`、観測は文字列の引数を解析した path の対象）と、資源の型 `File.Handle`（`isResource` が真、解放の応答は `none`）を加えた。形の検査（`read_shapeOk`）、空でない観測での `io_target`（`read_io_target`）、E-IO の事象（`read_step`）と観測の許可（`read_obs_allowed`）、`release_exists` の前提を満たす値（`handle_release`）を示した | `Release/ModelTargets.lean`、07-04 |
| 軽9 | 07-04 の L40.6c の段落に、構造上の包含のまま残す位置の一覧（C-Handle・C-Handle-Fail・K-Handle の保護本体、K-Empty、K-Let・K-Guard、状態の型付けの `ε1 ⊆ ε`、表層の E_Handle・E_HandleFail の保護本体、E_PartialCall、`HasMain`）と理由（計算の側の C-Eff・E_Sub・B_Sub と `Ty.Le` の被覆で先に広げられること、`handle` の保護本体は判断 11 の規則の値と L30.1 の保存に使うこと、`HasMain` の ε は言明の中で選べて `Builtins.Allows.of_covers` で移せること）を書いた | 07-04 |
| 軽10 | 07-04「形式化で仮定するもの」に Scope の局所解析の信頼の対象の【方針】を加えた（`scopeAcceptance` の `patterns`・`hosts`、`primResolve` の前提、整数のリテラルの U+0000 の表し方、出現の番号の数え方は Lean で閉じ、処理系の側は R20 で照合） | 07-04 |

## 中3 について（取りまとめへ返す点）

1. RV-L50 中3 は「型付けでは型が付くが検査器は断る」としたが、検査器の `handle` の腕は保護本体の効果から処理しない原子を除いた効果（`diffEff`）を初期値に `handle` の式の効果 ε を求め、ε は初期値を含むので、最後の `acceptEff (ε ∪ handled) εbody` はどの本体でも成り立つ。挙げられたプログラムは受理される（`CheckAcceptExamples` の `entryTxt [("main.store", handleWrite)] == none`）。
2. 実際の差は節の添字である。検査器は保護本体の推論した効果から判断 11 の規則の値（`clauseIxIn`）を選ぶ。表層の型付けの `E_Handle` は保護本体を `B_Sub` の被覆で広げてから規則の値を選べるので、広い添字を要る節を型付けは受け入れうる。例: 保護本体が `/data/a.txt` へ書き、`File.writeTextIn` の節が捕えたパスを `g(p: Scope.PathIn["/data/**"])` へ渡すと、検査器は型の誤りで拒否する（`== some none`）。`g` の引数が `Scope.PathIn["/data/a.txt"]` なら受理する。このプログラムの型付けの導出は Lean で書いていない（規則の読みからの結論）。
3. 依頼の形（「本体の効果の各原子を上限 ε の覆う原子へ写した εb' で調べ、節の添字も εb' から選ぶ」）は、`handle` の位置の検査器に上限がない（ε は推論する値である）ので、そのままでは書けない。書くには上限を検査器の入力に持たせる必要があり、節の添字を上限の原子の範囲で選ぶことになる。これは判断 11 の規則の値の選び方（保護本体の効果から一意に選ぶ。README の確認点 (10)・(14)）を変える設計の判断であり、狭い添字を要る節（今は受理される `g(p: Scope.PathIn["/data/a.txt"])` の形）を逆に拒否しうる。推す案の前提（検査器が挙げた形を断る）が成り立たなかったので、変更をせずに止めた。
4. 推す案: 検査器を今の形に保ち、節の添字は保護本体の推論した効果の規則の値とする。R20 の Rust の型検査器もこの形にそろえ、型付けより狭いことを 07-04 と R40 の診断の材料に残す（01-12・07-04 に書いた）。なお、節の本体の中で `Scope.widenPathIn` で広げる書き方は、節の入口の局所が由来を持たないので必須の判定で `unknownSource` になると読める（確かめていない）。R40 の診断の案内は R40 で決める。
5. 代案 (i): 検査器の入力に定義ごとの上限の欄を置き（`noFailRows` と同じく宣言の入口で設定し、本体の再帰では変えない）、保護本体の効果の原子のうち上限の原子が覆うものをその原子へ写した効果で節の添字を選ぶ。失敗したら今の添字で検査し直す形にすれば、受理する集合は今より狭まらない。健全性は被覆 `Covers εb' εbody` だけに依り、`handle_case` の証明に `B_Sub` を挟めば保てる見込みである（試していない）。代案 (ii): 期待する上限を検査器の全ての関数の引数として渡す（変更が大きい）。どちらも判断 11 の検査器での選び方を変えるので、設計者の確認を要する。

## 変えた定義

| 定義（ファイル） | 変更 |
|---|---|
| `ModelTargets.builtins`（`Release/ModelTargets.lean`） | 項目 `File.readText`（`readTextSig`）、その応答と観測（`readObs`）、エフェクト `File.Read` の操作の一覧、`isResource`（`File.Handle` だけ真）を加えた。ほかの項目と δ は変えていない |
| `Surface.CoverExamples.mainDef`（`Surface/CoverExamples.lean`） | 本体を `()` から検査の結果の照合と `f` の呼び出しに替えた（`checkE`・`callFE`・`okAlt`・`errAlt`・`mainArms`・`mainBody`） |
| `CoreAssumptions` の docstring（`Release/Assumptions.lean`） | 文だけ（軽6）。欄と型は変えていない |
| 新しい定義 | `ScopeOccurrence.occ`・`guardPre`・`ReachAtExpr`・`ReachAtExprs`・`ReachAtBlock`・`ReachAtArms`・`ReachAtClauses`（相互帰納）、`CoverExamples` の `coreProgram`・`start`・`oracle`・`rel`・`fresh`・`silent`・`passwd`・`resultCtors`・`checkTy`・`armsEff`、`ModelTargets` の `readTys`・`readObs`・`readTextSig`・`Examples.readCall`、`CheckAcceptExamples` の `aTxt`・`qTxt`・`materialsOf`・`entryTxt`・`writeTxt`・`handleWrite`・`writeClause`・`handleClause`・`gWith` |

`Scope/` の採用定義、`Builtins.Assumptions`・`CoreAssumptions`・`TargetAgreement` の欄、Release と表層の型付け・遷移・脱糖、検査器（`Surface/Check.lean` ほか）、`Release/LegacyCheck.lean` は変えていない。既定の import に `Surface.ScopeOccurrence` を加えた（`formal/Benitoite.lean`）。

## 置いた定理

| ファイル | 定理 |
|---|---|
| `Surface/ScopeOccurrence.lean`（新） | `occurrences_eq`・`occ_cons`・`occ_append`・`advance_advance`・`mem_occ_head`・`mem_occ_cons`・`mem_occ_left`・`mem_occ_right`・`mem_occ_key`・`preorderBlock_rhs`・`guardPre_length`・`preorderArms_cons`・`advance_one_add`、`ReachAt{Expr,Exprs,Block,Arms,Clauses}.toReach`、`ScopeLower.Reach{Expr,Exprs,Block,Arms,Clauses}.toAt`、`ReachAt{Expr,Exprs,Block,Arms,Clauses}.occ`、`reachAt_occurrences`・`reach_occurrences` |
| `Surface/ScopeSound.lean` | `scope_check_connection_at`・`scope_local_connection_at`・`scope_local_typed_at`（`scope_local_typed_of_typed` の系）・`scope_check_core_at` |
| `Surface/CheckAccept.lean` | `accepted_check_connection_at` |
| `Surface/CoverExamples.lean` | 型付け: `check_admissible_exact`・`check_names_wf`・`instR_empty`・`check_eff_at`・`check_params_at`・`check_fnTy`・`checkE_typed`・`callFE_typed`・`okAlt_ty`・`errAlt_ty`・`mainArms_typed`・`resultCtors_complete`・`mainArms_exhaustive`・`qsig_nil`・`main_typed`。到達: `oracle_ok`・`rel_ok`・`fresh_ok`・`core_typed`・`core_assumptions`・`silent_steps`・`start_stateTy`・`write_after_silent`・`main_reach`・`main_reach_allowed`・`passwd_not_allowed`・`main_never_passwd`。既存の `program_wellFormed`・`program_wellTyped`・`program_hasMain`・`program_target_sound` は新しい main で証明し直した（言明は同じ） |
| `Release/ModelTargets.lean` | `readTextSig_scoped`・`sig_read`・`readText_ret`・`readObs_kind`、`Examples.read_shapeOk`・`read_admissible`・`read_args`・`read_response`・`read_io_target`・`read_io_target_kind`・`read_step`・`read_obs_allowed`・`handle_release`。`sig_cases`・`effects_cases` は項目の追加に合わせて言明を広げ、`assumptions` は七項目で証明し直した（言明は同じ） |

未証明の theorem は置いていない。`native_decide`・`maxHeartbeats` は加えていない。

## 確かめた例

| 名前 | 内容 |
|---|---|
| `Surface.CoverExamples.main_reach` | 脱糖したプログラムの `main[;]()` から `Steps` で到達した状態が、`File.writeTextIn` の事象（観測 `[/data/a.txt]`）を伴って遷移する。`step` を事象のない遷移だけ 18 回続ける関数 `silent` と、その後の `step` の結果の真偽の判定 `write_after_silent` をカーネルの `decide` で評価し、`step_sound` と `preservation` で遷移の関係へ移した（`silent_steps`）。単一ファイルの検査は約 2 秒 |
| `main_reach_allowed`・`main_never_passwd` | `surface_target_sound`（`program_target_sound`）から、到達した観測 `/data/a.txt` を上限 `{File.Write["/data/**"]}` が許し、到達したどの IO の事象の観測にも `/etc/passwd` が現れない |
| `ModelTargets.Examples.read_io_target`・`read_obs_allowed` | 旧 Top の形の項目で、空でない観測 `[/data/a.txt]` が形の条件（`topTargeted .path`）を満たし、Top の原子 `File.Read` が許す |
| `ModelTargets.Examples.handle_release` | 資源の型 `File.Handle` の定数は型 `.opaqueTop "File.Handle"` を持ち、`release_exists` から解放の応答がある |
| `CheckAcceptExamples` の `#guard` 3件 | 中3 の受理する形、節の添字が狭い形の受理、広い添字を要る形の拒否 |

既存の例（`ioState_step`・`ioState_obs_allowed`、`Release.CoverExamples.narrow_io_step`、`TargetReachExamples.sEtc_step`、`HandlerTargetExamples.sIO_step`・`sIO_obs_allowed`）は、応答の関係の選言が一つ増えたので、`File.writeTextIn` の腕の位置（`.inr (.inr (.inl …))`）だけを直した。

## 主定理の言明と前提の内容

主定理（`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`step_target_sound`・`reachable_target_sound`・`desugar_typed`・`surface_effect_soundness`・`surface_target_sound`）と接続定理（`scope_check_connection`・`scope_local_connection`・`scope_local_typed`・`checkProgramAccepted_sound`）の言明は変えていない。前提の内容を変える定義（型付け・遷移・仮定の欄・検査器）も変えていない。実例の表の項目の追加は、`Builtins.Assumptions` の欄の追加ではない（plan「全 L 作業の停止条件」の「七 IO の表の項目の追加」と同じ扱い）。

## 設計書

| 文書 | 変更 |
|---|---|
| 01-12「型の情報を付けた表層の構文と型付け」の範囲条件の箇条 | `handle` の保護本体の構造上の包含が成り立つ理由、検査器が受理する中3 の形、節の添字の差と拒否の例、main が IO に到達する例（`main_reach`・`main_reach_allowed`・`main_never_passwd`）。「この例の main は IO を行わない」を除いた |
| 01-12「Scope の局所解析の接続定理」の最後の段落 | 番号の一致を補題で示すこと（`ReachAtBlock`・`reachAt_occurrences`・`ReachBlock.toAt`）と系 `*_at` の【決定】と理由 |
| 07-04「証明する性質」 | BA の段落（軽5）、被覆の段落（中2・軽9・中3・中1）、表層の対象健全性の段落（中1）、接続定理の段落（中4） |
| 07-04「形式化で仮定するもの」 | Scope の局所解析の信頼の対象の【方針】（軽10）、被覆の【決定】（軽7）、信頼条件の分離の箇条（軽6）、`ModelTargets` の表の行と資源の型の文（軽8） |
| 07-04「01-12 との対応」 | 「効果の上限の被覆による包含」「Scope の局所解析の接続定理」「表層の対象健全性」の行（どれも Rust は未接続のまま） |

見出しは加えていない・変えていない。01-12 の ` ```text ` のブロックは変えていない。`formal/README.md` と `formal/tests/` は直す箇所がなかった。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 全体のビルド 1回目（中1・中4 の後） | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <log>` | 0、573 ジョブ | 13.42 秒（排他の待ち 0 秒） | [lake-build1.log](lake-build1.log)・[lake-build1-time.txt](lake-build1-time.txt) |
| 全体のビルド 2回目（軽8 の後） | 同上 | 0 | 13.46 秒 | [lake-build2.log](lake-build2.log)・[lake-build2-time.txt](lake-build2-time.txt) |
| 全体のビルド 3回目（`Release/Assumptions.lean` の docstring の後。Release の根から組み立て直した） | 同上 | 0 | 150.06 秒 | [lake-build3.log](lake-build3.log)・[lake-build3-time.txt](lake-build3-time.txt) |
| 作業末の全体のビルド | 同上（別の名前のログ） | 0、`Build completed successfully (573 jobs)`、`sorry` の出現 0、誤り 0、警告 89 行（L50.3 の `lake-build1.log` と同じ数え方で同数。変えたファイルと新しいファイルの警告なし） | 0.27 秒（組み立て済み） | [lake-build-final.log](lake-build-final.log)・[lake-build-final-time.txt](lake-build-final-time.txt) |
| 局所の単一ファイル（約 30 回） | `cd <wt>/formal && lake env lean -M 12288 <相対パス>`（試作は一時ディレクトリの台本） | 途中に 1 が十数回（下の「失敗と修正」）、最後は全て 0 | 各 0.4〜2 秒 | 本書 |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l50.4>/axioms.lean`（`#print axioms` 106件） | 0 | 0.63 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |
| formal/tests の Python の検査（10件、`--rust-dir` なし） | `check-formal.sh` と同じ指定（width・named・extensible・try は `python3 -I`、batch2〜5・range・interval は `python3 -B`） | 10件とも 0 | 計 37 秒 | [python-tests.log](python-tests.log) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 1b30f6f9fa5b76c6b3330152962ec13d8bd3475e --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更）と `formal_build`（`formal/Benitoite.lean` ほか） | 数秒 | [check-work-dry-run.log](check-work-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 1b30f6f9fa5b76c6b3330152962ec13d8bd3475e` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 9.66 秒 | [check-work.log](check-work.log)（計時の出力は末尾） |

公理: 106件のうち 103件は標準の三公理の部分集合だけに依る（三つ全て 85件、`propext`・`Quot.sound` 7件、`propext` だけ 11件）。3件（`occurrences_eq`・`mem_occ_key`・`guardPre_length`）は公理に依らない。`sorryAx` と独自の公理はない。対象は本枝で加えた定理の全て、言明か証明を変えた既存の定理（`ModelTargets.sig_cases`・`effects_cases`・`assumptions`、`ModelHttp.assumptions`、腕の位置を直した例）、主定理 10件と接続定理 4件である。カーネルの `decide` は `write_after_silent`（18 回の `step` の評価）と小さな所属・網羅性の判定だけに使った。

本書を書いた後に同じ指定の dry-run をもう一度走らせ、選択が同じ三つ（差分のファイルは本書と記録を含めて 28）であることを確かめた。本書と記録の追加は検査を選ばないので、work は再実行していない。

`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。work の `formal_build` は排他の道具を通らないが、作業末の全体のビルドの直後で組み立て済みである。Rust の lib 全件・clippy・fmt は選ばれず、加えていない。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。全体のビルドの値は、排他の道具が包んだ `lake build` の計時の木の中の最大のプロセスの値である。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド 1回目 | 1640857600 | 1564.8 | 1.53 |
| 全体のビルド 2回目 | 1643757568 | 1567.6 | 1.53 |
| 全体のビルド 3回目（Release の根から組み立て直した） | 3571597312 | 3406.2 | 3.33 |
| 作業末の全体のビルド（組み立て済み） | 71663616 | 68.3 | 0.07 |
| 公理の確かめ（`import Benitoite` の全体を読む単一ファイル） | 1529528320 | 1458.7 | 1.42 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、組み立て済みの `formal_build` を含む一括の値） | 1384775680 | 1320.6 | 1.29 |
| 試作の単一ファイル（`write_after_silent` と同じ評価を含む） | 782942208 | 746.7 | 0.73 |

本作業で観測した最大は 3.33 GiB（3回目の全体のビルド）である。作業末の全体のビルドは組み立てが起きなかったので、その値は Lean の常駐量ではない。`-M 12288` は変えていない。

## 失敗と修正

- 試作（一時ディレクトリ）: `step` は計算できない定義なので `#eval` で到達の段数を調べられなかった。`#reduce` で段数（18）を求め、カーネルの `decide` で同じ判定を確かめた。
- `check_fnTy`: 空の効果の範囲の具体化が `simp` で閉じなかった。補題 `instR_empty` を置いた。
- 腕の型付け: `Err` の腕の型の移動（`Ty.shift`）が残った。`Ty.shift_opaque` を足した。`callFE_typed` の構築器の文脈を `[]` に固定していたので、腕の文脈（`[none]`）に合わず、文脈を量化した。`armsEff` は計算できない定義の `abbrev` なので `noncomputable` にした。
- 網羅性: `CtorsComplete` の証明で `split` が宣言の形を展開できなかった。`resultCons c = some cd` の形に移して分けた。
- `fresh_ok`: `dif_pos` などが非推奨の警告を出したので、`simp only [h, dite_true]` にした。`passwd_not_allowed`: `decide` の目標に自由変数が残ったので、範囲の所属だけを `decide` にした。
- `ScopeOccurrence`: 最初の検査で 7 件の誤り（`args` の番号の付け替え、`ite`・`ifOnly`・`matchE`・`withE` の連結の深さの違い、腕の `guard` の場合分けによるカーネルの型の不一致）。腕は `preorderArms_cons`・`guardPre_length` を置いて場合分けをなくした。`ReachBlock.toAt` は名前空間の外の型への点記法のため、`_root_` の完全な名前で宣言した。
- `ModelTargets`: 項目の追加で `assumptions` の証明の場合分けが合わなくなり、全欄を七項目で書き直した。既存の例の応答の関係の腕の位置を直す置換で、`io_exists` の一行を誤って置き換えたので戻した。`read_admissible` の証明項の入れ子を戦術に替えた。
- `CheckAcceptExamples`: `let` の中の構造体の記法が構文の誤りになったので、`materialsOf` を分けた。
- 設計書の書き換えの台本を標準入力から読ませたとき、符号化の誤りで止まった（ファイルは変わっていない）。台本をファイルにし、UTF-8 で読み書きした。

## ずれと申し送り

### 計画からのずれ

1. 中3 の検査器の変更をしていない（上の「中3 について」）。取りまとめの判断を求める。
2. 中1 の例は `f` だけを main から呼ぶ（`h` は呼ばない）。依頼の「`f`・`h` を main から呼ぶ形でもよい」の範囲である。
3. 依頼の「`/data/a.txt` へ書く」の中3 の例は、`CheckAcceptExamples` の原子の一覧に `/data/a.txt` の原子を足した入力 `qTxt` で書いた。

### 停止条件の点検

- 主定理・接続定理の言明と前提、`Builtins.Assumptions` の欄、`Scope/` の採用定義の意味、公理は変えていない。結論の弱化はない。
- 実例の表に項目を一つと資源の型を加えた。既存の欄を表について満たし直しただけであり、欄の追加ではない。
- 中4 は補題で閉じたので、「番号の一致は R20 が同じ数え方で保証する」を Lean の信頼の対象にする形にはしていない（処理系の側の照合は R20 に残る。07-04 の軽10 の箇条）。

### 後の枝への申し送り

- 取りまとめ: 中3 の推す案（検査器を保つ）か代案 (i) かを設計者の確認の一覧に加える。README の確認点 (17) は前提が変わった（挙げた形は受理され、差は節の添字）。
- K10: `ModelTargets` の表の旧 Top の項目 `File.readText` は形式化の実例であり、処理系の項目との対応はない。
- R20・R30・R40: 下の一覧。

## L10〜L50 で R 段が合わせるべき点

### 1. 効果の包含: 被覆を使う位置と構造上に残す位置

- 被覆（判断 5 の一原子の被覆 `Eff.Covers`。同じ名前の閉じた範囲の原子どうしは `Range.Covers`、Top を覆うのは同じ名前の Top だけ、範囲の変数の原子と行の原子は同じ原子だけ、和では覆わない。Fail は構造上の所属）で判定する位置: Release の C-Sub・C-Eff、関数の型の潜在効果の `Ty.Le`、K-Handle の節の効果、K-Handle-Fail の Rest と節の効果。表層の E_Sub・B_Sub と呼び出しの頭。表層の検査器のラムダの本体、`resume` の引数、関数とメソッドの本体、関数の型の潜在効果（`tyLe`）。
- 構造上の包含のまま残す位置: C-Handle と K-Handle の保護本体（`ε ∪ handled(H)` への包含）、C-Handle-Fail の保護本体、K-Empty、K-Let、K-Guard、状態の型付けの `ε1 ⊆ ε`、表層の E_Handle・E_HandleFail の保護本体、部分適用 E_PartialCall、`HasMain` の `d.eff ⊆ allowed`。検査器では `handle` の保護本体と節、Fail の節、純粋の要求（空の上限）、部分適用の潜在効果。
- 検査器の `handle` の保護本体の構造上の包含は、処理しない原子が式の効果へ移るのでどの本体でも成り立つ。Rust もこの形なら同じ受理になる。

### 2. 節の添字の規則（判断 11）

- 範囲の変数を持つ組み込みの操作 b（`opEff = some l`、`nranges > 0`）の節の添字 S は、保護本体の効果が行の変数を持たず、名前 l の閉じた原子をちょうど一つ持つときその範囲、それ以外（複数の原子、同名の Top、行の変数、同名の原子なし）は Top。範囲の変数のない操作と利用者の操作は Top。
- 表層の型付けと検査器は規則の値だけを選ぶ（Release の型付けは Top も許す）。検査器は保護本体の推論した効果から選ぶ（`clauseIxIn`）。型付けは `B_Sub` で広げた効果から選べるので、検査器のほうが狭い（中3。推す案では R20 は Lean の検査器と同じ形）。
- 捕捉した操作の型は引数の最上位の対象の位置だけを S で具体化し（`opSigAt`、`Ty.instTarget`）、結果の型は範囲の変数を持たない（`PrimSig.Scoped` の S1 の条件）。

### 3. 範囲の列の書き出し

- 型検査器は受理した範囲の列を表層の `primName b ts es rs` に書き、脱糖はそれをそのままコアの `.prim b ts es rs` に書く（`desugar_primName`、`desugar_rangeFree`。脱糖の出力に範囲の変数はない）。範囲の変数のない項目は空の列。
- 交換は corpus 15・sidecar 7 の `ranges`（項 `prim` と表層 `primName`）、名前の原子 `{"name":{"value","ix"}}`、不透明型 `{"opaque":{"name","ix"}}` で、`ix` は `{"fixed":R}` か `{"rvar":i}`。`rvar` は型表の署名にだけ置け、その番号は項目の `rkinds` の個数より小さい。範囲は整形式で正規形でなければならない（`checkRangeInput`）。欠けた欄・余りの欄は拒否し、Top で補わない。
- 交換の不透明型の名前は「識別番号:型引数」の形なので、表のデータ `valKinds`・`valContents` も同じ形で書く。効果は一覧の原子の符号順に書き、検査器の入力の候補には呼び出しの範囲の列で署名の原子を具体化した原子を含める。

### 4. 受理の判定と拒否の理由

- 型検査器の入口は型付けの検査の後に、全ての定義と実装のメソッドの本体を `acceptBody` で受理する（`checkProgramAccepted`）。本体の始まりの鍵は番号 0（`bodyKey`）、束縛番号の土台は引数の位置（辞書の引数を含む。`entryScope`）、メソッドの本体の鍵の名前は関数の鍵と同じ変換（`methodKey`）。
- 本体ごとに局所解析を一度走らせ、組み込みの名前を頭に持つ直接の呼び出しの各出現で、規則が範囲を選ぶ位置に契約の範囲があり、それが選んだ範囲を `Range.Covers` で覆うことを求める。規則が Top を選んだ位置は Top だけを受理する。最初に拒否した出現の鍵（定義の名前と先行順の番号）と理由を返す。
- 理由は DET-05 の `notCovered`・`atomicCoverOnly`・`unknownSource`・`budgetExceeded`。明示の Top を `unknownSource` と区別せず、予算の超過があれば地点を問わず `budgetExceeded`（L40.6b 軽5）。Lean の入口は効果の上限の拒否を型付けの誤りとして報告するので、`atomicCoverOnly` を報告するなら K10 の比較で照合の方法を決める。
- 局所解析の扱い: 合流の後は外側の事実を残し、合流した値の位置だけを由来なしにする（L40.3）。`try e` の結果は既知にしない。リテラルのパターンの検査は予算の超過の後も既知、局所の文字列のパターンは未知。ラムダ・遅延・`handle` の保護本体と節の入口は由来を仮定しない。検査の成功値はパスなら対象だけ（`checkedOk`）、要求なら渡された要求を保持する（`requestOk`）。`primResolve` は名前の解決を終えた構文を前提にする。

### 5. 交換の版

- corpus 15・sidecar 7 は範囲・観測・拒否の理由・必須の判定の入力を持つ。corpus 15 の各入力は `scopeAcceptance`（処理系の解析器が読んだリテラルのパスのパターンとホストのパターンの表 `patterns`・`hosts`、本体と全体の上限 `limits`）を必須とする。旧版（corpus 14 以前・sidecar 6 以前）に範囲の欄を置いた入力は拒否し、旧版は明示の Top と空の範囲の列を加えて読む。
- 報告の形: `surfaceCheck` の `result.cover`、`surfaceCheckAll` の `required check is not covered: <番号> "<理由>"`、`desugarDiff`・`surfaceCheckAll` の `nonTopRanges`（全 Top だけの一致と区別するため 0 でないことを比較の条件にする）。整数のリテラルの U+0000 の表し方は比較で除く。

### 6. 出現の番号の数え方

- 区間解析と同じ先行順（`Interval.surfacePreorder`）。式は自分を先に数えてから宣言の欄の順の子を辿り、容器（式の列・腕・節・文の並び）自身には番号を付けない。文の並びは右辺、続きの順で、構築器の専用の束縛の位置は数えない。腕は guard、本体、残りの腕の順、節は本体を宣言の順に辿る。入れ子の本体（ラムダ・遅延・節）の出現も囲む定義の番号で数える。
- 文の始まりの記録の番号は、その文の右辺の出現の番号と同じである（Lean は `reachAt_occurrences` で示した）。Rust の局所解析の記録と型検査器の受理は、同じ数え方の同じ番号を使う。

## 時間

| 区分 | 時刻（2026-10-28） | 所要 |
|---|---|---|
| 依頼文と文書を読む | 11:41〜11:46 頃 | 約 5 分 |
| 中3 の再現（試作の `#eval`） | 11:46〜11:50 頃 | 約 4 分 |
| 中1（試作、型付け、到達の証明） | 11:50〜11:56 頃 | 約 6 分 |
| 中4（`ScopeOccurrence`、系） | 11:56〜12:02 頃 | 約 6 分 |
| 軽8（表の項目と例） | 12:02〜12:06 頃 | 約 4 分 |
| 中3 の例、設計書と docstring | 12:06〜12:13 頃 | 約 7 分 |
| ビルド・公理・Python の検査・work | 12:13〜12:17 頃 | 約 4 分（3回目のビルドの 150 秒を含む） |
| 本書 | 12:17〜12:30 頃 | 約 13 分 |

外側の所要は約 50 分、能動時間は約 45 分（ビルドと検査の待ち約 5 分は別）。見込み（2〜5 時間）の下端より短く、上端の2倍（10 時間）には近づいていない。中4 は見込みの2倍（4時間）の前に閉じた。時刻はログの時刻と外側の時計から推定した。
