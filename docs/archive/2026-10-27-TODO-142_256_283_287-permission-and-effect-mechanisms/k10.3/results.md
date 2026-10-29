# K10.3: 全比較と接続の閉鎖

## 作業と状態

B_WORK と HEAD は `d35557f93ca65e73a841a17d6f19f1b79cf04464`、ブランチは `m013/k10.3` である。最初の時計取得は2026-10-29 14:16:50 UTCであり、その前に指定文書の読解を始めた。開始時の追跡ファイルの差分はなく、未追跡は取りまとめが保存した本ディレクトリのログだけだった。

処理系の本番コード・Lean のソース・交換の共通型・規則・主定理・Assumptions・保証・依存・固定版は変更しない。`private/`、そこを指すスキルのリンク、`docs/todo/` は読んでいない。状態を変える git 操作、本線への書き込み、新しい `CARGO_TARGET_DIR` の作成は行わない。担当の自己確認と、取りまとめの独立レビュー・設計者の受け入れを区別する。

## 一回目の F と再確認の境界

取りまとめが B_WORK で行った [一回目の全ログ](f-k10.3.log) は、終了1、外側2403.15秒、user1903.80秒、sys506.00秒、最大常駐量14,372,323,328 bytes（13.385269165 GiB）である。[開始と終了](f-k10.3-times.txt) は13:25:49〜14:05:53 UTCである。段の時間はシェルの整数秒で、外側の小数秒と混同しない。各段の最大常駐量は元記録にはなく、全体の最大値を各段へ割り当てない。[段と行番号の抽出](f-first-stages.json) も保存した。

それより前の [出力先の指定の失敗](f-k10.3-attempt0.log) は、終了2、外側0.33秒、最大常駐量15,597,568 bytesである。比較を始めておらず、一回目の段の成功へ合算しない。

| 一回目の段 | 元ログの時間 | 件数・結果 | 終了・今回の扱い |
|---|---:|---|---|
| 既定 `lake build` | 0秒 | 573ジョブ、sorry の検出なし | 0。引用 |
| desugarDiff / builtinCheck / coverageDiff のビルド | 各0秒 | 362 / 364 / 364ジョブ | 各0。引用 |
| Rust coverage export | 17秒、テスト本体12.37秒 | 4成功。境界20・乱数10,000、予算停止0 | 0。引用 |
| coverageDiff | 3秒 | 10,020一致、不一致0、fuel切れ0 | 0。引用 |
| coverageDiff with views | 個別時間なし、coverage段全体23秒 | 10,028一致、不一致0、fuel切れ0 | 0。引用 |
| coverageProgramDiff / surfaceCheck / surfaceCheckAll / intervalDiff のビルド | 0秒 / 個別時間なし / 0秒 / 0秒 | 366 / 366 / 372 / 452ジョブ | 各0。引用 |
| width独立交換 | 2秒 | 4検査成功 | 0。引用 |
| named独立交換 | 2秒 | 13検査成功 | 0。引用 |
| extensible独立交換 | 6秒 | 22検査成功 | 0。引用 |
| try独立交換 | 4秒 | 8検査成功 | 0。引用 |
| batch2独立交換 | 1秒 | 8検査成功 | 0。引用 |
| batch3独立交換 | 4秒 | 7検査成功 | 0。引用 |
| batch4独立交換 | 6秒 | 15検査成功 | 0。引用 |
| range独立交換 | 1秒 | 9検査成功 | 0。引用 |
| Rust export | 1,349秒、テスト本体1,347.40秒 | 45成功。全corpusの書き出し1,346.501秒、1,792入力＝1,373書き出し・419検査除外・対象外0 | 0。漏れた書き出し元一件だけ再出力 |
| Rust interval exports | 各テスト本体4.59 / 8.75 / 2.77 / 3.46秒 | identity / manifest / range / vm各1成功。range11入力、VM80 / 96 / 108操作 | 各0。引用 |
| 独立実ソース・拒否・報告側 | 10秒 | 受理15群18定義、拒否8、除外8、非Top12群計57、Top互換3群。報告26入力50コマンド。手書き拒否16群26定義 | 0。引用 |
| 番号付け・解析予算 | 0秒 | Rustだけの番号停止1、同一入力の比較2。補助停止位置null / 4 / 13 | 0。引用 |
| 既知差・受理対照 | 0秒 | 名指しした3入力 | 0。引用 |
| interval独立 / Rust / eval / VM | interval段全体918秒 | 1,852呼び出し、五profile、独立定義8 / 9 / 41 / 7 / 108。flow-containersはfuel40で除外1、80へ増やし成功 | 0。最終成功を引用し、途中のfuel試行も保持 |
| batch3 / batch4 Rust交換 | 7秒 | 独立7検査。b3 / blocks / g2 / g3は9 / 2 / 1 / 1入力、52 / 10 / 11 / 8定義 | 0。引用 |
| batch5独立 / Rust交換 | 2秒 | 独立8検査。32定義、formatted28、String3、fallback0 | 0。引用 |
| desugarDiff | 9秒 | scopeAcceptance欠落、報告未作成 | 2（Mainの例外分岐による）。修正後に再確認 |
| builtinCheck | 8秒 | 同上 | 2（同上）。修正後に再確認 |
| coverageProgramDiff | 4秒 | 1,373入力、match16,444・binding6,039＝22,483一致、不一致・対象外・fuel切れ0 | 0。入力ハッシュが不変なら引用 |
| surfaceCheckAll | 8秒 | scopeAcceptance欠落。比較報告はなく、準備失敗の小報告だけあり | 2（例外分岐による）。修正後に再確認 |
| per-program final Rust exports | 失敗までの個別時間なし | k3 / k4 / m1 / t3は5 / 7 / 31 / 9定義一致。routing1,792入力・width30定義一致。single surface checksの300 / 1,792表示後にc11-no-mainで停止 | 1。指定どおりcheck_named全体を一度再確認 |
| formal_interval.py manifest / verify | 未到達 | 未検査 | 修正後に各一度実行 |

