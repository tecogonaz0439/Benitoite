# F17 正規表現のリテラルを検査の時点で確かめる（OPEN-062 R08）

- 依存する作業: [F07](F07-typeck-records-constants.md), [F08](F08-typeck-traits.md), [F09](F09-typeck-effects.md), [F10](F10-typeck-patterns.md)、[L22](L22-regex.md)（U3 の `Benitoite.Regex` を加える作業）
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/F17-regex-literal-check

## 目的

`Regex.compile` の引数が文字列リテラルか定数式のとき、処理系が検査の段で正規表現を組み立て、構文の誤りを検査の誤りとして報告する（03-08「Regex」の【方針】）。これは、外部の検証者のレビューが OPEN-062 の R08 として指摘した「関数の本体の `Regex.compile(r"[")` が、検査の誤りにならず、実行時の `Result.Error` になる」という問題への対処であり、再現テストを兼ねる。`Regex.compile` の型（`function(String) -> Result[Regex.Pattern, String]`）は変えない。

## 始める前に満たすこと

本作業は、U3 の作業 L22 が `Benitoite.Regex` のモジュール（10-14 に加えるソースと、10-12 に加える `Regex.compile` の組み込みの関数）と `regex` クレート（[ADR 0138](../../design/decisions/0138-crates-and-licenses-for-stdlib.md)、03-08「各モジュールの範囲」）を取り込むまで始めない。オーケストレータが確かめてから起動する。本作業は、その作業が置く「正規表現の源の文字列を、実行時の `Regex.compile` と同じ設定で組み立て、成否と理由の文字列を返す純粋な Rust の関数」を呼ぶ。検査の時点と実行の時点で組み立ての結果が食い違わないようにするためである。U3 の作業がこの関数を置かなかったときは、作業を止めて報告する。

正規表現の構文の誤りの診断コードは E0444 である（10-02「コードの一覧」。文言の型板は `invalid regular expression: {reason}`、主な位置のラベルは `not a valid regular expression`。02-10「診断コード」）。

## 読む設計書の節

