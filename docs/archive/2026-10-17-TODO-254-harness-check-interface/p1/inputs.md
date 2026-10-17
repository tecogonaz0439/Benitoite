# P1 版・language・ハッシュ・環境設定の確認表

## 検索範囲と分類

[results.md](results.md) の HEAD の全追跡6,201項目を `git ls-files -z` から `xargs -0 rg --json -n` へ渡して検索した。無視された入力へ検索を広げず、版・language・ハッシュ・環境設定の四系統を別々に調べた。再実行するコマンドは次のとおりである。

```sh
git ls-files -z | xargs -0 rg --json -n -- '0\.0\.[0-9]+|CARGO_PKG_VERSION|benitoite-version'
git ls-files -z | xargs -0 rg --json -n -- '\blanguage\b'
git ls-files -z | xargs -0 rg --json -n -- 'sha256|SHA-256'
git ls-files -z | xargs -0 rg --json -n -- 'DYLD_|LD_[A-Za-z_*]|BENITOITE_BUILD_|BENITOITE_[A-Z_]+|Command\.environment|\.envs\(|env_clear|env_remove'
```

単語の一致には説明文・処理の識別子・IPv4・Wasm 内の文字列も含まれるので、一致件数を変更候補の件数とは扱わない。例えば `127.0.0.1` は版から除外する。パッケージの固定値、単一ソースのハッシュ、Wasm のチェックサム、測定入力のハッシュも区別する。バイナリは再生成が必要な根拠がない限り変更候補にしない。

補助検索は `rg -n 'language|environment:|environmentVariable|Process\.run|Process\.shell'`、固定64桁の十六進数の検索、全追跡 Markdown の fence の開始行の列挙である。後続作業はこの表を再検索の起点にする。P1 の一覧は版の更新パッチやハッシュの承認表そのものではなく、M2a でその時点の入力内容へ照合し直す。

| 分類 | 原則 | 主な担当 |
|---|---|---|
| 通常入力 | 現行版で元の仕事を検査する入力は0.0.7へ移す。他の誤りを検査する負のテストの準備も、不要な E0908 で遮らない | M2a/M2b |
| 旧版・未来版・不正版の検査 | 拒否する理由を保持。旧版は保持し、未来0.0.7は0.0.8以上へ、現行受理は0.0.7へ移す。期待値は全文と順を維持 | M1/M2a/M2b |
| 構文だけの例 | parser/fmt が版の意味を判定しない入力は綴りと整形の契約として保持できる | M2a で保持を確認 |
| 生成元 | 英語の手書き文書・構文章・診断表・標準ソースのコメントを先に変更 | C/A/E/D/M の各作業 |
| 生成物 | grammar/diagnostics/stdlib と bundle を gen_skill から再生成。手では直さない | 各生成元の変更と同時、D3/M2b |
| 歴史資料 | 過去の版・記録・計測条件を保持。実行用入力と混同しない | 原則変更なし |
| 今回の契約例 | design/harness-response の0.0.7や仮ハッシュは将来の契約の例。現行版の実行入力へ一律に置換しない | 実際の契約が変われば該当作業で整合 |

## 版と Rust の合成入力

以下の Rust のパスは `crates/benitoite/` からの相対パスである。

