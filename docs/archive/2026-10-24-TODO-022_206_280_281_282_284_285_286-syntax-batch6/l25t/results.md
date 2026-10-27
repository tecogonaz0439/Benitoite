# 作業 L25T の結果

着手: 2026-10-26 14:25:25 JST。終了: 2026-10-26 14:39:23 JST。所要時間: 13分58秒。

**状態: L25T の指定範囲の修正・固定表への影響の採取・作業末の検査を完了した。** B_WORK と HEAD はともに `079397f3c36b866091ec8dcb1783cfb4ccef9033`、ブランチは `mod012/L25T` である。着手時の差分はなかった。取りまとめによる独立レビューと受け入れは、この実装担当の点検とは別に行う。

## 実装と設計書

| 対象 | 変更と確認 |
|---|---|
| `Eval.lean` / `standardCallHead` | `.funName declaration [] []` に加え、`.primName declaration [] []` を認めた。出現表と標準束縛表、元キー、宣言の一致、引数位置と型の照合は既存のままである |
| `Sound.lean` / `targetOperationAt` | 同じ二種類の頭を認める。型引数・エフェクト引数を持つ funName も位置の認定から除き、認定の集合をそろえた。`target_at_tables` と `call_binding_target` の証明を両方の頭へ接続した |
| 位置の補助定理 | `target_at_function` を引数のない funName の等式に合わせ、同じ等式を primName について述べる `target_at_primitive` を追加した。これは内部の位置同定を説明する補助定理であり、公開入口の主定理の言明は変更していない |
| `BudgetScan.rangeCall` | 本文の変更は不要だった。既存の `standardCallHead` 呼び出しを通じて、同じ二種類の頭だけが出現表・標準束縛表を照会する。Range の規則では、その後の funName だけの条件を保つ |
| `DomainExamples.lean` | 組み込み20宣言を primName、包み7宣言を funName とする実際の分類へ直した。27宣言について両引数順・域内・域外・交差・Top・Bottom、評価の失敗原因と trace を確認する。型引数・エフェクト引数付きの頭、辞書付きの頭、メソッド、操作の除外を同じ有効な二表で確認する |
| `FixedDomainExamples.lean` | Byte.shiftLeft の位置同定を primName の頭と `[a,n]` の二引数で確認する。操作の位置は none のままである |
| 01-12・07-04 | 固定域、標準束縛表の入力条件、位置、予算の照会の頭を両種類へそろえた。Range の具体規則は funName に限ることと、固定域の規則は別名を含む純粋なシフトの宣言だけに付ける条件を保った |

funDicts・opDicts・methName・opName と型引数・エフェクト引数のある頭は、表の照会前に除く。固定域の警告の範囲をシフト以外へ広げていない。言語の型・エフェクトの規則、Rust、A11 の固定表と生成器、plan.md・decisions.md、ツールチェーンと `formal/lakefile.toml` は変更していない。private/ とそこを指すリンクは読まず、git の変更操作と担当の委任も行っていない。

## 中心二命題・主定理・参照する定義の差の向き

[点検器](audit.py)と[詳細](audit.json)で、中心二命題を含む24定義の本文、公開入口の主定理28件の言明、Interval の外の204個の Lean ファイルの一致を確認した。全 Lean ファイルの名前付き定理の言明を照合し、差は上記の `target_at_function` の修正と `target_at_primitive` の追加だけだった。中心二命題の本文・前提・結論、既存の主定理の言明は変更していない。

