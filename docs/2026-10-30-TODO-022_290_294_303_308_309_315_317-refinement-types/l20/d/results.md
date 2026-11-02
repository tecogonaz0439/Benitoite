# L20 群 D の実装結果（r2 対応を含む）

2026-11-02。指定ブランチは `m014/l20.d`、B_WORK は **`6bef569230cf169bd1d8f6f7116a1a19dcdc4688`**。担当から git のコマンドを実行していない。基準は依頼の指定値であり、work の入口がその値で差分を分類した。

**14成分76 case を閉じた。証明の残りは0 case である。** 76個の case 補題を一つの構造的な相互帰納へ合成し、公開 S02 の全14命題を `type_subst_all` で結論した。十の移送は `toPublic` を通す。関数・メソッドの本体には公開入口、通常節・失敗節の本体には `S02Internal.substC` を適用する。ハンドラの節の型付けから通常節・失敗節の行先のコードまでを組み立てる定理も既定 import に含む。r2 の所見処置と検査は末尾に記す。定義・言明・仮定の独立レビューと設計者の受入れは取りまとめが行うものであり、本記録をそれらの完了とはしない。

## 橋の結論

`Ctx.NormEq Γ Δ` は `Γ.map (Option.map Ty.norm) = Δ.map (Option.map Ty.norm)` であり、長さと `none` の位置を保つ。`.var`・`C_Resume`・`V_Lam` の移送を Lean で閉じた。恒等の値の像の `SubstOk` と既存の値・計算の置換を使う。`V_Lam` の `hide`・`bindParams` に型付けの枝を追加していない。`HasTypeCQ.narrow` は橋に使わない。

`NormEq` だけでは、最上位が `.cont` である項を読む規則を任意の文脈間で移せない。`Ctx.NormEq.substOk` と `comp` は、元の文脈で最上位が `.cont` である位置に、移送先でも最上位が `.cont` である項があるという補助入力を持つ。`OpSig.context_continuations` が、実際の節の文脈についてこの対応を `sg.WF` から証明する。公開 S02 の入力や独立の信頼条件を増やしていない。

`ClauseSig.localRows` は、利用者定義の操作の既存の `SignatureScoped` と組込みの既存の `clause_prim_rowfree` から、局所署名の行支持を得る。`OpSig.substAt_local` が、外側の型・行の置換による局所署名の差を正規化へ帰着する。`OpSig.context_normEq` と継続の位置の対応、型置換後のコードへの恒等置換の不変性を合わせ、**`OpSig.typeSubst_body`（L20.54）を閉じた**。結果型や継続全体の WF は要求しない。[normeq-check.lean](normeq-check.lean) の `bridge_tvar0` は `NormEq.comp` の直接の例である。r2 の `clauses_tvar0` は同じ非正規の `ret` と結果型 `tvar 0` を使い、`HasTypeClausesQ.cons` と `S02Internal.substClauses` まで通る。

`Ty.Annotation`・`Pred.Sorted`・`Γ.facts` の移送と、`hideConts`・`bindParams` の NormEq の対応も証明した。一方、任意の NormEq についての `CaptureWF` の不変性は偽である。最上位が `.cont` である `cont Unit Unit ∅` と、それを `truth` で包んだ refinement は同じ正規形を持つが、後者は `NotContCore` を満たさない。`captureWF_not_invariant` でこの例を Lean で確認した。今回の移送は既存の置換の仕組みを使い、捕捉済みの `CaptureWF`・`CaptureOk`・`ClosureTy`・`DependentClosureTy` の文脈を外側の Γ に合わせて変更しない。定義や規則を改める必要はなかった。

最初の60分の確認は、三枝と `tvar 0` の成功、L20.54 の橋、`Clauses_cons` への接続まで進み、その時点の65/76 case と残りの見込みを本記録へ記した。その後、同じ60分内に76 case、公開接続と担当検査を終えた。四つの実呼出しの入口の適用範囲は r2 で修正した。

## 完了条件と数

