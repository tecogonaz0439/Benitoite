# try の処置の移行候補

裸の try を明示形へ直す候補を、本物の parser の AST から抽出する道具である。既定は読み取りだけで、入力へ書き込まない。過去の移行の BASE や manifest を読まず、`tools/source-migrate/` のホスト抽出・位置対応・ハッシュ・範囲検証・diff・適用を使う。処理系の構文・型・脱糖は変えない。

## 候補と確認表を出す

リポジトリの根で補助プログラムをビルドし、出力先を指定する。

```sh
cargo build -p benitoite --example try_actions_inventory
python3 -B tools/try-actions-migrate/migrate.py inventory --out /tmp/try-actions-review
```

既定は git が追跡する `.bnt`・`.rs`・`.md` と fuzz corpus を走査する。非公開の `docs/todo/` は読まない。パスを追加すると、そのファイル・ディレクトリだけを走査する。新しい未追跡のファイルを調べる場合もパスを指定する。

```sh
python3 -B tools/try-actions-migrate/migrate.py inventory --out /tmp/try-actions-review docs/reference crates/benitoite/examples tools/bench
```

`--root <ディレクトリ>` は入力の根、`--helper <実行ファイル>` はビルドした補助プログラムを切り替える。いずれも `inventory` などのサブコマンドより前に置く。自己検査では一時ディレクトリを入力の根にする。

| 出力 | 内容 |
|---|---|
| `manifest.json` | 全入力のハッシュと、候補ごとの位置・契約・提案・保留・確認状態 |
| `review.md` | 同じ ID と全候補の情報を持つ確認表。変更前後と保留も表示する |
| `proposed.diff` | 保留のない return の提案。確認前の比較用であり、適用はしない |

## 何を読み、どこを保留するか

`.bnt`、Rust の通常／raw 文字列、Markdown のコードブロックとインラインのコードスパンを読む。複数行・CRLF・Rust の Unicode／改行のエスケープを、元のホストの UTF-8 バイト位置へ対応付ける。try の範囲、operand の末尾、既存の処置、囲む関数・ラムダ・ハンドラの情報は AST から取る。補間の式と処置の説明も走査する。同じ末尾を持つ入れ子の try は、内側から処置を並べて一つの挿入にまとめる。パイプ全体や短い lambda の本体の境界は parser に従う。

完全なプログラムは名前解決・型検査も通す。直接の `.bnt` は実ファイルとの一致を確認してから依存モジュールを読む。標準ライブラリはビルドに埋め込んだ同じソースを import して検査する。一致しない場合は保留する。単独の式・文は仮の関数で構文の位置だけ調べ、型検査した完全なプログラムとは扱わない。構文・型の誤りや生成・連結断片、byte 文字列、生成 Skill は保留する。コメント・文字列・説明文の実行例らしい箇所も一覧へ出し、AST にないものを編集しない。

同じ末尾を持つ入れ子は候補をまとめて確認する。一部だけを承認すると処置が別の try に結び付く可能性があるため、diff と apply は `nested try action dependency` として拒否する。括弧の自動追加や未承認候補の適用は行わない。

役割はパスとホストの文脈から、`sample`（手本）、`library`、`benchmark`、`test`、`history`、`generator`、`minimal_reference` に分ける。Rust の tests.rs・tests/ と検査属性以降の文字列は検査として保持する。この属性判定は保守的であり、Rust 全体の構文解析ではない。検査属性の後に本番の生成元を置くファイルは個別に確認する。歴史資料は編集せず、最小版リファレンスの try は現行版へのリンクを検討する保留にする。

| `classification` | 意味 |
|---|---|
| `change` | 型検査済みで、処置を挿入する提案がある。確認状態はまだ pending |
| `already_explicit` | 既に return または die が明示されている |
| `notation` | インラインの一般形 `try e`・`try Expr`・`try Operand`、EBNF など。`benitoite test` など、info 文字列の先頭の語が `benitoite` の未解析の実行用 fence は `hold` とする |
| `pre_migration` | 直前に Before・移行前・旧構文と明記した引用 |
| `keep_test` | 互換性を守る検査入力。移行器からは適用しない |
| `history` | 保管資料・固定した研究入力・過去の測定記録など |
| `hold` | 説明、生成元、負の入力、契約変更など、人の判断が必要 |

分類の件数の合計は候補数に一致する。一つの語を含むコードが手本か構文名かは、常に自動では判断できない。一般形として列挙したもの以外は、確認表の保留理由を確認する。生成断片の判定にも共通抽出器の近傍の字句による制約がある。未確認をなくすのは後続の移行作業の責務であり、inventory の成功だけでは移行の完了を意味しない。

## 処置と契約を確認する

Rust の補助プログラムが返す inventory は必須の `version: 2` と owner の `uses`・`file_uses`・`effective_effects` を持つ。版欄がない旧 inventory、旧版1の manifest、必須欄が欠けた入力を拒否する。旧 manifest は適用せず、現行の補助プログラムで候補を作り直して確認する。

`uses` は個別の宣言の原文のままであり、ファイルの宣言を合併しない。`file_uses` は同じファイルの元宣言を示し、実装メソッド・ラムダ・ハンドラでも所在情報として保持するが、それらの契約へ効果を追加しない。`effective_effects` は合併後の型検査済み契約を読む。断片や型の誤りがある入力、取得できない契約では null とし、`unknown_effective_contract` で保留して適用を拒否する。型検査に成功していても、この道具で文脈の効果変数などを名前へ対応付けられない契約は null となる。ファイルの宣言の範囲を元ホストへ対応付けられない場合は `unmapped_contract_boundary` で保留する。一般の Fail 型の同一性や移行の承認は、この文字列配列だけで判定しない。既存の型検査と契約の確認も必要である。

