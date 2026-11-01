# RV-L10.w のレビュー記録

2026-11-01。対象はブランチ `m014/l10.w` の未コミットの作業ツリー、基準は `d3a22dfb5dff5525888e4332e4bb978a4961074c`。

**判定: 条件付き可。所見は重0、中2、軽5 である。**

定義の本体（型代入・辞書の文脈・値の移動・return 契約・四名前空間）に誤りは見つからなかった。実際の遷移と一致することを補助入力で確かめた。条件は二つある。実装のメソッド本体の Q を規範と呼出し側に接続すること（中1）と、辞書と Q を読む正例を境界に足すこと（中2）である。どちらも L20 へ渡す前に閉じるのがよい。

検査の入口は `<repo>/formal` で `lake env lean -M 12288 <入力>`、補助入力は `<tmp>/rvl10w/` に置いた。下記の補助入力は全て終了0、`sorry` なしである。

## 所見

### 中1: 実装のメソッド本体の Q が、規範と呼出し側の Qsig に接続していない（主な定理の前提の中身に触れる）

- 箇所: `formal/Benitoite/Release/Refinement/ProgramTyping.lean` の `ImplDecl.WellTyped` の `QTel t'`、`docs/design/01-spec/01-12-core-calculus.md` の新節「篩を含む定義とプログラムの適格性」と既存の「D-Implの各メソッド本体は、対象型を代入する前の署名から得た`Qsig(Āj, Bj, εj)`で検査する」。
- 問題: 本体の Q は型代入と値移動の後の `QTel t'` である。一方 `C_Meth` の `MethodRowsAdmissible` は代入前の `Qsig ms.params ms.ret ms.eff` を読む。`MethSig.QTel_eq_Qsig` が与えるのは `QTel ms.tel` の等号であり、`QTel t'` には届かない。したがって、E_Meth の保存で要る `QTel t' i → Qsig … i` を与える補題がない。同じ 01-12 の中で、既存の文は代入前、新節は代入後と書いており、読めば確定する食い違いである。signatures の判断1と results の「Q の三等号で接続する」という説明も、関数については正しいがメソッドについては足りない。
- 再現: あり。`rv-w-t1.lean` の `qsig_empty`・`qtel_grows`。対象型が Fail と行変数を持つ関数型のとき、`Qsig` は偽、`QTel` の代入後は真である。`ImplDecl.WellTyped` はこの対象型を拒まない。`ImplDecl.Scoped` の `ne = 0` が拒むので、保存が両方の前提を持つ限り健全性の反例ではない。ただし等号は `target` の行なしと `Tel.bind`・`Tel.norm`・`Tel.shiftV` を通す別の相互帰納を要する。読んだ範囲では成り立つが、未証明である。
- 修正案: `TelBodyTy P B StoreTy.empty (QTel ms.tel) C Γ [] t' body` とする。01-12 の既存の文と旧 `ImplDecl.WellTyped` の `Qsig` に一致し、`MethSig.QTel_eq_Qsig` がそのまま呼出し側へ接続する。条件が強まらず追加の補題が要らない。detail の W と 01-12 の新節、signatures を同じ変更で直す。`QTel t'` を保つなら、`target.RowsIn (fun _ => False)` の下の等号を L10 で証明し、01-12 の既存の文を改める。

### 中2: 境界は辞書の文脈・値の順序・C の順序・Q の受渡しを検出しない

- 箇所: `l10/w/boundary.lean` の `impl_typed`・`def_typed`・`dictionary_value_shift`。`l10/w/results.md` の「Q の非空の行条件、型代入の具体的な像、辞書分の値移動…の正例も含む」。
- 問題: 正例のメソッド本体は引数 `x` しか読まず、Γ の辞書を読む正例がない。`dictionary_value_shift` は `Tel.shiftV` の計算だけで、入口へ接続していない。閉じた宣言では `Tel.shiftV` は恒等である。全ての Q 関連の正例も本体が Q を読まない。request の「同じ program で確認」の説明は、この四点については過大である。
- 再現: あり。`rv-w-t2.lean`。`ImplDecl.WellTyped` の条件を次のように変えた定義に、境界の `impl_typed` の証明がほぼそのまま通る。`Ty.shift g 0` を外す（`NoShift`）、値移動を外す（`NoValueMove`）、C の順を入れ替える（`SwapC`）、Q を常に真にする（`QTrue`）、辞書の文脈そのものを空にする（`NoDict`）。`NoValueMove` だけ展開の補題を足した。`Def.WellTyped` の Q を常に真にしても正例は通る（`def_typed_q`）。33本の負例は別の条件を射影するので、これらの変異を読まない。
- 定義自体の確認: `rv-w-t1.lean` の `impl_wellTyped` は辞書を返す本体を入口全体で型付け、`rv-w-t4.lean` の `call_through_dictionary` は `d.pm(x)` を `C_Meth` まで型付けた。定義は正しく、欠けているのは境界である。
- そのほか負例のない条件: `ImplDecl.WellTyped` のメソッドの `NamesWF`。`ConDecl.Scoped` の Annotation と kind。`OpDecl.Scoped` の NamesWF と辞書の添字。`MethSig.Scoped` の NamesWF と HasKind。`ImplDecl.Scoped` の辞書の添字・target の範囲と注釈・super の範囲。publicBoundary の範囲。外部関数の宣言は正例にもない。
- 修正案: `rv-w-t1.lean` と `rv-w-t4.lean` の二例を境界へ移し、行を持つメソッドの本体が Q を読む正例と、Q の外の行で拒まれる負例を足す。上の未検出の条件に負例を足す。results の説明を実際の範囲へ直す。

