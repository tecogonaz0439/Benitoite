# F-Q: B_WORK と V10.1d の出力への引用票

2026-10-30 JST、記録担当。[V10.1a の初版](../v10.1a/results.md#f-q-初版-b_work-への引用票)を、版上げとH31追加後の関係状態へ更新した。本票の対象は B_WORK `7179a3026fcf2b463c1ec933aefd23256be6dc93` とV10.1dの出力であり、以後の候補・保管・集約・公開状態を先に確認済みとはしない。段の詳細・終了・時間・RSS・件数は [results.md](results.md)、本票は [07-03「結果の保存と引用」](../../../design/07-quality/07-03-compiler-testing.md#結果の保存と引用)の欄を対応付ける。

| 欄 | 対象の状態・入力・実行と判断 |
|---|---|
| 元の基準と対象HEAD | K10.3/K10.3bは `d35557f93ca65e73a841a17d6f19f1b79cf04464`。元indexはHEADと同じ。未コミット差分は `crates/benitoite/tests/desugar_export.rs`・同 `desugar_export/check_named.py`・`scripts/check/test_policy.py`・07-03・07-04の5ファイルである。[source-state](../k10.3/source-state.json.gz)・[元差分](../k10.3/source-diff.patch)・[K10.3b最終状態](../k10.3/k10.3b-final-state.json.gz)・[最終差分](../k10.3/k10.3b-source-diff.patch)を同定する。元の未追跡の検査用ソース入力は0件 |
| 元差分の取り込み | K10.3b最終差分のSHA-256 `f2beae4f0a2abdc21960746bebb4aabde9e3e2cda56a4ee80d359ca0f5498749` と取り込み `28e05ae5f7adc378b441654fbdcd02feeef5f72a` の同5ファイルの差分との一致はV10.1aの照合を引き継ぐ。K10.3bのassert・policy・説明の3変更を、入力への接触なしと省略しない |
| 引用先の基準・HEAD・差分 | B_WORK・HEADはともに `7179a3026fcf2b463c1ec933aefd23256be6dc93`、ブランチ `m013/v10.1d`。[着手状態](initial-state.json)の追跡・index差分と未追跡は空である。空の差分のSHA-256は `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。作業末の未追跡は本ディレクトリの記録だけで、全内容のSHA-256をfinal-state.jsonへ残す。未追跡の比較用ソース入力は0件である。H31の2ソースとexpected.jsonはすでにB_WORKの追跡木へ入っている |
| 以後の変更の全一覧 | K10.3b取り込み後からB_WORKまでは [506ファイルの一覧と全コミットID](changes-after-k10.3.json)を使う。状態・内容ハッシュ・期間全体のbinary diffのSHA-256も保存した。V10.1a初版の対象HEADは `e4843058669262a4bf4bfbea9cfbe368a29a1e7b`、F-Lは `bae86164de063a9807784513e8960e46536d9f4b`。初版の42ファイルだけという説明を現在まで広げない |
| 関係するソース・固定入力・期待値 | 元のsourceHashes全4,680件と現在を読み戻して一致4,599・変更81・欠落0。[relation-state.json](relation-state.json)へ全変更の旧新SHA-256を記した。版・二lock・登録/要約/help・版依存テスト・testdataのheader/依存hash/診断期待値・named.rs・H31のexpected・Skill/生成診断・設計文書の変更を含む。標準ソースと意味の規則は不変。追加H31の2入力と事前期待値は [freeze](../v10.1b/h31-freeze.json)で同定し、固定ハッシュを保持する |
| 生成元・生成物・交換器・読者 | 書き出し元・テスト・比較器・manifestの実装は元のsourceHashesと照合した。named.rsのheaderとrange-sourcesの追加だけを不変と扱わない。全Rust書き出しをAで新規取得し、一般corpus/builtins/stdlib/coverage、独立coverage、区間102ファイルは旧新SHA-256一致。3変更・10追加の全ハッシュは [phase-a-hash-audit.json](phase-a-hash-audit.json)にある。生成Skillや訳・文書の例は全比較の自動収集先ではなく、work/change/候補の別責任である |
| manifest・生成出力の同定 | 新しいcollect・manifest・verifyを使い、古いinput-manifestを流用していない。最終input-manifestは276,948 bytes・`106815c6322d0abbc8de0a6c26fc0d0d91b6f88b0f6eeae8c4b9003b01154dfc`、manifestは2,243,167 bytes・`7d46994a68d7c514e7f3d55a1e4b63e2a1e02ebb7936c85058de0ee5ff83ef56`。manifest-comparisonは [保存した本文](reports/interval-diff/manifest-comparison.json)を使う。全12,904保存物の同定は最終manifestにあり、大きな原本は [LARGE-FILES.md](LARGE-FILES.md)にbytes/hashを残す |
| 設定・固定版・道具 | formal408＋rust-toolchain.tomlの計409項目、七実行ファイル、lake設定・manifest・固定版は全件一致。[formal-hashes.json](formal-hashes.json)とrelation-stateを使う。Rust/Cargo1.98.1・Lean4.34.1・`-M 12288`を保つ。実版・環境はK10.3と直前V10.3aのenvironment.json、V10.1dのログのtest/dev・benitoite0.0.13を引く。Python3.9.6・macOS/arm64の結果で、別OS/32ビット/機能を外した構成へ広げない。本記録でLean/elan等を新規起動・取得したとはしない |
| 実行・構成・正確な引数 | V10.1dの台本 [A](phase-a.sh)・[B1](phase-b1.sh)・[B2](phase-b2.sh)と各ログ、resultsの段表を使う。Rust既定構成、coverage4成功、desugar45成功とinterval4件、失敗0・ignored0。四区間は各48件、desugar本体は4件filter。新CLIをビルドし、範囲実ソース・既知差・区間・check_named・manifest/verifyを実行。不変の五読者・独立段・予算・formal_buildは引用。compare単独起動のargv/終了/時間、B1の外側時間と直接のexitは未採録と明記する |
| 終了・時間・最大常駐量 | A全体は終了0・real1,391.22秒、B2各段は終了0、B1は後続到達と成功報告で終了0と判定。16段の個別real合計2,867.06秒、未計時・段間の時間は含まない。今回のOS time最大値は区間比較16,016,441,344 bytes＝14.916473 GiB。旧初回全体は終了1・2,403.15秒・14,372,323,328 bytes、先行試行は終了2・0.33秒であり、成功へ書き換えない。K10.3の補助RSSや整数秒と今回のOS time原値を区別する |
| 件数・成功/失敗/無視/除外 | 一般1,792入力・書き出し1,373/検査除外419/対象外0、脱糖73,853定義、組み込み144,932比較、coverage10,020/10,028/22,483、表層51,742一致/対象外19/Q11一件を維持。不一致・非収束・準備失敗・fuel切れの0を維持。範囲は既存15群18定義/非Top12群57/Top3群にH31の2群2定義/非Top10を加え17群20定義/非Top14群67。拒否8・診断付き除外8・報告26入力50コマンド・六入口を維持。区間1,852呼出/五profile/十実ソース群・全countsと除外、VM39/37/46・独立のみ62を維持。件数減少0・除外増加0 |
| 不変の段を引用できる理由 | 五読者が読むファイルの旧新SHA-256は [reader-input-hashes.json](reader-input-hashes.json)の全件で一致する。独立段はformalの読者・固定入力・期待値、Rustからの入力、七実行ファイルが同一である。実CLIが変わる段と、header/expectedが変わる段は再実行した。HEADだけの一致で判断せず、意味の入力と出力を段ごとに対応付けた |
| 引用出力の来歴と最終状態 | 元cited.jsonは3,174ファイル・46,278,779 bytesの複写時点の記録。[cited-summary.json](cited-summary.json)に元パス・件数・bytes、写し元全ハッシュ一致を残した。最終時点で389ファイルは同じまま、2,785報告はcheck_namedが再生成した。後者は計時4種の欄だけが異なり、他の全欄は一致した。再生成済みの報告まで「引用したまま」としない |
| H31と個別義務 | [h31-final.json](h31-final.json)で、事前固定の署名の非Top添字・TopのAudit・両headerの効果・surface/core双方の範囲付きprimへの転送・全定義・非Top3/7を照合済み。常設比較と個別台本の役割を区別する。F-Lだけでなく最終F-Uで二つの不足を閉じたため、義務の行35を閉じてよい。他の未確認10行をこの判定で閉じない。obligations.mdは変更していない |
| 失敗・修正の履歴 | K10.3の入口失敗3件の必須欄欠落、NoMainFile、準備失敗101 bytes、1,009再出力の1,008不変・corpus差414 bytes、K10.3bの値を変えないassert/policy/説明の訂正とfmt初回失敗を元記録のまま保持する。予算の補助停止位置の初稿6→訂正4、実ソースの三拒否と独立期待値の個別照合、typingとcover理由の差、区間fuel40失敗→80成功も保持する。今回の外側の実行段に新しい失敗なし。記録用補助照合の誤った全写し不変assertと訂正もresultsへ記した |
| 判断者・日付 | 実行と引用の範囲の判断は設計者の委任による取りまとめ、2026-10-30。本票の保存済み証拠の照合と引用可能の判断は記録担当、2026-10-30 JST。独立レビュー・設計者の受け入れの代わりではない |
| 引用の限界と後続 | 現在の全比較の成功はK10.3の成功段、K10.3の再確認、V10.1bの独立期待値、V10.1dの影響段を合わせた判定である。一般の意味保存の証明、BA末尾・初期ε・TopのshapeAt・旧像の同値の一般化、RequestIn全体の要求保持、文字列解析、実体の隔離、DNS/TLS副次通信、内容の流れを保証しない。古いCLIのproducerを新候補の版/commit/同梱物の証拠へ流用しない。V10.1c・V10.3c/d/eで取りまとめが関係状態の変更を照合し、P/P-finalを新規取得する。新しい入力変更・引用不能はJ3へ返す |

この関係状態で引用不能のために追加実行を求める段はない。未採録の計時・外側argv等は上のとおり未取得のまま残し、成功した段の再実行を要求する理由へ置き換えない。対象HEADが変わる場合は、変更された入力を読者へ対応付けて本票を更新する。

最終manifestの保存物のbytes/hashは記録作業でも読み戻し、一致12,904・不一致0・合計3,476,222,140 bytesであった。[final-output-audit.json](final-output-audit.json)へ保存した。元のverifyの再実行ではない。交換の版はcorpus15/sidecar7/独立coverage4を維持する。[保存CLIと50報告の同定](cli-and-producers.json)では、報告のversion=0.0.13・commit=B_WORK・target=aarch64-apple-darwinを確認した。dirtyはnull/notCollectedのままであり、cleanという証拠へ変換しない。バイナリのハッシュは記録時点に読み取った値である。

## V10.1db: 引用票の追補（2026-10-30）

初稿の本文・件数を残し、[RV-V10.1d の対応](../reviews/RV-V10.1d.md#対応取りまとめ)により次の欄を補正する。対応箇所の一覧・段別の原値・確認方法は [results.md の追補](results.md#v101db-rv-v101d-への追補2026-10-30)、個別のハッシュと更新時刻は [v10.1db-evidence.json](v10.1db-evidence.json)による。

| 指摘・補正する欄 | 追補後の判断と根拠 |
|---|---|
| 中1: 終了・時間・最大常駐量 | 各16段の最大常駐量と peak memory footprint の bytes 原値・GiB、A 全体の外側の値、旧全体の値を results の表に記した。区間比較は最大常駐量16,016,441,344 bytes＝14.916473 GiB・footprint30,032,057,704 bytes＝27.969533 GiB、manifest の footprint は30,307,931,664 bytes＝28.226461 GiB、collect は24,978,917,232 bytes＝23.263430 GiBである。物理メモリは34,359,738,368 bytes＝32 GiB。`sysctl -n hw.memsize` は環境制限で終了1、同じ項目を sysctlbyname で読んで確認した。16 GB 級の計算機では同じ手順で走る保証がなく、ほかの重い作業と並べて走らせない。K10.3 一回目全体の14,372,323,328 bytes＝13.385269 GiBは getrusage の補助値で、測り方・対象範囲が異なり、増えた原因は断定しない。docs/todo の TODO-314 の区間の manifest の重複と最大常駐量の課題に関連するが、原因を特定した意味ではない |
| 中2: 判断者・日付 | 実行と引用の範囲は、[README「設計者の委任（2026-10-30）」](../README.md#設計者の並行作業中の判断2026-10-28-午後r-段)を根拠とする、設計者の委任による取りまとめの判断である。J2 の起動前の了承に代えて、範囲と45〜75分の見込みを記録してから起動した。追補の保存証拠の照合と引用判断は記録担当、2026-10-30 JST。独立レビュー・設計者の受け入れとは区別する |
| 軽1: 引用出力の来歴と最終状態 | 複写3,174件のうち、最終 SHA-256 と更新時刻が写し元に一致して引用のまま残るのは316件。同じバイト列の残る73件は check_named が再生成して更新時刻が変わったもの。同じバイト列の合計389件と、計時欄だけ変わった2,785件という初稿の件数は維持する。「引用したまま」の範囲は316件に限り、再生成された73件も B2 の実行結果として扱う |
| 軽2: 設定・固定版・道具 | Python 3.9.6 は [直前の V10.3a の記録](../v10.3a/environment.json)の値を引いた。V10.1d の実行では取得しておらず、当該実行時の実版を確認済みとはしない |
| 軽3: H31 と個別義務 | 署名の非 Top の固定添字と範囲付き prim への転送を最終 F-U で照合したため、義務の行35を閉じてよいという判断を維持する。ただし、[RV-UB30 軽2](../reviews/RV-UB30.md#指摘)の、effect を宣言する testdata 36件の一つ一つが書き出されたか（除外されていないか）は確かめていないという限界は残る |
| 軽4: 以後の変更の全一覧・引用先の差分 | B_WORK・HEAD は初稿と同じ `7179a3026fcf2b463c1ec933aefd23256be6dc93`。その後に [V10.1c の修正](../v10.1c/results.md#原因と修正)として `crates/benitoite/src/typeck/tests/interpolation_formats.rs` の109行を `benitoite::types::builtin::RangeIndex::TOP` から `crate::types::builtin::RangeIndex::TOP` へ置換した差分がある。`typeck/mod.rs` の `#[cfg(test)] mod tests` の中の1行であり、書き出しに使う lib は test の構成でなくビルドされる。全比較の書き出しと読者の入力ではなく、各比較段の再実行を要しない。旧新内容・差分の SHA-256 は証拠の changesAfterV101d に保存した |
| 同欄: 作業時点に存在した V10.1cb の追加差分 | [V10.1cb](../v10.1c/results.md#v101cb-二回目の-change-の失敗と統合テストの期待値の修正)による `crates/benitoite/tests/scope_annotations.rs` の期待値の修正も、現在の以後の変更に含めた。独立した統合テストであり、全比較の書き出し器・固定入力・期待値・読者の入力ではない。旧新内容・差分の SHA-256 を同じ証拠へ保存し、全比較の再実行を要しないと判断する。README の委任の追記と `v10.1c/`・レビューの記録も全比較の入力ではない。初稿の final-state と「追跡木に差分なし」は初稿時点の記録として残す |

この追補は最終の関係状態への引用に追加差分を対応付けたものであり、全比較や formal_build の実行を追加したものではない。通常の Rust の検査は取りまとめの change の結果で覆い、本作業では指定の work の dry-run だけを一度実行する。

作業末の dry-run は [保存ログ](v10.1db-work-dry-run.log)のとおり終了0で、fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally の7単位を選んだ。選ばれた検査は実行せず、依頼で示された取りまとめの change の結果で覆われるものとして記録する。初稿の dry-run の選択0件を現在の選択としない。
