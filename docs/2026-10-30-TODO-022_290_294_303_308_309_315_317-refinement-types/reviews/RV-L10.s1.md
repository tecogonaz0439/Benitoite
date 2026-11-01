# RV-L10.s1 レビュー記録

判定: **条件付き可**。所見は重0、中1、軽5の計6件である。五つの境界（主な定理の前提・結論、公理、提供範囲、利用者の書ける形、精密な外部状態）に触れる所見はない。

対象はブランチ `m014/l10.s1` の未コミットの作業ツリー、基準は `78aa5cca81cf24a420c266e6b714934297ce434e` である。補助の入力は `<tmp>/rvl10s1/` に置いた。リポジトリのファイルは本記録のほかに変えていない。

## 所見

### 中1: 有限比較が整礎再帰で、カーネルで計算できない

- 箇所: `formal/Benitoite/Release/Refinement/FiniteCompare.lean` 105〜151行の `tyCompareWith` 四族。`Finite.lean`・`FiniteFunctionView.lean` の実行経路が同じ影響を受ける。
- 問題: 四族に `termination_by structural` がなく、整礎再帰になっている。旧 `Release/Finite.lean` の同名の比較は構造再帰で、`Surface/FiniteExamples.lean` は `effEq … = true := rfl` の形で検査器の例を確かめている。新版では `rfl` も `decide` も止まる。`#eval` では動くので detail の「def として実行可能」は満たすが、後段が旧の例を移すときと、plan の O023 が区別するカーネルでの証拠に使えない。担当は boundary の例を `cbv` で閉じており、この差を結果に書いたが、後段への影響を申し送っていない。
- 再現: 再現した。`rv-s1-t1.lean` は `tyCompareWith [] .bytes .bytes = .eq` の `by decide` が止まり、`rv-s1-t2.lean` は同じ式の `rfl` が型の不一致で失敗する。
- 修正案: 四族それぞれに `termination_by structural a _ => a` を足す。`rv-s1-t7.lean` はこの4行だけを変えた写しで、`rfl` と `decide` が通り、450場合の一致の証明もそのまま通った。`rv-s1-t10.lean` は `FiniteFunctionView` と `Finite` を続けた写しで、全証明が通り、`Eff.normWith` の Fail の整列と `fnViewWith?` の受理・拒否も `decide` と `rfl` で計算できた。

### 軽1: `viewSupport` の和は候補を増やさず、実行だけを遅くする

- 箇所: `FiniteFunctionView.lean` 45〜46行の `viewSupport`。
- 問題: `collectAtoms s` の原子は `s.filter` の結果なので、`s ++ t.collectAtoms s ++ f.toTel.collectAtoms s` は集合として `s` と同じである。`s` に足りない原子を和が補うことはない。一方で列は重複で伸び、`firstDifference` と `finiteEncodeAtoms` が列の長さの2乗で走査する。支持の一致は `fnParts_support` と `support_toTel_iff` から `s` だけで成り立つ。detail の「入力と候補の収集の和」は、`s` を受け取らない形で書いた予定の名残と読める。
- 再現: 再現した。引数160個・候補40個で `rv-s1-t5.lean` は 13,655 ms、比較の候補を `s` だけにした `rv-s1-t11.lean` は 186 ms である。t11 は時間の測定だけのもので、`viewSupport_input` など二つの補題が未修正の型の誤りになる。t5 は引数の数を2倍にすると約6倍になる（40個で237 ms、80個で1,477 ms。候補10個）。
- 修正案: 比較の候補を `s` にし、`viewSupport` と二つの補題を消す。detail の一文との差を結果に記す。

### 軽2: 関数の見方の一致の前提は、実際には不要と見られる

- 箇所: `Tel.fnViewWith?_eq_some_iff`、`Tel.fnViewWith?_eq_fnView?`、`Ty.foldFnWith_eq_foldFn`。
- 問題: 再構築の比較の両辺で、効果の所属関数は同じ位置に同じ関数が来る。`renameValues` が所属関数を変えないためである。したがって比較の結果は候補によらず、候補不足でも `fnViewWith?` が偽の一致を返すことはない。反例が出ないので不具合ではないが、`Ty.Support` の前提は L20 G07 に余分な供給を求める。所属が全域の効果 `fun _ => true` は支持の前提を満たさないのに、受理も拒否も正しく動く。
- 再現: 不具合としては再現しない。`rv-s1-t1.lean` の9例は候補ありと候補なしで同じ結果であり、`rv-s1-t8.lean` の全域の効果の2例も正しい。一般の定理は証明していない。
- 修正案: G07 で前提の供給が負担になれば、前提なしの一致を足す。今の言明は detail どおりなので、本群で必須とはしない。

