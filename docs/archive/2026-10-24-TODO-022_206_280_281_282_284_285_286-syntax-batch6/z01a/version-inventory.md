# Z01b へ渡す版の記述の一覧

`git grep -n '0\.0\.11'` の追跡対象を照会した。未追跡の Z01a の記録自身は数えない。全件のパス・行番号・扱いは [version-inventory.json](version-inventory.json) に残した。行番号は Z01a の文書同期後である。過去の版を一括置換しない。

| ファイル | 該当行 | Z01b での扱い |
|---|---|---|
| `CHANGELOG.md` | 8, 28, 30, 34, 36 | UnreleasedをZ01bで版の見出しへ移す。過去版・比較元の0.0.11は保つ |
| `Cargo.lock` | 60 | 対象をbenitoiteに絞ったoffline updateで同期する |
| `README.md` | 7 | 現行版とCHANGELOGのアンカーを更新する |
| `crates/benitoite/Cargo.toml` | 3 | package.versionを0.0.12へ上げる（根のCargo.tomlに版指定はない） |
| `crates/benitoite/skill/SKILL.md` | 65 | 現行版・翻訳元・導入例・固定参照を更新し、過去移行節と比較元の版は保つ |
| `crates/benitoite/skill/references/idioms.md` | 951 | 現行版・翻訳元・導入例・固定参照を更新し、過去移行節と比較元の版は保つ |
| `crates/benitoite/skill/references/inspection.md` | 44 | 現行版・翻訳元・導入例・固定参照を更新し、過去移行節と比較元の版は保つ |
| `crates/benitoite/src/external/tests.rs` | 1613, 1755, 1779 | 現行版の成功入力・依存設定・期待値を確認して更新する。歴史的な拒否入力は保つ |
| `crates/benitoite/src/modules/hash.rs` | 222 | 現行版の成功入力・依存設定・期待値を確認して更新する。歴史的な拒否入力は保つ |
| `crates/benitoite/src/modules/package.rs` | 514, 523, 526, 534, 546 | BREAKING_CHANGESを追加し、履歴・全案内・受理表のテストを拡張する（既存版は保つ） |
| `crates/benitoite/src/modules/tests.rs` | 37, 72, 98, 107, 118, 914, 934, 958, 964, 970, 1043, 1078, 1114, 1118, 1153, 1189 | 受理表・現在より新しい版・全移行案内と成功用の設定を更新する |
| `crates/benitoite/src/modules/text.rs` | 51 | 0.0.11の既存移行文は保ち、0.0.12の要約・案内の定数を加える |
| `crates/benitoite/src/typeck/pattern_ext.rs` | 915 | 現行版の成功入力・依存設定・期待値を確認して更新する。歴史的な拒否入力は保つ |
| `crates/benitoite/src/typeck/tests/diagnostics_batch4.rs` | 267, 271 | 現行版の成功入力・依存設定・期待値を確認して更新する。歴史的な拒否入力は保つ |
| `crates/benitoite/testdata/external/self-package-outside/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/external/self-package/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/alias-only/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/config-declaration/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/config-textkit/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/copied-textkit/Textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/d6c-extensible-external/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/d6c-extensible-missing/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/d8-extensible-run/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/d8-extensible.files/dep/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/dependency-collision/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/dependency-config-declaration/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/dependency-no-block/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/dependency-root-import/Textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/dependency-root-overlap/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/dependency-settings.diag.json` | 3 | 現行版・E0907/E0908の追加案内・位置を候補の実診断に合わせる |
| `crates/benitoite/testdata/packages/dependency-settings/deps/transitive/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/distinct-modules/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/extensible.files/dep/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/hash-match/deps/hashkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/header-overlap/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/header-overlap/main.bnt` | 3 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/header-overlap/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/header/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/header/main.bnt` | 3 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/imported-header/Helper.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/imported-header/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/libraries.files/fuzzy/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/libraries.files/json-checks/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/libraries.files/pure-json/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/libraries.files/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/libraries.files/wasm-hash/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/libraries.files/wasm-json/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/libraries.files/wasm-regex/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/local-textkit/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/newer-config.diag.json` | 1 | 現行版・E0907/E0908の追加案内・位置を候補の実診断に合わせる |
| `crates/benitoite/testdata/packages/newer-language.diag.json` | 1 | 現行版・E0907/E0908の追加案内・位置を候補の実診断に合わせる |
| `crates/benitoite/testdata/packages/older-language.diag.json` | 1 | 現行版・E0907/E0908の追加案内・位置を候補の実診断に合わせる |
| `crates/benitoite/testdata/packages/package-as-root/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/package-dependencies/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/package-dependencies/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/package-error/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/package-header/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/package-isolation/deps/other/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/package-isolation/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/package-private-name/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/package-visibility-hidden/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/package-visibility-run/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/package-warning/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/root-config/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/root-config/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/root-fallback/deps/textkit/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/testdata/packages/todo-handler/deps/todo/package.bnt` | 1 | 成功させるlanguage宣言を更新し、依存ハッシュと位置の期待値も照合する |
| `crates/benitoite/tests/cli_process.rs` | 780 | 現行版の成功入力・依存設定・期待値を確認して更新する。歴史的な拒否入力は保つ |
| `crates/benitoite/tests/desugar_export/named.rs` | 641, 646 | 現行版の成功入力・依存設定・期待値を確認して更新する。歴史的な拒否入力は保つ |
| `crates/benitoite/tests/package_command.rs` | 18, 192, 219, 274, 275, 400, 405, 407, 452, 463 | 現行版の成功入力・依存設定・期待値を確認して更新する。歴史的な拒否入力は保つ |
| `crates/benitoite/tests/spec_examples.rs` | 455 | 現行版の成功入力・依存設定・期待値を確認して更新する。歴史的な拒否入力は保つ |
| `crates/benitoite/tests/test_command.rs` | 1441, 1448, 1956, 1967, 2887, 2902, 2911 | 現行版の成功入力・依存設定・期待値を確認して更新する。歴史的な拒否入力は保つ |
| `docs/design/01-spec/01-02-syntax.md` | 477 | 現行で受理するlanguageの例を更新する |
| `docs/design/06-tooling/06-09-packages.md` | 20, 32, 53, 55 | 既存の0.0.11行は保ち、0.0.12の登録・案内と受理の説明を加える |
| `docs/ja/reference/benitoite.md` | 3, 19, 103, 162, 1920, 1922, 1945, 1957, 1975, 2007, 2018, 2189 | 現行版・翻訳元・導入例・固定参照を更新し、過去移行節と比較元の版は保つ |
| `docs/ja/reference/install.md` | 3, 5, 7, 152, 154 | 現行版・翻訳元・導入例・固定参照を更新し、過去移行節と比較元の版は保つ |
| `docs/ja/skill/SKILL.md` | 3, 72 | 現行版・翻訳元・導入例・固定参照を更新し、過去移行節と比較元の版は保つ |
| `docs/ja/skill/references/common-mistakes.md` | 3 | 現行版・翻訳元・導入例・固定参照を更新し、過去移行節と比較元の版は保つ |
| `docs/ja/skill/references/idioms.md` | 3, 940 | 現行版・翻訳元・導入例・固定参照を更新し、過去移行節と比較元の版は保つ |
| `docs/ja/skill/references/inspection.md` | 3, 46 | 現行版・翻訳元・導入例・固定参照を更新し、過去移行節と比較元の版は保つ |
| `docs/ja/skill/references/language-comparison.md` | 3 | 現行版・翻訳元・導入例・固定参照を更新し、過去移行節と比較元の版は保つ |
| `docs/reference/benitoite.md` | 16, 100, 159, 2016, 2018, 2041, 2053, 2071, 2103, 2114, 2285 | 現行版・翻訳元・導入例・固定参照を更新し、過去移行節と比較元の版は保つ |
| `docs/reference/install.md` | 3, 5, 150, 152 | 現行版・翻訳元・導入例・固定参照を更新し、過去移行節と比較元の版は保つ |
| `fuzz/Cargo.lock` | 60 | 対象をbenitoiteに絞ったoffline updateで同期する |