- [テキストとデータのモジュール](../../design/03-interop/03-08-text-and-data.md)の「各モジュールの範囲」の `Benitoite.Regex` の段落と「Regex」
- [未決事項](../../design/open-issues.md#open-062)の OPEN-062 の R08 の行と、表の前後の段落（再現テストを書き、結果を報告する手順）
- [型検査器](../../design/02-impl/02-05-typechecker.md)の「定数の検査と評価」（定数の評価器を本体の中の式にも使うこと）「本体の後の検査」「誤りの報告と検査の継続」
- [構文](../../design/01-spec/01-02-syntax.md)の「定数（初回リリース版）」（定数式の形）「パイプ」
- ADR: [0128](../../design/decisions/0128-prelude-and-benitoite-namespace.md)、[0168](../../design/decisions/0168-regex-match-and-stdlib-opaque-values.md)、[0270](../../design/decisions/0270-open-062-items-in-runtime-rebuild.md)（R08 は U1 の範囲とした）
- インターフェース: [10-04](../10-interfaces/10-04-modules-and-resolve.md) の `ResolveOutput::stdlib`、[10-05](../10-interfaces/10-05-types.md) の「型検査の出力」、[10-02](../10-interfaces/10-02-diagnostics.md) の「型板の直し方」と E0444 の行
- 作業の文書: [F07](F07-typeck-records-constants.md) の「定数の検査と評価（`consts.rs`）」とフックの表

## 作るもの

- `src/typeck/regex_check.rs`: 本体の後の検査として、正規表現の源を確かめる処理。`typeck/mod.rs` に非公開の子のモジュールとして宣言する。
- `src/typeck/mod.rs` または本体の後の検査を呼ぶ共有のファイル: `regex_check` を呼ぶ一か所の変更だけを加えてよい（F07〜F10 がすべて取り込まれた後なので、並行する作業との衝突はない）。定数の評価器（`consts.rs`）の関数を本作業から呼ぶために可視性を広げる変更も、同じく最小限に限って加えてよい。
- 上のファイルのテストと、`testdata-next/stdlib/` の誤りのない例のゴールデンテスト（後述）。
- `src/diag/codes.rs`: E0444 について、10-02「型板の直し方」の範囲で直してよい。

## 手順の要点

1. 本体の検査で型の誤りがなかった本体だけを調べる（型の誤りのある本体の中の式は、定数式として評価しない）。
2. 本体の AST を辿り、次の形の呼び出しを探す（本プランの決定）。
   - 呼ばれる式が `NameExpr` で、名前解決の参照の表が指す束縛が `ResolveOutput::stdlib("Benitoite.Regex.compile")` と同じ束縛である呼び出し `Regex.compile(e)`。修飾の仕方（`Regex.compile`、`as` で付けた名前）によらず、束縛で照合する（ADR 0128）。`Benitoite.Regex` は非公式のモジュールであり、スクリプトは `import Benitoite.Unofficial.Regex` で取り込むが、`stdlib` の完全な名前は標準に加えた後の名前（`Benitoite.Regex.compile`）である（[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。
   - パイプを展開すると上の形になるもの（`e |> Regex.compile`、`e |> Regex.compile(_)`）。展開の規則は 01-02「パイプ」と 02-05「制約の生成」のパイプの行のとおり。
   - 名前を値として使った箇所（引数に渡す、束縛する）と、プレースホルダを含む呼び出し `Regex.compile(_)` を単独で書いたもの（ラムダになる）は調べない（OPEN-062 の R08 の修正の候補「値として扱った呼び出しは検査しない」）。
   - `stdlib` が `None`（`Benitoite.Regex` を取り込んでいないプログラム）なら何もしない。
3. 引数 `e` が 01-02「定数（初回リリース版）」の定数式の形なら、F07 の定数の評価器で値を求める（文字列リテラル、raw 文字列、複数行の文字列、定数の名前、定数式だけを埋め込んだ文字列補間、`+` による連結）。形が定数式でなければ調べない。評価が失敗したら調べない（誤りは F07 が報告済みか、実行時の問題である）。
4. 求めた文字列を、L22 が置いた組み立ての関数（10-16 で凍結する）に渡す。失敗なら E0444 の誤りとし、主な位置を引数の式、`{reason}` を関数が返した理由の文字列（改行を含むときは最初の行）とする。
5. 型検査の出力の表は変えない。

## 受け入れテスト

テストは F07 の `typeck::test_support` で検査する。

| 場合 | 入力の要点 | 期待する結果 |
|---|---|---|
| OPEN-062 R08 の再現 | `import Benitoite.Unofficial.Regex` と、関数の本体の `Regex.compile(r"[")` | E0444（主な位置は `r"["`） |
| 正しい正規表現 | 03-08「Regex」の例（`Regex.compile(r"\d{4}-\d{2}-\d{2}")` を `try` で取り出す） | 診断なし |
| 定数式 | `const pattern: String = "[a-"` の後の `Regex.compile(pattern)`、`Regex.compile("(" + "a")` | どちらも誤り |
| パイプ | `r"[" |> Regex.compile` と `r"[" |> Regex.compile(_)` | どちらも誤り |
| 調べない形 | 引数が関数の引数の変数、`bind f <- Regex.compile` の後の `f(r"[")`、`List.map(xs, Regex.compile)` | 診断なし |
| 修飾の仕方 | `import Benitoite.Unofficial.Regex as R` の後の `R.compile(r"[")` | 誤り |
| 同じ綴りの利用者の関数 | 利用者のモジュール `Regex` の関数 `compile` に `r"["` を渡す | 診断なし |
| 型の誤りのある本体 | 同じ本体に型の誤りと `Regex.compile(r"[")` | 型の誤りだけ |

ゴールデンテスト: 上の表の「正しい正規表現」の例を、`testdata-next/stdlib/` に `check` の方式のテスト（`.bnt`、`check` を書いた `.mode`、`0` を書いた `.exit`。`.bnt` の先頭に `// spec: 03-08 Regex` の行）として置く。本作業の時点で C05 が済んでいれば、置く先は `testdata/stdlib/` とし、初回リリース版の実行器で確かめる。誤りの診断のゴールデンテストは、C11 の後であれば本作業が `testdata/` に置いてよい。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 完了の報告の「残したこと」に、OPEN-062 の R08 の再現テストの結果（反例を再現し、検査の誤りにしたこと）を書く。OPEN-062 の記録を改めるのは設計者であり、本作業は設計書を変えない

## 確認の観点

- `Regex.compile` を綴りでなく束縛で照合しているか。
- 検査の時点の組み立てと実行の時点の組み立てが、同じ関数と同じ設定を使っているか。
- 値として扱った呼び出しを調べていないか（誤って調べると、03-08 が定めない誤りを報告する）。
- 共有のファイルへの変更が、`regex_check` を呼ぶ一か所と可視性の変更に限られているか。

## 難易度の理由

仕組みは本体の後に AST を一度辿るだけで小さい。U3 の組み立ての関数と診断コードの追加という、本作業の外の準備に依存する。