一回目の成功した段を個別にやり直さない。指定された `check_named.py` 一回の中で、その前半に含むrouting・width・batch群と後半の六入口が再度呼ばれることは、この台本の実行範囲として記録する。独立した再実行を追加する意味ではない。F全体と `lake build` はこの枝で起動しない。

## 原因と修正

### (b) 入口失敗の三入力の scopeAcceptance

[欠落と除外の照合](missing-and-exclusions.json) のとおり、欠落は次の3入力だけである。

- `testdata/modules/c11-no-main`
- `testdata/test/check_error`
- `testdata/test/directory`

漏れた書き出し元は `tests/desugar_export.rs::export_desugar_corpus` の `pipeline::check_path` が `Err` を返した分岐である。通常の `CheckResult` を受け取る `export` の失敗分岐には、すでに空の解析表と本番の四上限があった。入口失敗はこの変換を経ずに空の定義と除外理由を直接組み立てて `CorpusStream::push` へ渡したため、必須欄が抜けた。Lean の読者は除外の分類より前に新形式の必須欄を読み、三入口とも例外終了となった。desugarDiffとbuiltinCheckの報告は存在しなかったが、surfaceCheckAllには101 bytesの準備失敗の報告が残っていた（[初回の準備失敗](first-surface-report.json)）。比較が完了した報告とは区別し、依頼文の「三つとも報告なし」をこの範囲で訂正する。Lean の読者の修正を要する問題ではない。

入口失敗にも `scope_export::acceptance(&Value::Null)` を書く。さらに、逐次書き出しの境界 `CorpusStream::push` で、除外を含む各入力が本番四上限を持つことを照合する。範囲や型をTopへ落とす変換、除外の追加、期待値の変更はない。

K10.1の通常検査では、全corpusを書き出すこのテストは既存のignored一件として実行されていない。通常の `export_general_named_programs` も `named-programs-*` を作るが、検査に成功する9入力の別の書き出しである。F-localは `named-declarations` の5定義であり、`check_path` の入口失敗を含まない。したがって、K10.1の「通常の全件」の確認とRV-K10.1の全入力の記述は、このignoredの全1,792入力に対する必須欄の確認には届いていなかった。

K10.2では全corpusを作ったが、その全件の局所確認は `check_routing` である。これは識別子・除外・scopeの分類・coverageの件数を確認し、`scopeAcceptance` のschemaは確認しない。Leanへ渡したのは短いF-local・独立入力・範囲入力であり、入口失敗の三入力は入っていない。全corpusを三つのLean入口へ渡した一回目のFで初めて表面化した。先行記録の成功範囲を全1,792入力のschema成功へ広げて引用しない。

