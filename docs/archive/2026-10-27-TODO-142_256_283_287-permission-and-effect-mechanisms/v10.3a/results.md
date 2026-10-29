# 版・登録・訳・公開文書の最終編集の結果

基準と開始時 HEAD は `92f9ac80f81d2299978d2051ddcdfdeea1843e6d`、ブランチは `m013/v10.3a` である。開始時に追跡対象の差分はなかった。開始は2026-10-30 04:08:18 JST（2026-10-29 19:08:18 UTC）である。指定されたリリース準備の編集を行い、コミットその他の git の変更操作は行っていない。`private/`、それを指すスキル、`docs/todo/` は読んでいない。

## 変更と一覧との照合

追跡対象は84ファイルである。[役割ごとの全ファイルと変更前後の SHA-256](changed-files.json)、[確認済み一覧との照合](inventory-audit.json)を保存した。

| 役割 | ファイル数 | 内容 |
|---|---:|---|
| 版と二つの lock | 3 | benitoite の製品版だけを0.0.13へ更新 |
| 登録・文言・Rust 内のテスト | 7 | package.rs、text.rs、modules/tests.rs、modules/hash.rs、external/tests.rs、diagnostics_batch4.rs、pattern_ext.rs |
| 統合テストと固定の書き出し入力 | 5 | cli_process、package_command、spec_examples、test_command、desugar_export/named.rs |
| testdata | 56 | 正常な宣言50ファイル、診断期待値4ファイル、hash-match の依存ハッシュ、hash-mismatch の計算値の診断 |
| 設計書の正常な宣言例 | 2 | 01-02の1宣言と06-09の2宣言だけを更新 |
| 英語文書の版 | 2 | reference/benitoite.md と install.md |
| 日本語訳 | 7 | reference 2、Skill 本体1、手書き参照4 |
| README・CHANGELOG | 2 | 現在版、変更記録へのリンク、新版の事実を反映 |

書き換え一覧の追補後の対象である testdata 50ファイル、テスト10ファイル、登録・文言2ファイル、診断4ファイル、依存ハッシュ3組・4変更先をすべて反映した。古い版・将来版・ゼロのハッシュを狙う5入力はバイト一致で保持した。過去の登録、note/help と CHANGELOG の0.0.12以下も保持した。一覧外の追跡対象を変えていない。記録・照合の台本と出力は本ディレクトリの49ファイルに置く。

### 版と二つの lock

`crates/benitoite/Cargo.toml` の版を変更し、次の二つを順に一度実行した。両方とも終了0であった。

```sh
cargo update --offline -p benitoite
cargo update --offline --manifest-path fuzz/Cargo.toml -p benitoite
```

[二つの lock の差分](locks.patch)と[限定差分の照合](lock-audit.json)のとおり、それぞれ benitoite の `version = "0.0.12"` から `version = "0.0.13"` への一行だけが変わった。各 lock 全体をこの一置換で再現できた。ルートの Cargo.toml、fuzz パッケージの Cargo.toml、一般の依存の版・checksum・依存辺は変えていない。依存の一括更新と取得は行っていない。

### 登録・テスト・依存ハッシュ

修正後の [登録の差分案](../v10.1b/j2-registration-proposal.patch)を適用し、成功用の宣言と期待値を同時に更新した。0.0.12はE0908、0.0.13は受理、0.0.14はE0907という境界を、入口・根の設定・依存の設定の三か所で照合する。summary と help は `Http.Connect` の `send`/`sendIn` と部分ハンドラの事実だけを述べ、節の書き換え方や移行手順は含めない。

test-audit の作成時の関門を通した。守る契約は、宣言位置ごとの受理境界、診断位置、最初の該当版、すべての該当 note/help の版順である。既存の表へ行を足し、登録漏れ・旧版や将来版の誤受理・診断の欠落を捕まえる。新しい重複テストや本番の差し込み口は加えていない。成功用 header と hash の同期は、テスト本来の検査へ到達するための更新である。

06-09「中身のハッシュ」の規則を処理系と独立に実装し、変更前後のバイト列から3組を再計算した。[入力のハッシュと変更前後](hash-updates.json)は一覧の提案値と一致する。

