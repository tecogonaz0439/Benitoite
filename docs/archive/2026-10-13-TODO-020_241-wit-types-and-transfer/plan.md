# 実装プラン: WIT に合わせた型と外部の関数の受け渡し（フェーズ 3a）

2026-10-13。TODO-020・241 を扱う。[詳細設計 C](study/C-design.md) と [判断 Q1〜Q15・R1〜R23](decisions.md) を実装する。これは実装前の計画である。凍結した型の追加は decisions.md の Q13 と、コアの `Const` の追加を認めた Q15 の範囲で行う。今回の設計作業では処理系・設計書を変更せず、この計画のコマンドも実行しない。

## どの作業にも共通する決まり

- P1 から順に Codex が一作業ずつ実装する。Opus のレビューは作業ごとではなく、まとまり（P1〜P4、P5〜P10、P11〜P14、P15〜P18、P19〜P23、P24〜P29a、P30〜P36a、P37〜P40a。枝番も同じまとまりに含める）ごとに行い（`decisions.md` の Q14）、その指摘は後の直しの作業（Z1・Z2…）で直す。作業ごとの完了の条件の確かめは毎回行い、通れば取り込んで次へ進む。並列の実装は行わない。作業の見込みは、依存のビルドが済んだ状態で実装・短い検査・修正を含む 30〜55 分である。55 分までに完了の見込みが立たなければ、未完了を報告して残りを分割し、完了したと扱わない。
- 各作業は最後にコンパイルでき、既存の動作を保つ。追加した表現は読み込み・値の構築・演算の経路が揃うまで利用者向けの入口へ接続しない。新しい字句を途中で診断する場合は理由を示す実装済みの診断を使い、todo!()・unimplemented!()・仮の計算結果を残さない。
- 型・欄・列挙子の追加は Q13・Q15 の範囲だけとし、既存の関数のシグネチャ・型の番号・組み込み関数の番号を変えない。非公開の補助の型と関数は追加できる。unsafe は追加しない。Value<'epoch> を Store・長生きする作業列・作業用のスレッドへ保存しない。
- 新しいテストは test-audit の作成時の関門を通し、観察可能な規則と現実的な退行を記録する。一つの規則の主なテストを適した境界に置き、同じ期待値を各層で繰り返さない。ABI の試験は、生成器と復号器の相互の往復だけでなく、手書きのゲストと独立した期待値を使う。
- 新しいテスト一件は 10 秒以内とする。上限の試験では小さな指定値を使い、大量の要素・長いループ・巨大なゲストでしか分からない試験をこの作業に加えない。指定したフィルタで対象のテストが実際に一件以上走ったことも確認する。
- 検査の前に走らせるコマンドと見込みの時間を設計者へ知らせる。各作業は以下の C0 と関係する短い検査だけを走らせる。scripts/check.sh・check-heap.sh・check-formal.sh・--full・本測定は各 P 作業で走らせない。
- 診断は diag::codes と各層の text にまとめる。新しい番号は該当区分の末尾とし、既存の型・出力は Integer・Float・Byte を主に表示する。新しいゴールデンの名前は width-・wit-・adapter- など振る舞いを示す名前とし、P の ID を付けない。
- 01-12 の写しと 07-04 の対応表は形式化の作業で先に更新する。ほかの設計書・言語リファレンス・CHANGELOG のまとまった更新は P37〜P39 で行い、途中の実装を提供済みの仕様として公表しない。構文・診断・標準ライブラリを変えた各作業でも gen_skill を実行し、その作業時点の生成物を変更に含める。仕様の記述を更新した後にも生成し直す。
- 変更するファイルの列挙は作業の責任の範囲を示す。既存の列挙型に選択肢を足す際の網羅的な照合は、呼び出し元・表示・交換用の表現なども同じ作業で更新する。新しい公開の差し込み口をテストのためだけに設けない。

### C0: 各作業に含める共通の完了条件

各作業の「完了の条件」の C0 は、次のコマンドを省略せず走らせるという意味である。Lean だけの作業にも現在の Rust のビルドが通ることを適用する。テストの全件実行を毎回加える意味ではない。

```sh
cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep
cargo fmt --all --check
```

構文・診断・標準ライブラリに触れる作業の S は次である。gen_skill の生成物は手で編集しない。

```sh
cargo run -q -p benitoite --example gen_skill
cargo test -p benitoite --test skill_docs
```

### G: VM と即値の変更ごとの短い性能の関門

P1 の前にオーケストレータが開始時の release の bench_run を target/p3a-gate/start/bench_run へ保存する。G のある作業では変更前の同じ構成のバイナリを before、後を after に保存し、次を実行する。P の番号は記録のファイル名の置き換え箇所である。

```sh
cargo build --release -p benitoite --example bench_run
python3 tools/bench/gate.py --version start=target/p3a-gate/start/bench_run --version before=target/p3a-gate/before/bench_run --version after=target/p3a-gate/after/bench_run --iterations 3 --output target/p3a-gate/Pn.json
```

fib・loop の出力が正しく、run と wall の中央値を報告する。開始前から 5% を超える遅れは同じ条件で再確認し、原因を直してから進む。短い測定は benchmark の性能の関門の手順に従う。本測定と実行ファイルの正式な比較は最後にオーケストレータが行う。

### H: ヒープと値の根の変更ごとの構成

H のある作業では、その作業のテストのフィルタで以下の構成も走らせる。FILTER は各作業で指定したモジュール名へ置き換える。回収の強制を理由にテストを対象外にしない。

```sh
cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep,gc-stress,heap-verify FILTER
```

必要な CLI のケースは同じ機能を指定した --test golden と BENITOITE_GOLDEN_FILTER で走らせる。ヒープに触れる作業は既定の構成でも対象のライブラリのテストを走らせる。

## 作業の依存

直列の順序は P1 → P2 → … → P28 → P28a → P29 → P29a → … → P36 → P36a → … → P38 → P38a → … → P40 → P40a である。作業の依存は、先行する実装と短い検査の完了を指す。まとまりの先頭だけは前のまとまりのレビューと、先へ進むために必要な指摘の修正も前提とする。P1・P2 の本文は着手時の記録として保ち、P2 の「P1 のレビュー完了」も Q14 のこの共通規則に読み替える。下表は追加の前提を示す。

| 作業 | 前提と内容 |
|---|---|
| P1〜P4 | 形式化と交換用の形式。処理系より先に行う |
| P5〜P8 | P1〜P4 と Q13・Q15 の回答。型の名前、字句、型検査、定数 |
| P9〜P18 | P5〜P8。即値、読み込み、数の演算と標準関数 |
| P19〜P23 | P9〜P18。数と合成の境界の照合・動的な変換 |
| P24〜P32（P28a・P29a を含む） | P19〜P23。配置、形式、生成と合成。利用者の経路の切り替えはまだ行わない |
| P33〜P36a | P24〜P32。内部の接続、上限、診断、寿命・形式化の確認を経て P36a で公開 |
| P37〜P39（P38a を含む） | P1〜P36a。設計書と利用者向けの文書を仕上げる |
| P40・P40a | P37〜P39。比較入力と記録の道具を分け、小さい入力の動作確認だけを行う |

## 作業 P1: Lean の基本型と定数

依存: 設計 C と Q1〜Q12。見込み: 30〜55 分。

### 目的

新しい七種を既存の形式化の定義へ加え、型の同一性を先に確定する。

### 変えるファイル

formal/Benitoite/Release/Syntax.lean・Typing.lean・BuiltinTable.lean・Coverage.lean と影響する Lemmas、docs/design/01-spec/01-12-core-calculus.md、07-quality/07-04-formal-semantics.md。

### 内容

C の 6 節どおり新しい BaseTy・Const を加え、型・等値・鍵・値の形を更新する。新しい整数に数学的な整数、Float32 に 32 bit の表現を使い、旧 Float と区別する。保存・進行などの網羅的な場合分けを更新し、01-12 と対応表の写しを合わせる。

### 完了の条件

性質 2・3 と制約の判定が新しい型で通り、Float32 は鍵でない。既存の Core の段階 A の定義は変更しない。 共通の C0 を含め、次を実行する。

```sh
(cd formal && lake build)
```

## 作業 P2: Lean の演算子と補間の型

依存: P1 のレビュー完了。見込み: 30〜55 分。

### 目的

同型の整数の算術と Float32、符号なしの負号の拒否を形式化する。

### 変えるファイル

formal/Benitoite/Surface/Syntax.lean・Typing.lean・CheckTools.lean・CheckTables.lean・Desugar.lean と関連する証明、Release/BuiltinTable.lean、01-12・07-04。

### 内容

二項の算術と単項の - の集合を分ける。div/mod の新しい整数、Float32 の /、比較、補間、組み込みの型の表の判定を広げる。演算子の脱糖は同型の組み込みの関数の呼び出しとし、性質 1・検査の健全性を維持する。

### 完了の条件

符号なしの - と Byte の算術が型付けされず、算術・補間の正しい形が証明に含まれる。 共通の C0 を含め、次を実行する。