### 軽1: 実装の辞書引数の型に kind を要求しない

- 箇所: `ImplDecl.WellTyped`・`ImplDecl.Scoped` の `TypeAnnotations P id.tparams [] id.dictTys`。
- 問題: `Ty.Declared` は `.dict _ a` のクラスを読まないので、宣言のないクラスや kind の違う引数の辞書型を通す。target には HasKind があり非対称である。その実装の辞書の値を作れないので、実害はなく、現行の読者もない。
- 再現: あり。`rv-w-t5.lean` の `ghost_dict_annotated`・`ghost_dict_not_kinded`。
- 修正案: `ImplDecl.Scoped` に `∀ a ∈ id.dictTys, a.HasKind P (replicate … .value) .value` を足す。実際のプログラムは満たす。

### 軽2: 操作の dictParams と params の先頭の対応を検査しない

- 箇所: `OpDecl.Scoped`、`Refinement/Syntax.lean` の `dictParams` の doc comment。
- 問題: doc comment は「params と names の先頭はこの列の辞書である」と書くが、Scoped は添字の上限だけを見る。現在 `dictParams` の読者は Lean にないので、影響はない。
- 再現: あり。`rv-w-t5.lean` の `op_scoped_without_dictionary_prefix`。
- 修正案: 先頭の一致を足すか、読者ができるまで Lean の外の照合に残すと 01-12 に書く。

### 軽3: MetadataScoped は公開境界の行変数を拒み、VarianceOK は通す（書ける形に将来触れうる）

- 箇所: `Program.MetadataScoped` の `a.SourceScoped 0 info.arity 0 0`。
- 問題: `Ty.VarianceOK` の Eff は行の原子を読まないので、行変数を含む関数型の公開境界を通す。MetadataScoped は拒む。現在は収集器がなく、data は行変数を束縛しないので、書ける形の制限ではない。Rust の収集が公開関数の型をそのまま列へ入れると、受理できるプログラムが WellFormed を満たさなくなる。
- 再現: あり。`rv-w-t5.lean` の `boundary_row_variance`・`boundary_row_rejected`。
- 修正案: 定義は保ち、R10b の照合の義務に「公開境界の列に行変数を残さない。残す必要があれば MetadataScoped の `ne` を見直す」と書く。

### 軽4: 旧の範囲述語より SourceScoped が狭く、宣言の埋め込みの義務が増える

- 箇所: `Val.SourceScoped` の `.loc`・`.checked`・`.checkedRequest` などの False、旧 `Val.VarsIn` の True。detail の I は値の入力に checked 系を含める。
- 問題: 旧の型付けは空ストアでも `.checked` を本体に許す。旧 `P.WellFormed` から新 `P.WellFormed` を導く段階で、ソース構文だけという入力が別に要る。旧の前提から自動では得られない。
- 再現: 読めば確定する。利用者の書ける形には影響しない（これらはソースに書けない）。
- 修正案: L20 G08 の埋め込みの前提に、宣言の本体が実行時専用の構文を含まない入力を明記する。

### 軽5: 設計書に改造の工程の名前と未実施の照合が入っている

- 箇所: `docs/design/07-quality/07-04-formal-semantics.md` の「L70/R10b で Lean の外の照合に残す」、01-12 の新節の末尾の「Lean の外で照合する」。
- 問題: 07-04 の中で工程の ID を書くのはこの行だけである。設計書は実装した内容だけを書き、残りは docs/todo の項目とする規約に合わない。
- 再現: 読めば確定する。
- 修正案: 「この形式化は収集の完全性を保証しない」と現状だけを書き、残りを docs/todo の TODO-nnn で引く。

## 旧の要素との対応

