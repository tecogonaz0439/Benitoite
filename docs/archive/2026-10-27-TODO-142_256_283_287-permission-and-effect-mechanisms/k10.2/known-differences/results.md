# 既知の差の具体入力と旧 Scope の保存の再確認

2026-10-29。B_WORK は `c3ca4504dae42271df7336aca41d0a6d5447d0e3` である。新しい入力3本と手書きの期待値を比較前に固定し、正式な入力を `formal/tests/range-known-differences/`、記録の写しを本ディレクトリへ置いた。[manifest](manifest.json)に現在の入力と期待値のSHA-256を保存した。RustとLeanの規則・本番のコードは変更していない。

## E0711 と U+0000 の対象

| 入力 | 手書きの期待と実CLIの結果 | 比較の扱い |
|---|---|---|
| [class-structural.bnt](class-structural.bnt) | trait の `uses File.Read["/data/**"]` と実装の `uses File.Read["/data/a"]` の宣言は、CLI終了2、E0711だけで拒否 | Rustの実装宣言の構造上の包含という追加制約を名指しして除外する。Leanの `checkMethods` の被覆と、同じ受理・拒否になったと数えない |
| [nul-direct.bnt](nul-direct.bnt) | `Http.checkRequestIn` の直接の `hostPattern: "\u{0}443"` は、CLI終了2、E0459だけで拒否 | 精度差の対象は、先頭U+0000と整数の綴りからなるこの条件文字列だけである。Rustの `ScopeArgument::String` は文字列として保持し、host解析が既知不良を拒否する。Leanの `ScopeState.absArg` は整数の内部表現との混同を避けて未知へ落とす。Requiredの四理由の同じ鍵の比較へ混ぜない |
| [nul-dynamic.bnt](nul-dynamic.bnt) | 同じ文字列を局所変数に保存した条件は、CLI終了0、エラーなし | 除外しない対照である。局所の文字列は静的には未知の条件であり、Topで受理する。実行時の綴りの検査は残る。直接の不良なhost条件まで受理されるとは説明しない |

通常の整数ポート、通常の文字列の条件、要求のレコード全体、動的なhost条件全体は、この二つの除外へ含めない。検査済み実行値を交換が `unsupported` とする制限も、U+0000の精度差と別に扱う。

手書き期待値と実CLIの診断のコードは [cli-main/summary.json](cli-main/summary.json)に一致した。`exclusions` は `E0711:1`・`leanStringPrecision:1`、受理の対照1件である。これは診断と除外の照合の成功であり、除外した入力でRust/Leanの同じ受理や理由が一致した証拠ではない。

Leanの `ScopeState.absArg` の未知化は既存の定義と `ScopeLowerExamples` の独立guardで確認した。今回Leanの評価を追加せず、B-Leanの既定ライブラリの検査を引用する。Rustの当該直接入力は既存 `local_tests` の入力でもE0459を期待しており、現在の公開CLIでも同じだった。

## 初回の失敗と入力の修正

最初の台本は `--report=json` をファイル名の後ろへ置き、CLIの使い方の誤りで終了2となった。ソースの検査には到達していない。[最初のログ](../known-differences-check.log)と [初稿の期待値](expected-before-command-fix.json)を保持した。R40の固定文書に従って、オプションをファイル名の前へ置き、CLIの検査の拒否の終了値を1から2へ訂正して再固定した。診断コードの期待は変更していない。

次の実行はE0711に加えて、mainがないことのE0414で失敗した。[ログ](../known-differences-final.log)と [main追加前の3入力](before-main-fix/class-structural.bnt)を残した。三つの入力へ独立した `main() -> Unit` を加えて再固定し、E0711とE0459の主対象を変えずにCLIの完全なソースとした。期待する診断コードは変更せず、[再実行](../known-differences-main.log)で3入力とも一致した。期待値だけを出力に合わせて差し替えた比較にはしない。

最終の台本は `formal/tests/test_range_known_differences.py` である。正確な引数は [計時](../known-differences-main.json)にある。終了0、外側0.323964583秒、time-p real/user/sysは0.32/0.29/0.01秒、補助最大常駐量は38,420,480 bytes（getrusage、macOS）である。失敗の終了2や診断の余分なコードを無視するcatch-allはない。