```sh
(cd formal && lake build)
```

## 作業 P3: Lean の幅付きリテラルの脱糖

依存: P2 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

接尾辞の値と符号付きリテラルへの直接の負号を形式化する。

### 変えるファイル

formal/Benitoite/Surface/Syntax.lean・Typing.lean・Desugar.lean・Check.lean と Lemmas・CheckSound、Examples、01-12・07-04。

### 内容

新しいリテラルと直接の負号の表層の形を加える。一般の - と最小値の定数への脱糖を分け、負の符号なしの形を拒否する。性質 1 とその検査の健全性を修正し、新しい数のパターンを認めない。字句の解析自体は対象外に記す。

P1・P2 からの申し送りとして、`Release/Syntax.lean` の `Const.patternAllowed`・`Const.matches`、`Surface/CheckPatterns.lean` の新しい定数パターンの拒否を確認し、不足をこの作業で直す。`Exchange/Convert.lean::baseTy` と定数の変換など、P1 の列挙型の追加に伴う既存入力の互換・網羅性のビルド修正もここで確認する。漏れは P4 まで待たず、この作業の先頭で補う。型代入・正準形・網羅性を含む P1 の証明群の未完了も先に数える。55 分以内に収まらない残作業があれば P3a 等へ分け、P4 と処理系の着手を完了まで止める。申し送りのファイルと証明もこの作業の責任の範囲に含める。

### 完了の条件

新しいリテラルの型保存と負号の条件が通る。sorry・追加の axiom を使わず、丸め・あふれの実装まで証明したと扱わない。 共通の C0 を含め、次を実行する。

```sh
(cd formal && lake build)
```

## 作業 P4: Lean の交換用の形式

依存: P3 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

後の処理系の出力を、新しい型を含めて Lean が読めるようにする。

### 変えるファイル

formal/Benitoite/Exchange/Syntax.lean・Convert.lean・Builtins.lean・CheckInput.lean、DesugarDiff・SurfaceCheck の必要箇所。

### 内容

新しい型と定数、Float32 のビット、負号、組み込みの演算子の名前を交換用の形式へ加える。Integer・Float・Byte の旧名は同じ意味で読めるままとする。手で作った小さな JSON に新しい各種類を含め、変換の誤りを拒否できるようにする。

P1 の既存入力の互換・網羅性の申し送りは P3 で確認・修正済みであることを前提とし、この作業は新しい交換入力の受理を担当する。

### 完了の条件

現在の交換形式と新しい小さな入力の双方を受理し、不明の幅や負の符号なしをエラーにする。 共通の C0 を含め、次を実行する。

```sh
(cd formal && lake build desugarDiff builtinCheck surfaceCheckAll)
```

## 作業 P5: 組み込みの正の名前と別名

依存: P1〜P4 の実装・短い検査・まとまりのレビュー完了。見込み: 30〜55 分。

### 目的

型の ID と表示を保ち、幅付きの名前を導入する。

### 変えるファイル

