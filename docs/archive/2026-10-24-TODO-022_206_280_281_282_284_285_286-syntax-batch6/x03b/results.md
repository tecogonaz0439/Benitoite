# X03b の結果

着手（最初の時刻取得）: **2026-10-26 22:42:20 JST**。終了（実装・指定検査・最終点検と記録）: **2026-10-26 23:06:09 JST**。所要時間: **23分49秒**。

**状態: Range の実 VM 比較、局所の正負例、指定 work と最終点検を完了した。独立レビューと受け入れは取りまとめへ渡す。**

B_WORK と HEAD は `8b6feef2b36ae2a379c15ed5474b159d3622435f`、ブランチは `mod012/X03b`。着手時に差分はなかった。AGENTS.md、共通依頼文、plan の前提・契約・X01〜X05・X03b の検査・RV-C5 後の変更、D4 の変更・D5・D17・D18・D20・D21、指定された L26〜L29S・A16〜A18・A19〜A21・X01〜X03a の申し送り、RV-C5 を確認した。rtk・test-audit・japanese-tech-writing を適用した。

## 実装した範囲

| ファイル | 変更と目的 |
|---|---|
| `crates/benitoite/tests/desugar_export/interval/vm.rs` | 既存の一つの表形式の書き出しを共用し、Range の元・標識付きソースを `range/` へ加えた。実宣言から作った標準表と元キーで直接 call を同定し、頭を除いた引数をソース順に局所束縛へ取り出す |
| 同 `vm-range.bnt` | 一度保存した Result、直接射影、名前付き引数の評価順、第一・第二引数の失敗、引数の return を加えた。A18 の `range.bnt` と合わせ、単一の import を別名 R にして同じ解決済み宣言へ渡す |
| `formal/tests/interval_range_vm.py` | 既存の `range-expectations.json` と手計算の期待を読み、値・三欄・Error の構成子と保存引数・逆転優先・射影・算術失敗・到達順を、閉じた評価と実 CLI で比較する |
| 同 `interval_vm_compare.py`・`test_interval_exchange.py` | 標識除去後の構造照合を三引数の call へ広げ、出現表で同定した Range の直接名だけを具体規則として受け付ける。既存の `--vm-dir` から Range も起動し、五 profile の独立期待値・算術39件・繰り返せる解析比較を維持する |
| 07-04・交換の README | A18 の未接続だった実 VM 比較の入口と観察の境界を記した。minimum/maximum を具体規則へ加えず、一般の call と引数付き本体を実行比較へ入れない |

本番 Rust・VM 本体・安全点・標準ライブラリを変更していない。Lean の定義・定理・公理・`formal/lakefile.toml` の `-M 12288`、予算の上限・固定表、割り当て量の入力・上限・期待も不変である。既存六入口の本文・sidecar・manifest は変更していない。

## 比較の結果と境界

| 対象 | 結果 |
|---|---|
| Range の閉じた評価と実 VM | **37関数一致、正常な復帰33件・算術失敗4件、評価の除外0件**。算術失敗は射影後のあふれ2件と先行引数の除数0の2件 |
| Range の到達 | **選んだ80対象演算のうち68事象に到達し、順序が一致**。残る12演算は Error の腕、先行引数の失敗・return により未到達。書き出し全体は観察専用を含む96対象演算 |
| 境界と三欄 | 下端・上端・一点・Integer64 の両端について、正常な Result.Ok の三欄を公開の minimum・maximum・value で順に観察した。入力と契約順の trace は十進文字列で比較した |
| Error と失敗優先 | 逆転の内側・外側はともに InvalidBounds(10,0)。範囲外の両側は OutOfRange の三入力を保持した。正常な Result.Error と異常終了を区別し、Error 側では直接 value が未到達であることも照合した |
| 成功値の同一性 | 同じ入れ子の二検査から内側105と外側5を別々に射影した。一度の Result 保存、import の別名、射影後の正常な加算10とあふれも比較した |
| ソース順と未到達 | `argumentOrder` は value の加算、maximum の加算、minimum の減算、親 call の順。第一引数の失敗では最初の除算だけ、第二引数の失敗では最初の加算と次の除算だけへ到達した。引数の return では標識なしで42を返した |
| 実行比較へ入れる前の分類 | 元ソース46関数のうち、引数付き・一般の call・三欄の観察専用の9本体を理由付きで `selectedOut` に残した。偽の同定は既存の解析・独立期待値の対象であり、この実行比較へ入れていない |
| 別個体の独立観察 | `unrelatedCaller` の実 VM は、呼び出し元の検査、別関数の検査、その引数の射影の順で標識を出し、105を返した。この一実行は閉じた評価との37件へ加えず、関数本体へ呼び出し元の由来を渡していない |
| Range 比較器の負例 | 出現表の同定なし、Result の構成子、minimum、maximum、value、逆転優先をそれぞれ壊した6種類を拒否した |
| 既存の算術・フロー | **39関数・70事象の実 VM 比較を維持**。閉じた pipe への出力失敗 R0201 の一実行は正の件数と分け、標識出力の失敗を対象算術の失敗へ数えない |
| 元・標識付きソースの通常解析 | 算術39+39本体、Range46+46本体の **計170本体**を Rust と Lean で比較した。深さ・本体/全体予算・番号の停止、未解析は全て0件。未対応は順に0・37・7・45本体であり、標識用 Console と観察専用の形を含む |