| 起動単位 | 完了条件 | 結果 |
|---|---|---|
| D1・L20.39〜.45 | V29、Sub・Normal・Refine の包装 | 29/29 |
| D2・L20.46〜.51 | CQ24、Sub・Normal・Eff、依存する適用と external の具体化 | 24/24 |
| D3・L20.52〜.54 | 腕3・節2・失敗1、原文と正規形の文脈の橋 | 6/6 |
| D4・L20.55〜.60 | 残り17、単一の相互帰納、公開接続と4実呼出し | 17/17 |
| 担当の検査 | 既定 build、公理依存、写し、完全署名 | 成功 |
| 独立レビュー・受入れ | 定義・言明・仮定のレビューと所見処置、設計者の受入れ | 取りまとめへ引継ぎ |

| 成分 | 閉じた case | 残り |
|---|---:|---:|
| HasTypeVQ | 29 | 0 |
| HasTypeCQ | 24 | 0 |
| HasTypeVsQ | 2 | 0 |
| HasTypeEachQ | 2 | 0 |
| HasTypeTelArgsQ | 2 | 0 |
| TelBodyTy | 2 | 0 |
| CaptureOk | 1 | 0 |
| DependentClosureTy | 1 | 0 |
| CheckedWitness | 2 | 0 |
| AtCallAdmissible | 1 | 0 |
| HasTypeArmsQ | 3 | 0 |
| HasTypeClausesQ | 2 | 0 |
| HasFailureClause | 1 | 0 |
| ImageOk | 4 | 0 |
| **14成分の合計** | **76** | **0** |

`deriveV`〜`deriveImage` は一つの `mutual` に属し、各構成子で対応する独立の case 補題へ子の帰納の結果を渡す。Capture・Closure・Witness の三成分は恒等、Image は True である。Image.contLoc の格納 R を型置換した R へ変更する言明は作っていない。`C_DependentApp` は既存の `C_DependentAppNorm`、guard の原文の型への接続は既存の `C_Sub` と Annotation を使う。閉じない case を定理として置いたものはない。

## 四つの実呼出し

| 本体 | 本番の宣言 | 入力の供給と結論 |
|---|---|---|
| E_Fun | `type_subst_fun_body` | 型付き `.fnRef` を `fun_body_input` で逆転し、実際の defs の lookup に一致する SignatureInstance・Admissible から入力を構成し、Program.WellTyped の TelBodyTy に公開 `type_subst_body` を適用。QTel を元の Qsig と合わせ、行対応から Qempty を得る |
| E_Meth | `type_subst_method_body` | 型付きの実際の meth と辞書から method_body_input を得る。Program.WellTyped の method_body と Program.WellFormed の SourceScoped、辞書文脈の形成を合わせ、`ss ++ us` と行像で公開 `type_subst_body` を適用 |
| E_Op | `type_subst_op_body`・`type_subst_e_op_site` | 型付きの操作呼出しと、選択された ClauseSig の同じ lookup から op_body_input を構成。呼出し側の Φ0 と節側の Φ を分け、任意の捕捉 Γ に `S02Internal.substC` を適用。HasTypeClausesQ と findClause から選ばれた c の `c.body.substTy ts []` までを組み立てる |
| E_OpFail | `type_subst_opfail_body`・`type_subst_e_opfail_site` | 型付き raise から fail_input.toTypeSubstInput を得て、任意の Γ・Φ と捕捉元の Es に `S02Internal.substC` を適用。HasFailureClause の入力から `body.substTy [T] []` までを組み立てる。呼出し側の Φ0・E0 と節側の Φ・Es は別々に受ける |

未証明の S02 を引数にした実呼出しはない。内部入力は Γ に依存せず、残す C1 の下の形は S02 の一般の量化と型束縛の `under` で扱う。上表は本体の型置換の接続であり、捕捉・ストア・継続を合わせた Step の行先全体の StateTy の保存は後続の葉の担当である。`ValueMeaning`、型付け規則、公開 S02 の14定義、主な10言明を変更していない。

## 宣言と配置