| ファイル・箇所 | 分類・更新/保持する理由 | 担当 |
|---|---|---|
| `Cargo.toml:3`、ルート `Cargo.lock` の benitoite 項目 | 公開版。通常入力と固定ハッシュの適用と同時に0.0.7へ上げる | M2b |
| `src/modules/package.rs`、`src/modules/text.rs` | BREAKING_CHANGES に0.0.7を登録。既存0.0.5/0.0.6の説明を新しい版へ置換せず、新しい案内を追加 | M1/M2b |
| `src/modules/tests.rs:25` の版境界の表 | 入口・設定・依存をすべて検査。現在0.0.6成功/0.0.7未来を、新しい現行・旧版・未来の境界へ対応させ、notes/helps と主文の全文比較を維持 | M2a/M2b |
| `src/modules/package.rs:343,368` の版解析・注入した current/changes | `1.10.2`・上限・不正文字列、注入版の検査は独立した契約として保持。実際の BREAKING_CHANGES を読む期待値だけ追加の項目を厳密に反映 | M1/M2a/M2b |
| `src/modules/tests.rs:872` 以降の設定・依存入力 | 通常の0.0.6は更新。850行付近の99.0.0は未来の拒否を保持。100行付近のゼロのハッシュと path 欠落の検査は保持 | M2a/M2b |
| `src/modules/hash.rs:221–222` | 通常の CONFIG と正の FIXED を一緒に更新。固定値の所在は R12 を参照 | M2a/M2b |
| `src/external/tests.rs:1612,1754,1778` | 通常の依存パッケージの0.0.6を更新。外部関数の誤りを言語版の誤りへ変えない | M2a/M2b |
| `src/typeck/pattern_ext.rs:865` | 通常の依存の0.0.6を更新。extensible の契約まで検査を到達させる | M2a/M2b |
| `src/cli/tools/package/tests.rs:36,40,91,95` | ヘッダの移動・保持の入力と期待値。通常版の更新候補として一対で確認。BOM/改行/コメントの契約を保つ | M2a/M2b |
| `tests/package_command.rs:18,114,192,219,274,275,400,405,407,452,463` | CONFIG、format! の生成元と確認用文字列、操作出力、固定値を一単位で更新。正の依存を旧版の拒否へ変えない | M2a/M2b |
| `tests/desugar_export/named.rs:589,594`、`tests/spec_examples.rs:454`、`tests/test_command.rs:767,778` | 合成する入口・依存・package.bnt の0.0.6を更新 | M2a/M2b |
| `tests/runtime_builtins.rs` | 版/language の固定リテラルは現状なしと確認。実行用の Rust 文字列を検索対象から外さない。前回の構文移行漏れを理由に今回無関係な変更はしない | M2a/M2b/F1 の全ターゲット |
| `src/syntax/parser/header.rs:350` 以降、`src/cli/tools/formatter/tests.rs:408` | 0.0.5/0.0.2等は位置・二重宣言・配置・解析回復の検査。互換性検査を呼ばないため保持 | M2a |
| `testdata/fmt/header.bnt`・`header.formatted`、`tests/fmt_command.rs:479,485` | 0.0.6の綴りを整形の入力/期待値として保持。fmt は言語版の意味を検査しない | M2a |
| `src/cli/mod.rs:313`、`tests/cli_process.rs:79` | CARGO_PKG_VERSION を使う既存表示と厳密な二行の期待値を保持。0.0.7のハードコードを増やさない | V2/M2b |
| `src/cli/tools/skill/{mod,tests}.rs`、`tests/skill_docs.rs:241` | 版の置換・metadata の識別・placeholder の保持を検査。`1`・`benitoite-versions` の負の入力を現行版へ置換しない | S1/S2/M2a |
| `src/diag/codes.rs`、`src/runtime/report.rs`、names の renamed の期待値 | 0.0.1での改名・導入や `0.0.3` の版の書式例を保持。今回の現在版を示す数字ではない | M2a、E0512 は A1 |

## testdata の language 宣言

`testdata/packages/` の0.0.6の宣言は、別の誤りを検査する入力も含めて通常入力の準備として更新する。完全な候補パスは本書末尾に列挙する。単に package.bnt のうち成功例だけを更新すると、別理由での拒否やハッシュの不一致を生むためである。

