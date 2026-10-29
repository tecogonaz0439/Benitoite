# F-interval/VM の局所比較

2026-10-29。B_WORK は `c3ca4504dae42271df7336aca41d0a6d5447d0e3` である。取りまとめが用意した B-Lean の `intervalDiff` を使用し、Lean のビルドは実行していない。以下は計画の F-interval/VM の局所比較であり、全関係定義を含む `check-formal.sh` 全体の成功ではない。

## 実行と結果

出力先 E は `docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/k10.2/f-interval-vm` である。既存の `target/` を使い、新しい `CARGO_TARGET_DIR`・target 外の一時ビルド・基準版の展開は作っていない。実行器 [run.py](f-interval-vm/run.py) は以下を一つずつ `/usr/bin/time -p` で包み、各コマンドの直接の終了状態と getrusage の補助最大常駐量を保存した。

```sh
BENITOITE_DESUGAR_DIFF_DIR=$E/identity cargo test --test desugar_export export_interval_identity -- --exact --nocapture
BENITOITE_DESUGAR_DIFF_DIR=$E/vm cargo test --test desugar_export interval::vm::export_interval_vm -- --exact --nocapture
cargo build -p benitoite --bin benitoite
python3 -B formal/tests/test_interval_exchange.py --output $E/interval-comparison --source-dir $E/identity --rust-dir $E/identity --rust-dir $E/vm/original --rust-dir $E/vm/instrumented --rust-dir $E/vm/range/original --rust-dir $E/vm/range/instrumented --rust-dir $E/vm/shifts/original --rust-dir $E/vm/shifts/instrumented --vm-dir $E/vm --cli target/debug/benitoite
```

正確な argv・開始/終了の UTC・単調時計・補助RSSは各 JSON に保存した。time の `real` を外側の時間として以下に示す。getrusage の原値の単位は macOS の bytes で、子プロセス単体の最大値である。同時使用量の総和ではない。

| 実行 | 終了 | 外側の時間 | 補助最大RSS（bytes / MiB） | 記録 |
|---|---:|---:|---:|---|
| identity 書き出し | 0 | 12.22秒 | 1,458,683,904 / 1,391.109375 | [01.log](f-interval-vm/01.log)・[01.json](f-interval-vm/01.json) |
| VM 書き出し | 0 | 3.36秒 | 176,472,064 / 168.296875 | [02.log](f-interval-vm/02.log)・[02.json](f-interval-vm/02.json) |
| 実 CLI のビルド | 0 | 21.62秒 | 3,830,333,440 / 3,652.890625 | [03.log](f-interval-vm/03.log)・[03.json](f-interval-vm/03.json) |
| 比較の初回 | 1 | 0.05秒 | 37,863,424 / 36.109375 | [04-initial.log](f-interval-vm/04-initial.log)・[04-initial.json](f-interval-vm/04-initial.json) |
| 読者修正後の比較 | 0 | 38.16秒 | 97,386,496 / 92.875 | [04.log](f-interval-vm/04.log)・[04.json](f-interval-vm/04.json) |

二つの書き出しは各1テスト成功・失敗0・無視0である。VM の対象演算は算術80・Range96・shift108である。cargo のロック待ちはログにない。実行環境は macOS 27.0.1 arm64、Rust/Cargo 1.98.1、Python 3.9.6、Lean v4.34.1 で、`CARGO_TARGET_DIR` と `RUSTFLAGS` は未設定である。設定・読者・交換器の前後の SHA-256 と実CLIの SHA-256 は [inputs-tools-before.json](f-interval-vm/inputs-tools-before.json)・[inputs-tools-after.json](f-interval-vm/inputs-tools-after.json) に保存した。

## 初回の失敗と読者の修正

初回は `interval_vm_compare.py::connect_sites` の `len(calls) == 1` で止まった。`marker` が `primName` を旧版の name/tys/effs だけの辞書と完全等号で照合しており、Surface 15 の実ソースの書き出しにある必須の `ranges: []` を受けなかったためである。

`formal/tests/interval_vm_compare.py` の標識の同定と `require_closed` の固定域の組み込み参照を、明示の空の範囲の列まで照合する形に直した。`funName` の欄は変えていない。実ソースの区間材料は Surface 15 に固定されているので、ここで欠落欄を許す互換分岐は加えていない。手書き Surface 14 の独立交換・旧版の分岐は変更していない。書き出しと CLI は変わっていないため再実行せず、古くなった比較だけを同じ指定で再実行した。

作成時の関門: 守る契約は、同じ実ソースの元演算と、追加した標識の到達・値・失敗位置を結び付けて VM と Lean を比較することである。範囲の列の追加で標識が見つからなくなる退行を、既存の局所比較が実際に検出した。既存の比較器を修正しており、新たな重複テスト・本番の差し込み口・公開 API は加えていない。本番コードの差分は0行、読者の差分は追加4行・削除2行である。

全比較から呼ぶ Python の固定 `primName` の等号も検索した。他に見つかった `test_interval_exchange.py`・`test_batch4_exchange.py`・`test_try_exchange.py`・`test_width_exchange.py` のものは手書き旧版の独立入力であり、一律に書き換えていない。

## 比較の件数と除外

[summary.json](f-interval-vm/summary.json) と [interval-comparison/](LARGE-FILES.md) の各報告に件数を保存した。