r1 の明示した本番宣言は217件（定義17・定理200、うち非公開3）であった。r2 では定理5件を加え、合計222件である。[signatures.md](signatures.md) は定義の本体と case・帰納以外の完全署名を持ち、76 case と14成分は名前の一覧と本番ソースの SHA-256 で照合する。完全な222件の署名一覧は `<tmp>` に置き、大きさと SHA-256 を末尾に記す。生成された補助宣言はこの件数に含めない。

| モジュール | 明示した宣言 | 主な内容 |
|---|---:|---|
| TypeSubstTypingMotives | 10 | 十の移送の帰納の命題 |
| TypeSubstTyping | 90 | case 補題76と相互帰納14 |
| ContextNormEq | 24 | NormEq、恒等の像、注釈・sort・facts・束縛と三枝の移送 |
| TypeSubstCodeNormal | 12 | 型置換後のコードの恒等置換と計算の移送の包装 |
| TypeSubstLocalSignature | 21 | 局所署名の行支持、継続の対応、節の本体の橋 |
| TypeSubstAux | 12 | builder の局所参照、効果の union と handled、Boolean の注釈 |
| TypeSubstMain | 37 | 内部の六契約と toPublic、十の内部定理、公開14定理と全体 |
| TypeSubstCallSites | 12 | 空・辞書文脈の形成、関数・操作入力の逆転、四つの実呼出し、節の選択、冪等性と二つの site 定理 |
| TypeSubstFormation | 4 | Pred.Declared/Sorted、Ctx の sort、FactsWF の型置換（r0） |

全モジュールを既定 import に含めた。旧 Release、処理系、plan.md、l20/detail.md、レビューの記録を編集していない。01-12 と07-04の写しを同じ変更で更新した。

## 検査（r1）

| 検査 | コマンド（Lean は formal/ 内） | 終了 | 外側の時間と範囲 |
|---|---|---:|---|
| 選択の確認 | `scripts/check.sh --level work --base 6bef569230cf169bd1d8f6f7116a1a19dcdc4688 --dry-run` | 0 | 0.112秒、18変更ファイルから spec_tally/spec_examples/formal_build |
| 作業末の work | `scripts/check.sh --level work --base 6bef569230cf169bd1d8f6f7116a1a19dcdc4688` | 0 | **12.044秒**。集計の自己検査6件、仕様の集計、仕様例7件、既定の全 Lean build と sorry 拒否 |
| 公理依存 A-L | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/d/axioms.lean` | 0 | 1.616秒、9モジュールの475定数と旧主定理・既存移送18件、計493件 |
| 橋の例 | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/d/normeq-check.lean` | 0 | 0.343秒、tvar 0 の成功と CaptureWF の反例、公理依存 |
| 完全署名の照合 | Lean 環境から明示した宣言を一意に選び、型を印字 | 0 | 35.687秒、217件 |

work は r1 の作業末に一度、--only・--test を付けずに実行した。Rust の全 lib・clippy・fmt は追加していない。既定 build の単独の時間は work から分離していない。途中の既定 build は65 case の時点で2.653秒、終了0であった。最初の途中 build は内部の motive と case ファイルの不一致で終了1となり、両者を揃えた後に再確認した。最終の76 case と全読者は作業末の work が検査している。

A-L の493件は、444件が `propext`・`Classical.choice`・`Quot.sound` の部分集合に依存し、49件が公理に依存しない。**sorryAx・独自公理・許可外の依存は0件**である。既存の四移送と Model/ModelTargets/ModelHttp の仮定、旧 progress/preservation/step_sound/effect_soundness/noLamNames も検査した。ソースの sorry と axiom の検索は該当0件であった。

局所検査の初回の失敗は、恒等置換での部分適用した写像と正規化の等号、match の展開順序、相互帰納の構造的な下降の指定、完全署名の非公開宣言の選択にあった。最終のソース・橋の例・全署名の照合はすべて終了0である。失敗の出力も生の記録の束に含め、成功分だけを残す検査にはしていない。

## 大きさと elaboration（r1）

`lake env lean -M 12288 --profile Benitoite/Release/Refinement/<モジュール>.lean` の値である。外側は subprocess の開始から終了、elaboration と process pre-definitions は Lean の累積欄である。各欄は重なる処理を含み、加算して総時間としない。import の成果物がある状態の単独検査であり、clean build の値ではない。一部の独立したファイルの検査を同時に行った。Formation は既存の本体を含む全体の値である。

