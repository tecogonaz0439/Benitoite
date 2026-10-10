C3a の差分テストと分類記録を実装し、`scripts/check-formal.sh` は集計・報告の保存まで走りました。無作為な 1,000 プログラムはすべて一致し、ゴールデン入力の不一致は **6 関数・16 箇所、すべて (b) Lean の脱糖の定義の対応漏れ**と分類しました。

**完了条件のうち、`scripts/check.sh --base HEAD --only rust,formal` の成功は未達です。** 既存の HTTP テストがソケットの `bind` を実行環境に拒否されて失敗しました。形式化の検査は単独で成功しています。コミットはしていません。

## 1. 変えたファイル・作ったファイルと行数

行数は作業後のファイル全体です。既存ファイルには追加・削除行数も併記します。

**Rust**

| ファイル | 行数 | 変更 |
|---|---:|---|
| [tests/desugar_export.rs](crates/benitoite/tests/desugar_export.rs) | 190 | 新規。入力収集・書き出し・集計・整合の assert |
| [tests/desugar_export/exchange.rs](crates/benitoite/tests/desugar_export/exchange.rs) | 931 | 新規。範囲判定、表層・コアの JSON 変換、名前と変数の対応 |
| [tests/random_programs/generator.rs](crates/benitoite/tests/random_programs/generator.rs) | 839 | 38 行追加・1 行削除。形式化用の `generate_formal` |
| [tests/random_programs.rs](crates/benitoite/tests/random_programs.rs) | 288 | 1 行追加・1 行削除。共有する生成器をテストクレート内の `pub mod` に変更 |

**Lean とビルド設定**

| ファイル | 行数 | 変更 |
|---|---:|---|
| [Exchange/Syntax.lean](formal/Benitoite/Exchange/Syntax.lean) | 349 | 新規。交換用の型と JSON の読み書き |
| [Exchange/Convert.lean](formal/Benitoite/Exchange/Convert.lean) | 258 | 新規。Surface／Release との変換、エフェクトの集合比較 |
| [DesugarDiff/Main.lean](formal/DesugarDiff/Main.lean) | 132 | 新規。比較・集計・不一致の報告 |
| [lakefile.toml](formal/lakefile.toml) | 9 | 4 行追加。`lean_exe desugarDiff` |

**スクリプト**

| ファイル | 行数 | 変更 |
|---|---:|---|
| [scripts/check-formal.sh](scripts/check-formal.sh) | 47 | 新規。ビルド・書き出し・比較を順に実行 |
| [scripts/check.sh](scripts/check.sh) | 334 | `classify` に指定の分類を 1 行追加 |

分類と測定の記録として、[c3-diff-results.md](docs/2026-10-09-TODO-162-desugar-formalization/c3-diff-results.md) を新規作成しました（166 行）。

## 2. 交換用の表現の形と名前の付け方。本番のコードに足した公開の API

JSON の最上位は `version`・`operators`・`inputs` です。入力ごとに、検査の誤りによる除外か、利用者の関数定義の一覧を保持します。各定義は `inScope(surface, core)` または `outOfScope(elements)` とし、範囲内なら定義の頭と本体を両側から書き出します。

名前は次の規則で揃えました。

| 種類 | 規則 |
|---|---|
| 関数 | `fn:<BindingId>` |
| データ型 | `data:<BindingId>` |
| 構成子 | `con:<adt BindingId>:<tag>`。値・呼び出し・パターンで共通 |
| 組み込みの関数 | `builtin_decl(id).name`。例：`%Integer.add`、`%eq` |
| 組み込みのエフェクト | 組み込みの表のモジュール名と名前。`State` はそのまま |
| 利用者のエフェクト | `effect:<BindingId>` |
| 型パラメータ・エフェクト変数 | Rust の番号をそのまま使用 |

10-05 の番号の規則を確認し、トップレベルの関数では恒等対応としました。演算子の表は Rust の `OPERATORS`・`EQUALITY`・`INEQUALITY` から作り、Lean はこの表と `Operator.typeArgs` を使います。等値・不等値のスキームにエフェクト変数がないことも assert しています。

エフェクトは原子の有限の並びで受け渡し、比較時に集合として扱います。Float は u64 のビットで受け渡します。Lean の `UInt64` の JSON 表現に合わせ、`bits` は十進の文字列です。

`Float.ofBits`・`Float.toBits` は使用できます。ただし NaN のペイロードが往復で変わるため、ビットを保持できない入力は変換時に拒否します。今回の Rust の型検査済みの Float リテラルは有限値に限られるので、この制限には該当しません。

**本番のコードに足した公開の API：なし。** 本番の serde の導出も追加していません。

