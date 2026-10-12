# W3（628a9a0c）のレビュー

対象: コミット `628a9a0c`（作業 W3。宣言の流れ込みの報告の位置）。`crates/benitoite/src/typeck/solve.rs`、`crates/benitoite/src/typeck/tests.rs`、`docs/design/02-impl/02-05-typechecker.md`、`CHANGELOG.md`。照らした文書は、改造のディレクトリの `plan.md`「作業 W3」、`decisions.md` の Q4・R5、`study.md` の調査 C の 4 節、事前点検の補足（`orch9/W1W3-pf.md`「W3 への補足」）、実装者の報告（`orch9/W3-report.md`）、前の改造の `decisions.md` の R18 と `study.md` の C 部 4 節。ビルドとテストは走らせず、コードを読んで机上で確かめた。

## 結論

計画・事前点検の補足どおりに実装されており、d7・d9・d13・d16・d18 と、`return s` が型注釈より先にある形は、補足が予想した一件の報告になる。R18 の f・g・h（束縛のパターンの失敗）は従来どおり `return s` へ移る。

ただし、案 A で「変数を使う側の失敗」を後へ回さず即座に報告するようにしたため、**束縛のパターンの失敗を宣言へ移した変数を別の箇所で使うと、使う側に偽の E0401 が新しく出る**（H1）。W3 の前は、使う側の失敗も `late` に積まれ、報告のときの `poison` で重なりが消えていた。計画の案 A が見落とした形であり、取り込みの前に直すことを勧める。直し方は小さい（使う側の失敗を元の理由と位置のまま `declared_late` と同じ後回しの並びに積む）。そのほかは軽微な所見だけである。

## 観点ごとの確かめ

### (1) 計画と判断との一致

- 案 A（plan W3 の 1、R5）: `pair_failure`（solve.rs 1057-1071 行）が、`ReasonKind::Pattern` のときだけ `found` の側を調べ、`(code, found, expected, r, escaped)` を `late` に積む。`Priority::Declared` でないこと、E0401、宣言の式の内側でないことの条件も残る。凍結の `Reason` に印を足していない。補足の 1 のとおり。
- 案 D（plan W3 の 2、補足の 3）: 別の欄 `declared_late`（73 行）に積み、`poison` しない。条件は `Declared`・E0401・`Return` か `BindAnnotation`・`found` が変数・根の記録が今の理由と違う、で補足どおり。`solve` の終わり（960-967 行）で `late` の後に処理し、`found` が誤りの型を含めば捨てる。
- テスト（plan W3 の 3）: d13・d7・d9・d18・d16 と逆順の形を加えた。`redirected_binding_failures_report_once_per_root` を探さず件数で確かめたのは補足の 2 のとおり。
- 設計書（plan W3 の 4）: 02-05 の 391 行を直し、393 行に宣言どうしの食い違いの段落を加えた。補足の 4 の趣旨と合う。
- Q4 の範囲（案 A と案 D）を超える変更はない。

### (2) 正しさ

机上で追った入力と結果（行・桁は `orch9/c/` の入力のもの）:

| 入力 | 経路 | 結果 |
|---|---|---|
| d13 | 手順 1 で `return s` が `s` を Integer に決める。手順 2 の `g(s)` の `CallArg` の失敗は `Pattern` でないので即座に報告 | 7:15 に一件。正しい |
| d18 | 手順 1 で注釈が `s` を String に決め、`return s` の失敗は `declared_late` へ。手順 2 の `bind s <- n` の `Pattern` の失敗は注釈の記録へ移り `late` へ。終わりに `late` を報告して `s` を誤りの型にし、`declared_late` を捨てる | 3:21 に一件。正しい |
| d16 | d18 と同じ。`return s` の Unit との食い違いは捨てられる | 3:21 に一件。調査 C の 4 節が許容とした形 |
| 逆順（`return s` が先、注釈が後） | 注釈の失敗が `declared_late` へ。手順 2 の束縛は通り、終わりに `s` が誤りの型でないので報告 | 注釈の位置に一件。正しい |
| d3（二つの `return s`、関数は Unit） | 二つ目の流れ込みは Unit と Unit で通る。束縛のパターンの失敗は一つ目へ移る | 一件。変化なし |
| R18 の f・g・h | 束縛のパターンの制約の失敗で `found` が `s` の型変数 | `return s` へ移る。変化なし |
| 宣言の流れ込みの自身の失敗（剛な型の脱出の E0401） | `flow` が記録した直後の `equal` の失敗で、記録の理由と今の理由が等しいので `declared_late` に入らない | 従来どおり即座に報告（脱出の注記を保つ） |