| ファイル | 行 | バイト | 外側 | elaboration | process pre-definitions |
|---|---:|---:|---:|---:|---:|
| TypeSubstTypingMotives.lean | 56 | 7,261 | 0.482秒 | 28.3ms | 2.73ms |
| ContextNormEq.lean | 212 | 10,484 | 0.742秒 | 49.5ms | 11.7ms |
| TypeSubstCodeNormal.lean | 138 | 6,612 | 0.639秒 | 18.4ms | 35.8ms |
| TypeSubstLocalSignature.lean | 260 | 12,736 | 0.537秒 | 57.4ms | 24.6ms |
| TypeSubstAux.lean | 128 | 5,960 | 0.584秒 | 18.7ms | 3.43ms |
| TypeSubstTyping.lean | 1,464 | 92,113 | 4.186秒 | 235ms | 2.47s |
| TypeSubstMain.lean | 169 | 8,798 | 0.520秒 | 81.4ms | 9.41ms |
| TypeSubstCallSites.lean | 151 | 9,168 | 1.438秒 | 32.1ms | 721ms |
| TypeSubstFormation.lean | 1,055 | 55,973 | 3.331秒 | 166ms | 216ms |

メモリはすべて `-M 12288`。上限到達やメモリ不足の終了はなかった。RSS は未取得（計画上の非採取）であり、12 GiB との実測比較はしていない。

## 計画との差と見込み

取りまとめが指定したとおり、narrow による橋を NormEq による橋へ変更した。NormEq だけの任意の文脈の移送を主張せず、継続の形の補助条件を実際の節の文脈から証明した。閉じた CaptureWF の判断を任意の NormEq で移す命題も置いていない。これらは内部の証明方法の変更であり、公開 S02 や信頼条件の変更ではない。行支持や kind の欠けによる条件追加は0件である。

case 補題と相互帰納は指定の TypeSubstTyping.lean に置いた。補助・公開接続・実呼出しを六つの新モジュールへ分けた。既定 import から外したものはない。単独の検査で仮の sorry を本番へ残していない。全比較と独立レビューは担当の検査範囲に含めず、実施済みとも記録しない。

r1 の観測区間は UTC 00:23:46 の再開から本記録の整理まで約55分であり、能動時間と待ち時間を分離した総時間ではない。r0 は指定文書の読込みを除く約25分の観測区間を記録していた。これらを完全な能動時間の合計や他群の短縮率へ換算しない。当初の14時間〜27時間10分に対応する実装と担当検査の残りは0である。

| 残る工程 | 担当・時期 | 見込み |
|---|---|---|
| 定義・言明・仮定の独立レビュー、所見の提示 | 取りまとめ、今回の結果の受領後 | 不明 |
| 所見への対応と必要な検査の再実行 | 指摘された実装担当、レビュー後 | 所見が未提示のため不明 |
| 群 D の受入れと取り込み | 設計者・取りまとめ、所見処置後 | 待ち時間は不明 |

## 生の記録（r1）

生の出力・台本は `<tmp>` に置き、改造には下表の大きさと SHA-256 だけを残す。単独 profile の出力と局所の失敗・再確認は束に含める。

| 記録 | バイト | SHA-256 |
|---|---:|---|
| `<tmp>/r1-work-dry.log` | 759 | `eea6cf673915ed5c3a2779b379ac7d351fcca27ff7bf3eece76591ef9f44c7b0` |
| `<tmp>/r1-work.log` | 5,718 | `562c6544c371d0a1ce1ddd755cd8980d3a982b439aea6382ed60e902c0253842` |
| `<tmp>/r1-build-checkpoint.log` | 44,249 | `95d34b8e08bd9ed2a75fa5519d6739eaedb46da4e1092516bce61c562514d27d` |
| `<tmp>/r1-build-checkpoint2.log` | 41,216 | `24614eb7af1f95222895224cf72e0834b084c2b0bf4c0c73f00851e61f246b16` |
| `<tmp>/r1-axioms.log` | 62,766 | `219b0a62c9d6e0bb63c3d74499e99cf411b9fc58d46615b2367765ac4410d241` |
| `<tmp>/r1-normeq-clean.log` | 269 | `6596aa4082f459b04726a9ddbbe9e804e6658f34685ba78def8b2271a805c19d` |
| `<tmp>/r1-inventory2.log` | 17,756 | `297b0b3f2067f288623bd916e0d3f89c6ebd1ecc57e26d69440f45dd12620149` |
| `<tmp>/r1-attempts.tar.gz` | 82,489 | `12f7585d619c8ce89d39bada64f16671cf709d2d026fd1b3d11778ce55549a86` |

