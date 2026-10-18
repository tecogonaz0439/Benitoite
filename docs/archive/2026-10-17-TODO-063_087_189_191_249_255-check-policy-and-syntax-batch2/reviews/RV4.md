# RV4 段5（P1）と段6（G1a〜G4）のレビュー

対象: `git diff 04e82f6f..041689a7`（san_benito）。判断 R86〜R103、計画の P1・G1a〜G4・RV4、各作業の results.md、前のレビュー RV3 を参照した。全体を精読せず、P1 の判定と Lean の規則の対応、判定の木、RV3 の直し、derive.py の編集の保護、Codec と Property の公開 API、テストの期待の変更、規約に絞って読んだ。重いビルドと全件のテストは走らせていない。既存の `target/debug/benitoite`（2026-10-18 06:33 のビルド。P1 の新しい反例の表示と G3 の Property を含む）で、小さな入力を `check` と `run` にかけて挙動を確かめた。

## 判定

**先に直すべき点あり。**

型検査が受理した文字の `match` の一部で、判定の木の変換が内部エラー（終了状態 3）になる（重1）。P1 で加えた既定分岐の省略の条件が狭いためで、型検査と Lean の規則の一致は問題ない。直しは条件を一つ変え、退行テストを一件加え、02-06 の一文を直すだけで済む。ただし、受理したプログラムで処理系が止まる不具合なので、V1 の版の更新より前に短い修正作業として直すのがよい。V1 の change と check-formal の全比較は、直した後の状態で行う。そのほかの指摘は、V1 の中で直すか、docs/todo の項目にすればよい。

## 指摘

### 重1 文字の全域を区間で覆い、ワイルドカードの行も残る `match` で、判定の木が内部エラーになる

- ファイル: `crates/benitoite/src/ir/decision.rs` 1165〜1196 行（`range_tree` の `exhaustive_character` と `default` の決め方）。同じ条件を `docs/design/02-impl/02-06-ir-and-lowering.md` 218 行が述べている。
- 問題: 文字の区間が全域を覆っても、既定分岐を省くのは「既定の行列が空のとき」に限られている。列 c がワイルドカードの行があると既定の行列は空でないので、既定分岐を作る。ところが全域を覆うので、既定分岐に実行が届くことはない。さらに、既定の行列は残りの列について網羅しているとは限らない。型検査は欄どうしの相関で網羅を認めるが、既定の行列はその相関を失う。このため、既定分岐の部分木を作るところで空の行列に当たり、`LowerError::Internal` になる。
- 再現（既存のビルドで確認。`run` が終了状態 3 で止まる）:

  ```text
  import Benitoite.Unofficial.IO.Console
  function f(c: Character, d: Boolean) -> Integer
   return match Pair(c, d) with
   case Pair('\u{0}'..'m', _) -> 1
   case Pair(_, true) -> 2
   case Pair('n'..'\u{10ffff}', false) -> 3
   end match
  end function
  function main() -> Unit uses Console.Write
   Console.writeLine(Integer.toString(f(c: 'z', d: true)))
  end function
  ```

  出力は `internal error: internal compiler error` / `the error occurred in the decision stage` / `empty pattern matrix` だった。`check` は通る。列 c の区間は `[0..'m']` と `['n'..max]` で全域を覆い、既定の行列は `Pair(_, true)` の行だけになる。その行列は Boolean の false を覆わない。第 2 列を文字にした `Pair(_, '\u{0}'..'\u{d7ff}')`・`Pair('n'..max, '\u{e000}'..max)` の形でも同じく止まる。
- 失敗の筋書き: LLM が「文字の範囲で場合分けし、別の欄で残りを受ける」形の `match` を書く。0.0.8 では `case _` を書かなくても型検査を通る（P1 の目的どおり）ので、利用者はこの形にたどり着きやすい。ところが実行の前に処理系の不具合の報告で止まる。利用者には直し方がわからない。
- テストの穴: `exhaustive_character_ranges_lower_without_a_default`（同ファイル 2479 行）は一列の行列だけを使う。`character_domain_source_contracts`（`typeck/pattern_ext.rs`）の相関の例 `Row(c: 全域, b: true)`・`Row(c: 全域, b: false)` は型検査だけで、判定の木には渡していない。golden の `p1-character-domain` も一列である。差分実行（random_programs）と check-formal の網羅性の比較は、この形の判定の木の変換を通らない。
- 修正案: 1191 行の条件を `if exhaustive_character { None }` にする。全域を覆うなら既定分岐に実行が届くことはないので、既定の行の有無で分けない。未被覆の文字が残り、既定の行もないコア入力を内部エラーとして拒否する規則はそのまま保つ。この場合は `exhaustive_character` が偽なので、既定分岐の部分木を作るところで従来どおり止まる。02-06 の 218 行の「ワイルドカードの行がない場合は」を「区間の和が全域を覆う場合は」に改める。退行テストとして、上の二つの形を `decision.rs` の差分実行（`compare`）に加え、golden の `p1-character-domain` にも二列の相関の例を一つ加える（終了 0 と標準出力）。Lean の規則と網羅性の判定は変わらないので、formal/ は変えない。

