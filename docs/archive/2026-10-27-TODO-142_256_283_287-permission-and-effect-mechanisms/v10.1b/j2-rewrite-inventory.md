# J2 の書き換え一覧（未適用）

パスはリポジトリの根から省略せず記す。適用は V10.3a の版上げと同時である。各出現の行番号・内容・ハッシュは [JSON の全一覧](j2-rewrite-inventory.json) を正とする。

## testdata の50候補

| パス | 変更理由と依存して読む入力 |
|---|---|
| `crates/benitoite/testdata/external/self-package/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/external/self-package` |
| `crates/benitoite/testdata/external/self-package-outside/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/external/self-package-outside` |
| `crates/benitoite/testdata/packages/alias-only/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/alias-only` |
| `crates/benitoite/testdata/packages/config-declaration/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/config-declaration` |
| `crates/benitoite/testdata/packages/config-textkit/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/config-textkit` |
| `crates/benitoite/testdata/packages/copied-textkit/Textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/copied-textkit` |
| `crates/benitoite/testdata/packages/d6c-extensible-external/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/d6c-extensible-external` |
| `crates/benitoite/testdata/packages/d6c-extensible-missing/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/d6c-extensible-missing` |
| `crates/benitoite/testdata/packages/d8-extensible-run/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/d8-extensible-run` |
| `crates/benitoite/testdata/packages/d8-extensible.files/dep/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/d8-extensible-run` |
| `crates/benitoite/testdata/packages/dependency-collision/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/dependency-collision` |
| `crates/benitoite/testdata/packages/dependency-config-declaration/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/dependency-config-declaration` |
| `crates/benitoite/testdata/packages/dependency-no-block/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/dependency-no-block` |
| `crates/benitoite/testdata/packages/dependency-root-import/Textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/dependency-root-import` |
| `crates/benitoite/testdata/packages/dependency-root-overlap/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/dependency-root-overlap` |
| `crates/benitoite/testdata/packages/dependency-settings/deps/transitive/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/dependency-settings` |
| `crates/benitoite/testdata/packages/distinct-modules/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/distinct-modules` |
| `crates/benitoite/testdata/packages/extensible.files/dep/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/d6c-extensible-external`、`crates/benitoite/testdata/packages/d6c-extensible-missing` |
| `crates/benitoite/testdata/packages/hash-match/deps/hashkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/hash-match`、`crates/benitoite/testdata/packages/hash-mismatch` |
| `crates/benitoite/testdata/packages/header/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/header` |
| `crates/benitoite/testdata/packages/header/main.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/header` |
| `crates/benitoite/testdata/packages/header-overlap/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/header-overlap` |
| `crates/benitoite/testdata/packages/header-overlap/main.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/header-overlap` |
| `crates/benitoite/testdata/packages/header-overlap/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/header-overlap` |
| `crates/benitoite/testdata/packages/imported-header/Helper.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/imported-header` |
| `crates/benitoite/testdata/packages/imported-header/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/imported-header` |
| `crates/benitoite/testdata/packages/libraries.files/fuzzy/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/fuzzy-check`、`crates/benitoite/testdata/packages/fuzzy-run` |
| `crates/benitoite/testdata/packages/libraries.files/json-checks/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/json-pure-depth-array`、`crates/benitoite/testdata/packages/json-pure-depth-object`、`crates/benitoite/testdata/packages/json-pure-same` |
| `crates/benitoite/testdata/packages/libraries.files/pure-json/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/json-pure-depth-array`、`crates/benitoite/testdata/packages/json-pure-depth-object`、`crates/benitoite/testdata/packages/json-pure-same`、`crates/benitoite/testdata/packages/json-wasm-same` |
| `crates/benitoite/testdata/packages/libraries.files/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/outside-textkit` |
| `crates/benitoite/testdata/packages/libraries.files/wasm-hash/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/wasm-hash-same` |
| `crates/benitoite/testdata/packages/libraries.files/wasm-json/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/json-wasm-same` |
| `crates/benitoite/testdata/packages/libraries.files/wasm-regex/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/wasm-regex-same` |
| `crates/benitoite/testdata/packages/local-textkit/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/local-textkit` |
| `crates/benitoite/testdata/packages/package-as-root/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/package-as-root` |
| `crates/benitoite/testdata/packages/package-dependencies/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/package-dependencies` |
| `crates/benitoite/testdata/packages/package-dependencies/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/package-dependencies` |
| `crates/benitoite/testdata/packages/package-error/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/package-error` |
| `crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/package-header` |
| `crates/benitoite/testdata/packages/package-header/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/package-header` |
| `crates/benitoite/testdata/packages/package-isolation/deps/other/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/package-isolation` |
| `crates/benitoite/testdata/packages/package-isolation/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/package-isolation` |
| `crates/benitoite/testdata/packages/package-private-name/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/package-private-name` |
| `crates/benitoite/testdata/packages/package-visibility-hidden/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/package-visibility-hidden` |
| `crates/benitoite/testdata/packages/package-visibility-run/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/package-visibility-run` |
| `crates/benitoite/testdata/packages/package-warning/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/package-warning` |
| `crates/benitoite/testdata/packages/root-config/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/root-config` |
| `crates/benitoite/testdata/packages/root-config/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/root-config` |
| `crates/benitoite/testdata/packages/root-fallback/deps/textkit/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/root-fallback` |
| `crates/benitoite/testdata/packages/todo-handler/deps/todo/package.bnt` | 登録後のE0908による早期拒否・比較範囲減少を防ぐ。`crates/benitoite/testdata/packages/todo-handler` |

