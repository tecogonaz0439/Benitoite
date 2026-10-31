# RV-L00b.11: 型の正規形 D07 の移行と O001・O007 の独立レビュー

2026-11-01。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.11 の未コミットの作業ツリーにある `formal/` の本番の変更である。基準 `5fd3664e` からの差分は既存56ファイル（2171行追加、1010行削除）と新規14ファイルから成る。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.11-request.md)
- `l00b.11/` の `signatures.md`・`results.md`・`source-kind-contract.md`・`type-shift-contract.md`・境界の入力9件・`inputs-sha256.json`・`verification.json`
- `decisions.md` の D07・D19・D28、`plan.md` の L00b.11・L00b.13・L00b.15 の行、O001・O007 の行、rawApply と制約の読み手の判断（2026-10-31 の2行）、`l00a.06a/contracts.md` の差分、`l00b.02/signatures.md` の第31節
- 本番の `Conjunction`・`RefinementNormalForm`・`FunctionNormalForm`・`Normalize`・`Context`・`Typing`・`Le`・`Admissible`・`ExternalCheck`・`Canonical`・`InversionCore`・`TelTyping`・`ClosureTyping`・`Capture`・`StateTyping`・`StoreTransport`・`BuiltinResponse`・`ExternalResponse`・`SubstitutionContracts` の定義と差分

Lean は局所に実行した。補助のファイルはリポジトリの外（`<tmp>/rv11/`）に置いた。いずれも `cd formal && lake env lean -M 12288 <ファイル>` で実行し、全体の `lake build` は繰り返していない。

1. 境界の入力9件をすべて再実行した。誤り0件、`sorryAx` なしである。
2. `inputs-sha256.json` の145入力は今のファイルのハッシュと全件一致する。
3. `count.lean`。環境から HasTypeVQ 29、HasTypeCQ 24、ImageOk 4、Ty.LeQ 13、LocalRef.HasKind 3、ProperApply 7、TelLe 2、TelClosure 2 を読み取った。
4. `lam.lean`。`.lam ["x"] [Unit{true}] body` を実際に `closeVal` した閉包を `.fn ["x"] [Unit] Unit` で読み、`inv_closure` で逆転した。結論を仮定していない。公理は propext・Classical.choice・Quot.sound だけである。
5. `ret.lean`。`ContTy.end_normal` と `resume_raw_return` を証明した（軽1）。公理は同じ3つである。
6. `primraw.lean`。生の型引数を持つ閉じた組み込みの値が型付き（`prim_typed`）で、その型引数の `BuiltinArgs` が偽である（`args_rejected`）ことを示した（中1）。公理は同じ3つである。
7. `sigdiff.py`。基準版と現在の宣言の言明を機械的に比べた。基準2591宣言のうち、消えた6件と言明が変わった補助の59件を読んだ。

## 総評

**条件付き可**である。重の所見はない。読んだ範囲で、定理を偽にする誤りと、不正なプログラムを型付ける規則は見つからなかった。D07 の正規形は決定どおりであり、四つの新しい規則と `LeQ.convert`・`ImageOk.hidden`・`LocalRef.HasKind.normal` は意味を保つ。O001・O007 は計画の L00b.11 の範囲で閉じたと判断してよい。

条件は、中の2件を L20／L40 の義務として記録することである。どちらも今回の本番のコードの誤りではない。`canonical_of_wf` の撤回と `Ty.LeQ.convert` の結果、既存の `BuiltinArgs`・`CellOk` が読む前提が今の不変条件から供給できなくなった点であり、`signatures.md` と `results.md` の申し送りに載っていない。中1は Lean で再現した。処置の案は `StateTy` または信頼条件の入力に触れるので、L00b.13 の前に取りまとめが決めることを勧める。

## 観点ごとの判定

