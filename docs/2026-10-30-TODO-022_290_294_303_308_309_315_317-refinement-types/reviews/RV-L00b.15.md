# RV-L00b.15: 01-12・07-04 の写しと主な定理の対照の独立レビュー

2026-11-01。基準は `8819025a0a35c9bac7e78fb97c7dff00829228db`、対象は `m014/l00b.15` の未コミットの作業ツリーである。

**判定: 条件付き可。所見は計12件（重0・中5・軽7）である。**

本文の写しに偽の規則はなかった。中1だけが新しい事実で、今の `CoreAssumptions` のままでは計画した `effect_soundness` が偽であることを Lean で再現した。方式の変更は要らず、旧の前提の移し替えで足りる見込みである。この点は O160 の再提示の前に処置を決める。

五つの境界のうち、中1と軽2が「主な定理の前提」に触れる。新しい公理、提供範囲、利用者の書ける形、精密な外部状態に触れる所見はない。

## 所見

### 中

**中1. `io_op` は要否を調べる段階ではなく、必要である**（`l00b.15/theorems.md`「CoreAssumptions と旧 Assumptions の全欄の対応」の io_op の行、G05 の行、「方式の変更の兆しと未確定の点」。動かして確定。**境界: 主な定理の前提**）

theorems は「要否を L20 が再現して調べる」「未確認候補を確定した反例と呼ばない」と書く。しかし、次の反例が成り立つ。

- 補助の入力: `<tmp>/rv15/T1.lean`。`sorry` なし、公理は許可の三つだけ。
- 表: kind が `.io`、`opEff = none`、効果が `Eff.empty`、引数なし、結果 Unit の項目 `evil` と、get/set の項目を持つ。
- `assumptions : Builtins.CoreAssumptions P B` を全欄について構成した。
- `typed : HasTypeC P B StoreTy.empty [] [] [] none code U Eff.empty`。閉じた計算が空の効果で型付く。
- `step_io`: その計算は `E_IO` で IO の事象を出す。
- `not_covered`: この事象は `Event.Covered` をどの効果でも満たさない。

つまり「閉じた `a ! empty` は IO の事象を出さない」は、今の `CoreAssumptions` からは導けず、結論が偽である。旧ではこれを `io_op` が防いでいた。`opEff_io` は opEff から kind への向きしか言わず、kind が io なら opEff と効果の形を持つという向きは `io_op` だけが与える。旧の使用先は `Lemmas/EffectSound.lean` 77行と `Lemmas/PresMain.lean` 554行・579行、`TargetSound` である。保存の E_OpPrim だけでなく、effect_soundness と対象の健全性の前提である。G05 の OpPrim の行だけに置くと依存を取り違える。

同じ形の不足がもう一つある（読んだ範囲。未再現）。旧 `ShapeOk` は `b ∈ bs` を含むが、`PathBasesShape` は `opEff` だけで、`B.effects processEnvironmentEff` への所属を要求しない。`handled` は `B.effects` の一覧だけを見るので、別の操作の節だけで Process.Environment を消しつつ、`NoHandler` のままの pathBases の発行が通る表を書ける。io_op の写しの kind を io/exit に限ると、この穴が残る。

修正案: (1) theorems の該当の行を「必要。反例あり」へ改め、`rv-15-t1.lean` として写す。(2) `ShapeOk` の新しい形を `CoreAssumptions` へ足す。kind に pathBases を含めて所属も要求する。(3) 時期は取りまとめと設計者が決める。L20 の冒頭か L10 の前であり、G05 の依存を effect_soundness・対象の健全性まで広げる。(4) O160 の再提示で、state_effect・ref_get に続く同じ形の不足として示す。

**中2. 「既に設計者が選んだ」の範囲が広すぎる**（`theorems.md`「設計者が見直す判断の全一覧」の最後の段落。読めば確定）

本文は「既に設計者が選んだ強い Kleene の三値、rawApply の篩の枝、制約を正規形で読む変更」と書く。plan の行では、設計者の決定は強い Kleene だけである（2026-10-31「設計者の決定、RV-L00b.04」）。rawApply と制約の正規形読みは「取りまとめの判断」で、「設計者への問いにしない」と明記されている。δ/IO の入力の正規化と `CellOk.val` の `a.norm`（2026-11-01）も取りまとめの判断である。6件の数自体は「設計者の見直しの対象」の印の6行と一致するので正しいが、この一文のまま提示すると、設計者が承認していない判断を承認済みと読ませる。

