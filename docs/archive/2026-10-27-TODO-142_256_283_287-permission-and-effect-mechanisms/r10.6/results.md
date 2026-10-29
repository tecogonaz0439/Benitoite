# R10.6: Top の互換と設計書の整合

## 作業と状態

B_WORK と開始時 HEAD は `3fc9b3f88c039e61bf797b1da574e5275028253d`、ブランチは `m013/r10.6` である。開始時の差分はなかった。R10 全体の点検の基準 B0 は `6124775788579e60530f55fb85570f26ef7fa900` である。`private/`、そこを指すスキル、`docs/todo/` は読んでいない。git の状態を変える操作、本線のディレクトリへの書き込みは行っていない。

RV-R10.5 から指定された修正、R10 の通常の読者の点検、Top の互換比較、LR-U8、包含位置の対応、設計書の整合を扱った。通常検査の確定値は後述する。

計画で先行する受け入れ資料とされた `ub20.01/results.md`・`ub20.02/results.md` は、改造のディレクトリに存在しない。所在を照会し、独立して進められる修正と照合を行った。両作業の指摘を閉じたとは扱わず、UB20 の資料照合と取りまとめの独立レビュー・受け入れを未完として返す。後続の R10.7 へ無条件に進める状態とは報告しない。

## 先に閉じた R10.5 の指摘

| 指摘 | 修正・照合 |
|---|---|
| 中1 | 02-05 の `covers i j` を「j 番目（outer）の一範囲が i 番目（inner）を覆う」と訂正し、Rust の `Covers { outer, inner }` との対応を添えた |
| 軽1 | 全 Top の列は許容条件を満たすが、個数・種類と Covers の番号・種類の妥当性を検査すると書き分けた |
| 軽2・番号のずれ | E0303 の一覧・修正案の変化、k3 の束縛と補充型の番号のずれを、下の互換表に意図した差として記録した |
| 軽3 | `INVALID_RANGE_SIGNATURE`・`INVALID_RANGE_INSTANTIATION` を `typeck/text.rs` から呼び出し元へ戻した。終了状態3の説明本文は変えていない |
| 軽4 | `BuiltinEffectId::{FILE_READ, FILE_WRITE, HTTP_CONNECT}` と `BuiltinTypeId::REGEX_PATTERN` を定め、分類と既存 lib テストの生の番号を置き換えた。表の並び・識別番号・標準宣言の意味は変えていない |
| 軽6 | `signature_valid` を宣言の整形式、許容条件の番号、IO の形の補助関数へ分けた。宣言時検査済みの範囲変数0個の署名は `Body::instantiate` でそのまま型／行の具体化へ渡す。現在の登録はすべて0個であり、通常経路の再検査を省く。範囲変数を持つ署名の公開の具体化 API の検査契約は保った |
| 軽7 | 「範囲変数」「範囲付きの値型」を定義章付きで用語集へ加え、01-12 の「範囲の変数」との同義を示した。Lean の名前と写しの用語は変えていない |

コードの説明とテストの作成時の関門は [code-notes.md](code-notes.md)、設計書の判断は [design-notes.md](design-notes.md) に記録した。追加点検で同じ規約漏れだった `resolve/text.rs::SCOPE_INTERNAL` も、`resolve/scope.rs` の終了状態3の呼び出し元へ戻した。

## Top の互換の照合

L00.06 の対応では、旧の名前の原子を同じ名前の明示 Top の原子へ、旧の名前の型を同じ名前・型引数と明示 Top の添字へ対応させる。全 Top の旧像では被覆と構造上の包含が一致する。原子の構造上の等号・hash・和・正規化・除去を保ち、行と Fail の型を被覆で緩めない。この対応を通常の構文、名前解決、型検査、脱糖、CLI の入口で照合した。形式化の新しい証明や Rust/Lean の全比較を行ったという主張ではない。