この50件は成功用の版宣言である。拒否を狙うfixtureにも、その目的の検査まで進めるための正常な依存headerがある。`.files` は独立に収集せず依存として読む。通常のfixtureは `export_desugar_corpus` が読み、出力が変わった場合は desugarDiff・builtinCheck・surfaceCheckAll・coverageProgramDiff・check_named と区間 collect・実ソース比較・manifest/verify を再確認する。`libraries.files/{wasm-json,pure-json,wasm-regex}` は `export_interval_manifest` の json-wasm-same/wasm-regex-same からも読まれる。d6c の三パッケージは `named::export_extensible_source` の入力でもある。単なるheaderの同じ長さの変更だけで出力不変としない。

## テストと登録・文言

| パス | 変更と読者 |
|---|---|
| `crates/benitoite/tests/cli_process.rs` | 版登録後も検査本来の目的へ到達させる。過去の版の説明を保つ。cli_process。全比較の交換入力を直接作らない |
| `crates/benitoite/tests/package_command.rs` | 版登録後も検査本来の目的へ到達させる。過去の版の説明を保つ。package_command。全比較の交換入力を直接作らない |
| `crates/benitoite/tests/spec_examples.rs` | 版登録後も検査本来の目的へ到達させる。過去の版の説明を保つ。spec_examples（01-03等の独立MemFs）。全比較の直接入力ではない |
| `crates/benitoite/tests/test_command.rs` | 版登録後も検査本来の目的へ到達させる。過去の版の説明を保つ。test_command。全比較の交換入力を直接作らない |
| `crates/benitoite/tests/desugar_export/named.rs` | 版登録後も検査本来の目的へ到達させる。過去の版の説明を保つ。named::export_extensible_packageの根とDepのheader二つ。六入口/check_named。export_extensible_sourceはtestdata d6c経由 |
| `crates/benitoite/src/modules/tests.rs` | 版登録後も検査本来の目的へ到達させる。過去の版の説明を保つ。lib_default。loaderの版登録が全比較全般の受理へ影響する。MemFsの文字列自体は交換に収集されない |
| `crates/benitoite/src/modules/hash.rs` | 版登録後も検査本来の目的へ到達させる。過去の版の説明を保つ。lib_default。loaderの版登録が全比較全般の受理へ影響する。MemFsの文字列自体は交換に収集されない |
| `crates/benitoite/src/external/tests.rs` | 版登録後も検査本来の目的へ到達させる。過去の版の説明を保つ。lib_default。loaderの版登録が全比較全般の受理へ影響する。MemFsの文字列自体は交換に収集されない |
| `crates/benitoite/src/typeck/tests/diagnostics_batch4.rs` | 版登録後も検査本来の目的へ到達させる。過去の版の説明を保つ。lib_default。loaderの版登録が全比較全般の受理へ影響する。MemFsの文字列自体は交換に収集されない |
| `crates/benitoite/src/modules/package.rs` | BREAKING_CHANGESへVersion(0,0,13)を追加し、登録表を読むテストのnotes/helps/change_versions/current/end/firstを追随。旧版の文言は保持。lib_default。登録自体はcheck_header経由で全比較のloaderに影響 |
| `crates/benitoite/src/modules/text.rs` | J2再現に対応する事実だけのsummary/helpを追加。節の変更手順・移行例は含めない。登録表経由のE0908。corpusの受理へはpackage.rsの登録を通して影響 |