## 3. 正規化の一覧

| 内容 | 実装場所 |
|---|---|
| AST の束縛を de Bruijn の番号へ変換。定義の最後の引数が 0 | Rust `exchange.rs` の `Surface::name`・`statements`・`pattern` |
| コアの `VarId` を同じ規則へ変換 | Rust `Core::value`・`comp` |
| `match` の行と分岐を `(Pattern, Comp)` の並びへ変換 | Rust `Core::comp` |
| 行数＝分岐数、行 i の `arm=i`、パターンと分岐の変数の整合を検査 | Rust `Core::comp`・`pattern` |
| 構成子の識別、修飾、負の整数のパターンを揃える | Rust `con_name`・`Surface::pattern`、Lean `Pattern.toSurface`・`fromPattern` |
| 指定された型・由来・`BuiltinInfo`・ラムダの ID と引数名を捨てる | Rust `Core::value`・`comp` |
| 定義の頭を比較 | Rust `Surface::header`・`definitions`、Lean `desugar` |
| エフェクトの順と重複を除いて集合比較 | Lean `fromEff`・`canonicalJson` |

追加した表現上の対応は、**ラムダのエフェクトの別欄での比較**です。Release のラムダにはエフェクト注釈が残らないため、Rust のコアと Lean 側の表層から、ラムダの出力順に集めて比較します。場所は Rust `Core::value` と Lean `Expr.lambdaEffects`・`Block.lambdaEffects` です。構成子へ直接パイプする場合は、生成されない構成子ラムダを数えません。

`let x ⇐ return V` を代入して消す正規化は追加していません。パイプとプレースホルダの穴の再束縛は、そのまま比較して一致しました。負の Float の違いも正規化で消していません。

## 4. `scripts/check-formal.sh` の出力と時間

最終の集計は次のとおりです。スクリプトは報告を保存した後、不一致を理由に **終了状態 1** で終わりました。

| 入力 | 単位 | 一致 | 不一致 | 対象外 | 除外（検査の誤り） |
|---|---|---:|---:|---:|---:|
| ゴールデン | プログラム | 149 | 6 | 103 | 265 |
| ゴールデン | 関数 | 314 | 6 | 135 | 0※ |
| 無作為 | プログラム | 1,000 | 0 | 0 | 0 |
| 無作為 | 関数 | 2,621 | 0 | 0 | 0 |

※ 検査で除外した入力からは型検査済みの定義を取得していないため、関数単位の除外は計数していません。

対象外の内訳は以下です。複数の要素を持つ関数・プログラムがあるため、行の合計は対象外の総数と一致しません。無作為入力の内訳はすべて 0 です。

| 要素 | ゴールデンの関数数 | プログラム数 |
|---|---:|---:|
| field | 22 | 17 |
| interpolation | 22 | 22 |
| try | 52 | 44 |
| record | 21 | 18 |
| handler | 22 | 20 |
| resume | 17 | 16 |
| user operation | 13 | 13 |
| with | 27 | 24 |
| lazy | 5 | 5 |
| constant reference | 8 | 7 |
| alternative | 4 | 4 |
| list pattern | 7 | 7 |
| guard | 5 | 5 |
| range pattern | 3 | 3 |
| Rigid | 2 | 2 |
| typeclass method | 29 | 26 |
| record pattern | 4 | 4 |
| spread | 2 | 2 |
| class_constraints | 10 | 5 |
| TypeArg.Head | 4 | 3 |
| App | 1 | 1 |
| Decimal literal | 1 | 1 |

Rust の書き出しは、1,523 入力を **書き出し 1,185・対象外 73・除外 265** に分類しました。この判定は「範囲内の関数を一つでも書き出したか」です。Lean 側では対象外の関数を含むプログラムを対象外に数えるため、範囲内と対象外の関数を両方持つ 30 プログラムについて集計が異なります。

| 段 | 最終実行の時間 |
|---|---:|
| `lake build` | 1 秒 |
| `lake build desugarDiff` | 0 秒（秒単位の測定） |
| Rust の書き出し（cargo を含む） | 38 秒 |
| Lean の比較・報告の保存 | 1 秒 |

**書き出しのテスト内の計測は 36.893 秒**、テストハーネスの表示は 37.13 秒でした。10 秒を超えます。

全出力は [check-formal.log](target/desugar-diff/check-formal.log)、比較結果は [report.json](target/desugar-diff/c3a/report.json) に保存しています。無作為入力のソースも同じ出力ディレクトリに残しています。

## 5. 不一致の一覧と分類。直した (c) の内容

残る不一致は、すべて直接の負の Float リテラルです。以下の入力名は `crates/benitoite/testdata/` からの相対パスです。

