# T6 のレビュー（誤りのある型の別名、孤立した実装、型クラスの (a)(d)）

- 対象: 作業ディレクトリ `Benitoite-T5`（ブランチ `impl/TODO-178-T6`、基準 1622594）の未コミットの変更と、未追跡の `testdata/{types,traits}/todo178-*`（e0439 を除く）
- レビュー担当: Opus 5.5（medium）
- 確かめた方法: 差分を読み、作業ツリーの実行ファイル（`target/debug/benitoite`。変更より後にビルドしたもの）で小さな例を `check` にかけた。完了の条件のうち実装担当が走らせていなかった `cargo test --test cli_process` を走らせ、3 件が通った。

## 観点ごとの結論

1. 独立した誤りを消していないか: 別名の直しは、既存の決まり（宣言の頭部に誤りのある関数は本体を検査しない）に揃う形で効く。本体の型注釈（`Body::annotation`）は `ITy::Error` にするだけで、その後の独立した誤りは出る（例: `bind y: Bad <- 1` の次の行の `bind z: Integer <- "s"` は E0401 になる）。呼び出し側の引数の中の独立した誤り（`f(1 + "a")`）も出る。E0705 の抑止は、E0712 を出した型クラスと、構成子のない型の組に限られ、対照のゴールデンが範囲を確かめている。
2. 型検査を通るプログラムの集まり: 変わらない。`invalid_alias_uses` は誤りのある別名（診断を出した別名）を展開したときだけ増え、`invalid_impl_targets` は E0712 を出したときだけ、`orphan` は E0701 を出したときだけ立つ。E0711 の直しは表示だけである。
3. E0701 の実装を `seen` に入れないこと: 孤立した実装どうしの重なり（同じファイルに `Trait.Show[Integer]` を二つ）では E0702 が出ず、E0701 が二つ出る。どちらも E0701 を直さない限り通らないので、見逃しにはならない（低 3）。孤立していない実装どうしの重なりは、これまでどおり報告される。
4. E0711 の名前の並び: 名前の列は、置換に使う番号と同じく「実装の頭部の型パラメータ＋宣言のメソッドの型パラメータ（先頭の型クラスの引数を除く）」から作るので、添字は必ず範囲に収まる（`impls.rs:213-220` の `offset` と `impls.rs:269-274` の並びが一致する）。実装のメソッドの型パラメータが宣言より多い例・実装が型パラメータを持つ例（`implement[E] Wrap[List[E]]`）でも、`expected \`function(List[E], A) -> A\`` のように正しい名前が出た。
5. テストと規約: 新しいゴールデンは、報告どおり直す前に失敗する形で、仕様の節の印も付いている。コメントは日本語で、設計書の節（02-05「誤りの報告と検査の継続」「実装の検査」。どちらも実在の見出し）を示している。`unwrap`・添字・`as` の新しい使用はない。

## 所見

### 中 1: 実装の対象に誤りのある別名を書くと、E0702 が派生する（直しの範囲の漏れ。退行ではない）

- 根拠: `crates/benitoite/src/typeck/traits/collect.rs:235`（`ParamKind::Value` の対象を `d.ty` で読む）と `collect.rs:281`（`invalid` を診断の数だけで決める）、`traits/impls.rs:90-104`（`seen` の照合は `invalid(d, &i)` で止めない）。
- 再現:

  ```text
  type Bad = Option[Integer, Integer]
  trait Score[T]
    function score(x: T) -> Integer
  end trait
  implement Score[Bad]
    function score(x: Bad) -> Integer
      return 0
    end function
  end implement
  implement Score[Unit]
    function score(x: Unit) -> Integer
      return 0
    end function
  end implement
  ```

  E0410 のほかに「`Score` is implemented more than once for `Unit`」（E0702）が出る。別名を展開した `Bad` が `unit()` に置き換わり、対象が `Unit` として表に入るためである。基準の版でも同じく出ると読める（別名の診断は `prepare_aliases` で先に出るので、`collect_impl` の診断の数は変わらない）ため退行ではないが、T6 の目的（別名の誤りから派生する診断を出さない）の範囲にある。
