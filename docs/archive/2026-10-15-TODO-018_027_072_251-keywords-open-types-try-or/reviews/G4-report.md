# G4 レビュー報告（TODO-250 第 1 弾 段 3、B1〜B5 の Lean の定義と言明）

レビュー担当: Claude Code（Opus 5.5）。対象: `git diff cdd0cdc2 1af0f617 -- formal docs/design scripts/check-formal.sh`。git と読み取りだけで行い、ビルド・証明・公理の監査は B5 の記録を前提とした。

## 変わる規則の要点（設計者向け）

1. `try 式 or die` と `try 式 or die(説明)` を、Lean の型の規則に新しく二つ（Result 用と Option 用）加えた。どの関数の中でも書け、囲む関数の戻り値の型を問わない。
2. 成功すれば中身の値（型 T）になる。失敗すれば終了するので、式全体の型は T のままである。
3. エフェクトは「入力の式のエフェクト」に `Process.Exit` を一つ足したものになる。
4. Result の失敗値は、エラー型 E の表示（Show に当たる、純粋で String を返す一引数のメソッド）で原因の文字列にする。Option には表示を求めず、原因は固定の文 `expected a value, got Option.None` とする。
5. 説明は純粋な String の式に限る。説明の中から直接 return したり、外側のハンドラの続き（resume）へ抜けたりはできない。説明の中に書いたラムダは、ふつうの関数の境界を持つ。
6. 脱糖では入力を一度だけ計算する。失敗したときだけ、説明 → 原因の表示 → 既存の `exit[T](1)` の順に計算する。
7. 既存の `try`（失敗を返す形）の規則は変えていない。`or return` は交換形式でだけ区別し、Lean の中では裸の `try` と同じ規則に写す。
8. 証明できるのは型とエフェクトの対応までである。説明や表示が止まること、必ず終了状態 1 で終わること、報告が一度だけ出ることは証明の対象外であり、Rust の実行の検査で確かめる。

## 結論

重大 0 件、中 0 件、軽 5 件。定義と言明は design.md（段 3「型・エフェクト・書く位置」「脱糖とコード生成」「Lean の定義と証明」）と decisions.md（Q8・Q9・R3・R4・R8・R15・R49・R50）の意図に一致する。最終定理（`desugar_typed`・`surface_effect_soundness`・`checkProgram_sound` など）のファイルと Core/Release は差分がない。前提の弱化と新しい仮定は見つからなかった。軽の指摘は、文書の書き方の明確化と、B10a-3 への申し送りである。G4 を閉じて B6 へ進むことを妨げる指摘はない。

## 観点ごとの確認

### 1. DieShowOk・説明・E の Show 辞書・Option

- `Surface/Typing.lean` の `DieShowOk` は `DictEv.HasType … dict (.dict cl errorTy)` で辞書の対象をエラー型 E に結び付けている。成功型 T とは取り違えていない。同じ cl の宣言からメソッドを引き、`tparams = []`・`neffs = 0`・`names = ["x"]`・`params = [.tvar 0]`・`ret = String`・`eff = Eff.empty` を要求する。`Lemmas/ReturnTry.lean` の `tryResultDie_typed` は、`C_Meth` に型引数 `[] ++ [et]` を与えて `.tvar 0` を E に具体化する。したがって `.tvar 0` がクラスの対象型を指すことは、コアの規則と整合する。
- 辞書は元の Γ で型付けする（継続を隠さない）。辞書の変数が継続になることはないので問題ない。
- Option の規則（`E_TryOptionDie`）は辞書もメソッドも持たず、`DieShowOk` を要求しない。design.md の表「Option は不要」と一致する。
- 説明は `hideConts Γ`・R = none・`.other`・String・`Eff.empty` で型付けする。`E_ReturnTail`・`E_ReturnOther`・`E_TryResult`・`E_TryOption` は R = some を要るので、直接の return と裸／明示 return の try は型付けできない。`E_Resume` は Γ の継続を要るので、`hideConts` のもとで外側の resume は型付けできない。`E_Sub` はエフェクトを広げる向きにしか働かないので、`Eff.empty` の要求を迂回できない。ラムダは `binds ps ++ hideConts Γ`・`some r` で自分の境界を作る。R15 の「内側の lambda は通常の return 境界を持ち、外側の resume は使えない」と一致する。
- 純粋性の条件から、ガードと lazy の直接の本体の die は、`Process.Exit` を含むので型付けできない（既存の禁止を保つ）。

