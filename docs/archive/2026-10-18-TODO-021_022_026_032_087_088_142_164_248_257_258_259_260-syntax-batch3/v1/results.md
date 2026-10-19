# V1: 0.0.9・訳・同梱物と移行案内

基準のコミット（B_WORK）は `4f4ce985b77dc345e8193e4bf44d564d8330b11c`。開始時の作業ツリーに差分はなかった。コミット、docs/todoの変更、タグ付け、公開は行わない。

## 変更

- crates/benitoite/Cargo.toml、根とfuzzのCargo.lockを0.0.9へ更新し、README・英日reference/install・手書きSkillの訳を最終APIへそろえた。
- CHANGELOGの0.0.9へ、Regex/Scopeの定数拒否と動的Errorのテスト、Rangeの通常のError、@opaque後付けの影響、構築器のState・捕捉制限、doc報告版2、inventory/生成記録/Propertyの別々の版と新manifestの確認をまとめた。tools/derive/READMEにも版の対応と同じ移行への入口を加えた。
- 日本語referenceへ不透明型、Scope/Range、二引数クラス、三種の構築器、文書例、ShrinkStepと二つの予算、Show/Order生成を反映した。A2からの第二級の値という用語・見出し・上限超過の説明も反映した。260の既存の英日11節・18節の例は保った。
- 手書きSkillに不足していた公開境界・構築器の制限と対処を英日で加えた。gen_skillから全参照とbundleを再生成した。生成内容とbundle一覧には開始版からの差分がなかった。A2で変わった直接参照の領域の計上と、E0435へ早く達しうる点も英日referenceと移行案内へ補った。
- 既存の0.0.9の互換性表を現在版へ接続した。現行設計の互換性の説明と実行例、パッケージ・外部宣言・doc環境・交換入力のlanguageを更新した。歴史上の変更表の0.0.5〜0.0.8は保持した。

## テスト変更の関門

版の受理と移行案内は既存の公開読み込み境界の表で確かめる。0.0.8の拒否行を残し、0.0.9の受理と0.0.10の未来版の拒否へ移した。入口・根の設定・依存設定の全箇所で、診断コード・位置・主文・案内の順と全文を厳密に照合する。受理中の版を固定したままにすると、版の切り替え後に正常な入力が別の拒否へ進むため、関係する既存入力も更新した。新しいテストや本番の差し込み口は加えていない。

固定ハッシュはPythonのhashlibで、各入力のSHA-256と相対パスの行をソートして再度SHA-256する独立した計算で更新した。ゴールデンの期待を変えたのは、現在版の表示、追加された0.0.9の移行案内、languageのバイト変更によるcomputed hashだけである。診断のコード・位置・拒否条件は保つ。既存assertの削除・緩和、テストのignore化はない。

## 局所の確認

- `cargo run -p benitoite --example gen_skill`: 終了0（Cargoの表示17.72秒。外側は未計測）。生成参照とbundleに差分なし。
- `cargo test -p benitoite --lib modules::`: 終了0、39件成功（テスト内2.00秒。外側は未計測）。
- `BENITOITE_GOLDEN_FILTER=packages cargo test -p benitoite --test golden golden_suite`: 終了101、外側20.29秒。49ケース中hash-mismatchのcomputed hashだけが旧値で不一致だった。hash-matchで独立に再計算した同じ依存の新ハッシュへ更新した。
- `BENITOITE_GOLDEN_FILTER=hash-mismatch cargo test -p benitoite --test golden golden_suite`: 終了0、外側0.14秒。診断のほかの欄は変更していない。残るパッケージのケースを局所で重ねず、作業末の全goldenへ渡した。
- `cargo fmt`: 終了0。作業末のfmt検査とは別の整形操作である。
- 英日reference・SKILL・idioms・common-mistakes・language-comparisonのbenitoite/output/stderr/diagnostic/filesのフェンスを抽出して照合した。各75/4/47/56/5ブロックが全文一致した。訳注のtextやshのブロックはこの件数に含めない。

## 作業末の検査

計画の次のworkを一度実行した。先に同じ指定へ `--dry-run` を付けて、選ぶ単位と理由を確認した。外側の時間はrtk proxyから起動する子プロセスの前後をPythonのtime.monotonicで計測した。