## 入力と成果物の SHA-256（r1）

次表は r1 の検査時点の記録であり、r2 で変えたファイルの最終値は末尾に記す。パスはリポジトリの根からであり、l20/d は本改造内を指す。公開契約・規則・Narrowing の四ファイルは r0 の記録と同じハッシュである。対象 HEAD は git で再照合していないため、上記の指定 B_WORK、work の分類、以下の実ファイルのハッシュを証拠とする。

| ファイル | バイト | SHA-256 |
|---|---:|---|
| `formal/Benitoite.lean` | 15,173 | `16ff89b22028d12c1164773127b20f1f595ebbdfe9260355c711e7de0b5236bc` |
| `formal/lakefile.toml` | 872 | `10f2661bff8fce95a9253d976427d0ca44038ec12350c955badbc1cf1efa6e3a` |
| `formal/lean-toolchain` | 25 | `d5edba4e4b8faad9c1baeadb265716d20d03be4d1a2647dc5e35b0c0325bea7b` |
| `formal/Benitoite/Release/Refinement/TypeSubstTypingMotives.lean` | 7,261 | `e2bd6e89e44feab4c88299076b19d708ac102da95f50167df14028ff6eb71d6a` |
| `formal/Benitoite/Release/Refinement/ContextNormEq.lean` | 10,484 | `15d5867730db531f1bb7d2e27df4e010be12ee093b4604fa72d96621baaf6c77` |
| `formal/Benitoite/Release/Refinement/TypeSubstCodeNormal.lean` | 6,612 | `ba320fc0c7d0de48e1a0db9a76f2bae56a0ea554209685571bdf5ef8b6ac2251` |
| `formal/Benitoite/Release/Refinement/TypeSubstLocalSignature.lean` | 12,736 | `ef6fc7092aaa56f6b6148cb4bbba85b78f795a33313fe0e291285912c4bd01a8` |
| `formal/Benitoite/Release/Refinement/TypeSubstAux.lean` | 5,960 | `68e31dcf2452da67411dd71687bec8360f28d624228a6f5e2afc546a9628533f` |
| `formal/Benitoite/Release/Refinement/TypeSubstTyping.lean` | 92,113 | `7f0a1d4502b0840d00ce82f7dc9e0c171904bfc0caf0cf7043bd9fe082d838d9` |
| `formal/Benitoite/Release/Refinement/TypeSubstMain.lean` | 8,798 | `d2bdf2a772b2fb6f7485e2f062ca405cfa998db533a9eaafeae4e6593810f1fd` |
| `formal/Benitoite/Release/Refinement/TypeSubstCallSites.lean` | 9,168 | `42df9a1420e87820ae9b8dcb4b16d43c5ae3cda85dce4b0ea3b733607456624c` |
| `formal/Benitoite/Release/Refinement/TypeSubstFormation.lean` | 55,973 | `8ef636dd94f2e68359176d27b15874d04a9b898e1c87d8ca8be977b4abd8c5fe` |
| `formal/Benitoite/Release/Refinement/TypeSubstContracts.lean` | 13,479 | `74372dff22c92a14c6f51926dc73973e834832fbae26ff63533ed5a40fb27ebf` |
| `formal/Benitoite/Release/Refinement/Typing.lean` | 33,994 | `e101e41f167f463925e3fdbc725b41c7ef08ba34e30a730e85ba4c937db5835c` |
| `formal/Benitoite/Release/Refinement/HandlerContracts.lean` | 3,589 | `2c9e705e2aeeaa60e363a8009941e632d84740f887c6244f36791900cf63e514` |
| `formal/Benitoite/Release/Refinement/Narrowing.lean` | 45,976 | `ff452c989473b39829231abf00dec8ba728ffe49155c6b2c97bc29801fe1792e` |
| `docs/design/01-spec/01-12-core-calculus.md` | 726,584 | `27717d48ce7d2be0b014cab01a5f62a20dd384693980d5687ecb3bc0e6b8b3be` |
| `docs/design/07-quality/07-04-formal-semantics.md` | 471,343 | `2eedeb2cd136be291f13cf5ea29567b88e6e68229068b135573a01cbdb1c05bd` |
| `l20/d/signatures.md` | 172,385 | `3a267dea056d749ff6819ee49e65b06f1dbd51c4566f1ff2f7cde81c57c30c56` |
| `l20/d/axioms.lean` | 2,122 | `7c69a0a025921a25f14395492c455b1b224ea3cf14863df90b0cc77ceaf0cf0c` |
| `l20/d/normeq-check.lean` | 3,245 | `2968acf17dc4d0fba889863d73ab4857ce8761e9c29406953317f3df01646753` |
| `l20/d/clause-bridge.lean` | 4,480 | `e35ad20592ff069e893a10cd73698ebaa143ebeff39234c7b9e11855a5e36fcc` |