[Range の要約と元キー・位置](range-vm-summary.json)、[算術・フローの要約](arithmetic-vm-summary.json)、[通常解析の要約](real-source-summary.json)、[五 profile の記録](profile-manifest.json)を保存した。全入力と報告・実 CLI の標準出力・診断、途中の比較の失敗も [ZIP](local-records.zip) と [SHA-256 の索引](local-records-index.json)に保存した。

minimum/maximum は実 CLI の main で三欄を観察するためだけに呼ぶ。Lean の評価規則へ追加していない。成功値と Error の全体は閉じた評価の具体的な構造値と独立期待値へ照合し、VM では公開の射影または Error のパターンで読む。value だけの一致で三欄の一致を代用しない。一般の call を含む `unrelatedCaller` の105は、独立した VM 観察である。未知を含む入力を、閉じた評価との値の一致へ混ぜていない。

元の Surface と追加した束縛・標識を除いた Surface は、観察専用を含めた全46関数で構造を照合した。元番号と標識追加後の演算番号・演算位置・標識位置を別に保存している。評価専用の入力だけ、X03a と同じく根と根の型対応を本体の Unit へ戻す。末尾 return の型を元対応表で確認し、本文・子の型・元キーと通常解析の材料は保つ。返された具体値と trace の期待を、Rust の正常近似から作っていない。

この有限の比較により A18 が X03b へ渡した実本体との接続を確認した。全入力での意味保存、シフトの実 VM 比較、既存六入口を含む最終全比較と K1 の完了は結論しない。

## 検査と途中の失敗

