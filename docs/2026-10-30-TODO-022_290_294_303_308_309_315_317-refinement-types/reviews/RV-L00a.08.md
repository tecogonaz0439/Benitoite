# RV-L00a.08: L00a.08・.09a・.09b・.10（移動・置換・一原子の被覆の中心の補題）のレビュー

2026-10-30。レビュー担当は Opus 5.5 のサブエージェント（effort medium、所要約6分）。対象はブランチ m014/l00a.08 の `formal/Benitoite/Release/Refinement/` の新しい13モジュールと既存4モジュールの変更、`formal/Benitoite.lean`、[l00a.08/results.md](../l00a.08/results.md)。定義・言明・仮定のレビューとして行った。リポジトリのファイルは書き換えず、報告を応答で返した。取りまとめが要点を保存した。重大はない。中1件、軽7件。

## 実行して確かめたこと

`cd formal && lake build`（増分）は終了0（595 jobs、すべて再利用）。Refinement の警告はない（既存の Interval の unusedSimpArgs だけ）。新しい13モジュールと変更した4モジュールを `lake env lean -M 12288` で一つずつ検査し直し、17件すべて終了0・出力なし。`sorry`・`admit`・`axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern`・`set_option` は該当なし。主な補題27件（`Ty.LeQ.shiftV`/`bind`/`rawBind`、`Eff.Covers.shiftV`/`bind`/`substAt`/`subst`/`substV`/`mapRanges`/`substRAt`、`Ty.shiftV_eq_renameTy`、`Transport.extend`/`up`/`up_raw`、範囲と値の交換5件、`cannot_split_one_atom`、`covers_not_sub`、OpenSubstitution の3件、`rawApply_refined`、`Entails.bind`/`shiftV`）の `#print axioms` は {propext, Quot.sound, Classical.choice} の部分集合。13ファイルの private でない宣言は263件で public-names.json の added と一致、exposed は30件。既存4モジュールの差分は `private` を外したことと冒頭の説明だけで、型と本体は変わっていない。

## 読んで確かめたこと

`Ty.LeQ.bind`/`rawBind` は LeQ の9構成子について導出を帰納法でたどり新しい `Ty.LeQ` の導出を返し、意味のモデルへ落としていない。前提は `Transport`（整数を観測する位置の像が termSorted であること、Γ.facts ++ Φ の像を Δ.facts ++ Ψ から Entails で導けること）だけで、None の位置には何も課さず強すぎない。`Ty.assume_bind` は型の像で事実が増える場合を包含で扱う。`Eff.Covers.bind` は各原子に一つの証人を残し、行の像から来る原子と Fail を像の所属で覆い、像へ置換を当て直さない。`cannot_split_one_atom` と `Eff.Sub.covers`/`covers_not_sub` で被覆と構造上の包含を分けている。送ったもの（`rawApply_refined` を L00b.11 へ、Term の論理の置換と一般の `σ : Nat → Val` の整数の観測の接続を .12a/.12b へ、正規化との交換で閉じなかったものはないこと、四名前空間の一般の合成は条件付き）は黙って除外していない。記録の規約の違反はなく、新しい13モジュールにすべて冒頭の説明がある。

## 中

- **中1. 開いた代表の導出が、空でない facts/Φ と篩付きの像を一度も使っていない**（`OpenSubstitution.lean:72-78` の `all_open_derivation`、48-53 の `transport` の facts の枝）: 導出は `fn_effect` の一つだけで、Γ.facts=[path] と Φ は Entails の移送に使われず、篩付きの型の像 `dependentType` は関数の引数の位置に運ばれるだけ。Ψ を `[predBind σ path]` に選んだため `transport.facts` は `.hyp` だけで閉じる。一般の補題 `Ty.LeQ.bind` は introduce/refine の枝を閉じているが、O006 と O002 の代表が主張する性質はこの代表では確かめられていない。修正案: `introduce` か `refine` を使い path を仮定として使う導出（`Integer ≤ Integer{self = 7}` の形や `.tvar 0` を篩付きの像で置き換える `refine`）を作り `.bind θ transport` で移す代表を足す（Ψ を Δ.facts から導く形が望ましい）。直さないなら主張を弱める。

## 軽

1. 義務の判定表に O031（L00a.08〜.12b、Le/Covers の substAt/subst/shift と型・行の像の自由な値の変数）と O040（本番の Nat/cutoff での実績）の行がない。
2. 値を持たない束縛（`Ctx.extendNone`、Context.lean:143）の Transport がない。.12a/.12b で要る見込み。
3. 置換で WF と sort が保たれること（`Ty.wf_bind`/`Ty.sorted_bind` の型と行の版）の行き先が書かれていない。
4. rawApply の送り先（L00b.11）が plan.md に載っていない。rawApply は篩付き以外（`.base` など ctor でも tvar でもない像）でも型引数を捨てる。kind の検査（L00b.02a）の側で扱うかもあわせて判断する。
5. 範囲の具体化（`RangeSubst.lean:180` の `rangeAt`）は列の外の番号を詰めない（既存の `Ix.inst` の規約と一致）。c>0 の `substRAt` が普通の de Bruijn の置換と違うことを一文書く。
6. 一原子の分割の拒否を置換の像の上では示していない（任意）。
7. 公開に変えた `assumptions` は Release.ModelHttp:444 と ModelTargets:346 に同名の定理がある（名前空間は分かれている。後の段への注意）。

## 義務の行の判定

O002（RV-P1 S1）の L00a.08〜.10 の分は閉じた（代表の性格は中1）。O004 の .08〜.09b の分は閉じた。O006 は一般の補題では除外していないが、代表で導出を通す点は中1を直すまで不十分。O031 の L00a の Le/Covers の分は閉じた（相互置換は .12a/.12b → L20）。O040 の .08 の分は満たした。O010 は .16a/.16b へ。O016 は新しい葉の局所の公理の依存を確かめた（A-L は L00a 末）。

## 取りまとめの対応

中1・軽1・軽2・軽3・軽5 は L00a.08 の続き（同じセッション）で直させる。軽4 は取りまとめが plan.md の L00b.11 の行に記録する。軽6・軽7 は後の作業への注意として申し送る。