| 定義・保証 | 基準からの差と意味の向き |
|---|---|
| `NormalSoundness`・`WarningSoundness` | 本文が一致する。正常評価・到達・予算の条件を追加せず、拒否原因の一致を前提へ移していない。評価の認定が増える影響は次の行のとおりである |
| `EvalPartial`・`Unmodeled`・`UnknownAt` | 本文は一致する。`rangeCallBinding` の共通の頭が広がるため、二表・引数型・位置を認定した単相の primName のシフトだけが、未知の任意の正常値・失敗から既存の固定域の具体規則へ移る。依頼で指定された認定範囲の拡張であり、別の振る舞いの仮定や評価規則を追加していない |
| `ConcreteValue`・`ConcreteValue.type`・`EvalInput`・`Reached` | 本文が一致する。具体値の集合と型、事象への到達、キーと演算の一致を変えていない |
| `AbstractSlot`・`AbstractEnv`・`SlotModels`・`LocalsModels`・`Models` | 本文が一致する。二表の一致という条件を保ち、正常値の既知性・純粋性・標準実装との一致の前提を加えていない。Models を強めていない |
| `StandardRule`・`StandardBinding`・`EvalStandard` | 本文が一致する。新しい規則、標準 API の振る舞いについての仮定、操作の具体規則はない |
| `standardCallHead`・`rangeCallBinding`・`BudgetScan.rangeCall` | 前者だけを変更した。単相の primName が共通の二表を照会し、固定域の条件を通れば認定される。後二つの本文と照会後の順序・回数は一致する。Range の具体規則は funName のままである |
| `targetOperationAt`・`WarningLocated` | 前者は単相の primName を位置に加え、型引数・エフェクト引数付き funName を位置から除く。後者の本文は一致する。primName の認定による位置の集合の拡張と、認定しない引数付きの位置の除外による保証の強化を区別する |
| `arithmeticOperationAt`・`concreteRule`・`syntacticReachChildren` | 本文が一致する。算術の演算の同定と、構文だけで辿る子の候補を変えていない |
| `WarningOperationSyntax`・`InSyntacticReach`・CallReach | 本文は変更していない。共通の頭の認定を通じ、認定した primName のシフトの根と引数が既存の固定域の警告範囲へ加わる。未認定 call・操作・利用者関数の内側の除外は保つ |
| `RangeLocalFact`・`RangeLocalFact.Models`・`RangeState.Models` | 本文が一致する。Range の成功値と内部の保存関係を強めていない |
| `EvalClosed` | 本文は一致する。共通の認定により、primName のシフトにも既存の域外の拒否・域内で許す unknown の失敗を計算する。`evalClosed_sound` の言明は一致する |
| 式・本体・全体・独立入力の公開入口 | 主定理の言明を保ち、上記の認定範囲へ再接続した。シフトの追加以外の警告範囲を増やさず、算術の系と未認定 call の内側の除外を保つ。予算の状態機械は変更していない |

`target_at_function` は、従来の任意の型引数・エフェクト引数の位置の等式から、現在認定する空の二列の等式へ変更した補助定理である。この変更を「すべての言明が一致した」とは扱っていない。位置の述語自体が認定しない頭を除くための変更であり、公開の正常値・警告原因・位置・到達可能性・独立入力の主定理を弱めるものではない。

[公理の照会入力](axioms.lean)と[出力](axioms.log)で16宣言を照会した。依存は `propext`・`Classical.choice`・`Quot.sound` の範囲内で、`fixed_at_disjoint_failed` は `propext`・`Quot.sound` だけだった。sorry・新しい公理・Builtins.Assumptions の追加はない。追加行に `admit`・`native_decide`・`decide +kernel`・`implemented_by`・外部実装指定・計算上限の変更もない。D15 の停止条件に当たる必要は生じなかった。

## 例と退行の確認

test-audit の作成時の関門を通した。守る契約は、実際の名前解決の分類でもシフトの固定域の解析・評価・位置が接続し、操作や引数付きの頭は接続しないことである。primName を認定しない退行、両方の頭を引数の有無によらず認定する退行、辞書や操作を認定する退行で失敗する。従来の例はシフトの頭をすべて funName としており、この欠落を捕まえなかったため、既存の表形式の例を実際の分類へ直した。本番の差し込み口や公開範囲は増やしていない。

27宣言×2引数順×7区間の378解析と、27宣言×2引数順×4整数の216評価を既存の #guard で確認する。包み7宣言には Integer64 の三つ、UnsignedInteger と UnsignedInteger8 の各二つを含む。上端、期待する警告のキーと原因、具体評価の失敗と trace は対象の計算から生成せず、独立に指定した。二表の不在・偽装・元キーの違い、位置の重複と欠落、子の失敗・return、操作の未知の導出の既存例も保つ。新しい除外表の9種類の頭には、型引数付き primName と opName を含む。

修正前のビルド済み定義へ新しい例を渡し、期待値不一致を確認した（[記録](regression-clean-domain.json)・[出力](regression-clean-domain.log)）。primName のシフトが認定されず、解析・評価の #guard が失敗する。また、従来の位置の述語は型引数付き funName を認めるので、除外の表も失敗する。最初の試行には、例のエフェクト引数に存在しない Eff.var を書いた誤りもあった（[初回](regression-domain.log)）。Eff.mk に訂正して、構文・型の誤りによらない上記の失敗を確認した。修正後は同じ例が通った。解析器・評価器を具体の入力で走らせる例は #guard であり、カーネルの計算へ展開していない。