| 観点 | 判定 | 根拠 |
|---|---|---|
| 1. 連言の平坦化 | 可 | `Pred.conjuncts` は `and` だけを分解し truth だけを捨てる。falsity と重複は `[p]` のまま残る。`or`・`not` の内側へ入らない。`ofConjuncts` は右結合である |
| 1. 篩の平坦化 | 可 | `refineNorm` は芯と芯から外への述語列を連結する。self は内外とも同じ番号なので移動は要らない。`Ty.norm_refineNorm`・`refineNorm_assoc` は無条件である |
| 1. fn の正規化 | 可 | `fnView?` は `FnView.toTel = t` の証人があるときだけ `fn` を返す。`NamesWF` を証人が持ち、依存する列は `foldFn_no_view` で保たれる。`toTel_injective` で一意である |
| 1. 論理同値の紛れ込み | 可 | `Ty.norm` の分岐に Entails はない。述語の並べ替えも置換もしない。truth の除去は plan の判断どおりである |
| 1. `norm_idem` と交換 | 可 | `Ty/Tel/Eff.norm_idem`、`norm_shiftV`、`norm_rawBind`、`norm_shiftTypes`、`rawApply_norm` はいずれも無条件で、kind も WF も要らない。`Ty.bind` は rawBind の後の norm のままである |
| 2. `V_Normal`・`C_Normal` の必要性 | 可 | 読めば確定する。`.var 0` で Γ の型が `raw` のとき、`raw.norm` へ入る規則は V_Normal だけである。V_Sub は Sorted で、V_Refine は述語の sort で落ちる。主定理は Γ の Sorted を要求せず、`SubstOk.upValue`・`openValue` の束縛変数の像が正規形を要るので、本番から消せない |
| 2. `C_ResumeNorm` の必要性 | 可 | `resume_normal_entry` の入力で `v : raw` は導けない。結果の `t.norm` と `Eff.norm e` は `substTyValues` の像と一致する |
| 2. `C_ResumeLNorm` の必要性 | 可（軽1） | `full_substitution_entry` は元の置換主定理の結論としてこの判断を得る。規則がなければ主定理が偽である。ただしストアは `StoreOk` ではない。実際の状態では生の等号へ戻せる |
| 2. `C_DependentAppNorm` | 可 | `dependentApp_normalized` は構成子でなく補題であり、`FnView` の有無の2場合を閉じている |
| 2. `R'.map norm = R.map norm` | 可 | none と some を混ぜない。`C_Lazy` の none の内側で新しい再開は生じない。`.escape` の値の型の照合は norm の等号の範囲で意味を保つ |
| 2. `LeQ.convert` | 可 | `notContCore`・`assume`・`listCore`・`fnCore`・`refCore`・`names_eq` の全補題が convert の場合を持つ。Reference の共変は `reference_covariance_rejected` で拒否される |
| 2. `ImageOk.hidden` | 可 | `¬Ordinary` かつ生の cont でない束縛は V_Var・C_Resume・`Ctx.Readable`・`assume` のどれからも読めない。`hidden_not_wf` で WF と両立しない |
| 2. `LocalRef.HasKind.normal` | 可 | 書き込みの値を生の要素型へ戻すための Annotation は `BuilderCellOk` が持つ |
| 2. canonical forms の逆転 | 可 | `inv_list`・`inv_closure`・`canonical_ref` は V_Normal を convert の LeQ で V_Sub と同じに扱う。`assume_norm` で事実の列も保たれる |
| 3. 利用者の書ける形 | 可 | 新規則は導出を増やすだけである。減るのは cont を芯に持つ篩の変数と、`sat` が生の型と正規形で異なる表の場合だけであり、前者は WF が元から除き、後者は取りまとめの判断の範囲である |
| 3. 信頼条件の欄 | 可（軽2） | `Builtins` の欄、`ValueAssumptions`・`TypeAssumptions`・`ResponseAssumptions`・`ExternalAssumptions` の本文に差分はない。量化の意味の変更は D28 の記録がない |
| 3. 項と実行 | 可 | `Val.subst`・`Val.shiftEAt`・`closeVal`・`Closure.view`・`Semantics`・`Step`・`StateTyping`・`externalCheckedOutcome` に定義の差分はない |
| 3. valContent | 可 | 読み手を `T.norm` へ替えただけであり、表は不変である。元の導出は V_Normal で渡せる |
| 4. 反例の反転 | 可 | `original_derivation_rejected` は V_Normal を含む29場合を尽くす。`assumptions` は全欄を構成し、結論を仮定していない |
| 4. 撤回した補題 | 可 | `normalization-retractions.lean` の否定はいずれも `Unit{true}` の具体的な計算である。`of_arguments_without_normal_false` は全入力と結論の否定を同時に構成し、`old_resume_location_contract_false` は WF のあるストアで成り立つ |
| 4. `Normal` の前提 | 可 | 足したのは補助の `normal`・`instantiate`・`arguments`・`of_arguments`・`ClosureTy.pure` だけである。呼び出し元は `Tel.norm_idem` で供給でき、閉包は `cases` で得られる（`lam.lean`）。利用者の型を制限しない |
| 4. 主定理 | 可 | `HasTypeVQ/CQ` の `subst`・`subst_under_none`・`shift_values`・`shift_types`・`narrow` の言明は基準版と一致する。変わったのは補助の言明だけである |
| 5. 閉包の正例 | 可（軽3） | `closed_lambda_fn` は結論を仮定していない。引数なしの例だけなので、引数ありを `lam.lean` で確かめた |
| 6. 五つの境界 | 可 | 主定理の前提と結論、提供範囲、利用者の書ける形、精密な外部状態は変わっていない。`Refinement` と集約に `sorry`・`axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern` はない。`lakefile.toml` 等にも差分はない |
| 7. 場合の数 | 可 | 手順3のとおり依頼の数と一致する |
| 7. O001・O007 | 可 | 計画の定理の形と境界の正負の入力を確かめた。全 canonical forms は L40 の範囲である |
| 7. 申し送り | 条件付き | 中1・中2・軽1が不足する |
| 8. ビルド時間 | 可（軽4） | 目立つのは file 単位の `set_option` である |
| 文書の規約 | 可（軽5） | 手元の絶対パス、`work/` の参照、docs/todo へのリンクは対象の文書にない |