## r2: RV-L20.d の所見処置

2026-11-02。レビューの付録の Lean を本番に取り込み、**中2件・軽8件をすべて処置した**。レビューの記録・計画・l20/detail は編集していない。D1〜D4 の完了条件を再照合し、14成分76 case、単一の相互帰納、`toPublic`、四つの実呼出しの本体への接続を満たす。証明の残りは0 case である。群の受入れは取りまとめの判断を待つ。

| 所見 | 処置と証拠 |
|---|---|
| 中1 | `type_subst_opfail_body` を付録の一般形へ置換した。Γ・節側の Φ・捕捉元の Es は任意とし、呼出し側の Φ0・E0 から分けた。`fail_input.toTypeSubstInput` と `S02Internal.substC` で閉じる。`type_subst_e_opfail_site` は K_Handle_Fail の HasFailureClause と選択された節から `body.substTy [T] []` の型付けを組み立てる |
| 中2 | `type_subst_op_body` は呼出し側の Φ0 と節側の Φ を別々に受け、`hc : CaptureContextRegular …` を除いた。選択された ClauseSig の宣言と op_body_input を合わせ、`S02Internal.substC` を使う。`HasTypeClausesQ.findClause_body` と `hideBuilders_idem` により、`type_subst_e_op_site` は K_Handle の HasTypeClausesQ と findClause から行先の `c.body.substTy ts []` の型付けまでを組み立てる |
| 軽1 | 01-12・07-04 と本記録冒頭・四つの実呼出しの表を、公開入口を使う関数・メソッドと内部入口を使う通常節・失敗節の実装に合わせた |
| 軽2 | 07-04 に内部十契約の配置を明記した。TypeSubstContracts に四つ、TypeSubstMain に六つがある |
| 軽3 | normeq-check.lean に `clauses_tvar0` を追加した。非正規の dependentFn の ret、結果型 tvar 0 を持つ具体例を HasTypeClausesQ.cons に入れ、S02Internal.substClauses まで通した。`bridge_tvar0` 自体は NormEq.comp の直接の例と明記した |
| 軽4 | signatures.md を100 KB以下へ縮めた。定義17件の本体、case・相互帰納以外132件の完全署名、76 case と14成分の名前を残す。全222件の完全署名は `<tmp>/signatures-full.md` に置き、ソースとともに下表の SHA-256 で照合する |
| 軽5 | 01-12・07-04・本記録の該当箇所を「最上位が `.cont` である位置」又はその項という記述へ改めた |
| 軽6 | 形成の補題の説明を、元の述語と同じ内部入力 TypeSubstInput を使うという現在の決定へ改めた |
| 軽7 | `HasTypeVQ.fun_body_input` を追加し、V_Sub・V_Normal・V_Refine を通した fnRef の逆転を `type_subst_fun_body` で使う。入口は型付きの実際の呼出しと defs の lookup を受ける |
| 軽8 | E_OpPrim の入力の違いを L20.103 へ申し送る。次段落を参照 |