| 対象 | 変更後のハッシュ |
|---|---|
| hashkit | `sha256:3964a146fd259d0fef4d48af4ffb39ac0c824bd9ce6aaa67d3fef0e8211e6bdd` |
| modules/hash の固定値 | `sha256:730c7986f912d2cbafaf963824f1f28ed8bd731c4c04e28b7bd3ad288aa67546` |
| package_command の固定値 | `sha256:4eefbd9e6069548683f4aad0bed473b5b76b734591264b65e49b51854d70ffb8` |

### 文書の例・訳・公開文書

一覧の「文書の例」の案を採り、01-02、06-09、英語 reference と対応する訳の正常な宣言を現在版へ更新した。install の冒頭、reference の製品版・version の表示・互換境界・ソース配布の範囲も同期した。旧移行節と旧版を狙う説明は保持した。01-02の例は版診断自体を成功条件にしないため、今回の版の受理は loader の境界テストと組み合わせて確認する。検査器の条件は変えていない。

06-09「設定ファイルの検査」の登録説明の本文は今回の編集対象に含めず、正常な宣言例の数字だけを変えた。この本文の表は0.0.12までのままであり、0.0.13の登録説明の同期は取りまとめへ渡す。本文を担当の判断で追加していない。

前段の[英日対応表](../v10.2b/translation-map.md)の7ファイル20見出しと追補を訳し、5見出しを新設した。英語差分に含まれる Skill の「実行の前に」「テスト」、common-mistakes の冒頭の補正も反映した。derive の旧手順の削除、File.Write の宣言順、比較表の末尾、埋め込み文書の説明の限定も同期した。訳元は全7文書とも0.0.13であり、生成参照に対応する訳は新設していない。

担当の対照に加え、[独立した対照](translation-audit.json)で252組のコードフェンスの本文・情報文字列・順序、全見出しの数・階層・順序、版固定 URL の14出現が一致した。相対リンク184出現とアンカーに欠落はない。過去の英日移行節は開始版とバイト一致である。版固定のv0.0.12参照は、既存必須欄と区間解析を説明する用途を保った。v0.0.13のタグを取得できたという確認ではない。

README の現在版を0.0.13とし、リンクのラベルを changes にした。CHANGELOG は七操作の追加と旧 send だけの部分ハンドラの事実を含む短い新版の節とし、H21は[公開版での再現に基づく前段の判断](../v10.2b/changelog-draft.md)どおり載せていない。0.0.13の移行案内・移行例・手順・性能増減は書いていない。

## 生成物と性能判断

G の `cargo run -p benitoite --example gen_skill` は終了0、外側21.565秒であった。[出力](generate.log)と[終了値・時間](generate.json)を保存した。[生成参照66ファイルと bundle の照合](generated-audit.json)では、すべて開始版とバイト一致であった。生成物は手で直していない。bundle の追加編集を要する停止条件は生じなかった。

[測定入力の照合](benchmark-input-audit.json)では、台本・テンプレート・実際に読み込む固定入力32ファイルが不変で、測定用のソースとテンプレートには language 宣言がないことを確認した。今回変更した header 付き testdata や MemFs は測定器から読まれない。標準宣言と解析・型検査・実行の実装は不変であり、登録の追加は宣言した版の照合に使う。表示用の版と文書は測定する意味を変えないため、直前の short の判断を維持し、準備後の測定は追加していない。

## 検査

局所検査 `cargo test -p benitoite --lib modules::` は40件成功・失敗0、外側35.563秒であった。[出力](modules.log)と[終了値・時間](modules.json)を保存した。登録表と三か所の版境界、固定ハッシュを含む。

W-V は、先に[指定の dry-run](work-dry-run.log)を行い、終了0で自動選択と理由を確認した。[同じ指定の実行用台本](work-check.sh)を `/usr/bin/time -p` で包み、一度実行した。環境は `BENITOITE_DESUGAR_DIFF_DIR=<wt>/target/v10.3a/export` とした。新しい CARGO_TARGET_DIR は作っていない。K10.3 の保存物には書き込んでいない。