| 入力・期待値 | 判断 | 担当 |
|---|---|---|
| `packages/older-language/main.bnt` | language 0.0.4 は E0908 の負の入力として保持。対応する older-language.diag.json は0.0.7の note/help を追加し、既存の項目と順を維持 | M2b |
| `packages/newer-language/main.bnt`、`newer-config/package.bnt`、`dependency-settings/deps/future/package.bnt` | 99.0.0 は未来版の拒否として保持。対応する3つの .diag.json 内の現在の処理系0.0.6だけを0.0.7へ更新 | M2b |
| `packages/package-language-required`、`header-overlap`、`config-declaration`、`dependency-config-declaration`、`package-header`、`imported-header` | 必須宣言なし・重複・設定内の宣言禁止・import先のヘッダ禁止の理由を保持。含まれる通常版だけを更新し、位置・診断の追加/欠落も照合 | M2a/M2b |
| `testdata/external/self-package{,-outside}/package.bnt` | 通常の依存パッケージとして更新。Wasm バイナリの作り直しを伴うと推測しない | M2a/M2b |

## 固定ハッシュの対応

| 所在 | 何のバイト列か・現在値 | 更新/保持の条件 |
|---|---|---|
| `testdata/packages/hash-match/package.bnt:3` | deps/hashkit のパッケージ。`sha256:20e42f7da076ce5bd11f6f4a7b433f956e8f73e98f58cd279c8dc2aafbe09393` | deps/hashkit/package.bnt の版を変えるので再計算（M2a/M2b） |
| `src/modules/hash.rs:221` | fixture() の CONFIG を含むパッケージ。`sha256:3b02e3120f7e20f1c82b7c70dae26848f301edbb5988602795002a20d5c8b9b5` | CONFIG の版と一緒に再計算。CRLF・非UTF-8の wasm/x.wasm も含める（R12、M2a/M2b） |
| `tests/package_command.rs:114` | CONFIG を含む依存 Words の操作出力。`sha256:0e03d3fd2ac72afce915d04f076536efd301078c8e9f416bceb6b6f80b2219c7` | テストが構築するファイル全件を対象に再計算（M2a/M2b） |
| `testdata/packages/hash-mismatch/main.bnt`、`src/modules/tests.rs:100`、`modules/hash.rs:417` | 意図したゼロの不一致値・欠落入力 | ゼロを正しい値へ置換しない。E0919 や path 欠落の拒否を保持 |
| `src/cli/tools/package/tests.rs` の a/b の繰り返し、parser の64桁 | ヘッダの書き換え・ハッシュ文字列の構文の検査 | 内容の正当性を証明する固定値ではないため保持 |
| `testdata/packages/libraries.files/*/README.md`、`tools/bench/wasm*`、`tools/bench/wit-transfer/` | Wasm バイナリや測定入力のハッシュ | 今回バイナリを変えないため保持。ハッシュAPIの参照名や hashlib の実装を版の移行対象にしない |
| design/harness-response の contentHash | 単一ソースまたは置換後の文書の SHA-256。例示用ゼロ/空本文を含む | 実パッケージのハッシュと区別。仮データを実ファイルの計算結果と扱わない |

パッケージの計算は `src/modules/hash.rs::hash_files` の契約に従う。対象パスをUTF-8のバイト順に並べ、各ファイルの SHA-256 小文字十六進、半角空白二つ、相対パス、LF の連結をさらに SHA-256 にする。M2a/M2b は入力を決めてから Python hashlib で独立に検算する。P1 では新しい値を作らず、変更後の確認表を承認済みとは扱わない。

## 文書・生成元・生成物・実行用 fence

