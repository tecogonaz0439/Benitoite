# RV5 最終候補の受け入れのレビュー

対象: 候補 `2afe2d46`（その後の `81d8c0fa` は results.md の追記だけ）。計画の「最終候補の受け入れとRV5」の観点に絞り、次を読んだ。results.md の「段7の取りまとめ」、z2/results.md、v1/results.md、decisions.md の R104〜R108、RV4.md、コミット `1c545d8f`・`2afe2d46`・`7b0433fb`・`81d8c0fa` の差分、`crates/benitoite/tests/desugar_export/check_named.py` の比較の書き方、CHANGELOG.md の 0.0.8 の節、README.md、docs/reference/benitoite.md と install.md の変更箇所、同梱の SKILL.md の derive の段落、tools/derive/README.md の生成記録の節、性能の記録 `tools/bench/results/2026-10-18-1c545d8f5c5d.md` の環境・CPU プロファイル・所見、`git diff 0027a22c..HEAD -- docs/design` の追加行（未決の語の検索と、02-06・06-04・01-07・06-01・06-09 の変更）。全体は精読していない。

重いビルド・全件のテスト・check.sh・check-formal.sh は走らせていない。既存の `target/release/benitoite`（10:44 のビルド。`--version=json` の commit は `2afe2d46…`、版 0.0.8）と `target/debug/examples/derive_inventory` で、小さな入力を試した。入力は一時の作業領域に置き、リポジトリには置いていない。

## 判定

**軽い直しの後に受け入れてよい。**

候補の実行ファイルの挙動・同梱物・形式化の全比較・移行の範囲は、記録と食い違わなかった。RV4 の重1 は閉じている。固定記録の直し（`1c545d8f`・`2afe2d46`）は、比較を弱めずに実際の出力の件数へ合わせただけである。残る指摘は記録と文書の直しであり、処理系の挙動の不具合は見つからなかった。中1 は受け入れの根拠の記録に関わるので、設計者の受け入れの判断の前に results.md へ書き足すのがよい。軽の指摘は、受け入れの後に直すか、docs/todo の項目にしてよい。

## 指摘

### 中1 change と V1 の結果を候補へ引用する記録に、07-03 の引用の欄が足りない

- ファイル: results.md 92 行（change の行）と 124 行（V1 からの引用）。
- 事実: change は `79e32e13` で実行し、候補は `2afe2d46` である。その間のコミットは `1c545d8f` と `2afe2d46` で、変えたのは `crates/benitoite/tests/desugar_export/exchange-manifest.json` と `routing-manifest.json` だけだった（このレビューで `git show --stat` により確認）。二つの固定記録を読むのは `check_named.py` と `check_failure.py` だけで、Rust のテストは読まない（`git grep` で確認）。したがって change の結果は候補にもそのまま当てはまると判断できる。ただし results.md には、この差分の一覧と影響しない理由、判断者と日付が書かれていない。change の件数（lib・統合・長い対象・heap の各構成の成功・無視の数）もない。124 行の V1 からの引用には理由は書いてあるが、V1 の HEAD（`a20715fa` か取り込みの `79e32e13` か）、判断者、日付がない。
- 根拠: 07-03「結果の保存と引用」は、別の状態へ結果を引用するときに、対象の状態、差分の一覧、影響しない理由、判断者と日付を記録すると定める。plan も release の照合に「段1〜6の結果の引用とその後の変更を確認」することを求めている。
- 修正案: 「段7の取りまとめ」に短い引用の表を加える。change（`79e32e13` → `2afe2d46`。差分は上の二ファイル。読むのは check-formal の Python だけ）と V1 の 68 ファイル・訳の照合（V1 の HEAD → `2afe2d46`。以後の変更は固定記録・性能の記録・結果の記録だけ）について、元の記録の場所・判断者・日付を書く。change の件数は、一時の作業領域のログが残っていれば写す。残っていなければ「件数は記録していない」と明記する。

### 軽1 RV4 の残りの指摘の処置が、改造のディレクトリに記録されていない

