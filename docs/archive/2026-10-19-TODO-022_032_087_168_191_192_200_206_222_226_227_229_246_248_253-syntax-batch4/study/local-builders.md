# 関数内の構築器の残件の調査（S1）

2026-10-19、0.0.9 公開後の `c31e64b03d2810343e1779926bea4ebc958b6164`、`mod010/design` を調査した。対象は docs/todo の TODO-248 の残りと、測定に必要な TODO-262 の builders 族の修正である。元の本文は [項目の写し](../todo-items.md)、判断を求める点は [B1〜B16](local-builders-questions.md) に置く。以下の実装案・定理の追加案・数値目標は未決定であり、証明・実装・測定の成功を報告するものではない。

## 1. 推す範囲と調査で分かった限界

構築器だけを型付きの局所文脈（local context）で区別し、その専用操作を外側のエフェクト（effect）に残さない案を推す。通常の `Reference` の State は残す。0.0.9 の `bind`・専用 `new`・注釈・捕捉（capture）の禁止を引き継ぎ、寿命の注釈や領域多相（region polymorphism）は加えない。第二級の値（second-class value）という現行の呼び名を使う。普通の引数・結果・格納先へ渡せない構築器を指す。

**主定理の外側の前提・結論を保つことは設計目標にできるが、現行の定義・証明を保ったままでは実現できない。** 今の脱糖（desugaring）は State を持つ Reference の呼び出しである。表層から State を消すだけでは、同じエフェクトを持つコアへ移す脱糖の型保存（type preservation）である性質1が破れる。正式な Release の局所操作・ストア・継続（continuation）の規則と証明を先に拡張する必要がある。この調査では Lean を変更・実行していないため、「主定理を変えずに済む」と確定しない。

専用バッファには、既存の `ObjKind::Host` と `HostData` を使う案を推す。文字列は Rust の `String`、バイト列は `Vec<u8>`、リストは `Vec<Slot>` を保持する私有のデータにする。新しいヒープ（heap）の対象種別や `unsafe` は、まず必要としない設計を試す。局所状態を隠す証明と、物理バッファの GC（garbage collection）上の安全性は別の仕事であり、片方の成功をもう片方の根拠にしない。

測定は既存の `compare/` を使う。short は退行の疑いを探すため、targets は構築器の数値目標を判定するために使う。0.0.9 の関数数・制約・縮小の本測定は扱わない。

## 2. 調査の根拠と文書の扱い

