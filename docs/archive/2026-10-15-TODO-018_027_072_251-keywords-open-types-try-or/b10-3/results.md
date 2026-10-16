# B10-3 実装結果

## 目的と変更

IOError・NetworkError・Json.ParseError・Csv.ParseError を直接表示できるよう、各型のモジュールに Trait.Show を実装した。メソッドの引数名は宣言と同じ x とし、message の文字列をそのまま返す。Json/Csv では既存の ParseError.message getter を使う。引用符・位置・接頭辞は加えない。

四つの通常の import が同じ Trait モジュールを共有する。読み込み・名前解決・型クラスの本番コードは既存の処理で足り、変更していない。各実装は型の所属するモジュールに置き、孤児規則を満たす。Trait から逆の import は加えていない。die の内部依存・型・脱糖は B10a の担当として残す。

- `src/prelude/stdlib/{IOError,NetworkError,Json,Csv}.bnt`: import と四つの実装。
- `tests/desugar_export/named.rs`: 独立したパッケージ入力も、通常入力と同じ標準宣言の書き出しを使う。空の一覧によるメソッド名の欠落を直した（R61）。
- `src/typeck/traits/tests.rs`: Trait の58実装の assert を保ち、四型を含む62実装全体に、既存の辞書とメソッド対応の assert を適用した（R60）。
- `src/modules/tests.rs`: prelude からの Trait の共有を検査。FIFO の期待列とモジュールの総数を厳密な新しい値へ更新した。Clock/Time・ソースと ID の対応・既存の全モジュールの循環拒否の assert を維持した。
- `tests/runtime_builtins.rs`: 不正なパスと URL から得た不透明な二型の表示を、Direct/Request の両方で検査する。
- `tests/{l21_json,l23_csv}.rs`: 既存の getter・構築・更新のテストに、解析が返す値、構築・更新した値、空文字、引用符・改行・Unicode を含む原因の表示を追加した。
- `docs/design/03-interop/03-06-stdlib.md`・`03-07-io-modules.md`・`03-08-text-and-data.md`: 四型の表示と依存の説明を反映した。

## test-audit の作成時の関門

1. 守る契約は、四型の標準の辞書選択、message の文字列の保持、暗黙に読み込む Trait の共有、明示 import と循環拒否である。
2. 実装の未登録・誤った型への登録、Show[String] を経由する引用符やエスケープの追加、getter の取り違え、余計な位置の表示、依存の重複読み込みを捕まえる。
3. 表示は既存の公開パイプラインから VM までをつなぐ統合テストを主とし、Json/Csv は既存の入力を拡張した。不透明二型は外部の失敗から作る必要があり、一つの統合テストにまとめた。従来のコレクションの Show と getter のテストには、この四型の辞書選択がない。loader の既存の表は実行結果では観察できないモジュールの共有と辺を検査する。
4. 本番の API・フラグ・可視性・ヒープの操作を増やしていない。実在の File/HTTP の入力検査で失敗値を作り、外部ファイルの内容やネットワークの応答へ依存しない。

実装前に不透明二型と Json の拡張テストを実行し、意図した E0705（Show の未実装）で失敗することを確認した。Csv は実装後の全入力で確認する。既存の assert の削除・比較の緩和・ignore の追加は行っていない。既存の getter と構築・更新の入力も維持した。

本番の標準ソースは32行追加・削除0行、Rust のテストは84行追加・21行削除（差し引き63行増）である。削除行は既存の入力と厳密な件数の更新・表示の条件の追加・書き出しの共通化のための書き換えであり、assert の撤去ではない。golden は副位置の12行を書き換えた。

## 診断と期待値

仕様上の診断コード・主文・help・主位置・終了状態の変更はない。golden 一件では、標準ソースに import を加えたため Json/Csv の宣言の副位置だけを更新した（R59）。裸の try の検査は変更していない。

| 既存の読み込みの期待値 | 旧 | 新 | 理由と維持した検査 |
|---|---|---|---|
| prelude の後のモジュール列 | Clock、Time | Trait、Clock、Time | IOError/NetworkError の明示依存。Clock/Time の型と辺の assert を維持 |
| 最小入力のモジュール数 | prelude の数 + 3 | prelude の数 + 4 | 追加した Trait 一つ。二つの import の target が同一 ID であることも厳密に検査 |
| 複数の利用者 import を持つ FIFO 列 | Console の後に Clock | Console の後に Trait、Clock | FIFO の契約を保ち、Trait 一つを挿入。既存の全要素・ID の同一性を維持 |
| 全標準実装と Trait 内の実装の同一視 | 全実装58 = Trait 内58 | Trait 内58を維持し、四型を含む全実装62 = 全ソースの実装62 | R60。辞書・メソッド対応の全 assert を62実装に適用 |
| d7-stdlib-extensible の Json の副位置（E0601/E0607） | 16行・バイト387〜397 | 18行・バイト411〜421 | R59。コード・主文・主位置・副位置の対象とラベル・help・終了状態2を維持 |
| 同 Csv の副位置（E0601/E0607） | 5行・バイト198〜208 | 7行・バイト222〜232 | R59。同じ六件の拒否と文章/JSONの厳密な比較を維持 |