### 中1 組み込みの縮小器の候補の重複除去が、候補数の二乗で遅くなる

- ファイル: `crates/benitoite/src/prelude/stdlib/Test/Property.bnt` 234〜273 行（`shrinkList`・`deleteWidths`・`replaceElements`・`unique`）、354〜378 行（`reduce`・`tryCandidates`）。
- 問題: `shrinkList` は、削除の候補（長さ n に対しておよそ n log n 個）と、各要素の縮小の候補（n × 要素ごとの候補数）を、すべて先にリストとして作る。その後 `unique` が、各候補を既出の候補の列と `List.contains` で比べる。候補数を k とすると比較は O(k²) 回で、一回の比較は長さ n のリストの等値である。縮小が一歩進むたびに、この計算をやり直す。`maxShrinks` は性質の呼び出しの回数を数えるだけで、候補を作る費用は限らない。
- 実測（debug ビルド、`shrinkList(shrinkInteger())`、要素は 7 か 1000000、長さ 3 以上で失敗する性質）: 元の長さ 24 で 0.66 秒、88 で 11.4 秒だった（縮小の試行は 20〜24 回）。長さ 88 では一歩あたり約 2,000 個の候補を作り、その重複除去が時間の大半を占めると見られる。release ビルドでは数倍速いはずだが、増え方は変わらない。Config の size の上限は 10000 であり、その大きさのリストが失敗すると、現実的な時間で縮小を終えない。
- 失敗の筋書き: 利用者が size: 500 などで性質を試し、失敗した反例のリストが数百要素だと、`test` がほぼ止まったように見える。R10 が保証しないとしたのは「手書きの縮小器と性質の関数」の資源量であり、組み込みの縮小器がこの費用になることは利用者に予想しにくい（設計原則 6「簡単なことは簡単に」）。
- 修正案: 0.0.8 の中で直すなら、契約の文言を保ったまま `unique` の比較の相手を減らすのは難しい（`T: equality` だけでは整列もハッシュもできない）。V1 では 06-04 と Skill の参照の文書に「組み込みの List・String・Map の縮小の一歩は、元の長さに対して二乗を超える費用になりうるので、size は小さく保つ」と一文を加え、docs/todo に項目を立てるのがよい。項目では、候補の数を残りの予算（maxShrinks − shrinks）で打ち切って縮小器へ渡す形、重複除去を削除の候補どうしに限る形、候補を遅延して作る形を比べる。いずれも Shrinker の公開の型か「既出の候補を除く」という決定に触れるので、今回の段では直さない。

### 軽1 余分な鍵の経路の表示に、入力の鍵をそのまま埋める

- ファイル: `crates/benitoite/src/prelude/stdlib/Json/Codec.bnt` 72〜82 行（`rejectExtraFrom` が入力の鍵を `PathPart.Field(key)` にする）と 213 行（Show が `"." + name` を逃がさずに連ねる）。
- 問題: 設計（03-08「Json.Codec」）は、Show が「入力の内容を複製せず」に位置と種類を示すとする。欄の名前は宣言や設定から来るので安全だが、`rejectExtra` だけは入力の JSON の鍵を `Field` に入れる。Show はそれを引用符なしで出力する。`Key` の部分は `Trait.Show.show(key)` で逃がしているのと揃っていない。
- 再現: 鍵 `"a.b\n[0]: expected integer, found string"` を持つ Object に `rejectExtra(members, keys: [])` をかけて Show すると、`$.a.b` と `[0]: expected integer, found string: expected known field, found extra key` の二行が出力された。経路の区切りと偽の説明が、入力から作れる。
- 失敗の筋書き: 外部から受け取った JSON の検査の失敗を、ログか利用者への報告に Show で出す。余分な鍵に改行や制御文字を入れた入力で、報告の行を偽装でき、経路も読み違える。
- 修正案: 余分な鍵は `PathPart.Key(key)` にする（表示は `$["…"]` になり、逃がしが効く）。`Field` を残すなら、Show で識別子の形でない名前を `["…"]` の形で逃がす。03-08 の表の `rejectExtra` の行と、Skill の Json.Codec の参照を同じ変更で直し、l21_json に制御文字を含む鍵の例を一件加える。