- ファイル: results.md 126 行以降（「残り」）、z2/results.md の「計画からのずれと申し送り」。
- 事実: Z2 は RV4 の中1（縮小の候補の重複除去の費用）の最適化と、観察1（P1 の型検査の費用）・観察2（derive_inventory の Debug の書式）を行わず、「取りまとめ担当が後の課題を管理する」とした。性能の記録は TODO-257 を、results.md は TODO-032 への追記を挙げる。しかし、RV4 中1・観察1・観察2 がそれぞれどの項目へ送られたか（取りまとめの説明では TODO-258・257・259）は、改造のディレクトリのどこにも書かれていない。このレビューは docs/todo を読んでいないので、項目の中身は確かめていない。
- 修正案: 「残り」に、RV4 中1 → TODO-258、観察1 → TODO-257、観察2 → TODO-259、1 万関数の check の二乗の伸び → TODO-032 への追記、の対応を一行ずつ書く。skill-eval などの LLM を呼ぶ評価は計画の許可に含まれないので未実施である、と一文を加えると、未実施の項目が揃う。

### 軽2 性能の所見の二点が、記録の数値で支えられる範囲を少し越えている

- ファイル: `tools/bench/results/2026-10-18-1c545d8f5c5d.md` 452 行（所見 2）、results.md 104 行。
- 事実と見立て:
  - 所見 2 は「延びたのは 0.0.5 と 0.0.7 の間と見られる」とする。根拠は、別の日の本測定（`b89e14c8`、v0.0.4 の後の TODO-247 の取り込み）の 0.607 秒と、今回の 0.695 秒の比較である。この二つは別の回の測定であり、0.0.5 の実行ファイルとの交互の測定はしていない。したがって、測定の条件の差である可能性を除けない。
  - 「倍にするとほぼ 4 倍になり、二乗で伸びている」について、記録の数値の比は 2,500→5,000 が約 3.2 倍、5,000→10,000 が約 3.6 倍、10,000→20,000 が約 3.9 倍である。大きくなるほど 4 倍に近づくので二乗の項が支配的になると読めるが、「ほぼ 4 倍」は小さい側には当てはまらない。
  - results.md 104 行の「0.0.7 と交互に測った時間の差は、すべて ±1.3 % 以内」は、測った 11 の対象についての事実である。RV4 の観察1 が測った、高階関数とラムダの多い関数の型検査（900 呼び出しで開始版の約 1.97 倍）は、この本測定の対象に入っていない。読み手が「0.0.8 に性能の退行はない」と読むおそれがある。
- 修正案: 所見 2 を「別の回の本測定（0.0.5 の取り込みの前後）より長い。0.0.5 との交互の測定はしていないので、どの版の間の変化かは確かめていない」と改める。「二乗で伸びている」は「関数の数が大きいほど二乗に近い伸びになる」とする。results.md 104 行の後に「本測定の対象は、RV4 観察1 の型検査の費用（TODO-257）を含まない」と一文を加える。CHANGELOG は性能について何も約束していないので、直す必要はない。

### 軽3 derive の README が、処理系の版を上げると構造のハッシュが変わりうることを書いていない

- ファイル: `tools/derive/README.md` 165〜180 行。
- 事実: README は、構造のハッシュから位置と注記の綴りを除くことと、「管理の規則やテンプレートを変えたら `GENERATOR_VERSION` を上げる」ことを書いている。一方で、RV4 の観察2 のとおり、`derive_inventory` は型パラメータの kind などを Rust の `Debug` の書式で JSON に書き、`declarationSha256` はその JSON から取る。このため、生成器の版が同じでも、処理系をビルドし直すと `derive check` が不一致になりうる。README は過大な約束をしているわけではないが、利用者には原因が見えない（TODO-259 で直す予定と聞いている）。
- 修正案: 生成記録の節に「`derive_inventory` の出力の書式が処理系の版で変わると、構造のハッシュが変わり、`derive check` が不一致を報告することがある。その場合は preview から生成をやり直す」と一文を加える。TODO-259 で書式を固定したら、この文を消す。

### 軽4 未処理の Fail の E0506 の案内が、toResult による変換を示さない