修正案: 強い Kleene だけを設計者の決定とする。他の三件は「取りまとめの判断で、境界に触れないとして問わなかったもの」の別表にして、O160 で報告する。

**中3. 状態と遷移の規則の写しが足りない**（01-12「篩を含む状態の型付け」「保持要求と組み込みの遷移」「篩の正規形と制約の読み方」、`mapping.md`。読めば確定）

plan の L00b.15 は「実際に置いた定義・規則を同じ変更で写す」である。新しい6節に次がない。

- `ContTy` の `K_Handle`・`K_Handle_Fail`・`K_Let`・`K_Mark`・`K_Release`・`K_Drop`・`K_Sub`。特に `K_Handle` の `Eff.Covers [] [] ε ec`、`Eff.Sub eb (Eff.union ec (handled P B h))`、hideBuilders の下の捕捉、`Frame.Adequate`。01-12 の既存の K-Handle は Release の規則である。
- `C_Handle_Fail`・`C_Use`・`C_IssuePathBases`・`C_CheckAt`・`AtCallAdmissible`。節の `ClauseSig`・`ClauseIxOk`・`OpSig.context`・`failureContext`。
- 遷移の `E_PathBasesApply`・`E_IssuePathBases`・`E_AtOk` の系、`E_OpPrim` の kind に pathBases を含むこと、`Event.pathBases`・`Event.Covered`。
- 部分型の `Ty.LeQ.scoped`・`scoped_forget`。後者は Inhabits の既知の不足の原因なのに、本文に規則がない。

修正案: 上の規則を写すか、01-12 に「Step の全76遷移と ContTy の全枠は Lean を正とし、本節は次の差分だけを写す」と範囲を明記し、`K_Handle` と `scoped_forget`・pathBases の遷移だけは必ず写す。

**中4. 処理系が従う抽象機械の文が、新しい節まで及ぶと読める**（01-12「本章の位置付け」。読めば確定）

追加の段落の直後に、既存の「処理系は、本章の抽象機械と同じ観測できる振る舞いを示さなければならない」が続く。篩の節は同じ章にあり `【決定】` が付くので、Rust が `ExternalRefinement` や強い Kleene の三値に今従う義務があると読める。07-04 は否定しているが、01-spec だけを読む実装者には伝わらない。設計書の「実装済みの内容だけを書く」にも関わる。Release と Refinement の区別の段落は「提供範囲や全状態の定理の拡張ではない」と言うだけで、この義務の除外を言っていない。

修正案: 追加の段落に「『篩を含むコア計算の形式化』以下の節は、この後の段落の抽象機械に含まず、処理系への要求ではない」の一文を足す。

**中5. G/H の配分が L20/L40 の枠を使い切り、枠の他の中身の分が残らない**（`theorems.md`「一般化の残りの全一覧と重複しない配分」。読めば確定）

G01〜G09 の和は 39〜90、H01〜H04 の和は 18〜42 で、plan の L20・L40 の枠と端点まで一致する。文書は「枠の内数」と言うが、差が0である。一方、L20 の枠には本番追随の1〜2時間（O160 の最初の同種10〜20件を含む）と q_mono/store/hide/rename/localRefs、旧 Lemmas の RangeInst の移しがある。L40 の枠には各幅・Character・Float・Decimal・長さ・欄・Map/Set の契約がある。これらは G/H の行に明示がないか、一部しかない。

修正案: 13行の時間を「状態の代表の一般化の案」と「枠の残り」に分けるか、行ごとの時間は確度のない配分であり和の一致は合わせたものだと明記する。下の評価も添える。

### 軽

**軽1. `Admissible` は `admits` を読まない**（01-12「篩の正規形と制約の読み方」の「`Admissible`・`PrimitiveAdmissible` は `sg.admits C (Ty.normTys ts)` を読む」。読めば確定）。`Admissible` の欄は `types : SatAll …` で、`sg` がない。`admits` を読むのは `PrimitiveAdmissible` だけである。`Admissible` は `SatAll` を通じて読むと直す。

**軽2. 旧の他の三欄も使用先は既に分かる**（`theorems.md` の sig_scoped・sat_unconstrained・admits_sat の行。読めば確定。**境界: 主な定理の前提**）。`sat_unconstrained` は `Lemmas/PresFailure.lean` 29行の E_OpFail、`admits_sat` は `PresMain.lean` 568行の E_OpPrim、`sig_scoped` は `PresBase.lean` ほかである。「L20/L60 で追う」を、使用先の遷移を名指しした G05 の入力へ改める。sat_unconstrained は失敗節の `{}` の型の束縛に要り、今の `sat_subst` の前提の `SatAll` を満たす手段が他にない見込みである（未再現）。