B0 と B_WORK の必要な追跡済みソースだけを `git archive` で一時領域へ写し、それぞれの target で CLI をビルドした。ビルド入力は両版と作業版とも `BENITOITE_BUILD_COMMIT=3fc9b3f88c039e61bf797b1da574e5275028253d BENITOITE_BUILD_DIRTY=unknown` にそろえた。報告のビルド由来を比較するための入力であり、B0 のソースの基準を B_WORK と偽って数えていない。

前枝と同じ effects・handlers の83入力を、テキスト診断・JSON 診断・JSON 報告の249通りで採取した。さらに [inputs/](inputs/) の13入口と補助モジュール1ファイルを使い、三形式の検査39通りと CLI 上限6通りを採取した。各入力の SHA-256、実行ファイルの SHA-256、終了、stdout、stderr は [cli-b0.json](cli-b0.json.gz)・[cli-bwork.json](cli-bwork.json.gz)・[cli-after.json](cli-after.json.gz)、[extra-b0.json](extra-b0.json)・[extra-bwork.json](extra-bwork.json)・[extra-after.json](extra-after.json) に保存した。採取と比較の台本は [capture_top.py](capture_top.py)・[capture_extra.py](capture_extra.py)・[compare_cli.py](compare_cli.py) である。

| 比較 | 通り数 | 受理／拒否 | 結果 |
|---|---:|---|---|
| B_WORK → 修正後、前枝と同じ入力 | 249 | 81／168 | 入力ハッシュ・終了・stdout・stderr が全件一致、差0 |
| B_WORK → 修正後、補足入力 | 45 | 20／25 | 全件一致、差0 |
| B0 → 修正後、前枝と同じ入力 | 249 | 81／168 | 生の比較は246一致・3差。3件とも拒否例の JSON 報告の区間解析の実施状況だけであり、終了・診断・契約は一致 |
| B0 → 修正後、補足入力 | 45 | 20／25 | 生の比較は29一致・16差。E0303 の一覧・修正案12通りと、標準ソースの内容ハッシュ8件が重なる。受理／拒否は全件一致 |

比較は [cli-comparison.json](cli-comparison.json) に差を残して終了0となった。B0 の差を削除して全件同一とは報告しない。