現行の根拠は [目的と設計原則](../../design/00-overview/00-01-goals.md)、[用語集](../../design/00-overview/00-04-glossary.md)、[07-03「実装の規約と静的な検査」](../../design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査)、[07-04「01-12 との対応」](../../design/07-quality/07-04-formal-semantics.md#01-12-との対応) と現在のコードである。07-04:179 は構築器の0.0.9での保証をまとめている。

前回の記録は [0.0.9 の README](../../archive/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/README.md)、同ディレクトリの design.md 第7節、decisions.md B1〜B12・R108・R116・R123・R131・R147〜R155・R166〜R168・R182・R184、plan.md の Lean 先行と停止点、results.md、reviews/ の RV5 の指摘、および study/ の調査・問いの形を参照した。これらは作成経緯の資料であり、現行仕様の代わりにはしない。

非公開資料では、docs/todo の TODO-250 末尾の「形式化の重さによる組み方」、2026-10-17 の feasibility-spikes の248の findings.md と四つの `.lean`、2026-10-11 の language-direction の memo.md を読んだ。非公開資料へのリンクは作らない。方向のメモにある可読性の重みの見直しは、現行の00-01をすでに変更した決定とは扱わない。今回、表層の新構文を必要とする根拠は見つからなかった。

## 3. 0.0.9 の実装と保証

### 3.1 宣言・操作・持ち出しの検査

三モジュールを明示して import し、`bind b: StringBuilder <- StringBuilder.new()` の形で作る。List は `ListBuilder[T]` の T を明記する。注釈は通常の型ではなく、構築器の種類を指定する。宣言を普通の型推論へ混ぜない。

| 場所（行は開始版の番号） | 現在の処理と読み取れる契約 |
|---|---|
| [resolve/builders.rs](../../../crates/benitoite/src/resolve/builders.rs):188、271 | `builder_special` が解決済みの標準 ModuleId を照合し、`builder_bind` が注釈と同種の直接 new、型引数数を検査する。同じ綴りの利用者モジュールに特例を適用しない |
| 同ファイル:213、239 | `builder_name`・`builder_target` が通常値としての使用と、宣言時の境界を越える参照を拒否する。宣言と捕捉境界を診断の補助位置にする |
| [typeck/builders.rs](../../../crates/benitoite/src/typeck/builders.rs):13、49、91 | 全操作用の State、通常の型表に追加しない宣言情報、専用引数の種類と結果型を作る。List の要素は通常型である |
| [typeck/calls.rs](../../../crates/benitoite/src/typeck/calls.rs):576、650 | 通常の引数の個数・ラベル・型を検査し、操作に State を付ける |
| [diag/codes.rs](../../../crates/benitoite/src/diag/codes.rs):837 | E0463 は宣言の形、E0464 は通常の型・値への使用、E0465 は境界越しの捕捉、E0466 は専用操作の値化・部分適用等を報告する |
| [StringBuilder.bnt](../../../crates/benitoite/src/prelude/stdlib/StringBuilder.bnt):1、[ListBuilder.bnt](../../../crates/benitoite/src/prelude/stdlib/ListBuilder.bnt):1、[BytesBuilder.bnt](../../../crates/benitoite/src/prelude/stdlib/BytesBuilder.bnt):1 | 通常の関数定義を持たない説明用モジュール。専用の登録表は resolve/builders.rs:32、65、97 にある |

専用操作は new・append・appendAll・copy・長さである。String は byteLength、それ以外は length と呼ぶ。append は String、T、Byte をそれぞれ受け、appendAll は List[String]、List[T]、Bytes を受ける。追記は Unit、copy は通常の不変値を返す。

構築器は普通の変数・レコード・リスト・セル・型引数・Failの型へ入れられず、利用者関数へも渡せない。lambda・lazy・部分適用・ハンドラの節は外側の構築器を捕捉できない。そこで新しく構築器を宣言することはできる。if/match の分岐、handle の本体、通常の呼び出しの引数評価などは同じ局所文脈を使う。

現行に一般のループ文はない。List.forEach の lambda へ構築器を捕捉する反復は拒否する。appendAll に用意済みの断片列を渡すことと、動的な逐次ストリームの構築を区別する。今回もこの制限を保つ案である。

### 3.2 Reference と不変値への脱糖

[ir/desugar/builders.rs](../../../crates/benitoite/src/ir/desugar/builders.rs):28 の `builder_new` は空の通常値を Reference.new へ渡す。:65 の `builder_operation` は通常引数をソース順に一度ずつ評価した後に get し、copy ならその値を返す。長さなら get の後に通常の長さ関数を呼ぶ。append/appendAll は純粋な合成結果を作り、成功後に set する（:193）。

String の合成は `+` と String.join、List は List.append/concatenate、Bytes は Bytes.fromList の単一要素と Bytes.concatenate を使う。Bytes 全体を List[Byte] にしない。通常引数の評価中に継続を保存しても、再開後に読むセルの値から追記を始める。

copy は全量の物理コピーを義務にしない。現在の不変構造を共有し、次の追記でセルを別の構造へ替える。取り出したリストの要素にある Reference の内容まで複製する契約はない。速度向上は0.0.9の受け入れ条件でなく、実測でも確定していない。

### 3.3 Lean の表層・脱糖・捕捉禁止

以下の相対名は `formal/Benitoite/` の下である。

| ファイルと行 | 定義・定理と現在の役割 |
|---|---|
| [Surface/BuilderSyntax.lean](../../../formal/Benitoite/Surface/BuilderSyntax.lean):13、31 | `BuilderKind`・`BuilderOp`・`BuilderCtx`。通常の Ty と別の種類を持つ。`BuilderKind.cell` は脱糖先の Reference 型 |
| [Surface/Builders.lean](../../../formal/Benitoite/Surface/Builders.lean):26、107、224、249 | ΓとΔの `Aligned`、`Clean/AtomsIn/Single`、`fillBuilders`、`BuilderCellRefs.Ok`・`BuilderRefs.Ok`。セルの参照先の型・State を検査する |
| [Surface/Typing.lean](../../../formal/Benitoite/Surface/Typing.lean):86、501 | `E_BuilderOp` は通常引数の効果と State の和、`B_BuilderBind` は後続の効果と State の和。七判断へΔを渡し、捕捉境界では空にする |
| [Surface/BuilderLower.lean](../../../formal/Benitoite/Surface/BuilderLower.lean):14、29、47 | `builderCombine`・`builderFinish`・`builderNew`。純粋な合成と get/set/new の呼び出しへ展開する |
| [Surface/Lemmas/BuilderLower.lean](../../../formal/Benitoite/Surface/Lemmas/BuilderLower.lean):132、158、168 | `builderOp_desugar_typed`・`builderNew_typed`・`builderBlock_desugar_typed`。State 付きの型保存を証明する |
| [Surface/BuilderCheck.lean](../../../formal/Benitoite/Surface/BuilderCheck.lean):140、207 | 参照先の有限検査と `BuilderRefs.check_sound`。チェック器内部のΔと型付けを接続する |
| [Surface/Lemmas/BuilderNoCapture.lean](../../../formal/Benitoite/Surface/Lemmas/BuilderNoCapture.lean):365、375 | `builders_no_capture`・`builders_block_no_capture`。生成した lam/lazyC/節が外側のセルを自由参照しない。内部補題は BuilderCapture・BuilderCaptureCompose・BuilderCaptureAll に分ける |
| [Surface/Theorems.lean](../../../formal/Benitoite/Surface/Theorems.lean):19、31 | `desugar_typed`（性質1）、`surface_effect_soundness`。後者は純粋な main から IO・解放の事象と未処理操作がないことを結論する |
| [Surface/CheckSound.lean](../../../formal/Benitoite/Surface/CheckSound.lean):9 | 公開の検査器健全性11件。プログラム全体と交換入口にも接続している |

捕捉禁止は任意のΓ・Δについての性質であり、具体例だけの確認ではない。ただし `builders_ordinary_result` が示す TyOK は、コアのセル識別子の逸出一般を否定する定理ではない。現在は通常の Reference に展開するため、Release 自体に構築器の識別子・局所バッファの型はない。

## 4. 試作248の結果と正式モデルへの接続案

### 4.1 小モデルの成功と反例

`LocalBuilder.lean` は通常値のΓと、`Fin n` で参照する構築器の局所文脈を分ける。局所ヒープは `Fin n → List Nat` であり、通常値に識別子を入れる規則がない。通常セルの state と、構築器の local の印を別に集計する。`Run.trace_sound`、`local_mask_sound` は局所操作だけを除いた事象の包含を示し、`Run.world_frame` と `outer_pure` は外側の効果が空なら共有セルが変わらないことも示す。有限コマンドの実行存在・決定性、取り出し済みの構造の安定性も確認している。

反例が出た三つの案は次のとおりである。

| 弱い案 | 反例と避ける条件 |
|---|---|
| 普通の State もまとめて消す | `bad_mask_counterexample` では外側が純粋でも共有セルが7から99になる。局所と共有を、集計前から区別する |
| 具体化前の型だけを見る | Escape の `generic_escape_counterexample` は List[α] の α に Builder を入れる。通常型と局所の種類を分け、通常型の置換で Builder を導入できなくする |
| 関数の引数・戻り値だけを見る | `signature_only_counterexample` と `closure_lifetime_counterexample` は捕捉した構築器を見落とす。型の表面だけでなく捕捉境界を検査する |

`Regions.lean` は、異なる領域を同一視すると選択的な除去が破れること、引数と結果だけでは潜在エフェクトの領域を見落とすことを追加で示す。領域多相全体の健全性ではない。`Lowering.lean` は一つの構築器の追記・copyを純粋なletと不変リストへ移し、限定した変換先で意味を保存する。Release や Rust への接続はない。

四ファイルは `import Std` だけの独立したモデルである。ハンドラ・継続・タスク・遅延・再帰・GC・UTF-8・容量・取り消しを含まない。元の成功記録を読み、定義と証明の対象を確かめた。この作業で再検査はしていない。

### 4.2 Release で追加が必要な規則

局所の操作を通常の State の集合から後で引く方法は採らない。表層では既存のΔで専用操作を認識し、通常の引数式の効果 ε はそのまま残す。内部で局所操作の印を別に集計するか、Δで許された専用規則そのものに局所性を持たせる。外側の通常の Eff に LocalState という消去対象を混ぜる必要はない。これはエフェクトの計算を省くことではなく、局所操作の型付けと実行に別の根拠を与える案である。

コアでは、専用の束縛・追記・copy・長さと、通常値へ変換できない局所識別子を追加する案を第一候補とする。通常の Ty・Eff に Builder や領域変数を加えない。通常の `.loc` を構築器の値として使い回して、任意の関数やセルへ渡せる入口を作らない。内部の型付けには局所文脈・局所ストアとの対応が必要になる。公開の HasTypeC は空の局所文脈から始める入口とし、実行中は状態の型付けの中で対応する証拠を保持する設計を検討する。

これは定義の配置まで決まった案ではない。別の局所ストアを State に持たせる場合は全状態の引数が変わる。既存の Store に専用 Cell を加える場合は StoreTy と CellOk の場合が増える。後者は開始状態の形を保ちやすいため先に検討するが、局所識別子を通常値から参照できないこと、関数呼び出しごとに新しく確保すること、型・値の置換が境界を保つことを定義で示す必要がある。

| 現在の接続点 | 必要な変更・証明義務 |
|---|---|
| [Release/Syntax.lean](../../../formal/Benitoite/Release/Syntax.lean):129、154、Subst.lean、Typing.lean | 専用コア構成、局所識別子の束縛・置換、通常値との分離。型付けの七判断と既存の名前の付け替え・型代入・正則性の証明を拡張する |
| [Release/Semantics.lean](../../../formal/Benitoite/Release/Semantics.lean):38、50、186 | 局所バッファの抽象的な内容と専用の遷移を定義する。通常の E_RefNew/Get/Set/Update は State を要求するまま保つ。局所の一歩は IO/release の Event を出さない |
| 同ファイル:262、268、274 | E_Op・E_OpFail・E_OpPrim は残りの枠を Cell.cont に保存する。ハンドラ節へΔを渡さないことだけでは、その保存継続から参照する局所バッファの生存を説明できない |
| 同ファイル:288〜310、70、546 | 再開・破棄・escape・error・exit と `releases`、`K_Drop` の整合。通常のリソース解放は State と release 事象を残す。バッファのメモリ回収を同じ release 事象にしない |
| 同ファイル:520、564、580、618 | ContTy・CellOk・StoreOk・StateTy に局所ストアの対応を接続し、保存継続にも保存する。局所識別子だけを持った型なしの実行状態を許さない |
| Surface/BuilderLower・Lemmas/Typing・CheckCompute系・Exchange | Reference への展開を専用コアへ替え、検査成功から新規則を導く。参照先の契約と交換表現も替える |

継続の保存・破棄は次の二つに分けて扱う。保存した枠は、通常値の捕捉が禁止されていても後続の専用操作を含む。捕捉時にバッファを解放してはならない。一方、再開しない節が継続を捨てた後は、その枠だけから到達できたバッファを保持し続ける必要はない。再開は現行の一回だけの規則を保ち、Koka の複数回再開のための状態コピーを導入しない。

形式モデルのストアは有限性と型の整合を扱い、物理 GC をモデル化しない。局所の内容を論理ストアに残す案と、無効化した専用セルを残す案を比べる。現在のストア拡張の補題に反して、解放時に場所と型を単純に削除する案を先に固定しない。物理メモリの即時返却を、進行・保存の結論へ付け足す必要はない。

局所操作の隔離については、型付けの成功を前提にした任意の実行の有限接頭辞で、通常の共有セルへ局所操作が書かないことを示す補題を追加する。通常引数・ハンドラ節・通常の呼び出しが State を持つ場合は、その通常操作による変更を許す。List[Reference[T]] の copy が要素の共有セルを切り離すことは主張しない。生存している局所参照の有効性、通常値・捕捉環境への非出現、copy の内容の安定性を、別々の補題にする。

### 4.3 主定理の言明を保てるか

| 対象と現在の位置 | 保つ方針と成立条件 |
|---|---|
| 進行・保存：Release/Theorems.lean:35、42 | `StateTy → Final または Step` と、一歩後の StateTy を保つ。局所の実行状態を含む StateTy・Step の定義と補題は変える。呼び出しごとの隔離を外部仮定にしない |
| エフェクト健全性：同:52 | 空のエフェクトなら IO/release の事象と未処理操作がないという結論を保つ。局所操作を無事象にしても、共有セルを変えないことはこの定理だけからは出ないため、前節の補題を追加する |
| 性質1：Surface/Theorems.lean:19 | WellFormed・WellTyped・EffectsOk の結論を保つ。空の効果の専用コア操作にも型が付くようにする。今の State 付き脱糖の証明は使えない |
| 表層のエフェクト健全性：同:31 | `HasMain Eff.empty` と結論を保つ。局所構築器だけを使う main もこの前提を満たせるようにし、通常の State や IO を隠さない |
| 検査器の健全性：Surface/CheckSound.lean:9以降、プログラム全体 | 公開11件とプログラム全体の外側の言明を保つ。内部のΔ・支持・型付けの帰納を拡張する。検査が返した「局所」という Bool を未証明の前提にしない |
| 網羅性の判定の健全性：Release/Coverage.lean、Lemmas/CoverageRuntime.lean | Builder を通常の Ty とパターンの対象へ追加しないため、有用性から網羅性への結論を保つ見込みである。Comp の場合の追加は実行との接続の補題に反映する。TODO-191/200の変更とは別に確認する |

以上は「型・状態の定義も同一」という意味ではない。公理や Builtins.Assumptions に「局所状態は安全」と足さず、定義の中へ証明できない隔離条件を隠して旧プログラムを除外しないことも受け入れ条件にする。旧規則の導出から新規則の導出への対応と、新しい構築器を含むプログラムの検査・脱糖・実行までの接続をレビューする。主定理の文章だけが同じでも、この対応を欠けば完了にしない。

この条件を満たす証明が通らず、主定理の前提追加・結論の弱化・新公理が必要になった時点で、依存する実装へ進まず設計者へ戻す。今の調査だけでその必要性が確定したわけではない。

### 4.4 証明が閉じない場合の代案

| 案 | 得られる保証・費用と判断 |
|---|---|
| 0.0.9 の State 付き Reference 展開を保つ | 既存の表層・脱糖と Release の保証を保てる。専用バッファと State 除去は未完了になる。最も確実な戻り先として推す |
| State を残した専用バッファ | 公開の効果を変える証明は要らないが、新実行表現と既存の抽象的な内容の対応、GC・継続の検査は必要。Reference 展開と同じ保証を持つ最適化として何を示すかを再計画する |
| State は契約に残し、局所と判定した分だけ main の表示から外す | 型の保証は0.0.9のままで、純粋な関数としては使えない。権限の説明を簡略化する別の仕様になる。現在の効果集合は同じ State の出どころを保持しないので、単純な集合の差では実現できず、説明用の由来の追跡が要る。実行時の許可判定の入力には使わない |
| 不変値の受け渡しへの純粋な脱糖 | Release を変えずに済む余地がある。ただしハンドラ・分岐・returnを含む本体の状態受け渡しの変換と性質1を改めて証明し、専用可変バッファへの最適化の対応も別に示す。小モデルのLoweringだけでは足りない |

表示だけの案を採っても、通常の Reference やリソース解放を「局所」として省いてよいことにはならない。「表示にないので実行時に禁止される」「State のない関数である」という説明はできない。静的なエフェクトと将来の実行時権限を区別する00-01の方針を保つ。

## 5. 他言語の一次資料から分かること

すべて2026-10-19に確認した。以下は API・仕様の前例であり、Benitoite の証明が得られるという根拠ではない。性能の数値や各処理系の最新の内部最適化までは調査していない。

| 言語・資料 | 確認できた事実と今回への示唆 |
|---|---|
| Haskell：[GHC 9.10.3 の Control.Monad.ST](https://downloads.haskell.org/ghc/9.10.3/docs/libraries/base-4.20.2.0-f6da/Control-Monad-ST.html) | `runST :: (forall s. ST s a) -> a`。内部の状態を外部から利用できないようにする全称量化を持つ。ランク2の型（rank-2 type）の引数で局所状態を閉じる先例である。Benitoite の既存の捕捉・受け渡し禁止より広い使い方を得るために、同じ型機構をこの版へ導入する必要はない |
| Koka：[言語の公式文書3.2.4・3.2.5](https://koka-lang.github.io/koka/doc/book.html#sec-var) | `var` は local variable、一般の参照セルは `ref<h,a>` として区別する。局所変数は字句的な範囲を越えられず、内部の状態ハンドラは複数回再開も扱う。参照セルの `st<h>` は alloc/read/write の組で、heap型hについて多相な計算へrunを適用して閉じる。Benitoite の単一の State 全体を削る根拠にはしない |
| OCaml：[5.5 Buffer](https://ocaml.org/manual/5.5/api/Buffer.html) | 長さと容量を区別し、容量を指数的に増やす。contents/to_bytes は写しを返す。clear は領域を保持し、reset は初期領域へ戻す。局所エフェクトの証明と、容量・取り出しの API の選択を分けて考えられる |
| Rust：[Vec](https://doc.rust-lang.org/std/vec/struct.Vec.html)、[String](https://doc.rust-lang.org/std/string/struct.String.html) | Vec は push の償却定数時間（amortized constant time）を保証するが特定の増加率を保証しない。reserve は余分に確保し得る。try_reserve/try_reserve_exact は容量あふれ・確保失敗を Result で返す。String の容量はバイト単位で、同様の予約APIがある。「Rust は常に2倍」を言語の契約にしない |
| Java：[Java SE 25 StringBuilder](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/StringBuilder.html#ensureCapacity(int)) | ensureCapacity は必要容量と旧容量の2倍+2の大きい方を使う。toString の結果は後の変更に影響されない。容量の単位をUTF-8のバイト数へそのまま移さない |
| Scala：[2.13.16 の実装](https://github.com/scala/scala/blob/v2.13.16/src/library/scala/collection/mutable/StringBuilder.scala) | Java の StringBuilder へ append・ensureCapacity を委ね、result は underlying.toString を返す。clear は setLength(0) を使う。独立した倍率の規則をScalaから読み取らない |

Koka の局所変数を捕捉する反復を、そのままBenitoiteへ認める提案はしない。Kokaは局所変数と状態ハンドラの型規則を持つ。今回そこまで広げると、捕捉境界と継続の証明が追加になる。

## 6. 専用バッファと現在のヒープ

### 6.1 表現の比較

| 案 | 必要な仕事と評価 |
|---|---|
| 既存 Host の私有データ（推す案） | `HostData: Trace`、`Vec<Slot>`、host_mut・SlotOps・heap_bytesを使う。タスクや継続にも使う既存の追跡と容量計上へ接続できる。通常の値としての公開を型・IRの入口で防ぐ必要は残る |
| ObjKind に Builder 等を加える | 対象の配置・確保・走査・破棄・検証器・計数・二つの回収方式の全分岐を増やす。Hostの費用が実測で支配的な場合に再検討する。新しい種類だけでは局所性の保証を得られない |
| Opaque に可変の Rust 値を入れる | 採らない。OpaqueData は作成後の変更を認めず、言語値の Slot を含められない。ListBuilderの要素と容量更新に合わない |
| Cell に不変値を保存し続ける | 現行の意味は保ちやすいが、多数の小断片の追記の全体コピーを減らす目的に届かない。戻り先に残す |

根拠は [heap/value.rs](../../../crates/benitoite/src/runtime/heap/value.rs):259、295、309 の ObjKind/OpaqueData/HostData、[heap/ctx.rs](../../../crates/benitoite/src/runtime/heap/ctx.rs):572、579 の alloc_host/host_mut、[heap/core.rs](../../../crates/benitoite/src/runtime/heap/core.rs):1017 の with_host_mut である。後者は変更前後の heap_bytes を比べ、:1038 の recharge_host で実容量の増減を記録する。専用バッファのデータ構造はヒープ外の安全なRustで書けるが、Slotの生存を無制約にしてよいわけではない。

[builtins/iface.rs](../../../crates/benitoite/src/builtins/iface.rs):434 の PureCtx はValueCtxだけを持ち、host_mutを呼べない。外側の効果が空だからという理由で、一般の純粋な組み込み関数に可変なヒープへの入口を追加しない。専用コア操作を、局所の対象だけに作用するIR・バイトコード・VMの命令へつなぐ案を推す。命令の読み手、検証器、自由変数と生存判定、参照評価器、交換器を同じ契約へ移す。組み込みのCapabilityを全体へ広げる案は、別の型・実装境界の変更として再判断する。

### 6.2 容量・上限・確保失敗

new は容量0とし、最初の追記で確保する案を推す。必要長をN、旧容量をCとし、足りなければ `max(N, min(上限, max(初回の小容量, 2*C)))` を要求容量の候補とする。初回の小容量は文字列・Bytesで64バイト、Listで8要素を測定の仮置きとし、公開仕様の数値にはしない。掛け算・足し算は checked 操作を使う。要求容量の決定後に try_reserve_exact を使う場合も、確保器が返す実容量が要求値と一致するとは約束しない。論理長の上限と実容量の計上を区別する。

[runtime/mod.rs](../../../crates/benitoite/src/runtime/mod.rs):18 の文字列・Bytesの上限は1,073,741,824バイト、:20 のListの上限は16,777,216要素である。[heap/build.rs](../../../crates/benitoite/src/runtime/heap/build.rs):8 の CheckedLen と :48 の StrBuf は先に長さを検査する既存の入口である。これを専用バッファにも通す。

追記は、通常引数の評価、必要長の全計算、上限と表現可能性の検査、容量の確保、内容の追加の順に行う。String.appendAllはすべての断片のUTF-8バイト長を加算してから更新する。List.appendAllは要素数、Bytes.appendAllはバイト数を使う。`len + additional`、容量の倍増、`capacity * size_of::<Slot>()`、u64/usize/u32の変換をそれぞれ検査し、あふれた数で確保へ進まない。ListをBytesの中間表現に使って、小さい要素数上限を誤って課さない。

論理長の超過は現行の `Stop::Resource(ValueTooLarge)` を保ち、部分的に追加しない。上限内でもホストの確保失敗は起き得る。現在の ResourceError に汎用の確保失敗の項目はなく、内部の alloc.rs:34 は handle_alloc_error を使う。try_reserveの失敗をValueTooLargeやInternalへ偽装しない。回復可能な停止理由を新設するか、既存のホストOOM方針に合わせるかを詳しい設計で決める（問いB10）。後者ではプロセス異常終了時まで言語の後始末を保証できない。

Stringには有効なStringだけを加え、UTF-8の不変条件を保つ。BytesからStringへの無検査変換や、バッファの中身を直接公開する入口は加えない。大きいappendAll/copyで安全点へ戻れない時間は増え得る。初版は一操作を原子的に完了し、処理の途中でGCや利用者コールバックを呼ばない案とする。中断を途中へ入れる必要があれば、進捗・根・未公開の結果をVMへ保存する別作業として再計画する。

### 6.3 根・書き込みの障壁・解放

バッファ本体を指す値は、実行中のレジスタ・保存枠・RootStackのいずれかに保存する。Listの要素を `Value<'epoch>` のままVecへ置かず、SlotOpsで作ったSlotにする。Traceは初期化済みの全要素を辿る。容量だけの未初期化領域は辿らない。書き換えは host_mut の中だけで行い、要素の追加・交換・破棄はSlotOpsへ渡す。

既存の根と破棄は [heap/slot.rs](../../../crates/benitoite/src/runtime/heap/slot.rs):38、131、[heap/trace.rs](../../../crates/benitoite/src/runtime/heap/trace.rs):6、17、[heap/ctx.rs](../../../crates/benitoite/src/runtime/heap/ctx.rs):592 が定める。GCの根の走査と、参照の所有を手放すDiscardは別である。VecをdropしただけでSlotOpsの手放し処理を済ませたと数えない。Hostの内部の子の解放と根のSlotの解放を重ねて数えない。

| 制御の状況 | 推す扱いと確かめる点 |
|---|---|
| 普通の戻り・早期return | 戻り値を根へ保存した後、不要なレジスタ・枠のSlotを通常の手順で手放す。バッファは到達不能になれば回収対象。関数を抜けたという理由だけで共有中のバッファを強制破壊しない |
| 操作の捕捉・再開 | 保存区画のレジスタと必要な値から同じバッファへ到達できるようにする。再開時に古い生存期間のValueを再使用せず読み直す。引数評価を再実行せず、再開後の現在の内容に一度追記する |
| resumeしない節・型付きFail | 捨てる区画の参照を手放す。外側の未破棄の枠から同じバッファを使う場合は残す。Fail節が外側の構築器を直接捕捉できるようにはしない |
| Stop・exit・タスクの取り消し・中断 | 既存のunwindで区画を片付ける。バッファ自体にIOを伴う解放を持たせない。withのリソース解放の順序・回数は保つ。停止要求から一操作の終了までの待ち時間も確認する |
| 取り出した値が残る | バッファへの可変な別名を返さない。後の追加でcopyの結果が変化しない。リストの要素のReferenceは共有する |

実装の接続点は [vm/handler.rs](../../../crates/benitoite/src/vm/handler.rs):33 の ContState、[vm/frame.rs](../../../crates/benitoite/src/vm/frame.rs):163 の Trace と :200 のDiscard、[vm/dispatch/handlers.rs](../../../crates/benitoite/src/vm/dispatch/handlers.rs):673 の clear_captured、:701 のresume、:822 のunwind_top、[vm/unwind.rs](../../../crates/benitoite/src/vm/unwind.rs):278 のunwind_dropである。

AGENTS.md「unsafe の書き方」により、unsafeを書けるのは `runtime/heap/core.rs` と `core/` 直下だけである。Hostを使う私有のバッファ、VM、組み込み関数、参照インタプリタには書かない。新対象種別を選ぶ場合も、内部層の各不変条件と一操作ごとのSAFETYコメントが必要になる。バッファの高速化を理由に、許可の場所を増やす案は採らない。

### 6.4 copyの費用と参照インタプリタ

初版のcopyは、文字列・Bytesを通常の不変値へ写し、Listは要素のSlotを通常の永続ベクタへ移し替える案を推す。バッファを消費しない。要素の深い複製はしない。現在のcopyが不変値の共有で安いことに比べ、専用バッファではcopyの時間と一時的なメモリが増える。copy-on-writeや消費するfinishは、追記だけの高速化と別の所有規則になるため、今回の第一候補に含めない。

[refinterp/value.rs](../../../crates/benitoite/src/refinterp/value.rs):17 は独自のValueと平坦なListを持ち、セル・遅延・継続は独自のストアで扱う。[refinterp/convert.rs](../../../crates/benitoite/src/refinterp/convert.rs):1 の橋渡しは呼び出しごとの区間で変換する。構築器のコア操作も参照評価器自身のストアと不変列更新で評価し、VMの可変バッファを共用しない案を推す。物理的に同じ実装を比べても、意味の誤りを見つける独立性を得られないためである。

差分の照合はcopyの内容・引数の評価順と回数・複数構築器・分岐・早期return・capture/resume/drop・失敗時点を対象にする。GC・容量・回収量・取り消し・タスクで参照評価器が未対応の範囲は、VMの局所検査で独立に確かめる。TODO-222の共有構造の変換も同版の対象であるため、交換する通常値の同一性の扱いを共有契約として先に決める。専用バッファのSlotを橋渡しして、TODO-222の修正に依存する形式化の根拠を作らない。

## 7. builders 族による測定の案

### 7.1 現在の入力と直す箇所

[scenarios/builders.py](../../../tools/bench/compare/scenarios/builders.py):5 のbuilder_sourceは構築器を捕捉できないため、追記呼び出しをソースに展開する。nは断片の数、断片は文字列の`ab`、整数二つ、バイト二つである。通常の格子はn=0/8/128/1024、途中のcopyの指定は0/1/4。三種類にbuilder・builder-all・concatenate、Stringにjoin、Listにfoldがある。join/foldは途中copyを持たない。short_pointはn=8・copy指定0、quickはn=0/4だけである。

docs/todo の TODO-262 の修正は、requiresを構築器の手法の点だけに付けることである。実装時は次を同じ修正として行う必要がある。

1. builder/builder-allだけに`requires=('builders',)`を付け、既存操作と空mainのcontrolから外す。
2. builder_sourceがすべての手法へ付けている構築器のimportも、builder系だけへ移す。requiresだけを外しても、構築器のない旧版はimportで失敗する。
3. Stateを残す共通のmainは0.0.9/0.0.10比較の互換入力として使えるが、構築器を使わない比較点で不要なら除く。比較状態には同じ入力を渡す。新しい純粋な契約の正しさは性能入力のusesから推定しない。

既存のbuilder-allは一回の大きいappendAllではない。n回それぞれ短いリストまたはBytesを渡す。用意済みの全断片を一回で追加する点を別に足す。String.joinは一括操作、List.foldは小断片の連結の反復であり、一括構築と同じ分類にしない。

### 7.2 比較する計算と記録

| 目的 | 既存族に加える・保持する点 | 比較と解釈 |
|---|---|---|
| 小断片の多数追記 | n=128/1024の単一追記、短いappendAllの反復。必要ならnを増やす前に深さ上限を確認 | 0.0.9の同じbuilder、同版のString `+`・List.append/concatenate・Bytes.concatenateと比べる。ソースを展開した場合の解析・検査費用も記録する |
| 短い構築 | n=0/8。1/4も必要ならtargetsに追加 | new・小容量の初回確保・最後のcopyの固定費を比べる |
| 一括構築 | preparedなList[String]のString.joinと一回appendAll、List[T]の既存値をそのまま使う場合と一回appendAll+copy、Bytes.concatenateと一回appendAll+copy | 「完成済みの入力をそのまま使う」が最適な場合に構築器を推す根拠を作らない。準備の有無を揃えた点を別々に持つ |
| copy | 同じn・追記量で最後だけ、途中1回、途中4回。追記なしで同じバッファを複数回copyする点も追加 | copy回数ごとの全体時間・確保量・ピークを示す。既存不変値の参照の取得は安い基準だが、新実装がそれと同じ費用になるとは約束しない |

今の期待値は長さだけを出し、途中でConsoleへ出力する。内容の安定性や順序の誤りは長さだけでは検出できない。異なる断片を使い、取り出した値を後の追記の後まで保持して、内容から独立に計算した検査値を最後に一度出す系列を加える。Consoleの反復費用とcopyの費用を混ぜない。既存の長さの系列はそのまま意味の違う基準として残してよい。変更時にはPythonの生成器の決定性と誤出力の拒否を自己検査する。

現在の計時はCLIの起動・検査・実行・終了の全体である。[timing_probe.rs](../../../tools/bench/compare/timing_probe.rs):1 はload_parse/resolve/typeck/reparseだけを測り、VMの実行区間は測らない。空mainの差し引きだけでは、展開したソースの検査時間の差は消えない。runtimeの目標を判定する場合は、builders族内で普通の補助関数を動的な回数だけ呼び、関数内部に構築器を宣言し結果の検査値を集計する。構築器を引数やlambdaへ渡さず、入力ソースの長さを固定したまま仕事量を増やせる。repeats引数は現在のbuilders生成で使われていないので、この使い方を明示して接続する。

一回の構築の中のn回の追記は引き続きソースへの展開になるため、異なるnのCLI時間だけから追記の計算量を断定しない。同じソースの反復数Rと2Rの差を使う場合も、両方のばらつきが差を上回れば判定不能にする。VM実行区間が取得できていないことを記録し、公開APIの計時補助を拡張する必要が出てもcompareの中に置く。改造専用の別ランナーは作らない。

時間は既定構成、確保はalloc-statsの別実行、RSSも別実行にする。Hostの容量増加を含む`allocated_bytes`と`peak_heap_bytes`を読む。対象のallocationsはRustのVecの再確保回数そのものではない。実測出力にない回数は未取得とし、確保回数の減少を容量の増加回数の減少と読み替えない。原因の見立てはCPUプロファイルで確かめる。

### 7.3 段と受け入れ目標の提案

shortは全族の代表点を2状態・5標本で比較する。既定の幅`max(旧時間の10%, 2 ms)`は調査の合図であり、この幅内を性能目標の達成と呼ばない。短い入力や片側だけの機能は判定不能を残す。全族で15分以内という道具の条件を守る。

構築器の高速化を約束するため、受け入れはtargets・10標本以上を推す。基準は0.0.9の開始版、候補は0.0.10の完全コミットIDに固定する。以下は設計者へ尋ねる数値案であり、現在の測定値から得た閾値ではない。

| 対象 | 推す目標案 |
|---|---|
| 多数の小断片、n=1024、途中copyなし | 三種類それぞれで反復に対する時間増分が0.0.9の同じbuilderの1/2以下。String/Bytesのallocated_bytesも1/2以下、Listは旧版以下。永続ベクタの既存操作との比も全て示す |
| 短い構築、n=0/8 | CLI時間の増加が`max(10%, 2 ms)`以内。反復で識別できる構築一回分の増加も別に示し、起動時間で隠して「同速」としない |
| 一回appendAll+copyと一括の既存操作 | 反復の時間増分が既存操作の2倍以内を目安として相談する。完成済みListを直接返すだけの基準にはこの倍率を課さず、追加するコピー量を報告する |
| 途中copyを4回行うn=1024 | 時間・allocated_bytes・ピークの比を報告する観察点にする。旧版の共有copyと1倍以内を要求しない。ここが主用途なら、copy-on-writeを含む別の選択をB7で判断する |

反復で十分な差が得られない場合は判定不能であり、入力や標本の変更は理由とともに計画へ戻す。目標未達を「観察点だった」と事後に変更しない。nの伸び、短いappendAll、一回の一括追加、copyだけの点も残し、最速の一系列だけで三種類の成功としない。

本測定前には [benchmarkスキル](../../../.claude/skills/benchmark/SKILL.md) に従って静かな計算機・見込み時間・開始の了承を確認する。quickで出力と全経路を確かめ、estimate-fromで全体・族ごとの時間を示してから進む。現時点では入力の修正も試走もしておらず、実行時間の校正値はない。shortは15分以内、buildersだけのtargetsは初回ビルドを除いて20〜60分を暫定の予定枠とするが、10標本・反復数・copy保持量で変わるため開始前の再見積もりを必須とする。0.0.9の全targetsの約1時間50分は今回の見積もりへ流用しない。

## 8. 07-04 の内外と検査への引き継ぎ

| 変更 | 判定と必要な対応 |
|---|---|
| 局所状態を外側のエフェクトに残さない規則、表層のΔ、専用コア、継続・破棄 | 形式化の内側。版に含むLeanの変更を一段へまとめ、処理系より先に定義・証明・01-12の写し・07-04の対応表を揃える |
| Hostの物理配置・容量・GC・障壁・OOM・取消・中断 | 現在の主定理の対象外。抽象的な局所内容と型・実行規則は内側。物理メモリと並行な実行器の保証を主定理に追加したとは説明せず、07-04の対象外の記述と実装検査を具体化する |
| 専用名のModuleIdへの解決、診断位置、CLI表示、性能 | 外側。Rustと交換・独立入力・実CLI・測定で確認する |

Lean段では既定のlake buildがsorryなしで通ることと、定義・言明・仮定のレビューが処理系へ進む条件である。今回のTODO-192の脱糖、191/200の網羅性、206の組み込み効果など、同版の軽い変更もLean段へ集める。ただし、それらの調査をこのS1で済ませたとはしない。二つ目の重い変更が必要と判明したら版の組み方へ戻す。

今後のplan.mdの「検査の割り当て」には、Rust各作業のwork、ヒープのdoc_default・局所heap-verify/gc-stressと必要なcheck-heap、RustとLeanの接続を閉じるstage、改造全体のchange、公開候補のreleaseを置く。形式化の全比較は接続時と最後の関係状態で独立のcheck-formal.shを行うか、07-03の条件を満たす結果を引用する。formal_buildだけで全比較を完了扱いしない。

gc-stressには、同じ契約を確かめる小さい入力と、既定構成の大きさで確かめる長い入力を計画時に分ける。深い再帰・長いリストを全構成へ同じ大きさで流さない。既存の期待値や上限を失敗後に緩める手順にはしない。テストの追加・変更時はtest-auditの関門を適用する。

## 9. 規模の見込みの再点検

開始版の `.lean` を読み、行頭のtheorem宣言（privateを含む）を字句的に数えた。`formal/Benitoite/` は176ファイル・2,030宣言である。試作時に比べ、表層のΔ・捕捉禁止は実装済みになったが、型付きFailと検査器の読者も増えている。

| 現在の直接の点検候補 | 既存ファイル数 | 既存のtheorem宣言数 |
|---|---:|---:|
| ReleaseのSyntax/Subst/SubstEnv/WellFormed/Typing | 5 | 15 |
| Semantics・Theoremsと継続・ストア・保存・進行・StepSound・EffectSound・Failの補題12ファイル | 14 | 131 |
| Surface配下のファイル名にBuilderを含むもの | 12 | 147 |
| SurfaceのSyntax/Typing/Desugar/Check/CheckSound/Theorems、LemmasのTyping/Scoped/Invariants | 9 | 103 |
| Exchange直下 | 5 | 0 |
| 合計（重複なし） | 45 | 396 |

機械の14ファイルのうち、補題はContLemmas・StoreLemmas・PresBase・PresHelpers・PresMain・Preservation・PresFailure・FailureBase・FailureCont・Progress・StepSound・EffectSoundである。これ以外に名前の付け替え・値と型の置換・正則性・検査器内部・交換の実行ファイルがある。識別子HasTypeCは25ファイル、ContTyは14、BuilderCtxは18に現れる。Release.Syntax・Release.Semantics・Surface.BuilderSyntaxからimportを逆に辿ると135ファイルになる。これは再ビルドの候補であり、135ファイルの編集が必要という意味ではない。

45ファイル・396宣言は点検対象の実数であり、新規や変更の補題数ではない。試作の30〜60ファイル・80〜220件は正式モデルへの差分を作った実測ではなかった。今回も実際の差分なしに厳密化はできないが、通常型を変えない局所文脈案について、**既存と新規を合わせ45〜70ファイル、定義・補題の追加または変更140〜300件**を未実測の見込みとする。既存Δの再利用による減少より、Releaseの全構成子を読む補題とFail/継続の接続の増加を大きく見た幅である。領域多相や一般Referenceへ広げた場合の見込みはこの幅に含めない。

TODO-248と測定修正だけを対象とした作業の分け方は次のとおりである。時間は能動作業の未実測の見込みで、計算機のビルド待ち・レビュー待ち・本測定は別に数える。版全体15件の見込みではない。

| 分野 | 作業の区切り | 作業数 | 時間の幅 |
|---|---|---:|---:|
| Lean | 専用構文と局所型付け、置換と隔離、局所ストアと一歩、継続の捕捉・再開、破棄とFail/return/error/exit、進行・保存・効果、表層脱糖、検査器、交換と写しの接続 | 9〜12 | 30〜65時間 |
| 処理系 | 型・IRの接続、独立IR検査とコード生成、Hostバッファ、三種類の操作、根と継続、停止・取消、参照評価器、交換器、診断・移行・Skill | 8〜12 | 25〜50時間 |
| 測定 | requires/importと自己検査、入力・反復と目標、試走と本測定の集約 | 2〜3 | 4〜8時間 |
| 合計 | 設計の確定後の範囲 | 19〜27 | 59〜123時間 |

ビルドと局所・全件検査、レビューと修正、測定の待ちを含む予定枠は約70〜150時間とする。初回の局所型付け・機械・継続の設計が固まれば再見積もりする。各区切りの見込みの2倍になる前、または主定理・公理・Builtins.Assumptionsの条件変更が必要と分かった時点で設計者へ戻す。証明を弱めたり、Stateだけを消したRust実装へ先行したりして時間を合わせない。

## 10. S1 の確認記録

開始版とブランチ、変更前に差分がないことを確認した。調査に使う資料は読み取りだけとし、このディレクトリのtodo-items.mdとstudyの2文書だけを書く。実装・現行設計・テスト・formal/・docs/todo/は変更しない。コミット、Lean/Cargoのビルド、性能測定は行わない。

作業末に文書のリンク・パス・主な行番号、TODO本文の写し、問いの番号、非公開資料へのリンクがないことを照合した。TODO-248の本文は原文と一致し、TODO-262の段落も原文のまま写した。B1〜B16の連番と3ファイルの範囲を確認した。

| コマンド | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| `scripts/check.sh --level work --base c31e64b03d2810343e1779926bea4ebc958b6164 --dry-run` | 0 | 0.062秒。変更3ファイル、文書だけのため実行対象なし |
| `scripts/check.sh --level work --base c31e64b03d2810343e1779926bea4ebc958b6164` | 0 | 0.061秒。同じ選択を一度実行し成功。Rust・Leanの検査を実行したという意味ではない |

計画からの逸脱はない。計画・共通依頼文の作成、問いの回答の記録、処理系の実装、Leanと物理バッファの検証、性能の受け入れは後の作業へ残す。この確認結果をそれらの成功へ引用しない。