| 対象 | 分類と判断 | 担当 |
|---|---|---|
| `docs/design/01-spec/01-02-syntax.md:454`、`06-tooling/06-09-packages.md:20,32,41`、`01-spec/01-03-names-modules.md:278` | 現在版の例・互換性表を更新。01-spec に CLI の JSON の実装事情を入れない | M1/M2b、spec_examples |
| `docs/reference/benitoite.md`・`install.md` | 現在版の説明・三つの language 例・版表示・配布名を更新。ソースのみの配布という現実を保つ | D2a/M2b |
| `crates/benitoite/skill/SKILL.md`・手書き references | placeholder は保持し、検査報告・上限・環境制約の使い方を追記。現在のコード例も本番の検査へ通す | D2b/D3/M2b |
| `examples/gen_skill.rs` と `examples/skill_support/`、構文章、diag::codes、Process.bnt のコメント | 生成元。E0512・文法・標準ライブラリの説明を変更する作業で生成し直す | A1/E1/D2b/D3/M2b |
| Skill の `references/grammar.md`・`diagnostics.md`・`stdlib/*.md`、`src/cli/tools/skill/bundle.rs` | 生成物。0.0.1の改名説明・版の構文例・Hash.sha256 の仕様は保持し、変更した生成元に従う | 各生成元の変更と同時 |
| `docs/ja/reference/{benitoite,install}.md`、`docs/ja/skill/SKILL.md`、`docs/ja/skill/references/{common-mistakes,idioms,language-comparison}.md` | 訳6組。英語が確定してから版・表・コード・終了状態を照合して訳し直す。Skill の配布に含めない | M3a/M3b |
| `CHANGELOG.md` | 既存0.0.6以前は履歴として保持。Unreleasedを新設して六機能・破壊・移行を記し、最後に0.0.7へ改題 | M1/M2b |
| Markdown の `benitoite test` fence | 現行範囲8件。Skill/SKILL.mdが1、idioms.mdが2、英語referenceが1、日本語の対応文書が計4。実行用の入力であり、記法の例だけと分類しない | D2a/D2b/D3/M2a/M2b/M3b |
| その他の `benitoite` fence | 成功・失敗・run/check/test・imports等の指定を各実行器が読む。ラベルと期待結果を保持 | spec_examples/reference_examples/skill_examples/skill_docs |
| `tools/skill-eval/tasks/*/reference.bnt` 全11本 | 現状 language の固定宣言なし。process_run は LC_ALL=C、process_shell は shell、http_client は SKILL_EVAL_HTTP_BASE を使用し、禁止接頭辞の明示設定はなし。参照解を検索対象から外さず、今回は更新不要 | M2a/F1、LLM を呼ぶ評価は行わない |
| `tools/bench/` の実行入力、`tools/skill-eval/skill_eval.py` | 現在の実行用入力と版/Skillを読む道具。版の宣言の更新箇所は今回見つからない。記録用のハッシュとメタデータ取得は保持 | M2a/F1 |

## 環境設定とビルドの候補

| 対象 | 分類・判断 | 担当 |
|---|---|---|
| 新規 `crates/benitoite/build.rs`、後の `src/cli/build_info.rs` | BENITOITE_BUILD_COMMIT/DIRTY と埋め込み変数は未実装。明示値の検証、Gitの根・監視・由来を実際に使う作業で追加 | V1a/V1b/V2 |
| `src/builtins/funcs/process.rs::execute` と `process/external_tests.rs` | 明示環境の NUL/空名/`=` 検査の後、spawn の前で二接頭辞を拒否。既存の通常環境の検査に拒否・非起動・値の非開示の対照を加える | E1 |
| `src/prelude/stdlib/IO/Process.bnt`、`docs/design/03-interop/03-07-io-modules.md`、Skill の IO.Process.md | 型の五欄を保ち、environment の説明と InvalidInput・継承の限界を更新。Skill は生成する | E1/D1/D2b |
| `testdata/io/l40-process-environment.bnt`、`tests/l10_console_clock_process.rs`・`l13_external_commands.rs`、手書き idioms | 環境を読む契約、通常の追加/上書き等を保持。禁止名を黙って削除する入力へ変更しない | E1/D2b/F1 |
| CLI/tests/runtime の BENITOITE_DEV_PANIC・BENITOITE_DEV_IO_MODE・BENITOITE_DEV_ALLOC_STATS | 既存の開発用設定・実行経路の検査として保持。build の変数や新しいテスト専用フラグへ流用しない | C/T/V/P2 |
| `scripts/`、tools のハーネス・測定用の環境設定 | 処理系の Command.environment の入力とは区別して保持。親の PATH/HOME 等を変更しない | V1 の子プロセスの環境分離だけ実施 |

