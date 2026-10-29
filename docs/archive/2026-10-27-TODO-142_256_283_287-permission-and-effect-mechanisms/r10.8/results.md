# R10.8: RV-R10 の中1・中2への対応

## 作業と状態

B_WORK と開始時の HEAD は `f5821c672d22b32e097ca5980a6f20fa44583722`、ブランチは `m013/r10.8` である。開始時に未コミットの差分はなかった。中1の理由の分類・文言・通常入口のテスト・設計書・生成物と、中2の探査の二つの型構築を修正した。依頼対象の修正と検査記録は完了した。比較器の旧版に対する自己検査1件の失敗と、time の追加の RSS 採取の失敗は下に区別して記す。独立レビュー・受け入れ・取り込みは取りまとめが行う。

`private/`、そこを指すスキル、`docs/todo/` は読んでいない。Lean・scripts・依存は変更していない。状態を変える git 操作は行っていない。

## 変更と接続

`typeck/solve.rs` は、上限の一原子で覆われず、同名の上限がある名前の原子について、下表の理由と注記・修正案を選ぶ。非 Top の閉じた原子の数だけを数え、別名の原子・Top・範囲変数を数えない。一原子で覆える場合の受理、同名の原子がないときの E0501／E0401、主位置・宣言の副位置は保った。

| Lean の `atomFailure` の場合分け | Lean の結果 | 今回の Rust の対応 |
|---|---|---|
| 名前の原子の範囲が Top、由来が `unknown` | `unknownSource` | 既存の Top の経路。複数の閉じた上限があってもこの理由を先に選ぶ |
| 名前の原子の範囲が Top、由来が `exceeded` | `budgetExceeded` | この効果制約の診断経路は由来の予算超過を入力に持たず、この場合を作らない。局所解析の接続を追加したとはしない |
| 名前の原子の範囲が Top、由来が `known` | `notCovered` | この経路は Top を既知として分類する入力を持たず、既存どおり未知として扱う |
| 名前の原子が非 Top の閉じた範囲で、上限に同名の非 Top の閉じた原子が二つ以上ある | `atomicCoverOnly` | 新たに対応。和で実際に覆えるかどうかは判定しない |
| 名前の原子が非 Top の閉じた範囲で、上の個数が二つ未満 | `notCovered` | 既存の理由を保持 |
| 名前の原子が範囲変数、またはそれ以外の原子 | `notCovered` | 範囲変数を複数の閉じた原子の分類へ入れない。名前以外の原子は既存の構造の診断経路を保つ |

`acceptAtom` は先に一原子による被覆を調べる。Rust も `effect_accepts` の失敗後だけ理由を選ぶ。Lean と異なる新しい場合分けは要らず、停止条件には該当しない。今回を Scope の局所解析や Rust と Lean の全比較の完了とは数えない。

文言は `diag/codes.rs`、理由の値は `typeck/text.rs` に置いた。`atomicCoverOnly` の note は「複数の閉じた同名原子があるが一原子では覆えず、和の被覆は検査しない」とする。`notCovered` は同名の一原子で覆えないことを示す。この二理由の help は、一原子で覆う上限の宣言、または狭い宣言範囲を持つ呼び先の選択を示す。`unknownSource` は Top が全対象であり Top だけで覆えることを note に示し、範囲引数を省略した同名エフェクトの宣言、または上限で覆える宣言範囲の呼び先を help に示す。標準関数そのものの宣言を利用者が狭められるという表現を避けた。

01-07「閉じた範囲引数」と02-10の E0519 の説明を、この条件と理由別の文言に合わせた。他章の E0519 の記述を検索し、01-12 は既に `atomFailure` と同じ分類、02-05 は理由の選び方を列挙せず02-10を参照する記述であり、変更は不要と判断した（この判断は誤りで、02-05 の手順3は理由を二つだけ列挙していた。RV-R10.8 中1 を受けて取りまとめが三分類に直した）。`cargo run -p benitoite --example gen_skill` で `skill/references/diagnostics.md` を再生成した。生成物は手で編集していない。仕様の text の例は変更していない。