**軽3. 「Top はすべてを覆う」の範囲**（01-12「篩を含むコア計算の形式化」の `RangeExpr` の段落。読めば確定）。`RangeExpr.Covers` については正しいが、`RangeIx.Covers (.fixed top) (.rvar i)` と `Atom.Covers` は偽である。続く `RangeIx` の文に「fixed は rvar を覆わない」と足す。

**軽4. 「同時構成」は定義のない造語である**（07-04「篩を含む形式化の範囲」。読めば確定）。本文で定義しているが、用語集になく他の言語の呼び名の確認もない。「導出からの構成」など説明の文にするか、用語集の手順に従う。

**軽5. 短絡の文は Lean にない**（01-12「条件とパターンからの事実」の「短絡 And/Or のコアの表現には、この if の規則を用いる」。読めば確定）。`Refinement` の `Comp` に短絡はなく、脱糖も未実装である。L30 の残りには短絡の偽側もある。この文を削るか、脱糖の新体系への接続は範囲外と書く。

**軽6. 他段の申し送りに漏れがある**（`theorems.md` の L30・L40 の行。読めば確定）。次の4件が表にない。`.14e` の L30「実装の節の入力/結果・切り出し・resume・used・解放の照合」、`.14d` の L30「実表・Rust の結果型の共変性と篩の格納・観測」、`.14e` の L40「先頭 guard の空行と操作の不可能性」、`.04` の「鍵の言語上の等値」。

**軽7. 再実行の入口が一時領域に依存する**（`l00b.15/check-documents.py`、`verify.py`、依頼文「検査の証拠」）。台本は `baseline.json` の `<tmp>` の写しを読むので、一時領域が消えると再実行できず、`check-documents.py` は最初に `document-check.json` を false へ書き換えて記録も壊す。手元の絶対パスは検査の正規表現だけで、公開してよい形である。依頼文に再実行の条件を書くか、比較の入力を改造へ写す。

## 確かめて問題がなかった重点

- 旧の `CoreAssumptions` の全20欄と `TargetAgreement` を読み、theorems の対応と照合した。未移行は io_op・release_exists・sig_scoped・sat_unconstrained・admits_sat の5欄で、sat_local/admits_local は補題である。07-04 の列挙と一致する。
- D07 の連言（順序と重複の保持、true の除去、false の保持）、`Ty.Normal` の別名、`foldFn` の判定、`rawApply` の篩の枝、鍵の `a.norm`、δ/IO の入力の正規化、`CellOk.val` の `a.norm`。
- `evalClosed`、atomReady、三値表の9行、通常の短絡との差、`Entails` の規則。
- `C_If`、`C_Match`、`plain`、`guarded`（後続は元の Φ）、PathTest の全場合、構成子の除外の条件、`GuardBodyTy`、`K_Guard`。
- `groundTy`/`groundVal`、`V_CheckedRequest`、`CheckedWitness.request`。外部の宣言と受信の記述。`K_Update`、`StoreShape`、`state_effect`、`EffectsOk`、C-Handle に独立の `Eff.WF` がないこと（Release も同じ）。`CellOk` の表、`StoreOk`、`StateTyE`。
- 共有層の出典と `Shared/Approximation.lean` の記述。
- 代表の分類は各 results の冒頭と一致し（.14a〜.14c が閉じた、.14d・.14e が一部）、開始の逆転の有無も正しい。全状態の定理があると読める記述はない。
- 見直しの6件は plan の印の6行と一致し、境界・影響・手戻りの記述も plan と矛盾しない。
- 値29・計算24・相互76構成子、Step 76 の件数は Lean の定義の数え上げと一致する。三章の SHA-256 は `document-check.json` と一致する。`mapping-origins.lean` は223名で再実行して成功した。`spec_examples` は記録の7件の成功を読んだ（再実行はしていない）。見出しの改名なし、章から todo/archive/改造へのリンクなし。telescope は原語のままである。
- 用語集の出典のうち Erg と Agda は本文で確かめた。FSS2020 の PDF は取得できたが本文を読めず、「強 Kleene の三値論理」の用例は未確認である。

## 残りの見込みの評価

57〜132時間は、L20 と L40 の既存の枠の和そのものであり、新しい見積もりではない。文書もそう書いている。

