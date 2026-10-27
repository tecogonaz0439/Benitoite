# L27a の実装結果

再開の時刻取得: **2026-10-26 16:57:27 JST**。終了: **2026-10-26 17:13:45 JST**。この計測区間の所要時間: **16分18秒**。再開時の事前の読み込み開始時刻は記録していないため、これは再開の実作業全体より短い。初回起動の正確な着手・終了・所要時間は残存記録からは確定できず、**不明**である。初回の `Exchange.lean` の作成・更新として再開時に確認できた時刻は16:40:55〜16:42:13 JSTであり、観測できた区間は1分18秒だった。これを初回起動の所要時間と同一視しない。初回と再開を合わせた正確な総所要時間も不明である。

**状態: L27a の読者、base の正負例、既定ビルドへの接続、設計書への反映、指定 work と差分点検を完了した。独立レビュー・受け入れは取りまとめへ引き渡す。**

B_WORK・HEAD は `258735b076842aebf3498505b7238be67a5fba31`、ブランチは `mod012/L27a`。再開時には未追跡の `formal/Benitoite/Interval/Exchange.lean` と本ディレクトリの初回のコンパイル失敗ログ三つがあり、results.md はなかった。初回起動がモデルの混雑で終了したとの取りまとめの指示を受け、この実装と記録を引き継いだ。

## 実装した範囲