### 軽3: `typeEnvAt` の単一原子の条件は、行の像から導ける

- 箇所: `TypeSupport.lean` 284〜313行の `typeEnvAt_support`、`Ty.substAt_support`、`Eff.substAt_support`。
- 問題: 仮定 `ha` は真で空虚ではない。ただし `typeEnvAt` は `ranges = []` なので名前の原子を変えず、行の原子は自身か行の像へ写る。`∀ x, p x → q x` と行の支持があれば `ha` は導ける。旧 `substAt_support` の同じ支持の形も成り立つ。今の形では読者ごとに `Eff.mem_rawBind` を開くことになる。結果の「原子の像が変わる条件」という説明は一般の `SubstEnv` には正しいが、`typeEnvAt` には当たらない。
- 再現: 証明で確かめた。`rv-s1-t9.lean` の `typeEnvAt_atom` と `Ty.substAt_support_same` は通り、公理は許可する三つだけである。
- 修正案: この二つの補題と Eff 版を本番へ足す。detail の言明は変えない。

### 軽4: `Atom.code` の桁数が経路の段数に対して指数的に増える

- 箇所: `Order/Range.lean` の `wordCode`（`natPair` の入れ子）を読む `finiteAtomsCompare`、`finiteEncodeAtoms`。
- 問題: 段ごとに桁数がほぼ2倍になる。符号の順序そのものは既存の定義であり、本群の誤りではない。ただし新しい実行経路で初めて実際に計算され、`finiteEncodeAtoms` が候補ごとに `a.code` を計算し直す。Rust の `crates/benitoite/src` に `natPair` はなく、処理系の写しの妨げにはならない。影響は Lean の検査器の差分入力に限られる。
- 再現: 再現した。`rv-s1-t4.lean` で段数22の符号は約3.8億ビットである。`rv-s1-t6.lean` の一回の比較は、段数16で156 ms、20で4.8秒、22で22秒、24で96秒である。
- 修正案: 本群では順序を変えない。候補の符号を一度だけ計算する形を、軽1の修正と合わせて検討する。L70 の差分入力の設計へ、深い経路が実行時間を支配することを申し送る。

### 軽5: 記録と設計書の字句

- `l10/s1/results.md` 87行は署名の直接検査を警告0と書くが、`verification.json` の `signatures.warnings` は77である。出力はすべて `linter.defProp` の警告で、検査の意味は変わらない。記述を直す。再現: `signatures-output.txt`。
- `results.md` 61行は候補の「順」からの独立を実例と書くが、`boundary001` の二つの候補の列は順の入れ替えを含まない。定理は一般なので誤りはない。実例の説明を直すか、順を変えた例を足す。
- `docs/design/01-spec/01-12-core-calculus.md` の支持の段落に「持たないため 篩を」の余分な空白がある。同じ段落の「型変数の移動…でも変わらない」は、Lean では移動の保存の向きだけを証明している。「保たれる」と書くか、値の改名と書き分ける。

## 確かめて問題がなかった重点