### 軽2 上限に達したことを、候補を使い切った場合にも報告する

- ファイル: `crates/benitoite/src/prelude/stdlib/Test/Property.bnt` 362〜366 行（`tryCandidates` の先頭の検査）。
- 問題: 最後の候補を試して試行の総数がちょうど `maxShrinks` になり、残りの候補が空のとき、上限の検査が空の検査より先に来るので `limitReached: true` を返す。実際には縮小を最後まで終えている。最後の候補が Error だった場合も、`reduce` の先頭で同じく true になる（次の候補の列を作らずに止まるので、こちらは「上限で止めた」と言える）。
- 失敗の筋書き: 利用者が `limitReached=true` を見て maxShrinks を増やして再実行するが、結果は変わらない。害は小さい。
- 修正案: `tryCandidates` で、残りの候補が空かどうかを上限の検査より先に調べる。06-04 の「maxShrinks に達したら止める」と食い違わない。property_library に「候補数 = maxShrinks で全部 Ok」の例を一件加える。急がない。V1 で直さず docs/todo に回してもよい。

### 軽3 同梱の Skill が、ソースのリポジトリにだけある開発用の道具の手順を案内する

- ファイル: `crates/benitoite/skill/SKILL.md` 200〜229 行。
- 問題: Skill は実行ファイルに埋め込み、利用者のハーネスの LLM が読む。この節の後半は、`tools/derive` の preview・確認済みの apply・derive check と、生成記録の generatorVersion・configSha256 を案内している。この道具は、ソースのリポジトリの Python と、ビルドした example（`target/debug/examples/derive_inventory`）を前提とする。配布物だけを持つ利用者の環境にはない。SKILL.md の本文も約 30 行増え、毎回読み込む分量が増えた。
- 失敗の筋書き: LLM が Skill に従って `derive check` を実行しようとして失敗する。あるいは、手で書けば済むレコードの変換を「生成道具を使うべきもの」と判断して作業が止まる。
- 修正案: V1 で SKILL.md の derive の段落を「ソースのリポジトリの開発用の道具でも生成できる。配布物だけの環境では、Codec と Property の関数を直接呼んで書く」程度の一、二文に縮め、詳細は README へ委ねる。Codec と Property の API の説明は残す。

### 軽4 AGENTS.md のディレクトリ構成に `tools/derive/` がない

- ファイル: `AGENTS.md` の「ディレクトリ構成」の表。
- 問題: G1b で `tools/derive/`（derive.py・test_derive.py・examples・README）を加え、check.sh の Python の構文検査にも加えた。しかし AGENTS.md の表に行がない。`tools/named-arguments-migrate/` などと同じく、「既定は読み取りのみ。適用には確認済み manifest のハッシュの一致が必要」という扱いを書いておく必要がある。
- 修正案: V1 で表に一行を加える（内容、扱い、使い方は `tools/derive/README.md`、`derive_inventory` の example を先にビルドすること）。

### 観察1（P1 の型検査の短い測定。今回は直さなくてよい）

- 900 呼び出しで開始版の約 1.97 倍、絶対値は約 48 ms（Failure を取り込むと約 60 ms）だった。300→900 の伸びは約 3.3 倍で、二乗に近い兆しはあるが、3 点の入力では断定できない。
- 意見: 0.0.8 では直さず、docs/todo の項目にするのでよい。理由は三つある。第一に、この絶対値は利用者の典型的なスクリプト（数十〜数百の呼び出し）で体感に影響しない。第二に、原因の候補（`equal_function_effects` の線形探索、`propagate_effects` の制約の列の複製、RV3 軽4 の zonk）は Fail の規則の正しさの中心に近く、版の直前に手を入れると、F1〜F3 と P1 の全比較の結果を引用できなくなる。第三に、計画は V1 の最終状態で本測定と CPU プロファイルを行う。項目には、本測定の対象に「高階関数とラムダの多い一関数（1000〜5000 呼び出し）」の型検査の時間を加えることと、二乗であると確かめた場合の直し方（重複の判定を索引に置き換える、Fail の伝播を変化した制約だけに限る）を書く。V1 の本測定で 5000 呼び出しが秒の単位になれば、0.0.9 で優先して直す。