統合5ファイル・src内4ファイルの計9ファイルに、登録表を含むpackage.rsとtext.rsの2ファイルを加えて11ファイルである。modules/tests.rs は境界テストだけを差分案に含め、残りの成功用headerは一覧に記した。named.rsの二header以外のテスト内MemFs文字列を全比較へ収集したとはしない。

## 診断期待値

| パス | 変更 |
|---|---|
| `crates/benitoite/testdata/packages/dependency-settings.diag.json` | E0907の現在版表示だけ0.0.12から0.0.13へ。99.0.0の入力・位置・コードは保持。E0914/E0915は保持。transitive/package.bntのheader更新も別途必要。golden。export_desugar_corpusは.diag.jsonを読まない |
| `crates/benitoite/testdata/packages/newer-config.diag.json` | E0907の現在版表示だけ0.0.12から0.0.13へ。99.0.0の入力・位置・コードは保持。golden。export_desugar_corpusは.diag.jsonを読まない |
| `crates/benitoite/testdata/packages/newer-language.diag.json` | E0907の現在版表示だけ0.0.12から0.0.13へ。99.0.0の入力・位置・コードは保持。golden。export_desugar_corpusは.diag.jsonを読まない |
| `crates/benitoite/testdata/packages/older-language.diag.json` | 入力の0.0.4と最初の互換変更0.0.5・既存note/helpを保持し、末尾に0.0.13のnote/help（各1件）を追加。現在版表示の置換はない。golden。export_desugar_corpusは.diag.jsonを読まない |

## 依存のハッシュ

06-09「中身のハッシュ」に従う独立した再計算案である。ファイルを変更せず、0.0.13のheaderのバイト列をメモリ上で用いた。旧値は既存の固定値と一致した。

| 対象 | 旧値 → 提案値 | 変更先 |
|---|---|
| hashkit | `sha256:957fa49ad82a7d47e84a1f4730596d02f9dcd6dbf4b77321a6166decf235154b` → `sha256:3964a146fd259d0fef4d48af4ffb39ac0c824bd9ce6aaa67d3fef0e8211e6bdd` | `crates/benitoite/testdata/packages/hash-match/package.bnt`、`crates/benitoite/testdata/packages/hash-mismatch.diag.json` |
| modules-hash | `sha256:4fb9f0d272db82091050add15b118cfe017d3841af3a6020b7ddd19c618be2a4` → `sha256:730c7986f912d2cbafaf963824f1f28ed8bd731c4c04e28b7bd3ad288aa67546` | `crates/benitoite/src/modules/hash.rs::FIXED` |
| package-command | `sha256:b43b05e8f8d278bca44f4159a12db4fe14192cca587a25593e23706dbf4ef9fb` → `sha256:4eefbd9e6069548683f4aad0bed473b5b76b734591264b65e49b51854d70ffb8` | `crates/benitoite/tests/package_command.rs::add_and_update_record_hashes_effect_deltas_and_unchanged_state` |

hash-match の成功値と hash-mismatch の computed note を対で更新する。hash-mismatch の expected=全ゼロは保持する。package コマンドのadd/updateはCONFIG変更後の同じファイル集合で再計算し、動的に得るhashや包含条件の試験を固定文字列へ変えない。modules/hash.rsのFIXEDもCONFIGと同時に更新する。全比較はhash-match/mismatchのloaderを経るため一般corpusの再出力で受理と診断付き除外を照合する。テスト内の独立fixtureのhashはlib/package_commandが読者である。

## 一括置換から除くもの

| パス | 理由 |
|---|---|
| `crates/benitoite/testdata/packages/older-language/main.bnt` | 0.0.4を狙うE0908。宣言は保持 |
| `crates/benitoite/testdata/packages/newer-language/main.bnt` | 99.0.0を狙うE0907。宣言は保持 |
| `crates/benitoite/testdata/packages/newer-config/package.bnt` | 99.0.0を狙うE0907。宣言は保持 |
| `crates/benitoite/testdata/packages/dependency-settings/deps/future/package.bnt` | 99.0.0を狙う依存のE0907。宣言は保持 |
| `crates/benitoite/testdata/packages/hash-mismatch/main.bnt` | 不一致を狙うゼロのhashは保持。computedだけ更新 |
| `crates/benitoite/src/modules/package.rs` | 0.0.5〜0.0.12の登録・過去のnote/helpと旧版境界を保持。差分案で0.0.13だけ追加 |
| `crates/benitoite/src/modules/text.rs` | 旧版のCHANGE/MIGRATIONは保持。新helpの事実だけの制約を過去の説明へ遡及しない |
| `CHANGELOG.md` | 過去の版の説明は一括置換しない。今回の移行手順・移行例を作らない |