| 入力 | 関数 | 最初の最小の入力 | 箇所数 | 分類 |
|---|---|---|---:|---|
| `eval/f15_float_to_string.bnt` | `main` | `-1.0` | 2 | (b) |
| `eval/float_round_floor.bnt` | `main` | `-0.5` | 6 | (b) |
| `eval/float_semantics.bnt` | `main` | `-0.0` | 3 | (b) |
| `eval/float_to_string.bnt` | `main` | `-1.0` | 2 | (b) |
| `eval/list_sort.bnt` | `main` | `-1.0` | 2 | (b) |
| `test/values.bnt` | `standard` | `-2.0` | 1 | (b) |

最小の違いは次の形です。

```text
Lean: let x ⇐ return Float(bits=0x3ff0000000000000)
      in %Float.negate(x)

Rust: return Float(bits=0xbff0000000000000)
```

Rust は型検査で直接の負のリテラルを符号込みで記録し、脱糖で定数を返します。Lean は Float を一般の `neg` として脱糖します。**型保存の定理が偽になる反例ではありませんが、Rust との項の一致は成り立ちません。**

診断用の一時の処理で、この Float の形だけを対応させると、6 定義とも残りの全体が一致することを確認しました。この処理は比較器には組み込んでいません。

(a) の不一致は 0 件です。追加の正規化を必要とする (c) の不一致も 0 件で、意味変換による正規化の追加はありません。詳細と修正案は [c3-diff-results.md の「不一致の分類」](docs/2026-10-09-TODO-162-desugar-formalization/c3-diff-results.md:95) に記録しました。

## 6. `scripts/check.sh --base HEAD --only rust,formal` の結果

**失敗しました。** format と全ターゲットの lint は通りましたが、既存の次の HTTP テストで停止しました。

```text
runtime::io::http::tests::
stopping_an_exchange_with_a_pending_or_dispatched_release_closes_without_waiting

runtime/io/http/tests.rs:298
TcpListener::bind(("127.0.0.1", 0))
PermissionDenied: Operation not permitted

789 passed; 1 failed; 16 ignored
```

同じテストの単独実行でも再現しました。実行環境がソケットの `bind` を許可しないため、要求された共通検査の成功を確認できていません。ログは [check-rust-formal.log](target/desugar-diff/check-rust-formal.log) にあります。

個別に確認できた結果は次のとおりです。

- `scripts/check.sh --base HEAD --only formal`：成功。`lake build` に `sorry` の警告なし。
- `lake build desugarDiff`：成功。macOS 上で実行可能。
- 書き出しのテスト：1 件成功。
- 既存の `random_programs`：通常設定で 3 件成功（23.38 秒）、`gc-stress` でも 3 件成功（15.32 秒）。
- 既存の生成器：6 段階それぞれ種 0〜999 のソースと機能別計数が、変更前後で完全一致。
- 最終変更後の `cargo fmt` と書き出し・無作為テストの `cargo clippy`：成功。
- `/bin/bash -n` と `git diff --check`：成功。
- 範囲内のコアを `unsupported(Lazy)` に置き換えた検出確認：不一致 1・対象外 0、終了状態 1。
- Float の正負のゼロを取り違えた検出確認：不一致 1。エフェクトの重複・並べ替えだけなら一致。

## 7. C3b の見込みと、C4 以降で範囲を広げるときの注意

C3b の対象は、現時点では負の Float リテラルの 1 系統に集約できます。修正案は、Lean の直接の Float リテラルへの `neg` を定数へ移す規則に揃えることです。括弧で囲んだリテラルや一般の式への否定を区別し、型付け・範囲の条件・型保存の証明・例と、01-12 の写しを同じ変更で確認する必要があります。Rust 側を変更する案も記録してあり、どちらを正にするかは C3b で確定する事項です。

後の段階では、特に次の対応を先に決める必要があります。

- **継続・利用者の操作**：`ContVar` と普通の値の変数を区別し、操作の型パラメータの番号を追加する。
- **辞書・メソッド・高カインド型**：現在の番号の恒等対応をそのまま適用せず、10-05 のメソッド・実装の番号を写す。
- **レコード・補間・展開**：構成子とフィールドの順、評価順を保持する。Decimal は Float のビット表現と分ける。
- **選択肢・ガード**：現在の「行 i が分岐 i」という前提を見直し、共有分岐と束縛の対応を定める。
- **ラムダの本体を複製・並べ替える脱糖**：エフェクト注釈を出力順で対応させる現在の方式を見直す。
- **型付けの検査への再利用**：今回の `opaque` の型名による表現とは別に、Task などの型引数と型の置き換えを扱う方式を検討する。