```sh
BENITOITE_DESUGAR_DIFF_DIR=<wt>/target/v10.3a/export scripts/check.sh --level work --base 92f9ac80f81d2299978d2051ddcdfdeea1843e6d --test spec_examples --test reference_examples --test skill_docs --test skill_examples --test stdlib_doc_examples --test build_info --test cli_process --test package_command --test test_command --test declarations --test golden --test desugar_export --dry-run
BENITOITE_DESUGAR_DIFF_DIR=<wt>/target/v10.3a/export /usr/bin/time -p sh <D>/v10.3a/work-check.sh
```

dry-run は9単位を選んだ。fmt、既定構成の lib・tests・examples の clippy、既定 lib 全件、指定12統合ターゲット、ソース規約、生成 Skill の鮮度、仕様集計、ライセンス、二対象の勧告照合である。spec_examples・reference_examples・skill_docs は tests_related に含まれ、別実行を省く。dry-run 後に増えた差分の件数は本ディレクトリの記録であり、実行時も同じ9単位と12ターゲットを選んだ。

本実行は2026-10-30 04:15:16〜04:19:33 JSTで、**check.sh 自身の終了0、timeの終了0**であった。timeはreal **257.00秒**・user1241.73秒・sys38.97秒、ラッパーの外側は257.007秒である。[check.sh自身の値](work-check-exit.json)、[計時](work.json)、[出力](work.log)、[対象別の件数](test-counts.json)を保存した。

| 対象 | 成功 | 失敗 | ignored | テスト本体の秒数 |
|---|---:|---:|---:|---:|
| 既定lib全件 | 1,392 | 0 | 22 | 76.61 |
| build_info | 0 | 0 | 5 | 0.00 |
| cli_process | 46 | 0 | 0 | 33.70 |
| declarations | 33 | 0 | 1 | 18.36 |
| desugar_export | 48 | 0 | 1 | 12.08 |
| golden | 2 | 0 | 0 | 56.49 |
| package_command | 16 | 0 | 0 | 1.18 |
| reference_examples | 1 | 0 | 0 | 4.07 |
| skill_docs | 8 | 0 | 0 | 0.09 |
| skill_examples | 4 | 0 | 0 | 4.85 |
| spec_examples | 7 | 0 | 0 | 3.43 |
| stdlib_doc_examples | 1 | 0 | 0 | 2.70 |
| test_command | 52 | 0 | 0 | 4.35 |
| 合計 | **1,610** | **0** | **29** | — |

12統合ターゲットだけの合計は218成功・失敗0・ignored7件である。build_infoの5件を含むignoredは予定どおり通常のworkでは実行せず、後続changeのlong_onlyの担当へ残す。指定の12ターゲットにrandom_programsは含まれないため、random_differentialは実行していない。検査中に別のビルドは走らせず、60秒の予算に関する失敗と再試行もない。

fmt、既定構成のlib・tests・examplesのclippy、ソース規約、生成物の鮮度、仕様集計、ライセンスは成功した。生成物の差分は増えていない。仕様集計が示す参照テストのない節の一覧は情報であり、初回リリース版の未記入の条件はnoneであった。仕様全体を検証済みという意味ではない。通常の書き出しは346ファイル・38,410,849 bytesであり、[大きさとSHA-256](work-export-files.json)を記録した。これらをLeanで比較したとは扱わない。

最大常駐量は未計測である。指定の time -p は RSS を報告しないためであり、0とは記録しない。W-V全体の反復はない。

### 依存の勧告照合

W-V内の初回は、ワークスペース・fuzzとも既定の `<home>/.cargo/advisory-dbs/db.lock` が読み取り専用で排他ロックを取得できず、**未照合**であった。生のcargo-denyは両方終了1、表示単位は方針どおり終了0である。[初回の対象別結果と生出力](advisories-initial/report.json)を保持した。初回を照合済み0件と扱っていない。

入力・共通設定の検査項目を変えず、既存実行器の `--db-path` で書き込み可能なDB保存先だけを指定し、勧告照合を単独で再確認した。

```sh
python3 -B scripts/check/advisories.py --db-path target/v10.3a/advisory-dbs
```

[再確認のコマンド・終了値・時間](advisories-recheck.json)と[出力](advisories-recheck.log)、[共通設定・DB・対象別の結果・生出力](advisories-recheck/report.json)を保存した。表示単位は終了0・2.706秒で、両対象とも照合済み0件、生のcargo-denyもそれぞれ終了0であった。共通deny.tomlの写しへdb-pathだけを加え、両方に同じ設定と--lockedを使った。二つのlockのハッシュは照合前後で一致した。

