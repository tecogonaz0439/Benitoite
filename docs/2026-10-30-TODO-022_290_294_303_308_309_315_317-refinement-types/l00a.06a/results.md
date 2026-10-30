# L00a.06a: LeQ と並置判断の契約の結果

2026-10-30。実装担当 Codex が [contracts.md](contracts.md) を作成し、[RV-L00a.06a](../reviews/RV-L00a.06a.md) の重1・重2、中1〜5、軽1〜6の全13所見に従って修正した。Lean の実装・証明は行っていない。修正版の再レビューと、その後の L00a.06b の起動を取りまとめへ渡す。

## 基準と成果

| 項目 | 内容 |
|---|---|
| 指定ブランチ | `m014/l00a.06a`。切り替え・作成・コミットなし |
| B_WORK | `9310eff4e2281a6ef344c4d745f39df7a4abb2c6`。起動依頼の指定値。担当による git コマンドでの HEAD/ブランチの再取得はしていない |
| 読み取りの開始記録 | 2026-10-30 19:57:34（+0900）。共通依頼文等の最初の読取り直後の時計 |
| 作業の定義 | [共通依頼文](../implementation-request.md)、[plan.md](../plan.md) の L00a.06a と「L00a.06a の LeQ 二案と並置する判断」 |
| 判断 | [README](../README.md#設計者の決定)、[decisions.md](../decisions.md) の D17〜D20・D29 と U01/U08/U09 の回答を継承 |
| 開始状態の引継ぎ | [L00a.01a](../l00a.01a/results.md)・[L00a.01b](../l00a.01b/results.md)。過去のビルド成功を今回の文書の検査へ数え直していない |
| 変更ファイル | `l00a.06a/contracts.md` と本書だけ |
| 実装・設計への変更 | なし。処理系・形式化・現行設計書・docs/todo・計画・判断の記録を編集していない |
| 最大常駐量 | 未取得（計画上の非採取）。Lean ビルドや計測用の追加実行はしていない |

推す案は、**新 LeQ に必要な規則を置き、旧導出を補題で埋め込む案 A** である。旧判断を持ち上げる lift 構成子は採らない。型/行の置換像が篩を含み、外側の値に依存する場合を許すと、旧 `Ty.Le.substAt` の引数の型ではその像を表せない。lift の枝に必要な二つの言明と、旧構文の像へ戻らない型の例を契約に記した。言明を証明したとはしていない。

本番の旧 `Ty.Le` は inductive ではなく、等号と最外の関数の効果の拡大という二枝の定義だった。この二枝の全場合と旧 Ty の15構成子、`substAt/subst/shift`・`fn_left/fn_right`・`eq_of_not_fn` 系・V_Sub/C_Sub・K_Sub・主な逆転の利用先を表にした。計画の「旧導出の帰納法」は、旧二枝の消去と、新 LeQ 自身の導出の帰納法に分けて具体化した。推す案や変数表現を変更したものではない。

対照表では `Benitoite.Release.Refinement` を新判断の名前空間として固定した。LeQ/TelLe/TelClosure/Covers、値/値列/各要素/計算/腕/通常節/Fail節、空Qの入口、CellOk/StoreOk、Lazy に関係する構成子、ContTy/StateTyE/StateTy、宣言/Program.WellTyped、Step/Steps/step を記し、L00a の定義/代表の補題、L00b/L10 の全構成子、L20〜L70 の全証明と切替を分けた。旧体系に独立した `Lazy` という判断はなく、型・場所型・値/計算の規則・thunk/done セルを対応させた。

最小の `refined`、整数項/比較/論理結合、Nat の self/外側値、WF/sort、有限な Γ/facts/Φ、LeQ/Entails の規則と署名、V_Sub/C_Sub の接点を記した。Γ の外側参照の順序と None、型像の篩による事実増加を含意と cut で扱う条件も固定した。D19 の閉じた評価器と `Entails.ground` は計画どおり L00b.04 とし、追加後の補題の場合も更新する。D20 の groundVal/reqTarget/valContent は後段の値の葉と適格な旧導出の埋め込みに引き継ぐ。

レビュー後は、.06b の Val/Comp/Arm/Clause の全構成子と、L00a の V/Vs/Each/C の型付けの構成子を表に固定した。Const は共有し、新 Const.type は旧 type と embedTy の合成にする。Program/Builtins と型を含む宣言は新しく作る。腕・節の判断は予約とし、全構成子を定義する L00b.02b と全相互置換を証明する L20 の義務を明記した。

正規化は .06b から旧定義を拡張し、norm/Canonical/memFail と埋め込みとの交換を証明する契約に直した。篩の平坦化と true 消去は L00b.11 に残した。SubstEnv の rows/ranges は有限列とし、プログラムの値の像 Nat→Val と、論理項の像 Nat→Term を分けた。V_Refine に整数 carrier を要求し、型付きの像から整数観測と事実を導く。適格条件の表も三分類へ直し、承認済みの変更以外を新しい旧入力の除外条件にしない。

## 初版の自己点検と共通検査

文書だけを変更する W-D として、指定された B_WORK に対する work の選択を確認する。Rust の lib/clippy/fmt や Lean の既定ビルド、公理依存 A-L、全比較、性能測定を追加しない。L00a.01 の数値を今回の別実行の実績へ流用しない。

契約案を一つ作成した時点の最初の dry-run は、次のコマンドで終了0だった。出力は `1 changed file(s)`、`nothing to check: only documents changed` であった。これは最終の二文書を対象とした結果とは区別する。

```sh
rtk proxy scripts/check.sh --level work --base 9310eff4e2281a6ef344c4d745f39df7a4abb2c6 --dry-run
```

最終の二文書に対する dry-run と作業末の work は、次の同じ指定で行う。検査入口による比較の読み取りを除き、担当が git を直接操作するコマンドは実行していない。ブランチ・index・コミットを変更する操作はない。

```sh
rtk proxy scripts/check.sh --level work --base 9310eff4e2281a6ef344c4d745f39df7a4abb2c6 --dry-run
rtk proxy scripts/check.sh --level work --base 9310eff4e2281a6ef344c4d745f39df7a4abb2c6
```

二コマンドは `rtk proxy python3 -` から `subprocess.run` で上記の引数を順に実行し、monotonic clock で各呼出しの外側の時間を採取した。

| 実行 | 終了 | 外側の時間 | 選択と結果 |
|---|---:|---:|---|
| 最終 dry-run | 0 | 0.111020秒 | `2 changed file(s)`、`nothing to check: only documents changed` |
| 作業末の work（一度） | 0 | 0.095593秒 | 同じ二文書、`nothing to check: only documents changed`、`selected checks passed` |
| 文書の初回の自己点検（`rtk proxy python3 -`） | 0 | 0.166449秒 | 二文書のコード柵・表の列数・相対リンク、旧 Ty の15構成子の表との対応、保護対象の内容を確認 |

work の成功は、文書のみとして検査を追加しない選択が成功した意味である。Lean の定義/証明が通った、Rust のテストが成功した、検査対象が1件以上あった、という結果には読み替えない。

保護対象は `formal/Benitoite/`、`crates/benitoite/`、`docs/design/`、`scripts/` の通常ファイル4,641件（target と __pycache__ を除く）とした。書き込み前と自己点検時に各内容の SHA-256 を計算し、相対パス順の辞書を Python の `json.dumps(records, sort_keys=True)` で直列化したものの SHA-256 は、双方とも次だった。追加・欠落・内容変更は0件である。

```text
f32e358d1aaabcb3f189d805f4eb077921af3f582194a176d3d4eb50eeba8fd3
```

開始状態との接続も別に照合した。[L00a.01b の一覧](../l00a.01b/inventory.json.gz)に保存された `formal/` 401入力と `scripts/check.sh` の計402入力の SHA-256 は、今回の現物と全件一致した。一覧の B_WORK は `9506fb623d9b26750177521933b50a9f67dd0346` であり、今回指定された B_WORK と同一 ID としては扱わない。比較したのは保存された関係入力の内容である。圧縮一覧自体の SHA-256 は `9957e5fae2d1596c5c783c670c1c40f3c00228396831ef32f20e36ef0892706b` だった。今回 `.olean` の時刻や実行ファイルを再採取した検査とはしていない。

最終の文書の点検結果と時計は末尾に記す。初回の表15個・相対リンク27個という件数は、その後の本書の結果追記より前のものだった。自己点検を取りまとめの独立レビューとして扱わない。途中の検査失敗とそのための修正はない。読取りコマンドでは、存在しない仮のファイル名 `Subtyping.lean` と `State.lean` を含む最初の検索が終了2となり、実際の定義がある Typing/Semantics を読み直した。関係の定義を見落としたまま契約を固定していない。

## 義務行と残る段

| 作業・義務 | 今回の判定と証拠 | 残る担当・段 |
|---|---|---|
| L00a.06a | 全13所見の修正と自己点検を完了。証拠は contracts.md と本書の対応表。修正版の再レビュー前 | 取りまとめの再レビュー後に .06b |
| O040（変数と葉の表現を分ける） | L00a.06a の分: 閉鎖。RV の判定を継承し、Nat/WF と有限な論理の葉を別々に固定。二方式の時間の優劣は主張しない | .08 の本番の補題、.16b の見込み更新。O040 全体は未閉鎖 |
| O042（並置） | L00a.06a の契約の分: 重1/重2修正により閉鎖。作る構文/判断/作業、正規化と埋め込みの交換を固定。修正版の再レビューは未実施 | .06b の新判断/import/補題、L10/L20。O042 全体は未閉鎖 |
| O159（完全名と切替） | L00a.06a の対照表の分: 中3修正により閉鎖。補助判断・正規化・Const.type を加え、各行の作成/予約/担当を明記。予約名を実装済みと数えない | L00a.06b と L00b/L10 の全構成子、L70 の主定理/全交換/旧判断の処置。O159 の段全体は未閉鎖 |
| O002/O031（置換）、O029（Γ）、O004（Nat/WFの保存） | 今回は言明と段の配分まで。証明義務を閉じていない | L00a.08〜.12b、L00b、L20 |
| O003（棚卸し）、O010（中心の補題の実績と外挿） | 未実施。今回の使用箇所の表や所要を、棚卸し全件や証明作業の実績へ算入しない | .07a〜.07b、.16a〜.16b |

判定日はいずれも2026-10-30、修正後の上表の確認者は実装担当 Codex である。初版の独立レビューの判定は RV-L00a.06a に保存済みであり、修正版の再レビューの判定は取りまとめが別に記録する。

## 未決、計画との差、申し送り

設計者へ新しい選択を求める停止条件は発見していない。A、Nat/WF、有限な論理の文脈、D19/D20 の採択を変えていない。本書を Lean の型検査済みの契約とみなさず、取りまとめが公開署名と構成子を独立レビューしてから .06b へ渡す。

未決は、Release/Refinement/*.lean 内の細分、L00b の Tel と fn の接続・状態の閉じた環境・σ/外部表の完全署名、全sortと篩の正規化の一般化である。旧の子/Fail の正規化と埋め込みの交換は .06b の確定した義務へ移し、未決として後へ送らない。L00b の詳細化とレビューを経るという既存の起動条件を保つ。

.06b には、旧 Le の二枝の構造的な埋め込み、篩を再帰的に含められる新しい型/行、開いたΓ/Φ、既定importに新モジュールを加え旧ビルドを保つことを引き継ぐ。型/行の像を旧構文へ制限せず、最外の篩のアダプタや旧Leの lift で代用しない。L00a の証明の新しい場合は L00b.02a〜.02b/L10 の各行の内数で追加し、ground の場合は L00b.04 に含める。

修正後の .06b は、構成子表の宣言と規則、比較順/正規化/memFail/Canonical/WF の埋め込みとの交換、`Ty.LeQ.assume` と必要な cut も実装・証明する。値の像の観測・facts の導出と Γ の narrowing は .12a〜.12b の担当である。旧 Release のモジュールから Refinement へ逆向きの import を追加しない。

計画との差は、旧 Le に帰納的構成子がないことを本番の二枝に即して説明した点と、文書だけの作業として W-D の選択を用いる点である。Lean を変更していないため、全 L 作業の W-L にある formal_build を今回の文書作業へ強制的に追加していない。作業の範囲・主定理の前提/結論・提供範囲の縮小はない。

## 初版の最終の自己点検と所要の記録

初版の最終の `rtk proxy python3 -` は2026-10-30 20:13:43（+0900）に終了0だった。呼出し内の単調時計による外側の時間は0.169605秒。二文書の16表・28相対リンク・コード柵と旧 Ty の15構成子の対応、保護対象4,641件の作業前後の一致、L00a.01b に保存された402入力と現物の一致を再確認した。初版の契約文書の SHA-256 は `8b3f2abd71f68e429922e99f8b71e043f87db1580ee92568a9288529e08c53d2` である。レビュー後の修正は次節以降に別に記録する。

通常の時計の記録で確認できる区間は19:57:34〜20:13:43の **16分9秒** である。最初の依頼文の読取りの一部と、本節の追記・最終報告を除く外側の時間であり、能動時間の実測値とはしない。ビルド待ち・独立レビュー待ちは発生していないが、読取り/文書作成とツールの待ちを全区間について分離した記録はない。中心の補題の証明の時間や、後段の骨格/追随の時間の比へ算入しない。

## RV-L00a.06a への対応

対象は初版に対する全13所見である。各所見の引用元を開いて確認し、contracts.md の以下の節を修正した。完了は文書の修正の判定であり、新しい Lean 定義/補題の実装済み又は再レビュー済みという意味ではない。

| 所見 | 確認した根拠 | 直した場所と内容 |
|---|---|---|
| 重1 | Syntax.lean の Const/Val/Comp/Arm/Clause/宣言/Program、Typing.lean の PrimSig/Builtins/各判断 | 「L00a で作る項の構文・判断と作業の境界」。構文の全構成子、型付けの作る一群と残る全場合、.06b と .12a/.12b の役割を表に固定。Const共有/新type、Program/Builtins新設と全欄を指定 |
| 重2 | Normalize.lean の norm/Canonical/memFail、Typing.lean の fn/cont の WF、TypeSubst.lean の正規化を含む bind、Order/Types.lean の比較 | 「L00a の正規化と埋め込みの交換」。旧正規化の構造的な拡張、refinedのcarrierだけの正規化、memFail の正規形の一致、比較順/正規化/Canonical/WF の交換を .06b の義務に追加。平坦化/true消去は L00b.11 |
| 中1 | TypeSubst.lean:36–58、RangeInstDef.lean、Scope/Signature.lean の Ix.inst | 「LeQ と含意の署名・全規則」の SubstEnv。rows は有限の List Eff、ranges は有限の List Range とし、範囲外は恒等。Fail の走査と具体化に既存表現を使う理由を記載 |
| 中2 | Val.toTerm? と V_Refine の初版の契約、Syntax.lean の値構文、SubstTyping.lean の実際の Nat→Val の像 | 「V_Refine とプログラムの値の像」。整数 carrier を要求する一案を推す。論理の Term と実際の Val の像を分け、型付き整数の観測成功と参照されない位置の既定項の無関係性を .12a の補題にする。外側だけの条件は LeQ.introduce/V_Sub で保つ |
| 中3 | Typing.lean の PatTy/PatTys/Inhabits/適格性/LocalRef.HasKind、SubstTyping.lean の SubstOk、Semantics.lean の BuiltinOnly、Effect/Normalize の各定義 | 「並置する判断の完全名と段ごとの責務」。補助宣言の対照表を追加し、元の全行にも L00a で作る/予約と担当を表示。Ty.WF/Eff.WF/Sub/memFail/正規化/Const.type/Program/Builtinsを含めた |
| 中4 | plan「全 L 作業の停止条件」、decisions D20〜D29、README の骨格二点 | 「旧導出の埋め込みの前提と限界」。全行を承認済みの変更/旧導出から導く性質/写しの義務に三分類。後の二つを旧入力の追加除外にしないと明記 |
| 中5 | RV-P4 M1、P4 Context.lean の predicate/context_map_of_typed、Derivations.lean の assume/bind_context | 「部分型による事実の移しと Γ の narrowing」。Ty.LeQ.assume は .06b、文脈と V 側の narrowing は .12a、CQ側と相互入口は .12b、全一般化は L00b/L20に配分 |
| 軽1 | rg の行番号付き出力で Typing.lean:621、SubstTyping.lean:224,252 を確認 | 「主な補題と型付けの使用箇所」の三つの行番号を訂正 |
| 軽2 | 旧 Ty.Le の二枝と B の refl/lift の再構成に必要な言明 | 「LeQ 二案と置換に必要な言明」。等号の例は B でも refl で導けることを明記。lift の再適用が閉じず、旧二枝の分解と追加の逆転の場合が必要になる比較へ修正 |
| 軽3 | TypeRegularity.lean の wf/wf_rev、Preservation.lean の fn_fn'、CoverCompat.lean の LeOld/限定同値、EffectCover.lean の substRho | 「主な補題と型付けの使用箇所」に四群を追加し、それぞれの移植先と限定を記載 |
| 軽4 | Normalize.lean/TypeSubst.lean、P4 Logic.lean の instantiate/upSub、初版の WF 署名 | 「有限構文、self、WF」「L00a の正規化と埋め込みの交換」。open は外側を一つ下げると明記。Eff.WF に nv、refinedに Pred.WF(nv+1)、Ty/Eff.bindに normを指定 |
| 軽5 | plan L00b.02c と L70 の切替、旧 Types/Typing/Interval の依存の境界 | 「下流の逆転と切替の条件」。Release/Refinement/*.lean の配置案と依存順を記載し、L70まで旧 Release から新判断への import と旧 Types/Typing への Interval.Domain の追加を禁止 |
| 軽6 | LeQ の trans と P3b/P4 の listCore/fnCore を介する逆転 | 同節に、篩を除いた最外の形の保存を L00b.11/L40 の逆転に先行する義務として追加。refl と重複する reference/set 構成子は置かない |

案A、Nat/WF、D19/D20、提供範囲と主な定理の前提/結論は変更していない。今回の再レビュー待ちを除き、設計者の新しい判断が要る停止条件は発見していない。以下に修正版の検査と時間を記録する。

## レビュー修正後の検査と所要

レビューを読んだ最初の時計は2026-10-30 20:25:25（+0900）である。指定 B_WORK は初版と同じ `9310eff4e2281a6ef344c4d745f39df7a4abb2c6` のままとした。処理系・形式化・設計書・計画・判断・レビューの原文を変更せず、contracts.md と本書を修正した。git の直接操作とブランチ/index/コミットの変更はしていない。

自己点検では、相対リンクと表の列数に加え、Syntax.lean の Val 17構成子・Comp 13構成子・Clause 2構成子・Arm 1構成子を契約の構文表に照合した。旧 HasTypeVQ の19構成子と旧 HasTypeCQ の17構成子は、L00a で作る場合と L00b/L10 で揃える場合に全て分類されている。L00a の追加の V_Refine も別に明記した。元の完全名対照表30行の全行に作成/予約の表示があり、レビューが列挙した補助宣言も追加表にあること、13所見に対する対応行が各一行あることを確認した。

| 本修正での実行 | 終了 | 外側の時間 | 対象と結果 |
|---|---:|---:|---|
| 文書/構成子表/所見/内容の自己点検（`rtk proxy python3 -`） | 0 | 0.168008秒 | 2026-10-30 20:46:10（+0900）。二文書の23表・30相対リンク・コード柵、全13所見、上記の構成子と対照表を確認。この検査結果を追記する前の件数 |
| 修正後 dry-run | 0 | 0.104222秒 | `scripts/check.sh --level work --base 9310eff4e2281a6ef344c4d745f39df7a4abb2c6 --dry-run`。基準との差分表示は3文書、`nothing to check: only documents changed` |
| 本修正の作業末の work（一度） | 0 | 0.094595秒 | 同じ指定から --dry-run を除いた実行。同じ文書のみの選択で `selected checks passed` |
| 結果追記と中4の補足後の最終の文書点検（`rtk proxy python3 -`） | 0 | 0.001085秒 | 2026-10-30 20:49:08（+0900）。二文書の24表・30相対リンク・コード柵を確認 |

dry-run と work は、初版と同じく `rtk proxy python3 -` の subprocess.run から表の引数で順に実行し、それぞれの monotonic clock の外側の時間を採取した。基準との差分表示の3件と、担当が修正した2件を区別する。work の成功は文書のみの選択の成功であり、Lean の型検査や Rust のテストの成功を追加した意味ではない。

保護対象4,641件の内容の識別値は、初版の `f32e358d1aaabcb3f189d805f4eb077921af3f582194a176d3d4eb50eeba8fd3` と一致した。L00a.01b の一覧に保存された形式化/検査入口の402入力も現物と全件一致した。今回も .olean/import/道具の版の再採取、Lean ビルド、A-L、全比較、性能測定、RSS採取は行っていない。最大常駐量は未取得（計画上の非採取）。

20:46の点検時の contracts.md の SHA-256 は `9c7cf0cd811a1f6b85da54162a46b23ab0234ed05522ea84c08924f52c44bf45` だった。その後、中4の行へ「旧規則が条件を要求する位置ごとに示し、文脈全体の WF を追加要求しない」と補足した。20:49の最終点検時の契約文書の SHA-256 は **`ffa95dbf072eec29055652dbfcc25bf252b277b3e07a0a04c4814020bcf9fe32`** である。以後の編集は本書の検査結果の追記だけである。実行した検査に失敗はない。引用元の探索中に存在しない仮のファイル名を含む rg が終了2となったが、定義が実際にある Typing.lean 等を検索して開き直し、各所見の根拠を確認した。

最終の文書点検まで確認できる区間は20:25:25〜20:49:08の **23分43秒** である。最後の検査結果の追記と最終報告はこの区間に含めない。読み取り/文書修正とツールの待ちを分離していない外側の時間であり、能動時間の確定値や本番の証明作業の比へ算入しない。修正版の独立レビュー・受け入れは取りまとめと設計者の担当である。