- R18 の意図: R18 は「FE403 の仕組みを手順 2 の食い違いの全般に広げ」た。W3 は Q4 の判断で移し替えをパターンの失敗に絞った。R18 が想定した f・g・h はパターンの失敗なので、移し替えの形は保たれる。ただし、R18 の実装には「移した失敗を後へ回し、報告のときの `poison` で同じ変数の重なりを消す」働きもあり、W3 は使う側の失敗についてこの働きも外した。これが H1 の原因である。
- `declared_late` を捨てる条件: `found`（流れ込む値の側の型変数）が、`late` の報告の後に誤りの型を含むとき。`failure_with_escape` も両辺が誤りの型を含めば報告しないので、二重の判定になっている（L2）。同じ変数に宣言どうしの食い違いが二つ以上あるときは、最初の報告が `poison` して残りを抑えるので、重ならない。
- 報告の順序: `late` を積んだ順、続いて `declared_late` を積んだ順で、決まっている。
- 漏れと重複: 下の H1 のとおり、変数を使う側の失敗で偽の報告が新しく出る。`declared_late` を後へ回して `poison` しない分、手順 2 で同じ変数に当たる使う側の制約が、注釈の型のまま比べられる（H1 の入力 2）。宣言どうしの本当の食い違いが、無関係の誤りの `poison` で抑えられる場合（例: 束縛が注釈と合い、`return s` が食い違い、別の呼び出しで `s` の使い方も誤る）は、一件目を直した後の再検査で出るので許容できる。

### (3) AGENTS.md の実装の規約

- `unwrap`・`expect`・添字・`as` を使っていない。panic を起こす経路はない。
- コメントは日本語で、理由と設計書の節（02-05「誤りの報告と検査の継続」）を示す。保管した実装プランの節や作業の ID を引いていない。
- 凍結した型とシグネチャ（`Reason`・`ReasonKind`・`Priority`・`Constraint`）を変えていない。足した欄は非公開。
- `declared` の欄のコメントが用途を呼び出しの戻り値だけと書いたまま（L3。W3 の前からの古さだが、W3 が用途を増やした）。

### (4) テストの質

- 二つのテストは型検査の公開の入口（`expect`）で、診断のコード・行・桁・件数をちょうど一致で確かめ、本文の向き（`expected String, found Integer`）と注記の有無も見る。直す前に落ちることを実装者が確かめている。関門のコメントで既存のテストとの差を書いている。test-audit の作成時の関門に合う。
- 不足: H1 の形（束縛のパターンの失敗を移した変数を、別の箇所で正しく使う）がない。02-05 の 391 行が対象に含めた `match` の分岐のパターンの形（`case s -> … return s` の系）もない（L4）。

### (5) 02-05 の記述と実装、文章の規範

- 391 行と 393 行は実装と一致する。393 行の「手順 2 と後へ回したほかの報告を終えた後に」は、`late` の後に処理する実装と合う。
- 391 行の「対象は、束縛の文と `match` の分岐で、値の型とパターンの型を等しくする制約のうち、パターンの側がその変数であるもの」は、実装が `ReasonKind::Pattern` の全体（構成子の引数・リストの要素・レコードのフィールドのパターンを含む）を対象にすることと矛盾しない（入れ子のパターンも分岐や束縛のパターンの一部）。
- 理由はそれぞれ 1〜3 文に収まり、常体で、空句や比喩はない。H1 を直すときは、391 行の「元の理由と位置で報告する」に、報告の時機（後へ回し、変数が誤りの型なら捨てる）を書き足す必要がある。
- CHANGELOG の「Conflicting declaration flows wait for binding errors」は、利用者に通じない内部の語を使う（L1）。

## 所見

### 重大

**H1. 束縛のパターンの失敗を宣言へ移した変数を別の箇所で使うと、使う側に偽の E0401 が出る（W3 による後退）**

- 場所: `crates/benitoite/src/typeck/solve.rs` 1057-1072 行（`pair_failure` の移し替えの条件と、その後の `self.failure`）。
- 問題点: 手順 1 で宣言（`return` か型注釈）が変数の型を決め、手順 2 でその変数を定める束縛が食い違うと、束縛の失敗は `late` に積まれ、変数はまだ宣言の型のままである（`poison` は `solve` の終わり）。W3 の後は、その間に解く「変数を使う側」の制約（呼び出しの引数など）が宣言の型で比べられて失敗し、即座に報告される。変数の本当の型（束縛の値の型）では正しい使い方なのに、誤りとして報告する。W3 の前は、使う側の失敗も宣言の記録へ移して `late` に積み、一件目の報告の `poison` で二件目を抑えていたので、報告は一件だった。
- 入力 1（`return` との食い違い）:

  ```
  function g2(x: Integer) -> Integer
    return 1
  end function

  function f(n: Integer) -> String
    bind s <- n
    bind _ <- g2(s)
    return s
  end function
  ```

  予想: W3 の前は 8 行の `return s` に「expected `String`, found `Integer`」の一件。W3 の後は、それに加えて 7 行の `g2(s)` の `s` に「expected `Integer`, found `String`」（`s` は Integer なので偽）が出て二件になる。