実行場所は `<repo>`。[run.py](run.py) がコマンド・終了状態・外側時間とパスを伏せた出力を保存する。Cargo は `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。局所比較は既存ビルド済みの intervalDiff を逐次起動し、別の Lean ビルドと並行させていない。

| 検査 | 結果・記録 |
|---|---|
| 最終の書き出し | **終了0、4.647秒**。算術80演算・Range96演算の元と標識付きソース（[記録](export-complete.json)・[出力](export-complete.log)） |
| 最終の局所比較 | **終了0、15.646秒、intervalDiff 170起動**。Range37件、既存算術39件、独立 VM 観察と出力失敗の各一件、四つの実ソースの通常解析、既存五 profile の正負例を含む（[記録](comparison-verified.json)・[出力](comparison-verified.log)） |
| 作業途中の割り当て量二件 | **両方成功、11.328秒**。20,000定数は442,858,487バイト、5,000定数・1,000診断は254,972,750バイト。X03a と同じで、上限512 MiB・256 MiB、入力と期待は不変（[記録](allocations.json)・[出力](allocations.log)） |
| 同じ基準・指定の dry-run | **終了0、0.094秒**。fmt、examples を含む clippy、全 lib、全統合、ソース規約、生成 Skill、仕様集計、Lean の既定ビルドの8単位を確認した（[記録](dry-run.json)・[出力](dry-run.log)） |
| 指定 work | **検査本体終了0、471.883秒、8単位成功**。lib 1,332件成功・失敗0・ignored 21、全統合40ターゲット・394件成功・失敗0・ignored 10（[本体](work-check.json)・[全出力](work-check.log)） |
| 最終点検 | **終了0**。7入力のハッシュ、757保護対象、Python の構文、件数、記録のパス、ZIP と索引、結果の相対リンク、git diff --check を検査後も照合した（[点検器](audit.py)・[結果](self-review.json)） |

指定 work は、同じ指定の dry-run の後に次を一度実行した。Rust と crates の比較入力を変えたため、統合ターゲットを絞っていない。

```sh
scripts/check.sh --level work --base 8b6feef2b36ae2a379c15ed5474b159d3622435f
```

**最大常駐量（maximum resident set size）は取得できなかった。** `/usr/bin/time -l` は検査本体の終了0の後、`sysctl kern.clockrate: Operation not permitted` となり、外側は終了1だった。real/user/sys は471.90/1382.33/74.96秒である（[外側の記録](work.json)・[出力](work.log)）。未取得を0とせず、計測だけの再実行はしていない。指定 work の失敗・再実行はない。

最終の局所比較の指定は次のとおりである。

```sh
BENITOITE_DESUGAR_DIFF_DIR=target/interval-diff/x03b cargo test -p benitoite --test desugar_export export_interval_vm -- --nocapture
python3 -B formal/tests/test_interval_exchange.py --vm-dir target/interval-diff/x03b --rust-dir target/interval-diff/x03b/original --rust-dir target/interval-diff/x03b/instrumented --rust-dir target/interval-diff/x03b/range/original --rust-dir target/interval-diff/x03b/range/instrumented --output target/interval-diff/x03b/comparison-verified
cargo test -p benitoite --test call_allocations constant -- --nocapture --test-threads=1
```

書き出しの初回は標準表を作る補助へ渡す引数の型を誤り、コンパイルで失敗した。既存の `named_builtin_tables` から得る表へ直した。比較専用入力の作成中には discard の構文、Console の import の不足と unofficial の名前、同じ Range モジュールの二重 import を通常の検査が拒否した。ワイルドカード bind と既存の unofficial import を使い、Range は一つの import の別名 R に統一した。export-first〜export-final の記録に失敗を保存し、export-final-2 と最後の export-complete は成功している。

比較器の初回は既存の未知の負例にエラー理由を付け忘れ、その負例の自己検査で失敗した。次は本体名を除いた番号だけで出現表を引いてしまい、同じ番号を持つ他関数との混同を検出した。本体ごとの出現表へ限定した。次は全標準表にシフトの宣言もあるのに range profile を選んだため、厳密な読者が拒否した。通常交換の表と同じ domain profile を使う形へ直した。その後、二重 import の書き出し失敗の直後に古い材料で比較を起動した一回は、新しい関数の欠落で停止した。書き出しの成功を待ってから最終比較を行った。これらは compare-first〜compare-third と comparison-final の記録に残した。古い材料での失敗を実装の一致へ数えていない。Lean の規則・予算・固定表・警告の期待を変えて通したことはない。

## 最終点検と申し送り

[work の入力ハッシュ](work-inputs.json)を固定した後、実装・比較入力・文書を変更していない。最終の work の後は結果と点検の記録だけを更新した。[bundle.py](bundle.py) は局所比較の4,066ファイル・相対リンク4件を保管し、保存した bytes のハッシュを ZIP から読み戻して照合した。手元の絶対パスは記録・ログ・保存スクリプトに残していない。

作成時の関門では、同じ実ソースの Range の評価規則と実 VM の三欄・Error・優先順・同じ成功値の射影・到達を独立した契約とした。現実的な退行は、引数のソース順と契約順の混同、別の成功値の射影、三欄の取り違え、逆転を範囲外より後に検査すること、子が失敗した親の標識の捏造、名前の字面だけの標準認定である。既存の算術比較と静的解析比較は実 VM の Range の三欄・Error を読まないため、同じ書き出しと比較の境界を拡張した。本番の観測口・フラグ・注入用引数やテストダブルは加えていない。既存テストの削除はない。

本番 Rust の増減は0行、Rust のテストは33行追加・6行削除、比較用 bnt は33行追加、Python の比較は267行追加・6行削除である。Rust のテスト関数は増やさず、既存の一つの表形式の書き出しを拡張した。結果記録・保管・点検のスクリプトはこの集計に含めていない。

計画の範囲の変更、停止条件への該当、4時間の上限による中断はない。言語の規則・既存の本番 Rust の型や署名・Lean の定義・主要定理・公理・予算固定表の変更を要する判断は残っていない。private/ とそのリンク、担当の委任、git の変更操作、コミット・取り込み・docs/todo の更新・保管・公開は行っていない。stage・change・release・check-formal.sh 全体は本枝の割り当てでは実施していない。別状態の検査結果を引用して省いた検査もない。

| 残る手順 | 担当と受け渡す内容 | 見込み |
|---|---|---|
| X03b の独立レビュー・受け入れ | 取りまとめ。三欄の観察、出現表の本体ごとの同定、元と標識付きの構造・位置、選択前の分類と検査の関係状態を確認する | 不明 |
| 案III の実行比較・検査・レビュー・受け入れ | X03c と取りまとめ。現状の require_closed は Range と算術・フローだけを許す。域内 unknown と Byte の評価不能を厳密な比較へ加えず、操作と HTTP を対象へ戻さない | 計画の実装・記録2時間。検査・レビュー・受け入れの追加時間は不明 |
| 全比較の接続・K1・検査・レビュー・受け入れ | X04〜X05 と取りまとめ。`--vm-dir` は Range まで含む。元・標識付きの通常解析は四つの `--rust-dir` も使う。既存六入口を含む全比較は別に実施する | 計画による。今回未測定の時間は不明 |

## 取りまとめのレビュー（2026-10-26）

受け入れる。変更はテスト側の比較と比較用の bnt・Python・07-04 の記述で、本番の Rust・VM・安全点・Lean の定義は変わらない。Range の37件が実 VM と一致し、D18 の三欄・逆転の優先・射影を比べた。未知を含む9本体は理由付きで比較の前に分けている。最初の起動は Codex のモデルの混雑で途中で終わり、10 分あけた二回目で完了した。X03c へ進む。