## 検査

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1,180件成功・失敗0件・既存の ignore 21件。最終156.13秒（先の実行は157.46秒） |
| `cargo test -p benitoite --test runtime_builtins --test l21_json --test l23_csv --test golden` | 4スイート・14件成功。154.44秒 |
| `cargo test -p benitoite --test desugar_export` | 修正後16件成功・既存の ignore 1件。5.17秒 |
| `cargo run -p benitoite --example gen_skill` | 成功。実装メソッドは生成対象外のため生成物の差分なし |
| `cargo test -p benitoite --test skill_docs --test spec_examples` | 2スイート・15件成功。22.02秒 |
| `cargo clippy --workspace --all-targets` | 最後の Rust の変更後に成功 |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |
| `bash scripts/check-formal.sh` | 最終状態で全体が成功。lake build・六入口・独立入力・破損入力・manifest の照合を含む |

最初の golden 検査は R59 の宣言位置のずれで失敗し、その副位置だけを直した。lib の1件の失敗は R60 の旧い前提によるもので、修正後の同名の個別検査は成功した。check-formal の最後の独立入力の失敗は R61 の標準宣言の欠落によるもので、修正後に同じ独立入力の全入口と宣言所属・view の検査が成功した。修正後の全体再実行も最後まで成功した。統合テストの成功後、対象の本番ソースと入力は変えていない。

Skill の再生成と例の検査も実行した。構文の章・診断表・英語リファレンス・手書き Skill の例の変更はない。

最終の形式化の出力は `target/desugar-diff/run-74019/` と `target/coverage-diff/run-74019/` にある。Rust の書き出しは1,736入力中1,349件が対象、387件が既存の check error、範囲外0件で、787.808秒だった。最初の失敗と修正後の独立入力の確認は `target/desugar-diff/run-70068/` と `/private/tmp/benitoite-b10-3-formal.log` に残る。網羅性の独立した比較は通常10,020件・view付き10,028件が一致し、不一致・fuelExhausted は0件だった。

| 形式化の入口 | 結果 |
|---|---|
| `coverageDiff` | 通常10,020件・view付き10,028件が一致。不一致・fuelExhausted 0 |
| `desugarDiff` | golden 349入力・968定義、random 1,000入力・72,778定義が一致。既存の check error 387件、範囲外・不一致0 |
| `builtinCheck` | 対象1,349入力、summary 比較72,468件。不一致・非収束0 |
| `coverageProgramDiff` | match 16,417件・bind 6,036件、計22,453件が一致。不一致・対象外・fuelExhausted 0 |
| `surfaceCheckAll` | 51,645件一致。不一致・準備失敗・lazyRestriction 0。既存の対象外19件・q11 1件を維持 |
| `surfaceCheck` と最終 manifest | 全1,736入力・73,746定義・22,453 coverage entries の識別名・分類・結果が一致。独立したパッケージ入力の宣言所属・view も一致 |

独立した width・named・extensible・try の交換形式も成功した。契約の破損3件、hole/pipeの破損6件、名前付きの破損6件を意図した理由で拒否した。最終の個別照合は214秒だった。標準の型表から得る宣言を含め、対象内の件数・対象外理由を下方修正していない。最終ログは `/private/tmp/benitoite-b10-3-formal-final.log` にある。

Lean の定義・証明と corpus 9・型表3・網羅性3を維持した。新しい axiom・sorry/admit/native_decide は追加していない。

## 起動と静的検査の短い測定

変更前の release 実行ファイルを `/private/tmp/benitoite-b10-3/before` に保存した。基準 HEAD は `c4bfba010981cf62218e3bf8cccd0eee86ae32c3`。入力は tools/bench/run.py の generated_sources と同じ最小の main を使い、変更前後に同じソースで run/check を比較する準備をした。benchmark スキルが要求する環境の準備の了承を確認中であり、まだ計時していない。

了承後に実行する比較のコマンドは次である。各実行ファイルを既定構成の `cargo build --release -p benitoite` で作り、同じ入力・IO方式・予熱回数・標本数で比較する。`measure_startup.py --help` で引数の処理と構文を確認済みである。既存の記録を上書きせず、JSON の生の標本、Markdown の条件と結果、線形目盛の HTML を書く。

```sh
python3 -B docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/b10-3/measure_startup.py \
  /private/tmp/benitoite-b10-3/before /private/tmp/benitoite-b10-3/after \
  tools/bench/results/2026-10-16-b10-3-startup
```

まだ計時していないため、起動への影響と B10 の親の完了確認は未了である。比較に加えて、benchmark スキルに従う最小入力の CPU プロファイルと所見も残る。

## 計画との差と申し送り

R59〜R61 に、失敗した既存テストの前提と更新範囲を推す案として記した。比較の緩和や既存の assert の削除は行っていない。

コミット、docs/todo の変更、scripts/check.sh（dry-run を含む）、gc-stress の構成の検査は依頼に従って実施しない。共通の検査と取り込みはオーケストレータへ引き継ぐ。die の構文からの内部依存の検出は B10a-1、ソースからの die の一貫した実行は B11/B12 の範囲である。