## テストの作成時の関門と再現

主となるテストは、既存の `tests/scope_annotations.rs::effect_coverage_uses_one_same_named_atom` である。公開の `pipeline::check_text` を通し、必要な原子・上限・コード・理由・note・help・主位置・副位置を観測する。原子の代数だけのテストや、コードだけを期待する従来の表では、`atomicCoverOnly` を `notCovered` に誤分類する退行を捕まえなかった。既存の表に独立した理由の期待値を加え、別の層や内部の差し込み口を追加していない。

追加した三入力は、上限が `File.Read["/a/**", "/b/**"]` のとき、必要な原子が `File.Read["/**"]` なら `atomicCoverOnly`、裸の `File.Read` なら `unknownSource`、`File.Read["/a/x"]` なら受理、という境界である。既存の HTTP の `0..9` 対 `0..4`・`5..9` も `atomicCoverOnly` と明示した。異名の上限を混ぜた既存例では `notCovered` を維持する。

本番修正前の [退行再現ログ](regression-before.log) は終了101であり、HTTP の二原子の例が `atomicCoverOnly` ではなく `notCovered` になって失敗した。修正後は、通常入口の関係する5テストが成功した（[ログ](regression-after.log)）。既存テストの削除はない。本番の Rust は28行追加・9行削除、テストは48行追加・22行削除である（生成物・道具を除く）。

## 道具の修正と確認

`tools/bench/compare/timing_probe.rs` の `irenv` が Unit と Boolean を構築する二箇所へ、第三引数 `types::builtin::RangeIndex::TOP` を渡した。

[読者の検索ログ](readers.log) のコマンドは次のとおりである。

```sh
git grep -n -E 'Ty::Con|EffectName::|RangeIndex' -- tools crates/benitoite/examples
```

`derive_inventory/mod.rs`・`derive_inventory/schema.rs` と `try_actions_inventory.rs` は、既に三引数の型と二引数の効果名に追随している。非 Top を表せない schema の生成では明示的に拒否しており、添字を黙って捨てる変更は加えていない。追加の未追随は見つからなかった。

比較器の README「自己検査」のコマンドを実行した。固定された旧版も対象に含むため、B_WORK の確認とは分けて下に記録する。[check_probe.py](check_probe.py) は同じ `build_all` で B_WORK の archive をビルドし、同じ照合器で probe の独立 IR とグラフの点を一度ずつ機能検査する。欠けていた `bridge-shared-8` も対象にする。性能の標本採取や比較の判定は行わない。

## 検査

実行器 [run_logged.py](run_logged.py) は生ログ・終了・外側の経過時間を保存する。作業末は `/usr/bin/time -p -l` の内側の sh で check.sh を実行し、その直後の `$?` を [work-check-exit.txt](work-check-exit.txt) へ直接保存して、同じ値を time に返す。`-p` に `-l` を加えて macOS の time による最大常駐量の採取も試みたが、下記の環境制限で取得できなかった。外側の経過時間は Python の単調時計である。ログ中の手元の絶対パスは `<wt>`・`<home>`・`<tmp>` に置き換える。

```sh
python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r10.8/run_logged.py regression-before cargo test -p benitoite --test scope_annotations effect_coverage_uses_one_same_named_atom -- --nocapture
python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r10.8/run_logged.py regression-after cargo test -p benitoite --test scope_annotations effect_coverage -- --nocapture
python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r10.8/run_logged.py generation cargo run -p benitoite --example gen_skill
python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r10.8/run_logged.py compare-selftest env PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'
python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r10.8/run_logged.py probe-check env PYTHONPYCACHEPREFIX=target/bench/pycache python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r10.8/check_probe.py
scripts/check.sh --level work --base f5821c672d22b32e097ca5980a6f20fa44583722 --dry-run
python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r10.8/run_logged.py work --work scripts/check.sh --level work --base f5821c672d22b32e097ca5980a6f20fa44583722
```