| 対象 | 再照合日時（UTC） | 結果 | DBコミット |
|---|---|---|---|
| workspace | 2026-10-29 19:20:05 | 照合済み0件 | `ee1a49a2769a24a596afc1c20cb33748d2769586` |
| fuzz | 2026-10-29 19:20:06 | 照合済み0件 | 同上 |

cargo-denyは0.20.2である。[実行環境と固定入力](environment.json)のとおり、Rust/Cargoは1.98.1、ホストはaarch64-apple-darwinであった。今回の二lockの照合を、Rust/Cargo/Lean/elanのツールチェーン勧告の照合に読み替えない。その候補時点の照合は後続の担当に残る。

## 全比較の影響段への引き渡し

[実際に変わった入力62ファイルの一覧](comparison-inputs.json)に、変更前後の SHA-256、依存して読む入力、計画の影響表の行を対応付けた。これは比較の再実行や出力不変の証明ではない。

| 計画の影響表の行 | 今回の変更と次の確認 |
|---|---|
| testdata の header・依存ハッシュと現在版の loader | 正常な宣言50ファイル、hash-match の依存ハッシュ、製品版と二 lock、package.rs/text.rs の登録。一般 corpus と同時出力の区間 manifest/material/observations を新旧照合し、変わった出力を読む段を選ぶ。独立探索と `.files` の依存読み込みを区別し、E0908による受理・件数減少を認めない |
| named.rs の固定パッケージと区間 manifest の依存 header | named.rs の根とDepの2宣言。testdata の d6c のパッケージ、libraries.files の wasm-json/pure-json/wasm-regex の header も変わった。該当する named の六入口と区間の実ソース比較を出力差で選ぶ |
| H31 の範囲の実ソース | H31の固定入力・expected.json・verify-local.py は今回不変。版上げ後の書き出しとCLIで、既存群と追加群を分けて再確認する。前段の申し送りどおり verify-local.py または同等の照合で署名の非Topとprimへの転送を確認する |
| .diag.json の現在版の文と E0908 の note/help | E0907の3件、older-languageのnote/help、hash-mismatchのcomputed note。goldenで確認する。書き出し器はこれらを読まず、期待値の変更だけを理由に交換の読者を再実行しない |
| 新旧出力と読者の結果がそろった状態 | 取りまとめが来歴・ハッシュを照合し、新旧を混ぜない集合から collect と最終 manifest/verify を更新する。古い manifest を流用しない |

残りのテスト内 MemFs と版の期待値、文書の例・訳は全比較 corpus の収集対象ではない。[役割ごとの全差分](changed-files.json)と、書き出し入力の一覧を分けた。交換形式の版・Lean・台本・標準宣言・生成器を変えていない。`lake build` と `scripts/check-formal.sh` は実行しておらず、通常 work の成功を交換比較の成功と扱わない。影響段の範囲・時間・資源を具体化して了承を得る手順は取りまとめの担当に残る。

## 失敗・ずれ・残る確認

編集の補助 Python は最初、環境の Python に未対応の `zip(strict=...)` で終了1となった。登録・宣言・診断の更新の後、ハッシュと文書の編集に入る前だった。strict 指定を外し、処理済みの部分を再適用せず、未実行部分から再開した。依存ハッシュは独立に再計算して照合した。訳担当の最初の補助 Python は標準入力の文字コードの SyntaxError で、ファイルへ書く前に止まった。UTF-8の宣言を付けて実行し直した。いずれも処理系やテストの失敗ではない。

非訳の差分と訳は読み取り専用の別担当が独立に確認し、対象外の入力変更、期待値の誤り、修正を要する誤訳は見つからなかった。[レビューの所見](review.md)を保存した。06-09の本文の登録説明を今回編集していない点を指摘され、上に範囲として明記した。CHANGELOGの最終読解では、存在しない値型の列挙を検査前に取り除き、Scope.PathIn/Http.RequestInに限定した。

計画にない入力や交換形式・Lean・台本の変更は加えていない。新版の移行案内も加えていない。新たな仕様の採否を担当側で決めた事項や、J3により停止した判断はない。指定の編集・生成・局所検査・W-V・結果記録を完了した。全比較の影響段、change、候補のツールチェーン勧告・実CLI・配布の照合、最終レビュー・設計者の受け入れは、この枝の検査に含めず、計画上の担当へ残す。