## 新しい所見

### 重

なし。

### 中

**中1. 生の型引数を持つ組み込みの値では `BuiltinArgs` を作れない**（`BuiltinResponse.lean` 15行、`Capture.lean` 42行と `.var` の枝、`Typing.lean` の V_Prim。Lean で再現済み）

問題: `BuiltinArgs.types` は `t.Canonical` を要求する。基準版では `canonical_of_wf` が WF から供給したが、これは偽として撤回した。`closeVal` と `Closure.view` は `.prim b ts es rs` の項を正規化するが、`.var i` は `cap.env i` をそのまま返す。V_Prim の `PrimitiveAdmissible.typeScope` は WF だけを要求するので、`StateTy` は捕捉環境の中の `.prim b [Unit{true}] [] []` を除かない。

このとき `q.view = .app (.prim b [raw] [] []) ws` となり、`delta_typed`・`io_exists` の前提を満たせない。`CoreAssumptions` は非正規形の `ts` で `B.delta` が定義されることを求めないので、L40 の進行で行き止まりになる。実行は `closeVal` だけで値を作るので実際には生じないが、それを述べる不変条件がない。

再現: `<tmp>/rv11/primraw.lean` の `prim_typed` は `HasTypeV P B Ψ [] [] [] (.prim "p" [raw] [] []) _` を導き、`args_rejected` は同じ型引数の `BuiltinArgs` を否定し、`view_raw` は捕捉環境の値が `view` にそのまま現れることを示す。

`ExternalArgs.types` は同じ欄を持つが、`.externalCall` は計算の項で、`view` が必ず `closeTy` を通すので同じ問題はない。

修正案: 今回の本番は変えない。L20 の前に次のどれかを取りまとめが決める。