[W-R の dry-run](work-dry-run.log) は終了0である。fmt、既定構成の lib/tests/examples の clippy、既定 lib 全件、全統合ターゲット、source_rules、skill_generated、spec_tally、python_syntax、migrate_selftests の9項目を選んだ。spec_examples は全統合に含まれる。Rust と Skill の差分が最初の7項目、`tools/bench/compare/timing_probe.rs` の差分が Python 構文と移行器の自己検査を選ぶ理由である。対象を手で狭めていない。

| 検査 | 終了 | 外側の秒 | 結果と記録 |
|---|---:|---:|---|
| 修正前の通常入口の退行再現 | 101 | 22.908 | 理由の誤分類で1失敗。[ログ](regression-before.log)・[計時](regression-before.json) |
| 修正後の関係する通常入口のテスト | 0 | 10.293 | 5成功。[ログ](regression-after.log)・[計時](regression-after.json) |
| Skill の再生成 | 0 | 0.736 | [ログ](generation.log)・[計時](generation.json) |
| 比較器の README の自己検査 | 1 | 287.600 | 39件中38成功・1失敗。[ログ](compare-selftest.log)・[計時](compare-selftest.json) |
| B_WORK の共通ビルドと探査の機能検査 | 0 | 1.195 | ビルド済みの B_WORK を照合して再利用し、7点成功。[ログ](probe-check.log)・[計時](probe-check.json)・[入力・出力とビルドの証拠](probe-results.json) |
| W-R の選択確認 | 0 | 0.109 | [ログ](work-dry-run.log)・[計時](work-dry-run.json) |
| W-R（9項目を一度実行） | check.sh は0、外側の time は1 | 532.666 | 全項目成功。time の追加の RSS 採取だけが環境制限で失敗。[ログ](work.log)・[計時](work.json)・[check.sh の直接の終了状態](work-check-exit.txt) |

比較器の自己検査の1失敗は `CommonProbeCompilationTests.test_both_revisions_compile_through_the_common_builder` であり、固定した旧基準 `c31e64b03d2810343e1779926bea4ebc958b6164` が三引数の `Ty::Con` と `RangeIndex` を持たないためである（[ビルドログ](probe-build-c31e64b03d28.log)、E0433・E0061）。もう一つの固定旧基準 `706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8` でも probe は同じ理由で使えない（[ビルドログ](probe-build-706d7ca3d16f.log)）が、こちらの自己検査は CLI の入力検査を対象としており成功した。いずれも CLI の release ビルドそのものは成功している。今回の修正で古い二引数 API の探査との互換性は失われる。自己検査を全件成功としない。

依頼対象の B_WORK は共通 builder が `cargo build --release --locked -p benitoite` と `rustc --edition=2024 -O` で実ビルドし、探査まで成功した（[ビルドログ](probe-build-f5821c672d22.log)）。`probe-results.json` は正確なコマンド、コンパイラと Cargo の版、lock・ソース・バイナリの SHA-256 を持つ。機能検査の7点は `codegen-irenv-empty`・`codegen-irenv-4`・`bridge-empty`・`bridge-shared-4`・`bridge-nodes-4`・`bridge-nodes-8`・`bridge-shared-8` であり、IR の不正な兄弟参照の拒否、グラフの節・辺・ヒープの対象数・観測値を既存 validator で確認した。旧 API と新 API の両方へ対応する版別 adapter を設けるなら、編集範囲外の `build.py` と自己検査の固定基準を含めて取りまとめが別に判断する。現在の B_WORK どうしを比較する取り込み後の short を阻む失敗ではない。

W-R の check.sh 自身の終了状態は0であり、選ばれた9項目は全て成功した。既定 lib は1,359成功・失敗0・既存の無視21、全統合は41ターゲット422成功・失敗0・既存の無視10である（[件数](test-counts.json)）。fmt、既定構成の lib/tests/examples の clippy、ソース規約、Skill 生成物の一致、仕様の自己検査と集計、Python 構文、移行器の自己検査（6件と10件）も成功した。

