# D21 手で書く Skill の文書と、載せたコードの例の検査

- 依存する作業: [D20](D20-skill-generation.md), [D12](D12-test-golden.md), L33, L40
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（500〜1500 行。文書を含む）
- ブランチ: impl/D21-skill-docs

## 目的

同梱の Agent Skill の手で書く文書（`SKILL.md`、イディオム集、よくある誤り集、既知の言語との対応表）を英語で書き、載せたコードの例をゴールデンテストと同じ仕組みで検査する（06-06「同梱の Agent Skill の構成」、ADR 0229 の決定 4、ADR 0231、ADR 0249）。

イディオム集は、ファイル・JSON・CSV・外部コマンド・HTTP・テストの書き方を載せるので、標準ライブラリの作業（L33・L40）と `test` の方式（D12）の後に書く。例が実際に動くことを確かめながら書くためである。

## 読む設計書の節

- [Agent Skills 対応](../../design/06-tooling/06-06-agent-skills.md): 全体（特に「同梱の Agent Skill の構成」の `SKILL.md` に書くもの、「実行の前の確認」）
- [構文](../../design/01-spec/01-02-syntax.md)、[エフェクト](../../design/01-spec/01-07-effects.md) の組み込みのエフェクトの表
- [付録の構文の比較](../../design/08-appendix/08-04-fp-syntax-comparison.md)（既知の言語との対応表の材料）
- [IO のモジュール](../../design/03-interop/03-07-io-modules.md)、[テキストとデータの処理](../../design/03-interop/03-08-text-and-data.md)、[ネットワークのモジュール](../../design/03-interop/03-09-network.md)、[利用者プログラムのテスト](../../design/06-tooling/06-04-test-runner.md)
- [ADR 0229](../../design/decisions/0229-bundled-skill-contents-and-japanese-translations.md)、[ADR 0231](../../design/decisions/0231-skill-shows-main-effects-before-running.md)、[ADR 0243](../../design/decisions/0243-signal-exit-code-and-posix-shell.md)、[ADR 0249](../../design/decisions/0249-skill-test-procedure-without-check.md)、[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)
- インターフェース: [10-19](../10-interfaces/10-19-skill-and-distribution.md) の「Skill のファイルの置き場所」

## 作るもの

パスは処理系のクレート `crates/benitoite/` からの相対パスである。

- `skill/SKILL.md`: 06-06 の「`SKILL.md` に書くもの」の 1〜4、実行の前の確認の手順（ADR 0231）、組み込みのエフェクトごとの利用者に示す言葉の対応表、`Process.shell` を POSIX の sh の範囲で書くこと（ADR 0243）。500 行より短くする（06-06「前提」）。前付けは D20 が置いた形を保つ。
- `skill/references/idioms.md`・`common-mistakes.md`・`language-comparison.md`。
- `tests/skill_examples.rs`: 上の文書のコードの例の検査。
- 生成の道具を実行し直した `src/cli/tools/skill/bundle.rs`（ファイルの一覧が変わらなければ変わらない）。

## 手順の要点

1. コードの例の書き方を次のように決め、各文書の先頭のコメント（HTML のコメント `<!-- … -->`）に書く。検査の対象は、情報文字列が `benitoite` のコードブロックである。
   - 直後に情報文字列が `output` のコードブロックがあれば、`run` して標準出力を比べる。`exit N` の行を置けば終了状態も比べる（なければ 0）。
   - 情報文字列が `benitoite check` なら、`check` だけを行い、誤りがないことを確かめる。
   - 情報文字列が `benitoite test` なら、`test` を行い、すべてのテストが成功することを確かめる。
   - 情報文字列が `benitoite error` なら、よくある誤り集の誤りの例として、`check` が誤りを報告することと、続く `diagnostic` のコードブロックに書いたコード（`E0201` など）が報告に含まれることを確かめる。
   - `text` などほかの情報文字列のブロックは検査しない（シェルの例など）。
2. `tests/skill_examples.rs` は、`skill/SKILL.md` と `skill/references/` の手で書く三つの文書を読み、例ごとに一時ディレクトリに `main.bnt` を置いて `cli::execute` で実行する（ゴールデンテストの実行器と同じく、出力先は `Capture`、標準入力は空、`color` は偽）。ファイルを読む例は、例の前の `files` のコードブロック（`name: <名前>` の行と内容）で一時ディレクトリにファイルを置く。HTTP の例は、ループバックの通信で完結するものだけを置く（07-03「HTTP のテスト（初回リリース版）」）。外部コマンドの例は `echo` など POSIX の環境にあるものだけを使う。
3. 失敗の一覧に、文書のパス、例の行番号、期待との差を示す。
4. 例は、非公式のモジュールを取り込みの名前（`import Benitoite.Unofficial.IO.File`）で書く（06-06「`SKILL.md` に書くもの」の 2、ADR 0286）。
5. 書き終えたら、生成の道具（`cargo run -p benitoite --example gen_skill`）を実行し、`tests/skill_docs.rs` が通ることを確かめる。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| 例の検査 | すべての例が通る。例の出力を 1 文字変えると失敗し、文書と行番号が示される（手で確かめ、完了の報告に書く） |
| `SKILL.md` | 06-06 の 1〜4 と実行の前の確認の手順を含み、500 行より短い。参照の文書の一覧が、`skill/references/` のファイルと一致する |
| イディオム集 | ファイルの読み書き、JSON、CSV、外部コマンドの起動（`Process.run` と `Process.shell`）、HTTP（サーバとクライアント）、テストの書き方（組み込みの操作をハンドラで差し替える例を含む）の例が、それぞれ一つ以上ある |
| よくある誤り集 | ほかの言語の書き方（`let`、波括弧のブロック、`==`・`&&`、戻り値の型の `:`、修飾しない構成子、IO のモジュールの import の忘れ、非公式のモジュールを `Benitoite.X` で取り込むこと）の誤りの例と、正しい書き方の例がある |
| 対応表 | Python・JavaScript・Rust などの構文と関数に対する Benitoite の書き方が並ぶ |

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」。例の検査と古くないことのテストを含む）
- 受け入れテストのすべての場合を確かめるテストか確認の記録がある

## 難易度の理由

文書を書き、例を実際に動かして確かめる作業である。検査の仕組みはゴールデンテストの実行器と同じ公開の関数を呼ぶ。