| 観点 | 通常の入口と結果 | 互換の判断・限界 |
|---|---|---|
| 旧構文、Top だけの型・型引数・行 | `declarations`、`scope_annotations`、`golden`、`fmt_command`、通常の `desugar_export`。型引数・Fail・行の通常の受理／拒否、旧型の添字 Top を保つ | 新二型の裸の Top と非 Top との不変性も R10.5 の通常入口で検査する。利用者の `rvar` は許さない |
| IO.All とファイル宣言 | `file-io-all.bnt` と `declarations`。旧 String の `File.readText` を IO.All のファイル契約の下で受理し、従来の W0501 も維持 | IO.All は従来の表の項目だけへ展開する。Http.Connect と Log を IO.All に含めない表示・宣言の既存テストも通す |
| Fail と行変数、ファイル宣言 | `file-fail-row.bnt` が `Support/Contracts.bnt` を import する。ファイルの Fail と多相な E を持つ公開関数を受理。過不足や行の誤りは既存の effects・handlers で拒否 | Fail の中の型と関数契約は構造を保つ。main に未処理の Fail を残す例を成功例と混同しない |
| 利用者エフェクトの処理と消去 | `user-handled.bnt` は検査と空の CLI 上限での実行が0。`user-unhandled.bnt` は E0506、終了2 | 処理した Ask が権限一覧へ戻らない。利用者の原子は Top のまま |
| 既存 Scope と旧 Checked 型 | `scope-old.bnt`、`checked_args`、通常交換の scope 入力。旧 `checkPath`・`checkHost` の受理、旧 CheckedPath の射影を保つ | 新しい範囲選択の規則は旧 Scope のラッパーへ付けない |
| Unofficial の import | 既存83入力、補足の Scope・Http・File・Failure と `declarations` | 認定は解決済みの標準束縛だけであり、同綴りの利用者の型や別名を誤認しない |
| 名前だけの CLI 上限 | `run --allow-effects=File.Read` は0、空の上限では E0512。IO.All・範囲付き綴り・Ask は従来どおりオプションの誤りで2 | CLI の照合単位を範囲付きへ変えていない |
| R30.1 の例外はまだ起きていない | `scope-ipv4.bnt`・`scope-cidr.bnt` は B0・B_WORK・修正後とも E0459、終了2 | 旧 Scope の IP/CIDR への拡大は未実施で、R30.1 の担当である |
| R30 の例外はまだ起きていない | `http-full-handler.bnt` の Http.send 一節だけのハンドラは三版とも受理、終了0 | 新操作はまだ追加しておらず、部分ハンドラへの変化は未発生 |
| 公開の型の追加による E0303 | `Scope.Zzzzzz` の一覧へ PathIn、`Http.Zzzzzz` へ RequestIn が加わる。Scope.PathInn・Scope.Path は一覧の note から `a similar name exists: PathIn` の help へ変わる | R10.5 の型の公開に伴う意図した差。終了2・E0303・主位置は同じ。今回の B_WORK 比較では既に同じ公開名を持つため差0 |
| 拒否例の区間解析の報告 | handlers の f1-arguments-extra/missing/ordinary の `--report=json` 3件で、B0 の coverage=some と非0の計上が、none・0へ変わる | R10.3 が E0513 を名前解決で報告し、型検査後の区間解析へ進まなくなったため。診断本文・主位置・終了は同じ。B_WORK から今回の差はない |
| 標準ソースの内容ハッシュ | Scope.bnt・Network/Http.bnt の型の説明コメントが変わり、補足の JSON 報告8件の sources.contentHash が変わる | 入力のソースの同一性を示す欄の意図した差。契約・実行結果・診断と混同しない |
| 旧交換の k3 の生のハッシュ | R10.5 の206ファイルの比較は203件一致、k3 の builtins/corpus/stdlib の3件で束縛と補充型の番号がずれる | PathIn の束縛追加による既知の差。宣言の同一性で番号を対応させた206件一致の根拠は [R10.5 の結果](../r10.5/results.md#top-比較の確定値と証拠)。今回は同じ比較を実行したとは数えず、通常 desugar_export を W-R で実行する。K10 へこの差を渡す |
| Fail 内の関数契約の検査 | R10.2b がコア IR 検査器で Fail の内部も巡回し、R10.3 が02-06とテストへ反映した | 意図した検査の追加であり、旧の不正な手作り IR の受理を保証しない。本番の通常入口にはこの検査器を追加していない |

通常入口の既存テストが各契約を守っているため、重複するテストは追加していない。補足は互換比較の入力と採取記録として残した。既存 lib テストの変更は生の番号の定数への置換だけであり、期待する意味・件数・無視は変えていない。

## R10 の残りの点検

[audit-notes.md](audit-notes.md) の先行レビューの表と、各 results・RV の対応欄を照合した。R10.5 から今回へ明示された指摘と追加の文言配置を修正し、通常の読者に未接続の仮の値は見つからなかった。前枝の初回の lint・準備の失敗は、それぞれの修正後の通常検査で閉じている。R10.3c の最適化した深い再帰の検査も、取りまとめが release_stack の成功10件を RV 末尾に記録済みである。

| 残る対象 | 現在の状態 | 後続の担当 |
|---|---|---|
| Rust の構造の整列と Lean の符号順 | Top の旧順は保持。非 Top の順を同一とは主張しない | R10.7、K10 |
| `decl_types` の直接の読者 | `effects/handle.rs`、`ir/desugar/decls.rs`、`traits/solve.rs` は現行の範囲変数0個の登録で動く。変数を残す新宣言は登録していない | 最初の rvar 宣言登録時に R20.0a/.0b がコア Scheme・IR 検査器の Top 具体化を接続。範囲列と IR は R20.3、節の添字は R20.4、標準操作と型クラスの読者は R30.2/.4 |
| 型クラスの宣言と実装の効果 | Rust は構造上の包含で、Lean の checkMethods より狭い既知の受理。01-06 に明記済み | K10 の型付け比較で差を照合 |
| 内部署名の rvar の表示、由来・JSON の全体 | 利用者構文へ rvar を公開していない。旧の CLI 上限は名前だけ | R40。RV-R10.2b 軽3も保つ |
| 新しい純粋 API、widen、七 IO | 現行は未登録。保存先だけや仮の成功値を置いていない | 四入口は R20.0a/.0b、範囲選択・widen・列は R20.3、七 IO は R30.2/.4 |
| 新版交換と必須欄 | 通常の旧版 export を維持し、非 Top と未具体化を明示的に断る。形式化との全比較は未接続 | R10.7 の署名・原子・表と局所 F-table、K10.1/.2 の全必須欄、K10.3 の全比較 |
| UB20 の指摘と受け入れ資料 | 両 results が未提供のため、指摘の有無と対応の完了を確認できない | 取りまとめが UB20.01/.02 の結果を用意し、R10.6 で必要な修正・検査と受け入れを閉じる |

## LR-U8: R10 全体の差分の点検

B0 から B_WORK までの `src/` 80ファイルを点検した。[audit-notes.md](audit-notes.md#lr-u8-の対応表) は B_WORK の行番号付きの14行の詳細表であり、次はその要点である。R10.6 の追加差分は定数・検査の整理・説明文字列の配置であり、数値の表現や外部依存を加えていない。

| 観点 | 結果と根拠 |
|---|---|
| 固定幅 | IP は V4=u32、V6=u128、port=u16、prefix=u8、範囲変数の番号=u32。数値の意味にホストの usize 幅を使わない。mapped は V6 を保つ |
| シフトの境界 | prefix から host bits を checked_sub し、128ビット全体は u128::MAX、それ以外は checked_shl。IPv6 の組み立ては u128 上の16ビットずつの固定8要素であり、幅以上のシフトや2^128を作る加算はない |
| 個数の上限 | IPv4=4、IPv6=8の固定配列と桁数を検査。圧縮左右の和は高々16で、8以上を拒否する。署名の個数は u32::try_from、配列の番号は get で検査する |
| 検査付き変換・加算 | port は u16::try_from、位置と番号は usize::try_from と get。メモリ計上は size_of、checked_add・checked_mul と既存上限を用いる。欠けた番号を Top にしない |
| 依存の方向 | `types` と対象の代数は std・既存 AST/base・型モジュール内へ依存する。ネットワーク・暗号・Wasmtime・サーバの実装への直接 import はない。checked_scope の実装から代数へ読む向きを保つ |
| 64ビットの前提 | 本番の追加行に切り詰める as、u64/u128→usize の直接変換、usize=64ビットを前提とする定数・分岐は見つからない |
| 実ビルドの限界 | 現行 Cargo にネットワーク／WASM を外す feature がなく、check.sh に32ビット target の指定もない。読解の点検であり、これらの実ビルドを実施済みとはしない。後の既存 heap/stress/lint の成功でも代替しない |

## L50.4 の包含位置表との対応

[design-notes.md](design-notes.md#l504-の包含位置表との対応) に R10.4 の被覆10行・構造14行と現在のソースの対応を記録した。分類を変える必要はなかった。

| L50.4 の位置 | Rust の対応と扱い |
|---|---|
| C-Sub・C-Eff、Ty.Le、E_Sub・B_Sub、呼び出しの頭 | IR の計算の拡大、最外側の関数の潜在効果、関数・lambda・メソッド本体、calls の generate/builder・generate::apply、try の die が呼ぶ Process.Exit は被覆 |
| resume、K-Handle 節、K-Handle-Fail の Rest と節 | resume の引数、IR の節の計算の上限への拡大は被覆 |
| C-Handle・K-Handle・C-Handle-Fail の保護本体、E_Handle・E_HandleFail | 表層の保護本体と節、Fail の節・Rest、IR の保護本体は構造上の包含 |
| 純粋要求、E_PartialCall、HasMain | lazy・guard・die の説明の空の上限、部分適用、main/test・ファイル宣言は構造上の規則を保つ |
| K-Empty・K-Let・K-Guard、状態 ε1⊆ε | Rust の実行時に形式的な状態の型付けを直接検査する入口はない。IR の計算の拡大と guard の純粋要求を区別し、この形式化の構造包含を実行時の被覆と読み替えない |
| 表層一覧に直接の名前がない Rust の位置 | with の State の和、行・Fail・推論集合の和と最小解、NoFail、索引と重複の鍵は構造 |
| 型クラスの宣言と実装メソッド | 本体は被覆、宣言照合は構造包含。前述の Lean より狭い既知の受理を保つ |

L50.4 の残りの一覧も、節の添字=R20.4、呼び出し範囲列=R20.3、署名・原子・表の交換=R10.7、必須判定・予算=R20、理由と報告=R40/K10、必須欄と全比較=K10、出現の番号=R20.1/.3/.6 と K10へ対応させた。

## 設計書と生成物

変更した設計書は00-04・02-03・02-05・01-12の4ファイルである。採用済みの9用語を定める章付きで加え、範囲付きのエフェクトと値型・Top・被覆・構造包含を区別した。02-03 の古い uses の説明を EffectRef と型／範囲引数に合わせた。02-05 は指摘と具体化時の再検査省略を反映した。01-12 は「現在の Rust は Top だけを作る」という進捗説明だけを訂正した。

01-12 の訂正は、07-04「01-12 との対応」の Lean 先行の条件を読んだうえで行った。構文・型の規則・脱糖・定義・言明・仮定・Lean の名前と写しを変えず、既に受理する閉じた注釈の説明を直したものである。用語のために形式化の規則を変えていない。

01-02・01-06・01-07・02-03・02-05・02-06・06-03と二型を説明する03-06/03-09の R10 の箇所を点検した。新しい純粋検査・射影・widen・七 IO を現行の Rust の実装済み API と説明する記述はなかった。01-12/07-04 の形式化の表・モデル・定理は、Rust の未接続を示す説明とともに保った。未実装の情報フロー制御の語を用語集へ加えていない。

見出しと text の例は変更していない。[design-checks.json](design-checks.json) に基準との比較と追加リンク20件の確認を保存した。`cargo run -p benitoite --example gen_skill` は終了0で、生成物の差はなかった。作業末でも skill_generated が再生成による一致を検査する。

実装・設計書は計12ファイルで、[implementation.patch](implementation.patch)・[changed-files.json](changed-files.json)・[line-counts.json](line-counts.json) に差分・大きさ・SHA-256・行数を保存した。生成器・標準宣言の意味・依存・Lean・scripts は変更していない。ヒープの不変条件・根・障壁・安全点を越える言語値の保持も変えておらず、H/H-full は対象外である。

## 検査

作業末の正確な指定は次のとおりである。`run_logged.py` の `--work` が time の内側で check.sh を実行し、直後の終了状態を保存して同じ状態で exit する。パイプの末尾の状態を check.sh の終了と数えない。`time -l` は使用していない。

```sh
scripts/check.sh --level work --base 3fc9b3f88c039e61bf797b1da574e5275028253d --dry-run
/usr/bin/time -p scripts/check.sh --level work --base 3fc9b3f88c039e61bf797b1da574e5275028253d
```

dry-run は fmt、既定の lib/tests/examples の clippy、lib 全件、全統合ターゲット、source_rules、skill_generated、spec_tally の7項目を選択した。spec_examples は全統合に含まれ、重ねて選ばれていない。[選択と理由](work-dry-run.log)を保存した。

| 実行 | 終了 | 外側の時間 | 根拠 |
|---|---:|---:|---|
| 署名の局所3テスト | 0 | 外側の計時なし。ビルド16.41秒、実行0.01秒 | [signature-local.log](signature-local.log) |
| B0 の CLI ビルド | 0 | 61.397秒 | [baseline-b0-build.json](baseline-b0-build.json)・同名 log |
| B_WORK の CLI ビルド | 0 | 62.136秒 | [baseline-work-build.json](baseline-work-build.json)・同名 log |
| 作業版の CLI ビルド | 0 | 11.970秒 | [current-build.json](current-build.json)・同名 log |
| gen_skill | 0 | 9.805秒 | [generation.json](generation.json)・[出力](generation.log) |
| CLI の比較、最終の条件照合 | 0 | 0.033秒（最初の比較0.037秒も保存） | [comparison-final.json](comparison-final.json)・[差の全体](cli-comparison.json) |
| W-R の dry-run | 0 | 0.120秒 | [work-dry-run.json](work-dry-run.json) |
| W-R、全7項目 | 0（check.sh 自身も0） | 453.586秒 | [work.json](work.json)・[全ログ](work.log)・[check.sh の終了](work-check-exit.txt) |

CLI の採取は B0 の初回を除き個別の JSON へ計時した。B0 の初回採取は計時していない。前枝と同じ249通りの B_WORK 採取16.058秒・作業版15.945秒、補足の最終採取は各 extra-*-final.json に保存した。環境・固定版・lockとmanifestのハッシュ・補助モジュールを含む入力のハッシュは [environment-and-inputs.json](environment-and-inputs.json) にある。

W-R は一度の実行で全7項目が成功した。2026-10-28 12:52:27.146〜13:00:00.732 UTC、Python の外側時計は453.585982秒、time の原値は real 453.58秒・user 1430.94秒・sys 52.24秒である。既定 lib は1,358成功・失敗0・既存の無視21、全統合は41ターゲット416成功・失敗0・既存の無視10であった。[ターゲットごとの件数](test-counts.json)を保存した。spec_examples、checked_args、declarations、fmt_command、golden、desugar_export、coverage_export、reference_examples 等を含む。無視・除外・時間制限・期待値を緩めていない。

補助の最大常駐量は2,352,070,656 bytes、2243.109375 MiB、2.190536499 GiBである。`/usr/bin/time -p` は RSS を報告しないため、同じコマンドだけを待つ Python の `getrusage(RUSAGE_CHILDREN).ru_maxrss` を採取した。macOS の原値の単位の根拠は [先行枝のローカル確認](../r10.1/getrusage-units.txt)を引き継ぐ。一つの子孫プロセスの最大値の補助記録であり、並行した全プロセスの RSS 合計ではない。OS の time 自体からの RSS は取得不能であって0ではない。基準版ビルド等の個別の RSS は各計時 JSON に保存し、作業末の値と合算しない。

## 初回の失敗と修正

作業末の W-R、通常83入力の比較、CLI のビルド、gen_skill に失敗はなかった。補足入力の最初の準備では、Http のハンドラの引数名が外側の request を隠して E0338 となり、ファイルの Fail を main に直接付けた例も E0506 で拒否された。意図した受理境界を確かめるため、節の引数を sent にし、Fail のファイル宣言を import する補助モジュールへ置いた。ソースの規則や診断を緩めた修正ではない。

また、最初の補足採取の input 欄が手元の絶対パスになったため、記録では `<wt>` に置換し、最終の台本は入力をリポジトリ相対で保存する形へ直した。初回の結果は extra-initial-*.json に残し、最終の採取を上書きで隠していない。通常の83入力は変更していない。

最終確認の台本の初回は、生成前の final-state.json をリンク先として検査する順序の誤りで終了1となった。[失敗の記録](final-validation-initial.log)を残し、出力を作ってから宛先の存在を検査する順序へ直した。処理系や検査の対象は変更していない。

## 計画との差、停止条件、申し送り

前の枝の通常検査の失敗、未接続の仮の成功値、今回の明示割当以外の必要な RV 修正の持ち越しは見つからなかった。Lean の規則・主定理・仮定、被覆と構造等号の境界、不変添字・署名の許容・資源 Top・公開契約を変える停止条件には該当しない。追加の resolve の文言配置と、01-12 の古い実装状態の説明の修正は、依頼で許された追随の範囲内である。

ただし、計画の先行条件である UB20.01/.02 の結果が未提供であるため、その照合と受け入れは未完である。先行枝へ戻すことを要する実装不備の発見と、資料がなく確認できない状態を区別する。取りまとめが両結果を確認し、必要な修正とその検査を R10.6 で閉じてから R10.7 へ渡す必要がある。

| 受け持つ担当・時期 | 残る手順 | 見込み |
|---|---|---:|
| 取りまとめ・R10.6 の受け入れ前 | UB20.01/.02 の結果の提供と指摘の照合、必要なら修正・古くなった検査 | 不明。計画の UB20 自体は能動時間1〜2時間 |
| 取りまとめ・R10.6 | 独立レビュー、指摘への対応と受け入れ | レビュー10〜20分、修正・受け入れ待ちは不明 |
| 取りまとめ・本体変更の取り込み後 | 今回の通常の具体化経路の変更を short の対象に含める計画の更新と比較 | 既存の short の手順。待ちはビルド不明、採取15分以内 |
| R10.7 | 署名・原子・表データ、非 Top の順、版の切り替え、独立期待値と排他の Lean ビルド後の局所 F-table、R10 段末レビュー | 計画の能動時間1.5〜4.5時間、work約9分、ビルド・局所比較待ちは不明 |
| K10 | scopeAcceptance・limits 等の全欄、k3 の番号の差、全書き出し元、型付け比較と最終の全形式比較 | 計画の担当を維持。今回には実行しない |

R10.7 は現在の RangeSignature・RangeIndex と解決済みの range_signatures を使い、旧版へ非 Top や rvar を混ぜないこと、Top でも個数・種類・Covers の番号と向きを検査すること、k3 の生のハッシュを意味の同一性と混同しないことを引き継ぐ。R20.3/.4・R30.2/.4 には上の直接の読者3箇所を必ず渡す。`check-formal.sh`、Lean のビルド、short の性能比較は本枝では実行していない。

## 時間

着手直後の時計は採っていない。最初に記録した時計は2026-10-28 12:45:04 UTCであり、それ以前に規約と指定文書を読み、担当を分けた。最終確認は 2026-10-28 13:02:47 UTC である。記録した時計の間は約17.7分であり、事前の読解・分担を含む外側全体は約25分、主担当の能動時間は約20分という概算である。担当ごとの厳密な能動時間は採っていない。作業末の検査の外側453.586秒、基準ビルドと採取・生成の個別の時間は前述の記録へ分けた。検査中も証拠と結果を整理したので、外側所要から検査時間を単純に引いて能動時間とはしない。新しい設計者の回答待ち・性能測定・取りまとめの独立レビューは行っていない。UB20 の所在照会には回答を得ていない。並行した担当の能動時間を外側の所要へ単純に加算しない。見込み上端2倍の9時間には達していない。

最終確認では、HEAD・ブランチが開始時のままであること、許された範囲だけの差分であること、実装・設計書の12ファイルの SHA-256 が保存値と一致すること、生成物の差がないこと、git diff --check の終了0、相対リンクの宛先、記録の手元の絶対パスの不在を確かめた。[確認記録](final-state.json)を保存した。作業末検査後に変更したのは結果と比較・確認の記録だけで、処理系・設計書・生成物は変更していない。
