# RV-L00b.02a: 群末の独立レビュー依頼

2026-10-31。実装担当の自己点検と担当検査を終えた状態を渡す。独立レビューの実行・担当の割当て・受け入れは取りまとめが行う。本書はレビュー済みの記録ではない。

## 入力と範囲

- 基準B_WORK: `2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf`。指定ブランチは `m014/l00b.02`。gitの操作は行っていない。
- [実装の結果](../l00b.02/results.md)、[完全署名と決定の記録](../l00b.02/signatures.md)。最新は第19節であり、第16〜18節の停止は当時の記録である。
- [今回開始時の入力](../l00b.02/02a-r4-inputs-before.json)、[最終の入力](../l00b.02/02a-r4-inputs-final.json)、[差分の大きさと SHA-256](../l00b.02/large-records.md)、[変更の一覧](../l00b.02/02a-r4-source-changes.json)。差分は前の担当の未コミット変更を含む今回開始時からのものである。
- [検査](../l00b.02/02a-r4-validation.json)、[場合の一覧](../l00b.02/02a-r4-case-inventory.json)、[公理依存](../l00b.02/02a-r4-axioms-summary.json)、[境界の補助入力](../l00b.02/02a-r4-boundary.lean)。本番はすべて既定 import に入る。

新規ファイルの一覧（B_WORKから、全16）: AtomOrder.lean、Atoms.lean、BindCongr.lean、BindingShift.lean、Codes.lean、ContextFacts.lean、ContextMap.lean、Declared.lean、DeclaredTransport.lean、KindInference.lean、Kinds.lean、ScopeSyntax.lean、Telescope.lean、TermSyntax.lean、ValueClosed.lean、**ValueReferences.lean**。今回開始時からの新規15と、前の担当が追加済みだったScopeSyntaxを区別する。

## 優先して確かめること

1. 候補(A)のsomeかつOrdinaryという参照の条件がsnapshotのsomeの中・self・Telのparamの下まで一貫し、None/cont/hideを扱えるか。Transport.references / typeImages と型付き像からの導出に欠けがないか。
2. Sourceの制限、sort、References、Declared、WFを混同していないか。部分の像のnoneをslotに保ち、openOptional/assume_optionalでsortのない関数の像も扱い、旧の全域openの誤った交換へ戻っていないか。
3. Ty21/Tel2、LeQ12/TelLe2/TelClosure2の相互のnorm/shift/bind/有限置換が、任意のcutoffと二つ目以降の引数の下でも成り立つか。旧の非依存fnをtoTelへ包むときの外側の移動が正しいか。
4. FieldRef.Declaredが受け手の名目型と型引数、実際の構成子宣言・欄・具体化後のsortを照合しているか。宣言の欄型のWF0、宣言のselfのΓ.extend、DeclarationImagesの束縛/正規化/値置換の証拠が正しいか。内部snapshotのHasData.valueの証拠と型付き観測の接続を、閉じた評価・欄の意味論の完成と混同していないか。
5. V_Sub/C_Sub/V_RefineへのDeclaredの接続、narrowingの補助判断へのP/CとDeclaredの追加が、許可された補助契約の詳細化の範囲か。主定理の前提/結論、提供範囲、書ける形を変えていないか。
6. kindがconstructor nの像を最外のctor/tvarに限り、arityの照合からrawApplyの引数破棄/Unit補完を除けるか。dataの全構成子宣言のarityの一致、有限の宣言注釈のkindの供給と、後続の呼出し・Program.WellTypedの役割を区別できているか。
7. 新Atom/RangeIxと旧の構造的な埋め込み、based/secretsを保つ範囲置換、Bool所属関数の単射な比較、旧比較順・norm・WF・単射性の交換に抜けがないか。比較のcodeを言語の鍵の等値へ流用していないか。
8. 既存3族の各15場合とTypedFactsの予定12場合、追加の補助28場合を区別して数えているか。既存の障害例を削除・弱化していないか。新しい公理・sorry、未検証の前提への置換がないか。

## 検査済みの範囲と残り

既定 `cd formal && lake build` は成功（619 jobs）。単独の境界の型検査、公理依存検査も `-M 12288` で終了0である。全46モジュールの6,151宣言を検査し、propext / Quot.sound / Classical.choiceだけを使用した。入力のSHA-256は検査前後で一致した。担当からworkは実行していない。

`.02b-values`以降、閉じた評価、意味論の三モデル、主定理、Rust/Leanの全比較は今回の完成範囲に含めない。取りまとめのworkと独立レビュー、設計者の受け入れが残る。レビューのreport/response/handlingは、このrequestに対応するファイルとして取りまとめが保存する。