## 時間

終了は2026-10-30 04:22:12 JSTであり、外側の所要は13分54秒である。G・局所検査・W-V・勧告の単独再確認の外側は計316.840秒であった。能動時間と短い読み取り・記録の待ちは厳密に分離していない。独立レビューは他の作業と並行して行い、設計者の回答待ちと性能測定の待ちはない。見込みの上端の2倍と6時間の停止条件には達していない。


## 追補（レビュー指摘への対応、2026-10-30）

着手は2026-10-30 04:35:33 JSTであり、上記の未コミット差分の上で修正した。基準とHEADは `92f9ac80f81d2299978d2051ddcdfdeea1843e6d` のままである。以下は上記の履歴を保った追補であり、要約・helpがHttpだけを述べること、06-09の本文を後続へ残すこと、生成物に差分がないことについては、この追補の結果で更新する。

| 指摘 | 直した箇所と対応 |
|---|---|
| 中1 | `modules/text.rs` の定数を `SCOPED_EFFECT_OPERATIONS_CHANGE`・`SCOPED_EFFECT_OPERATIONS_HELP` に改名し、File.Read・File.Write・Http.Connectの操作追加と部分ハンドラの事実へ広げた。`package.rs` の登録と表のテスト、`modules/tests.rs` の表、`older-language.diag.json` の末尾のnote/help、CHANGELOGの非互換の項目を同期した。`decisions.md` の旧sendの段落に、旧11操作を処理するFile.Readと旧12操作を処理するFile.Writeの完全ハンドラも部分ハンドラになる事実を一文追加した |
| 中2 | 06-09「設定ファイルの検査」に0.0.13の行を加えた。0.0.12までの移行方法と0.0.13の変更事実を区別し、後者がCHANGELOGを参照せず、宣言とハッシュの更新も促さないことと、0.1.0の公開まで移行案内を書かない理由を明記した。02-10を「各変更の案内」へ直し、`diag/codes.rs` とGの生成診断文書の説明を `corresponding guidance` へ同期した |
| 中3 | CHANGELOGに、Scopeのホストの検査とパターンが正規形のIPv4/IPv6アドレスとCIDRを受け付け、IPv4射影の対象を拒否し、不正なパターンの理由が新しい形式を挙げるという項目を一つ追加した。日本語のCHANGELOGは存在せず、新設していない |
| 軽1 | CHANGELOG冒頭の一般文の変更理由を下に記した。push前の設計者の確認は取りまとめへ引き継ぐ |

CHANGELOGの冒頭は、0.0.13が移行方法を載せないため、すべての非互換の変更に移行方法を添えるという約束をやめ、各版の節に非互換の変更を列挙するという文へ直した。

追加の変更は[10ファイルの追補前後のハッシュと限定差分の照合](ab-change-audit.json)にまとめた。READMEは変更していない。ワークスペースとfuzzのCargo.toml、二lock、標準宣言、Lean、交換形式、台本、生成器、bundleは追補前のままである。`private/` とそこを指すリンク、`docs/todo/` は読まず、gitの状態を変える操作も行っていない。

### 新しい要約・helpと操作数

summaryは次の文である。

```text
scoped operations were added to File.Read, File.Write, and Http.Connect; handlers that cover only their earlier operations, such as a handler with only an Http.send clause, are partial and leave the effect unhandled
```

helpは次の文である。

```text
the File.Read effect declares 13 operations, File.Write 16, and Http.Connect send and sendIn; a handler without every operation of an effect leaves that effect in the effect contract
```

両方とも小文字で始まり、終止の句点を付けていない。節の書き換え方、移行手順・例、CHANGELOGへの参照は含めない。`IO/File.bnt` と `Network/Http.bnt` のエフェクト宣言を読み、functionを数えて13・16・2であることを確かめた。[操作名と宣言のハッシュ](ab-operation-counts.json)を保存した。CHANGELOGの該当項目も、この三つの操作集合と、従来の操作だけを処理するハンドラにエフェクトが残る事実にそろえた。0.0.12以下のCHANGELOGはHEADとバイト一致である。