### (a) NoMainFile の除外の正規化

`check_programs` が `item["excluded"]` とmanifestの文字列を直接比較していた。実際のNoMainFileは手元の根を含む絶対位置であり、固定manifestはリポジトリ相対位置なので、同じ入力でも不一致となる。一回目のroutingは同じ回に全1,792入力で成功していたが、別の後半の比較には正規化を使っていなかった。

`check_programs` の両辺を既存の `relocation_independent_routing` で正規化する。NoMainFileの完全な書式を持つ理由だけを対象とし、`crates/benitoite/` と入力名から作る相対位置に完全一致することを保つ。末尾のbasenameだけを比べない。三入力すべてで旧比較の不一致と正規化後の一致を確認し、異なる相対位置の絶対／相対の6負例を拒否した。ほかの除外の意味や件数は変えていない。

## 作成時の関門と policy

公開の `test-audit` に従った。守る契約は、交換の全入力の必須欄、場所の移動に依存しないが相対位置には厳密な除外の照合、新しい四つの比較と残る四群の実行および失敗の伝播である。現実的な退行は入口失敗だけの必須欄の欠落、NoMainFileの場所の取り違え、比較の呼び忘れ、前半の失敗を後半の成功で隠す変更である。既存の短い成功入力とroutingの要約照合だけでは最初の二つを検出できず、既存policyは `check_named.py` を外部Pythonとして代用するため四群に到達しなかった。本番の差し込み口・公開範囲・フラグは増やさない。

RV-K10.2軽5では、range exchange・sources・budget・known differencesの完全な引数と一回ずつの実行を、既存の実シェルのpolicyへ加えた。各呼び出しの終了17が後続へ伝播することも表で検査する。残るk3 / k4 / m1 / t3は、本物の `check_remaining_batch3`・`check_batch3`・`rust_inputs` を一時構成でつなぎ、外部のLean実行ファイルだけを代用するpolicyを一件加えた。各群の六入口、入力の場所、群ごとの失敗17の伝播を確認する。交換の意味の一致を代用の報告で確かめたとは扱わない。

[変更したpolicy二件の局所実行](policy-local.json) は2成功・失敗0、終了0、外側14.812935秒、補助最大RSS21,430,272 bytesであった。policy全件はW-Kの一回に含める。

## 再出力・再確認・作業末検査

再出力は `BENITOITE_DESUGAR_DIFF_DIR=<wt>/target/desugar-diff/k10.3-reexport` を指定し、`cargo test --test desugar_export export_desugar_corpus -- --exact --ignored --nocapture` の一件だけを実行した。[ログ](reexport.log) は1成功・失敗0・無視0・48件フィルタ、全1,792入力を保持する。Rust exportの45件全体、通常の9入力を書き出すテスト、区間の四書き出しは再実行していない。

[旧新の照合](reexport-comparison.json) では、再出力した1,009ファイルのうち、1,008ファイルの大きさとSHA-256が一致した。変わったのは `named-programs-corpus.json` だけである。全1,792入力を順に比較し、三つの入口失敗への空のpatterns・hostsと本番四上限の追加以外の差がないこと、ヘッダと末尾も不変であることを確認した。三入力の値は、実装から算出し直さない手書きの四上限とも一致する。

| corpus | 大きさ（bytes） | SHA-256 |
|---|---:|---|
| 一回目 | 343,290,941 | `e74cd54690a78a3adde544858814660069d34e40e3310182f42256a3cba84e54` |
| 修正後 | 343,291,355 | `5bff0451e759527428e8aef0eae4052324c95a6e547de408075ff2abf4522321` |

差は414 bytesである。この一ファイルだけを保存済みの `target/desugar-diff/k10.3/` に置き換えた。`named-programs-builtins.json`・`named-programs-stdlib.json`・`named-programs-coverage.json`、区間の五入力、乱数ソース1,000件はバイト単位で不変だった。このため、coverageProgramDiffと区間の成功済みの比較を独立に再実行していない。

最初のcollectが凍結した `input-manifest.json` は、修理したcorpus一件のbytesとSHA-256だけを更新した。[更新した一行と前後のハッシュ](input-manifest-update.json) を保存し、元のmanifestも `target/k10.3-before/` に保持した。期待値は更新していない。collectやprepareを再実行して成功済みの入力を作り直していない。

