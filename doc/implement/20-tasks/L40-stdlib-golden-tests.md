# L40 標準ライブラリのゴールデンテスト

- 依存する作業: [L01](L01-unicode-functions.md)〜[L03](L03-bytes.md)、[L10](L10-console-clock-process.md)〜[L14](L14-random.md)、[L20](L20-path.md)〜[L25](L25-encoding-and-hash.md)、[C10](C10-golden-runner.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 大（テストのスクリプトと期待値が多い）
- ブランチ: impl/L40-stdlib-golden-tests

## 目的

[ADR 0137](../../design/decisions/0137-first-release-library-scope.md) が初回リリース版に入れた各モジュールの主な機能を、スクリプトとして確かめるゴールデンテストを、`stdlib` と `io` の区分に加える（07-03「ゴールデンテストの形式（初回リリース版）」）。組み込みの関数の意味は、項目ごとの単体テスト（L01〜L25）が確かめた。本作業は、利用者のスクリプトから、非公式のモジュールの取り込みの名前、型、エフェクト、関数の組み合わせが期待どおりに働くことを、CLI と同じ経路で確かめる。ネットワークの区分は L33 が書く。

## 読む設計書の節

- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「ゴールデンテスト」「ゴールデンテストの形式（初回リリース版）」「差分テスト」（どのテストが差分テストの対象になるか）、「テストの設計の原則」
- [標準ライブラリ](../../design/03-interop/03-06-stdlib.md)、[IO のモジュール](../../design/03-interop/03-07-io-modules.md)、[テキストとデータの処理](../../design/03-interop/03-08-text-and-data.md)（各章の例）
- [標準ライブラリ](../../design/03-interop/03-06-stdlib.md)の「標準のモジュールと非公式のモジュール（初回リリース版）」
- ADR: [0137](../../design/decisions/0137-first-release-library-scope.md)、[0224](../../design/decisions/0224-golden-test-format-for-first-release.md)、[0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の全体（ソースの宣言が、スクリプトから使える関数と型の一覧である）
- C10 の作業の文書（ゴールデンテストの形式と実行器、`.files/`・`.stdin`・`.args` のファイル、テストごとの一時ディレクトリ、回収の強制と差分テストの対象の選び方）

## 作るもの

- `crates/benitoite/testdata/stdlib/` と `testdata/io/` のゴールデンテスト

## 手順の要点

- モジュールごとに、少なくとも一つのテストを置く。03-06〜03-08 の章の例（`totalAmount`・`extractDates`・`fingerprint`・`countLines` など）は、非公式のモジュールの import を取り込みの名前（`import Benitoite.Unofficial.…`）に書き換えてテストにする（ADR 0286 の帰結）。
- 取り込みの名前: 非公式のモジュールを `import Benitoite.Json` と書いたスクリプトの `check` が E0321 と、正しい取り込みの名前への修正案を示すことを、`check` のテストとして置く（診断の文言は期待値として記録する）。標準のモジュール（`Bytes`・`Map` など）は import なしで使えること、`import Benitoite.Unofficial.Bytes` が E0321 になること。
- `io` の区分のテストは、C10 の実行器がテストごとに作る一時ディレクトリを基準のディレクトリとして走る（C10「実行の手順」の `working_directory`）。読むファイルは `.files/` に置き、実行器が一時ディレクトリに写したものを相対パスで読む。書くファイルも一時ディレクトリの中に相対パスで作る。並べて走らせても、テストどうしが干渉しない。出力に一時ディレクトリの絶対パス（`Process.workingDirectory`・`File.canonicalize` の値）をそのまま書かない。
- 外部コマンドのテストは、`/bin/sh` のような、対応環境（macOS と Linux）に必ずあるコマンドだけを使う。
- 実行のたびに値が変わる関数（`Clock.now`・`Random.integer` など）は、値そのものを出力しない。性質（範囲に入る、前後の関係）だけを出力するか、`handle` で値を固定する（01-07）。
- 差分テストの対象の選び方は C10 のとおりである（タスクを起動するテストと `.stdin` を持つテストは外れる）。対象に入るテストは、参照インタプリタと VM で同じ結果になる。

## 受け入れテスト

- `stdlib`: `Character`・`String` の Unicode の関数、`Map`・`Set` の関数（関数を引数にとる関数と `Trait` の実装を含む）、`Bytes`・`ByteOrder`、`Path`・`Json`・`Regex`（`replaceAllWith` を含む）・`Csv`・`Time`・`Encoding`・`Hash`、取り込みの名前の診断。
- `io`: `Console.readAllLines`・`readAllBytes`（`.stdin` のファイルで入力を与える）、`File` のファイルとディレクトリの操作とリソースの関数、`Process` の環境変数・作業ディレクトリ・`scriptDirectory`・外部コマンド、`Clock`、`Random`（`handle` で固定した値と、生成器の決まった列）。
- すべてのテストが、C10 の実行器で、二つのメモリの管理と回収の強制で通る。

## 完了条件

- `scripts/check.sh` が通る
- ADR 0137 の決定 2 の各モジュールに、少なくとも一つのテストがある
- `src/` を変えていない。処理系の不具合を見つけたら、直さずに完了の報告に書いている

## 確認の観点

- テストが、スクリプトの出力と終了状態だけを期待値にしているか（処理系の内部の値を読んでいないか。スキル `test-audit`）。
- 期待値が、設計書の例の値と一致しているか。今の処理系の出力を、確かめずに期待値にしていないか。
- 環境や実行の時刻によって結果が変わるテストがないか。

## 難易度の理由

書くのはスクリプトと期待値だけであり、仕組みは揃っている。量が多く、環境に依存しない書き方に注意が要る。