### 2. HasType の新しい規則（R・T・エフェクト）

- `E_TryResultDie`・`E_TryOptionDie` は R を前提にも結論にも制限しない。入力 e は同じ R・`.other` で型付けする。このため `try (try r or return) or die` の内側の `or return` は囲む関数の R を使い、design.md の境界の表と一致する。
- 結論は `t` と `Eff.union ε (Eff.single "Process.Exit")` であり、Q8 の答え A（任意の関数で使え、Process.Exit が加わる）と一致する。
- `DieExitOk` は種類 exit・所属 `Process.Exit`・型引数 1・エフェクト引数 0・`NamesWF`・`admits C [t]`・具体化後の `(code: Integer) -> t ! {Process.Exit}` を要求する。Never 型と新しい操作は加えていない（Q8・R4）。
- 既存の `E_TryResult`・`E_TryOption` は変更していない。Show のない E の伝播は従来どおり受理する。
- `Expr.Exits` は `| _ => False` で die を「必ず抜ける文」に数えない。`CheckPredicates.exprExits` も同じである（design.md「die を必ず抜ける文とは判定しない」）。

### 3. 脱糖の評価順・自由変数・辞書

- `Desugar.lean` は入力を一つの `letIn` に脱糖し、成功の分岐を `ret (var 0)` とする。失敗の分岐だけに `dieFailure` を置く。入力の計算は一度だけであり、成功時には説明も表示も計算しない（R3）。
- `dieFailure` は、説明があれば「説明の let → 原因の let（+1 で移す）→ `exit[t](1)`」、なければ「原因の let → exit」とする。01-12 の表の四行と一致する。
- 番号の移し方: Result の失敗の分岐では入力と Error の二つの束縛があるので、辞書を `+2`、説明を `+depth = 2` で移す。説明の let がある場合は、原因の計算全体をさらに `+1` で移す。Option は束縛が一つなので `+1` で移す。原因の `var 0` は Error の束縛を指す。正しい。
- `dieMessage_typed` は、R = none・空のストアで型付けした説明を `withReturn` で任意の R へ移し、`hideConts Γ` から `xs ++ Γ` への付け替えで型を保つ。既存のハンドラと解放の規則は Release 側にあり、変更していない。die に専用の遷移はなく、既存の `E_Exit`（`NoHandler`・`ioResponse`）に委ねる。R4 の「操作を増やさず既存の exit に乗せる」と一致する。

### 4. 最終定理への接続

- `Lemmas/Typing.lean` の `HasType.desugar` は、新しい二つの場合を `tryResultDie_typed`・`tryOptionDie_typed` へ渡す。説明の型付けは、`hΓ.hide` と R = none の clean 条件から導いている。新しい外部の仮定は置いていない。
- `Scoped.lean`・`Invariants.lean`・`CheckSupport.lean`（AtomsIn）・`WellFormed.lean`（Scoped）は、T・辞書・入力・任意の説明をすべて扱う。
- `CheckSoundDie.lean` の `checkDieShow_sound`・`checkDieExit_sound`・`checkDieMessageR_sound` は、`Input.Sound` と原子の範囲だけを前提として `DieShowOk`・`DieExitOk`・説明の型付けを導く。`tryResultDie_case`・`tryOptionDie_case` は既存の `CaseSound` の形のままであり、`checkCasesSound` の振り分けに加わっている。
- `Surface/Theorems.lean`・`CheckSound`・`CheckInduction`・`CheckProgramSound`・`CheckTablesSound`・Core・Release は、基準と比べてファイル全体に差分がない（`git diff --stat` で確認）。最終定理の言明は変わらず、帰納型が広がったことで、die を含むプログラムも定理の対象に入る。
- checker の条件は型の規則より強い（原子集合に `Process.Exit` があることを要求する）。健全性の向きでは問題ない。

### 5. 交換形式（corpus 10）