- 入力 2（`return` がなくても起きる。d17 に使う側を足した形）:

  ```
  function h(x: Integer) -> Integer
    return x
  end function

  function f(n: Integer) -> Unit
    bind s <- n
    bind t: String <- s
    bind _ <- h(s)
  end function
  ```

  予想: W3 の前は 7 行の注釈の `s` に「expected `String`, found `Integer`」の一件。W3 の後は、8 行の `h(s)` の `s` に「expected `Integer`, found `String`」が加わる。d18 に `bind _ <- h(s)` を足した形も同じく二件になる（`declared_late` で `poison` しなくなったため、W3 の前は `return s` の誤った位置の一件だった）。`return Option.Some(s)` のように変数を引数に包む形も、構成子の引数の `CallArg` の失敗として同じ形になる。
- 修正案: 使う側の失敗の位置は W3 のまま元の理由と位置にし、時機だけを W3 の前に戻す。すなわち、`Priority::Declared` でない E0401 で、`Pattern` の移し替えの条件に入らず、`expected` か `found` のどちらかが `declared` に根の記録のある変数であるときは、`self.failure` を呼ばず、元の `(code, expected, found, reason, escaped)` のまま `declared_late`（名前は用途に合わせて改める）に積む。`solve` の終わりで `late` の後に処理すれば、パターンの失敗を移した変数は誤りの型になっていて捨てられ（入力 1・2）、d13・d7・d9 は変数が誤りの型でないので元の位置で報告される。`failure_with_escape` は両辺を見て誤りの型なら報告しないので、捨てる判定はそれに任せられる。宣言の式の内側の条件（1065-1067 行）は報告の位置に関わらなくなるので、使う側には要らない。テストに入力 1・2 と「d18 に `h(s)` を足した形」を加え、どれも一件であることを確かめる。02-05 の 391 行の「元の理由と位置で報告する」に、手順 2 と移し替えた報告の後に、変数が誤りの型でなければ報告することを書き足す。案 A の範囲を広げる変更なので、オーケストレータと設計者の判断を経てから直す。

### 中

なし。

### 軽微

**L1. CHANGELOG の文が内部の語を使う**

- 場所: `CHANGELOG.md` 43 行。
- 問題点: 「Conflicting declaration flows wait for binding errors」の「declaration flows」は型検査の内部の語で、利用者に意味が通じない。
- 修正案: 例「When a binding annotation and a `return` disagree about a variable's type, the error is now reported where the variable's value conflicts with the annotation, instead of at the `return`.」のように、利用者に見える振る舞いで書く。

**L2. `declared_late` を捨てる判定が二重になっている**

- 場所: `crates/benitoite/src/typeck/solve.rs` 963-967 行。
- 問題点: `if !self.contains_error(&found)` は、`failure_with_escape` の先頭（E0401 では必ず通る `contains_error(expected) || contains_error(found)` の判定）と重なる。害はないが、片方だけを直すと食い違う。
- 修正案: H1 を直して並びの用途を広げるなら、明示の判定を消して `failure_with_escape` の判定に任せ、そのことをコメントに書く。残すなら、`failure_with_escape` も同じ判定をすることをコメントで示す。

**L3. `declared` の欄のコメントが用途を呼び出しの戻り値だけと書く**

- 場所: `crates/benitoite/src/typeck/solve.rs` 66-68 行。
- 問題点: 「呼び出しの戻り値の型の食い違いを、宣言の側の理由で報告するために使う」とあるが、今はパターンの失敗の移し替えと、宣言どうしの食い違いの判定にも使う。
- 修正案: 「呼び出しの戻り値の型の食い違い（FE403）、変数を定めるパターンの失敗の移し替え、宣言どうしの食い違いの判定に使う」と三つを挙げる。

**L4. `match` の分岐のパターンで移し替える形のテストがない**

- 場所: `crates/benitoite/src/typeck/tests.rs` 526 行と 546 行の付近。
- 問題点: 02-05 の 391 行は `match` の分岐のパターンも対象と書くが、テストは `bind` の形だけである。事前点検の補足は、分岐のパターンでも制約の向きの決まりが成り立つと確かめたが、テストで固定していない。
- 修正案: 例「`function f(n: Integer) -> String` の本体で `match n with case s -> return s end match`」の形を `returned_binding_mismatch_uses_the_declared_return_reason` の表に一件足し、`return s` の位置に一件出ることを確かめる（生成の順で手順 1 の流れ込みが先に `s` を決めることを、作業で確かめてから足す）。