実績との関係は次のとおりである。.03〜.14e の11作業の担当の外側の時間は約12.7時間で、計画の22〜52時間の下端を大きく下回る。比は0.24〜0.58である。ただし .02 は約12時間で、当初の3〜10時間を上回った（後から相互補題を移したので単純には比べられない）。.02 を含めると約24.7時間対25〜62時間で、約0.4〜1.0である。短いのは主に限定の強い代表である。上の比を単純に掛けると14〜77時間だが、これは参考にとどめ、全残件へ適用しない。レビューと反例の処置の待ちも含まない。

見込みを大きく見誤る要因は次である。

- G03: 型置換の別族。14判断76場合で、代表には経験がない。.11 の正規化の改訂は一度で約4.4時間を要した。
- G04: 緩い捕捉からの正則性。結論を弱めずに閉じる形が未確定である。
- G09/H01: `Inhabits` の修正。定義の変更は網羅性と表層の検査へ波及する。
- 中1と同じ形の追加: L00b の後半で6回、主な定理の前提か定義の不足が出て、今回で7回目である。

## 方式の変更の兆し

Nat/WF・捕捉環境・閉じた評価の方式を変える根拠は、今回も見つからなかった。「兆しなし」の結論は保てる。ただし、根拠の範囲は開始からの逆転の代表までであり、G03・G04・G09 を未確認のまま残す記述は適切である。設計者へは、方式の問題と別に、旧の前提の移行が未完で反例が既にあることを示す必要がある（中1）。

## 区別

- 読めば確定: 中2〜中5、軽1・軽3〜軽7、中1の「旧の使用先」。
- 動かして確定: 中1の主文（`<tmp>/rv15/T1.lean`、`lake env lean -M 12288` で成功）。
- 未再現: 中1の pathBases の所属、軽2の sat_unconstrained の必要性。

## 取りまとめの追記

2026-11-01。`<tmp>/rv15/T1.lean` を `l00b.15/rv-15-t1.lean` へ写した。中1は `plan.md` の先頭の判断のとおり、`ShapeOk` を `CoreAssumptions` へ移し、`PathBasesShape` に所属を足して本番へ入れる。中2〜中5、軽1〜7 は同じ再開で処置する。

## 再レビュー

2026-11-01。範囲は処置した箇所に絞った。対象は `ConstraintAssumptions.lean` の差分、`BuiltinEffects.lean`、`l00b.15/boundary.lean`、01-12 の追加、`theorems.md` の該当の表である。全体の再実行はせず、補助の入力 `<tmp>/rv15/T2.lean` だけを検査した。

**判定: 条件付き可。所見は計4件（重0・中1・軽3）である。** 中1の処置は正しく、反例は排除された。残る中1は、処置の誤りではなく、未移行の欄の時期の判断である。

再中1だけが「主な定理の前提」に触れる。ほかの四つの境界に触れる所見はない。

### 所見

**再中1. 未着手の4欄のうち3欄は、L20 を待たず今移せる**（`theorems.md` の #4・#5・#20、G08。読めば確定。**境界: 主な定理の前提**）

`release_exists`・`sat_unconstrained`・`admits_sat` の言明は、新の判断へ置き換えるだけで決まる。いずれも一文で書け、未定義の補題に依存しない。`release_exists` は `HasTypeV … v (.opaque o (.fixed .top))` と `isResource` から応答の存在、`sat_unconstrained` は閉じた型について `B.sat [] t.norm {}`、`admits_sat` は `s.admits C (Ty.normTys ts)` から `SatAll` である。必要なことは旧の使用先で分かっており（下の確認）、この3欄がない限り進行と E_OpFail・E_OpPrim の保存は言明できない。L20 まで待つと、state_effect・ref_get・io_op と同じく、後から前提を足して表と利用例を直す手順を繰り返す。

`sig_scoped` は別である。`PrimSig.Scoped` は Refinement に定義がなく、依存列と範囲の束縛に合う形を決める作業が要るので、L20 でよい。

修正案: 3欄を今足すかを、O160 で独立の問いとして設計者に示す。今足す案の影響は、`CoreAssumptions` の3欄と、正の表・利用例の追随である。L20 に残す場合は、その判断と理由を記す。

**再軽1. 具体化後の効果への補題が名指しされていない**（`theorems.md`「io_op と PathBases の決定の記録」、G05。読めば確定）