`/usr/bin/time -p -l` は real 532.65秒・user 1544.43秒・sys 57.18秒を出した後、`time: sysctl kern.clockrate: Operation not permitted` となり終了1になった。check.sh の終了0とは異なる。`-l` を追加した採取方法がこの環境で使えなかったことが原因であり、検査対象の失敗ではない。W-R は依頼どおり一度だけ実行し、計時の失敗を理由に成功済みの検査を繰り返していない。Python の外側の経過時間は532.666秒（約8分53秒）である。

OS の time による最大常駐量の原値は取得不能である。補助値として、この一回の検査を待った Python の `getrusage(RUSAGE_CHILDREN).ru_maxrss` は3,375,939,584 bytes、3219.546875 MiB、3.144088745 GiBを返した。これは子プロセスの最大値であり、並行した全プロセスの常駐量の合計ではなく、一括実行全体の同時使用量とも区別する。取得不能を0とは記録していない。

検査後も、[変更8ファイルの SHA-256](changed-files.json) は保存時と全て一致する。`git diff --check` は終了0である。以後の変更は本ディレクトリの結果記録だけである。

## 失敗・ずれと申し送り

退行再現、比較器の固定旧版の API 不一致、time の追加の RSS 採取の環境制限は、上記のとおり失敗を保存した。比較器の自己検査の基準や期待値、検査範囲を変えて失敗を隠していない。計画からのずれは、RSS の取得不能に補助値を残したことと、旧 API との互換性の失敗を取りまとめへ申し送ることである。

ヒープの不変条件・安全点を越える保持・依存方向・ホストの整数幅は変更していないため、追加の heap・32ビット・特殊構成の実ビルドは行わない。Lean と Rust の全比較、段の検査、short の性能比較は本枝では実行していない。short は取り込み後に取りまとめが担当し、`bridge-shared-8` を再取得する。RV-R10 の中2が挙げた R10.2b・R10.3・R10.4・R10.5・R10.6 の5回の欠測の注記は、編集範囲外の段の結果へ取りまとめが転記する。過去の結果を修正済み・再測定済みとはしない。

## 時間

開始時の時計は2026-10-28 14:44:27 UTCで、その直前に最初の規約を読み始めた。結果の確定は2026-10-28 15:00:26 UTCであり、時計間の外側の所要は959.3秒（約16.0分）である。能動時間は約9分という概算である。最長の作業末検査は8分53秒、比較器の自己検査は4分48秒であり、一部を並行し、その間にも文書と結果を整理したため、待ち時間を外側の時間から単純に引いて能動時間とはしない。局所検査と生成の時間は上表のとおりである。独立レビュー・性能比較・設計者の回答待ちは本枝では行っていない。見込み上端90分の2倍には達していない。


## R10.8b: 新旧の型の形での探査のビルド（追記）

上記は R10.8 時点の記録である。旧版の API との互換性の喪失と、short の基準である開始版 `6124775` では probe を使えない問題を本作業で修正した。過去の失敗ログは残し、以下に今回の再検査を区別して記す。性能の標本は採らない。

### 判定と探査

`build.py::probe_api` が、比較する各版の archive の `crates/benitoite/src/types/mod.rs` を読み、`pub enum Ty` 内の `Con` 宣言の第三引数が `builtin::RangeIndex`（または非修飾の `RangeIndex`）かどうかを調べる。コミット ID や呼び出し側の作業ツリーでは判定しない。該当する版にだけ `--cfg benitoite_range_index` を渡す。既存の `benitoite_parser_pending` の判定は保つ。

`probe_api` に判定 `range_index` と宣言元のバイト列の SHA-256 `types_sha256` を残す。既存の鍵は `probe_api` 全体を含むため、判定または宣言元のハッシュが変われば、以前に失敗した probe のキャッシュも無効になる。CLI のビルドのキャッシュはそのまま利用できる。

`timing_probe.rs` の `builtin_ty` に型の構築を集めた。Unit と Boolean はこの関数を呼び、cfg があるときは `Ty::Con` の第三引数に `RangeIndex::TOP` を渡し、ないときは旧版の2引数で構築する。README の版の判定の段落にも cfg と切り替えを追記した。