ファイル宣言の範囲は、断片の offset とホストの境界対応を通して元位置へ写す。位置が対応しない場合は保留する。共通宣言を一関数の編集範囲には使わず、候補の編集が共通宣言の範囲と重なる場合も拒否する。共通の `uses` を変更する必要がある場合は、個々の try の適用から分け、ファイル全体の契約として確認する。

再利用する関数・ライブラリ・コールバック、仕事量と結果を保つベンチマークには return を提案する。main には die を候補として示すが、`contract_review_required` で保留する。名前だけで uses・戻り値・出力を変更しない。Result.Error を返す契約、同じ結果を教える例、純粋性やハンドラの目的を保つ例では return を選ぶ。説明の内容、Kind の包括的な分岐の本体、テストの期待値は生成しない。

manifest の主要な欄は次のとおりである。位置はすべて半開区間、行番号は1始まりとする。

| 欄 | 内容 |
|---|---|
| `version` / `inputs` | 形式の版2／編集しないホストも含む path と SHA-256 |
| `id` / `path` / `line` / `start` / `end` | 候補の ID と、元のホストの行・UTF-8 バイト範囲 |
| `snippet` / `host_kind` | ホスト内の断片の番号と種類 |
| `source_sha256` / `after_sha256` | ホスト全体の変更前／その候補単独の提案を入れた後のハッシュ |
| `file_changes` | 保留のない提案をまとめた、ファイルごとの変更前後のハッシュ |
| `before` / `after` / `edits` | ホスト上の変更前後の候補と、共通適用器へ渡す編集。Rust の既存の escape は保持する |
| `operand_end` / `operand_host_end` | 復号した断片／元のホストの operand の末尾。処置の編集がこの位置と選んだ処置に一致するかも検証する |
| `owner` | 囲む関数の名前・種類・公開性・戻り値・個別の `uses` 原文。ラムダでは推論する戻り値は null |
| `owner.file_uses` | 元のファイル宣言の `{text, span: {path, start, end}}`、宣言なしは null。span は元ホストの UTF-8 バイト位置 |
| `owner.effective_effects` | 型検査で確認した最外側の正規化済み効果名の文字列配列。純粋な契約は `[]`、確認不能は null |
| `action` / `proposed_action` / `reason` | 現在の処置／推す処置／選択理由 |
| `typed` / `parse_errors` / `check_codes` | 完全な入力の型検査の可否と、保留の根拠になる診断コード |
| `holds` / `classification` / `confirmation` | 保留理由／分類／pending・approved・rejected などの確認状態 |
| `contract_changes` / `contract_reviewed` | uses・戻り値・失敗出力の変更の説明／die の契約を確認したか |

承認する return の行は `confirmation` を `approved` にする。採用しない行は pending のままか rejected とする。die の保留を解消するときは、人が契約を確認し、必要な import・uses・戻り値の編集を `edits` へ追加する。`contract_changes` の三欄を具体的な内容へ替え、`contract_reviewed` を true にして、その保留理由を除き `classification` を change にする。return を選び直す場合は proposed_action と挿入する after を return に揃え、契約変更が不要である理由を残す。型検査できない断片や生成元の保留を、確認状態だけで適用してはならない。完全な生成結果と元の契約を個別に確認する。

人が編集を変えた後は、`diff` で承認した行の実際の差分を出して再確認する。before/after とハッシュの欄は inventory 時の提案なので、編集を変えた場合は確認表も合わせて更新する。適用は確認済みの manifest 全体のハッシュに対して行い、実際の変更後の全入力のハッシュは receipt に記録する。

```sh
python3 -B tools/try-actions-migrate/migrate.py diff --manifest /tmp/try-actions-review/manifest.json --out /tmp/try-actions-review/approved.diff
shasum -a 256 /tmp/try-actions-review/manifest.json
python3 -B tools/try-actions-migrate/migrate.py apply --manifest /tmp/try-actions-review/manifest.json --reviewed-sha256 <確認したSHA-256>
```

apply は manifest のハッシュ、承認・保留・処置、die の契約の確認、保護するパス、全入力のハッシュ、全編集範囲と変更前の内容を確かめてから書く。検査・歴史資料・生成物への適用は拒否する。manifest を出すときも承認する行はない。適用後の静的検査と結果の確認は、後続の移行作業で必ず行う。

同じ確認済み manifest を再適用すると、隣の `manifest.applied.json` の全入力のハッシュと照合し、`already applied; no diff` を出す。変更済みの入力がある場合は拒否する。検証と書き込みの間の外部更新を除くロックや、複数ファイルの IO 失敗のトランザクションは共通適用器と同じく持たない。

## 自己検査

```sh
cargo build -p benitoite --example try_actions_inventory
python3 -B tools/try-actions-migrate/test_migrate.py
```

一時ディレクトリの実ファイルと実際の補助プログラムを使い、LLM は呼ばない。parser の operand の境界、複数行と inline、補間、Rust の escape、保留と分類、die の契約確認、確認済みハッシュと全入力・範囲の拒否、diff、適用と再適用を確認する。旧出力の拒否だけは、版欄なし・版1の JSON を返す小さな実行スクリプトを `--helper` に渡して確かめる。通常の `scripts/check.sh` の `python_syntax` が構文を確認し、`migrate_selftests` が helper のビルドとこの自己検査を呼ぶ（水準なしの互換指定は `python`）。
