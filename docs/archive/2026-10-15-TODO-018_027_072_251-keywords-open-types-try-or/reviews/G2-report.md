# G2 のレビュー（2026-10-16、Opus 5.5 のサブエージェント）

対象: D1〜D4（`git diff dc2c15a1 d9e96ec0 -- formal docs/design`）。依頼書は G2-request.md。ファイルは変えず、ビルドも走らせていない。

**結論**: 【重大】なし。定義は意図どおりに働き、定理は弱められていない。ただし、どの型をどの本体で開くかの規則は Lean の外にあり、設計書の写しに食い違いが一つある。

**意図どおりと確かめた点**
- 入れ子の `Error(各 Kind)` だけの照合と、リストの要素の中の照合は、外部では反例 future を返す（Coverage.lean の nestedTy とリストの例）。
- ガード付きの `case other` は網羅に数えない。全構成子の後の `_` は外部では「選ばれない」と報告せず、内部では報告する。
- 一構成子の型（レコードの `ParseError(message: m, ..)` もこの形）を構成子で分解する bind は外部では拒否する（Wrap の例）。
- `future` と `other` は別の形で、`specialize_future_iff` で変数と `_` だけが future を覆う。
- try・レコードの更新・getter の内部の照合は `closedView` に固定。
- 旧い定理 28 件のうち言明が変わったのは `checkImpl_sound`（views の追加）だけ。`desugar_typed` は前提の WellTyped が強まったが結論は同じ。閉じた view の互換の入口は `rfl` で一致。新しい axiom と sorry は差分にない（公理の実測は d4 の記録で確認）。

【中】
1. 開く型を決める規則が Lean の外にある（`Exchange/Version.lean` の `coverageView`、`CheckInput.prepare`、`Convert.Input.operationProgram`）。view は Rust から受け取り、Lean は「挙げた型が extensible であること」しか確かめない。Rust が外部の本体の view から IOErrorKind を落とすと、Rust も Lean も閉じた判定で受理し、差分テストは一致する。Result・Option が閉じたままであることも Rust の `extensible=false` に頼っている。定理は任意の view で成り立つので証明は壊れないが、保証の範囲が狭い。修正案: 9/3/3 の `DataTypeInfo` に型の所属パッケージを、`SurfaceDef` と網羅性の各項目に本体のパッケージを足し、Lean で「extensible かつ所属が違う型」を計算して `coverageView` と一致することを確かめる。少なくとも、Result・Option が `extensible=false` であることと、外部の本体の view に IOErrorKind 等が入ることを確かめる負の入力を D6b に加える。
2. 将来の構成子に対する保証が定理になっていない（`Release/Coverage.lean`）。view 付きの定理の結論はどれも現在の値の `Exhaustive` で、`closedView` でも得られる。修正案: 「拡張に対する健全性」を加える。前提: `usefulWithView P ctors view [a] rows [wild] = none`、P' は view が真の型にだけ新しい構成子を足したもの、`CtorsComplete P' ctors'`。結論: `Exhaustive P' a ps`。証明は補題 U の形に沿う見込み（推測）。
3. `docs/design/02-impl/02-05-typechecker.md` の 340 行（`Declarations` の段落）「Program の本体ごとの指定と交換形式は未接続であり」は D3 と食い違い、01-12・07-04 とも矛盾する。同じ節の最初の段落の「現在の処理系と交換形式はまだ閉じた既定を使い」も合わない。修正案: 340 行を「Program の functionViews・methodViews と交換形式 9/3/3 へ接続済みである。Rust の書き出しは 8/2/2 の閉じた既定のままである」、最初の段落を「Rust の処理系と書き出しは閉じた既定を使う」に直す。

【軽】
4. 07-04「`SurfaceDef.coverageView` は…有効な型名の一覧」の型名は、Lean が照合する識別名 `name` か表示名 `typeName` かが二通りに読める。D6b が表示名を出すと拒否される。「型の識別名（`DataTypeInfo.name`）の一覧」と書く。
5. 各入口は corpus の `dataTypes` と型表の `dataDecls` を順序と集合まで一致させるので、D6b は二つを同じ並びから出す必要がある。`prepare` は v9 の空の `dataTypes` を照合せず、型表を持たない DesugarDiff では型の情報が抜けた入力を閉じた入力として黙って通す。修正案: `readCorpus` で、入力に現れる `.data d` がすべて `dataTypes` にあることを確かめる。
6. `prepare`・`operationProgram` の `views.find?` は、同じ鍵に違う view が二つ来ると最初のものを黙って使う。重複を拒否する。
7. 定数の本体は使う側の本体の view で検査される（`E_Const`）が、R12 では Rust は定数をそれ自身のモジュールで判定する。パッケージをまたぐ定数の中に match があれば結果が分かれうる（推測）。D6b で確かめるか写しに明記する。
8. `closedDefaults` は対象の種類を欄名の有無で推測する。今は害はないが、後で交換形式を変えたときに取り違える恐れがある。


## 対応

- 【中】1: 型・本体・定数の package と標準型の builtin を必須で交換し、Lean で view を再計算して完全照合する。Result/Option の開放を拒否する。D6b の出力欄と負の入力を plan.md に追記した（R33）。
- 【中】2: ConstructorExtension と usefulWithView_extension_exhaustive を追加し、変更前後の完全性と許可された構成子追加から拡張後の Exhaustive を証明した（R34）。
- 【中】3: 02-05 の未接続という記述を Program と交換 9/3/3 の接続済みに修正し、Rust の出力 8/2/2 と区別した。
- 【軽】4: coverageView は DataTypeInfo.name の型の識別名の一覧であり、表示名ではないと写し・計画に明記した。
- 【軽】5: readCorpus で型引数・定数内を含む data 型の metadata の存在を検査し、desugarDiff でも欠落を拒否する。D6b で二表を同じ宣言順から出すことを明記した。
- 【軽】6: prepare と operationProgram の関数名・実装名とメソッド名の組の重複を拒否し、異なる view が先勝ちしないようにした。
- 【軽】7: public const は外部参照できるが match は E0433 で拒否することを実装で確認し、E_Const の使用側の view との差と適用範囲を写しに明記した（R35）。
- 【軽】8: closedDefaults を形式と既知の欄の経路による変換へ変更し、任意の入れ子の欄名から対象の種類を推測しないようにした。

- Z2【軽】1: builtin の一意性と stdlib 所属を validateDataTypes で、Ok/Error・Some/None の名前と型引数・引数型・非 record を構成子を持つ入口で検査する（R38）。
- Z2【軽】2: 外部パッケージの inspect が IOErrorKind を照合し、書き出した view に型の識別名が含まれる正の入力と、その指定を落とした負の入力を D6b に追加した。
- Z2【軽】3: 01-12 の定数の段落から Rust の検査とファイル名を外し、仕様の制限と E_Const の関係だけを残した。02-05 は 07-04 の説明を参照する形にした。
- Z2【軽】4: corpus9 の readCorpus で定数の本体を再帰検査し、ソースの match と束縛を含む入力を拒否する（R38）。