### 自己検査の範囲

新たなテスト関数は増やさず、既存のキャッシュの検査と共通 builder の実ビルドの検査を拡張した。キャッシュの検査は、archive に2引数の宣言を加えた場合（判定は同じでハッシュだけが変わる場合）と、3引数へ変えた場合を通す。CLI を再利用しつつ probe を作り直し、cfg・判定・ハッシュ・鍵に反映されることを観測する。git と外部コンパイラだけを代用し、本番専用の差し込み口は加えていない。修正前は probe の再ビルドが起きず失敗し、修正後は成功した（[修正前](r10.8b-regression-before.log)・[修正後](r10.8b-regression-after.log)）。

`test_both_revisions_compile_through_the_common_builder` は固定の0.0.9 `c31e64b03d2810343e1779926bea4ebc958b6164` と現在の HEAD に加え、開始版 `6124775788579e60530f55fb85570f26ef7fa900` も実ビルドし、同じ既存の照合器で probe の入力を機能検査する。旧版の固定値や期待値を置き換えて失敗を隠していない。別の既存検査が使う `706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8` も維持した。

[両版の機能検査の台本](r10.8b-check-probe.py) は、共通 builder で開始版と B_WORK をビルドする。quick/short の probe の6点に、通常の `bridge-shared-8` を加えた7点を各版で一度ずつ照合する。IR の不正な兄弟参照の拒否、変換グラフの節・辺・ヒープの対象数・観測値も既存 validator で確かめる。これは機能検査であり、性能の反復標本や性能の比較判定ではない。

### 実行と記録

[r10.8b-run-logged.py](r10.8b-run-logged.py) にコマンド・生ログ・終了状態・外側の単調時計の時間を保存する。work は `/usr/bin/time -p` の内側で check.sh を実行し、直後の `$?` を専用ファイルに保存して、その値を time に返す。`-l` は使わない。

```sh
python3 <改造>/r10.8/r10.8b-run-logged.py r10.8b-compare-selftest env PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'
python3 <改造>/r10.8/r10.8b-run-logged.py r10.8b-probe-check env PYTHONPYCACHEPREFIX=target/bench/pycache python3 <改造>/r10.8/r10.8b-check-probe.py
python3 <改造>/r10.8/r10.8b-run-logged.py r10.8b-work-dry-run scripts/check.sh --level work --base f5821c672d22b32e097ca5980a6f20fa44583722 --dry-run
python3 <改造>/r10.8/r10.8b-run-logged.py r10.8b-work --work scripts/check.sh --level work --base f5821c672d22b32e097ca5980a6f20fa44583722
```

`<改造>` はリポジトリの根から本改造のディレクトリまでの相対パスである。実行したコマンドの正確な引数は各 JSON に保存する。

work の dry-run は終了0であり、fmt、既定構成の lib/tests/examples の clippy、既定 lib 全件、全統合ターゲット、source_rules、skill_generated、spec_tally、python_syntax、migrate_selftests の9項目を選んだ。spec_examples は全統合に含まれる。今回の追加差分だけへ範囲を狭めず、開始時からある R10.8 の差分も B_WORK から検査する。


比較器の README の自己検査は39件全て成功し、終了0、外側157.275秒であった（[ログ](r10.8b-compare-selftest.log)・[計時](r10.8b-compare-selftest.json)）。固定の0.0.9・開始版・HEAD に対して、共通 builder から probe の実ビルドと機能検査が通った。別の自己検査が使う `706d7ca3` の probe もビルドできた。[ビルドの証拠](r10.8b-builds.json) は、版ごとの cfg・宣言元のハッシュ・キャッシュの鍵・コンパイルの引数・バイナリのハッシュを持つ。宣言元のハッシュを archive の実バイト列と再照合した。