## 置き換えない記録

CHANGELOG の過去版の節、0.0.11 への移行節、上限導入前の 0.0.11 との比較、BREAKING_CHANGES の過去版の定数は保つ。docs/archive、測定結果、第6弾の plan・判断・実行記録・translation-inventory の版は当時の入力であり更新しない。全件の分類は JSON の action を参照する。

## 検索に現れない対象

- `crates/benitoite/src/modules/package.rs` の `Version(0, 0, 11)` の登録は過去版として保ち、`Version(0, 0, 12)` を追加する。`language "0.0.11"` は E0908、`"0.0.12"` は受理、それより新しい版は E0907 とする。根と依存の独立照合・全移行案内の版順を保つ。
- `--version` と JSON の版、Skill の置換する版、producer は Cargo の現行版を元にする。候補をビルドして実出力・抽出した Skill・一覧と文書ハッシュを照合する。Git の build 情報は集約後に再照合する。
- `tools/derive/README.md` の現行の契約は generator `3.1.0-syntax-batch5`・inventory 3・manifest/receipt/record/hash 3・config 1・Property.libraryVersion `2.0.0` である。これらは処理系の版上げの対象ではない。英語リファレンスと Skill・訳も同じ値を保つ。
- 新しい互換性境界で成功用の package.bnt を直す場合、そのバイト列に依存する hash-match・package コマンド・外部宣言の入力、`.diag.json` の位置・案内も照合する。既存の拒否・警告テストの期待値を一括置換しない。
- `crates/benitoite/src/cli/tools/skill/bundle.rs` と Skill の生成参照は `gen_skill` で再生成する。生成物を手で直さない。
- 英語リファレンスと 06-09 の互換性節の追加、CHANGELOG の language の行、README・install の現行版のリンクを候補の実装と同時にそろえる。日本語訳も同じ枝で同期する。

## 二つの lock の同期

版上げ後は次の二つだけを使い、一括更新しない。両方の差分が benitoite のパス依存の版の同期であることを確認する。キャッシュが不足したら不足を確認して取得し、同じ対象限定のコマンドを使う。

```sh
cargo update --offline -p benitoite
cargo update --offline --manifest-path fuzz/Cargo.toml -p benitoite
```