各段の正確な引数・環境・開始・終了・計時は同名のJSONとlog・exitに残した。[再確認の順序](recheck.py) は [全比較の入口](../../../../scripts/check-formal.sh) と同じ出力先と引数を使い、失敗すれば後続を実行しない。`run-record.py` は `/usr/bin/time -p` に対象を直接渡し、その終了状態を保存する。RSSはmacOSの `getrusage(RUSAGE_CHILDREN).ru_maxrss` の補助値であり、bytesで記録する。並行する全プロセスの合計ではない。MiBは2^20、GiBは2^30 bytesで換算した。

| 実行と計時 | 終了 | 外側秒 | 補助最大RSS（bytes / GiB） | 確認した内容 |
|---|---:|---:|---:|---|
| [該当一件の再出力](reexport.json) | 0 | 1,342.921370 | 707,952,640 / 0.659332 | 1,792入力、件数を保持 |
| [旧新の出力と全入力の照合](reexport-audit.json) | 0 | 15.446030 | 5,905,465,344 / 5.499893 | 三入力の必須欄だけを修理。ほか1,008ファイル不変 |
| [desugarDiff](desugar.json) | 0 | 51.612888 | 4,592,484,352 / 4.277084 | golden1,075・random72,778＝73,853定義一致、不一致0 |
| [builtinCheck](builtin.json) | 0 | 30.445194 | 4,555,669,504 / 4.242798 | 1,373入力、summary144,932比較、不一致・非収束・errors0 |
| [surfaceCheckAll](surface-all.json) | 0 | 54.856548 | 5,647,024,128 / 5.259201 | 51,742一致、既定の対象外19・Q11一件、準備失敗・不一致0 |
| [check_named全体](named.json) | 0 | 349.071052 | 8,902,131,712 / 8.290756 | 1,792入力・73,853定義・coverage22,483件、後半の交換と拒否も一致 |
| [manifest](manifest.json) | 0 | 416.780221 | 13,951,320,064 / 12.993179 | 十の実ソース群、独立profile、全manifestと件数を照合して12,872保存物を同定 |
| [verify](verify.json) | 0 | 36.801904 | 147,144,704 / 0.137039 | 全入力・報告・件数・ハッシュの読み戻し一致 |

[報告の集計](verification-summary.json) には、一般corpusの非Top件数は0であり、それを範囲の比較の成功件数へ加えないことを残した。範囲の12群は候補を除いて合計57であり、Top互換は3群である。番号付け停止一件はRust独自差、予算の二件は同じ鍵での直接比較、必須判定の三拒否は共通の独立期待値への個別照合である。効果上限のtypingをcover理由へ変換していない。最終manifestのVM比較は算術39・Range37・shift46、shiftの独立のみ62であり、既存の除外の内訳も保持する。

manifestは一回目に未到達だった段の初回実行である。約924 MiBのmanifest、約300 MiBのmaterial、約561 MiBのobservationsをPythonのオブジェクトとして同時に保持する経路があり、実行中にOSの圧縮メモリの増加を観察した。これが時間を要する有力な要因と読解では考えられるが、時間の原因をプロファイルで一意に特定したものではない。途中で打ち切ったり読者を書き換えたりせず、上の終了0を確認した。

## 台本の変更と局所確認

| 変更した箇所 | 変更と局所の確かめ方 | 結果 |
|---|---|---|
| `tests/desugar_export.rs:521`・`:640` | 逐次出力の必須上限の照合と入口失敗の必須欄。全体45件の代わりに、該当するignored一件をexactで再出力し、三入力以外の不変を確認 | 再出力と旧新照合が終了0 |
| `tests/desugar_export/check_named.py:306` | 両辺に既存の正規化を使用。[局所照合](exclusion-local.json) で旧比較の三不一致と修正後の三一致、異なる相対位置の六負例を確認 | 終了0、5.139140秒、補助RSS1,758,167,040 bytes。後のcheck_named全体も終了0 |
| `scripts/check/test_policy.py:244` | 新しい四呼び出しの全引数・一回の実行と失敗17の伝播を既存の表へ追加 | [二件の局所](policy-local.json) とW-Kで確認 |
| `scripts/check/test_policy.py:315` | 残る四群を実際の読者経由で検査するpolicyを追加 | 同上。各六入口と各群の失敗伝播を確認 |
| `scripts/check-formal.sh`・`scripts/check/formal_interval.py`・`formal/tests/` | 台本の変更なし | 変更部分の追加実行は不要。指定のmanifest / verifyは上のとおり初回実行 |