| 版 | `range_index` | 探査のビルドログ |
|---|---|---|
| 0.0.9 `c31e64b03d28` | false、2引数 | [ログ](r10.8b-build-c31e64b03d28.log) |
| 開始版 `612477578857` | false、2引数 | [ログ](r10.8b-build-612477578857.log) |
| HEAD = B_WORK `f5821c672d22` | true、3引数 | [ログ](r10.8b-build-f5821c672d22.log) |
| 既存の入力検査の基準 `706d7ca3d16f` | false、2引数 | [ログ](r10.8b-build-706d7ca3d16f.log) |

両版の補助の機能検査は終了0、外側0.589秒であり、開始版と B_WORK の各7点、計14点が成功した（[ログ](r10.8b-probe-check.log)・[計時](r10.8b-probe-check.json)・[入力コマンド・出力とビルドの証拠](r10.8b-probe-results.json)）。対象は `codegen-irenv-empty`・`codegen-irenv-4`・`bridge-empty`・`bridge-shared-4`・`bridge-nodes-4`・`bridge-nodes-8`・`bridge-shared-8` である。測定では候補側だけに割り当てる小さい nodes の点も、この補助台本の中でだけ両版を対象にして照合した。測定のシナリオの割り当ては変更していない。

補助台本の初回は、候補側だけへ割り当てられた `bridge-nodes-4` の入力を基準側にも要求して KeyError となった（終了1、外側0.459秒。[ログ](r10.8b-probe-check-initial.log)・[計時](r10.8b-probe-check-initial.json)）。台本の対象状態を修正して上記の14点を再検査した。probe 自体の失敗ではない。

`rustfmt --check --edition 2024 tools/bench/compare/timing_probe.rs` も終了0であった。処理系本体・既存のテスト・設計書・生成物の7ファイルは R10.8 の保存済みハッシュと一致する（[照合](r10.8b-preserved-files.json)）。変更は比較器の4ファイルと本ディレクトリの記録だけであり、既存テストの削除、処理系のテスト専用コードの追加はない。B_WORK 比で builder は10行追加・1行削除、探査は13行追加・5行削除、自己検査は17行追加・1行削除である。探査の行数は R10.8 の未コミット差分を含む。


work は選択した9項目を一度実行し、check.sh 自身の終了0、外側の time の終了0であった（[ログ](r10.8b-work.log)・[計時](r10.8b-work.json)・[check.sh の直接の終了状態](r10.8b-work-check-exit.txt)）。外側の単調時計は482.724秒、`time -p` は real 482.72秒・user 1455.79秒・sys 56.89秒であり、`-l` は付けていない。fmt・clippy、既定 lib 1,359成功・失敗0・既存の無視21、全統合41ターゲット422成功・失敗0・既存の無視10、ソース規約、Skill 生成物の一致、仕様の自己検査と集計、Python 構文、移行器の自己検査6件と10件が全て成功した（[件数](r10.8b-test-counts.json)）。[dry-run](r10.8b-work-dry-run.log) も終了0であった。

ビルドログは既存のキャッシュへの追記であり、過去の失敗を含む。今回の最終のビルド状態は `r10.8b-builds.json` の probe の実在・ハッシュ・コマンドと、成功した機能検査で確認した。

archive・release ビルド・probe は `target/bench/builds/`、補助の入力は `target/bench/r10.8b-probe-inputs/` に置いた。自己検査が `target/` の外へ作る一時の archive とビルドは `TemporaryDirectory` の終了処理で削除された。ログに現れた一時先も存在しないことを確認した（[確認](r10.8b-cleanup.json)）。作業後も処理系・設計書などの既存の7ファイルは R10.8 のハッシュと一致した。比較器を含む最終の11ファイルのハッシュを [保存](r10.8b-changed-files.json) した。HEAD・ブランチ・空の index は開始時のままで、状態を変える git 操作は行っていない。

計時の起点は最初の規約確認直後の2026-10-28 15:02:15 UTC、結果の確定は 2026-10-28 15:13:31 UTC である。外側の所要は 676.3秒（約11.3分）、能動時間は約6分という概算である。自己検査157.275秒と work 482.724秒は一部を並行し、待つ間に記録と証拠を整理した。独立レビュー・受け入れ・取り込みは取りまとめの担当であり、本枝では実行していない。性能の標本採取も行っていない。
