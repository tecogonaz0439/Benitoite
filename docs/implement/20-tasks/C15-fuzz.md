# C15 fuzzing を初回リリース版のパイプラインに移して広げる

- 依存する作業: [F18](F18-pipeline-cli.md)、[F19](F19-escape-result-type.md)（`compile_ok` が種の入力 `first-release-with.bnt` で見つけた不具合を F19 が直す。F19 の前に始めると `fuzz-short.sh` がそこで止まる）
- 難易度: 3（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/C15-fuzz

## 目的

最小実行版の fuzzing の三つの対象（`fuzz/fuzz_targets/` の `check_bytes`・`check_mutated`・`compile_ok`）は、C18 が初回リリース版のパイプライン（[10-13](../10-interfaces/10-13-pipeline-and-cli.md)）に移した（下の三つの性質と検査の選択肢を満たしている）。本作業は、07-03 が初回リリース版で加えるとした対象のうち、モジュールの読み込み（複数のファイルからなる入力）を加える（[処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「fuzzing」）。フォーマッタの対象は U4 が加える。

## 読む設計書の節

- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md): 「fuzzing」「テストの設計の原則」の退行テスト
- [パイプライン](../../design/02-impl/02-01-pipeline.md): 「誤りが見つかったときの段の進め方」
- [名前解決とモジュール読込](../../design/02-impl/02-04-resolver.md): 「モジュールの探し方」「依存グラフと循環の検出」
- [ソース管理と位置情報](../../design/02-impl/02-02-source-and-spans.md): 「span」「ソースとファイル ID」
- [ADR 0003](../../design/decisions/0003-license.md)
- インターフェース: [10-13](../10-interfaces/10-13-pipeline-and-cli.md) の `pipeline::check_text`・`check_files`・`desugar_checked`・`compile`・`CheckOptions`、[10-06](../10-interfaces/10-06-ir.md) の `ir::check::check_program`、[10-02](../10-interfaces/10-02-diagnostics.md) の `Diagnostic` と `ReportKind`
- 既存の `fuzz/README.md`、`scripts/fuzz-seed.sh`、`scripts/fuzz-short.sh`

## 作るもの

パスはリポジトリの根からの相対パスである。

| ファイル | 変更 |
|---|---|
| `fuzz/fuzz_targets/check_bytes.rs`・`check_mutated.rs`・`compile_ok.rs` | C18 で移し済みなので、原則として変えない。`check_modules` と共通の補助（性質の検査）を切り出すなら変えてよい |
| `fuzz/fuzz_targets/check_modules.rs` | 加える（複数のファイルからなる入力） |
| `fuzz/Cargo.toml` | `check_modules` の `[[bin]]` を加える。依存は変えない（`libfuzzer-sys` の版を上げない） |
| `scripts/fuzz-seed.sh` | ディレクトリのテストを `check_modules` の種の入力にする処理を加える |
| `scripts/fuzz-short.sh` | 四つの対象を 60 秒ずつ実行する。一つの対象が不具合を見つけても残りの対象を実行し、最後に不具合を見つけた対象の一覧を示して 0 以外の終了状態を返す |
| `fuzz/README.md` | 対象の一覧と、`check_modules` の入力の形を書く |

`fuzz/` の対象を `legacy` から移すことは C18 が済ませた（今の `fuzz/` は `legacy` を参照しない）。

## 手順の要点

### 性質

07-03「fuzzing」の三つの性質を確かめる。性質が破れたら `panic!` で知らせる（`fuzz/` はワークスペースの外にあり、lint の表を引き継がない。最小実行版と同じ扱い）。

1. 検査が処理系の不具合を起こさない: Rust の panic がなく、`ReportKind::Internal` の報告がない。
2. すべての診断の主な位置と補助の位置の span について、ファイルがソースの表にあり、`start <= end <= 内容の長さ` である。
3. 検査に誤りがなければ、`desugar_checked` が `Ok` を返し、`check_program` が空の並びを返し、`compile` が `Ok` か `CompileError::Limit` を返す（`Internal` は不具合）。

検査の選択肢は、`require_main` を真、`deny_warnings` を偽とする（CLI の `check` と同じ）。

### 対象

| 対象 | 入力 | 性質 |
|---|---|---|
| `check_bytes` | 任意のバイト列を一つのファイルとして `check_text("fuzz.bnt", data, opts)` に与える | 1・2 |
| `check_mutated` | `check_bytes` と同じ。種の入力は既存のテストのスクリプト | 1・2 |
| `compile_ok` | `check_mutated` と同じ | 1・2・3 |
| `check_modules` | 入力を複数のファイルに分けて `check_files` に与える（下記） | 1・2・3 |