例の差分は追加47行・削除20行、例以外の formal は追加17行・削除7行である。既存の例の削除はなく、表の入力と共有の組み立てを修正した。Rust の本体・テストの差分は0行である。

## 保存済みの予算の固定表への影響

[採取器](reference-impact.py)で保存済みの A18a の実交換から Range の解決済み宣言を読み、既存の budget-reference.lean と summary-reference.lean を新しい Lean で**各一度だけ**順に実行した。前者は71.083秒、後者は17.129秒、終了0である。どちらも `-M 6144`・300秒上限とした。既存の StandardBinding の第三欄の既定値 `[]` を一時入力で明示したほかは、入力式・予算・選択規則・期待値を変更していない。A11 の表・生成器・入力を含む7ファイルは基準とバイト一致し、ハッシュを audit.json に残した。

[全差分](reference-impact.json)と[採取結果](reference-output/)を参照。変更は同じ `(name,kind,cap)` の列が異なる行、追加は最小完走予算が増えた結果として既存の選択規則が選ぶ新しい行である。

| 表 | A18 後の保存済み行数 | L25T の選択行数 | 同じキーの変更 | 追加 | 削除 |
|---|---:|---:|---:|---:|---:|
| body | 18,336 | 18,342 | 158 | 6 | 0 |
| whole | 6,304 | 6,304 | 0 | 0 | 0 |
| summary | 6,304 | 6,304 | 0 | 0 | 0 |

| body の形 | 最小完走予算の旧→新（本体操作/本体保持/全体操作/全体保持） | 変更行 | 追加行 | 原因 |
|---|---|---:|---:|---|
| with | 22/21/22/21 → 23/21/23/21 | 52 | 2 | 資源取得の `openResource = .call (.primName "open" [] []) [] [] .nil` を独立解析する際、rangeCall が出現表を一参照するようになった。apiAt は none なので標準束縛表の走査はない。増分は操作1回 |
| nestedWith | 40/33/40/33 → 42/33/42/33 | 106 | 4 | 入れ子の二つの with の openResource をそれぞれ独立解析する。同じ primName の call の照会が二回増え、操作2回となる |

変更列は operations・saved・peak・next・stop・independent・unsupported で、警告列自体は変わらない。小予算では増えた照会のために停止位置、保持済みの内容、分類も変わる。ほかの body の108形に差はなく、whole・summary は行順と全列が一致した。保存済みの表は書き換えていない。A19b は最初にこの照会の順序・回数を Rust とそろえ、その新しい状態で固定表を作り直す必要がある。

生の計算出力は [raw-logs.zip](reference-output/raw-logs.zip) と[索引](reference-output/raw-logs-index.json)、交換由来の宣言は [range-bindings.json](reference-output/range-bindings.json) に保存した。

## 検査と計測

実行場所は `<repo>`、固定版は Lean 4.34.1・Rust 1.98.1である。Cargo には既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。rtk・japanese-tech-writing・test-audit を適用した。

| 検査 | 結果・時間 | 記録 |
|---|---|---|
| 依存順の逐次ビルド | 既定7ターゲットに必要な264モジュールを依存順に確認し、すべて終了0。Sound 32.367秒、Examples 2.436秒、DomainExamples 0.675秒 | [build.py](build.py)、[ログ](development-logs.zip)、[終了状態・ハッシュの索引](development-logs-index.json) |
| 例の直接検査 | DomainExamples 0.583秒、FixedDomainExamples 0.363秒、`-M 6144`、終了0 | [Domain](final-domain.json)・[FixedDomain](final-fixed-domain.json) |
| 公理照会16宣言 | 終了0、0.637秒 | [記録](axioms.json)・[出力](axioms.log) |
| 既定ターゲットの事前確認 | `lake --no-build build`、終了0、0.147秒。未更新のビルドを残していない | [ready.json](ready.json) |
| 指定と同じ dry-run | 終了0、0.012秒。三単位だけの選択と理由を確認 | [dry-run.log](dry-run.log)・[記録](dry-run.json) |
| spec_tally | 集計器の自己検査と仕様参照の集計が成功。初回リリース版の完了条件の未記入は none | [work.log](work.log) |
| spec_examples | 7件成功、失敗0、ignored 0、3.12秒 | 同上 |
| formal_build | 既定の lake build と sorry の拒否が成功 | 同上 |
| 作業末検査の本体 | **終了0、76.551秒。指定の三単位を一度だけ実行** | [work-check.py](work-check.py)・[本体の記録](work-check.json) |
| 外側の `/usr/bin/time -l` | 終了1、76.585秒。real/user/sys は76.58/450.68/62.11秒。`time: sysctl kern.clockrate: Operation not permitted` により **maximum resident set size はサンドボックスの制約で取得不能**。未取得を0とせず、取得のための再実行はしていない | [work.json](work.json)・work.log |
| 定義・主定理・固定表・差分 | 24定義・28主定理・204ファイル・固定表関連7ファイルの照合が成功。`git diff --check` も成功 | audit.json・[最終点検](final-review.json) |