**L20.103 への申し送り（E_OpPrim）**: E_OpPrim は今回の四つの実呼出しに含めない。行先のコードは E_Op と同じ `c.body.substTy ts []` であるが、組込み署名の型文脈は `s.tparams` であり、利用者操作の `TypeCtx.values` を使う入力の構成をそのまま写せない。組込みの型付き呼出しから同じ内部入力を構成し、呼出し側の Φ0 と節側の Φ を別々に受ける形で接続すること。今回の通常節と同様、`hc : CaptureContextRegular …` の供給を前提にせず、`S02Internal.substC` を使う。E_OpPrim の接続と状態全体の保存は後続の担当である。

計画 L20.60 の「公開入口を使用」からのずれは、通常節・失敗節の二つの本体入口に `S02Internal.substC` を直接使う点である。取りまとめの r2 の指定に従った。内部の形は公開の形より強く、任意の Γ に対し TypeSubstInput だけを読む。公開の toPublic は ClosedTypeSubstInput.context の CaptureContextRegular を読まないため、通常節の hc は不要な仮定であった。公開 S02、type_subst_all、主な10言明、ValueMeaning、型付け規則はそのままである。行支持・kind の欠け、新しい公理又は独立の信頼条件は見つかっていない。

本番の追加宣言は `hideBuilders_idem`・`HasTypeVQ.fun_body_input`・`HasTypeClausesQ.findClause_body`・`type_subst_e_op_site`・`type_subst_e_opfail_site` の5件である。既存の関数・通常節・失敗節の本体入口3件を改めた。本番の明示した宣言は合計222件（定義17・定理205、非公開3）となった。文書の検査用の追加宣言 `clauses_tvar0` はこの件数に含めない。署名は実装前に記し、Lean の環境から印字した最終の全222件と照合した。

### r2 の検査と測定

コマンドの水準は r1 と同じであり、work の `--base` は指定の B_WORK、`--only` は使っていない。Lean の単独検査はすべて `-M 12288` を付けた。

| 検査 | 終了 | 外側の時間・範囲 |
|---|---:|---|
| work の選択の確認（--dry-run） | 0 | 0.113秒、19変更ファイルから仕様の集計・仕様例・既定の Lean build を選択 |
| 既定の `scripts/check.sh --level work --base 6bef569230cf169bd1d8f6f7116a1a19dcdc4688` | 0 | 5.713秒、集計の自己検査6件と仕様の集計、仕様例7件、既定の `lake build` と sorry 拒否 |
| 全9モジュールと既存主定理の公理依存 | 0 | 1.474秒、492定数と既存18件の計510件 |
| normeq-check.lean | 0 | 0.337秒、NormEq.comp・HasTypeClausesQ.cons・S02Internal.substClauses、CaptureWF の反例と公理依存 |
| 既存の clause-bridge.lean | 0 | 0.372秒、節の橋の入力の検査 |
| Lean 環境からの完全署名の照合 | 0 | 25.519秒、本番222件を一意に選択して型を印字 |

公理依存510件のうち458件は `propext`・`Classical.choice`・`Quot.sound` の部分集合、52件は公理依存なしである。**sorryAx・独自公理・許可外の依存は0件**。新しい二つの site 定理と関数の逆転を含めて確認した。normeq-check の三例も標準三公理だけに依存する。公開契約・Typing・TypeSubstMain のハッシュは r1 と一致し、76 case・76個の異なる適用・一つの mutual を再照合した。ソースの禁止された宣言も0件である。

| r2 で変えた Lean ファイル | 行 | バイト | 外側 | elaboration | process pre-definitions |
|---|---:|---:|---:|---:|---:|
| TypeSubstCallSites.lean | 224 | 12,972 | 1.294秒 | 62.2ms | 1.33秒 |