- ファイル: `crates/benitoite/skill/references/diagnostics.md` 1646〜1651 行（生成元は `diag::codes` の表）。
- 再現: `main` に `uses Console.Write, Failure.Fail[String]` を書いて raise すると、`check`・`run` とも終了 2 で、案内は「handle `Failure.Fail` with `handle ... with` inside `main`」だけだった。`@test` でも `test`・`test --check` で同じ案内が出た。
- 問題: CHANGELOG（「Handle or convert it within the entry」）とリファレンス 233 行（「convert it with `Failure.toResult`」）は、toResult による変換を勧めている。E0506 の案内は他のエフェクトと共通の文なので、Fail のときにもっとも書きやすい直し方が示されない。拒否は正しく働いており、害は小さい。
- 修正案: 次に診断を変える改造で、効果が Fail のときだけ「or convert it with `Failure.toResult`」を加える。docs/todo の小さな項目にしてよい。

### 軽5 リファレンスの第 11 節が、エフェクトの宣言を説明する前に制約付き操作から始まる

- ファイル: `docs/reference/benitoite.md` 987〜993 行。
- 問題: 「## 11. Effect handlers」の最初の二段落が制約付き操作（`render[T: Trait.Show]`）の説明であり、「You can declare your own effects.」はその後に来る。初めて読む人と LLM は、`effect` の宣言と `handle` を知る前に、操作の型の制約を読むことになる。内容は正しい（制約付き操作を関数値・`_`・`|>` で使い、`<42>/<"x">` を得た。操作に効果の変数を書くと E0510 になった）。
- 修正案: 二段落を節の基本の例（`effect Log`）の後へ移す。英語の版を直したら、次のリリースで日本語訳も合わせる。

## 確かめて問題がなかった点