| 対象 | 内容 |
|---|---|
| [Exchange.lean](../../../../formal/Benitoite/Interval/Exchange.lean) | 生の `interval-corpus` 初版1の厳密な読者。Surface 14の型・本体・定数の復号と変換を再利用し、再符号化との一致で深い未知欄・欠落欄・複数構成子を拒否する。重複欄は JSON の object が作られる前に検査する |
| 同上の値・対応の検査 | 正規の十進文字列を Int・Nat として読み、閉区間の i64 値域・順序、予算状態の三条件、全型キーと先行順、根の型、元演算の対応、警告の出現・演算・Integer64型を検査する。重複した入力・モジュール・定義・定数・番号・警告を拒否する |
| 同上の profile と定数 | base だけを受理し、standards・apiAt は空配列を要求する。偽の標準宣言を補わない。定数の重複・循環・欠落を拒否し、展開した constE の子も番号の照合に含める |
| [ExchangeExamples.lean](../../../../formal/Benitoite/Interval/ExchangeExamples.lean) | 33組の `#guard`。除数0・加算と単項負号のあふれの候補、i64両端、大きな十進数、impl名、定数展開、primName・funNameの頭と、深い不正入力を生の読者の境界で確認する |
| [Benitoite.lean](../../../../formal/Benitoite.lean) | 上の二モジュールを既定 import に加えた |
| [01-12](../../../design/01-spec/01-12-core-calculus.md#区間解析の独立交換の読者)・[07-04](../../../design/07-quality/07-04-formal-semantics.md#区間解析の独立交換の読者) | 復号した型の写し、受理済みの欄・版・数値・対応、読者が保証する範囲を反映した |

端点を Float・usize に変換していない。操作回数・保持数・fuel・番号も Nat のままとし、機械語幅で打ち切らない。既存の corpus14・sidecar6・六入口・lakefile.toml と `-M 12288`、Rust と予算の固定表は変更していない。組み込みの関数・操作の primName、利用者関数・包みのシフトの funName は既存 Surface の形で保持する。操作やHTTPの欄を交換の標準規則に追加していない。

復号した Expected は入力に記述された値を保持する。読者の例は、Expected の区間・候補・消費数と解析結果の一致を検査しない。特に例の after の0は読者の入力であり、解析の実消費についての期待値として後続の比較へ流用しない。読者は型表の完全性・根の一致を検査するが、型導出・名前解決そのものを再検査する処理は含まない。交換の検証用の全列挙を、予算付き解析の事前走査には接続していない。

## テストの作成時の関門

1. 守る契約は、独立交換の生の入力からの受理・拒否、復号した数値・型・本体・キー・候補の保持である。
2. 現実的な退行は、既存 FromJson が捨てる深い余剰欄の見逃し、JSON の重複欄の上書き、十進数の丸め、定数展開後の番号の欠落、警告と元演算の取り違えである。
3. 既存の Surface の例だけでは、新しいヘッダ・予算・型表・sourceKeys・Expected の境界を通らない。正負の入力を一つの例ファイルの表にまとめた。パスの編集に失敗した例を拒否成功に数えない。
4. 準備用の編集・観測の補助は例ファイル内の private 定義だけである。本番の差し込み口や解析器の公開範囲を増やしていない。

## 中心命題・参照定義・旧主定理・公理の照合

基準との `git diff` と、既存ファイルの内容を基準の git blob と照合する [点検器](audit.py)・[結果](audit.json)を使った。root の既定 import の追加を除き、既存の formal/・crates/・fuzz/ と manifest 等の **4,474ファイルが一致**した。既存 Lean の名前付き定理 **3,015件の言明と本文はファイル全体として不変**である。新しい読者と例に theorem・公理・sorry は加えていない。

| 言明・参照定義 | 照合対象 | 差分と意味の向き |
|---|---|---|
| NormalSoundness・WarningSoundness の本文・前提・結論 | Interval/Eval.lean 全体 | 変更なし。中心二命題の弱化なし |
| EvalPartial・EvalBlock・EvalInput・Unmodeled・UnknownAt | 同上 | 変更なし。未知を具体規則に置き換える変更もなし |
| ConcreteValue・StandardRule・StandardBinding・EvalStandard と各具体規則 | 同上 | 変更なし。操作の具体規則や新しい仮定なし |
| targetOperationAt・arithmeticOperationAt・WarningLocated | Interval/Sound.lean 全体 | 変更なし。既存定義を読者から参照するだけ |
| concreteRule・syntacticReachChildren | Interval/SyntacticReach.lean 全体 | 変更なし。構文的な到達可能性の拡張・縮小なし |
| AbstractSlot・AbstractEnv・SlotModels・Models・LocalsModels | Interval/Domain.lean・Environment.lean 全体 | 変更なし。Models の前提を強める変更なし |
| RangeState.Models と由来の表現 | Interval/RangeState.lean 全体 | 変更なし |
| 公開入口を含む既存主定理・公理・Builtins.Assumptions | root を除く既存 formal/ の全ファイル | ファイル全体が一致。新しい公理・既存定理の言明の変更なし |
| 六入口・交換・設定・Rust・予算固定表 | 既存 formal/・crates/・fuzz/・manifest 等 | 変更なし |

点検器は実行前後の対象5ファイルの [SHA-256](work-inputs-sha256.json)も照合する。作業末検査後に、Lean・設計書・入力・期待値を変更していない。

## 検査の実行

実行場所は `<repo>`、Lean は `<repo>/formal`。シェルでは rtk proxy を使用した。Lean 4.34.1 と Rust 1.98.1 の固定版を使い、作業末の Cargo は書き込み可能な既存の `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を継承した。実行のコマンド・開始時刻・終了状態・外側時間は各JSON、出力は同名のlogに保存した。試しの読者と例は `lake env lean -M 6144` に時間上限300秒または25秒を付けた。上限による停止・終了143はなかった。

| 記録名 | 終了 | 外側時間 | 記録 |
|---|---:|---:|---|
| `reader-resumed` | 0 | 0.862秒 | [JSON](reader-resumed.json)・[出力](reader-resumed.log) |
| `reader-complete` | 0 | 0.875秒 | [JSON](reader-complete.json)・[出力](reader-complete.log) |
| `reader-build` | 0 | 0.986秒 | [JSON](reader-build.json)・[出力](reader-build.log) |
| `examples-first` | 1 | 0.750秒 | [JSON](examples-first.json)・[出力](examples-first.log) |
| `examples-second` | 1 | 0.831秒 | [JSON](examples-second.json)・[出力](examples-second.log) |
| `examples-complete` | 1 | 0.821秒 | [JSON](examples-complete.json)・[出力](examples-complete.log) |
| `examples-final` | 0 | 0.782秒 | [JSON](examples-final.json)・[出力](examples-final.log) |
| `reader-documented` | 0 | 1.003秒 | [JSON](reader-documented.json)・[出力](reader-documented.log) |
| `examples-expanded` | 0 | 0.841秒 | [JSON](examples-expanded.json)・[出力](examples-expanded.log) |
| `examples-build` | 0 | 1.009秒 | [JSON](examples-build.json)・[出力](examples-build.log) |
| `root-build` | 0 | 0.671秒 | [JSON](root-build.json)・[出力](root-build.log) |
| `ready` | 0 | 0.149秒 | [JSON](ready.json)・[出力](ready.log) |
| `dry-run` | 0 | 0.011秒 | [JSON](dry-run.json)・[出力](dry-run.log) |
| `work` | 1 | 10.828秒 | [JSON](work.json)・[出力](work.log) |
| `audit-before` | 0 | 0.241秒 | [JSON](audit-before.json)・[出力](audit-before.log) |

`reader-*` は読者の単体検査またはビルド、`examples-*` は正負例の単体検査またはビルドである。成功した最終の単体検査は `examples-expanded`、その後の既定用の例のビルドは `examples-build` である。いずれも同じ最終のソースを検査している。

依存はキャッシュ済みであり、読者 → 例 → root の順に一モジュールずつビルドした。未ビルドの依存を並列に起動しないよう、作業末の前に `lake --no-build build` が **All targets up-to-date（359 jobs）**、終了0となることを確認した。Lean の実行中に別のビルド・編集を進めず、各プロセスの終了状態を確認してから次へ進んだ。既定ビルドでは既存の lint 警告の再表示があるが、新モジュールの警告はない。

指定の dry-run と作業末の本体は次である。三単位だけを名指しし、各単位は work から一度実行した。

```sh
scripts/check.sh --level work --base 258735b076842aebf3498505b7238be67a5fba31 --only formal_build,spec_examples,spec_tally --dry-run
scripts/check.sh --level work --base 258735b076842aebf3498505b7238be67a5fba31 --only formal_build,spec_examples,spec_tally
```

[work-check.py](work-check.py)が二つ目のコマンドを呼び、外側を `/usr/bin/time -l` で包んだ。**検査本体は終了0・10.799秒**、三単位すべて成功した。[本体の結果](work-check.json)・[生の出力](work.log)。仕様集計の自己検査と集計は成功し、初回リリース版の完了条件の未記入は none。仕様例は **7件成功・失敗0・ignored 0**、テスト本体2.98秒。formal_build は既定 lake build と sorry 拒否を通過した。

**maximum resident set size はサンドボックスの制約で取得不能**だった。検査本体の終了0の後、time が `sysctl kern.clockrate: Operation not permitted` を報告し、外側は終了1・10.828秒となった。real/user/sys は10.82/7.54/2.15秒である。未取得を0とせず、計測のための検査の再実行はしていない。

## 途中の失敗と修正

引き継いだ [reader-first.log](reader-first.log)・[reader-second.log](reader-second.log)・[reader-third.log](reader-third.log)は、最初の起動のコンパイル失敗である。残存コードで最後に残っていた予約語 `matches` を変数名に使う構文エラーを直し、再開後の読者単体検査を通した。初回の三つのログに記された時間は0.938・0.833・0.814秒、いずれも終了1であり、これらの合計を初回の作業時間とはしない。

新しい例の最初の検査では、head! に必要な Inhabited Input がないことを検出した。本番の型にインスタンスを増やさず、例の観測を列のパターンマッチにした。続く検査では存在しない contains の参照、さらに min64・max64 の名前空間の欠落を検出したため、閉区間の両端を直接比較し、Release の名前空間を明示した。期待値・入力・時間制限を緩めず、その後の例を通した。失敗した出力も上表の examples-first・examples-second・examples-complete に保存している。

点検器の初回は `git ls-files` の日本語・非ASCIIファイル名の引用表現をパスとして渡して失敗した。NUL区切りの `git ls-tree` と blob 内容のハッシュの照合に直した。点検器の修正だけであり、処理系・Lean・検査入力の変更ではない。[audit-before.json](audit-before.json)以降は成功している。最終の記録点検の初回は、出力のない正常ログにも末尾改行を要求して失敗したため、空ログを認めるよう点検条件を直した。最終のリンク・パス・Python 構文の点検は [final-review.json](final-review.json) に残した。

## 計画との差と申し送り

L27a の範囲の変更・停止条件への該当・4時間による中断はない。読者の正負例を既定で検査するため、例ファイルと既定 import を加えた。新しい言語規則・主要定理の前提や結論・公理に関する未決の判断はない。private/ とそれを指すリンク、git の変更操作、担当の委任は利用していない。別状態の結果を引用して検査を省いていない。

| 残る手順 | 担当・受け渡す内容 | 見込み |
|---|---|---|
| L27a の独立レビュー・受け入れ・コミット・取り込み | 取りまとめ。本結果と読者の厳密さ、定義・言明・仮定の差を確認する | 不明 |
| 既定の intervalDiff の接続と検査・受け入れ | L27b。生入力は `readCorpus` に渡す。旧六入口を保ち、`IntervalDiff/Main.lean` と lakefile を接続する | 計画の1〜2時間。検査・レビューの追加時間は不明 |
| analyze/eval の報告・局所比較・検査・受け入れ | L28。Expected と解析の一致・具体評価を別に実装する。読者の例の after=0 を解析の期待値として転用しない。Python 経由の比較はここから | 計画による。今回未測定の時間は不明 |
| profile の追加と C5、その後の Rust/VM 比較・検査・受け入れ | L29・X01〜X05。domain はシフトだけ、操作・HTTP の欄は含めない。全型表・元キーは定数展開後の Surface の先行順で渡す | 計画による。今回未測定の時間は不明 |

stage・change・release・check-formal.sh 全体、実 VM と Python 経由の局所比較は本枝の割り当てでは実行していない。

## 取りまとめのレビュー（2026-10-26）

受け入れる。既存の Lean のファイルは変わらず（`formal/Benitoite.lean` の import の追加だけ）、新しい `Exchange.lean`・`ExchangeExamples.lean` に sorry・公理・`decide +kernel` はない。最初の二回の起動は Codex のモデルの混雑で途中で終わった。番人の記録によれば、一回目は 16:36:44〜16:43:14、二回目は 16:43 頃〜16:46:26 である。取りまとめは 10 分あけて再起動した（`retry-work.sh`）。L27b へ進む。