test-auditの作成時の関門を通した。守る契約は、実際のloaderのE0908が三つの事実を欠落なく伝え、版境界とnote/helpの順序を保つことである。旧Httpだけの説明へ戻る退行を、既存の表とCLIの診断の期待値で捕まえる。既存テストの期待値を更新し、新規の製品テスト、差し込み口、公開範囲の拡大は加えていない。レビュー入力の両版比較は、今回の確認の記録として保存した。

### 両版の実CLIでの確認

[保存した入力・コマンド・全文出力・終了状態・CLIのハッシュ](ab-cli-evidence.json)と[実行用の台本](ab-probes.py)を残した。旧CLIは指定の `target/v10.2b/benitoite-0012`、候補CLIは既存の `target/debug/benitoite` を使った。候補は `cargo build -p benitoite --bin benitoite` でビルドし、[終了0・20.571秒](ab-build.json)だった。新しいCARGO_TARGET_DIRは作っていない。

| 入力・操作 | 0.0.12 | 0.0.13 |
|---|---|---|
| 旧11操作のFile.Read、旧12操作のFile.Write、旧sendだけのHttp.Connect、宣言なしでcheck | 三つとも終了0 | 三つとも終了2・E0501。各エフェクトが契約に残る |
| 同じ三入力に `language "0.0.12"` を付けてcheck | 三つとも終了0 | 三つとも終了2・E0908。上のsummaryを注記へ、上のhelpを修正案へ出し、期待値と文字列まで一致 |
| 保存済みのsendの0.0.11・0.0.12・0.0.13・0.0.14の各宣言と宣言なし | 旧版は範囲付き構文をE0201で拒否するため、旧版受理の根拠にはしない | 順にE0908・E0908・E0501・E0907・E0501。0.0.11の案内は0.0.12→0.0.13の版順 |
| 新13操作のFile.Readの保存済み入力をcheck | 終了2・E0303（新操作二つがない） | 終了0 |
| `ip.bnt` をcheck | 終了0 | 終了0 |
| `ip.bnt` を `run --allow-effects=Console.Write` | 終了0。CIDRの行はInvalidPattern | 終了0。CIDRの行はok |

範囲付き構文を使わない旧sendの入力と、その版宣言の変種を分けた。変種の本文とハッシュも `rv-probes/ab-inputs/` とCLI証拠に保存した。IPの二行目の `"**"` は両版ともInvalidPatternであり、新版の理由は `expected a host, *.host, **.host, canonical IP address, or CIDR` である。旧版は `expected a host, *.host, or **.host` と出す。

指定された旧CLIの `--version=json` は版が0.0.12だが、`build.commit` はnull、`provenance.commit` はunknownだった。公開タグ `v0.0.12` のコミットは `d0678ddb7e82da77715ea2e01ef974d06d41814b` であり、レビュー記録にある「公開タグのコミットと一致」は、この実ファイルでは再確認できない。指定の旧CLIを別のものへ交換せず、版とファイルのSHA-256を証拠として残す。この制約を公開タグとの一致確認済みに読み替えない。

確認用の台本には二つの期待の誤りがあった。最初は旧CLIのcommitと公開タグの一致をassertして停止した。次はIPの二行ともokになると誤って期待し、二行目が不正な `"**"` であるため停止した。[後者の終了1の出力](ab-probes.log)を保持し、前者は上の来歴の制約として記録した。どちらも製品の失敗ではなく、来歴の確認不能と、不正なパターンが拒否される事実へ記録を直した。

### 設計書・英日文書・生成物

06-09・02-10・codes.rsの修正を担当した別のエージェントが、英語リファレンス、Skill本体と手書き参照4文書、および対応する日本語訳の完全／部分ハンドラの説明を点検した。すでに13・16・2操作と、従来の操作だけなら部分ハンドラになる説明が対応しており、追加の英日修正は不要だった。追補以外の先行差分78ファイルをハッシュで保持したことも確認した。

Gの `cargo run -p benitoite --example gen_skill` は[終了0・6.308秒](ab-generate.json)だった。[生成参照66ファイルとbundleのハッシュ照合](ab-generated-audit.json)では、差分が `skill/references/diagnostics.md` のE0908説明の `corresponding migration guidance` から `corresponding guidance` への一か所だけである。生成物は手で直していない。bundleの追加編集を要する停止条件は生じていない。診断の説明文字列だけの変更で測定経路と入力は変わらず、レビューの取りまとめの判断どおり、直前のshortの判断を維持する。

