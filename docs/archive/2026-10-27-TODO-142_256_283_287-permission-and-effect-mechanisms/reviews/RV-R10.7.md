# RV-R10.7: 署名・効果の原子・表データの書き出しの独立レビュー

2026-10-28。対象は R10.7 の未コミットの差分と `r10.7/` の記録。`cargo test --test desugar_export scope_tables::`（3件成功）と、保存済みの corpus と builtins を使った `builtinCheck`・`desugarDiff` の再実行（どちらも終了0、報告は保存済みの2件と JSON として一致）を行った。作業用のディレクトリと git の状態は変えていない。

結論: 重大1・中3・軽5。重大1 を直すまで取り込まない。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 重大1 | 重大 | `tests/desugar_export/exchange.rs` の `ExchangeJson::serialize` | 鍵が `"bits"`・`"network"` で値が文字列なら、場所を問わず u128 の整数として書く。既存の書き出しの Float64 の bits（`ConstValue::Float` の `{"float":{"bits":"…"}}`、`negFloat`）も十進の文字列なので、全 corpus の Float64 定数と負の Float64 が JSON の数値に変わる。Lean の `UInt64` の `FromJson`（v4.34.1 の `bignumFromJson?`）は文字列しか受けず、数値には誤りを返す。通常テストは Float32 しか最終バイト列で確かめず、F-table の入力に Float がないので見つからなかった。K10.3 までの既知の失敗に紛れる。ソースを読めば確定する誤りで、Lean に読ませる再現はしていない | 整数への変換を IP の対象だけに限る（`family` と並ぶ `bits`、`prefixLen` と並ぶ `network` だけを変換する、または材料の段階で別の鍵を使う）。Float64 と `negFloat` が最終バイト列でも文字列のまま残る回帰テストを加え、W-R をやり直す |
| 中1 | 中 | `builtins.rs` の `named_builtin_tables` の `request` | ClientRequest は data として書かれ交換の名前は `data:N` なのに、表のデータには束縛番号 N を `"N:[]"` という不透明型の名前として書く。不透明型の名前空間は組み込みの型番号なので、N が組み込みの番号と同じなら別の型を指す（本番の出力に仮の値を書くのと同じ）。名前の解決に失敗すると黙って空の表になる | R20.0b で表現を決めるまで本番では `valContents` を空にして未接続と記録するか、少なくとも解決の失敗を明示的に断る。README の確認点 (13) とあわせて R20.0b/K10 に記録する |
| 中2 | 中 | 計画の分担表と results の後続の表 | 版 14/6 を固定する Rust の出力の読者が、分担表（`check_named.py` と manifest）のほかにもある: `tests/desugar_export/check_batch3.py`（`check-formal.sh` が呼ぶ）、`formal/tests/test_batch2_exchange.py`・`test_batch3_exchange.py`・`test_batch5_exchange.py` の Rust の出力を読む経路、interval の台本群の `surfaceVersion=14`。R10.7 で生産側の版を上げたので失敗が確定するが、表に載っていない | results の後続の表に各読者と担当（K10.1 か K10.2）を加え、取りまとめが計画の分担表へ写す |
| 中3 | 中 | `docs/design/07-quality/07-04-formal-semantics.md`「道具と置き場所」 | 「現在の Rust の通常の書き出しは corpus 14・型表 6・プログラム網羅性 6 である」が実装と食い違う | 「corpus 15・型表 7・プログラム網羅性 7（区間の Surface は 14 のまま。scopeAcceptance・limits・ranges は未接続）」に改める |
| 軽1 | 軽 | 07-04 の「Rust との全比較は行っていない（Rust は未接続）」と表の「Rust は未接続」 | 直前に加えた「書き出しは切り替えた」「局所照合は接続した」と食い違う | 「本番の必須欄が未接続なので、全比較は行っていない」に揃える |
| 軽2 | 軽 | results の F-table の節 | `builtinCheck` が rvar について検査するのは IO の形と `rvar 0` の対応だけで、`rvar < rkinds` の個数や種類は照合しない。`desugarDiff` は型表を読まない。番号と種類の検査は Rust の側だけで、Lean で確かめたのは読めることまで | この範囲を一文で書く |
| 軽3 | 軽 | `scope_tables.rs` の `rejects_range_variables_outside_signatures_and_invalid_signature_indices` | 範囲外の番号では `signature_valid` の assert が先に失敗するので、`scope.rs::index` の `rvar < bound` の検査を単独で確かめていない。どの panic でも合格になる | `range_bound` を直接与えて `index` だけを確かめるか、panic のメッセージを照合する |
| 軽4 | 軽 | results の B-Lean の記録 | 計画が求める B-Lean の全出力・sorry の拒否・RSS がない | 取りまとめが排他のビルドのログを `r10.7/b-lean-build.log` に置いた（`lake build` の全出力と `/usr/bin/time -l`、sorry なし） |
| 軽5 | 軽 | W-R の後の doc コメントの変更 | fmt だけを再実行し clippy を再実行していない | 重大1 の後の W-R の再実行で閉じる |