## V10.1bb 追補（RV-V10.1b 中1・中2）

上の表と件数は初稿の記録として残す。以後はこの追補とJSONの `counts` を使う。初稿のJSONの件数は `firstDraftCounts` に残し、`testFiles` へ漏れていた1ファイルを追加した。

指定の `git grep -n -E '0\.0\.12|0, 0, 12'` は終了0、955ファイル・2,611行であった。エスケープした宣言にも一致する。生出力（20,923,657 bytes。[LARGE-FILES.txt](LARGE-FILES.txt) に大きさと SHA-256）と[全ファイルの分類](v10.1bb-version-grep.json.gz)を保存した。検索の一致行数を、編集する宣言の数やファイル数と混同しない。

| 区分 | 初稿 | 追補後 |
|---|---:|---:|
| testdata | 50 | 50 |
| テスト内の版文字列 | 統合5・src内4、計9 | 統合5・src内5、計10 |
| 登録・文言を加えた区分全体 | 11 | 12 |
| 診断期待値 | 4 | 4 |
| 依存ハッシュ | 3組・変更先4か所 | 3組・変更先4か所 |
| 文書の例を加える前の重複を除く対象 | 67 | 68 |
| 文書の例 | 未計上 | 6 |
| 文書の例を含む重複を除く書き換え候補 | 67 | 74 |
| 関連する版・固定参照・訳元の表示（保持判断を含む） | 未計上 | 11 |
| 上記全体の重複を除く確認・編集候補 | 67 | 85 |
| 既存の一括置換からの除外 | 8行 | 8行 |

### テストと登録・文言への追加

| パス | 変更案と読者 |
|---|---|
| `crates/benitoite/src/typeck/pattern_ext.rs:920` | #[cfg(test)] 内の external の場合に使う根の package.bnt の成功用宣言を0.0.13へ更新する。E0908より先のパターンの検査へ到達させる。lib_default の typeck::pattern_ext::tests。依存側の設定は既存50候補の d8-extensible.files/dep/package.bnt。MemFsの文字列を全比較へ収集しない |

### 文書の例

inlineの過去の宣言も含めて区分した。宣言の更新・保持は次表の案であり、この作業では入力を変更していない。

| パス・行 | 読むテストと確認範囲 | V10.3aへの案 |
|---|---|---|
| `docs/design/01-spec/01-02-syntax.md`（477） | spec_examples::spec_and_appendix_examples_are_readable の text 抽出 → check_example → check_local_bindings → pipeline::check_files。ローダは通るが、loading_errors と 束縛診断の絞り込みに E0907/E0908 はなく、版の受理自体を検査の成功条件にしていない。版上げ後に束縛の検査まで到達することは V10.3a で確かめる | V10.3aで現在の正常な先頭部分の例を0.0.13へ更新する案。spec_examples.rsの補助の依存headerと同時に確認する |
| `docs/design/06-tooling/06-09-packages.md`（20、32） | spec_examples の text 抽出対象は01-specと付録08-04であり、本章は含まれない。文書の例を直接実行するテストは、調べた tests 内では見つからなかった | V10.3aで根とパッケージの正常な宣言の例を0.0.13へ更新する案。54・56行の過去の登録・案内の説明は保持し、新登録の説明は現行の設計文書との整合で別に確認する |
| `docs/reference/benitoite.md`（2059、2077、2109） | reference_examples::code_examples_in_the_language_reference_behave_as_written → doc_examples。2059の files と2077の本文はCLIのrun、2109の files はCLIのcheckへ渡る。三つとも実ローダが版を照合する | V10.3aで三つの実行例の宣言と現在版の説明・version表示を0.0.13へ更新する案。2016〜2020の旧版の移行節と旧版の宣言は保持し、一括置換しない。新しい移行手順は書かない |
| `docs/ja/reference/benitoite.md`（1963、1981、2013） | reference_examplesのDOCUMENTSは英語のbenitoite.mdだけであり、この訳は直接実行しない。英語の例との対照をV10.3aで行う | V10.3aで対応する三宣言・現在版の表示・訳元を英語と同時に0.0.13へ更新する案。1920〜1924の旧版の移行節と旧版の宣言は保持する |
| `docs/reference/install.md`（inlineの旧版の宣言はJSON参照） | reference_examplesのDOCUMENTSにinstall.mdはなく、直接実行するテストは調べた tests 内では見つからなかった | V10.3aで3・5行の現在版の説明を0.0.13へ更新する案。150・152行の0.0.11から0.0.12への更新節とinlineのlanguage宣言は過去の手順として保持する。0.0.13の移行手順に書き換えない |
| `docs/ja/reference/install.md`（inlineの旧版の宣言はJSON参照） | 直接実行するテストは調べた tests 内では見つからなかった。英語install.mdとの対照をV10.3aで行う | V10.3aで3・5・7行の訳元と現在版の説明を英語と同時に更新する案。152・154行の旧版の更新節とinlineのlanguage宣言は保持する |