- 値に埋まった型引数が正規形であるという不変条件を `StoreOk`・`CaptureOk`・`ContTy` へ足す。`closeVal`・`Val.subst` が保つことを示す。`Val.shiftEAt` の保存は別に確かめる。
- `E_Prim` などの遷移が `Ty.normTys ts` を信頼条件へ渡す。実行の規則の変更になる。
- `BuiltinArgs.types` の Canonical を外す。D28 の意味の変更になり、L60 の負担が増える。

**中2. Reference への書き込みの保存に要る `v : b` を、今の `StoreOk` から導く道が示されていない**（`StateTyping.lean` 110行の `CellOk .val`、`StoreTransport.lean` の `LocTy.WF`、`Canonical.lean` の `canonical_ref`。実行しないと分からない疑い）

問題: O007 により `canonical_ref` は `Ψ l = some (.ref b) ∧ b.norm = a.norm` を返す。基準版では生の等号だったので、`E_RefSet`・`E_RefUpdate` の書き込む値は格納の型 `b` をそのまま持った。今の値は `a`（署名の具体化の後なので正規形）を持ち、`CellOk .val` は生の `b` を要求する。

`b` が正規形でなければ V_Sub が要る。`StoreOk` が持つのは `Ψ.WF` と `StoreTy.Declared` だけで、Sorted がない。`V_LocRef` も Declared しか要求しない。`Normal` の不変条件もない。`Unit{true}` を格納の型とする `StoreOk` は作れるので、正規形を前提にできない。読んだ範囲では「閉じた値の型は Sorted である」補題で埋まる見込みだが、ストアについての帰納が要り、`Ty.sorted_norm` の逆向きも要る。どちらも本番にない。反例は作れていない。

継続の入力は `K_Sub`、builder は `BuilderCellOk` の Annotation、lazy は `K_Sub` と共変で足りるので、この問題は `.val` の書き込みだけである。

修正案: L40 の義務に足す。`CellOk .val` が `HasTypeV v a.norm` を読むように改めるのが最も小さい。V_Normal で入口を作れ、読み出しも norm の等号で足りる。代案は `StoreOk` へ ref の内容の `Sorted` または `Normal` を足すことである。

### 軽

**軽1. 実際の状態では、再開の R は生の等号へ戻せる**（`Typing.lean` の C_ResumeLNorm、`signatures.md` の「後続の全状態の保存では」、`StateTyping.lean` の K_Empty。Lean で確認済み）

`resume-return-contract-obstruction.lean` のストアは `StoreTy.WF` だけを満たし、`StoreOk` ではない。規則は一般の Ψ を量化する主定理のために必要であり、否定は正しい。一方、`K_Empty` は `R` と `Re` の生の一致を要求するので、継続の連結には生の等号か、R を付け替える76場合の補題が要る。

`<tmp>/rv11/ret.lean` の `ContTy.end_normal` は `EndsWithHandle k` のとき末尾の `Re` が正規形であることを示す。`K_Handle` の `cap.closeR Rs = R` による。`resume_raw_return` は `StoreOk` と `.cont` のセルから、現在の R が正規形なら `r = R` を導く。現在の R の正規形は `closure_return_normal` で得られる。

修正案: 2つの補題を L20 の補題として本番へ置き、申し送りの「生の等号を仮定しない」を「`StoreOk` の下で生の等号を導いて連結に使う」へ具体化する。R の付け替えの補題は要らなくなる。

**軽2. D28 の新旧対照の記録がない**（`results.md` の「信頼条件の欄は強めていない」。読めば確定）

欄の文言は同じだが、`delta_typed`・`io_typed`・`io_exists`・`external_typed`・`external_exists` が量化する `HasTypeTelArgsQ` と `PrimitiveAdmissible` の意味は変わった。導出は V_Normal・`LeQ.convert` を含み、`admits` は `normTys` を読む。`sat_values`・`sat_renameTypes` などの入力も、呼び出し側は正規形の `a` に限って使う。D28 は「欄名が同じことを前提の維持と呼ばない」と定める。`BuiltinArgs.types` の Canonical が `ts` の広がりを止めているので、実質の増分は小さい。

