# V10.1dr: 版上げ後の全比較の影響段の記録

## 作業と判定

2026-10-30 JST、記録担当。B_WORK・対象 HEAD は `7179a3026fcf2b463c1ec933aefd23256be6dc93`、ブランチは `m013/v10.1d` である。取りまとめが版上げ後に実行した影響段と、K10.3/K10.3b から引用した不変段を合わせ、**この関係状態に対する全比較の成功を引用できる**と判断する。既存の比較件数の減少・除外の増加はなく、H31 の2群2定義だけが加わった。義務の行35は、下記の根拠により閉じてよい。独立レビューと設計者の受け入れは別である。

本作業は保存済み出力の読解・ハッシュ照合・文書化だけである。`private/` と同所を指すスキル、`docs/todo/` は読まず、書込みは本ディレクトリだけに限った。本番・設計書・テスト・計画・元のログ・出力を変更せず、git の状態を変える操作、ビルド、テスト、`lake build`、`scripts/check-formal.sh` は実行していない。以下の「実行」は、取りまとめが既に行った V10.1d の実行を指す。

判断の正は [README の設計者の決定](../README.md)、[plan-v10 の F-Q と停止条件](../plan-v10.md#全比較の入力と引用)、保存の規約は [07-03「結果の保存と引用」](../../../design/07-quality/07-03-compiler-testing.md#結果の保存と引用)である。設計者の委任による取りまとめの2026-10-30の判断として、不変段は引用し、J2・H31 と実 CLI の変化に影響される段だけを走らせ直した。全比較の入口全体の終了0を新たに得たとは記さない。

## 段ごとの実行と引用

コマンドは [phase-a.sh](phase-a.sh)・[phase-b1.sh](phase-b1.sh)・[phase-b2.sh](phase-b2.sh)の `step` へ渡す引数を記した。各 `step` は対象を直接 `/usr/bin/time -l` で包む。`OUT=<wt>/target/desugar-diff/v10.1d`、`COV=<wt>/target/coverage-diff/v10.1d`、`INT=<wt>/target/interval-diff/v10.1d`、`CLI=<wt>/target/debug/benitoite` とする。三つの `BENITOITE_*_DIFF_DIR` は順に OUT・COV・INT である。`log` は元ログの保存先、`here` は B1 の第3引数の台本置場である。外側の台本の呼出し argv 自体は保存されていないため、この二引数の実値を推測して補わない。台本6件の写しは本ディレクトリにある。

real は元の OS time の小数秒、最大常駐量は `maximum resident set size` のバイト原値と GiB（2^30 bytes）である。`peak memory footprint`、プロセスの合計、K10.3 の getrusage による補助値とは区別する。[機械可読な採録](stages.json)にも残した。

| 段 | コマンド | 終了 | real秒 | 最大常駐量 bytes / GiB | 件数・内容 | 実行か引用か |
|---|---|---|---:|---:|---|---|
| [A: coverage書き出し](coverage-export.log) | `cargo test --test coverage_export -- --include-ignored --nocapture` | 0（直接記録） | 34.27 | 3,839,557,632 / 3.575867 | 4成功・失敗0・ignored0・filter0。境界20＋乱数10,000、予算停止0 | 実行 |
| [A: Rust書き出し（区間を除く）](rust-export.log) | `cargo test --test desugar_export -- --include-ignored --nocapture --skip export_interval` | 0（直接記録） | 1,316.20 | 706,002,944 / 0.657516 | 45成功・失敗0・ignored0・filter4。1,792入力、1,373書き出し・419検査除外・対象外0 | 実行 |
| [A: interval identity](interval-identity.log) | `env BENITOITE_DESUGAR_DIFF_DIR="$INT/identity" cargo test --test desugar_export export_interval_identity -- --nocapture` | 0（直接記録） | 4.52 | 182,829,056 / 0.170273 | 1成功・失敗0・ignored0・filter48 | 実行 |
| [A: interval manifest](interval-manifest.log) | `env BENITOITE_DESUGAR_DIFF_DIR="$INT/manifest" cargo test --test desugar_export export_interval_manifest -- --nocapture` | 0（直接記録） | 8.58 | 524,828,672 / 0.488785 | 1成功・失敗0・ignored0・filter48 | 実行 |
| [A: interval range](interval-range.log) | `env BENITOITE_DESUGAR_DIFF_DIR="$INT/range" cargo test --test desugar_export export_interval_range -- --nocapture` | 0（直接記録） | 2.84 | 130,482,176 / 0.121521 | 1成功・失敗0・ignored0・filter48、11入力 | 実行 |
| [A: interval VM](interval-vm.log) | `env BENITOITE_DESUGAR_DIFF_DIR="$INT/vm" cargo test --test desugar_export export_interval_vm -- --nocapture` | 0（直接記録） | 3.52 | 177,422,336 / 0.165237 | 1成功・失敗0・ignored0・filter48、80/96/108操作 | 実行 |
| [A: CLIビルド](cli-build.log) | `cargo build -p benitoite --bin benitoite` | 0（直接記録） | 21.18 | 3,888,660,480 / 3.621597 | benitoite 0.0.13、devビルド完了 | 実行 |
| [B1: 引用の複写](cite.log) | `python3 -I "$here/cite.py" "<wt>/target" "$log/compare.json" "$log/cited.json"` | 0（後続到達・報告） | 1.01 | 33,292,288 / 0.031006 | 3,174ファイル・46,278,779 bytes。実行したのは複写・ハッシュ照合で、読者の再実行ではない | 実行 |
| [B1: 範囲の実ソース](range-sources.log) | `python3 -B formal/tests/test_range_sources.py --exports "$OUT/range-sources" --cli "$CLI" --output "$OUT/range-source-comparison"` | 0（後続到達・報告） | 9.92 | 45,629,440 / 0.042496 | 17群20定義・非Top14群67、拒否8・除外8、報告26入力50コマンド | 実行 |
| [B1: H31の個別照合](h31-verify.log) | `python3 -I "$here/h31-final-verify.py" "<wt>" "$log/h31-final.json"` | 0（後続到達・報告） | 0.05 | 16,302,080 / 0.015182 | 2群各1定義、非Top3/7、署名・prim転送・全定義・固定ハッシュ一致 | 実行 |
| [B1: 既知差と対照](range-known-differences.log) | `python3 -B formal/tests/test_range_known_differences.py --cli "$CLI" --output-dir "$OUT/range-known-differences"` | 0（後続到達・報告） | 0.30 | 38,174,720 / 0.035553 | 名指し3入力。予定したE0711/E0459と動的受理の対照 | 実行 |
| [B2: 区間の集約](collect.log) | `python3 -B scripts/check/formal_interval.py collect --interval-dir "$INT" --desugar-dir "$OUT" --coverage-dir "$COV"` | 0（直接記録） | 101.00 | 15,986,081,792 / 14.888199 | 新しいinput-manifestと区間の入力集合を作成。最終件数は下表 | 実行 |
| [B2: 区間・実ソース・VM比較](interval-comparison.log) | [I-Cの全引数](#区間比較の全引数) | 0（直接記録） | 638.11 | 16,016,441,344 / 14.916473 | 1,852呼出、五profile、実ソース10群、VM39/37/46。予定したfuel試行は本文 | 実行 |
| [B2: check_named全体](check-named.log) | `python3 -I crates/benitoite/tests/desugar_export/check_named.py "$OUT" "$COV"` | 0（直接記録） | 339.54 | 8,901,836,800 / 8.290482 | 1,792入力・73,853定義・coverage22,483、六入口・変異拒否を照合 | 実行 |
| [B2: 最終manifest](manifest.log) | `python3 -B scripts/check/formal_interval.py manifest --interval-dir "$INT" --desugar-dir "$OUT" --coverage-dir "$COV"` | 0（直接記録） | 351.39 | 15,526,084,608 / 14.459793 | 12,904保存物を同定。全群・VM・範囲・既知差を集約 | 実行 |
| [B2: manifestの読み戻し](verify.log) | `python3 -B scripts/check/formal_interval.py verify --interval-dir "$INT" --desugar-dir "$OUT" --coverage-dir "$COV"` | 0（直接記録） | 34.63 | 150,126,592 / 0.139816 | 全入力・報告・ハッシュ・件数一致 | 実行 |

### 区間比較の全引数

I-C は B2 に保存した次の呼出しである。

```sh
python3 -B formal/tests/test_interval_exchange.py \
  --output "$INT/comparison" --source-dir "$INT/identity" \
  --rust-dir "$INT/programs" \
  --rust-dir "$INT/identity" \
  --rust-dir "$INT/manifest/manifest-interval" \
  --rust-dir "$INT/range/interval" \
  --rust-dir "$INT/vm/original" \
  --rust-dir "$INT/vm/instrumented" \
  --rust-dir "$INT/vm/range/original" \
  --rust-dir "$INT/vm/range/instrumented" \
  --rust-dir "$INT/vm/shifts/original" \
  --rust-dir "$INT/vm/shifts/instrumented" \
  --vm-dir "$INT/vm" --cli "$CLI"
```

段 A の `prepare` は `python3 -B scripts/check/formal_interval.py prepare --interval-dir "$INT" --desugar-dir "$OUT" --coverage-dir "$COV"` である。個別の終了・時間・RSS は未採録だが、`set -e` の台本で後続に到達し、段 A 全体は終了0となった。旧新の比較は [compare.py](compare.py)と保存済み compare.json による。入力は `target` と報告の出力先であり、単独起動の正確な argv・終了値・時間・RSS は保存されていない。報告の存在と内容の再照合を証拠とし、未計測を0秒・使用量0としない。

B1 は段別 `.exit` と段全体の `.out`・開始終了の記録がない。表の終了0は、`set -euo pipefail` の台本、後続段のログの存在、最終の成功報告を合わせた判定であり、直接保存された終了値とは区別する。A と B2 は [phase-a.out](phase-a.out)・[phase-b2.out](phase-b2.out)に各 `exit 0` がある。範囲比較内の予定した拒否、空の比較、区間の fuel 試行の終了1は、外側の段の失敗と混同しない。

### K10.3 から引用する段

次表の時間・件数は [K10.3 の結果](../k10.3/results.md)、[初回の段の抽出](../k10.3/f-first-stages.json)、[再確認の全引数](../k10.3/recheck.py)を引用する。旧出力先を使ったコマンドであり、今回起動したものではない。`E=formal/.lake/build/bin`、`O=target/desugar-diff/k10.3`、`C=target/coverage-diff/k10.3` とする。初回の時間はシェルの整数秒で、個別の OS time real・RSS は未取得である。再確認した三読者の時間は外側の小数秒、RSS は getrusage の補助値である。

| 段 | 元のコマンド | 終了 | 元の時間（秒） | 元の最大常駐量（bytes / GiB） | 件数 | 扱い |
|---|---|---:|---:|---|---|---|
| 既定 Lean ビルド | formal で `lake build` | 0 | 0（整数秒） | 個別未取得 | 573ジョブ、sorry検出なし | 引用 |
| 七交換実行ファイルのビルド | formal で `lake build` に desugarDiff / builtinCheck / coverageDiff / coverageProgramDiff / surfaceCheck / surfaceCheckAll / intervalDiff を各指定 | 各0 | 各0、surfaceCheck単独は未取得 | 個別未取得 | 362 / 364 / 364 / 366 / 366 / 372 / 452ジョブ | 引用 |
| coverageDiff | `$E/coverageDiff $C/named-all-corpus.json $C/report.json` | 0 | 3（整数秒） | 個別未取得 | 10,020一致、不一致・fuel切れ0 | 引用。check_named内の再確認もあり |
| view 付き coverageDiff | `$E/coverageDiff $C/future-corpus.json $C/future-report.json` | 0 | 単独未取得（旧coverage段全体23） | 個別未取得 | 10,028一致、不一致・fuel切れ0 | 引用 |
| width | `python3 -I formal/tests/test_width_exchange.py` | 0 | 2 | 個別未取得 | 独立4検査 | 引用 |
| named | `python3 -I formal/tests/test_named_exchange.py` | 0 | 2 | 個別未取得 | 独立13検査 | 引用 |
| extensible | `python3 -I formal/tests/test_extensible_exchange.py` | 0 | 6 | 個別未取得 | 独立22検査 | 引用 |
| try | `python3 -I formal/tests/test_try_exchange.py` | 0 | 4 | 個別未取得 | 独立8検査 | 引用 |
| batch2 | `python3 -B formal/tests/test_batch2_exchange.py` | 0 | 1 | 個別未取得 | 独立8検査 | 引用 |
| batch3 独立 | `python3 -B formal/tests/test_batch3_exchange.py` | 0 | 4 | 個別未取得 | 独立7検査 | 引用 |
| batch4 独立 | `python3 -B formal/tests/test_batch4_exchange.py` | 0 | 6 | 個別未取得 | 独立15検査 | 引用 |
| 範囲の独立交換 | `python3 -I formal/tests/test_range_exchange.py --output $O/range-exchange-comparison` | 0 | 1 | 個別未取得 | 独立9検査 | 引用 |
| 範囲の予算 | `python3 -B formal/tests/test_range_budget_sources.py --rust-dir $O/range-budget --output-dir $O/range-budget-comparison` | 0 | 0 | 個別未取得 | Rustだけの番号停止1、同一入力の直接比較2 | 引用 |
| batch3/4 の Rust 交換 | `python3 -B formal/tests/test_batch3_exchange.py --rust-dir $O/batch3/b3`、続いて `check_batch3.py --rust-dir $O/batch3/$profile --report $O/batch3/$profile-exchange-results.json`（profile=b3, blocks, g2, g3） | 0 | 7（段全体） | 個別未取得 | 独立7、各9/2/1/1入力・52/10/11/8定義 | 引用 |
| batch5 独立・Rust | `python3 -B formal/tests/test_batch5_exchange.py --rust-dir $O/batch5` | 0 | 2 | 個別未取得 | 独立8、32定義、formatted28・String3・fallback0 | 引用 |
| desugarDiff | `$E/desugarDiff $O/named-programs-corpus.json $O/report.json` | 0 | 51.612888 | 4,592,484,352 / 4.277084 | 73,853定義一致 | 引用 |
| builtinCheck | `$E/builtinCheck $O/named-programs-corpus.json $O/named-programs-builtins.json $O/builtin-report.json` | 0 | 30.445194 | 4,555,669,504 / 4.242798 | 144,932比較 | 引用 |
| coverageProgramDiff | `$E/coverageProgramDiff $O/named-programs-coverage.json $O/named-programs-builtins.json $O/coverage/report.json` | 0 | 4（整数秒） | 個別未取得 | 22,483一致 | 引用 |
| surfaceCheckAll | `$E/surfaceCheckAll $O/named-programs-corpus.json $O/named-programs-builtins.json $O/named-programs-stdlib.json $O/surface-check/report.json` | 0 | 54.856548 | 5,647,024,128 / 5.259201 | 51,742一致・対象外19・Q11一件 | 引用 |

surfaceCheck の個々の呼出し、width・named・batch の一部は、今回の check_named 全体にも含まれる。独立段を別に起動した意味ではなく、B2 の339.54秒に含む。区間比較内の五 profile・実ソース・実 VM も今回は B2 で再実行しており、旧918秒を今回の所要へ加えない。

## 段 A の旧新の差

旧脱糖出力は `target/desugar-diff/k10.3` に `k10.3-reexport` を重ねた合成の状態、旧 coverage・区間は各親の `k10.3` である。[compare-summary.json](compare-summary.json)は元 compare.json の要約、[phase-a-hash-audit.json](phase-a-hash-audit.json)は保存済みファイルを今回読み戻したハッシュである。

| 出力 | 旧全ファイル | A時点の新ファイル | 同一 | 変更 | 追加 | A時点でまだない旧ファイル |
|---|---:|---:|---:|---:|---:|---:|
| 脱糖 | 4,786 | 1,249 | 1,236 | 3 | 10 | 3,547 |
| coverage | 9 | 3 | 3 | 0 | 0 | 6 |
| 区間 | 8,078 | 102 | 102 | 0 | 0 | 7,976 |

右端は段 A がまだ作っていない後続の報告等であり、入力の削除件数ではない。B1 の引用と B1/B2 の再確認で補う。最終 manifest の保存物は12,872から12,904へ32件増えた。

| 変わったファイル（OUTからの相対位置） | 内容を読んで確認した差 | 影響する段 |
|---|---|---|
| `extensible-package-source/dep/package.bnt` | 先頭の `language "0.0.12"` → `language "0.0.13"` だけ。42 bytesのまま | check_named の external package の読込み |
| `extensible-package-source/package.bnt` | 同じ header の版だけ。60 bytesのまま。宣言・依存の内容は不変 | 同上 |
| `range-sources/rust-observed.json` | 旧31レコードは全欄一致したまま、H31 の2レコードが末尾に追加され33となった。ともにaccepted=true・診断なし・Required呼出しなし。署名だけの例の位置4件、転送の例13件を追加 | 範囲の実ソース、range_counts、manifest/verify |

header の全文差は [extensible-header.diff](extensible-header.diff)、観測の追加の全内容は [rust-observed-delta.json](rust-observed-delta.json)にある。追加10ファイルは、`h31-user-signature.bnt`・`h31-user-forward.bnt` と、それぞれの `named-programs-{corpus,builtins,stdlib,coverage}.json` の計8ファイルである。[追加出力の写し](h31-output/range-sources/)とハッシュ一覧へ残した。corpus は各1定義で、署名と本体の範囲の違いを含む。builtins・stdlib は各入力が使う表、coverage は両例とも空である。新しい交換形式・標準宣言の追加ではない。

## 引用した出力と読者の入力

[cited-summary.json](cited-summary.json)と元 cited.json は、B1 で写した **3,174ファイル・46,278,779 bytes** を同定する。元の `source` は `target` からの相対位置である。

| 元のパス | ファイル数 | bytes |
|---|---:|---:|
| `target/desugar-diff/k10.3/` | 3,168 | 37,323,398 |
| `target/coverage-diff/k10.3/` | 6 | 8,955,381 |

この一覧は写した時点の来歴であり、最終状態の全ファイルを「引用したまま」とはしない。元ファイルの3,174ハッシュは現在も全件一致する。写し先では389ファイルが同じバイト列のまま、2,785ファイルは後続の check_named により再生成されている。後者は JSON と JSON の標準出力ログの `checkNanos`・`preparationNanos`・`elapsedNanos`・`elapsed_seconds` だけが異なり、その他の全欄は一致した。各プログラムの surface、width、残る batch3 の4群、named の表層報告が該当する。一覧と照合の範囲は同要約に残す。これを計画外の意味の差とは判定しない。

一般 corpus の四入力と coverage の三入力は [reader-input-hashes.json](reader-input-hashes.json)で旧新の bytes・SHA-256・元のパスを個別に照合した。

| 引用する読者 | 同一である入力（OUT/COVからの相対位置） |
|---|---|
| desugarDiff | OUT の `named-programs-corpus.json` |
| builtinCheck | 同 corpus と `named-programs-builtins.json` |
| surfaceCheckAll | 同 corpus・builtins と `named-programs-stdlib.json` |
| coverageProgramDiff | `named-programs-coverage.json` と同 builtins |
| coverageDiff | COV の `named-all-corpus.json`・`future-corpus.json`。named の `named-corpus.json` も一致 |

これら五読者の大きな報告は入力が同じなので引用できる。独立交換・予算は、その読者・固定入力・期待値・Lean 実行ファイルのハッシュが不変である。Rust の対応する書き出しも A で一致した。実 CLI を読む範囲の実ソース・既知差・区間比較は、CLI の変化を無視せず再実行した。check_named が直接読む生成済みパッケージの header は変わったため、同台本全体も再実行した。

## Lean の設定・固定版・七実行ファイル

[V10.1a の relation-state](../v10.1a/relation-state.json)が参照する K10.3b 最終状態から、formal の408項目と `rust-toolchain.toml` の計409項目を照合し、**409一致・不一致0・欠落0** であった。七実行ファイルは V10.1a が保存した値とも全件一致した。[formal-hashes.json](formal-hashes.json)に409項目、[relation-state.json](relation-state.json)に設定・実行ファイルのハッシュを残した。

| ファイル | bytes | SHA-256（一致した旧新の値） |
|---|---:|---|
| `formal/.lake/build/bin/builtinCheck` | 105,558,528 | `be56b7e8ed17f3aad50d0bc7d2040afda6e5d0b571abce441966a558fc1b001b` |
| `formal/.lake/build/bin/coverageDiff` | 104,979,488 | `414952573e6aef85dd141019289cdf618e628534d923d787bc0ce0265aa0f40f` |
| `formal/.lake/build/bin/coverageProgramDiff` | 105,121,184 | `87644040a5cfd2ec5615ae98399a691ba298e4ce01498dc7228856881809e021` |
| `formal/.lake/build/bin/desugarDiff` | 105,931,152 | `3150df168046e6c4a69d63ddde07e3ef558e2e30ffbd7228cfb3f275bad24e7f` |
| `formal/.lake/build/bin/intervalDiff` | 106,504,256 | `8d136d3ec816c2c46ac9910d32d711c7b7f4100e082ecb989b58aea305fd6b52` |
| `formal/.lake/build/bin/surfaceCheck` | 107,025,072 | `967c8a654ba88a24ef8b52d984c2387d867c8ac81a07ed59da2627aef3e9e18e` |
| `formal/.lake/build/bin/surfaceCheckAll` | 107,149,696 | `adc9328681838baf58053cff432a84a8cd287acda36f0136bc8fb1014030936e` |
| `formal/lakefile.toml` | 872 | `10f2661bff8fce95a9253d976427d0ca44038ec12350c955badbc1cf1efa6e3a` |
| `formal/lake-manifest.json` | 152 | `f4a9b127f95cf577c7da1c2269f85ffd5754f76afccace5dc310d56ef8f41a32` |
| `formal/lean-toolchain` | 25 | `d5edba4e4b8faad9c1baeadb265716d20d03be4d1a2647dc5e35b0c0325bea7b` |
| `rust-toolchain.toml` | 66 | `4d7d5425fe623392e565a964fc135c563c316ce125058199eb40b2953ba6ecbb` |

固定は Rust/Cargo 1.98.1、Lean 4.34.1、Lean のメモリ指定は `-M 12288`（MiB/プロセス）である。元の環境は [K10.3 environment.json](../k10.3/environment.json)の macOS/arm64・Python 3.9.6、直前の実版は [V10.3a environment.json](../v10.3a/environment.json)を引く。V10.1d のログは benitoite 0.0.13 の test/dev、既定構成、`--include-ignored` である。本記録では実行ファイルや道具を起動せずハッシュを照合したので、Lean/elan の現在の実版を新規取得した意味を持たない。固定版の勧告の新しい照合でもない。

交換形式は corpus15・プログラムのsidecar7・独立coverage4であり、製品版0.0.13と区別する。[cli-and-producers.json](cli-and-producers.json)へ記録時点の保存済みCLIのハッシュと、報告側50コマンドの保存ログのハッシュ・producerを採録した。50件ともversion=0.0.13、commit=B_WORK、target=aarch64-apple-darwinである。dirtyはnull、由来はnotCollectedであり、CLIがcleanを報告したと読み替えない。記録時点のバイナリのハッシュを、実行時に採取した値とはしない。公開候補の全同梱物とP/P-finalの照合は後続に残る。

以上により既定ビルド573ジョブ・終了0・sorry検出なしと七実行ファイルのビルド成功を引用する。formal_build の引用と、Rust/Lean 全比較の成功は別の判定である。別 OS・32ビット・機能を外した構成へ成功を広げない。16 GB 級で余裕がないという資源上の限界は残す。今回の区間比較の最大常駐量14.916473 GiB、manifestの14.459793 GiBは OS time の値であり、旧 manifest の補助値12.993179 GiBとの差から原因や性能の増減を断定しない。

## K10.3 と版上げ後の件数

[count-comparison.json](count-comparison.json)、[範囲の全群・定義の一覧](reports/desugar-diff/range-source-comparison/source-manifest.json)、[範囲の集計](reports/desugar-diff/range-source-comparison/summary.json)、[区間の比較](reports/interval-diff/manifest-comparison.json)による。**減った段0・除外が増えた段0** であり、J3 の停止条件に当たらない。独立期待値を変更してこの一致を作ったものではない。

| 対象 | K10.3 | V10.1d | 判定 |
|---|---|---|---|
| 一般入力・書き出し | 1,792＝golden792＋random1,000。書き出し1,373・検査除外419・対象外0 | 同じ | 識別子・除外・scope・coverageの対応も check_named で一致 |
| 脱糖 | 1,075＋72,778＝73,853定義、不一致0 | 同じ | 大きな報告を引用、check_namedでも件数を確認 |
| 組み込み・表層 | 144,932比較、不一致・非収束・errors0。表層51,742一致・対象外19・Q11一件・準備失敗0 | 同じ | 入力ハッシュ一致。一般corpusの非Topは0 |
| coverage | 独立10,020、views込み10,028、プログラム22,483。不一致・fuel切れ0 | 同じ | 22,483＝match16,444＋binding6,039 |
| 範囲の実ソース | 受理15群18定義、非Top12群57、Top互換3群 | 受理17群20定義、非Top14群67、Top互換3群 | 旧15群の定義・鍵・表・非Top・coverage・全定義検査を個別に維持。追加はH31の3＋7 |
| 六入口 | desugarDiff、builtinCheck、surfaceCheck、surfaceCheckAll、coverageDiff、coverageProgramDiff | 同じ六入口 | 追加2群も全定義を検査。追加群のprogram coverageは空で、期待する終了1を非空の成功へ数えない |
| 拒否と除外 | 実ソース拒否8、E0459〜E0462の診断付き除外8、Top互換3群 | 同じ | 除外の名前・コード・理由も一致 |
| 拒否の独立入力 | 16群26定義・非Top56、三拒否の独立期待値への個別照合3、typing拒否4、独立の和の拒否1、受理対照8 | 同じ | typingをcoverの四理由へ変換しない。実ソースだけの射影拒否も保持 |
| 報告側 | 26入力50コマンド | 同じ、passed | check/test/doc、許可名等の意味の比較。実候補の全producer照合の代替ではない |
| 予算 | Rustだけの番号停止1、同一入力の直接比較2 | 同じ（引用） | 補助停止位置null/4/13、初稿6対実測4の不一致を保持 |
| 既知差 | class-structural、nul-direct、nul-dynamicの3入力 | 同じ | E0711とleanStringPrecision各1、動的対照は受理。Rust/Leanの同じ受理へ算入しない |
| check_named | 1,792入力・73,853定義・coverage22,483、width3入力30定義 | 同じ | 六入口、既存の変異拒否3/6/6、external packageも成功 |
| 区間・VM | 1,852呼出、五profile、独立定義8/9/41/7/108、実ソース10群 | 同じ | 下表の全counts・除外・比較フラグも一致 |
| 保存物 | 12,872 | 12,904 | H31追加に伴う32件増加 |

区間の十群は、入力数・定義数・本体数・検査器の成否・除外の内訳を K10.3 と照合し、`seconds` 以外の全欄が一致した。検査器の拒否や externalType の除外を、比較台本の失敗や新しい除外としない。

| 実ソース群 | 入力 | 定義 | 本体 | 検査器の成功/拒否 | 除外定義/本体 | 旧新 |
|---|---:|---:|---:|---:|---:|---|
| `programs` | 1,793 | 64,028 | 100,009 | 1,404 / 389 | 12 / 16 | 全欄一致 |
| `identity` | 24 | 195 | 198 | 24 / 0 | 0 / 0 | 全欄一致 |
| `manifest/manifest-interval` | 16 | 263 | 347 | 15 / 1 | 12 / 16 | 全欄一致 |
| `range/interval` | 11 | 65 | 65 | 11 / 0 | 0 / 0 | 全欄一致 |
| `vm/original` | 1 | 39 | 39 | 1 / 0 | 0 / 0 | 全欄一致 |
| `vm/instrumented` | 1 | 39 | 39 | 1 / 0 | 0 / 0 | 全欄一致 |
| `vm/range/original` | 1 | 46 | 46 | 1 / 0 | 0 / 0 | 全欄一致 |
| `vm/range/instrumented` | 1 | 46 | 46 | 1 / 0 | 0 / 0 | 全欄一致 |
| `vm/shifts/original` | 1 | 108 | 108 | 1 / 0 | 0 / 0 | 全欄一致 |
| `vm/shifts/instrumented` | 1 | 108 | 108 | 1 / 0 | 0 / 0 | 全欄一致 |

五 profile の analyze/eval の件数と既存除外も全件一致した。flow の eval の除外3、domain の eval の除外62を保持する。flow-containers は fuel40 の終了1・除外1、fuel80 の終了0・除外0という試行を残す。実 VM は算術39・Range37・shift46一致、shiftの独立だけの62を区別し、`unknownFailure` 46・`notClosedOrFuel` 16、Rangeの選択外9定義も元と同じである。

## H31 と義務の行35

[h31-final.json](h31-final.json)は、[V10.1b の固定期待値](../v10.1b/h31-expectations.json)と [freeze](../v10.1b/h31-freeze.json)を版上げ後の書き出しへ照合した結果である。[h31-final-verify.py](h31-final-verify.py)は、V10.1b の個別照合の出力先を V10.1d へ替えた台本で、常設比較器の拡張ではない。[RV-V10.1b 中5の対応](../reviews/RV-V10.1b.md)の申し送りを満たす。

| 入力 | 署名と本体の照合 | 定義・非Top | 結果 |
|---|---|---|---|
| h31-user-signature | Audit.logの値引数のPathInの固定添字は `/srv/audit/**`。操作の効果原子AuditはTopのまま。sampleのsurface/coreの引数型に同じ添字があり、未処理のAuditをPathInの範囲で狭めていない | sample 1定義、候補欄を除く非Top3（操作署名1＋両header各1） | 全定義を検査、期待値に一致 |
| h31-user-forward | 同じ署名に加え、ハンドラのlog節から同じ狭い型のqをFile.writeTextInへ渡す。surfaceのprimName・coreのprimはともに同じ範囲列を1回持ち、両headerの効果はFile.Writeの同じ非Top範囲 | sample 1定義、非Top7（上の3＋両headerの効果各1＋両本体のprimの範囲各1） | 全定義を検査、期待値に一致 |

`expected.json` の SHA-256 は `2e240f8fc90bfd34fca382432b1cff63cacee31c6a32cf66995187d119d9ee42`、H31期待値は `29b0cf83997ffd88c394c733a4956abaf12734dd6af42a5816de8a8f78397144` で、実行前の固定から不変である。2ソースのハッシュもfreezeと一致する。署名の添字とprimへの転送の位置・名前・範囲は個別台本が検査し、常設のtest_range_sources.pyがこの詳細まで検査するとは書かない。後者は終了・定義数・非Top件数・surface・六入口を確認する。

[義務の行35](../v10.1a/obligations.md)は、K10.2の既存の標準認定・衝突拒否・OpRefの分離に加え、[RV-UB30](../reviews/RV-UB30.md)が特定した二つの不足を最終の関係状態で確認できたため、**閉じてよい**。局所F-Lだけの成功を根拠にした判断ではなく、今回のF-Uの書き出し、六入口、個別照合、最終manifest/verifyを根拠にする。obligations.md自体は変更しない。他の未確認10行のうち本作業で新しく閉じるものはない。利用者エフェクトへの範囲引数、実行時の権限制御や情報フロー制御（information-flow control）の実装を意味しない。

## F-Q、保存範囲、失敗の来歴

07-03 の全欄を更新した [F-Q 引用票](f-q.md)を置いた。元の K10.3/K10.3b、V10.1a の初版、V10.1b の F-L と今回の F-U を B_WORK へ結び付ける。取り込み後の差分は [全506ファイル・コミット一覧](changes-after-k10.3.json)、旧入力4,680件との一致4,599・変更81件は [relation-state.json](relation-state.json)にある。変更を無視して全関係状態がバイト一致したとは判定しない。formalと固定版は409一致、変更されたloader・版・testdata・H31を通したAの出力と読者の入力一致で段ごとに判断する。

旧4,680件のうち変わった81件の読者との対応は次のとおりである。新規H31の2ソースは旧一覧の外なので、追加として別に同定した。

| 変更の区分 | 件数 | 読む段と今回の扱い |
|---|---:|---|
| crateのCargo.toml・二lock | 3 | 製品版だけの更新。AでRustとCLIを作り直した。依存と固定版の更新ではない |
| 本番のpackage.rs・text.rs・diag/codes.rs | 3 | 0.0.13の登録・案内とE0908の説明の変更。loaderを通るA、実CLIを使うB1/B2を再実行。診断の生成参照の変更も同定した |
| src内の版依存テスト | 5 | 通常work/changeが読む。交換の実行入力へテスト関数を収集しない |
| 統合テスト4ファイル・named.rs | 5 | 前者は通常work/changeの入力。named.rsの2headerはAで再出力、check_namedで再読込みした |
| range-sources/expected.json | 1 | H31の2case追加。範囲の実ソース・個別照合・range_counts・manifest/verifyを更新した |
| testdataのソース51・診断期待値5 | 56 | header50ファイルと依存ハッシュを更新。Aのloaderを経る出力が不変であることを確認。診断期待値はgoldenの入力で、交換器は読まない |
| Skillと手書き/生成参照 | 6 | 全比較のcorpus収集先ではない。埋込みCLIはAで再ビルドし、候補の同梱物はP/P-finalで照合する |
| 07-03・07-04 | 2 | 記録・保証・接続の説明。Leanの定義・交換入力を変えない |

新しい最終manifestの12,904保存物についても、比較器を実行せず内容を読み、bytesとSHA-256を全件照合した。一致12,904・不一致0、合計3,476,222,140 bytesである。[final-output-audit.json](final-output-audit.json)へ、事前固定の4入力の現在ハッシュ一致と合わせて保存した。この読解照合を、formal_interval.py verifyをもう一度実行した結果とは数えない。

ログ・報告・台本の写し50ファイル（761,414 bytes）は [saved-files.json](saved-files.json)に元のハッシュと、手元のパスを伏せた写しのハッシュを分けて同定した。台本6つ、全16段のログ、A/B2の.out/start/end、H31照合、範囲・区間・coverageの小さい報告、H31の追加10出力を含む。200 KiBを超える11ファイル（478,968,832 bytes）は写さず、[LARGE-FILES.md](LARGE-FILES.md)に大きさとSHA-256を記した。compare.json・cited.jsonの全文、大きなcorpus・表層報告・最終manifest等が該当する。要約と比較の根拠は本ディレクトリに残した。元の三出力先は読み取り専用のままである。

K10.3の先行出力先試行の終了2・0.33秒、最初の全体の終了1・2,403.15秒・最大常駐量14,372,323,328 bytesを保持する。scopeAcceptanceの欠落3入力、NoMainFileの正規化、再出力1,009件のうち1,008不変・corpus差414 bytes、準備失敗101 bytes、K10.3bのassert/policy追加、fmt初回失敗と修正を [元記録](../k10.3/results.md)から引き継ぐ。今回の実行ログに新しい外側の失敗はない。Rust exportのpanic表示は予定した拒否試験で、45成功・失敗0である。

記録作成の補助照合では、cited.jsonの写し先が全件そのままと仮定してassertに停止した。書込みは照合済みの状態・入力一覧までで、元の記録は変えていない。check_namedの生成先を読んで、後続で作り直した2,785報告の計時欄だけが異なると確認し、引用時点と最終時点を分けて記録した。比較の失敗やJ3の想定外の意味の差を隠したものではない。

## 作業末の確認と時間

段Aは元の時計で2026-10-30 04:48:43〜05:11:54、外側timeのrealは1,391.22秒である。B2は05:15:21〜05:39:46（時計の差1,465秒）、段別realの合計は1,464.67秒である。時計ファイル自体にはタイムゾーンがないので、新たにUTC/JSTを付けて断定しない。B1の外側時間は未採録、四段のreal合計は11.28秒である。16段のreal合計は2,867.06秒（約47.8分）で、段間の照合・待ち・compareの未計時分は含まない。A全体のtimeをこの合計へ二重に加えない。

本記録作業の開始の採時計は2026-10-30 05:40:12 JST（2026-10-29 20:40:12 UTC）である。能動時間と読解・ハッシュ照合の待ちを厳密には分離していない。指定の作業末dry-runと最終の範囲確認、終了時計は以下へ追記する。

指定の `scripts/check.sh --level work --base 7179a3026fcf2b463c1ec933aefd23256be6dc93 --dry-run` を一度実行した。[出力](work-dry-run.log)は `nothing to check: only documents changed`、選択0件、check.sh自身は終了0、外側0.108436167秒であった。[引数・開始終了と計時](work-dry-run.json)へ保存した。ビルド・テストの成功として数えず、最大常駐量は未計測である。dry-run後の変更は本書と最終の状態記録だけで、実検査を追加・反復していない。

最終の確認では、相対リンク・空白・用語・手元の絶対パスと禁止先リンクの不在、台本6件の写しと補助Pythonの構文、JSON、保存した写し50件のハッシュ、変更が本ディレクトリだけであること、HEAD・ブランチ・追跡木・indexの不変を確認した。[final-state.json](final-state.json)へ全成果物のbytesとSHA-256を残す。自己参照を避け同ファイル自身は対象外とする。独立レビュー・取り込みと受け入れは取りまとめ・設計者が行う。

終了の採時計は2026-10-30 05:49:12 JST、外側の所要は540.64秒（約9.0分）である。能動時間も約9.0分の概算で、読解・ハッシュ照合の待ちと厳密には分離していない。指定dry-runの待ちは約0.11秒、実検査・測定・独立レビュー・回答待ちはない。2時間の停止条件には達していない。

## V10.1db: RV-V10.1d への追補（2026-10-30）

[RV-V10.1d の対応（取りまとめ）](../reviews/RV-V10.1d.md#対応取りまとめ)に従い、初稿の本文・件数・保存記録を残して、次の箇所を補正する。初稿の `final-state.json` は初稿作成時の状態とハッシュであり、この追補後の現在の状態を示すものではない。新しい比較・書き出し・ビルド・テストは行っていない。

| 指摘 | 初稿の箇所 | 追補した内容 |
|---|---|---|
| 中1 | 「Lean の設定・固定版・七実行ファイル」末段、F-Q の「終了・時間・最大常駐量」 | 各段の最大常駐量と peak memory footprint の原値、物理メモリ、16 GB 級の計算機での実行条件、旧計測との違いを下表に追加した |
| 中2 | 「作業と判定」の委任の記述、F-Q の「判断者・日付」 | 委任の範囲と起動判断の根拠を [README「設計者の委任（2026-10-30）」](../README.md#設計者の並行作業中の判断2026-10-28-午後r-段)へ結び付けた |
| 軽1 | 「引用した出力と読者の入力」、F-Q の「引用出力の来歴と最終状態」 | 同じバイト列の389件を、引用のままの316件と再生成された73件に分けた |
| 軽2 | 環境の説明、F-Q の「設定・固定版・道具」 | Python の版は今回の実行では取っておらず、直前の記録を引いたことを明記した |
| 軽3 | 「H31 と義務の行35」、F-Q の「H31と個別義務」 | 行35を閉じる判断に残る RV-UB30 軽2 の限界を併記した |
| 軽4 | F-Q の「以後の変更の全一覧」 | V10.1c のテストの1行の修正と、作業時点に存在した V10.1cb の統合テストの修正を、読者との対応・ハッシュ付きで追加した |

### 各段のメモリと実行条件（中1）

保存済みの各ログから、macOS の `/usr/bin/time -l` が示した `maximum resident set size` と `peak memory footprint` をそのまま採録した。両欄の単位は bytes、GiB は 2^30 bytes である。異なる指標の値を足したり、一方を他方の代用にしたりしない。各段のログの SHA-256 と原値は [v10.1db-evidence.json](v10.1db-evidence.json)にも残した。

| 段とログ | 最大常駐量 bytes / GiB | peak memory footprint bytes / GiB |
|---|---:|---:|
| [A: coverage 書き出し](coverage-export.log) | 3,839,557,632 / 3.575867 | 54,100,688 / 0.050385 |
| [A: Rust 書き出し](rust-export.log) | 706,002,944 / 0.657516 | 53,625,552 / 0.049943 |
| [A: interval identity](interval-identity.log) | 182,829,056 / 0.170273 | 53,297,896 / 0.049638 |
| [A: interval manifest](interval-manifest.log) | 524,828,672 / 0.488785 | 53,445,352 / 0.049775 |
| [A: interval range](interval-range.log) | 130,482,176 / 0.121521 | 53,281,464 / 0.049622 |
| [A: interval VM](interval-vm.log) | 177,422,336 / 0.165237 | 53,412,560 / 0.049744 |
| [A: CLI ビルド](cli-build.log) | 3,888,660,480 / 3.621597 | 53,166,800 / 0.049515 |
| [B1: 引用の複写](cite.log) | 33,292,288 / 0.031006 | 29,540,712 / 0.027512 |
| [B1: 範囲の実ソース](range-sources.log) | 45,629,440 / 0.042496 | 20,857,192 / 0.019425 |
| [B1: H31 の個別照合](h31-verify.log) | 16,302,080 / 0.015182 | 12,714,344 / 0.011841 |
| [B1: 既知差と対照](range-known-differences.log) | 38,174,720 / 0.035553 | 9,306,496 / 0.008667 |
| [B2: 区間の集約](collect.log) | 15,986,081,792 / 14.888199 | 24,978,917,232 / 23.263430 |
| [B2: 区間・実ソース・VM 比較](interval-comparison.log) | 16,016,441,344 / 14.916473 | 30,032,057,704 / 27.969533 |
| [B2: check_named 全体](check-named.log) | 8,901,836,800 / 8.290482 | 8,848,562,872 / 8.240866 |
| [B2: 最終 manifest](manifest.log) | 15,526,084,608 / 14.459793 | 30,307,931,664 / 28.226461 |
| [B2: manifest の読み戻し](verify.log) | 150,126,592 / 0.139816 | 140,493,256 / 0.130845 |
| [A 全体の外側の計時](phase-a.out)（段別の値と別記） | 3,888,660,480 / 3.621597 | 1,622,400 / 0.001511 |
| [K10.3 一回目の全体](../k10.3/f-first-stages.json)（終了1、getrusage の補助値） | 14,372,323,328 / 13.385269 | 未取得 |

A 全体の外側の footprint を、内部の各段や全プロセスの合計の footprint としない。prepare、旧新比較の単独起動、B1/B2 全体について、保存されていないメモリの値を補ってはいない。

測った計算機の物理メモリは **34,359,738,368 bytes＝32 GiB** である。追補時に指定の `sysctl -n hw.memsize` を試したが、`sysctl fmt -1 1024 1: Operation not permitted` で終了1となった。同じ項目を libc の `sysctlbyname("hw.memsize")` で読み取り、終了0・32 GiB を確認した。コマンドが成功したと読み替えず、取得方法と終了状態を上の証拠へ保存した。

**16 GB 級の計算機では同じ手順で走る保証がなく、ほかの重い作業と並べて走らせない。** 最大常駐量14.916473 GiBだけでは判断できず、区間比較の footprint は27.969533 GiB、manifest は28.226461 GiBに達した。区間比較のログは user286.10秒・sys335.01秒・page faults261,515回も示す。Lean の `-M 12288` は、これら Python と交換実行ファイルの上限ではない。

K10.3 一回目の全体の13.385269 GiBは getrusage の補助値であり、今回の段別の OS time と測り方も対象の範囲も異なる。今回の最大常駐量や footprint が大きい原因は、この数値の比較から断定しない。docs/todo の TODO-314 に残した区間の manifest の重複は、この最大常駐量と合わせて扱う既存の課題であり、今回の増加の原因を特定した意味ではない。

### 引用の範囲、道具の版、義務の限界（中2・軽1〜軽3）

初稿の「設計者の委任による取りまとめの判断」は、[README「設計者の委任（2026-10-30）」](../README.md#設計者の並行作業中の判断2026-10-28-午後r-段)の項を根拠とする。取りまとめは、問い合わせがあれば推奨する方法で進めて push 直前で止めるという委任により、J2 の起動前の了承に代えて範囲と45〜75分の見込みを記録してから起動した。独立レビューや設計者の受け入れを済ませたという意味には広げない。

初稿の「389ファイルが同じバイト列のまま」は、ハッシュ一致の件数として残し、来歴を次の三つに分ける。`cite.py` が `shutil.copy2` で保存した更新時刻と SHA-256 を、写し元・最終出力の全3,174件で照合した。個別のパス・ハッシュ・更新時刻（mtime のナノ秒原値）は [証拠の provenance](v10.1db-evidence.json)にあり、同じバイト列の389件を一つずつ同定した。

| 最終状態 | 件数 | ハッシュ・更新時刻と引用の扱い |
|---|---:|---|
| K10.3 の出力を引用したまま残る | 316 | SHA-256・更新時刻とも写し元と一致。複写した3,174件のうち「引用したまま」の範囲はこの316件である |
| check_named が再生成して同じバイト列になった | 73 | SHA-256 は一致し、更新時刻は変化。最終更新は2026-10-29 20:27:59〜20:33:20 UTCで、check_named が作り直した出力である。引用したままとは数えない |
| check_named が再生成し、計時欄だけ変わった | 2,785 | SHA-256・更新時刻とも変化。計時4欄以外が一致するという初稿の照合を維持する |

316＋73＝389、316＋73＋2,785＝3,174であり、初稿の件数は変わらない。再生成された73件と2,785件の結果は B2 の check_named の実行に含む。初稿の五読者・独立段の入力一致と引用の判断を、この来歴の区別によって取り消すものではない。

Python 3.9.6 は、[直前の V10.3a の environment.json](../v10.3a/environment.json)にある値を引いたものである。V10.1d の実行では Python の版を取得しておらず、今回測定した実版とはしない。

義務の行35は、署名の非 Top の固定添字と節から範囲付き prim への転送という二つの不足を最終 F-U で照合したため、閉じてよいという判断を維持する。ただし、[RV-UB30 軽2](../reviews/RV-UB30.md#指摘)が残した、effect を宣言する testdata 36件の一つ一つが書き出されたか（除外されていないか）は確かめていないという限界は残る。

### 以後の変更と作業末の確認（軽4）

[V10.1c の結果](../v10.1c/results.md#全比較への影響と申し送り)と現在の差分を読んだ。`crates/benitoite/src/typeck/tests/interpolation_formats.rs` の109行の `benitoite::types::builtin::RangeIndex::TOP` → `crate::types::builtin::RangeIndex::TOP` は、`typeck/mod.rs` の `#[cfg(test)] mod tests` の中の1行である。全比較の統合テスト用の書き出しは lib を test の構成でなくビルドするため、この単体テストは含まれない。全比較の書き出しと読者の入力ではなく、各比較段の再実行を要しないと判断する。

追補の着手時には [V10.1cb の結果](../v10.1c/results.md#v101cb-二回目の-change-の失敗と統合テストの期待値の修正)にある `crates/benitoite/tests/scope_annotations.rs` の期待値の修正も存在した。独立した統合テストの入力・アサーションであり、全比較の書き出し器・固定入力・期待値・読者には含まれない。これも以後の変更として記録し、全比較の再実行を要しないと判断する（記録担当、2026-10-30 JST）。二つの変更の旧新内容と差分の SHA-256 は [証拠の changesAfterV101d](v10.1db-evidence.json)へ保存した。本作業では両ファイルを変更していない。

初稿の「追跡木に差分なし」は初稿の記録時点の事実として保ち、現在の差分なしという意味に広げない。F-Q の以後の変更も [同票の追補](f-q.md#v101db-引用票の追補2026-10-30)へ追加した。

作業末に `scripts/check.sh --level work --base 7179a3026fcf2b463c1ec933aefd23256be6dc93 --dry-run` を一度実行し、終了0・外側0.121170083秒であった。[選択の全出力](v10.1db-work-dry-run.log)と [引数・開始終了・計時](v10.1db-work-dry-run.json)を保存した。

| 選択 | 中身 |
|---|---|
| fmt | 全体の Rust の書式の照合 |
| lint_default | 既定の gc-mark-sweep 構成で lib・tests・examples の clippy |
| lib_default | 既定構成の lib の単体テスト全件 |
| tests_related | 統合テスト全ターゲット（`--test` の指定なし） |
| source_rules | 仮置きの許可と unsafe_code の場所の検査 |
| skill_generated | gen_skill による生成物の鮮度の照合 |
| spec_tally | 仕様集計の自己検査と集計 |

115変更ファイルから7単位が選ばれ、表示された理由はいずれも既存の `interpolation_formats.rs` の差分であった。選択されたコマンドは実行していない。通常の Rust の検査は、依頼で示された取りまとめの change の結果で覆われるものとし、この文書だけの追補で重ねて実行しない。初稿の dry-run の選択0件と今回の7単位は時点が異なるため、両方の記録を残す。

作業末の読解確認では、results.md と f-q.md の初稿の全バイトを先頭に保持したこと、追補の相対リンクと見出し、手元の絶対パスと禁止先リンクの不在、補助 JSON、既存のほかの保存物のハッシュ不変を確認した。HEAD・ブランチ・index と追跡ファイルの全内容・差分も着手時と同一である。[追補の最終状態](v10.1db-state.json)に同定を残す。dry-run 後の変更は追補の文章と記録だけであり、dry-run を反復していない。独立レビューと受け入れは取りまとめ・設計者へ引き渡す。

追補の所要は約6分である。保存できた最初の時計は2026-10-30 06:39:12 JST、作業末の採時計は06:44:43 JSTで、その間は331秒であった。冒頭の読解を含む概算であり、能動時間と読解・ハッシュ照合の待ちは厳密に分けていない。指定 dry-run は約0.12秒、ビルド・テスト・測定・独立レビュー・回答待ちはない。1時間の停止条件には達していない。