## 意図して残す資料と範囲外

| 対象 | 保持する理由 |
|---|---|
| `docs/archive/`（追跡1,598項目） | 読み取り専用の過去資料。前回の plan/results/reviews は漏れの経緯だけを参照し、現在の仕様の根拠にしない |
| `reference/`（追跡0項目） | 会話用の読み取り専用資料。変更候補や成果物からの依存先にしない |
| `tools/bench/results/`（149項目）・`tools/skill-eval/results/`（20項目）・`tools/syntax-measure/results/`（8項目） | 測定時の版・ソースハッシュ・環境を保持 |
| `tools/syntax-measure/{template,variants,tasks}/` | 第一段階の構文比較の入力・生成元・生成物。現行Skillの例ではないため、一律に現行の記法や版へ移行しない |
| `docs/reference/benitoite-minimal.md` | 最小実行版の範囲を明示した資料。現行リファレンスの更新と区別 |
| `AGENTS.md`、ロードマップ・用語集・設計目次・配布章等の初回0.0.1、resolverの改名0.0.1、formal READMEの0.0.2 | リリースの履歴・概念・過去の不具合の記述であり、現在版の例ではない。今回変更しない |
| `.claude/skills/archive-and-bundle/` と `.agents/skills/` のリンク | アーカイブ名・既存タグの例。リリース番号の一律置換をしない |
| `fuzz/Cargo.toml` の0.0.0と `fuzz/Cargo.lock` のbenitoite 0.0.1 | 前者は別クレート自身の版、後者は既存の古い依存の控え。数字だけ更新せず、依存の再解決は別作業とする |
| `tools/named-arguments-migrate/README.md` とその基準参照 | 旧移行器の基準データ依存の既知の残件。P1で旧検査の成功を主張せず、TODO-253の解消も行わない |
| 今回の request/answers/study、Qの検討時の例 | 原文・調査・判断の経緯を保持。R2等で置き換えた案は現行の実装指示と区別する |
| `design.md`・`harness-response.md` | 今回の契約例。0.0.7は予定版、例示のハッシュは仮データである。実装中に契約が変わる場合だけ同時に直す |

## 前回の漏れと今回の担当

前回の記録は `docs/archive/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/` の plan/results/reviews を読んだ。以下は経緯の対応であり、前回の計画を現在の規範として再利用するものではない。

| 経緯 | 今回の担当と確認 |
|---|---|
| G1/G3 の章・診断説明のずれ | 各実装で現行設計も更新し、D1で横断照合 |
| G3/G5 の個別検査と段末検査の混同 | K6/K7、段末表、F1。今回依頼された check/gc-stress の分担も results に未実施として明記 |
| G5b の読み込みの退行 | C1/C3/T1 の一度の検査・段内の破棄を保持。既知の失敗扱いにせず変更前後で再現 |
| G6 の別名禁止と手本/helpの矛盾 | C3、D1/D2a/D2bで有効な別名と禁止された別名を対照 |
| G7 の実行用 fence の分類漏れ、旧移行器の未達 | 上の8件の fence を実行用として扱い、D/Mで照合。旧移行器の残件は今回の成功と分ける |
| 全ターゲットの runtime_builtins の旧入力 | 本書の Rust 入力表、M2a/M2b、C3/A4/M2b/F1で両構成の全ターゲットを確認 |
| G8 の固定ハッシュ・版境界・CHANGELOG・訳 | M1、M2a/M2b、M3a/M3b/F1。R12の固定値を含め、三組を独立に計算し、全文/全件の比較を保つ |
| check.sh の Python 自己検査の接続範囲 | V1a/V1bの実ビルドは長いRustテストへ登録し、V2でも名指し。F1で実際の呼び出しを照合 |

## 通常入力の宣言を更新する testdata の全パス

