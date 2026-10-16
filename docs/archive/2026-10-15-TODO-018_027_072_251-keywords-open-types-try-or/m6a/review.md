# M6a 版の宣言と固定ハッシュの確認表

## 対象と確認の単位

M7 で 0.0.6 と通常入力を同時に更新するためのパッチである。現在の処理系、通常入力、crate の版には適用していない。元のバイト内容、適用順、各段階の適用後のハッシュを [manifest.json](manifest.json) に固定した。作業の結果は [results.md](results.md) に記す。

P1 の files を全追跡ファイルから更新し、履歴として除く範囲を同じにした。[inventory.json](inventory.json) は4,364ファイルのハッシュ、P1 からの変更278件・追加92件・削除0件、版・language・64桁のハッシュの候補2,046件を持つ。コメント、Markdown のインライン、Rust の通常文字列・raw 文字列・format!/concat! の材料も走査した。候補の action と理由を確認済みにし、未分類・未確認は0件である。行は元のソース上の位置であり、AST の件数ではない。

歴史資料の除外範囲は reference、docs/archive、docs/todo、tools/bench/results、tools/skill-eval/results、tools/syntax-measure である。今回を含む docs/YYYY-MM-DD-… の作業記録も通常入力に数えない。除外した追跡ファイルの件数は inventory の excluded_tracked_counts にある。新たな通常入力や変更があれば verify.py がファイル集合かハッシュの違いで拒否する。

## 適用順と元の内容

次の三つを番号順に適用する。途中では版と入力が揃わないため、M7 では三つをすべて適用してから処理系を検査し、一つの取り込みにする。パッチ自身の SHA-256 と全対象ファイルの適用前後の SHA-256 は manifest の stages にある。開始時の HEAD は `584955aa6bd709f958481f9bf1f453e0c3e2fcb2` である。文書だけの取り込みで HEAD が変わった場合も、適用条件は記録した元のバイト内容である。

| 順序 | パッチ | 内容 |
|---|---|---|
| 1 | [01-release.patch](01-release.patch) | crate/Cargo.lock の版、本番 BREAKING_CHANGES の0.0.6登録、既存の検査用文言を本番へ接続、CHANGELOG の移行・診断の説明。5ファイル |
| 2 | [02-current-inputs.patch](02-current-inputs.patch) | 通常入力と期待する版、依存の控え、設計書・英語リファレンス、日本語リファレンス・導入例。69ファイル |
| 3 | [03-boundaries-and-hashes.patch](03-boundaries-and-hashes.patch) | 入口・根の設定・依存の版境界、旧/未来版とハッシュ不一致の厳密な期待値、独立計算した固定ハッシュ。9ファイル |

同じファイルに複数段が触るため、全体の対象は80ファイルである。既存の0.0.5の変更表の summary/help と CHANGELOG の0.0.5以下の章は保持する。0.0.6の summary/help は M6 の文言をそのまま本番へ接続する。新しい公開シグネチャ、診断コード、型・脱糖・Lean の規則は加えない。

元の作業ツリーで次を実行すると、通常入力を変更せずに全ハッシュの照合、順次適用、逆適用による元のバイト内容の復元を確認できる。

```sh
python3 -B docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/m6a/verify.py
```

M7 の検査ではこの検証を先に通し、同じ順で git apply を行う。gen_skill はソースを更新した後に再実行する。一時コピーで実行した今回の生成結果は既存の生成物と同一であり、生成物用のパッチはない。通常の検査からこの改造ディレクトリへの依存は加えていない。

## 入力の分類と保持する契約