## 旧 makeHost・makeEndpoint と正規化した保存

`formal/Benitoite/Checked/Scope.lean::makeHost` は、パターンの整形式性、対象の整形式性、所属の順に検査する。`makeEndpoint` は、パターン・対象・ポートの上下限・portの有効性・hostの所属・portの所属の順に検査し、成功した値は条件と対象を保持する。成功と各失敗の対応は同ファイルの `makeHost_success_iff`・`makeHost_invalidPattern_iff`・`makeHost_invalidTarget_iff` などと `makeEndpoint_*` にある。文字列の解析と書式は、そのままこの抽象の定理が保証する範囲へ加えない。

公開の持ち主の試験 `runtime_builtins::scope_checked_values_preserve_inputs_and_runtime_errors` を一度だけ局所実行した。[ログ](../old-scope-runtime.log)・[計時](../old-scope-runtime.json)のとおり、終了0、1試験成功・失敗0・無視0・除外28、外側0.7216415秒（time-p real/user/sys0.71/0.57/0.08秒）、補助最大常駐量78,069,760 bytesである。

この試験は独立した `fixtures/checked-scope.json` の112入力（host64・path24・endpoint24、成功31・失敗81）を、Direct/Requestの二方式で通す。成功する全入力では、射影した正規形の条件と対象を同じ `checkHost`・`checkPath`・`checkEndpoint` へもう一度渡し、同じ保存欄を得ることまで確認する。IPのexact/CIDR、v4/v6、最大prefixのexactへの正規化、host bitsの拒否、mappedの対象拒否、異族の非包含と、失敗の優先順も入力にある。既存の試験を使い、似た準備やテストを新設していない。

新しい独立実ソース群の `old-ip.bnt` は、IPv4の `S.checkHost(pattern:"192.0.2.0/24",host:raw)` とIPv6の `S.checkEndpoint(hostPattern:"2001:db8::/32",minimumPort:80,maximumPort:443,host:raw,port:443)` を交換する。同じ公開の標準ラッパーが `inspectHost/inspectEndpoint` の本番の解析へ渡し、成功時は正規化した条件・対象をレコードへ保存する。実ソースの交換で表・型・本体の接続を、上の実行試験で値の保存と再利用を照合する。交換の脱糖の一致だけで、動的なmakeHost全体の完全な実行比較を済ませたとはしない。

## k3 の宣言の同一性

R10.5の [既存の対応表](../../r10.5/binding-renumbering.json)を旧506・追加後507宣言のTSVへ再照合し、追加が `Scope.PathIn` 一件であることと、表の全対応が同じ宣言を指すことを確認した。現在の同じ `batch3/scope.bnt` を同じ公開pipelineで読み、[採取ソース](capture-current-bindings.rs)から [現在の471宣言](bindings-current.tsv)を採った。rustcの [引数](bindings-command.json)と [ログ](bindings-build.log)を残した。

[照合結果](k3-declaration-correspondence.json)は、現在のk3の比較対象5関数（checkedHost・checkedPath・checkedEndpoint・endpointPort・dynamicHost）が全て同じ宣言へ対応し、全てinScopeであることを示す。補充型27件は、既存対応表と現在のbuiltinsの `supplementalData` の修飾名で対応できた。番号の差を見て全整数を一律にずらす処理は使わない。

一方、507宣言全体が今も番号だけ違って残る、とする最初の探査の仮定は成り立たなかった。現在は旧Traitのimport宣言群とScopeの旧エラー表示のprivate補助関数など39件がなく、checkPathIn/pathInValue/widenPathInの3件が加わっている。これらの全名前も照合結果に残し、R10.5後の宣言集合の差を番号だけの差に丸めない。現在の読者によるk3の5関数の各入口の結果は親のreaders記録にあり、古い版の生のハッシュが現在の新形式とも一致したとはしない。

## 片付けと停止条件

一時の採取実行ファイルは既存targetの下へ置き、採取後に削除した。target外の一時ビルド・基準版の展開・新しいCARGO_TARGET_DIRは作っていない。Leanの規則・ソース・主定理・仮定・保証を変える必要はなかった。全比較とW-Kは親担当が受け持つ。この台本は全比較へ接続し、二つの除外の名前と診断をmanifestへ残す。