別担当の読み取り専用の追加点検では、中1・中3の差分、診断の期待値、生成物、CLI証拠に修正を要する不整合は見つからなかった。確認用の台本の誤った期待と、旧CLIの来歴の制約は上に分けて記録した。

### 作業末の検査と失敗の保持

指定どおり出力先を `BENITOITE_DESUGAR_DIFF_DIR=<wt>/target/v10.3a/export2` とし、dry-runで9単位と指定12統合ターゲットの選択を確認した。対象はfmt、既定lib・tests・examplesのclippy、既定lib全件、指定12統合ターゲット、ソース規約、生成物の鮮度、仕様集計、ライセンス、二対象の勧告照合である。spec_examples・reference_examples・skill_docsはtests_relatedに含まれる。

最初の実行はfmtで停止し、check.sh自身は[終了1](ab-work-first-check-exit.json)、[timeはreal 2.72秒](ab-work.log)だった。summary定数の改行がrustfmtの期待と異なったためであり、`rustfmt --edition 2024 crates/benitoite/src/modules/text.rs` で一行へ整形した。clippy・lib・統合テストへは到達していない。初回の[選択確認](ab-work-dry-run.log)、[コマンド・終了状態・時間](ab-work.json)を残した。

整形後に[同じ選択のdry-run](ab-work-final-dry-run.log)を終了0で再確認し、[同じ引数の台本](ab-work-check.sh)を `/usr/bin/time -p` で包んで全体を実行した。対象と基準を変えず、失敗後に必要な一回の全実行である。最終の結果と勧告照合は下に追記する。

### 全比較の引き渡しの更新

V10.1dへの [comparison-inputs.json](comparison-inputs.json) は、既存62件を保持して64件とした。`package.rs`・`text.rs`・`older-language.diag.json` の最新SHA-256を更新し、追補前の値も `beforeSupplementSha256` に保持した。`diag/codes.rs` と生成診断文書をビルド入力として追加し、説明文だけの変更と、通常の診断・受理判定を変えないことを記した。`modules/tests.rs` の表の文字列は通常libの境界テストが読み、交換corpusへは収集されない。

| 影響表の対象 | 更新した引き渡し |
|---|---|
| loaderと版を読む書き出し | 三エフェクトへ広げた要約・helpの最新ハッシュを使う。互換性の境界・受理規則は追補前と同じであり、一般corpus・named・区間の再確認の予定と、出力差から読者を選ぶ条件を保つ |
| `.diag.json` とE0908の案内 | goldenで新しい末尾note/helpを確認する。`.diag.json` を書き出し器が読まないことは変わらず、この期待値の変更だけで交換の読者を再実行しない |
| E0908の説明・埋め込む生成文書 | 新しいビルド入力のハッシュを候補のCLIへ対応付ける。説明文字列の変更を交換形式や標準宣言の変更としない |
| 既存の全比較の最終保存 | 最新の実入力から影響段の再出力・件数照合・collect・manifest/verifyを取りまとめが行う。通常workの出力や成功をLean比較へ読み替えず、既存の受理・比較件数が減る場合は停止する |

`lake build` と `scripts/check-formal.sh` は実行していない。交換形式・Lean・台本・標準宣言・生成器の変更、J3の停止条件、新たに設計者の判断が必要な入力変更は生じていない。全比較の影響段、change、候補照合、独立レビュー・設計者の受け入れは従来の担当へ残す。軽1の設計者による確認と、指定の旧CLIの来歴が不明である点も、取りまとめの受け入れ資料へ引き継ぐ。