修正案: L00b.15 の新旧対照に、制約の読み手の変更と導出の増加を載せる。L60 の実表で `sat`・`admits` を正規形の上で定めることも義務に書く。

**軽3. 閉包の正例が引数なしである**（`l00b.11/boundary.lean` の `closed_lambda_fn`。読めば確定）

引数がないと `toTel` の移動も `Tel.bind` の正規化も通らない。`<tmp>/rv11/lam.lean` で、篩 true の付いた仮引数を持つ閉包を `fn` で読めることを確かめた。D07 が狙った問題は解けている。同じファイルの `cases hb` で閉包の Tel が `Normal` であることも得られる。

修正案: `lam.lean` の例を境界へ足す。`DependentClosureTy.normal` を補題にすると、L40 の `arguments` の呼び出しで `hn` を供給しやすい。

**軽4. file 単位の探索の上限が増えた**（`HandlerTyping.lean` 6行、`Narrowing.lean` 10〜11行、`SubstTypingObstruction.lean` 13行。読めば確定）

3ファイルに `maxHeartbeats 2000000` を、`Narrowing` に `maxRecDepth 4096` を足した。どの宣言が要るかは分からない。`results.md` の時間は増分ビルドなので、全面ビルドの増減は記録にない。

修正案: 次の全面ビルドの時に時間を記録し、遅ければ `set_option ... in` で宣言へ絞る。

**軽5. 文書の小さなずれ**（読めば確定）

- `signatures.md` 58行の「全28場合」は、入力と `results.md` の「全29場合」と合わない。
- 依頼と `results.md` の「既存57」は候補の数である。基準との差分は56で、`BindCongr.lean` に差分はない。
- `Ty.Canonical` と `Ty.Normal` は同じ定義を二つの名前で持つ。`BuiltinArgs` は前者、新しい補題は後者を使う。L20 の前にどちらかへ揃えるとよい。

**軽6. `Tel.fnView?` は計算できない**（`FunctionNormalForm.lean` 83行。読めば確定）

`fnView?` は `Classical.choose` で定義するので、Lean の中で `foldFn` は簡約しない。Rust の検査器には、各段の移動を戻せるかを調べる手続きが要る。`signatures.md` の L20 の義務は「接続」だけを述べる。

修正案: L20 の義務に「`fnView?` の決定手続きと、Lean の存在の定義との一致」を足す。

## 読めば確定する事項と実行で確かめた事項

- 読めば確定: 観点の表の判定のうち Lean の実行を挙げていないもの、軽2〜軽6。
- 実行で確かめた: 境界の入力9件の再実行、入力のハッシュ、場合の数、基準版との言明の比較、引数のある閉包の正例、軽1の2補題、中1の再現。
- 実行で確かめていない: 中2が実際に閉じないかどうか。全 canonical forms と保存・進行の全体（L40）。実表の `sat`・`admits`（L60）。全面ビルドの時間。

## 取りまとめの追記

2026-11-01。補助の入力 `<tmp>/rv11/` を `l00b.11/rv-11-ret.lean`・`rv-11-lam.lean`・`rv-11-primraw.lean`・`rv-11-count.lean`・`rv-11-sigdiff.py` へ写した。処置は次のとおりである。

- 中1: 組み込みの遷移が正規形の型引数と行の引数を信頼条件へ渡す。同じセッションで直す（plan.md の 2026-11-01 の行）。
- 中2: `CellOk .val` を `a.norm` で読み、読み書きの補題と正例を足す。同じセッションで直す。
- 軽1: `ContTy.end_normal`・`resume_raw_return` を本番へ置き、申し送りを具体化する。
- 軽2: L00b.15 の新旧対照に載せ、L60 の実表の義務に書く。
- 軽3: 引数のある閉包の正例を境界へ足し、`DependentClosureTy.normal` を補題にする。
- 軽4: 取りまとめが work の全面ビルドの時間を読む。
- 軽5: 文書を直し、`Ty.Normal` を `Ty.Canonical` の別名にして定義を一つにする。
- 軽6: L20 の義務に足す。