01-02の版の診断を失敗に含めない点は読解で確定するが、版上げ後の実行は本追補で行っていない。正常な現在版の例として宣言を更新し、V10.3aで `spec_examples` の結果を確かめる。検査器を拡張する案ではない。

### 検索で拾った関連する版・固定参照・訳元の表示

上の74ファイルと重ならない11ファイルである。現行版へ更新する表示と、意味を確認して保持できる固定参照を区別した。文書の例の6ファイル内の現在版表示・過去の節は、前表とJSONの全出現へ含めた。

| パス | V10.3aでの更新・保持の案 | 読者 |
|---|---|---|
| `crates/benitoite/Cargo.toml` | V10.3aでbenitoiteの版だけ0.0.13へ。ワークスペースの全依存を更新しない | Cargoとbuild_info。W-V |
| `Cargo.lock` | V10.3aでbenitoite項目を対象を絞って同期する | Cargo。W-Vと候補照合 |
| `fuzz/Cargo.lock` | V10.3aでbenitoiteのパス依存の項目だけ同期する | fuzzのCargo。勧告照合と候補照合 |
| `README.md` | V10.3aで現在版を更新する。0.0.13の移行案内を作らない | 実行例の自動抽出ではなく候補照合 |
| `crates/benitoite/skill/SKILL.md` | 既存必須欄の説明だけを指すv0.0.12固定参照は意味を確認して保持できる。V10.2bの一覧をV10.3aで照合する | skill_examplesとskill_docs。リンク先の取得・内容の実行を確認した意味ではない |
| `crates/benitoite/skill/references/inspection.md` | 既存必須欄のv0.0.12固定参照は意味を確認して保持できる。新しい範囲の説明は候補版へ固定する。V10.2bでの編集結果をV10.3aで照合する | skill_examples。版固定参照の意味は文書と候補の照合 |
| `docs/ja/skill/SKILL.md` | V10.3aで訳元の版を0.0.13へ更新し英語の最終差分に対応させる。版固定参照は英語側の保持・更新の判断に合わせる | 日本語訳をskill_examplesのDOCUMENTSには含めない。V10.3aで英語との対照 |
| `docs/ja/skill/references/common-mistakes.md` | V10.3aで訳元の版を0.0.13へ更新し英語の最終差分に対応させる。版固定参照は英語側の保持・更新の判断に合わせる | 日本語訳をskill_examplesのDOCUMENTSには含めない。V10.3aで英語との対照 |
| `docs/ja/skill/references/idioms.md` | V10.3aで訳元の版を0.0.13へ更新し英語の最終差分に対応させる。版固定参照は英語側の保持・更新の判断に合わせる | 日本語訳をskill_examplesのDOCUMENTSには含めない。V10.3aで英語との対照 |
| `docs/ja/skill/references/inspection.md` | V10.3aで訳元の版を0.0.13へ更新し英語の最終差分に対応させる。版固定参照は英語側の保持・更新の判断に合わせる | 日本語訳をskill_examplesのDOCUMENTSには含めない。V10.3aで英語との対照 |
| `docs/ja/skill/references/language-comparison.md` | V10.3aで訳元の版を0.0.13へ更新し英語の最終差分に対応させる。版固定参照は英語側の保持・更新の判断に合わせる | 日本語訳をskill_examplesのDOCUMENTSには含めない。V10.3aで英語との対照 |

その他の一致は保管済み文書37ファイル、今回の改造の記録834ファイル、過去のCHANGELOG 1ファイルである。これらを版上げの一括置換へ含めない。候補内での保持箇所も全出現と変更案に記した。