- `Exchange/Syntax.lean` は裸の `tryResult`/`tryOption`、明示の `tryResultReturn`/`tryOptionReturn`、`tryResultDie`/`tryOptionDie` をタグで分ける。`checkTryFields` は try のタグに属さない欄と、タグの横に別の欄がある入力を拒否する。die の欄は `getObjVal?` によってすべて必須であり、説明なしも `message: null` が要る。R50 と一致する。
- `Exchange/Version.lean` は、corpus が 10 未満なら新しい四つのタグを `rejectFields` で再帰的に拒否する。9 は互換入力として通し、8 は従来どおり閉じた既定を補う。新版の欄を既定値で補ってはいない。型表との組は `version >= 9` と型表 3 で照合する。
- `Convert.lean` は明示 return を既存の表層の規則へ写す。`lambdaEffects` は入力 → 説明の順に辿り、脱糖したコアの中のラムダの順（入力の let → 失敗の分岐の説明）と一致する。
- `SurfaceCheck/Walk.lean` は入力を子 0、説明を子 1（R = none・String を期待）として辿る。型の規則と一致する。

### 6. 01-12・07-04 の写し

- 01-12「die の先行モデル」の二つの規則の前提と結論、`DieShowOk`・`DieExitOk` の条件、説明の条件、脱糖の表、番号の移し方は Lean と一致する。
- 07-04 の交換契約の記述と「01-12 との対応」の表の行は、Lean の実装と一致する。保証しないもの（停止、必ず終了操作に達すること、終了状態と引数の対応、報告の一回性、標準束縛への名前解決）を明記しており、過大な記述は見つからなかった。表現の細部を軽の指摘 L2・L3 に挙げる。

## 指摘

### 重大

なし。

### 中

なし。

### 軽

**L1 `Surface/Syntax.lean` の `Expr.tryResultDie` のドキュメントコメントが古い**

- 場所: `formal/Benitoite/Surface/Syntax.lean` の `Expr.tryResultDie` の `/-- … -/`。
- 問題: 「型付けと checker の受理はまだ加えない」は B1 の時点の記述である。B2・B3 で型の規則と checker の受理を加えたので、今の定義と食い違う。
- 修正案: 「型付けは `E_TryResultDie`・`E_TryOptionDie`、検査は `checkExprR` の die の場合で行う」に書き換える。あわせて「処理系に未接続」の一言を残す。

**L2 01-12 の「`surface_effect_soundness` は…両場合を含む」の範囲を補う**

- 場所: `docs/design/01-spec/01-12-core-calculus.md`「die の先行モデル」の最後の段落。07-04 の対応表の die の行の「表層のエフェクト健全性」。
- 問題: `surface_effect_soundness` は純粋な main を前提とする。このため die がこの定理の対象になるのは、`Process.Exit` を main の内側のハンドラが処理する場合だけである。die の主な使い方（main が `uses Process.Exit` を持つ）について、エフェクトの追跡が保証されるのは型保存（`desugar_typed` の EffectsOk）の側である。いまの書き方では、終了するプログラムでもエフェクト健全性の定理が成り立つと読める。b5/contracts.md にはこの限定が書いてある。
- 修正案: 01-12 に一文を足す。「`surface_effect_soundness` は純粋な main を前提とするので、die について主張するのは、`Process.Exit` を内側のハンドラが処理する場合に限る。`Process.Exit` を持つ main の停止は主張しない。」

**L3 01-12 に交換形式と Rust への接続の状況が混じっている**

- 場所: 01-12「die の先行モデル」の最後の段落の後半（「交換形式 corpus 10 は…」から「Rust の die には未接続である」まで）と、冒頭の「処理系に未接続の」。
- 問題: AGENTS.md の規約で、`01-spec/` には処理系の実装方式に依存する記述を入れない。交換形式・六入口・Rust への接続の状況は、07-04 の交換契約と対応表に同じ内容がすでにある。
- 修正案: 01-12 からは交換形式と Rust の状況の文を除き、「交換と処理系への接続は 07-04 に従う」の一文で参照する。B11 で本番の受理を有効にするときに、01-12 の「処理系に未接続」も外す必要があるので、記述を 07-04 に集めておくと後の直しが一箇所で済む。

**L4 説明の中の try の扱いについて、モデルが Rust より広い場合を書き添える**