追加・変更した読者と記録用Pythonの直接の構文検査も行う。W-Kのpython_syntaxはtools配下を対象にするため、これをcheck_namedの直接の構文検査と説明しない。

## 07-03「結果の保存と引用」に従う全比較の判定

全比較の成功の判定は、**一回目の成功段の引用と、修正後の失敗・未到達段の再確認を合わせたもの**である。`check-formal.sh` 全体をこの枝で再実行し、終了0を得たとは説明しない。一回目の終了1と、出力先の指定で止まった終了2を保持する。段の件数・拒否・除外を減らした判定ではない。

| 記録する欄 | 引用と判定の内容 |
|---|---|
| 基準と対象HEAD | ともに `d35557f93ca65e73a841a17d6f19f1b79cf04464`。ブランチ `m013/k10.3`、indexはHEADと同じ。HEADだけで関係状態を同一とはしない |
| 未コミット差分 | `tests/desugar_export.rs`、`tests/desugar_export/check_named.py`、`scripts/check/test_policy.py`、07-03、07-04の五ファイル。内容は [差分](source-diff.patch) と [ソースのハッシュ](source-state.json.gz) に固定する。未追跡の検査用ソース入力はなく、結果の台本は記録の最終確認に個別のハッシュを残す |
| 検査の入力と道具 | [一回目終了後の保存物と入力のハッシュ](initial-state.json.gz)（取りまとめが取り込みのときに gzip で圧縮した。元の JSON の SHA-256 は `5947668eb7bf7bb8551dea956ccdc452547ec1dd76e0f00bd5a5e609834598a5`）、[固定版と環境](environment.json)、上の旧新照合、入力manifestの一行の更新、最終manifestのハッシュを保存する。関連ソース・設定・道具4,678件（七つの交換実行ファイルを含む）のハッシュを保存する。初期一覧は一回目F終了後、書き出し元とNoMainFile読者の二修正直後に採った。実行前に採取した記録とはしない。B_WORKの変更前の五ファイルはgit showから再構成してハッシュを残す |
| 一回目から変わったファイルと影響 | corpus一件に、除外三入力の必須欄だけを追加。影響する三入口と後半の読者を再確認した。builtins・stdlib・coverageと区間入力、独立入力・期待値・乱数ソースは不変。凍結入力manifestはその一件の同定だけ更新した。変更前後のSHA-256は別記録で保持する |
| 影響しない段の根拠 | coverageProgramDiffはcoverageとbuiltinsを読み、両方のハッシュが不変である。区間は書き出した五入力と独立入力・期待値・実CLIを読み、いずれも不変である。rangeの独立入力・拒否・予算・既知差、batch交換もその入力を変えていない。policyの追加と設計書の説明は比較の入力や意味を変えない |
| 実行・構成・件数と環境 | 一回目は全比較の台本、今回の再確認は [順序と正確な引数](recheck.py) と各計時JSONのとおり。三つの出力先は同じk10.3を使い、Lean実行ファイルの再ビルドはない。Rust1.98.1・Cargo1.98.1・Python3.9.6、macOS/arm64。成功・不一致・対象外・除外・fuel試行は前掲の表と最終manifestに分けた。ほかのOSや32ビットの実行へ広げない |
| 元の記録と以後の変更 | 元は [f-k10.3.log](f-k10.3.log)。以後の修正は上の五ファイルと記録だけであり、本番の実装・Lean・設定・依存・固定版・標準ソースを変えていない。書き出しの修正は全1,792入力、読者の修正は局所の負例と指定の全体で確認した |
| 判断者・日付 | Codex、2026-10-30 JST（UTCでは2026-10-29）。設計者の2026-10-29の「成功した段を再実行せず、動かなかった段だけ確認する」という指示に従う。担当の判定であり、独立レビューと設計者の受け入れの代替ではない |

formal_buildは、一回目Fの既定 `lake build`、573ジョブ・終了0・sorryの検出なしを引用する。Leanの全入力・設定・固定版と交換実行ファイルのハッシュは今回も不変である。Rustの交換の書き出しとPython読者の修正、policyと設計書の変更はLeanのビルド入力を変えない。単一のLeanファイルの検査も行っていない。