作業末の実コマンドは次である。先に同じ指定へ `--dry-run` を付けた。

```sh
scripts/check.sh --level work --base 079397f3c36b866091ec8dcb1783cfb4ccef9033 --only formal_build,spec_examples,spec_tally
```

work-check.py がこのコマンドを呼び、外側を `/usr/bin/time -l` で包んだ。逐次ビルドは [build.py](build.py) と [run.py](run.py) により共有ロック・依存順・一モジュールごとの実行を保ち、Lake に複数の未ビルド依存を渡していない。Lean は常に一つだけとし、ビルドを背景に残して別の作業へ進まず、終了状態を確認してから次へ進んだ。ビルドの `-M 12288` は保持した。試しの計算・例・公理の直接検査は `-M 6144`、Sound は175秒、Examples は25秒、参照計算などは300秒の上限とし、時間・メモリ上限による停止はなかった。

最終点検器の初回は、自分が作る final-review.json を作成前にリンク先として確認して失敗した（[記録](final-review-first.json)）。その出力だけ作成後に存在を確認するよう点検器を直し、全リンク・ログのハッシュ・パスの伏せ方・Python の構文・六入力のハッシュを確認して成功した。これは点検器の訂正であり、Lean・設計書・検査の入力を変更していない。

## 取りまとめへの引き渡し

L25T の指定範囲に未完・不合格は残っていない。範囲の変更と4時間上限による中断はない。新しい評価規則・公理・中心二命題の変更や公開入口の主定理の弱化を要しなかった。補助定理と位置の述語の変更は上記のとおり明示した。指定の作業末検査後に Lean・設計書を変更していない。別の状態の検査結果を引用して省いた検査はない。

| 次の手順 | 担当・引き渡す内容 | 見込み |
|---|---|---|
| 独立レビュー・受け入れ | 取りまとめ。共通の頭、二表、評価と警告の範囲の意味、補助定理の変更、固定表の差を確認する | 不明 |
| 計画・判断の反映 | 取りまとめ。plan.md・decisions.md の「funName だけの照会」「固定表が A18 と一致する」を今回の二形の差に合わせる | 不明 |
| Rust の接続・局所検査・work | A19b。primName と funName の共通の照会、上記の操作数の増分、domainEntry/domainCallShape/selectArguments をそろえ、新しい Lean から固定表を作り直す | 計画の1〜3時間。固定表更新の追加時間は不明 |
| 診断・文書・交換・VM 比較、各検査と受け入れ | A21 と後続の比較担当。固定域の対象は引き続き純粋なシフトだけとし、操作・HTTP の欄を対象へ戻さない | 計画による。今回未測定の時間は不明 |

Rust/Lean の全関係状態、実 VM、stage・change・release、性能測定は本枝の担当範囲では実施していない。コミット・取り込み・docs/todo の更新・保管・公開は取りまとめの担当である。

## 取りまとめのレビュー（2026-10-26）

受け入れる。取りまとめも基準 `079397f3` と作業ツリーを比べ、中心二命題・`SlotModels`・`Models` の定義の本文が一致し、sorry・公理・`decide +kernel` の追加がないことを確かめた。`standardCallHead` は `.funName declaration [] []` と `.primName declaration [] []` だけを認定する。予算の固定表の差は body の `with`・`nestedWith` の二形（158 行の変更と 6 行の追加）で、A19b の最初で Rust の照会を揃えて作り直す（計画の変更（2026-10-26、A19a を受けて））。