- 場所: 01-12「die の先行モデル」の「直接の try 全般を説明から除く字句・構文の制限は、モデルの型付けの外側である」。
- 問題: 実際のモデルでは、説明の中の裸／明示 return の try は R = none で、die はエフェクトが空でないことで型付けできない。例外は、説明の中の `handle` が `Process.Exit` を処理する場合だけである。この場合だけモデルは受理し、Rust は parser の E0218 で拒否する。いまの書き方では、モデルが説明の中の try をまったく制限しないように読める。
- 修正案: 「モデルの型付けは、説明の中の die の try を、説明の中のハンドラが `Process.Exit` を処理する場合に限って受理する。そのほかの直接の try は型付けできない。説明の中の try をすべて禁じるのは parser の検査である」と書く。

**L5 B10a-3 への申し送り: 表示のクラスと exit が標準の束縛であることの照合**

- 場所: `Surface/Typing.lean` の `DieShowOk`・`DieExitOk`（R49 の抽象名）。`Exchange/CheckInput`・`BuiltinCheck`。
- 問題: R49 のとおり、型の規則は「純粋な一引数の String のメソッドを持つ任意のクラス」と「種類が exit の任意の組み込み」を受理する。標準の Show と `Process.exit` を選ぶ正しさは、Rust の名前解決に任せている。01-12 にもこの範囲は明記されている。ただし、Rust が別のクラス（同じ形のメソッドを持つ利用者のクラス）を書き出しても、Lean の六つの入口では検出できない。
- 修正案（規則は変えない）: B10a-3 の Rust の書き出しのテストか `test_try_exchange.py` に、次の照合を加える。die の `dict` のクラスの識別名と `showMethod` が、stdlib の型表の Trait.Show の BindingId から作った識別名と一致すること。`exit` が組み込みの表の `Process.exit` であること。

## 確認した範囲と、確かめていないこと

- 読んだもの: 段 3 の design.md、decisions.md の Q8〜Q10・R3・R4・R8・R14〜R16・R48〜R51、b5/contracts.md・results.md・G4-request.md。Lean の差分のうち `Syntax`・`Typing`・`Desugar`・`WellFormed`・`Check`・`CheckSoundDie`（補題の言明）・`CheckSoundControl`・`CheckPredicates`・`CheckSupport`・`Lemmas/{ReturnTry,Typing,Scoped,Invariants}`・`Exchange/{Syntax,Version,Convert}`・`SurfaceCheck/{Walk,Main,Batch}`・`BuiltinCheck/Main`。`CheckExamples.lean` の die の例の一覧。01-12・07-04・`check-formal.sh` の差分。
- 確かめていないこと: 証明の本体、`Examples.lean` の各例の中身、corpus 10 の JSON と `test_try_exchange.py` の個々の入力、ビルドと公理の監査（B5 の記録を前提とした）。`checkDieMessageR_sound` は `.strict` の状態についての言明である。ハンドラの節の探索の状態での健全性は、既存の誘導の仕組みに従うものとして詳しく追っていない（ビルドが通ることは B5 で確認済み）。

## 対応

- L1: `Surface/Syntax.lean` の古いコメントを、二つの型付け規則と `checkExprR` による検査の説明へ直し、処理系には未接続であることを残した。
- L2: 01-12 と 07-04 の対応表に、`surface_effect_soundness` の純粋な main の前提と内側のハンドラによる処理の条件を補い、`Process.Exit` を持つ main のエフェクトの追跡は `desugar_typed` の `EffectsOk` が保証することを明記した。
- L3: 01-12 から交換形式と Rust への未接続の状況を除き、07-04 への参照にまとめ、交換の変換自体は証明の対象外であることも 07-04 に集約した。
- L4: 01-12 に説明内の直接の try を型付けできる条件を補い、07-04 にモデルが受理する場合も Rust の parser は E0218 で拒否することを明記した。
- L5: 今回は照合を実装せず、B10a-3 の完了条件に標準の `Trait.Show` のクラス・メソッドの識別名と組み込みの `Process.exit` との照合を追加した。
- 重大・中の指摘がないため、オーケストレータの判断で G4 を閉じ、上記「変わる規則の要点」を設計者に示した。