## 設計書と保証の限界

07-03には段の引用と再確認を合わせる場合の保存と判定の規約を追記した。07-04は、実際に閉じた交換の比較の範囲を、全関係定義・六入口・独立交換・区間と実VMとして明記し、未接続の状態の説明を更新した。[行別の変更](design-edits.json) は34行・対応表25行である。見出しとコード例、Leanの定義を変えない。01-12は既存の07-04への参照で足りるので変更していない。設計書に作業IDを加えていない。

一般の型付け・遷移とRust全実行の対応を証明したとはしない。BAの継続末尾の整形式性、初期の同じε、Top定数のshapeAt、旧像の同値の射程、到達したRequestIn全体の要求保持を形式化から導かない限界を残した。valContentsとdataDecls・二署名の一致を書き手に任せる境界、文字列の解析の正しさをLeanで示さない境界、観測専用APIを持たない本番実行器と、DNS/TLSの副次的通信を含めない観測も保つ。

## W-Kと最終確認

[dry-run](work-dry-run.log) は指定の九項目と五つの統合ターゲットを選び、終了0だった。続いて同じ指定を `/usr/bin/time -p` で一度実行した。[計時](work.json)・[ログ](work.log)・[直接の終了](work.exit) のとおり、**check.sh自身が終了0、外側330.557901秒**、time-pはreal330.55・user1129.41・sys40.70秒である。補助最大RSSは2,354,675,712 bytes＝2,245.593750 MiB＝2.192963 GiBだった。

```sh
scripts/check.sh --level work \
  --base d35557f93ca65e73a841a17d6f19f1b79cf04464 \
  --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,policy_selftest \
  --test desugar_export --test coverage_export --test golden \
  --test verify --test random_programs
```

[件数の集計](work-counts.json) は次のとおりである。

| 対象 | 成功 | 失敗 | 既存の無視 | ターゲット内の秒 |
|---|---:|---:|---:|---:|
| lib_default | 1,392 | 0 | 22 | 80.86 |
| coverage_export | 3 | 0 | 1 | 1.17 |
| desugar_export | 48 | 0 | 1 | 12.55 |
| golden | 2 | 0 | 0 | 60.26 |
| random_programs | 7 | 0 | 0 | 48.51 |
| verify | 3 | 0 | 0 | 68.12 |
| Rust合計 | **1,455** | **0** | **24** | 外側時間とは別 |
| policy全件 | 31 | 0 | 0 | 32.716 |

fmt・clippy・source_rules・生成Skillの一致・仕様集計・Python構文も成功した。random_programs全体は48.51秒であり、300件／60秒の予算・種・入力の縮小や単独再実行はない。formal_buildは前述の一回目Fを引用し、名指しに加えていない。部分選択の成功を、workの全自動選択を新しく一括実行した成功とは呼ばない。

W-Kの開始後に変えたのは本ディレクトリの記録とその確認台本だけであり、五つの検査対象ファイルは不変である。関係するテストやpolicy全件を重ねて実行していない。

## 停止条件、片付けと時間

Leanの規則・交換の共通型・主定理・Assumptions・保証・公開契約を変える必要はなかった。原因はRustの書き出しとPythonの比較であり、Leanの読者の変更も不要だった。停止条件への該当はない。処理系の本番コードは追加0・削除0行、Rust/Pythonの交換テスト・読者とpolicyは追加133・削除3行である。設計書と記録はこれと区別する。

target外に一時のRust/Leanビルドや基準版の展開は作らず、新しいCARGO_TARGET_DIRも作っていない。policyが作る一時構成はTemporaryDirectoryの終了で削除された。元の三つの出力先とログを保持し、再出力と旧版の控えはtarget配下に残した。過去の記録やレビュー本文は変更していない。

時間は各計時JSONのUTCを正とする。開始時の読解は最初の時計取得14:16:50 UTCより前であり、厳密な読解開始と能動時間の分離計時は未取得である。再出力は22分23秒、再確認の各段の時間は前掲の表、W-Kは5分31秒である。実行中にも記録の作成を進めたため、これらを外側の総所要へ単純加算しない。見込みの上端の2倍と5時間の停止条件を超えていない。最終確認の時計と所要は確認後に追記する。