| 入力の種類 | 確認結果 |
|---|---|
| Rust の通常/raw 文字列、format!/concat! | language の固定値を含む生成元と期待値を対応させた。package_command の `{MAIN}`、spec_examples の `{alias}`、desugar_export/named の依存、外部関数・型検査・モジュールの合成入力もパッチに含む。構築後の入力を既存の公開境界のテストで確認 |
| tests/runtime_builtins.rs | ファイル全体のハッシュを inventory に記録。language 宣言も固定パッケージハッシュもなく、既存の format! を含む入力を保持。元と適用後の両方で統合テストを実行 |
| tools の現在の参照解・生成器 | tools/bench の .bnt・生成器と tools/skill-eval/tasks/*/reference.bnt を含めて走査。版宣言の更新対象は0件。WIT の manifest は入力・生成物の SHA-256 であり、package hash ではない。今回のパッチでそれらの中身は変わらないため保持 |
| package.bnt と依存の控え | [packages.json](packages.json) に52設定と要約対象の全ファイルを記録。版宣言・依存の控え等の更新によって47パッケージの要約が変わる。Hashkit 以外は固定 hash の記録先がないため、新たな hash 欄は加えない |
| parser/header.rs と formatter/tests.rs の版 | 版の互換性を調べない構文の検査である。旧版、重複宣言、不正な位置の language をそのまま保持。これらの0.0.5は通常の読み込みへ渡す成功入力ではない |
| modules/package.rs の注入する版の表 | current と変更表を注入する M6 の境界検査を変更せず保持。旧版・未来・空の表・未整列の表の厳密な期待を維持 |
| 日本語文書冒頭の翻訳元の0.0.5 | 既存の訳の出典として保持。M8 で本文を訳し直すときに版も変更する。R81 を参照 |
| fuzz/Cargo.lock | benitoite の項目は変更前から0.0.1のままで、ワークスペースの0.0.5とも不一致。古い控えとして記録し、版だけを直して依存一覧の古さを隠さない。依存の再解決は今回の範囲外として申し送る。R81 を参照 |
| その他の版・64桁の値 | Cargo の依存の版/checksum、Hash.sha256 の既知値、Wasm コンポーネントの SHA-256、文字列の検査入力、過去の改名診断・規約の例を保持。Wasm の README 3件の SHA-256 は実ファイルとも一致 |

## 固定ハッシュの候補

固定値は本番の compute_hash を呼ばず、仕様06-09の「中身のハッシュ」に従って Python hashlib で計算した。ファイルの中身の要約をパス順に「SHA-256・空白二つ・相対パス・LF」として連結し、その要約の SHA-256 を求めた。[hashes.json](hashes.json) に入力の全相対パスと変更前後の SHA-256 がある。CRLF と非 UTF-8 の Wasm のバイトを保持した。

| 対象 | 更新前 | 更新後 | 記録先 |
|---|---|---|---|
| lib hash fixture | `sha256:a1b90227fd78ffd9f1ce24c6969a96511416e6f18571e480713a16e92f7b503f` | `sha256:3b02e3120f7e20f1c82b7c70dae26848f301edbb5988602795002a20d5c8b9b5` | `crates/benitoite/src/modules/hash.rs` |
| package command fixture | `sha256:eee08f30ef130c609237874eefd93d59e3338d58438294fb47dc24ec917cef4e` | `sha256:0e03d3fd2ac72afce915d04f076536efd301078c8e9f416bceb6b6f80b2219c7` | `crates/benitoite/tests/package_command.rs` |
| golden Hashkit | `sha256:ddac9d07ae2a12288b1ef3e5a4cbe36ae1d44a3991a1fc3f3b9e5d44a57da584` | `sha256:20e42f7da076ce5bd11f6f4a7b433f956e8f73e98f58cd279c8dc2aafbe09393` | `crates/benitoite/testdata/packages/hash-match/package.bnt`, `crates/benitoite/testdata/packages/hash-mismatch.diag.json` |

Hashkit の成功入力の hash と、不一致の診断の computed だけを更新する。不一致の入力と expected のゼロ64桁は維持し、成功入力へ変えない。参照文書のゼロ64桁は書式の例として保持する。

## 版・診断の期待値と維持先

| 入力・観測 | 適用後の厳密な期待 | 維持するもの |
|---|---|---|
| 宣言0.0.0・0.0.3・0.0.4 | E0908。主文の最初の変更は0.0.5。notes/help は0.0.5・0.0.6の2件を版順に全文比較 | modules/tests の入口・根の設定・依存の3位置。主位置は元の版文字列、help の置換は全件なし |
| 宣言0.0.5 | E0908。最初の変更は0.0.6、notes/help は0.0.6の1件 | 元の0.0.5の行を新しい境界の期待へ変更し、0.0.6の受理の行を残す |
| 宣言0.0.6 | 診断なし | 元の現在版の成功契約を新しい現在版で確認 |
| 宣言0.0.7 | E0907、主文全文、notes/help なし | 元の未来版の拒否を0.0.7へ進める。golden の99.0.0は入力を保持 |
| newer-language、newer-config、dependency-settings | E0907 の主文中の処理系の版だけ0.0.6へ | 99.0.0、位置、その他の診断、終了状態2を保持 |
| older-language | E0908、旧0.0.4の入力を保持し、notes/help に0.0.6の案内を1件ずつ追加 | 主文・主位置・副位置・コード・終了状態2、0.0.5の案内を保持。golden の JSON 全体で比較 |
| hash-mismatch | E0919、computed だけ新しい Hashkit の要約へ | expected のゼロ64桁、入力・主位置・コード・終了状態2を保持 |
| 不正な版・language の位置 | E0905 等の既存の構文診断 | parser/header.rs の不正・重複の全入力と assert を保持。golden の元の誤りも維持 |

0.0.6の変更表は M6 が固定した文言であり、die の改名、四つの型の包括的な分岐、record の制限、return の値を同じ物理行で書き始めた後の複数行の継続、明示tryと裸の意味、CHANGELOG の参照を含む。CHANGELOG のパッチにも同じ移行を記し、E0258・E0259・E0511の役割と、既存のhelpの変更を実際の診断表と照合した。

## test-audit の関門

1. 守る契約は、通常入力が新しい版でも元の仕事と期待結果を検査することと、版・内容ハッシュの境界で正しい診断を返すことである。主となる境界は既存のモジュール読み込みと package CLI・golden である。
2. 捕まえる退行は、通常用の依存設定の移行漏れによる E0908、固定ハッシュの更新漏れによる E0919、旧版の案内の欠落・重複・順序の誤り、負の入力を成功入力へ変えることである。
3. 既存の modules/tests の表へ新しい境界の行を加え、既存の厳密な比較と golden を更新する。新しい Rust テスト関数は作らない。元の全 assert を同じ観測のために保持し、help の全文と置換なしの確認は全該当項目のループへ拡張する。Rust 12ファイルすべてで assert マクロの数も変わらない。既存の ignore、対象件数、時間制限を変えない。
4. 本番にテスト専用の API、フラグ、ラッパー、引数を加えない。verify.py は今回の成果物を一時ディレクトリで照合する作業用の確認器であり、通常の検査から呼ばない。

今回のパッチはリリースによる仕様上の期待値の更新であり、処理系の不具合を修正するものではない。最初の一時コピーの検査で通常の依存設定10箇所の移行漏れを検出したときも、失敗した6テストの assert を保ち、入力の版だけをパッチに追加した。

## パッチのファイル別一覧

同じファイルが二つのパッチに現れる場合も、この一覧では一行とする。各行の元と適用後の内容のハッシュは manifest の同名の項目にある。

| 対象ファイル | 適用するパッチの順序 |
|---|---|
| [CHANGELOG.md](../../../CHANGELOG.md) | 1 |
| [Cargo.lock](../../../Cargo.lock) | 1 |
| [crates/benitoite/Cargo.toml](../../../crates/benitoite/Cargo.toml) | 1 |
| [crates/benitoite/src/cli/tools/package/tests.rs](../../../crates/benitoite/src/cli/tools/package/tests.rs) | 2 |
| [crates/benitoite/src/external/tests.rs](../../../crates/benitoite/src/external/tests.rs) | 2 |
| [crates/benitoite/src/modules/hash.rs](../../../crates/benitoite/src/modules/hash.rs) | 2, 3 |
| [crates/benitoite/src/modules/package.rs](../../../crates/benitoite/src/modules/package.rs) | 1 |
| [crates/benitoite/src/modules/tests.rs](../../../crates/benitoite/src/modules/tests.rs) | 2, 3 |
| [crates/benitoite/src/modules/text.rs](../../../crates/benitoite/src/modules/text.rs) | 1 |
| [crates/benitoite/src/typeck/pattern_ext.rs](../../../crates/benitoite/src/typeck/pattern_ext.rs) | 2 |
| [crates/benitoite/testdata/external/self-package-outside/package.bnt](../../../crates/benitoite/testdata/external/self-package-outside/package.bnt) | 2 |
| [crates/benitoite/testdata/external/self-package/package.bnt](../../../crates/benitoite/testdata/external/self-package/package.bnt) | 2 |
| [crates/benitoite/testdata/fmt/header.bnt](../../../crates/benitoite/testdata/fmt/header.bnt) | 2 |
| [crates/benitoite/testdata/fmt/header.formatted](../../../crates/benitoite/testdata/fmt/header.formatted) | 2 |
| [crates/benitoite/testdata/packages/alias-only/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/alias-only/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/config-declaration/package.bnt](../../../crates/benitoite/testdata/packages/config-declaration/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/config-textkit/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/config-textkit/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/copied-textkit/Textkit/package.bnt](../../../crates/benitoite/testdata/packages/copied-textkit/Textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/d6c-extensible-external/package.bnt](../../../crates/benitoite/testdata/packages/d6c-extensible-external/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/d6c-extensible-missing/package.bnt](../../../crates/benitoite/testdata/packages/d6c-extensible-missing/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/d8-extensible-run/package.bnt](../../../crates/benitoite/testdata/packages/d8-extensible-run/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/d8-extensible.files/dep/package.bnt](../../../crates/benitoite/testdata/packages/d8-extensible.files/dep/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/dependency-collision/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/dependency-collision/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/dependency-config-declaration/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/dependency-config-declaration/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/dependency-no-block/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/dependency-no-block/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/dependency-root-import/Textkit/package.bnt](../../../crates/benitoite/testdata/packages/dependency-root-import/Textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/dependency-root-overlap/package.bnt](../../../crates/benitoite/testdata/packages/dependency-root-overlap/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/dependency-settings.diag.json](../../../crates/benitoite/testdata/packages/dependency-settings.diag.json) | 3 |
| [crates/benitoite/testdata/packages/dependency-settings/deps/transitive/package.bnt](../../../crates/benitoite/testdata/packages/dependency-settings/deps/transitive/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/distinct-modules/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/distinct-modules/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/extensible.files/dep/package.bnt](../../../crates/benitoite/testdata/packages/extensible.files/dep/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/hash-match/deps/hashkit/package.bnt](../../../crates/benitoite/testdata/packages/hash-match/deps/hashkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/hash-match/package.bnt](../../../crates/benitoite/testdata/packages/hash-match/package.bnt) | 3 |
| [crates/benitoite/testdata/packages/hash-mismatch.diag.json](../../../crates/benitoite/testdata/packages/hash-mismatch.diag.json) | 3 |
| [crates/benitoite/testdata/packages/header-overlap/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/header-overlap/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/header-overlap/main.bnt](../../../crates/benitoite/testdata/packages/header-overlap/main.bnt) | 2 |
| [crates/benitoite/testdata/packages/header-overlap/package.bnt](../../../crates/benitoite/testdata/packages/header-overlap/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/header/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/header/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/header/main.bnt](../../../crates/benitoite/testdata/packages/header/main.bnt) | 2 |
| [crates/benitoite/testdata/packages/imported-header/Helper.bnt](../../../crates/benitoite/testdata/packages/imported-header/Helper.bnt) | 2 |
| [crates/benitoite/testdata/packages/imported-header/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/imported-header/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/libraries.files/fuzzy/package.bnt](../../../crates/benitoite/testdata/packages/libraries.files/fuzzy/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/libraries.files/json-checks/package.bnt](../../../crates/benitoite/testdata/packages/libraries.files/json-checks/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/libraries.files/pure-json/package.bnt](../../../crates/benitoite/testdata/packages/libraries.files/pure-json/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/libraries.files/textkit/package.bnt](../../../crates/benitoite/testdata/packages/libraries.files/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/libraries.files/wasm-hash/package.bnt](../../../crates/benitoite/testdata/packages/libraries.files/wasm-hash/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/libraries.files/wasm-json/package.bnt](../../../crates/benitoite/testdata/packages/libraries.files/wasm-json/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/libraries.files/wasm-regex/package.bnt](../../../crates/benitoite/testdata/packages/libraries.files/wasm-regex/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/local-textkit/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/local-textkit/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/newer-config.diag.json](../../../crates/benitoite/testdata/packages/newer-config.diag.json) | 3 |
| [crates/benitoite/testdata/packages/newer-language.diag.json](../../../crates/benitoite/testdata/packages/newer-language.diag.json) | 3 |
| [crates/benitoite/testdata/packages/older-language.diag.json](../../../crates/benitoite/testdata/packages/older-language.diag.json) | 3 |
| [crates/benitoite/testdata/packages/package-as-root/package.bnt](../../../crates/benitoite/testdata/packages/package-as-root/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/package-dependencies/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/package-dependencies/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/package-dependencies/package.bnt](../../../crates/benitoite/testdata/packages/package-dependencies/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/package-error/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/package-error/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt](../../../crates/benitoite/testdata/packages/package-header/deps/textkit/Slug.bnt) | 2 |
| [crates/benitoite/testdata/packages/package-header/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/package-header/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/package-isolation/deps/other/package.bnt](../../../crates/benitoite/testdata/packages/package-isolation/deps/other/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/package-isolation/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/package-isolation/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/package-private-name/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/package-private-name/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/package-visibility-hidden/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/package-visibility-hidden/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/package-visibility-run/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/package-visibility-run/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/package-warning/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/package-warning/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/root-config/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/root-config/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/root-config/package.bnt](../../../crates/benitoite/testdata/packages/root-config/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/root-fallback/deps/textkit/package.bnt](../../../crates/benitoite/testdata/packages/root-fallback/deps/textkit/package.bnt) | 2 |
| [crates/benitoite/testdata/packages/todo-handler/deps/todo/package.bnt](../../../crates/benitoite/testdata/packages/todo-handler/deps/todo/package.bnt) | 2 |
| [crates/benitoite/tests/desugar_export/named.rs](../../../crates/benitoite/tests/desugar_export/named.rs) | 2 |
| [crates/benitoite/tests/fmt_command.rs](../../../crates/benitoite/tests/fmt_command.rs) | 2 |
| [crates/benitoite/tests/package_command.rs](../../../crates/benitoite/tests/package_command.rs) | 2, 3 |
| [crates/benitoite/tests/spec_examples.rs](../../../crates/benitoite/tests/spec_examples.rs) | 2 |
| [crates/benitoite/tests/test_command.rs](../../../crates/benitoite/tests/test_command.rs) | 2 |
| [docs/design/01-spec/01-02-syntax.md](../../../docs/design/01-spec/01-02-syntax.md) | 2 |
| [docs/design/01-spec/01-03-names-modules.md](../../../docs/design/01-spec/01-03-names-modules.md) | 2 |
| [docs/design/06-tooling/06-09-packages.md](../../../docs/design/06-tooling/06-09-packages.md) | 2 |
| [docs/ja/reference/benitoite.md](../../../docs/ja/reference/benitoite.md) | 2 |
| [docs/ja/reference/install.md](../../../docs/ja/reference/install.md) | 2 |
| [docs/reference/benitoite.md](../../../docs/reference/benitoite.md) | 2 |
| [docs/reference/install.md](../../../docs/reference/install.md) | 2 |