src/types/builtin.rs・types/mod.rs、resolve/collect.rs と名前の参照、prelude/mod.rs・新しい幅と別名の stdlib/*.bnt、型の表示・標準ライブラリの生成の必要箇所（src は crates/benitoite/src の下）。

### 内容

C の 2.1・4 節を実装する。既存の表の番号はそのまま、七種を末尾へ追加し、正の名前・別名・表示名を別の内部の表で持つ。新しい標準モジュールを末尾に埋め込み、旧名の廃止警告は出さない。数の操作の公開は本体が揃ってから行う。

追加する `Integer8/Integer16/Integer32/Integer64/UnsignedInteger8/UnsignedInteger16/UnsignedInteger32/UnsignedInteger64/UnsignedInteger/Float32/Float64` の標準モジュールはすべて `prelude: true`・`unofficial: false` とする。型名とモジュール修飾名は import なしで使える。`resolve/collect.rs` の標準モジュール内の組み込み型の採集と `stdlib_names` の索引にも同じ ID を登録し、`Integer64.Integer64` 等の修飾名、import したモジュール、ルートの別名を一致させる。

### 完了の条件

Integer64= Integer、Float64=Float、UnsignedInteger8=Byte、UnsignedInteger=UnsignedInteger64 と、旧表示を名前解決・型検査の入口で確かめる。 共通の C0・S を含め、次を実行する。

```sh
cargo test -p benitoite --lib resolve::
cargo test -p benitoite --lib types::
```

## 作業 P6: 接尾辞の字句・構文・整形

依存: P5 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

Q6 の仮の接尾辞を正確に読み、整形で保つ。

### 変えるファイル

src/syntax/token.rs・lexer.rs・lexer/tests.rs・ast.rs・parser の該当箇所、cli/tools/formatter、typeck/generate.rs・text.rs、diag/codes.rs・syntax/text.rs、testdata/lexical と fmt の関連ケース。

### 内容

C の 3.1 の形を加える。数の塊全体で不正な接尾辞を診断し、s/u は基数付きの整数、f は十進の小数点か指数がある形だけにする。0xfff32 は十六進整数として保ち、m と接尾辞の重複を区別する。負号は字句に含めない。AST を辿る各処理も更新する。

P7〜P10 の段階的な接続に先立ち、新しい七種のリテラルに使う「数の実行経路が未接続」の静的な診断を型検査へ設ける。旧型に対応する s64/f64/u8 のリテラルは既存の値の経路に接続し、新しい型を仮の値へ変換しない。

### 完了の条件

合法な字句・不正な綴り・十六進の曖昧さを字句の入口で確かめ、整形の往復で接尾辞を保つ。 共通の C0・S を含め、次を実行する。

```sh
cargo test -p benitoite --lib syntax::
cargo test -p benitoite --test fmt_command
```

追加したケースを読む実行器も選ぶ。

```sh
BENITOITE_GOLDEN_FILTER=lexical cargo test -p benitoite --test golden
BENITOITE_GOLDEN_FILTER=fmt cargo test -p benitoite --test golden
```

## 作業 P7: 幅付き数の型検査

依存: P6 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

範囲と演算子の閉じた型の集合を型検査へ加える。

### 変えるファイル

src/types/mod.rs の ConstValue・TySet、typeck/infer.rs・generate.rs::literal/binary/unary・solve.rs の該当箇所、consts の値の表示、diag/codes.rs と text、旧 ConstValue を照合する読み手。

`ir/desugar.rs::constant`、`bytecode/codegen/tables.rs::const_value`、`tests/desugar_export/exchange.rs::constant`・`Surface::literal` の ConstValue の読み手、`typeck/decls.rs::summary`・`ir/check.rs::satisfies` と定数パターンの判定もこの作業で更新する。

### 内容

C の 2.2・3.2 に従い、符号付きの最小値・u64 の全域・f32 の直接の解析を扱う。七種の ConstValue を追加して読者の網羅性を更新する。単項の集合と二項の集合を分け、混合型・Byte の算術・符号なしの - を拒否する。各幅のリテラルの型を期待される型で変えない。

七種の ConstValue の追加と同時に、上記の網羅的な読み手を更新する。交換形式は P4 の表現へ出力し、新しい数を対象外へ送らない。P10 まで Core Const/ConstDesc の七種がない読み手は、到達不能な新しい値を既存の InternalError として返す。利用者の入力は型検査の静的な診断で先に止め、内部エラーを利用者向けの途中の診断に使わない。P10 でこの境界を実際の変換へ置き換える。

段階的な接続を次のとおり固定する。P6 で構文を読めても、新しい七種のリテラルは「数の実行経路が未接続」と示す静的な診断（該当区分の末尾に追加）で拒否する。P7 では幅・範囲・負号を検査した後に同じ診断を出し、型検査の公開の入口が返す TypeckOutput の値・型と診断で範囲検査を確かめる。P10 でリテラルの入口を開く。算術の型の集合の定義はここで追加するが、有効な演算子の集合は旧型だけに保ち、新しい型の演算は同じ静的な診断で拒否する。P11 は s8/s16/s32、P12 は u16/u32/u64、P13 は f32 の本体と OPERATORS が揃ったときだけ算術を有効にする。比較・補間は P14 で有効にする。直接の負号で最小値を作るリテラルの特例と、一般の単項演算を分ける。

Float32 の鍵の拒否は `solve.rs::bounds`・`typeck/decls.rs::summary`・`ir/check.rs::satisfies` のすべてへ適用する。Float32 を含む record/data でも鍵と判定されず、新しい七種の定数パターンがコアの検査でも拒否されることを確認する。

新しい整数を含むキーの利用も、実行時の鍵の変換と比較が揃う P14 まで静的な診断で止める。定数評価の表は P8 で準備しても、P10 で定数を読めるだけでは Map/Set の実行の入口を開かない。P8 の確認は型検査の出力の値と診断を使う。

### 完了の条件

最小／最大・一つ外、混合型、Byte、u64 の上半分、Float32 の範囲外を型検査の入口で確認する。未接続の新しい値を実行の入口へ公開しない。 共通の C0・S を含め、次を実行する。

```sh
cargo test -p benitoite --lib typeck::
```

## 作業 P8: 数の定数評価と静的な警告

依存: P7 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

定数の意味と警告を、実行する算術と一致する形へ広げる。

### 変えるファイル

src/base/prim.rs と新しい数の共通の計算、typeck/consts.rs・consts/key.rs、types/mod.rs、diag/codes.rs・typeck/text.rs、testdata/types・warnings の width-*。

### 内容

検査付きの各幅の算術と f32 の計算を、値の表現に依存しない共通部へ置く。const で E0435、通常の式で W0401/W0402、MIN mod -1 は 0 とする。補間とキーの定数も広げる。変換の失敗を警告へ変えない。

`base/prim.rs::KeyAtom` の新しい整数六種と定数用の幅・符号別の順序を P14 から前倒しし、`typeck/consts/key.rs` の Map/Set 定数で使う。実行時の Value から鍵への変換と比較は P14 に残す。P7 の静的な入口の制限を保ち、型検査の公開の入口が返す定数・診断で新しい幅を確認する。成功する通常の式のゴールデンは P11〜P14 の接続時に加える。

### 完了の条件

独立した境界値で定数評価・警告・const の誤りを確認する。Float32 の NaN/無限大の演算は算術の警告を出さない。 共通の C0・S を含め、次を実行する。

```sh
cargo test -p benitoite --lib typeck::consts
```

const のあふれと通常の式の警告のケースは実際に読むゴールデンも選ぶ。未接続の幅では範囲・警告に加えて P7 の静的な診断を期待し、接続した幅の担当作業でその診断の期待値だけを外す。

```sh
BENITOITE_GOLDEN_FILTER=types cargo test -p benitoite --test golden
BENITOITE_GOLDEN_FILTER=warnings cargo test -p benitoite --test golden
```

## 作業 P9: Value と Slot の即値

依存: P8 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

新しい数をヒープの対象を増やさず保存できるようにする。

### 変えるファイル

src/runtime/heap/value.rs・slot.rs・ctx.rs と core の即値の読み手、refinterp/value.rs と値の変換、値の表示・Trace・Discard の網羅的な読み手。

### 内容

七種の Value と SlotRaw、その安全な読み出しと保存を追加する。u64 を i64 と区別し、Float32 に f32 を使う。即値の Trace/Discard は参照を辿らず、Obj の回収・heap-verify の識別はそのままとする。参照インタプリタにも値の同じ区別を加える。

### 完了の条件

Value/Slot の既定の 16 バイト、保存と読み直し、回収を挟む保持を確認する。参照インタプリタに偽の Float への拡大を残さない。 共通の C0・G・H（FILTER=runtime::heap） を含め、次を実行する。

```sh
cargo test -p benitoite --lib runtime::heap
cargo test -p benitoite --lib refinterp::
```

## 作業 P10: 定数のコード生成と型付きの読み出し

依存: P9 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

新しい ConstValue を VM と組み込みの関数へつなぐ。

### 変えるファイル

src/bytecode/program.rs・bytecode/codegen/tables.rs・bytecode/codegen/emit.rs::const_ty・verify の定数の読み手、ir/desugar と定数の読み手、vm/dispatch の定数の読み込み、builtins/iface.rs の Arg/Return の実装、refinterp の定数の変換。

Q15 が認めた `src/ir/core_ir.rs::Const` の七種、表現の等値、`ir/check.rs::constant_type`、`ir/desugar.rs::constant`、参照インタプリタの定数、`tests/desugar_export/exchange.rs` のコア定数の読み手を含める。`bytecode/codegen/tests.rs::nested_constants_are_shared_and_children_precede_parents` 等の ConstDesc の網羅的な照合も同時に更新し、C0 の all-targets を保つ。

### 内容

ConstDesc の七種を追加し、生成した定数を新しい Value へ読み込む。型付きの宣言のマクロが i8/i16/i32/u16/u32/u64/f32 を読めるようにする。BuiltinDecl と既存のシグネチャを変えず、旧 Integer の命令はそのまま使う。

Q15 の範囲で Core Const の七種を追加し、P7 で到達を防いでいた ConstValue の読み手を全幅の実際の変換へ置き換える。同時に ir/check.rs の七種の定数パターンの拒否を加える。VM・参照実行器まで定数を読めた後に、七種のリテラルの静的な入口の制限を外す。算術・比較・補間の有効な集合は P11〜P14 の本体の完成まで広げない。

### 完了の条件

各幅の定数がコード生成・検証・VM・参照インタプリタで同じ値になる。型の付いた値の種類の食い違いは Internal として返す。 共通の C0・G・H（FILTER=runtime::heap） を含め、次を実行する。

```sh
cargo test -p benitoite --lib bytecode::
cargo test -p benitoite --lib builtins::
cargo test -p benitoite --test verify
```

## 作業 P11: 符号付きの幅の算術

依存: P5〜P10 の実装・短い検査・まとまりのレビュー完了。見込み: 30〜55 分。

### 目的

s8・s16・s32 の算術を実行できるようにする。

### 変えるファイル

src/builtins/funcs/operators.rs またはその新しい幅の子モジュール、builtins/table.rs、ir/desugar/exprs.rs、refinterp の演算の接続、testdata/eval/width-signed-*。

### 内容

同型の +・-・*・div・mod・単項 - を型付きの組み込みとして登録し、既存の呼び出しへ脱糖する。C の最小値・-1・除数 0 の例外を共通部で実行する。診断と停止の経路は Integer と揃える。

`builtins/table.rs::builtin_intrinsic` は、既存の専用命令が対応する旧型だけに `Intrinsic::Operator` を返し、新しい七種には `None` を返す。P12・P13・P14 の登録にもこの条件を適用し、`bytecode/codegen/emit.rs::plan` へ未対応の専用命令を送らない。`internal_lookup_functions_supply_the_language_types_and_intrinsics` の「全演算子が専用命令を持つ」という期待を旧型と新型に分ける。本体・OPERATORS・参照実行器が揃った後に s8/s16/s32 の算術の入口を開く。

### 完了の条件

実行の入口で各幅の正しい値と停止を確認し、定数評価と VM と参照インタプリタを比較できる。 共通の C0・S・G を含め、次を実行する。

```sh
BENITOITE_GOLDEN_FILTER=width-signed cargo test -p benitoite --test golden
```

```sh
cargo test -p benitoite --lib builtins::table
```

## 作業 P12: 符号なしの幅の算術

依存: P11 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

u16・u32・u64 の演算を、上半分と負の結果も含めて実装する。

### 変えるファイル

src/builtins/funcs/operators の新しい幅の本体、builtins/table.rs、ir/desugar/exprs.rs、refinterp の接続、testdata/eval/width-unsigned-*。

### 内容

同型の +・-・*・div・mod を登録する。0-1・最大値+1・除数 0 は停止し、u64 の比較や変換へ符号付きの値を混ぜない。単項 - の登録と u8 の算術を加えない。

P11 の `builtin_intrinsic` の新型に `None` を返す条件を使い、本体と OPERATORS が揃った後に u16/u32/u64 の算術の入口を開く。

### 完了の条件

u64 の上半分の正常な算術と境界の停止を CLI で確認する。Byte の式が実行へ到達しないことは P7 の主なテストで確認済みとする。 共通の C0・S・G を含め、次を実行する。

```sh
BENITOITE_GOLDEN_FILTER=width-unsigned cargo test -p benitoite --test golden
```

## 作業 P13: Float32 の算術

依存: P12 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

各演算の単精度の結果を保つ。

### 変えるファイル

src/builtins/funcs/operators の Float32 の本体、builtins/table.rs、ir/desugar/exprs.rs、refinterp の接続、testdata/eval/width-float-*。

### 内容

f32 の +・-・*・/・単項 - を登録する。各結果を単精度にし、融合積和へ変えず、IEEE の零・無限大・NaN を Float と同じ規則で扱う。定数の実行への接続を揃える。

P11 の専用命令への振り分けの条件を使い、本体と OPERATORS が揃った後に Float32 の算術の入口を開く。NaN の等値と大小比較は P14、Order との差は P18 に割り当てる。

### 完了の条件

2^24 付近の加算の丸め、正負の零、0 での除算と NaN の算術結果を独立した値で確認する。 共通の C0・S・G を含め、次を実行する。

```sh
BENITOITE_GOLDEN_FILTER=width-float cargo test -p benitoite --test golden
```

## 作業 P14: 等値・キーの順序・値の表示

依存: P13 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

新しい型を比較・Map/Set・文字列補間に使えるようにする。

### 変えるファイル

src/base/prim.rs の KeyAtom の使用、runtime/equal と map/keys、builtins の比較と文字列化、types の表示、typeck の補間、cli の結果の表示、refinterp の対応。

`builtins/table.rs::OPERATORS`・`INTERPOLATION` と新しい数の `toString` の Rust の本体・登録を含める。標準モジュールの toString の公開宣言は P15〜P17 に置く。

### 内容

整数六種の符号と幅ごとの順序、Float32 の Float と同じ等値と ordered を実装する。Float32 はキーの判定で拒否する。C の最短の f32 の表記を共通化し、補間・テスト結果・表示で同じ関数を使う。

P8 の KeyAtom の順序を実行時の値へ適用する。比較・補間の本体と登録の表、実行時の鍵の変換が揃ってから、比較・補間と新しい整数を含むキーの型検査の入口を開き、P11 の新型に専用命令を使わない条件を保つ。P7・P10 のコアの定数パターンの拒否が、比較の追加後も保たれることを確認する。

### 完了の条件

小さい Map/Set で鍵の順序と u64 の上半分、補間で Float32 の短い表記、旧出力を確認する。 共通の C0・S・G・H（FILTER=runtime::map） を含め、次を実行する。

```sh
cargo test -p benitoite --lib runtime::map
BENITOITE_GOLDEN_FILTER=width-display cargo test -p benitoite --test golden
```

Float32 の NaN の等値・大小比較と正負の零をここで確認し、Order の NaN の全順序との違いは P18 の型クラスの試験で確かめる。

## 作業 P15: 狭い整数の変換と標準関数

依存: P11〜P14 の実装・短い検査・まとまりのレビュー完了。見込み: 30〜55 分。

### 目的

s8・s16・s32・u16・u32 を Integer と明示的に変換する。

### 変えるファイル

src/prelude/stdlib の五つの数のモジュール、builtins/funcs の幅付きの整数・mod.rs・table.rs、prelude/mod.rs。

### 内容

fromInteger・toInteger・parse・toString・toFloat と absolute・minimum・maximum・floorDivide・floorModulo を表の型どおりに設ける。parse の字句は既存 Integer に合わせ、符号なしの負号は None、縮小の範囲外は None とする。宣言のマクロで登録する。

### 完了の条件

狭い幅の最小／最大と None、負の割り算の floor と mod の違いを小さな値で確認する。 共通の C0・S を含め、次を実行する。

```sh
cargo test -p benitoite --test runtime_builtins
BENITOITE_GOLDEN_FILTER=width-convert cargo test -p benitoite --test golden
```

旧型の組み込み呼び出しの共通部を変える場合は G も実行する。

## 作業 P16: u64 の全域の変換と標準関数

依存: P15 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

Integer に収まらない値も、正確に作り表示できるようにする。

### 変えるファイル

src/prelude/stdlib/UnsignedInteger64.bnt・UnsignedInteger.bnt、builtins/funcs の u64 と Decimal との変換、table.rs。

### 内容

C の u64 の Option の変換・parse・toString・toFloat・Decimal との全域の変換を設ける。fromDecimal は整数で範囲内の場合に限り、1.0m を認める。Integer 経由の i64 の折り返しと、Float からの誤った正確な変換を加えない。

### 完了の条件

2^63・2^64−1 と一つ外、1.0m、端数、負の Decimal を独立した値で確かめる。 共通の C0・S を含め、次を実行する。

```sh
BENITOITE_GOLDEN_FILTER=width-u64-convert cargo test -p benitoite --test golden
```

旧型の組み込み呼び出しの共通部を変える場合は G も実行する。

## 作業 P17: Float32 の変換と標準関数

依存: P16 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

縮小の丸めと Float に揃う標準関数を提供する。

### 変えるファイル

src/prelude/stdlib/Float32.bnt、builtins/funcs/float32.rs・mod.rs・table.rs、base/prim の表示の共通部。

### 内容

fromFloat・toFloat・parse・toString・truncate・isNaN・isInfinite と absolute/floor/ceiling/round/squareRoot を実装する。parse は数字列から直接 f32、縮小の有限値の無限大は None、元の無限大と NaN は Some とする。

### 完了の条件

縮小の半分の丸め、負の零、有限値のあふれ、truncate の Integer 境界を確認する。 共通の C0・S を含め、次を実行する。

```sh
BENITOITE_GOLDEN_FILTER=width-f32-convert cargo test -p benitoite --test golden
```

旧型の組み込み呼び出しの共通部を変える場合は G も実行する。

## 作業 P18: ビット演算・型クラス・正の名前のモジュール

依存: P17 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

残る数の標準 API と別名の使い方を完成させる。

### 変えるファイル

src/prelude/stdlib の新しい数と別名のモジュール・Trait.bnt、builtins/funcs のビット演算、table.rs、型クラスの重複判定の必要箇所。

### 内容

C のビット演算とシフトを幅ごとに追加する。Show/Order を同一性ごとに一度登録し、Float32 の NaN の全順序を Float に揃える。Integer64/Float64/UnsignedInteger8 と UnsignedInteger の関数は標準の転送で公開し、Rust の本体を複製しない。数の入口をすべて接続する。

### 完了の条件

シフト量 -1/0/幅−1/幅、符号付きと零埋めの差、型の別名を使う型クラスの同一性と旧出力を確認する。 共通の C0・S・G を含め、次を実行する。

```sh
BENITOITE_GOLDEN_FILTER=width-bits cargo test -p benitoite --test golden
BENITOITE_GOLDEN_FILTER=width-trait cargo test -p benitoite --test golden
```

数の本体と表が揃ったこの時点で、release の `benitoite` と `bench_run` を `target/p3a-versions/numbers/` へ別に保存する。HEAD と未コミット差分・機能・strip 前後の大きさを manifest に記録し、後の target/release の上書きから独立させる。P40a と最後の本測定へこの位置を引き継ぐ。

## 作業 P19: 数の WIT の照合と動的な受け渡し

依存: P15〜P18 の実装・短い検査・まとまりのレビュー完了。見込み: 30〜55 分。

### 目的

十種の数を WIT と一対一に対応させる。

### 変えるファイル

src/external/mod.rs・types.rs・convert.rs・text.rs・tests.rs、testdata/external の wit-numbers-*。

### 内容

WitPlan に s8/s16/s32/u16/u32/u64/f32 を追加し、WIT の同じ幅の型だけと照合する。Val の両方向の変換、逆に引ける宣言の修正案、新しい幅の診断を追加する。既存 TypedKind の種類と具体化の数を増やさない。

WitPlan の追加と同時に `TypedKind::of`・`ExternalRoute::of`、convert.rs の引数・結果の予算と子の走査、types.rs の各表示を更新する。新しい数の TypedKind は `None` とし、既存の具体化を増やさない。`unmapped_component_types_omit_declaration_notes` の s32/list<s32> の修正案なしという期待は、対応する修正案の期待へ変える。

### 完了の条件

手書きの小さなゲストで数の両方向と不一致を確認し、Integer64/Float64/UnsignedInteger8 の別名が旧経路に入ることを確認する。 共通の C0・S を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::
BENITOITE_GOLDEN_FILTER=wit-numbers cargo test -p benitoite --test golden
```

## 作業 P20: 型引数の代入・循環・State

依存: P19 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

具体的なレコードと data を、予算とエフェクトまで同じ実体で照合する。

### 変えるファイル

src/external/types.rs の DeclPlan と展開、typeck/external.rs、external/check.rs・tests.rs、testdata/external の wit-generic-*。

### 内容

型引数の環境で展開し、宣言の依存の循環と有限の入れ子を分ける。現在の深さ・出現数・合計の予算を入口から数える。resource の存在を代入後の到達する欄で判定し、予算切れを理由つきの E1010 にする。

`generic_recursive_and_multi_argument_types_are_rejected_before_reading_components` の Generic の二行を、具体的な代入を同じパイプラインで受理する確認へ更新する。再帰と Many の拒否は P23 まで必要なものを残す。`typeck/external.rs::contains_external` は宣言を一度だけ訪れる方式と全型引数の走査をやめ、具体的な代入後の使う欄だけを調べる。`Phantom[外部の型]` の未使用の型引数に State を要求せず、実際に resource に到達する欄には要求する。試験は既存の external/tests.rs に置き、generic の名前で指定フィルタから実行する。

### 完了の条件

Box[Box[Integer]] の受理、Nest の循環と相互の循環の拒否、未使用の宣言と型引数、resource を含む欄の State を確かめる。 共通の C0・S を含め、次を実行する。

```sh
BENITOITE_GOLDEN_FILTER=wit-generic cargo test -p benitoite --test golden
cargo test -p benitoite --lib external::tests::generic
```

## 作業 P21: flags の照合と動的な変換

依存: P20 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

Set[D] を 1〜32 項目の flags に対応させる。

### 変えるファイル

src/external/mod.rs・types.rs・convert.rs・check.rs・tests.rs、testdata/external の wit-flags-*。

`runtime/map.rs` と `map/tree.rs` に Set の本番用の `pub(crate)` の走査入口と必要なカーソルの可視性を設ける。既存の `pub(super)`・`pub(in crate::runtime)` の Cursor を external から呼べると仮定しない。既存の公開シグネチャは変えず、P22・P26 でもこの入口を使う。

### 内容

具体的な引数なしの data の項目・順・正規化した名前を照合し、タグから番号への表を作る。Set のカーソルで Val::Flags を作り、戻る名前を Set にする。0/33 項目とペイロードありの D を拒否し、選んだ名前の UTF-8 のバイト数を予算へ加える。

### 完了の条件

空の選択、1/8/9/16/17/32 の配置の境界、項目の不一致と重複正規化を小さなゲストで確かめる。 共通の C0・S・H（FILTER=external::） を含め、次を実行する。

```sh
BENITOITE_GOLDEN_FILTER=wit-flags cargo test -p benitoite --test golden
```

## 作業 P22: map の照合と動的な変換

依存: P21 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

現在の Map の順序と重複の意味で WIT の map を扱う。

### 変えるファイル

src/external/mod.rs・types.rs・convert.rs・runtime.rs・tests.rs、engine_config、testdata/external の wit-map-*。

### 内容

K を C の共通範囲に限定し、map の設定を検査と実行で有効にする。カーソルから行きを作り、帰りは全組に予算を課して順に挿入する。resource の消える値も対象へ登録して回収で片付くようにする。中間の List[Pair] を作らない。

`convert.rs::check_arguments` と統計の戻り値の計数にも map を追加し、動的な一組に `size_of::<(Val, Val)>()` と子の可変長の量を数える。`unsupported_types_are_rejected_at_the_declared_type` の Map[String,Integer] は WIT との不一致の期待へ更新し、未対応鍵を E1010 で拒否するケースは残す。

### 完了の条件

順序が乱れた重複の結果が後勝ちで鍵順になること、未対応の鍵、不正な消える値、resource の State と解放を確認する。 共通の C0・S・H（FILTER=external::） を含め、次を実行する。

```sh
BENITOITE_GOLDEN_FILTER=wit-map cargo test -p benitoite --test golden
```

## 作業 P23: 任意の組と複数引数の構成子

依存: P22 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

tuple と variant を既存の data で受け渡す。

### 変えるファイル

src/external/mod.rs・types.rs・convert.rs・tests.rs、testdata/external の wit-tuple-*・wit-variant-*。

### 内容

DeclPlan の一構成子を WIT の種類まで未確定で持つ。標準 Pair/Triple を先に識別し、1/4 個以上の tuple と variant の複数引数を照合する。WitPlan にタグと分配を保存し、帰りに直接構成子の欄を作る。Unit と 0 tuple の拒否を保つ。

P20 から残った既存試験の Many の拒否を受理へ更新する。一構成子の variant を tuple へ決め打ちしない試験は残す。convert.rs の既存 Tuple の PAIR/TRIPLE は保ち、一般の tuple と欄の分配は新しい WitPlan の種類で扱う。引数の予算・子の走査・戻り値の直接の組み直しの読み手を同時に更新する。

### 完了の条件

1/4/17 要素の組、同じ WIT の One(Pair) と Two(a,b)、従来の一構成子 variant が正しい宣言の値へ戻る。 共通の C0・S・H（FILTER=external::） を含め、次を実行する。

```sh
BENITOITE_GOLDEN_FILTER=wit-tuple cargo test -p benitoite --test golden
BENITOITE_GOLDEN_FILTER=wit-variant cargo test -p benitoite --test golden
```

## 作業 P24: 生成器の依存と記憶域の配置

依存: P19〜P23 の実装・短い検査・まとまりのレビュー完了。見込み: 30〜55 分。

### 目的

オフラインの依存と、安全な配置の計算を導入する。

### 変えるファイル

crates/benitoite/Cargo.toml、Cargo.lock、src/external/adapter/mod.rs・layout.rs。

### 内容

wasm-encoder 0.258.3 の機能を C のとおり固定して追加する。数・string/list/map の参照・record/tuple・flags/enum・variant の size/alignment/stride を検査付きで計算する。表の型の予算と memory32 の表現上限を計算の入口へ当てる。

### 完了の条件

独立した手計算の配置と小さなゲストの結果を比べ、数の幅と record/variant の詰め物を確認する。依存追加のライセンスの根拠を記録し、本体の licenses は最後のオーケストレータへ引き継ぐ。 共通の C0 を含め、次を実行する。

```sh
cargo check --offline --locked -p benitoite
cargo test -p benitoite --lib external::adapter
```

## 作業 P25: ABI の平らな型と間接の呼び出し

依存: P24 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

引数と結果の ABI を、合流と上限を含めて生成用の表にする。

### 変えるファイル

src/external/adapter/layout.rs、emit.rs のコアの型、adapter の入口の試験。

### 内容

数の平らな形・record の連結・variant の合流をビットの再解釈として求める。引数 16/17 と結果 1/2 の境界で、lower の追加の結果の位置と lift の返す位置を分ける。Rust の内部の ABI の型を直接使わない。

### 完了の条件

手書きの型と Wasmtime の検証を使い、i32/f32・i64/f64 の合流と間接の呼び出しを確かめる。生成器と同じ計算で期待値を作らない。 共通の C0 を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::adapter
```

## 作業 P26: ホストの転送形式の書き込み

依存: P25 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

言語の値を、予算付きの相対位置の形式へ詰める。

### 変えるファイル

src/external/adapter/wire.rs・codec.rs、WitPlan の読み手、list/map/set の既存カーソルの使用箇所。

### 内容

32 バイトの版付きのヘッダ、根の record、固定部と動的領域の宣言順の書き込みを実装する。全長・構築量・u32 の計算を検査してから Vec を確保する。Vec<Value> を作らず、各数・flags・map・tuple・variant を同じ表から読む。

版 1 の magic は ASCII の `BNTW`（42 4e 54 57）とする。wire.rs を magic・各欄の幅と位置・版・根の数・詰め物の唯一の定義とし、P27〜P31 はこの定義を参照する。不明の版・magic・根の数・全長の不一致、零でない詰め物と非選択の領域は補助形式の不一致として拒否する。ヘッダの二つの上限はホストの指定値と等しいことを確認する。

P32 の共有条件を先に確定し、WIT の配置と別に、タグ番号を含まない構築量の数え方を表にする。構築量は下表の言語の出現だけを加算し、根の record・map の組・variant の複数引数を平らにする ABI 用 tuple 自体は数えない。構成子のタグが違ってもこの表が同じなら共有でき、表が違えば同じ WIT でも別の補助の書き出しになる。

| 言語の出現 | 構築量 |
|---|---|
| 数・bool・char 等の基本値、引数なしの構成子 | 一つに 16 バイト |
| String/Bytes | 値一つに 16 バイトと内容のバイト数。Bytes の各 u8 を別の値として数えない |
| List | List 一つに 16 バイトと各要素の言語の出現。List[Byte] は要素ごとに 16 バイト |
| Map | Map 一つに 16 バイトと、重複を縮める前の各組の鍵・値の出現 |
| flags の Set[D] | Set 一つに 16 バイトと選択した構成子ごとに 16 バイト |
| record・tuple に写す data・variant・Option・Result | 実際に作る構成子一つに 16 バイトと、その宣言の欄の出現。非選択の欄は数えない |
| 複数引数の根、ABI 専用の中間の record/tuple | 追加なし。実際の引数・結果の言語の出現だけを数える |

Bytes と List[Byte]、`One(Pair[A,B])` と `Two(A,B)` の数え方を小さい独立した期待値で確認し、P29a・P30・P32 の生成器と共有の試験へ引き継ぐ。

### 完了の条件

独立した小さなバイト列の期待値で根が 0/1/複数の形式と、境界直前・直後の量を確認する。 共通の C0・H（FILTER=external::adapter） を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::adapter
```

## 作業 P27: ホストの転送形式の読み込み

依存: P26 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

不正な形式を検査してから言語の値を構築する。

### 変えるファイル

src/external/adapter/wire.rs・codec.rs、既存の list の葉の構築・map/set の挿入の呼び出し。

`runtime/list.rs` に `Result<Value, Stop>` の要素を小さい葉へ順次構築する本番用の `pub(crate)` の入口を追加する。既存の `from_iter_exact` のシグネチャは変えない。

### 内容

全体を検査してから、小さな葉と構成子の欄を作る。順序つきの相対位置、範囲、UTF-8、char/bool/判別子、要素数、構築予算を確認する。共有参照・あふれ・余分な末尾を拒否する。Map の全組を先に予算へ数え、後勝ちの値を組み直す。

復号は「全体の形式・すべての値の妥当性と予算の検査」と「言語の値の構築」の二段に分ける。Map の重複で消える値も前段で検査・構築予算へ含め、後段でだけ正規化する。入れ子の要素の失敗を新しい葉の構築入口から Stop として返し、失敗を返せない `from_iter_exact` へ渡さず、全要素の Vec<Value> で代用しない。

### 完了の条件

手で壊した参照先とタグが値の確保より先に拒否され、回収の強制でも戻る言語の値が正しい。 共通の C0・H（FILTER=external::adapter） を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::adapter
```

## 作業 P28: 補助のメモリ・確保・失敗の接続

依存: P27 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

生成コードの共通部と失敗の契約を、値の走査より先に作る。

### 変えるファイル

src/external/adapter/emit.rs・runtime.rs、wire.rs、試験用の最小のコアと外側の component の構成。

### 内容

メモリと realloc、整列・範囲・加算・memory.grow の結果の検査を作る。補助専用の adapter-fail の取り込みと canon lower を生成し、試験の Linker へ接続する。wire.rs のヘッダの検査もこの共通部を使う。

段階・条件の番号と専用の Rust のエラー型はこの作業で一つの内部の表に定義する。番号 1 は引数の転送、2 は結果の転送、3 は引数の構築、4 は結果の構築、5 は既存の値の大きさ、6 は realloc のメモリ不足、7 は補助形式・配置の不一致とする。要求量・上限の二つの u64 を受け、未知の番号は Internal とする。1〜4・6 は R0905、5 は R0902、7 は Internal に分類できる型を保持する。燃料・中断・Store の制限器の失敗を先に分類する順序も固定し、P29〜P34 の emit の担当者が番号を独自に割り当てない。P35 は実行の診断と統計を仕上げる。

### 完了の条件

小さなメモリで realloc の境界と失敗、既知・未知の報告番号を独立した試験用のコアから呼び、専用のエラー型と要求量・上限を確認する。生成は Wasmtime の通常の検証を通す。共通の C0 を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::adapter
```

## 作業 P28a: 固定値の呼び出しと合成

依存: P28 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

固定値を補助のメモリから元の関数へ渡し、結果を受け取る。

### 変えるファイル

src/external/adapter/emit_values.rs・component.rs・emit.rs の固定値の生成、数の手書きのゲスト。

### 内容

数・bool・char・固定の record/tuple の行き帰り、直接／間接の呼び出しを生成する。P28 の realloc・adapter-fail と P26 の構築量の表を使い、元の関数を一度だけ呼ぶ。補助の合成と canon lower/lift の検証を最小の固定値で完成させる。

### 完了の条件

手書きの数のゲストを補助で呼び、各幅のビット、間接の引数と結果を独立した期待値で確認する。生成した外側のコンポーネントは Component::from_binary の検証を通す。共通の C0 を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::adapter
```

## 作業 P29: 補助の文字列と単純なリスト

依存: P28a の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

文字列・Bytes と固定サイズの要素のリストをコピーする。

### 変えるファイル

src/external/adapter/emit_values.rs・emit.rs、adapter の小さな手書きのゲスト。

### 内容

string/Bytes と数・bool・char の list の行き帰りを Wasm のループで生成し、結果を別の領域へ詰め直す。空の値・UTF-8・要素数・転送と構築の予算を P26 の契約で検査する。型の生成は明示した作業列を使い、要素数の分だけホストの作業領域や Vec<Value> を増やさない。燃料の計数を切らず、P28 の固定した失敗番号を使う。

### 完了の条件

Boolean/Character/String/Bytes と各幅の単純なリストを手書きのゲストで往復し、不正な UTF-8 と小さい予算の境界を確認する。共通の C0 を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::adapter
```

## 作業 P29a: 入れ子のリストと結果の再配置・予算

依存: P29 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

可変長の子と 0 サイズの要素を含む走査を完成させる。

### 変えるファイル

src/external/adapter/emit_values.rs・layout.rs の走査、入れ子と構築予算の手書きのゲスト。

### 内容

入れ子の list と空の構成子を含む list の変換・結果の再配置を行い、固定部を先に予約して子の動的領域を宣言順に置く。ABI のサイズが 0 でも言語の出現の構築量を加算する。型の走査は明示した作業列、値の可変長の走査は Wasm のループとする。型の深さによる Wasm の呼び出し深さと、要素数による作業領域の量を分け、小さい値で深さの境界を確認する。

### 完了の条件

同じ list<u8> を返す引数なしのゲストを、補助の本番用の内部の入口から呼ぶ。結果を Bytes と List[Byte] とする各宣言で、転送量が上限以内でも構築量の違いで成功・失敗が分かれることを小さい上限で確認する。入れ子の行き・帰りと 0 サイズの要素も構築予算に数え、P32 の共有の試験へこのゲストを引き継ぐ。共通の C0 を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::adapter
```

## 作業 P30: 補助の直和型と多くの欄

依存: P24〜P29a の実装・短い検査・まとまりのレビュー完了。見込み: 30〜55 分。

### 目的

任意の record と variant・Option・Result を扱う。

### 変えるファイル

src/external/adapter/emit_values.rs・layout.rs の読み手、adapter の手書きのゲスト。

### 内容

宣言順の欄、場合の判別子と合流する平らな型、単一／分配のペイロードを生成する。非選択の領域を零で埋め、Result の Unit の側を省く。複数の引数・戻り値なしと多数の欄の間接 ABI を実装する。

### 完了の条件

小さな record、各場合、数の型が違う場合の合流、17 要素の tuple、複数の引数の値を独立したゲストで確認する。 共通の C0 を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::adapter
```

同じ WIT の結果に対応する One(Pair[A,B]) と Two(A,B) を、小さい構築上限で比較する。ABI 用の tuple に余分な費用を加えず、言語の構成子の個数の違いだけが費用へ反映されることを確認し、このゲストを P32 で再利用する。

## 作業 P31: 補助の flags と map

依存: P30 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

Q7・Q8 を動的な名前の確保を使わずに渡す。

### 変えるファイル

src/external/adapter/emit_values.rs・codec.rs の flags/map の接続、手書きのゲスト。

### 内容

flags の 1/2/4 バイトと i32 の形を生成し、余分な上位ビットに意味を与えない。map を鍵・値の tuple の列で変換し、重複を縮める前の全量を制限する。帰りの値の正規化はホストの Map に任せる。

P26 の構築量の表と P28 の失敗番号を使う。map の ABI 用の組に言語の Pair の費用を加えず、flags は選択した項目だけの構築量を数える。

### 完了の条件

flags の幅の境界、重複 map と乱れた順序、入れ子の値で期待する Set/Map を得られる。 共通の C0 を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::adapter
```

## 作業 P32: 合成したコンポーネントの共有

依存: P31 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

元のコードを一つだけ含む合成と実行内の共有を実装する。

### 変えるファイル

src/external/adapter/component.rs・mod.rs、external/check.rs・runtime.rs の共有する表、ComponentSource の必要な内部の管理。

### 内容

同じ元のソースについて対象関数をまとめ、alias と canon lower/lift のコンポーネントを組み立てる。元のバイト列、書き出しごとの WIT の形・構築量の数え方、書き出しの集合、形式の版を鍵とする。言語の構成子のタグ番号はホストの表に置き、共有の鍵から除く。生成の 16 MiB の予算と事前の動的への判定を設ける。

事前点検の推す修正 A を採り、タグ番号を除いた「構築量の数え方」を生成と共有の鍵、補助の書き出しの識別へ加える。同じ元の WIT の関数でも数え方が違えば、別の補助の関数を生成する。数え方を実行時の追加データで解釈する代案 B は、転送形式と走査を増やすため採らない。補助の Wasm が増えうるが、生成量の 16 MiB の上限へ含め、ホスト実行ファイルの増分と性能は最後に測る。元のコンポーネントは引き続き一つだけ埋め込む。

### 完了の条件

一つの元コードの複数の関数、違う言語の宣言、違う元のコードを取り違えずに呼べる。生成量の超過を小さな内部の予算で確認し、検証の失敗を隠さない。 共通の C0 を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::adapter
```

P29a・P30 のゲストで、同じ元の書き出しに対する Bytes/List[Byte] と One(Pair)/Two を同じ実行内で宣言し、各構築上限の結果の成功・失敗が混ざらないことを確認する。Bytes/List[Byte] は既存の速い経路にも入るため、この共有の試験は補助の本番用の内部の入口で行い、利用者向けに経路を強制するフラグを設けない。タグだけが違い数え方が同じ宣言は共有し、数え方が違う宣言は別の補助の書き出しを使う。

## 作業 P33: 実行の内部の接続とキャッシュ

依存: P32 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

補助の固定した呼び出し型を内部へ接続し、既存の経路と共有の管理を揃える。

### 変えるファイル

src/external/adapter/runtime.rs、external/mod.rs・check.rs・runtime.rs・typed.rs の内部の振り分けとキャッシュ。

### 内容

resource の状態を持つ動的、既存 TypedShape、補助、生成上限時の動的の順の候補を内部で求める。数の型の具体化を増やさない。純粋な補助の呼び出しごとに新しい Store を作り、引数の検査・詰め込みを実行時の遅延コンパイルとインスタンス化より先に行う。補助の内部の報告関数だけを Linker に登録し、元のゲストの取り込みなしの検査を保つ。呼び出し失敗を再試行しない。

ExternalRuntime.components の元ソース単位のキャッシュと、補助のコンパイル済み Component のキャッシュを分ける。後者は P32 の鍵と Engine に対応させる。同じ元コードの resource の経路と補助が互いの Component を上書きせず、複数の構築量の表も区別して保持する。Value と Store の状態をこのキャッシュへ保存しない。

利用者向けの経路はまだ切り替えない。既存の TypedShape と動的の選択を保ち、補助は本番用の非公開の接続を単体の試験から呼ぶ。P34・P35 の上限・分類と P36 の必須の寿命・符号化の試験を通し、P36a で入口を切り替える。

### 完了の条件

内部の試験で同じゲストを既存経路と補助から呼び、キャッシュの共存と各宣言の値を確認する。利用者の宣言ではこの作業の前の経路が選ばれる。共通の C0・G・H（FILTER=external::runtime）を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::runtime
```

## 作業 P34: 補助の上限・燃料・中断

依存: P33 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

新しい経路にも既存の制限を漏れなく当てる。

### 変えるファイル

src/external/adapter/runtime.rs・emit.rs・emit_values.rs・codec.rs、external/runtime.rs の制限器。

### 内容

転送と構築の予算をヘッダと増分の確保の前に検査する。メモリとコアインスタンスの追加を Store の合計へ数え、燃料と epoch の中断を共通化する。既存 String/Bytes/List の上限と memory32 の全長の上限を確かめる。

P33 の内部の接続で確認し、利用者向けの経路は切り替えない。予算検査は stats の指定と独立して実行する。

### 完了の条件

小さい上限で行き・帰り・入れ子の量の直前／直後、合計メモリ・対象数・燃料・中断が正しく止まる。大きな長時間のゲストを使わない。 共通の C0・G・H（FILTER=external::adapter） を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::adapter
cargo test -p benitoite --test external_signals
```

## 作業 P35: 診断と消費量の報告

依存: P34 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

ABI の誤り・生成器の不具合・資源の不足を区別して示す。

### 変えるファイル

src/external/stats.rs・text.rs・runtime.rs・adapter/runtime.rs、diag/codes.rs、cli の統計の読み手と `cli/mod.rs` の既存の統計の試験。

### 内容

P28 で定義した adapter-fail の番号・量と専用の Rust のエラー型を実行の診断へ接続し、Wasmtime のエラーの型を読み、R0902/R0904/R0905/R0906 と Stop::Internal を分ける。燃料・中断・制限器の失敗との優先を保つ。旧 JSON の欄を保ち、経路と construction_bytes・事前の動的への理由を追加する。統計を指定しない場合の追加の走査と表の確保を避ける。

既存の `cli::tests::wasm_limits_and_stats_reach_run_and_test` で統計の表示・分類を既存経路から確認し、補助固有の成功・失敗は P33 の本番用の内部の接続で確認する。利用者の補助経路を前倒しで開かず、補助の CLI の統計の確認は P36a に置く。ゴールデンの API の実行を `--wasm-stats` の読み込みの確認へ代用しない。統計を指定しなくても必要な予算の検査は省かない。

### 完了の条件

成功と各分類の失敗で関数名・経路・量を確認し、旧名の表示と統計を指定しない結果も保つ。小さなゲストで専用のエラーの型が合成の境界を越えて保持され、元のゲストから報告関数を呼べないことを確認する。 共通の C0・S を含め、次を実行する。

```sh
cargo test -p benitoite --lib cli::tests::wasm_limits_and_stats_reach_run_and_test
```

```sh
cargo test -p benitoite --lib external::adapter
```

## 作業 P36: 後処理・符号化・形式化の接続の確認

依存: P35 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

生成した経路の寿命と、処理系から Lean への短い往復を確認する。

### 変えるファイル

src/external/adapter の後処理の必要な修正、tests/desugar_export.rs・desugar_export/exchange.rs と formal/Exchange の意味の対応、手書きの寿命・符号化のゲスト。

### 内容

元のゲストの post-return が領域を壊しても補助へ移した結果を保持することを、P33 の内部の接続と手書きのゲストで確認する。UTF-16 のゲストと不正な文字列・タグ、深い入れ子も小さな値で扱う。補助経路をまだ公開せず、この確認を P36a の前提にする。

Rust の交換形式の網羅性の修正は P7・P10 で済ませ、ここでは新しい型・定数・標準関数の意味の対応を確認する。tests/desugar_export.rs に短い専用の `export_width_smoke` を追加し、`#[ignore]` を付けず、既存の export・宣言表の出力処理を再利用する。符号付き各幅の最小値・u64 の上半分・Float32 のビットと各幅の演算を数件の入力にまとめ、全 corpus の発見と 1,000 件の生成は呼ばない。出力先は BENITOITE_DESUGAR_DIFF_DIR に従い、corpus.json・builtins.json・stdlib-decls.json を既存の読み込み形式で作る。新しい数を含む定義が inScope であり、excluded・outside に落ちていないことと各幅が一件以上検査されることを確認する。

### 完了の条件

post-return を二度呼ばず、純粋な呼び出しの状態が残らない。通常の Rust テストや lake build だけを接続の確認とせず、次の短い出力を三つの Lean の実行器へ渡し、各 report の成功件数と新しい数の非除外を確認する。全 corpus の ignore 付き export_desugar_corpus と check-formal.sh は最後に一度行う。共通の C0・S・H（FILTER=external::adapter）を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::adapter
BENITOITE_DESUGAR_DIFF_DIR=target/p3a-formal-smoke cargo test -p benitoite --test desugar_export export_width_smoke -- --exact --nocapture
(cd formal && lake build desugarDiff builtinCheck surfaceCheckAll)
formal/.lake/build/bin/desugarDiff target/p3a-formal-smoke/corpus.json target/p3a-formal-smoke/report.json
formal/.lake/build/bin/builtinCheck target/p3a-formal-smoke/corpus.json target/p3a-formal-smoke/builtins.json target/p3a-formal-smoke/builtin-report.json
formal/.lake/build/bin/surfaceCheckAll target/p3a-formal-smoke/corpus.json target/p3a-formal-smoke/builtins.json target/p3a-formal-smoke/stdlib-decls.json target/p3a-formal-smoke/surface-report.json
```

## 作業 P36a: 補助経路の公開と中間版の保存

依存: P33〜P36 の実装と短い検査、上限・分類・寿命・符号化の必須試験の完了。見込み: 30〜55 分。

### 目的

保護と失敗の分類が揃った補助経路を、利用者の宣言へ接続する。

### 変えるファイル

src/external/mod.rs・check.rs・runtime.rs の経路の選択、testdata/external の adapter-route-*・adapter-lifetime-*、`src/cli/mod.rs` の統計の試験。

### 内容

P33 の候補の選択を本番の入口へ接続する。resource は状態を持つ動的、現在の TypedShape は速い経路、残りは補助、生成・配置の上限に当たる契約は呼ぶ前に動的とする。3 引数の数のリストと戻り値なしも補助へ送る。失敗後に別経路で呼び直さない。

P34 の上限、P35 の分類・統計、P36 の寿命・符号化の確認を公開前の条件として記録する。経路・後処理のゴールデンと CLI の統計の試験はここで初めて補助を選ぶ。統計は既存の `wasm_limits_and_stats_reach_run_and_test` へ補助の行を足し、実際の run/test の `--wasm-stats` と、指定しない場合の出力を確認する。P29〜P36 のゲストを再利用し、内部で確認済みの境界値を重複して大量に増やさず、実際の入口と報告の接続を確認する。

### 完了の条件

旧の速い経路と resource の状態の寿命を保ち、CLI で adapter の成功・失敗・統計を確認する。共通の C0・S・G・H（FILTER=external::runtime）を含め、次を実行する。

```sh
cargo test -p benitoite --lib external::runtime
BENITOITE_GOLDEN_FILTER=adapter-route cargo test -p benitoite --test golden
cargo test -p benitoite --lib cli::tests::wasm_limits_and_stats_reach_run_and_test
BENITOITE_GOLDEN_FILTER=adapter-lifetime cargo test -p benitoite --test golden
```

この時点で release の benitoite と bench_run を target/p3a-versions/adapter/ へ別に保存する。P18 と同じ構成・HEAD と差分・機能・strip 前後の大きさを manifest に記録し、P40a と最後の本測定へ渡す。

## 作業 P37: 言語仕様と数の標準 API の文書

依存: P30〜P36a の実装・短い検査・まとまりのレビュー完了。見込み: 30〜55 分。

### 目的

実装した数と字句の規則を設計書へ反映する。

### 変えるファイル

docs/design/01-spec/01-01-lexical.md・01-02-syntax.md・01-04-types-basic.md・01-06-type-system.md・01-12-core-calculus.md、03-interop/03-06-stdlib.md、00-overview/00-04-glossary.md、07-quality/07-04-formal-semantics.md。

`docs/design/01-spec/01-08-evaluation.md` の「整数の溢れ」と「0 による除算」の表も含める。

### 内容

C の 2〜6 節を実装の事実に合わせて書く。Byte の例外、正の名前と表示名、算術の停止と静的な警告、変換の Option、f32 の丸め、パターンの範囲を明記する。既存の見出しを変えず、形式化の写しと対象外を通読して整合する。

01-08 の表へ新しい幅・符号なしの負値になる減算・各標準関数の停止条件を追加し、01-04・03-06 と実行時エラーの一覧を一致させる。

### 完了の条件

数の各幅と別名、負号・範囲外、補間の例が仕様の検査を通る。推測した保証を設計書へ書かない。 共通の C0・S を含め、次を実行する。

```sh
cargo test --test spec_examples
cargo test -p benitoite --test skill_docs
```

## 作業 P38: 数の表現とコンパイラの設計書

依存: P37 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

新しい即値・定数・演算の接続を現在の実装として記録する。

### 変えるファイル

docs/design/02-impl/02-03-frontend.md・02-04-resolver.md・02-05-typechecker.md・02-06-ir-and-lowering.md・02-07-bytecode.md・02-08-vm.md、03-interop/03-01-library-structure.md。

### 内容

C の 4・5 節を反映し、prelude と別名の索引、Q15 の Core Const の追加、新しい幅の組み込み呼び出しと旧専用命令の区別、即値の大きさを記録する。実装中の入口の制限は提供済みの仕様に残さない。

### 完了の条件

定数・値・型の名前と演算の記述が実装と一致し、リンクと見出しの参照が切れていない。共通の C0・S を含め、次を実行する。

```sh
cargo test -p benitoite --test skill_docs
```

## 作業 P38a: 外部境界・上限・報告の設計書

依存: P38 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

WIT の照合・経路・予算・共有と失敗の報告を現在の実装として記録する。

### 変えるファイル

docs/design/02-impl/02-09-runtime.md・02-10-diagnostics.md、03-interop/03-10-external-functions.md、06-tooling/06-01-cli.md、07-quality/07-01-security-model.md、testdata/external の wit-docs-*。

### 内容

C の 7〜9 節を反映し、型の代入と循環、flags/map/組、転送と構築の予算、追加のメモリと燃料、構築量の数え方を含む共有の鍵、生成上限時の事前の動的への振り分けを明記する。Wasmtime の版とライセンスの根拠、対象外の保証を揃える。03-10 の例は testdata/external の本物のゲストと同じ宣言・入力の wit-docs-* ケースへ対応させ、例が増えた場合はそのケースも更新する。

### 完了の条件

03-10 の各例とゴールデンの対応を記録し、実際の外部の関数の入口で型・値を確認する。spec_examples は 03-10 を読まないため、その成功を外部の例の検査へ代用しない。リンク・目次・診断の表と実装が一致する。共通の C0・S を含め、次を実行する。

```sh
BENITOITE_GOLDEN_FILTER=wit-docs cargo test -p benitoite --test golden
cargo test -p benitoite --test skill_docs
```

## 作業 P39: 言語リファレンス・CHANGELOG・Skill

依存: P38a の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

利用者と LLM に公開する契約を揃える。

### 変えるファイル

docs/reference/benitoite.md、CHANGELOG.md、crates/benitoite/skill/SKILL.md と手書きの references、src/cli/tools/skill/generate.rs、生成した skill/references。

### 内容

英語の数の型と外部の関数の節、接尾辞の仮の構文の予告、型の別名の表、変換・flags/map・data の例を更新する。旧の三モジュールの表示を主とし、生成器が別名の同一性を参照するようにする。CHANGELOG の Unreleased に利用者の変化と予算の説明をまとめる。日本語訳はリリース時の作業とし今回変更しない。

`cli/tools/skill/generate.rs::module_reference` は AST の宣言だけでなく P5 の組み込みの名前の表を読み、型の説明を各モジュールの関数の前に生成する。Integer64=Integer・Float64=Float・UnsignedInteger8=Byte・UnsignedInteger=UnsignedInteger64 と、七種が独立した型であることを出力する。主の表示は旧名を保ち、正の名前と別名の同一性を型の節で示す。薄い転送関数だけから型の同一性を推測しない。

### 完了の条件

リファレンスと Skill の例が実行でき、生成物をもう一度作って同じ内容になる。既存の例と旧表示を保つ。 共通の C0 を含め、次を実行する。

```sh
cargo run -q -p benitoite --example gen_skill
cargo test -p benitoite --test reference_examples
cargo test -p benitoite --test skill_docs
cargo test -p benitoite --test skill_examples
```

## 作業 P40: 比較入力とゲストの再利用

依存: P39 の実装と短い検査の完了。見込み: 30〜55 分。

### 目的

最後の本測定に使う比較入力と独立した期待値を揃える。

### 変えるファイル

tools/bench/wit-transfer/ の入力・期待値・ゲストと再生成するソース、tools/bench/README.md。

### 内容

P19 の新しい数、P21 の flags、P22 の map、P23・P30 の record/tuple/variant、P29 の Boolean/Character/String/Bytes、P29a の入れ子、P36 の UTF-16 の手書きのゲストと再生成ソースを再利用する。試験の内部のコードへ依存せず、元ソース・生成コマンド・版を比較用 manifest に記録する。0/小/大の入力と共通の期待値を用意し、九種類の契約と短い数・大きな Bytes の比較を構成する。

型付き・補助・動的は実際の宣言で選ばれる範囲を記録し、経路を強制する公開フラグを加えない。必要な動的の比較は Wasmtime を直接呼ぶ測定用の例として P40a で用意する。

### 完了の条件

小さい入力の各宣言を最終版で実行して独立した期待値と一致させ、ゲストの再生成手順・入力の大きさ・選ばれる経路を P40a へ渡す。大きい入力の計時は最後の本測定へ残す。共通の C0 を含め、各小さい入力を読む manifest の CLI コマンドを実行する。

## 作業 P40a: 計時・RSS・統計の記録の道具

依存: P40 の実装と短い検査の完了、P18・P36a の保存した release と manifest。見込み: 30〜55 分。

### 目的

初回と同じ実行内の繰り返しの費用を分けて記録する。

### 変えるファイル

tools/bench/wit_transfer_bench.py（新規）、tools/bench/README.md、crates/benitoite/examples の測定用の入口。

### 内容

測定用の例に開始・終了の時刻を取る箇所を置く。生成は adapter の生成の入口、コンパイルは Component::from_binary、インスタンス化は Linker の接続から instantiate の完了、実行は TypedFunc/動的 Func の call の前後とする。ホストの詰め込み・復号は別の欄に記録する。本番の公開 API に測定だけの差し込み口を加えず、必要な測定の内部の接続は例から使う範囲を明記する。既存 stats の合計から各時間を推測しない。

ExternalRuntime のキャッシュは実行内にだけ生きるので、繰り返しは一つの Benitoite の実行で同じ外部関数を複数回呼ぶ。別プロセスの初回の結果と区別して、生成・コンパイル・インスタンス化・実行の時間、RSS、stats、燃料、転送と構築量を記録する。P18 と P36a のバイナリは保存位置と版・構成・strip 前後の大きさを読み、再ビルドで置き換えない。

### 完了の条件

--quick は P40 の小さい入力と最終版の結果の一致、計時の欄と JSON の形式だけを確認し、中間版の再ビルドと本測定は行わない。比べる版・構成・バイナリの位置と同一実行内の繰り返しのコマンドを最後のオーケストレータへ渡す。共通の C0 を含め、次を実行する。

```sh
python3 tools/bench/wit_transfer_bench.py --help
python3 tools/bench/wit_transfer_bench.py --quick --output target/p3a-transfer-quick.json
python3 -m py_compile tools/bench/wit_transfer_bench.py
```

## 全作業の後にオーケストレータが行うこと

この節は P 作業に含めない。各 P の実装と Opus のレビューを終えた後に一度行う。

1. scripts/check.sh --dry-run で選ばれる検査と理由を設計者へ知らせる。formal・heap・licenses を含む見込みと時間も報告し、選択に従って scripts/check.sh を一度実行する。P 作業の gc-stress と短い関門が通っていても、共通検査を省かない。
2. 形式化した範囲を変更したので scripts/check-formal.sh を一度通し、脱糖・網羅性・型検査の出力・組み込みの表を突き合わせる。check.sh が選ぶ lake build と、差分検査を含む check-formal.sh の役割を区別する。新しい型を対象外として除くことで通してはならない。
3. check.sh が分類できないファイルを示して終了状態 3 で止まった場合は、該当ファイルを示して設計者に --full・--only・--none を尋ね、その回答どおりに選ぶ。オーケストレータの判断だけで --none へ変えない。
4. benchmark の手順と設計者が確認した機械の状態に従い、本測定を一度行う。開始前の版と最終の版の fib・loop、既存の短い数と大きな Bytes、新しい合成型の量・RSS・燃料・初回と繰り返しの費用、release の strip 前後の大きさを記録する。P18 の numbers と P36a の adapter の保存済みバイナリと manifest を使い、最終版との差と各段の増分を区別する。上書き済みの target/release から中間版を復元しない。
5. 未確認の性能を試作の数値で埋めず、測定の限界と未対応の範囲を報告する。項目の閉じ方と改造の保管は AGENTS.md に従い、設計者の作業の範囲でとりまとめる。

性能や大きさの測定により追加の改造が必要になった場合は、原因と修正範囲を先に示す。作業 ID の完了の印だけを進めず、修正後の必要な検査を行う。