| 引き継ぐ手順 | 担当 | 見込み |
|---|---|---|
| 独立レビューと必要な指摘の対応 | 取りまとめ | 段全体のレビュー20〜40分、指摘の対応は不明 |
| 設計者の受け入れと取り込み | 設計者・取りまとめ | 不明 |


最終の状態の確認は2026-10-30 00:05:34 JST（2026-10-29 15:05:34 UTC）であり、最初の時計取得から2,924秒（48分44秒）である。これより前の文書読解の時間は未計測であり、外側の総所要へ含めた厳密な値は不明である。[最終確認](final-verification.json) は終了0、関連入力4,680件・五ファイルの差分・未追跡の検査ソースなし・七実行ファイルとLeanの不変を確認した。HEAD・ブランチ・indexは不変であり、許可した編集範囲に収まる。設計書の見出しとコード例は不変、相対リンクは解決し、記録に手元の絶対位置は残っていない。記録用Python五本のハッシュも同じ確認に保存した。最終の差分のSHA-256は `dc7a7bfd8f347108e0d078d6ef303b1a94ac831f600d9ed046e4b0f60d3b8f76` であり、source-state.json.gzにも保存した。最後の変更はこの段落の追記だけであり、検査対象を変えていない。

## K10.3b: RV-K10.3 の中1・軽1・軽2への対応

2026-10-30 JST。基準と HEAD は引き続き `d35557f93ca65e73a841a17d6f19f1b79cf04464`、ブランチは `m013/k10.3` である。上の K10.3 の記録を保持し、以下を追加する。[着手時のハッシュ](k10.3b-initial-state.json) に対象ファイルと保護する二文書、index の状態を保存した。レビュー本文と計画の時間の訂正は変更しない。軽3の課題登録は取りまとめが受け持つため、この作業では `docs/todo/` を読まず、更新もしない。`private/` とそこを指すスキルも読んでいない。

| 指摘 | 変更 | 確認 |
|---|---|---|
| 中1 | `scripts/check/test_policy.py` に `test_formal_remaining_batch3_main_order` を追加。`check_named.py` の AST の `main` 直下で `check_remaining_batch3(directory)` が一回呼ばれ、`check_routing` より前にあることを検査する | [一時変異の記録](k10.3b-mutations.log)。元の写しは成功、呼び出し削除は呼び出し数、順序の交換は前後関係の検査で失敗した。写しは `target/` 内で作り、終了時に削除した |
| 軽1 | `CorpusStream::push` で `scopeAcceptance` の欄の集合を `{patterns, hosts, limits}` と照合する。既存の本番四上限の照合を保ち、除外入力では `acceptance(&Value::Null)` 全体との一致も検査する | [非 ignored の desugar_export](k10.3b-desugar-local.log) と W-K。書き出しの値を作る処理は変更しない |
| 軽2 | 07-04 の二段落を、実ソースの書き出しと実 VM の観察が接続済みである記述へ改める | 同章の公開 minimum・maximum・value による三欄の観察と、保存済みの [Range 37件の成功](verification-summary.json) に合わせた。評価関係との意味の一致は A1 の信頼の範囲に残し、minimum・maximum の観察を評価関係との一致の証拠へ加えない。設計書に作業 ID は加えない |

作成時の関門では、四群の検査を `main` から呼び忘れる退行と、routing より後へ移す退行を対象とした。既存の四群の直接呼び出しの検査と、`check_named.py` を外部プロセスとして代用するシェルの検査では、この接続の欠落を検出できない。今回はレビューが指定した入口の AST を一件で検査し、一時の二変異でそれぞれ意図した失敗を確認した。軽1は既存の書き出し境界の assert を強めたものであり、本番コードの差し込み口や新しいテスト関数は増やしていない。本番コードは追加0・削除0行である。

### 全比較と formal_build の引用

軽1の assert を加えても、書き出しの値は変わらない。一回目と再確認を合わせた全比較では、Lean の読者がすべての入力の `scopeAcceptance` の三欄を受理している。今回の修正は、この必須欄と除外入力の既存の空の受理表を Rust の書き出し境界でも検査するものである。中1は policy の追加、軽2は接続範囲の説明の訂正であり、比較の入力・期待値・交換の意味を変えない。このため、設計者の「動いた段を走らせ直さない」という指示に従い、全比較、Rust の ignored の全件書き出し、各比較段を再実行しない。前掲の一回目の終了1と再確認を合わせる判定を保持し、新しい全体実行の終了0とは説明しない。