```sh
scripts/check.sh --level work --base 4f4ce985b77dc345e8193e4bf44d564d8330b11c --test '*' --dry-run
scripts/check.sh --level work --base 4f4ce985b77dc345e8193e4bf44d564d8330b11c --test '*'
cargo clippy --all-targets
cargo build -p benitoite --example derive_inventory --bin benitoite
python3 -B tools/derive/test_derive.py
target/debug/benitoite check tools/derive/examples/People.bnt
target/debug/benitoite test tools/derive/examples/People.bnt
python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json
target/debug/benitoite --version=json
```

| 検査 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| work dry-run | 0 | 0.08秒 | fmt、lint_default、lib_default、tests_related、source_rules、skill_generated、spec_tally、python_syntax、migrate_selftests、licensesを選択 |
| work | 0 | 383.00秒 | 選んだ全単位が成功。lib1217件・全40統合ターゲット310件成功、失敗0 |
| 追加clippy --all-targets | 0 | 13.90秒 | 成功 |
| derive_inventory/CLIのビルド | 0 | 1.71秒 | 0.0.9の候補から実ビルド |
| derive自己検査 | 0 | 47.80秒 | 34件成功。旧記録/旧manifest/本文改変/再適用/復旧を含む |
| 同梱Peopleのcheck | 0 | 0.84秒 | 成功 |
| 同梱Peopleのtest | 0 | 0.49秒 | 2件成功 |
| 同梱例のderive check | 0 | 0.33秒 | generated regions and records match |
| 実CLIの版の問い合わせ | 0 | 0.02秒 | 0.0.9、testCheckReport/testResultsは[1,2] |
| 変更文書のリンク・英日フェンス・差分 | 0 | 0.25秒 | 相対リンク534件（アンカーも含む）に切れなし。英日フェンス一致、git diff --check成功 |

work内のfmtは `cargo fmt --all --check`、libは `cargo test -p benitoite --lib` である。関係統合は `cargo test -p benitoite --test '*'` であり、spec_examples・reference_examples・skill_docsを含むため別実行しない。tools/derive/READMEの変更により、自動選択がPython構文とsource-migrate/try-actions-migrateの自己検査（各6件）も実行した。変更のないPython構文の直接の再検査は追加していない。libの既存ignoreは21件、統合の既存ignoreは9件で、新しくignoreにしたものはない。ビルド情報の5件、交換の書き出し、Propertyのlongは今回の通常workでは実行しない。ユーザーの指示どおり特殊構成・all-targetsのテスト・全体のcheckは追加しなかった。

cli_processの29件は、`--doc`の版2、--versionの形式、全埋め込み文書とlist/show/installの版置換後の本文・長さ・ハッシュの一致を含む。標準docの統合ターゲットと英語reference/Skillの例も成功した。版の問い合わせのbuildはcommitが開始版、dirtyがnull（notCollected）、targetがaarch64-apple-darwinであり、未コミット差分を含む候補がcleanであることを意味しない。releaseの候補同一性の証拠には転用しない。

Rustの変更はすべて既存のテスト入力・期待値であり、本番の処理の変更はない。Rustは51行追加・46行削除（差し引き5行増）、既存assertとignoreの数は各ファイルで不変である。workは初回のまま成功し、作業末の補完・再実行は不要だった。以下に統合ターゲット別の件数を残す。

| 対象 | 成功 | 失敗 | 無視 | テスト内の秒数 |
|---|---:|---:|---:|---:|
| build_info | 0 | 0 | 5 | 0.00 |
| call_allocations | 3 | 0 | 0 | 14.27 |
| checked_args | 8 | 0 | 0 | 8.94 |
| cli_process | 29 | 0 | 0 | 6.74 |
| coverage_export | 1 | 0 | 1 | 0.11 |
| declarations | 7 | 0 | 0 | 0.31 |
| desugar_export | 25 | 0 | 1 | 3.50 |
| external_signals | 3 | 0 | 0 | 0.87 |
| fmt_command | 18 | 0 | 0 | 0.18 |
| golden | 2 | 0 | 0 | 49.40 |
| http_descriptor_exhaustion | 1 | 0 | 0 | 0.40 |
| http_exchange_release | 3 | 0 | 0 | 0.90 |
| interrupt_process | 9 | 0 | 0 | 9.83 |
| io_modes | 7 | 0 | 0 | 0.79 |
| l10_console_clock_process | 3 | 0 | 0 | 0.94 |
| l13_external_commands | 7 | 0 | 0 | 6.15 |
| l21_json | 4 | 0 | 0 | 0.26 |
| l23_csv | 1 | 0 | 0 | 0.16 |
| l24_time | 1 | 0 | 0 | 0.09 |
| l30_http_server | 12 | 0 | 0 | 3.43 |
| l31_http_serve_and_helpers | 6 | 0 | 0 | 0.78 |
| l32_http_client | 9 | 0 | 0 | 12.69 |
| named_arguments | 21 | 0 | 0 | 1.80 |
| network_faults | 3 | 0 | 0 | 0.70 |
| open_062 | 8 | 0 | 0 | 1.70 |
| open_062_http | 4 | 0 | 0 | 0.70 |
| package_command | 13 | 0 | 0 | 0.27 |
| property_library | 15 | 0 | 2 | 7.84 |
| random_programs | 4 | 0 | 0 | 33.98 |
| reference_examples | 1 | 0 | 0 | 2.67 |
| runtime_builtins | 10 | 0 | 0 | 1.45 |
| skill_docs | 8 | 0 | 0 | 0.09 |
| skill_examples | 3 | 0 | 0 | 3.43 |
| spec_examples | 7 | 0 | 0 | 2.36 |
| stdlib_doc_examples | 1 | 0 | 0 | 1.84 |
| test_command | 46 | 0 | 0 | 3.24 |
| verify | 2 | 0 | 0 | 63.68 |
| vm_handlers | 2 | 0 | 0 | 12.95 |
| vm_lazy | 1 | 0 | 0 | 0.30 |
| vm_reference_cells | 2 | 0 | 0 | 5.33 |