### 最終の検査結果と追補の完了
整形後の全実行は2026-10-30 04:39:45〜04:44:04 JSTで、**check.sh自身の終了0、timeの終了0**であった。timeはreal **258.31秒**・user1216.12秒・sys41.08秒、ラッパーの外側は258.313秒である。[check.sh自身の終了状態](ab-work-check-exit.json)、[実行の計時](ab-work-final.json)、[全文出力](ab-work-final.log)、[対象別の件数](ab-test-counts.json)を保存した。
| 対象 | 成功 | 失敗 | ignored | テスト本体の秒数 |
|---|---:|---:|---:|---:|
| lib_default | 1392 | 0 | 22 | 76.43 |
| build_info | 0 | 0 | 5 | 0.00 |
| cli_process | 46 | 0 | 0 | 33.55 |
| declarations | 33 | 0 | 1 | 18.30 |
| desugar_export | 48 | 0 | 1 | 11.89 |
| golden | 2 | 0 | 0 | 56.59 |
| package_command | 16 | 0 | 0 | 1.20 |
| reference_examples | 1 | 0 | 0 | 4.11 |
| skill_docs | 8 | 0 | 0 | 0.09 |
| skill_examples | 4 | 0 | 0 | 4.84 |
| spec_examples | 7 | 0 | 0 | 3.43 |
| stdlib_doc_examples | 1 | 0 | 0 | 2.70 |
| test_command | 52 | 0 | 0 | 4.31 |
| 合計 | **1,610** | **0** | **29** | — |

既定libは1,392件、指定12統合ターゲットは218件成功した。fmt・clippy・ソース規約・生成物の鮮度・仕様集計・ライセンスも成功した。build_infoの5件を含むignoredは予定どおり後続のchangeのlong_onlyへ残す。random_programsを選んでいないためrandom_differentialは実行しておらず、60秒超過に伴う再確認もない。最大常駐量は、指定の `/usr/bin/time -p` がRSSを出さないため未計測であり、0とは扱わない。

通常workの書き出しは346ファイル・38,410,849 bytesだった。[ファイルの大きさとSHA-256](ab-work-export-files.json)を保存した。これを全比較やLean側の成功の証拠とはしない。整形後の最終ビルドのCLIで両版比較を再確認し、[終了0・2.198秒](ab-probes-final.json)、診断とIPの結果は同じだった。最終のCLI証拠は `ab-cli-evidence.json`、整形前の証拠も `ab-cli-evidence-before-final-check.json` に保持した。

勧告照合の初回は、両対象とも既定DBの排他ロックを取れず未照合だった。[初回の生出力と対象別結果](ab-advisories-initial/report.json)を保存し、照合済み0件と扱っていない。設定・二lock・検査項目を変えず、次を一度だけ実行した。

```sh
python3 -B scripts/check/advisories.py --db-path target/v10.3a/advisory-dbs
```

[再確認のコマンド・終了状態・時間](ab-advisories-recheck.json)は終了0・1.847秒であり、[両対象の結果・DB・共通設定と生出力](ab-advisories-recheck/report.json)を保存した。workspace・fuzzとも照合済み0件、生のcargo-denyも各終了0である。共通deny.tomlの写しにdb-pathだけを加えた同じ設定と--lockedを使い、二lockのハッシュは照合前後で一致した。cargo-denyは0.20.2、DBコミットは `ee1a49a2769a24a596afc1c20cb33748d2769586`、確認日時はworkspaceが2026-10-29 19:44:28 UTC、fuzzが19:44:29 UTCである。この二lockの照合を四ツールの勧告照合に読み替えない。

Rustの追補前との差は、本番が+5/−6行、テストが+4/−4行だった。テストは既存の診断の期待値を更新し、削除や新しい独立テストの追加はない。32ファイルの性能比較用入力のハッシュも不変だった。追補の監査の件数集計の補助コードは、最初にdifflibの返す組の要素数を誤って終了1となり、正しく読み直して再集計した。製品ファイルの変更と検査結果への影響はない。

中1・中2・中3と軽1の理由の記録を完了した。初回のfmt停止と確認用台本の期待の誤りは上のとおり保持した。検査後に変更したのは追補の結果・証拠・引き渡しの記録だけである。指定範囲に未完の修正はなく、軽1の設計者の確認と旧CLIの来歴の制約を、後続の受け入れへ申し送る。

追補の終了は2026-10-30 04:46:17 JST、外側の所要は10分44秒である。能動時間と短い読解・記録の待ちは厳密に分離していない。作業末の全検査は258.313秒、先行するfmt停止は2.726秒だった。見込みの上端の2倍と3時間の停止条件には達していない。[最終状態と記録のハッシュ](ab-final-state.json)に対応付けた。