### 観察2（derive_inventory の出力の安定性）

- `crates/benitoite/examples/derive_inventory/mod.rs` は、型パラメータの `kind` と組み込みの番号を Rust の `Debug` の書式（`format!("{:?}", …)`）で JSON に書く。宣言の構造のハッシュ（declarationSha256 など）はこの JSON から取るので、Rust の列挙の名前を変えるだけでハッシュが変わり、利用者の生成記録の `derive check` が不一致になる。処理系の版を上げたときに再生成を求めることは、生成記録の版の設計で許されている。ただし、原因が利用者に見えない。急がないが、次に example を変えるときに、明示の文字列の対応表に置き換えるのがよい。

## 確かめて問題がなかった点

- **文字の全域の判定（P1）**: `typeck/patterns.rs` の `shapes` は、分割の端に 0・0xD800・0xE000・0x110000 と各区間の下端・上端の直後を加え、`0 ≤ lo ≤ hi < 0x110000 ∧ (hi < 0xD800 ∨ 0xE000 ≤ lo)` の区間だけを残す。文字には残りの値（`Other`）を置かない。これは Lean の `charBounds`・`charPartition`（`formal/Benitoite/Release/Coverage.lean` 137〜146 行）と同じ条件である。端に 0xD800 と 0xE000 を必ず含めるので、区間がサロゲートをまたぐことはない。整数は従来どおり `Other` を先頭に置く。
- **反例の表示（R64）**: Rust の `show_character` と Lean の `CoverageWitness.showCharacter` は、可視の ASCII、五つの逃がし、それ以外の小文字で 0 埋めのない `\u{…}` で一致する。区間の下端を文字へ戻す条件も、Lean の `characterValue` と同じである。問いの形を返す場合（Rust の `fallback` の `show_pattern`、Lean の `queryWitness`）も、文字のリテラルと範囲の下端を表示する点で一致する。範囲の下端が上端より大きい場合だけ表示が異なりうるが、その入力は E0605 で先に拒否される（確認済み）。既存のビルドでの確認: `case 'a'` だけに対して `'\u{0}'`、`'\u{0}'..'\u{d7ff}'` と `'\u{e001}'..` の組に対して `Pair('n', '\u{e000}')` の形の反例が出た。
- **判定の木の区間（重1 以外）**: `Domain::next` が 0xD7FF の次を 0xE000 とするので、二範囲の組は連続とみなされる。部分ごとの特殊化の行列は、型検査が網羅を認めた入力では網羅している。ガード付きの全域の範囲（`'\u{0}'..'\u{d7fe}' if c = 'a'` を含む三分岐）は実行できた。
- **P1 の記録の信頼性**: `p1/relation-state.json` の基準と HEAD は `04e82f6f`、関係する入力 36 件の SHA-256 は、P1 のコミット `49bdd3c1` の同じファイルの内容とすべて一致した（このレビューで照合）。全比較が作業ツリーで走り、その内容がそのままコミットされたことを示している。`formal-summary.json` の件数（網羅性 10,020 件と view 付き 10,028 件の不一致 0、燃料切れ 0。表層 51,658 件の一致。既存の対象外 19 件と Q11 の 1 件は維持）は results.md の記述と合う。ただし、全比較は型検査の判定を比べるもので、判定の木の変換は対象外である。重1 はこの範囲の外にある。
- **期待を変えたテストと golden**: `nonexhaustive_literals.diag.json` は、文字の反例の文字列と追加案だけが `'\u{0}'` に変わり、コード・位置・終了状態は同じである。`patterns.rs` の既存の表は、全域の範囲の非網羅を網羅に変え、`unreachable(3, 0, &[2])`（全域の後の `_`）を加えた。どちらも R87 の意味の変更であり、緩めた変更ではない。後者の覆う行に [2] を選ぶのは、既存の「単独で覆う行を先に選ぶ」規則どおりである。
- **RV3 の直し**: 中1 は `ir/check.rs` 1147 行で `rest ⊆ comp.eff` を検査するようになった。変異テストは handle の `comp.eff` の名前を消す。そのとき、ほかの検査（節の効果、定義の宣言との包含）は通るので、新しい検査だけがこの変異を捕まえる。修正前に失敗したことも記録にある。軽1 は同じ型の Fail の重複を E0419 にし、異なる型の E0514 は保つ（golden `p1-duplicate-failure`）。軽2 は既存の `cases` を元の直接の束縛で実行し、新しい二つの表だけを if で包む形に戻った。
- **derive.py の編集の保護**: 管理印は完全一致の行だけを認め、形の崩れた印・入れ子・対応しない終わり・閉じない領域を拒否する。領域の本文のハッシュを生成記録の outputSha256 と比べ、手書きの変更・記録のない既存の領域・記録にあって消えた領域・設定にない領域を拒否する。生成する名前は、領域の外のトップレベルの宣言と import の別名との衝突を拒否する。編集は、領域の本文の置き換えか、import の後またはファイルの末尾への新しい領域の挿入だけである。apply は、レビュー済みの manifest のハッシュ、生成器の版・root・設定、埋め込みの入力、全入力の集合を照合し、receipt がなければ入力のハッシュを確かめたうえで `prepare()` を作り直して manifest と完全に一致することを要求する。生成記録は、旧ハッシュか不在を先に確かめ、ソースを適用した後に書く。宣言の後にしか置けない import は書き込まずに拒否する（R95）。
- **純粋さと特殊扱い**: Codec と Property は通常の `.bnt` であり、prelude の表に `unofficial: true` の二行を足しただけである。型検査・脱糖・VM に新しい特殊扱いはない。Property は `Random.Generator` を明示の状態として受け渡し、`fromSeed`・`nextInteger`・`nextFloat` はエフェクトのない関数なので、生成も縮小も乱数の権限を要しない。Skill の生成器の説明文の追加は文書だけである。`desugar_export` と `check_named.py` の拡張可能な標準型が 4→5 になったのは、`ConversionError` が `@extensible` であるためで、R98・R102 の説明どおりである（名前・レコードの区別・package・coverageView の照合は残っている）。
- **公開 API と決定の一致**: モジュール名は `Benitoite.Unofficial.Json.Codec` と `Benitoite.Unofficial.Test.Property`（R8）。Config の範囲（試行 1〜10000、size 0〜10000、maxShrinks 0〜100000）、誤設定のときにコールバックを呼ばないこと、整数の枝（`nextInteger(0, 8)` → 0・low・high → `nextInteger(0, 2)` → high か半開区間）、文字の番号の写し方（0x10F800 未満、0xD800 以上に 0x800 を加える）、maxShrinks が 0 なら縮小器を呼ばないこと、候補の試行ごとに総数を増やすこと、Error で候補の列を作り直すことは、R10 と 06-04 の記述どおりだった。
- **G1a の宣言の読み取り**: 名前解決と型検査は宣言の処理を通常の `check` と共用し（`resolve_declarations`、`typeck::collect_declarations`）、本体の検査は行わない。同じパスを異なる内容で二度読めば拒否する。段のスタックと panic 境界も通常と同じである。
- **規約**: 本体のコードに新しい `unwrap`・`expect`・`panic`・`#[allow]`・大域の状態・`unsafe` はない（いずれもテストの中だけ）。example の文言は子のモジュール `text` にまとめてある。診断 E0601 の説明の文の変更は `diag::codes` の表の中である。
- **テストの削除**: tests/ と testdata/ の変更は、追加と、上に挙げた期待の変更だけだった。削除、ignore の追加、assert の削除はない。`check_named.py` の `matched` の数え方の変更は、`scopes` を持つ新しい入力（G4 の生成例）だけに効く。

## 補足（指摘ではない）

- 重1 の直しの後、V1 の check-formal の全比較は改めて行う計画になっている（P1 の結果を無条件に引用しない）。判定の木の変更は、交換の入力と Lean の比較器には影響しない。そのため、重1 の直しのために P1 の全比較をやり直す必要はない。
- `Codec.decodeFloat` は JSON の整数（`1`）を受け付けない。03-08 の決定（暗黙の数の変換をしない）どおりだが、外部の JSON では `1.0` を `1` と書く生成元が多い。利用者の報告が出たら、Float の欄に限って整数を受け付けるかを検討する項目にするとよい。
