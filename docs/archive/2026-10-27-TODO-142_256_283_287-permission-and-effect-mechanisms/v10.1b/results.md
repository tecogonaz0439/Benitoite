# V10.1b: 回帰・J2 の差分案・UB30.01-1（H31）の局所比較

V10.1b の初稿の件数・文案・実行記録は残す。RV-V10.1b への対応後の一覧と文案、引用判断は末尾の「V10.1bb 追補」を正とする。

## 作業と状態

2026-10-30 JST、担当。B_WORK・HEAD は `bae86164de063a9807784513e8960e46536d9f4b`、ブランチは `m013/v10.1b` である。J2 の公開入口による再現、未適用の登録差分案、書き換え一覧、H31 の独立期待値と局所比較、H11 の読解照合を完了した。H08・H09・義務の行23は未確認、行35は最終確認待ちの未完を維持する。

変更は本ディレクトリの記録と、`crates/benitoite/tests/desugar_export/range-sources/` の2入力および `expected.json` のcase追加だけである。本番ソース・設計書・他のテスト・testdata・計画・git の履歴とindexは変更していない。`private/`、そこを指すスキル、`docs/todo/` は読んでいない。Lean のビルド・全比較・新しい CARGO_TARGET_DIR・性能測定は実施していない。

根拠は [plan-v10](../plan-v10.md)、[README の決定](../README.md)、[V10.1a の申し送りと追補](../v10.1a/results.md)、[義務の行23・35](../v10.1a/obligations.md)、[UB30.01b 後の本文](../ub30.01/results.md)、[RV-UB30](../reviews/RV-UB30.md)、[K10.2 の範囲の実ソースの記録](../k10.2/results.md)である。記録と引用は [07-03「結果の保存と引用」](../../../design/07-quality/07-03-compiler-testing.md#結果の保存と引用)に従う。

## J2 の再現

[事前期待値](j2-expected.json)を [固定記録](j2-freeze.json)の時刻に保存してから、既定の target へ CLI をビルドした。両入力は先頭で `language "0.0.12"` を宣言する。

| 入力・公開入口 | 実行前の期待 | 結果 |
|---|---|---|
| [j2-send-only.bnt](j2-send-only.bnt) を `benitoite check --report=json` | 終了2、E0501一件、7行19列の `protected()`。UTF-8の半開バイト範囲194〜205。残る効果は `Http.Connect["api.example", 443]` | コード・位置・効果とも一致した。[生ログ](j2-send-only.log)・[計時](j2-send-only.json) |
| [j2-complete.bnt](j2-complete.bnt) を同じ公開入口へ渡す | 終了0、診断なし | 一致した。[生ログ](j2-complete.log)・[計時](j2-complete.json) |

保護関数は `Http.Connect["api.example", 443]` を宣言し、本体は整数を返す。通常の静的な契約の残り方を確認する入力であり、HTTP通信は実行していない。旧 send 一節では、保護関数の呼び出しが Connect を残す。完全なハンドラは純粋な main として受理された。旧版の実行ファイルとの比較を行った結果ではない。登録後の E0908 より前に、この現在版の振る舞いを再現できた。

[個別の照合結果](local-verification.json)は、実行前の期待値のハッシュ、診断のコード・位置、完全なハンドラの受理を確認している。再現不能の項目や判断待ちはない。

## J2 の差分案と書き換え一覧

[差分案](j2-registration-proposal.patch)は次の3ファイル分であり、適用していない。`git apply --check` は終了0であった。版0.0.13への更新と併せたコンパイル・テストは V10.3a の担当である。

| パス | 差分案の内容 |
|---|---|
| `crates/benitoite/src/modules/package.rs` | BREAKING_CHANGESへVersion(0,0,13)を登録する。`version_check_reports_all_applicable_changes_in_version_order` の登録表を読む部分に、0.0.13のsummary/help、版順、current/end/firstを追加する |
| `crates/benitoite/src/modules/text.rs` | 事実だけの英文summary/helpを追加する。既存の過去の文言は保持する |
| `crates/benitoite/src/modules/tests.rs` | `language_versions_check_the_release_boundary_in_each_header_location` のentry/config/dependencyすべてで、0.0.12→E0908、0.0.13→受理、0.0.14→E0907とする。旧版のnote/helpに今回の行を版順に加える |

summary案は “Handlers with only an Http.send clause are partial handlers; Http.Connect remains unhandled.”、help案は “Benitoite 0.0.13 includes additional Http operations; handling Http.send alone leaves Http.Connect in the effect contract.” とした。計画の文案を再現と照合して採った。節の書き換え方・移行の手順・移行の例は含めない。これは独立レビュー前の案である。

[書き換え一覧](j2-rewrite-inventory.md)と[全パス・各出現・理由・読者・ハッシュのJSON](j2-rewrite-inventory.json)を保存した。件数は次のとおりである。

| 区分 | 件数 | 扱い |
|---|---:|---|
| testdataの `language "0.0.12"` | 50ファイル | 既存の検査目的へ到達させるheaderを0.0.13へ更新する候補。個々のfixture・依存・全比較の読者を対応付けた |
| テスト内の版文字列 | 統合5・src内4、計9ファイル | 成功用headerと編集結果は更新し、旧版境界・過去の説明は区別する |
| 登録表と文言 | 2ファイル | 上のpackage.rsとtext.rs。9ファイルに含めない |
| 指定の `.diag.json` | 4ファイル | dependency-settings/newer-config/newer-languageはE0907の現在版表示。older-languageは古い宣言と最初の変更を保持し、0.0.13のnote/helpを追加する |
| 依存ハッシュ | 3組・変更先4か所 | hashkitの2か所は上記以外の2ファイル。modules/hash.rsとpackage_command.rsの固定値は9ファイルに含む |

重複を除く書き換え先は67ファイルである。別に、一括置換から除く理由を8行にまとめた。旧0.0.4を狙う拒否・将来99.0.0を狙う拒否・hash-mismatchの全ゼロ・過去の登録と説明を保持する。宣言上の不正な親への依存を、各パッケージを実際に読む経路へ数えていない。

ハッシュは06-09「中身のハッシュ」の規則から、変更後のheaderをメモリ上で使って独立に再計算した。現在の処理系に計算させた値は使っていない。旧値は既存の固定値と一致した。提案する新値と全入力バイトのSHA-256、変更先をJSONへ記した。hash-matchの成功用hashとhash-mismatchのcomputed noteを対で変更し、後者のexpected=全ゼロは保持する。packageコマンドとmodules/hash.rsの固定値も、それぞれCONFIGと同時に更新する。testdata・版・登録・これらの期待値への適用は V10.3a で行う。

## H31 の独立期待値と F-L

[事前期待値](h31-expectations.json)と[固定時刻・ハッシュ](h31-freeze.json)を、処理系を実行する前に手で定めた。[固定台本](freeze-h31.py)は処理系を呼ばず、既存の初稿を上書きしない。元のexpected.jsonは [変更前の写し](h31-expected-before.json)として保存した。既存31caseの期待値は一つも変更していない。

| 追加case | 終了・定義 | 手書きの非Top数（candidatesを除く） | 効果と確認点 |
|---|---|---:|---|
| h31-user-signature | 終了0、sampleの1定義 | 3 | Audit.logの署名のPathIn固定添字1、sampleの表層・コアの引数型各1。効果は利用者原子AuditのTop |
| h31-user-forward | 終了0、sampleの1定義 | 7 | 上の3に、両headerのFile.Write各1と、両本体のFile.writeTextInの範囲各1を加える。効果は `File.Write["/srv/audit/**"]` |

両入力は UB30.01 の a-inline を基にし、既に検査済みのPathInを受け取るsampleへ絞った。Audit.logの値引数にある `/srv/audit/**` の固定添字と、同じ狭い型を節から範囲付きprimへ渡す組合せだけを追加した。利用者エフェクトへの範囲引数は追加していない。

固定した `crates/benitoite/tests/desugar_export/range-sources/expected.json` のSHA-256は **`2e240f8fc90bfd34fca382432b1cff63cacee31c6a32cf66995187d119d9ee42`** である。H31だけの期待値のSHA-256は `29b0cf83997ffd88c394c733a4956abaf12734dd6af42a5816de8a8f78397144`。2入力のハッシュは固定記録にある。実行後も同じ値である。

F-Lでは、書き出し1テスト・既存の六入口を使う比較とも終了0となった。追加2件は書き出せており、対象外・定義の除外はない。[追加の照合器](verify-local.py)で、独立期待値に対する署名の引数添字、全定義のheader効果、表層・コア双方のprimの範囲を個別にも照合した。[結果](local-verification.json)は両入力の全定義と3/7の非Top件数の一致を示す。利用者原子そのものの添字はTopのままである。

既存15群18定義・非Top12群57・Top互換3群を保ち、合計は **受理17群20定義・非Top14群67・Top互換3群** となった。拒否8・コード付き除外8、報告側26入力50コマンドも保持した。[比較集計](f-l-summary.json)・[全入力と型表・定義のmanifest](f-l-source-manifest.json)を保存した。追加2群のprogram coverageは空であり、coverageProgramDiffの期待する終了1を非空の比較成功へ数えない。六番目の独立coverageDiffは既存の1件を別に確認している。

この成功は版上げ前の局所の関係状態に限る。[義務の行35](../v10.1a/obligations.md)は閉じない。V10.3a後のV10.1dで範囲の実ソースの段を再確認し、最終F-Qへ反映する必要がある。expected.jsonが変わったため、K10.3bの範囲の実ソース・range_counts・最終manifestの入力ハッシュは古くなる。全比較の不変の段を再実行した結果ではない。

## Lean のビルド成功の引用

F-L起動前の [照合](lean-prerequisites.json)では、V10.1aのrelation-state.jsonが結び付けるK10.3bのsourceHashesから、formal全体と固定Rust版の409項目を読み取り、すべてSHA-256が一致した。六つの必要な交換実行ファイル（desugarDiff、builtinCheck、surfaceCheck、surfaceCheckAll、coverageDiff、coverageProgramDiff）に加え、intervalDiffも一致した。lakefile.toml・lake-manifest.json・lean-toolchain・rust-toolchain.tomlとLeanのソースを含む。

元の [K10.3の結果](../k10.3/results.md)・[V10.1aの引用票](../v10.1a/results.md)が同定する既定ビルド573ジョブ・終了0・sorryなし、交換実行ファイルのビルド成功を引用する。引用先は本作業のB_WORKと許可された差分である。今回変えた2入力とexpected.json、記録・差分案はLeanのビルド入力や交換器を変えない。判断者は担当、判断日は2026-10-30 JSTである。実行ファイル・設定・固定版の一致を理由とし、現在のLean/elanの実版を再取得したことにはしない。

[実行後の全入力照合](relation-state-after.json)では、元の4,680件のうち4,679件が一致し、唯一の差分は予定したexpected.jsonである。追加の2入力は別に同定した。別状態への引用に要る未コミット差分と未追跡入力のSHA-256は最終状態記録へ残す。formal_buildと六交換実行ファイルの新しいビルドは0回であり、K10.3の全比較を今回新たに実行したとはしない。

## H11・H08・H09・行23

[個別の照合文書](h11-and-unconfirmed.md)に、ファイル・位置・読解で確定する相違と実行が必要な差を分けた。01-06の「だけ」は、lower.rsの定数本体・withの二つ目以降の束縛の記録命令を網羅しない。V10.2aへ、この記録位置を文書に補う案を渡す。受理する入力の差を示す短い具体的な反例は特定できておらず、振る舞いの差を確認済みとはしない。資源の型の制約で先に拒否される入力を、この問いの再現として追加していない。

H08のE0521の自然な到達と案内の解消効果、H09・行23の通常ソースでの全体保持2,048への到達は未確認のままである。小さい予算の試験や他の3上限の到達を、この上限の到達へ読み替えない。無目的な大入力を作らず、行23の計上順・忘却費用の全項目・changeのlong_only両構成まで閉じたとはしない。

## 実行した検査と時間

正確な引数・環境・開始終了・直接の終了・外側時間は各JSON、生出力は同名logに保存した。手元の絶対パスは `<wt>` 等へ置換した。計時は指定どおり `/usr/bin/time -p` であり、`-l`は使っていない。

| 実行 | 終了 | timeのreal / user / sys（秒） | 記録 |
|---|---:|---|---|
| CLIビルド `cargo build -p benitoite --bin benitoite` | 0 | 6.13 / 2.88 / 1.09 | [JSON](cli-build.json)・[log](cli-build.log) |
| J2の旧send一節のcheck | 2（期待どおり） | 1.20 / 0.13 / 0.02 | [JSON](j2-send-only.json)・[log](j2-send-only.log) |
| J2の完全なハンドラのcheck | 0 | 0.11 / 0.10 / 0.00 | [JSON](j2-complete.json)・[log](j2-complete.log) |
| F-L: `BENITOITE_DESUGAR_DIFF_DIR=<wt>/target/v10.1b/export cargo test --test desugar_export range_sources::export_range_sources -- --exact --nocapture` | 0 | 9.53 / 7.69 / 1.74 | [JSON](f-l-export.json)・[log](f-l-export.log)。1成功、48filter |
| F-L: `python3 -B formal/tests/test_range_sources.py --exports <wt>/target/v10.1b/export/range-sources --cli <wt>/target/debug/benitoite --output <wt>/target/v10.1b/compare` | 0 | 9.25 / 7.10 / 0.87 | [JSON](f-l-compare.json)・[log](f-l-compare.log)。上記17群・20定義 |
| W-Rの同一指定のdry-run | check.sh自身0、time0 | 0.13 / 0.04 / 0.21 | [JSON](w-r-dry-run.json)・[log](w-r-dry-run.log) |
| W-R実行（下記） | check.sh自身0、time0 | 170.25 / 984.16 / 28.50 | [JSON](w-r.json)・[log](w-r.log)・[直接の終了](w-r-command-exit.json) |

W-Rの指定は、基準 `bae86164de063a9807784513e8960e46536d9f4b` に対する `scripts/check.sh --level work --base <B_WORK> --test golden --test desugar_export` である。直前の同一指定に `--dry-run` を付けた実行で7項目の自動選択と理由を確認してから、一度だけ実行した。`run.py` はW-Rのcheck.shを子として待ってその終了を保存し、外側のtimeの終了と分ける。

選択はfmt、既定のgc-mark-sweep構成のclippy（lib/tests/examples）、既定lib全件、関連統合のgolden/desugar_export、source_rules、skill_generated、spec_tallyである。libは1,392成功・22ignored、desugar_exportは48成功・1ignored、goldenは2成功、失敗はすべて0だった。desugar_exportのignoredは全corpus書き出しであり起動していない。仕様集計は参照テストのない節を一覧表示したが、初回リリース版の未記入条件はnoneで終了0となった。生成Skillに内容差分はない。random_differentialという別の統合ターゲットは今回の選択に含まれず、60秒の超過・再確認もない。他のビルドや長い検査と並行していない。

`time -p`が表示する値はreal/user/sysだけであり、最大常駐量は取得不能である。RSSを0と記録せず、別方式の補助RSSも今回追加していない。user時間は子孫のCPU時間でありreal時間と同一ではない。

## 作成時の関門

公開test-auditの四つの問いに対して、次を確認した。守る契約は、通常ソースの利用者操作の固定範囲の署名が交換へ残り、同じ狭い型を節から範囲付きprimへ渡せることと、全定義・範囲の比較である。現実的な退行は、利用者操作の型をTopへ落とす、転送時の範囲を失う、利用者とprimの参照を取り違える、定義を対象外へ落とすことである。既存のrange-sourcesとnamedの成功にはこの署名と転送の組合せがなく、CLI報告の成功だけでは交換への接続を確かめられなかった。そのため既存の表形式の書き出し境界へ2caseだけ加えた。本番の差し込み口・公開範囲・新しいフラグは増やしていない。

固定値は実行前に独立して書き、出力から作っていない。添字と効果を個別に照合する際も、既存の全定義・六入口の比較を置き換えていない。登録表のテストの変更は差分案に限り、版順と公開loaderの三位置という既存の契約へ行を追加する案とした。

## 失敗・ずれと保存

追加照合器の初回は、公開名File.writeTextInと交換の完全名Benitoite.IO.File.writeTextInを直接比較して停止した。builtins/table.rsの登録名を読み、同じ宣言の名前の対応を照合器へ加えた。[経緯](helper-failure.md)を残し、固定入力・期待値・交換器・F-Lの出力は変更していない。これは局所比較の不一致ではなく、補助の照合器の誤りである。F-L・W-Rの再実行はない。

W-Rでは書き出し先の環境変数を渡し忘れたため、既存テストが `target/<用途>/export-11342/` に出力した。終了後、このW-RのテストPIDが新規作成した22ディレクトリ・301ファイル・35,796,277 bytesだけを `target/v10.1b/work-export/` の下へ移し、全内容のハッシュの不変を確認した。[移動一覧](work-output-relocation.json)を残す。K10.3の三つの保存先は書き換えていない。許可された局所出力先から一時的に外れた点をずれとして記録する。

最終状態を作る補助Pythonの初回は、UTF-8の本文に対するencoding指定の不足としてSyntaxErrorを報告し、書込み前に停止した。ファイルのUTF-8が正しいことを読み取りで確認し、encoding指定を明示して実行した。処理系やF-L/W-Rの失敗ではない。

手前の読解コマンドでは、存在しない候補ファイル名や未一致のglobが終了1/2となった。また、ツール呼出しを組み立てるJavaScriptの一回はSyntaxErrorで実行前に停止した。いずれも書込み前の読解・呼出しの誤りであり、処理系の検査の失敗や禁止領域の読解ではない。

F-Lの書き出し・比較出力512ファイルは [全一覧](local-output-inventory.json)に相対パス・大きさ・SHA-256を残し、[圧縮した証拠](local-evidence.tar.gz)にも保存した。圧縮物の大きさ・SHA-256は [実行後の照合](relation-state-after.json)にある。追跡する記録がtargetだけを根拠にせず後から比較結果を読めるようにした。ローカルの全出力はtarget/v10.1bに残す。K10.3の巨大manifest等は再生成していない。

## 停止判断と後続

計画外の機能変更、交換器の拡張、J3の想定外の比較差・引用不能、再現できない回帰、時間超過による停止はない。今回の局所比較は成功したが、次の作業を完了したことにはしない。

| 後続 | 残る作業・受け持ち | 見込み |
|---|---|---|
| V10.1bの独立レビュー・受け入れ | 取りまとめが本記録・未適用patch・67ファイルの一覧・独立期待値と保存出力を確認し、設計者が受け入れる | レビュー10〜20分、受け入れ待ちは不明 |
| V10.2a | H11の記録位置の文書への反映とH08/H09等の未確認の維持 | 全体の計画1〜2時間。今回分だけの内訳は不明 |
| V10.3a | 版0.0.13と登録・テスト・testdata・hash・diagを同時適用する。今回の差分案を単独適用しない | 全体の計画1.5〜3時間、検査10〜20分 |
| V10.1d・F-Q | 設計者の了承後に影響段を再確認し、H31の最終関係状態と義務の行35を照合する | 能動0.5〜1時間、実行45〜75分＋初回費用不明。起動前に取りまとめが再見積もりする |

H23について、本作業は本番・埋込みSkill・測定入力を変えないため性能測定を追加しない。後のV10.3aの実差分で測定経路が不変かを判断する責任は取りまとめに残す。H08・H09・行23の未確認は後続にも保つ。

## 作業末の確認と所要

開始の採時計は2026-10-30 02:21:46 JST（2026-10-29 17:21:46 UTC）である。F-Lの書き出し・比較は計18.78秒、CLIビルドは6.13秒、W-Rは170.25秒であった。能動時間と短い読解・書込み待ちを厳密には分離計時していない。終了時計・外側の所要・最終の差分と未追跡入力のSHA-256は最終状態記録へ保存する。見込み1〜3時間と6時間の停止条件は変更していない。

終了の採時計は2026-10-30 02:37:21 JSTである。開始時計からの外側の所要は935.26秒（約15.6分）で、能動時間は約12.3分の概算である。検査・ビルド待ちの一部と文書作業は重なるため厳密な分離ではない。独立レビュー・設計者の回答待ちは含めない。6時間の停止条件には達していない。

最終確認では、既存31caseと固定した追加2caseの期待値、許可された差分だけであること、Python台本の構文、相対リンク63件、手元の絶対パスと禁止先リンクの不在、HEAD・ブランチ・indexの不変を確認した。[最終状態](final-state.json)へ差分と未追跡入力のSHA-256を保存した。K10.3の最終3manifestのハッシュも元記録と一致した。最後の追記は記録だけであり、F-L・W-Rを繰り返していない。

## V10.1bb 追補

2026-10-30 JST。[RV-V10.1b「対応（取りまとめ）」](../reviews/RV-V10.1b.md#対応取りまとめ)の V10.1bb の行を反映した。基準・HEAD はともに `bae86164de063a9807784513e8960e46536d9f4b`、ブランチは `m013/v10.1b` である。本追補の編集先は `v10.1b/` の文書・差分案・記録用の台本だけであり、`rv-probes/`、範囲の実ソースの入力と `expected.json` は変更していない。新しい判断を要する停止条件は生じなかった。

### 直した箇所

| 指摘 | 追補の内容と置き場所 |
|---|---|
| 中1 | 指定の検索で候補を数え直し、`pattern_ext.rs` のテスト内の宣言を追加した。[書き換え一覧の追補](j2-rewrite-inventory.md#v101bb-追補rv-v101b-中1中2)とJSONの `testFiles`・`firstDraftCounts`・`counts` に反映した |
| 中2 | 同一覧の「文書の例」へ6ファイルを追加し、読むテスト、V10.3aでの更新・保持の案を添えた。版表示・固定参照・訳元表示の11ファイルも別区分へ追加した |
| 中3・軽4 | [patch](j2-registration-proposal.patch)と[作成台本](make-j2-proposal.py)のsummary/helpを修正し、登録表と境界テストのnotes/helpsの期待値の案も同じ文へそろえた |
| 中5 | 下の「H31の照合範囲」で常設の比較と個別の照合を区別し、V10.1dへの実行の申し送りを追加した。比較器は拡張していない |
| 軽6 | `expected.json` は固定したハッシュを保ち、数え方を `h31-expectations.json` に置く理由を追記した |
| 軽7 | 作成時の関門の追補として、signatureの場合だけが捕まえる退行を下に一文で記した。入力は2件とも保持した |

### 検索と件数

リポジトリの根で `git grep -n -E '0\.0\.12|0, 0, 12'` を実行し、終了0、**955ファイル・2,611行**を得た。生出力（20,923,657 bytes。[LARGE-FILES.txt](LARGE-FILES.txt) に大きさと SHA-256）と[全一致ファイルの分類](v10.1bb-version-grep.json.gz)を保存した。エスケープした `language \"0.0.12\"` も検索に掛かる。検索は追跡ファイルの現在の内容を対象とし、未追跡の本追補自身は数に含めない。

初稿の50件・9テストファイル・重複を除く67ファイル・除外8行は上に残した。追補後のテストは統合5・src内5の計10ファイル、登録・文言の2ファイルを加えた区分全体は12ファイルである。`crates/benitoite/src/typeck/pattern_ext.rs:920` は `#[cfg(test)]` のexternalの場合で、根のMemFsの `package.bnt` に正常な版を宣言する。登録後もパターンの検査へ到達させるため、V10.3aで0.0.13へ更新する候補とした。文書を加える前の重複を除く書き換え先は68ファイルとなる。

「文書の例」に追加したのは `docs/design/01-spec/01-02-syntax.md`、`docs/design/06-tooling/06-09-packages.md`、`docs/reference/{benitoite,install}.md`、`docs/ja/reference/{benitoite,install}.md` の6ファイルである。これらを含む重複のない書き換え候補は**74ファイル**となる。関連する版・固定参照・訳元の表示11ファイルはこれらと重ならず、保持判断を含む確認・編集候補の全体は85ファイルである。JSONの `counts` とMarkdownの追補の件数は同じ集合から数えた。初稿の作成台本はそのまま残し、[追補台本](v10.1bb-inventory.py)で追補を再生成できる。

英語リファレンスの2059行の `files` と2077行の本文は `reference_examples` の共通実行器がCLIの `run` へ渡し、2109行の `files` は `check` へ渡す。三つとも実ローダによる版の照合があるため、現在版の正常な例として0.0.13へ更新する案である。01-02の477行のtextの例は `spec_examples::spec_and_appendix_examples_are_readable` が読み、`check_local_bindings` から `pipeline::check_files` へ渡す。ただし同テストの診断の絞り込みはE0907/E0908を失敗条件に含めず、版の受理自体を守る検査ではない。現在版の例へ更新する案とし、版上げ後に束縛の検査まで到達することはV10.3aで確かめる。06-09・日本語訳・install.mdをこの英語リファレンスの実行対象とみなしていない。

検索で拾ったその他の関連ファイルには、Cargoの版・二lock、README、同梱Skillの固定参照と日本語訳元の表示がある。V10.2b/V10.3aの分担に合わせた案を一覧に追加した。過去の移行節・inlineの古い宣言・過去の登録は保持し、0.0.13の移行手順へ書き換えない。候補83ファイルのほか、検索に一致した保管済み文書37ファイル、今回の改造の入力・結果・レビュー・計画の記録834ファイル、過去のCHANGELOG 1ファイルを保持に分類した。74/85は検索の全一致数ではなく、既存のハッシュの変更先等も含む一覧の件数である。

### 診断の新しい文案と適用可否

- summary: `handlers with only an Http.send clause are partial handlers; Http.Connect remains unhandled`
- help: `Http.Connect declares send and sendIn; a handler that handles only Http.send leaves Http.Connect in the effect contract`

summaryは小文字から始め、helpの先頭は固有の名 `Http.Connect` とした。どちらも末尾に句点を付けない。`Http.Connect.sendIn` が加わって二操作になった事実と、旧sendの節だけではConnectが残る事実を示す。節の書き換え方・移行の手順・移行の例は含まない。登録表とloaderの三位置の境界テストのnotes/helpsも同じ文に直した。

修正したpatchへの `git apply --check` は**終了0**であった。[引数・終了・時間・patchのSHA-256](v10.1bb-patch-check.json)と[生出力](v10.1bb-patch-check.log)を保存した。patchは適用しておらず、版上げと併せた実コンパイル・テストはV10.3aに残る。

### H31の照合範囲と作成時の関門の追補

`expected.json` の `h31` の欄は、常設の比較器 `formal/tests/test_range_sources.py` が読まない。署名の非Topと節から範囲付きprimへの転送の二点は、V10.1bの `verify-local.py` の個別の照合で確かめた。常設の比較はH31固有の内訳については候補欄を除く非Topの件数3・7だけを守り、primの取り違えや、総数が同じまま位置が変わる退行まで個別に捕まえるものではない。既存の終了・定義数・surface・六入口の比較を保つことと、この追加の個別照合の範囲を区別する。

数え方は [h31-expectations.json](h31-expectations.json) の `counting` にある。signatureは操作headerのPathInが1、sampleのsurface/coreのheaderのPathInが各1で計3である。forwardは、これに両headerのFile.Writeが各1、両本体のFile.writeTextInのrangesが各1で計7となる。節の引数の型は操作headerから得ており、節のarityから重ねて数えない。`expected.json` の `nonTopRangesAddition.counting` へこの説明を足さない理由は、実行前に固定した入力・期待値のハッシュを保つためである。`expected.json` のSHA-256 **`2e240f8fc90bfd34fca382432b1cff63cacee31c6a32cf66995187d119d9ee42`** と `h31-expectations.json` の固定ハッシュは不変である。

作成時の関門の「signatureの場合だけが捕まえる退行」は、**操作headerのAuditはTopのままなのに、非TopのPathInを値引数に持つsampleの未処理のAuditをsurface/coreのheaderへ書き出す際、そのPathInの範囲で狭める退行であり、Auditを完全に処理するforwardと、範囲付きの値引数を持つ利用者操作ではない既存のuser-spellingでは捕まえられない**。この点は `verify-local.py` がsampleのsurface/coreの効果を操作headerのTopの効果と一致させて照合する。新しいテストや差し込み口を加えた説明ではなく、既存2入力の役割の区別である。

V10.1dへの申し送りは、**F-Uで `verify-local.py`（または同等の照合）を版上げ後の書き出しに走らせる**ことである。現台本は `target/v10.1b/export` と `compare` を固定して読むため、そのまま古い出力へ走らせて版上げ後の成功としない。新しい出力先を使い、固定したH31期待値へ署名・Topの利用者原子・header効果・surface/core双方のprimとranges・全定義・3/7の件数を個別に照合する。F-Uの起動の範囲と見込み、設計者の了承は従来どおり取りまとめが受け持つ。比較器は拡張せず、義務の行35は最終確認待ちの未完を保つ。

### W-Rの引用と追補の検査

本追補は `v10.1b/` の文書・未適用の案・記録台本だけであり、W-Rの関係するソース・入力・期待値・設定・生成物を変えていないため、V10.1bのW-R実行を引用する。元の [w-r.json](w-r.json)・[w-r.log](w-r.log)・[final-state.json](final-state.json)は書き換えず残した。

| 07-03の欄 | 引用の対象と根拠 |
|---|---|
| 状態 | 元・引用先ともB_WORK/HEADは `bae86164de063a9807784513e8960e46536d9f4b`。元と同じ追跡差分はrange-sources/expected.jsonだけであり、未追跡のH31入力2件も固定ハッシュと一致する。追補の変更一覧と未追跡記録のSHA-256は追補の最終状態へ別に保存する |
| 入力 | 本番ソース、テスト本体、testdata、全range-sources、Cargo・二lock・build.rs・固定版、生成元/物、交換器・比較器・設定に追補の変更はない。元の関係状態と固定入力の同定はfinal-state.json、h31-freeze.json、relation-state-after.jsonを引く。未適用patchはコンパイル・実行されない。補助PythonはW-Rの実行入力ではない |
| 実行 | 元の正確な指定は `scripts/check.sh --level work --base bae86164de063a9807784513e8960e46536d9f4b --test golden --test desugar_export`。既定gc-mark-sweep構成、Rust/Cargo 1.98.1、Darwin arm64等はenvironment.jsonを引く。fmt、clippy、lib、関連統合、source_rules、skill_generated、spec_tallyの7項目。lib 1,392成功/22ignored、desugar_export 48成功/1ignored、golden 2成功、失敗0。check.sh・timeとも終了0、外側170.259秒。time -pのためRSSは取得不能である |
| 以後の変更と判断 | 変更は本追補の一覧・文案・記録だけで、元の検査対象のバイト列を変えない。判断者は本追補の担当、判断日は2026-10-30 JST。作業末の同一指定のdry-runで選択も照合し、W-Rの実検査は追加しない |
| 初回の失敗等 | 元のW-Rは成功である。出力先の環境変数の指定漏れと局所領域への移動は初稿の「失敗・ずれと保存」およびwork-output-relocation.jsonをそのまま引く。今回その記録を消したり修正したりしていない |

F-L、全比較、Leanのビルド、性能測定は追加実行していない。V10.1bbの末尾のdry-run・最終の範囲確認・所要は以下へ追記する。

### V10.1bbの作業末の確認と所要

作業末の指定 `scripts/check.sh --level work --base bae86164de063a9807784513e8960e46536d9f4b --test golden --test desugar_export --dry-run` は一度だけ実行した。[出力](v10.1bb-work-dry-run.log)と[計時・選択の記録](v10.1bb-work-dry-run.json)を保存した。選択は元のW-Rと同じ7項目、すなわちfmt、既定構成のclippy、lib全件、関連統合のgolden/desugar_export、source_rules、skill_generated、spec_tallyであった。今回も元のexpected.jsonの差分を理由に選ばれており、検査そのものは実行していない。

外側に付けた `/usr/bin/time -l` は選択の全表示後に `sysctl kern.clockrate: Operation not permitted` と報告し、終了1となった。sandboxによる計時の制限であり、check.sh自身の終了値は分けて取得していなかったため未取得と記録した。表示されたreal/user/sysは0.10/0.03/0.20秒、Pythonの外側計時は0.110秒である。最大常駐量は取得不能であり0としない。dry-runを一度とする依頼に従い、この計時の制限のための再実行は行っていない。W-R実行の成功を今回のdry-run自身の終了0へ読み替えない。

最終の範囲確認ではrange-sourcesの全65ファイルとrv-probesの7ファイルのSHA-256が着手時と一致し、追跡差分のSHA-256もV10.1bのfinal-state.jsonにある値と一致した。初稿の一覧のMarkdown本文・件数を保持し、一覧の全85パスとJSONの件数を照合した。記録用Pythonは構文を検査し、相対リンクの参照先を確認した。HEAD・ブランチ・ステージの差分なしを確認し、状態を変えるgit操作は行っていない。[追補の最終状態](v10.1bb-state.json)に変更・追加の一覧、固定入力・記録のSHA-256、検査の引用と計時の制限を保存した。初稿の最終状態はその当時の記録として変更していない。

変更した既存ファイルは `results.md`、`j2-rewrite-inventory.md`、`j2-rewrite-inventory.json`、`j2-registration-proposal.patch`、`make-j2-proposal.py` の5ファイルである。追加したのは `v10.1bb-inventory.py`、`v10.1bb-version-grep.{log,json}`、`v10.1bb-patch-check.{log,json}`、`v10.1bb-work-dry-run.{log,json}`、`v10.1bb-state.json` の8ファイルである。すべてv10.1b内である。

採時計は2026-10-30 02:46:09 JSTから2026-10-30 02:54:45 JSTまで、外側の所要は516.13秒（約8.6分）であった。冒頭の短い読解は採時計前で未計測である。能動時間と読解・記録の待ちを厳密には分離していない。patchの確認は約0.009秒、dry-runの外側計時は約0.110秒であり、実テスト・測定・レビュー・回答の待ちは追加していない。2時間の停止条件には達していない。