`io_event_covered`・`pathBases_event_covered` の言明は正しく、`s.eff` についての局所の事実である。ただし `effect_soundness` が読むのは `BuiltinArgs` の具体化後の `e` なので、このままでは使えない。必要なのは旧 `ShapeOk.inst_eff_mem` に当たる「`ShapeOk` と `BuiltinArgs` から `∃ ix, e.mem (.name l ix)`」である。`.single` では `.rvar 0` が `rs` で置き換わるので、`Event.Covered` の `r` は `s.eff` の `r` と別になる。「署名の効果による被覆」と「具体化後から Eb への伝播」の区別の記述は正しいが、後者の最初の補題が欠けている。G05 か G07 に `inst_eff_mem` 相当を名指しする。

**再軽2. 境界に `.single` と全欄の正例がない**（`l00b.15/boundary.lean`。動かして確定）

`accepts_io_shape` は `.untargeted` の `ShapeOk` だけで、`CoreAssumptions` 全体が満たせるかは示していない。`<tmp>/rv15/T2.lean` は、untargeted・`.single`（`opaque "PathIn" (.rvar 0)`）・pathBases・get/set を持つ表で `CoreAssumptions` の全欄を構成した。`sorry` なし、公理は許可の三つである。応答は err だけの表である。したがって新しい欄は空虚ではない。この入力を `l00b.15/rv-15-t2.lean` へ写すか、境界へ足す。

**再軽3. `.scoped` の引数は `ShapeOk` で受理しない**（`ConstraintAssumptions.lean` の `ShapeOk`。読めば確定）

旧と同じ内容にした結果であり、誤りではない。`.checkedAt` などの値は `.scoped` の型を持ち、`scoped_forget` で `opaque o ix` へ渡るので、引数を `opaque` と宣言した表で動く。L50 の実表が引数を `.scoped` で宣言すると `io_op` に落ちるので、その義務を L50 の行に書く。

### 確かめて問題がなかった点

1. **ShapeOk:** 旧と連言が一致する。`.single` の `s.eff` は旧 `singleAt l (.rvar 0)` と同じ一原子で、`rkinds = [k]`、`opaque o (.rvar 0)`、`valKind`、`neffs = 0`、`b ∈ bs` もある。`rejects_evil` は `opEff = none` から矛盾を導き、本物の拒否である。`rejects_missing_pathBases_member` も同じ。正の側は再軽2の T2 で確認した。新の三モデルはまだなく、実表の充足は未証明である。theorems はそう書いている。
2. **被覆の補題:** `E_IO`・`E_IssuePathBases` の入力と言明が一致する。`operation_not_handled` は `EffectsOk` の第三連言を正しく使う。
3. **01-12:** 追加の9個のコードブロックを規則・定義の単位に分け、空白を除いて Lean と機械照合し、不一致は0件だった。範囲の明記（計算24・遷移76）は定義の数と一致し、「五規則」は PathBases 2 と At 3 で正しい。「本章の位置付け」の除外の文は、処理系の対応の段落の直前にあり、中4を解消している。全状態の健全性を済んだと読める文はない。
4. **旧20欄:** 移行済み16（#2・3・6〜19）、必須で未着手4、不要0 を確かめた。使用先の PresFailure・PresMain・PresBase・Regularity・TySubstMain・Progress・StepSound も実際の呼出しと一致する。
5. **残りの見込み:** 但し書きは、配分の確度・機械的な外挿の禁止・待ちの除外を述べており足りている。.02 を含む比の算術も正しい。見直しの7件は plan の印の行と一致し、判断の別表も plan の記録と一致する。

### O160 の提示に足す材料

- 未移行の3欄を今足すかの問い（再中1）。
- 前提の不足は L00b の後半で7回出て、いずれも旧の前提の移行漏れか定義の不足だった。4欄を移せば、欄そのものの欠落による不足はなくなる。移した欄の意味の差や、旧にない新しい構成の不足からの反例は、これとは別に残りうる。
- 新の表の充足は T2 の小さな表まで確かめたが、三モデルでの充足は L50/L60 まで未証明である。

## 取りまとめの追記（再レビューの処置）

2026-11-01。`<tmp>/rv15/T2.lean` を `l00b.15/rv-15-t2.lean` へ写した。再中1は `plan.md` の先頭の判断のとおり、`release_exists`・`sat_unconstrained`・`admits_sat` をこの作業のうちに移す。`sig_scoped` は L20 に残す。再軽1〜3 は同じ再開で処置する。