## 問題がなかった点

- 新形式の形: 名前の原子 `{"name":{"value","ix"}}`、不透明型 `{"opaque":{"name","ix"}}`、`ix` の `fixed`/`rvar`、範囲の符号化、`rkinds` と `shape`（untargeted・topTargeted・single）、表のデータの欄名と「識別番号:型引数」の名前が Lean の読者（`Exchange/Range.lean`・`Builtins.lean`）と一致する。
- `admitsR.covers` の inner/outer は Lean の `AdmitsRule.covers i j`（j が i を覆う）と RV-R10.5 中1 と一致する。
- rvar は `range_bound` で署名の中だけに限られ、項・通常の型・効果では拒否される。Top へ落として変数を消す処理はない。
- 版と分担: 分担表の R10.7 の列の各行が計画どおり（corpus 14→15、sidecar 6→7、typed try の header 13→15 で corpus 10 の固定入力は変えない、interval の header・check_named.py・manifest・coverage_export は変えず未接続として記録）。途中の不完全な出力を完成した入力と数えていない。
- 独立期待値: 先頭3署名・dataDecls・dataTypes・summaries・共通の表の行は L50.2 の手書きの値を名前の対応表で写したもの、追加の10署名は `TargetTable.lean` の定義と一致する。由来と写しの限界が results にある。
- F-table: 条件（corpus 15・sidecar 7、空の patterns・hosts、limits 1000/10000、呼び出しの ranges、path・endpoint の rvar・rkinds・shape・admitsR、corpus に rvar がない）を満たし、報告（13署名変換・構成子4・要約4一致、2定義と1プログラム一致、不一致・対象外・除外0、nonTopRanges=18）は再実行と一致する。全比較の成功として数えていない。
- 通常テスト: 対象の除外・無視の追加・件数の縮小はない。未使用の効果操作の全署名の照合も妥当。
- R10.6 の軽1〜軽4 の用語集と 01-07 の修正は指摘どおり。work の記録（基準・コマンド・check.sh 自身の終了0・437.29秒・lib 1,358・統合420）はそろう。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 重大1・中1・中3・軽1〜軽3・軽5 | 採る。中1 は推す案として本番の `valContents` を R20.0b まで空にし、未接続として記録する | R10.7b |
| 中2 | 採る。R10.7b が results に読者と担当を書き、取りまとめが計画の分担表へ写す | R10.7b と計画 |
| 軽4 | 取りまとめが `r10.7/b-lean-build.log` を置いた | 済み |

R10.7b（同じ枝）で重大1・中1〜中3・軽1〜軽3 を直し、F-table を再実行した（両入口とも終了0、13署名・2定義・1プログラム一致、不一致・対象外・除外0）。作業末の W-R の途中でディスクが満杯になり止まったので、R10.7c で W-R をやり直した（check.sh 自身の終了0、外側469.56秒、lib 1,359件・統合41ターゲット422件）。取りまとめが確かめた: `ExchangeJson::serialize` の整数への変換は `family` と並ぶ `bits` と `prefixLen` と並ぶ `network` だけに限られ、回帰テスト `export_preserves_float64_bits_and_numeric_strings`（正・負の Float64、`-0.0`、数字だけの文字列）が bits を文字列のまま保つことを確かめる。中1 の本番の `valContents` は推す案として R20.0b まで空にした（設計者の並行作業中の判断）。