`check_modules` の入力の形は、次のとおりとする（【新しい決定】）。libfuzzer の変形で壊れにくく、`Arbitrary` のクレートを加えずに済む形である。

- 入力をバイト 0x00 で区切り、最大 6 個の断片に分ける（7 個目より後は捨てる）。
- i 番目の断片を、固定のパスの表の i 番目のファイルの内容とする。表は `main.bnt`・`Lib/Text.bnt`・`Lib/Geometry/Shape.bnt`・`Util.bnt`・`Lib/Deep/Inner.bnt`・`util.bnt` とする（3 番目は、既存のディレクトリのテスト `modules/f05_imports` を種にできるようにするため）（最後の二つは、入れ子のディレクトリと、大文字と小文字だけが違う名前を試すため。02-04「モジュールの探し方」）。
- 最初の断片（`main.bnt`）が実行を始めるファイルである（`check_files` の規則）。`main.bnt` 以外の空の断片は、ファイルを置かない（存在しないモジュールの import を試せるようにする）。`main.bnt` は空でも置く。種の入力で途中のファイルがない場合は、空の断片（0x00 を続ける）で位置を合わせる。

### 種の入力

- `scripts/fuzz-seed.sh` は、`crates/benitoite/testdata/` の `.bnt`（`<名前>.files/` の中を除く）を `check_mutated` と `compile_ok` の種の入力に写す（最小実行版のとおり）。加えて、ディレクトリのテスト（`<名前>/main.bnt` を持つディレクトリ）ごとに、中の `.bnt` を上の固定のパスに当てはめられるものだけ 0x00 で連結し、`check_modules` の種の入力にする。当てはまらないディレクトリは飛ばし、飛ばした数を示す。

### 見つけた不具合

見つけた不具合は、本作業の範囲では直さない。不具合を見つけた対象があっても、`fuzz-short.sh` は残りの対象を 60 秒ずつ実行するので、受け入れテストの「四つの対象をそれぞれ 60 秒実行する」は対象ごとの実行で判定してよい。対象と入力の置き場所（`fuzz/artifacts/`）を完了の報告に書き、該当する作業の不具合として報告する。直した後の退行テストは、持ち主の境界（その段の単体テストかゴールデンテスト）に置く（07-03「テストの設計の原則」の退行テスト）。

## 受け入れテスト

- `scripts/fuzz-short.sh` が、四つの対象をそれぞれ 60 秒実行する。
- `check_bytes` に次の手で作った入力を与えて、性質の検査が働くことを確かめる: 空の入力、正しくない UTF-8 だけの入力、1001 段の括弧の入れ子、閉じていない文字列リテラルで終わる入力、シェバンの行だけの入力。`cargo +nightly fuzz run check_bytes <入力のファイル>` で一件ずつ実行できる。
- `check_modules` に次の入力を与えて、性質の検査を通ることを確かめる: `main.bnt` が `Lib.Text` を import し、`Lib/Text.bnt` が `Lib.Geometry.Shape` を、`Lib/Geometry/Shape.bnt` が `Lib.Text` を import する入力（循環する import）、`main.bnt` が存在しないモジュールを import する入力、`util.bnt` と `Util.bnt` の両方を持つ入力。
- `compile_ok` と `check_modules` を、検査を通るスクリプト（`testdata/` の `run` のテストの一つと、ディレクトリのテストの一つ）で実行すると、性質の検査を通る。
- `grep` で、`fuzz/` の下に `legacy` の参照がないこと（C18 の後の退行がないこと）を確かめる。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）。`fuzz/` はワークスペースの外なので、check.sh の結果に影響しないことも確かめる
- 受け入れテストのすべての場合を確かめ、完了の報告に結果を書く
- nightly の Rust と cargo-fuzz がない環境では、`fuzz-short.sh` が導入の案内で止まったことを報告し、`check.sh` の結果で判定する（この計算機には両方ある）
- 完了の報告に、`libfuzzer-sys` の版とライセンス（変えていないこと）、`fuzz-short.sh` の実行の結果（見つかった不具合があればその一覧）を書く

## 難易度の理由

三つの対象の移行は C18 が済ませた。判断が要るのは、複数のファイルの入力の形を、libfuzzer の変形で意味のある入力が得られるように決めることと、種の入力の作り方である。