- 直し案: `collect_impl` で対象を読む前後の `invalid_alias_uses` を比べ、増えたら E0712 の経路と同じく `TypeArg::Head(TyHead::Param(u32::MAX))` にして表の鍵を作らない（`solve::target_con` が `None` になる）ようにし、実装を誤りとして扱う。T6 で直さないなら、docs/todo に項目として残す。

### 低 1: 頭部に誤りのある別名を使った関数・実装のメソッドは、本体を検査しない

- 根拠: `decls.rs:410-414`（`signature` が宣言を `invalid` に入れる）、`generate.rs:94`（`check_function` が `invalid` の宣言の本体を飛ばす）。
- `function f(x: Bad) -> Integer return "oops" end function` の `"oops"` の E0401 は出ない。ただし、頭部に直接誤りを書いた `function f(x: Option[Integer, Integer]) -> Integer` でも同じく本体を検査しないので、既存の決まりに揃っている。別名の置き換え先の `Unit` で本体を検査すると派生の誤りが出るので、この形が妥当である。直しは不要。設計書に反映するとき（T9）、02-05「誤りの報告と検査の継続」の「誤りのある宣言」の扱いに、誤りのある別名を使った宣言も含むと書けば足りる。

### 低 2: 誤りのある別名を参照する別名では、使われない型パラメータの E0432 が出なくなる

- 根拠: `decls.rs:766-769`。
- `type W[T] = List[Bad]` では `T` は本当に使われていないが、E0432 は出ない。一方で、`type W[T] = Bad2[T]` のように誤りのある別名に `T` を渡す形では、置き換え先の `Unit` に `T` が現れないので、この打ち切りがないと派生の E0432 が出る。両者を見分ける費用に見合わないので、今の形でよい。直しは不要。

### 低 3: 孤立した実装どうしの重なりを報告しない

- 根拠: `traits/impls.rs:92`。
- 観点 3 のとおり、どちらにも E0701 が出るので見逃しにはならない。E0701 を直して実装を型か型クラスのモジュールへ移すと、その時点で E0702 が出る。直しは不要。

### 低 4: E0705 の抑止は、その型クラスについての構成子のない型すべてに及ぶ

- 根拠: `traits/solve.rs:126-129`（鍵が型クラスだけ）。
- `implement Score[function(Integer) -> Integer]` が E0712 のとき、`function(String) -> String` についての `Score` の制約も E0705 にならない。構成子のない型はどれも実装を持てず、E0712 の補助の文がそれを伝えるので、受け入れてよい。直しは不要。

### 低 5: 別名のゴールデンに、独立した誤りが残ることを確かめる対照がない

- 根拠: `testdata/types/todo178-alias-{before,after,annotation}.bnt`。三つとも期待は E0410 だけで、抑止が広すぎて独立した誤りまで消す退行を捕えない（型クラスの側には `todo178-impl-target-independent` がある）。
- 直し案: 一組加えるとよい。例: `todo178-alias-annotation` の `use` に `bind z: Integer <- "s"` を足すか、別の関数に `return "x"` を置き、E0410 と独立した E0401 の二つを期待にする。必須ではない。

### 補足

- `traits/tests.rs` の `coherence_and_method_contracts` の孤立した実装の部分は、ゴールデン `todo178-orphan-standard`（診断の一覧と終了状態 2 を確かめる）とほぼ重なる。計画の T6 が期待を `[E0701]` に直すと定めているので、このままでよい。T8 の整理で、test-audit の観点から一方に寄せるかを考えてよい。

## 取り込みの判断

取り込んでよい。高の所見はない。中 1 は T6 の直しの範囲の漏れだが退行ではないので、T6 に追加で直させるか、docs/todo の項目にして後に回すかをオーケストレータが決めればよい。低 5 の対照のゴールデンは、追加で直させるなら合わせて頼むとよい。