次表は開始時の `language "0.0.6"` を持つ .bnt のうち、fmt専用の入力を除いた50ファイルである。パスは `crates/benitoite/testdata/` からの相対パス。全行の担当は M2a/M2b、理由は上の「通常入力」である。旧版・未来版・宣言なしの検査は上の別表で保持する。不正なUTF-8を検査する .bnt も存在するため、この列挙は元のバイト列の検索で行った。

| パス | 開始時の行 |
|---|---|
| `external/self-package-outside/package.bnt` | 1 |
| `external/self-package/package.bnt` | 1 |
| `packages/alias-only/deps/textkit/package.bnt` | 1 |
| `packages/config-declaration/package.bnt` | 1 |
| `packages/config-textkit/deps/textkit/package.bnt` | 1 |
| `packages/copied-textkit/Textkit/package.bnt` | 1 |
| `packages/d6c-extensible-external/package.bnt` | 1 |
| `packages/d6c-extensible-missing/package.bnt` | 1 |
| `packages/d8-extensible-run/package.bnt` | 1 |
| `packages/d8-extensible.files/dep/package.bnt` | 1 |
| `packages/dependency-collision/deps/textkit/package.bnt` | 1 |
| `packages/dependency-config-declaration/deps/textkit/package.bnt` | 1 |
| `packages/dependency-no-block/deps/textkit/package.bnt` | 1 |
| `packages/dependency-root-import/Textkit/package.bnt` | 1 |
| `packages/dependency-root-overlap/package.bnt` | 1 |
| `packages/dependency-settings/deps/transitive/package.bnt` | 1 |
| `packages/distinct-modules/deps/textkit/package.bnt` | 1 |
| `packages/extensible.files/dep/package.bnt` | 1 |
| `packages/hash-match/deps/hashkit/package.bnt` | 1 |
| `packages/header-overlap/deps/textkit/package.bnt` | 1 |
| `packages/header-overlap/main.bnt` | 3 |
| `packages/header-overlap/package.bnt` | 1 |
| `packages/header/deps/textkit/package.bnt` | 1 |
| `packages/header/main.bnt` | 3 |
| `packages/imported-header/Helper.bnt` | 1 |
| `packages/imported-header/deps/textkit/package.bnt` | 1 |
| `packages/libraries.files/fuzzy/package.bnt` | 1 |
| `packages/libraries.files/json-checks/package.bnt` | 1 |
| `packages/libraries.files/pure-json/package.bnt` | 1 |
| `packages/libraries.files/textkit/package.bnt` | 1 |
| `packages/libraries.files/wasm-hash/package.bnt` | 1 |
| `packages/libraries.files/wasm-json/package.bnt` | 1 |
| `packages/libraries.files/wasm-regex/package.bnt` | 1 |
| `packages/local-textkit/deps/textkit/package.bnt` | 1 |
| `packages/package-as-root/package.bnt` | 1 |
| `packages/package-dependencies/deps/textkit/package.bnt` | 1 |
| `packages/package-dependencies/package.bnt` | 1 |
| `packages/package-error/deps/textkit/package.bnt` | 1 |
| `packages/package-header/deps/textkit/Slug.bnt` | 1 |
| `packages/package-header/deps/textkit/package.bnt` | 1 |
| `packages/package-isolation/deps/other/package.bnt` | 1 |
| `packages/package-isolation/deps/textkit/package.bnt` | 1 |
| `packages/package-private-name/deps/textkit/package.bnt` | 1 |
| `packages/package-visibility-hidden/deps/textkit/package.bnt` | 1 |
| `packages/package-visibility-run/deps/textkit/package.bnt` | 1 |
| `packages/package-warning/deps/textkit/package.bnt` | 1 |
| `packages/root-config/deps/textkit/package.bnt` | 1 |
| `packages/root-config/package.bnt` | 1 |
| `packages/root-fallback/deps/textkit/package.bnt` | 1 |
| `packages/todo-handler/deps/todo/package.bnt` | 1 |