| 対象 | 件数・判定 |
|---|---|
| `intervalDiff` の入口の呼び出し | 237回。期待した不正入力・不一致の拒否を含め、台本全体の終了0 |
| 実ソースの読者 | 195入力・1,381出現・227対象、整数演算の種類81、shift宣言27（参照 primName40・funName14）、仮の根195 |
| 五つの profile | base 8・flow 9・width 41・range 7・domain 108定義。analyze/eval の最終の深さ除外は0、全 profile を保持 |
| flow-containers | 初期fuel40では深さ除外1で終了1、同じ corpus 全体をfuel80で再実行し最終除外0。深さの除外を成功としていない |
| 算術VM | 39実行・比較39・除外0、標識自身の失敗R0201を別に確認 |
| Range VM | 37実行・比較37・評価除外0、選ばない9定義と理由を報告、独立した unrelatedCaller の値105も照合 |
| shift VM | 108実行、Leanの評価との比較46・独立期待値だけの62。評価の除外はunknownFailure46、notClosedOrFuel16として区別。ラッパー宣言7・域外実行14も保持 |
| 実ソース7群の解析 | 合計584本体でRust/Lean一致。深さ除外0・phaseDepth0・未発見/未開始/未出力0。unsupported は各群の報告に残し、比較を削っていない |

VM の到達・値・失敗位置、Range の構成子・最小値・最大値・値・逆転の優先、shift の失敗コード・ファイル・位置・ラッパー位置を壊した否定入力が拒否されることも既存の各比較で確認した。profile の `vmCompared=false` は独立 profile 報告そのものの区分であり、上の VM 報告と取り違えない。

## K10.3 への見込みと限界

局所の書き出し二つと実CLIのビルドは計37.20秒、修正後の比較は38.16秒で、合計75.36秒であった。今回の範囲には全program群・manifest/range書き出し・六入口の全関係定義がないため、75秒を全比較の見込みへ置き換えない。K10.3 は前版の973秒（約16分）を基準にし、親担当の F-local・F-range と新規独立実ソース群の所要を加えて取りまとめが見込みを決める必要がある。少なくとも区間の現行読者の局所比較が数分以上に増える兆候は、この入力では認められなかった。

Leanの規則・交換の共通型・主定理・Assumptions・保証の変更を要する停止条件には該当しない。`private/`・`docs/todo/` を読まず、gitの状態を変える操作、`lake build`、`check-formal.sh` 全体、short の比較は実行していない。一時のビルドをtarget外に作っていないので、その削除対象はない。

## 全比較の接続の読解

`check-formal.sh` は identity・manifest・range・vm の四書き出しをそれぞれ実行し、その後で実CLIをビルドする。`test_interval_exchange.py` には、今回の7群に加え programs・manifest/manifest-interval・range/interval の3群を渡す。`exercise` は同じ `vm_dir` から算術・Range・shift の三比較を順に実行し、続いて source、全 rust-dir、五profileと否定入力を比較する。今回の237呼び出しはこの局所の引数集合の件数であり、全比較では追加3群があるため固定の237を成功条件にしない。

`scripts/check/formal_interval.py` の `SOURCE_DIRS` は10群をすべて列挙し、`counts` は各群の報告数、comparedBodies、manifestのanalyzedBodies、観測の順を一致させる。各群に情報のある本体・警告・非Topの独立入力を要求し、深さ除外・未比較を成功へ混ぜない。五profileとanalyze/evalの10報告、三VM報告の実行数と比較/独立のみ/除外の和も照合する。`collect` が実行前の入力一覧とハッシュを固定し、`manifest` と `verify` が全成果物を再照合する。この読解では、今回の7群584本体を全比較で省く変更はなかった。実際の全比較と残る3群の成立は K10.3 に残る。

全比較の見込みは、前版約16分へ F-local・F-range・新しい範囲の実ソース群の増分を加えて決める。局所区間75.36秒のうち実比較38.16秒であり、区間の現行読者追随だけを理由に旧見込みを大きく伸ばす根拠はない。親担当の追加群が数分以内なら、全比較の仮の幅は約16〜23分とする。全件の負荷と追加群は今回の局所7群から厳密には外挿できず、これは実績でなく取りまとめ用の推定である。

## 保存した成果物

全1,575ファイルの最初の一覧を [artifacts-before-pack.json](LARGE-FILES.md) に path・bytes・SHA-256 で保存した。実ソース、元の各群の入力、summary/report、実台本と小JSONはそのまま残した。反復する大きな中間入力JSON69件（合計53,303,746 bytes）だけを [large-intermediate-json.tar.gz](LARGE-FILES.md) へ圧縮してから各メンバーの SHA-256 一致を確かめ、展開された複写を削除した。圧縮物は1,106,002 bytes、SHA-256 は `1900622433557e3a960f375ed6820407dc947585d16c5660ef190a913c4da9b6` である。対応は [large-intermediate-json.json](f-interval-vm/large-intermediate-json.json) に残した。読み込み拒否の報告は圧縮対象から除いた。リポジトリ外に一時の保管物を作っていない。

担当の読解・実行・記録は UTC 12:10台から12:17台に行った。能動時間は約5分、検査待ちは約75秒（初回失敗0.05秒を別記）、外側約7分の概算である。親担当の並行作業の時間と加算しない。