- **記録とコミットの対応**: `1c545d8f` は `exchange-manifest.json` の batch2Character の定義の数を 2→4 にした一行だけである。`2afe2d46` は、p1-character-domain の項目（定義 4、inScope 4、照合 3、束縛 1、表層の検査 4）と集計（脱糖 983→985、表層の一致 51,658→51,660、網羅性 22,456→22,458、定義 73,761→73,763、表層の検査 51,678→51,680）を改めた。results.md の表の記述と一致する。入力 `testdata/patterns/p1-character-domain.bnt` は 4 関数（classify・correlatedBoolean・correlatedCharacter・main）、match 3 つ、束縛 1 つ（classify の bind）なので、改めた数は入力の実際の形と合う。表層の検査の数は一致の数＋対象外 19＋Q11 の 1 で、直す前も後も等式が成り立つ。`7b0433fb` は性能の記録だけ、`81d8c0fa` は results.md の追記だけである。
- **固定記録の直しは比較を弱めていない**: `check_named.py` は、経路の分類（`compare_routing`）、入力ごとの定義の数・scopes・照合と束縛の数・表層の検査の数、集計の各数を、すべて `==` の完全一致で比べ、不一致の数 0 も要求する。直したのは期待の数だけで、比較の範囲・条件・許容は変えていない。二つの固定記録を読むのは check-formal の Python だけなので、`79e32e13` で走らせた change の結果は固定記録の直しで古くならない（中1 は、その判断の記録が足りない点である）。
- **候補の版と CLI**: `--version` は `benitoite 0.0.8`、`--version=json` は commit `2afe2d46…`・dirty 未収集・formats 版 1 の 9 種類を示した。`language "0.0.8"` は受理、`"0.0.7"` は E0908 と 0.0.8 の移行案内、`"0.0.9"` は E0907、`"0.0.5"` は 0.0.6・0.0.7・0.0.8 の注記 3 件を版順に示した（いずれも純粋なスクリプト）。`package update` は `--help` に載っている。
- **Fail と許可の名前**: main と `@test` の未処理の Fail は、check・run・test・test --check のどれでも E0506（終了 2）になった。`Failure.toResult` で処理した main は `--allow-effects=Console.Write` で実行でき、`check --report=json` の `expanded` は `["Console.Write"]` だけだった。`--allow-effects=Console.Write,Failure.Fail` は許可の名前の誤り（終了 2）、空の指定は E0512（終了 2）だった。
- **文字の全域**: 全域の一範囲の後の `case _` は E0602、同じ分岐の重複した選択肢は E0608、`'a'` だけの match は反例 `'\u{0}'`、`'\u{10fffe}'` で止めた二範囲は反例 `'\u{10ffff}'`、ガード付きの全域の範囲と `case _` は受理、整数の全域の範囲の後の `case _` も受理した。いずれも CHANGELOG の記述どおりである。
- **RV4 の重1 は閉じた**: RV4 の再現の入力（`Pair(c, d)` の三分岐）は終了 0 で `2`・`3`・`1` を出力した。変種として、三列の `Triple` の相関、`Option` の中の `Pair`、ガードと変数の束縛を含む二列の文字の match も試し、すべて期待どおりの値を返した。`decision.rs` の直しは RV4 の修正案どおり、全域なら既定の行の有無によらず既定分岐を省く形である。02-06 の記述も合わせてある。RV4 の軽1（余分な鍵を `Key` にして逃がす）は l21_json のテストの期待の全文で、軽2 は property_library のテストで確かめられている（テストの本文を読んだ）。軽3（SKILL.md の derive の段落を二文に縮めた）と軽4（AGENTS.md に `tools/derive/` の行）も反映されている。
- **制約付き操作と derive**: `render[T: Trait.Show]` を関数値・`_` の部分適用・`|>` で使い、Integer と String に対して `<42>/<"x">` を得た。`derive.py check` はリポジトリの例で「generated regions and records match」（終了 0）、`People.bnt` の `test` は 2 件成功した。
- **ソースの候補**: `git ls-tree -r 2afe2d46` は 6,786 項目（シンボリックリンク 6）で、docs/todo と reference/ を含まない。results.md の記述と一致する。`/private/tmp/benitoite-candidate-0.0.8/src` が展開先として残っている。
- **利用者向けの文書**: CHANGELOG の 0.0.8 の節は、Fail・Codec・Property・derive・文字の全域・E0908 の記述が、上の CLI の挙動と食い違わなかった。Property の節は、縮小の費用が二乗を超えうることと、maxShrinks が候補の生成の費用を限らないことを明記しており、TODO-258 の改善を約束していない。型検査の費用（TODO-257）と derive_inventory の書式（TODO-259）についても、利用者向けの文書に将来の約束はない。install.md と README は 0.0.8 に揃っている。Rust の最小版（1.98）は性能の記録の rustc 1.98.1 と矛盾しない。
- **設計書**: 追加行に【未決】【要検証】はない。「docs/todo の TODO-191」への参照（01-05 の整数の扱い）は、改造の README と decisions の「Character だけを変え、Integer は残件」の決定と合っている。02-06 の既定分岐の条件、06-04 の Property と Fail の扱い、01-07 の型付きの失敗、06-01・06-09 の版の表は、上で確かめた挙動と一致した。`Benitoite.Test.Property`（モジュール名）と `import Benitoite.Unofficial.Test.Property`（取り込みの名前）の書き分けは、同梱の Skill の Failure の文書と同じ慣例である。
- **未実施の扱い**: skill-eval と構文の測定は計画の許可に含まれず、実施していない。release の自動の検査の終了 0 を、results.md は release_stack 10 件の成功として記録し、受け入れを設計者の判断に残している。計画の区別どおりである。

## 補足（指摘ではない）

- 公開のタグを付けるコミットは、`2afe2d46` の後の、results.md とこの RV5 を含むコミットになる見込みである。その間の差分は改造のディレクトリの文書だけなので、候補の照合はそのまま引用できる。タグを付けるときに、差分が文書だけであることを一行記録しておくとよい。
- リファレンス 1591 行の言語の版の段落は、移行案内の説明として 0.0.7 の読み込みの環境の変更だけを例に挙げている。0.0.8 の案内も同じく「現在の版へ更新」を促しているので誤りではないが、次に段落を直すときに、変更ごとの例ではなく一般の規則として書くと、版ごとの更新が要らなくなる。