測定は import の成果物がある状態の単独 `--profile` であり、clean build の値ではない。各欄の時間は加算しない。単独検査のメモリ上限は12 GiBであり、分割を要する状況はなかった。r2 の観測区間は UTC 01:28:06 の記録から本記録の整理まで約8分である。当初の14時間〜27時間10分に対応する実装と担当検査の残りは0、r2 の所見処置の残りも0である。

| 残る工程 | 担当・時期 | 見込み |
|---|---|---|
| r2 の所見処置の再確認、群 D の受入れ | 設計者・取りまとめ、今回の結果の受領後 | 不明 |
| 全状態の保存と E_OpPrim の接続 | 後続の葉・L20.103 | 本群では不明 |

### r2 の成果物と生の記録

生の出力と全署名は `<tmp>` に置く。改造には要約と下表の大きさ・SHA-256 だけを残す。手元の絶対パスは記さない。r1 の表は当時の記録として残し、次表を r2 の最終値とする。

| 成果物 | バイト | SHA-256 |
|---|---:|---|
| `formal/Benitoite/Release/Refinement/TypeSubstCallSites.lean` | 12,972 | `487bb2c1f98af9d9f2e98f9d88628f6f6515dbff98bb86fba4a25191654b2094` |
| `formal/Benitoite/Release/Refinement/TypeSubstTyping.lean` | 92,113 | `7f0a1d4502b0840d00ce82f7dc9e0c171904bfc0caf0cf7043bd9fe082d838d9` |
| `docs/design/01-spec/01-12-core-calculus.md` | 727,106 | `93296bc2618a88df3dd76f6fb2844fdabbdce5dae89eab6aec962c24865a3a77` |
| `docs/design/07-quality/07-04-formal-semantics.md` | 471,754 | `46a7fff3966c2e21f9875734f52610ae1a99f78a2d74777106eda35d2ae9b575` |
| `l20/d/signatures.md` | 81,413 | `dd790bdf409b1faee501a0ba84189905da75a81aa97c928175c7fe0e68256e6f` |
| `l20/d/normeq-check.lean` | 4,859 | `7a55bd2ecda29a6fb823dfeb5b30f28c4770ce07f534babc08d5cd1a39e79601` |
| `<tmp>/signatures-full.md` | 179,677 | `a6a66c7f85abfdabd24e2e9517869e62581718395abfc57a2b594c6eb4999ef9` |
| `<tmp>/signatures-r1-full.md` | 172,385 | `3a267dea056d749ff6819ee49e65b06f1dbd51c4566f1ff2f7cde81c57c30c56` |
| `<tmp>/work-dry.log` | 759 | `81adc6624cce04d026b44be8386d6cc10fd4f422d888daae908457b5cc445795` |
| `<tmp>/work.log` | 5,718 | `4f46b9adb1315788641d695e4f147471b3d75bb28ee8a846b0178c59e51c842d` |
| `<tmp>/axioms.log` | 64,894 | `fdfb7fbee9f752c714ae8ebfeab8fba44a321f97d63e3d38cab5943df84bf6b9` |
| `<tmp>/normeq.log` | 399 | `8cacfec6e29e88cab5d9c82340828df0cf2a6161aff3e25515a47b72d9843407` |
| `<tmp>/profile.log` | 783 | `7b3e2afae6773b1ef9167b874bed62d3fd862fae5edebdf517eeda3df6b49436` |
| `<tmp>/inventory.log` | 18,177 | `f6fd20576389a6285e3fcbb7cfd783b65388305f60f2928c05ed45dc63bdb69d` |
| `<tmp>/structural-check.log` | 207 | `a7307a202b199278cc900e39f8b3ea31e6477f63cc161886aab801f57a19f455` |
| `<tmp>/records.tar.gz` | 59,664 | `87dffcc00601778f9c8b913e05d0f54989d3152cb5835edb0239af5608a2cc39` |

## 作業末の work

`scripts/check.sh --level work --base 6bef569230cf169bd1d8f6f7116a1a19dcdc4688` を、Refinement の生成物を消した状態で実行した。終了0、外側110.55秒、最大常駐量1377959936バイト。