| 旧 | 新 | 判定 |
|---|---|---|
| Def.WellTyped の NamesWF・本体 | NamesWF・TelBodyTy。kind と Annotation を追加 | 対応 |
| Impl の定義域・本体・super | 同じ条件と target kind・辞書の注釈 | 対応。Q は中1 |
| Program.WellTyped の二欄 | defs・impls に variance・external を追加 | 対応 |
| Def/Con/Op/Meth/Class/Impl の Scoped | 同名の六定義。kind・Annotation・範囲を追加 | 対応。軽4 |
| 別の前提の `EffectsOk`・`CoreAssumptions` | 別の前提のまま。`sig_scoped` は G08 | 取りこぼしなし |

新の追加条件で現実のプログラムを狭めるものは見つからなかった。実装の型パラメータを value kind に限る点は、処理系で確かめた。`data Wrap[F[_]]` は構文エラー、`implement[F[_]] Describe[List[F[Integer]]]` は E0712 で拒まれる（`hk.bnt`・`hk2.bnt`）。構成子のない型は 01-05 で誤りなので、DataArity の存在の要求も狭めない。`implement Functor[List]` の形は `rv-w-t3.lean` の `hk_impl`・`hk_scoped`・`hk_impl_scoped` で通る。

## 確かめて問題がなかった重点

- 主な定理への供給: `E_Fun`・`E_Meth`・`E_Super`・`E_Op` の遷移を辿った。本体、定義域、辞書の長さ、上位辞書、constructor の形成、外部宣言は取り出せる。既定のメソッドは `ClassDecl` に欄がなく、脱糖で実装の本体になるので別の読者はない。進行に要るものは `WellTyped` にある。
- 型代入と値の順序: `Capture.extendMany (vs ++ ws)` の添字は `bindParams` の逆順と `TelBodyTy.param` に一致し、`body.substTy (ss ++ ts) es` の型の番号は `ms … ++ id.tparams` に一致する。`superStep` の `instantiate vs` も `bindParams [] dictTys` に一致する。
- 行と型構成子の代入: `es = []` で行は保たれる（`rv-w-t1.lean` の `row_kept`）。`.tapp g` は対象の `.ctor` で `.list` へ還る（`rv-w-t3.lean` の `hk_contract`）。
- Q の関数側: `Def.QTel_eq_Qsig` は `V_Fun` の `Admissible` が読む式に一致する。追加の NoFail はない。
- 依存列と return 契約: `dep_body` は先行引数を読む結果型を `C_Return` で型付ける。`escape_under_handler` は C-Handle の下の escape が `done` の R を読むことを示す。
- SourceScoped: 44構文の束縛数を旧 `VarsIn` と `Subst`・`Step` と照合した。`.lam` は非依存で `ps` を `nv` のまま読むので正しい。Pat は値参照を持たない。`Eff.WF` が読まない効果原子の範囲は RangesScoped が補う。
- 空の全称の範囲の記述、原ソースとの一致を主張しないこと、`VarianceValid` と metadata の二重の arity の整合。
- 負例33本は同じ非空の program の一か所を変え、意図した条件を射影している。空虚なものはない。
- 五つの境界: 新公理なし、提供範囲の変更なし、利用者が書ける形の新しい制限なし（軽3の留保）、精密な外部状態なし。主な定理の前提は欄の追加だけで結論の変更なし。中1は前提の中身の式の修正である。`ValueMeaning` と型付けからの所属を信頼する欄はない。
- 証拠の再実行: `lake build` は753ジョブで成功。境界は終了0、378件。公理依存は終了0で記録の出力と一致。`immutable-inputs.json` の641件と `check-inputs.json` の516件のハッシュは一致。signatures の二つのブロックは本番と完全に一致。76・22・44の件数と負例33・補題54を確認した。主要ファイルは git で無変更であり、304枝も変わらない。絶対パスは記録にない。

## 補助入力

`rv-w-t1.lean`（辞書の本体、行の保存、Q の差）、`rv-w-t2.lean`（変異）、`rv-w-t3.lean`（型構成子のクラス、依存列）、`rv-w-t4.lean`（辞書経由の C_Meth、handler の下の escape）、`rv-w-t5.lean`（読まれない条件）、`hk.bnt`・`hk2.bnt`（処理系の確認）。

## 取りまとめの追記

2026-11-01。補助の入力は `l10/w/rv-w-t1.lean`〜`t5.lean`、`rv-w-hk.bnt`・`rv-w-hk2.bnt` へ写した。中1は `plan.md` の先頭の判断のとおり `QTel ms.tel` へ改める。中2と軽1・軽2・軽4・軽5 は同じ再開で処置する。軽3は R10b の義務へ書く。