- 一致の定理: 比較・`fnViewWith?`・`foldFnWith`・`normWith` の一致を読み、新規5モジュールを直接に再検査した。前提は両入力の支持であり、空虚ではない。`boundary003`・`boundary004` の負例は計算の結果を証明しており、結論を仮定していない。
- 候補不足: `normWith` は Fail を黙って一つに併合する。これは支持の外の振る舞いで、定理の適用外である。所属関数の支持は一般に計算で判定できないので、利用先が旧 Surface の `AtomsIn` と同じ不変量を証明で持つ必要がある。旧にある `union_support` などの効果の構成の支持は `Surface/FiniteTools.lean` にあり、L70 の移植の範囲になる。
- 計算できること: `execution-path.lean` の方法は、証明の定数を除いて定義を辿り、`Classical.choice` まで届くものを拒むので十分である。別法として、コンパイル後の IR の呼び出し先を11入口から辿った（`rv-s1-t8.lean`）。210宣言に `Classical`・`Ty.norm`・`Ty.foldFn`・`fnView?`・`encodeAtoms` はなく、`Term`・`Pred` の `noncomputable instance` の `DecidableEq` もない。`#print axioms` に出る `Classical.choice` は `NatCode` の単射性などの証明に由来する。構造再帰にしても表示は変わらない。
- 比較の450場合: 非対角は順位の比較の一つの枝にまとまり、指数的な再計算はない。`firstDifference` も再帰は一度である。`FiniteCompare` の再検査は5.5秒である。
- `SupportTransport`: `up` の閉性、`rawApply`、`Tel.param` の下の `θ.up` を読んだ。`shiftTypes` と公開 `shift` の対応は `rawBind_shiftTypes` を通る。旧 `rawShift` 三件の写しは正しい。
- `fnView` の候補: 一束縛ずつの逆移動を、外の変数の参照、前の引数への依存、Fail の内部の依存、入れ子の依存列の内外、深さ2の依存、空の列で試し、受理と拒否は予想どおりであった（`rv-s1-t1.lean`）。依存の変数は `unshiftValue` で潰れても再構築で検出される。
- 述語と型の中の効果: `Term`・`Pred`・`RangeExpr` に `Ty`・`Eff` はなく、述語を支持へ数えない判断は正しい。
- 本番追随: 17件は FND133〜135、136〜140、141〜146、024〜026、残2件は FND027・028 で detail と同じ宣言である。有限版12件は FND009〜012、016〜023、棚卸し外13件は F01・F02・F06〜F16 で、重ねて数えていない。detail の処分の行で .33〜.37 と .43 は31件、L10 の全行は99件、.38〜.42 は0件である。残りは 99−31=68件である。
- `A_17`・`c_g`: 未取得の記録は plan の「分離できなければ未取得」に合う。旧見込みを保ち、.37 で N_g=0 とし、他の群へ外挿していない。O160 の見込みの更新の欄は取りまとめの転記が残る。
- 五つの境界: 既存の formal の変更は `Benitoite.lean` の import だけで、主な10言明は不変である。独自公理と `sorry` はない。
- 件数とハッシュ: 636=136+79+288+29+104、654=636+18、796=654+99+43 である。署名の99件は signatures.md と signatures.lean で一致する。既定ビルド765ジョブ、新規5モジュールと 01-12・`Benitoite.lean` のハッシュを再計算して一致を確かめた。絶対パス、`docs/todo` へのリンク、`work/` の参照はない。
- 設計書: 01-12・07-04・用語集の記述は Lean と一致し、軽5のほかに食い違いはない。

## 補助の入力

- `rv-s1-t1.lean`: 受理・拒否の9例と `decide` の停止（意図した誤り1件）
- `rv-s1-t2.lean`: `rfl` の失敗（意図した誤り1件）
- `rv-s1-t3.lean`: Fail なしの計算と `NamesWF` の `decide`
- `rv-s1-t4.lean`、`rv-s1-t6.lean`: 符号の桁数と比較の時間
- `rv-s1-t5.lean`: 引数と候補の数に対する時間
- `rv-s1-t7.lean`、`rv-s1-t10.lean`: 構造再帰にした写し
- `rv-s1-t8.lean`: 全域の効果の例と IR の依存
- `rv-s1-t9.lean`: 単一原子の条件の導出
- `rv-s1-t11.lean`: 候補を縮めた時間の測定（補題の誤り2件を含む。証拠は時間だけ）

## 取りまとめの追記

2026-11-01。補助の入力は `l10/s1/rv-s1-t1.lean`〜`t11.lean` へ写した。中1は `termination_by structural` を足す。軽1は比較の候補を `s` にする案を採る。軽3は補題を本番へ足す。軽5は記録と文書を直す。軽2は G07、軽4は L70 の差分入力へ申し送る。五つの境界に触れないので、plan.md の判断の行は足さない。見込みの再計算は L10 の段末に実績をまとめて扱う。