## 取りまとめへ渡す実装範囲

以下は先行作業の実装範囲と記録の所在であり、過去の検査結果を別の関係状態へ引用してV1の検査を省いたものではない。

| 作業 | 引き渡す範囲 | 元の記録 |
|---|---|---|
| C1/C2・P1/P2 | 詳細設計・計画と事前点検の修正 | c1/、c2/、p1/、p2/results.md |
| L1/L2/L3/L4a/L4b/L4c/L5/L6/L7 | 公開境界・Scope/Range小モデル、Resultの法則、構築器の表層・検査器・脱糖と交換版12 | 各小文字ID/results.md、reviews/RV2.md |
| T1/T2/T3 | Body内の表、Fail確定、制約の索引とmap/solve比較状態 | t1/、t2/、t3/results.md |
| K1/K2/K3/K4 | opaque、定数取得とRegex、Scope、Range | k1/、k2/、k3/、k4/results.md |
| M1/B1/B2/B3 | 二引数クラスとResult、三種の第二級の構築器と交換・安全点 | m1/、b1/、b2/、b3/results.md |
| G1/G2/G3/G4 | inventory版2、Show/Order、ShrinkStep、予算と生成記録の一括移行 | g1/、g2/、g3/、g4/results.md |
| H1/H2/H3 | doc元位置と共通抽出、test --docの許可と報告、標準例とFail案内 | h1/、h2/、h3/results.md |
| A1/A2 | RV3/RV4の修正。構築器の使用元import、const由来の費用、第二級の値の用語、Yield上限駆動など | a1/、a2/results.md、reviews/RV3.md・RV4.md |
| V1 | 現在版、英日文書、同梱物、移行案内と全読者のwork | 本書 |

## 計画からのずれ・未実施・申し送り

R186で開始版と検査を固定した。版を持つテスト入力と固定ハッシュの更新、依頼の追加clippy以外に機能の範囲の変更はない。formal/と交換manifestは変更していない。V1は正式モデル・主定理・公理・Builtins.Assumptionsを変更しない。

- 取りまとめはR130に従い、V1後の候補からrouting/exchangeの件数を再集計し、二manifestを照合・更新してから全比較へ進むこと。V1はlanguageの正常入力を変えたが定義・脱糖の追加削除はしていない。H3等の標準doc・新golden・生成例の増減は各元記録も確認すること。
- change、check-formal全体、GC特殊構成、032/257/258と構築器の本測定、releaseの候補・実CLI・配布物照合、RV5と設計者の受け入れは取りまとめへ残す。V1のworkの成功だけで改造全体の完了とはしない。
- maxShrinkWork:10000は小さな例の暫定推奨のままである。本測定で変更する場合は説明と例・生成物をそろえ、古くなる検査だけを更新する。性能目標の達成、最小反例、コールバック内部の時間や確保、構築器のネイティブな高速化は保証していない。
- 再帰・型パラメータを持つ生成対象、型構成子の部分適用、State消去、既存IOの引数型の制限、実行時の権限制御、Property専用実行器は今回の対象外である。13件の今回の実装範囲と、各TODO項目全体の閉鎖を区別する。docs/todoの項目の閉鎖・archiveへの移動・公開は行わない。