`formal_build` は前掲の一回目の F の `lake build`（573ジョブ、終了0、sorry の検出なし）を引用する。Lean のソース・設定・固定版・交換実行ファイルは変更しない。基準、元の記録、件数、道具、入力ハッシュと判定は上の引用表および `source-state.json.gz` に保持し、以後の三ファイルの修正と影響しない理由をこの節で追加する。判断者は Codex、判断日は2026-10-30 JSTである。short も実行しない。

### 局所検査と W-K

局所検査は既存の `run-record.py` から `/usr/bin/time -p` に対象を直接渡した。ログの絶対位置は `<wt>`・`<home>` へ置き換える。RSS は同じ台本の macOS `getrusage(RUSAGE_CHILDREN).ru_maxrss` による補助値（bytes）であり、同時使用量の合計ではない。

| 検査 | 終了 | 外側秒 | 結果 |
|---|---:|---:|---|
| [AST の元の写しと二変異](k10.3b-mutations.json) | 0 | 0.052959 | 元の写し成功、削除・交換の二変異を意図どおり拒否。写しの削除も確認 |
| [policy_selftest の直接実行](k10.3b-policy-local.json) | 0 | 35.991856 | 32件成功・失敗0 |
| [desugar_export の直接実行](k10.3b-desugar-local.json) | 0 | 19.681956 | 48件成功・失敗0・既存の ignored 1件。ignored は実行しない |
| [最初の dry-run](k10.3b-work-dry-run.json) | 0 | 0.015378 | 指定の九項目と五ターゲットを確認 |
| [W-K の最初の試行](k10.3b-work-attempt1.json) | 1 | 2.685977 | 最初の fmt が追加 assert の改行二箇所を拒否。後続の検査は未実行 |
| [書式修正後の dry-run](k10.3b-work-dry-run-final.json) | 0 | 0.014309 | 同じ基準・九項目・五ターゲットを再確認 |

最初の試行は [失敗ログ](k10.3b-work-attempt1.log) と終了状態を保持した。rustfmt の指示どおり assert の二引数を同じ行へ置き、書式だけを修正した。その後、未実行だった後続の検査を含む W-K を同じ指定で一度実行した。指定は前掲の W-K のコマンドと同一で、`formal_build` を加えない。`/usr/bin/time -p` の直下に `scripts/check.sh` を置き、要約器やパイプの終了状態で置き換えなかった。

修正後の [W-K の計時](k10.3b-work.json)・[ログ](k10.3b-work.log)・[check.sh 自身の終了状態](k10.3b-work.exit) は、終了0、外側320.701972秒である。time-p は real320.69・user1132.63・sys40.34秒、補助最大RSSは2,268,594,176 bytes＝2,163.5 MiB＝2.112793 GiBであった。Rustは1,455件成功・失敗0・既存の無視24件、policyは32件成功・失敗0である。fmt・clippy・source_rules・生成Skillの一致・仕様集計・Python構文も成功した。名指しの部分選択の成功であり、work の自動選択全体の新しい実行とは扱わない。

W-K 開始後は検査対象を変えず、このディレクトリの記録だけを追加した。最終の自己確認は [確認台本](k10.3b-final-evidence.py) で行い、K10.3 の保存済みソース4,680件との比較、HEAD・ブランチ・index と計画・レビューの不変、許可した三ファイルだけの変更、未追跡の検査ソースがないこと、構文・リンク・絶対位置の伏せ方を確認する。新しい状態は `k10.3b-final-state.json.gz` と `k10.3b-source-diff.patch` に保存し、先行する証拠のファイルを上書きしない。状態を変える git 操作、target 外の一時ビルド、新しい CARGO_TARGET_DIR はなく、一時変異の写しも残していない。Lean の規則や保証等を変える停止条件への該当はない。

最初の時計取得は2026-10-30 00:13:22 JST（2026-10-29 15:13:22 UTC）であり、W-K 後の記録時点は00:22:09 JST、外側8分47秒である。局所検査は並行して実行したため、各外側秒を総所要へ単純加算しない。能動時間と待ちの分離計時は行っていない。最終確認の時刻と計時は `k10.3b-final-state.json.gz` および `k10.3b-final-evidence.json` に保存する。1.5時間の停止条件を超えていない。独立レビュー・受け入れ・取り込みは取りまとめと設計者が受け持つ。
