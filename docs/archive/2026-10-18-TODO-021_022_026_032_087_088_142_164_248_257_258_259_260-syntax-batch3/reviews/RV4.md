# RV4 独立レビュー（段4 M1・B1〜B3、A1、段5 G1〜G4）

対象は二つの差分である。

- `git diff 6f60cd22 90c87a93`（M1・B1〜B3）
- `git diff 7f431373 ebfd0e26`（A1・G1〜G4）

7f431373 の記録だけのコミットは対象から除いた。作業ディレクトリは、san_benito の ebfd0e26 を detached で取り出したものである。コード・文書・Lean の定義を読んで確かめた。cargo build・cargo test・lake は実行していない。実行結果についての判断は、m1・b1〜b3・a1・g1〜g4 の results.md と、それぞれが保存した比較資料に拠る。以下では、コードで確かめたことと推測とを分けて書く。

## 結論

**中の指摘を版の公開候補の前に直す条件で、次の段（文書例の H1〜H3）へ進んでよい。**

段4と段5について、コードで確かめたのは次の点である。

- 構築器の脱糖（`ir/desugar/builders.rs`）は、Lean の `builderFinish`・`builderCombine`・`builderNew` と、束縛の順序・範囲がそろっている。順序は、引数の一度だけの評価、get、純粋な合成、set の順である。
- 捕捉境界は、ラムダ・lazy・部分適用・handle の節の四か所で、名前解決が境界を置き換えている。
- 局所交換は、Rust の出力から期待を作っていない。0件や入力の欠落は manifest の件数で失敗になる。
- M1 の件数の更新は、厳密な等値を保っている。
- G4 の limitReached の期待の変更は、design 11.2 の新しい契約に沿っている。既知の Done で false になる例も残っている。

一方、構築器の完全な名前が import なしで通る（中1）。また、A1 の長い連鎖のテストに、実測値に近い壁時計の上限がある（中2）。さらに、構築器の説明に独自の語「local classification」を使い、用語集にも登録していない（中3）。中1〜中3 は H 系と独立しているので、並行して直してよい。

指摘の数は、重0・中3・軽6 である。

## 重

なし。

## 中

### 中1 構築器の完全な名前 `Benitoite.StringBuilder.…` が、import なしで受理される

- ファイル: `crates/benitoite/src/resolve/builders.rs` 188〜225 行（`builder_special`）。特に 193〜203 行。
- 問題: 先頭が `Benitoite` のとき、`self.modules` から `["Benitoite", 名前]` の標準モジュールを探し、その場で専用名として受理している。`self.modules` は、プログラムのどれかのモジュールが import したために読み込んだ全モジュールである（`modules/load.rs` は、prelude 以外の標準モジュールを import されたときだけ読み込む）。そのため、モジュール A が `import Benitoite.StringBuilder` と書けば、import していないモジュール B でも `bind b: Benitoite.StringBuilder <- Benitoite.StringBuilder.new()` が通る。通常の名前の引き方では、根 `Benitoite` の子は prelude の名前に限る（`resolve/lookup.rs` の `children` の `NamespaceRoot` の分岐）。したがって、`Benitoite.Regex.compile` のような完全な名前は、import していても通らない。構築器だけが、この規則の例外になっている。
- 根拠: 01-03「標準ライブラリの名前空間と prelude」は、「prelude でない標準ライブラリのモジュールは、import しなければ使えない。import なしに完全な名前で書くこともできない」と定める。design 7.1 は「明示importする」「import別名もModuleIdで照合する」と定める。設計原則 1 にも当たる。複数モジュールでの再現は実行していないが、上の二つのコードの経路から確かめた。この形を使うテストは見当たらない（`git grep 'Benitoite\.\(String\|List\|Bytes\)Builder\.'` で該当なし）。
- 修正案: 根 `Benitoite` から始まる経路を `builder_special` から外し、import した名前（別名を含む）の `upper` による解決だけを受理する。外した経路は通常の解決へ渡し、既存の未解決の名前の診断に任せる。named_arguments の構築器の表に、次の二つの負例を加える。
  - 単一モジュールで、import なしに完全な名前を書く例
  - 二つのモジュールのうち、一方だけが import する例

### 中2 長い const 連鎖のテストの壁時計の上限（10 秒）が、実測（約 7.8〜8.0 秒）に近い

- ファイル: `crates/benitoite/tests/call_allocations.rs` 154〜197 行（`long_constant_chain_has_bounded_check_allocations`）。特に 193〜196 行の `elapsed < Duration::from_secs(10)`。
- 問題: a1/results.md によれば、このテストは局所で 7.82 秒、作業末の work で 7.95 秒かかった。初回が 10 秒未満だったため、長いテストにしていない。最適化しないビルドで、上限まで 2 秒の余裕しかない。そのため、負荷の高い機械、並行する別の cargo、特殊構成（heap-verify など）で実行すると、退行がなくても失敗しうる。確保量の上限（512 MiB 未満。実測 316.6 MiB）は機械の速さに依存しないので、二乗の退行を捕まえる役目はこちらで果たせる。
- 根拠: AGENTS.md「テストの運用」は、10 秒を超えるテストを加えるときに、長いテストにするかを考えるよう定める。07-03 のテストの設計の原則も、環境に依存して結果が揺れる検査を避ける立場である。推測: 640 KB のソースの check に 8 秒かかるので、一宣言あたりの費用が大きいか、連鎖のどこかに線形を超える費用が残っている可能性がある。今回は計測していない。
- 修正案: 壁時計の assert を外すか、修正前の二乗の時間とはっきり区別できる程度の大きな値にする。その上で、二乗の退行の検出は確保量の上限に任せる。時間も測るなら、`#[ignore = "long: ..."]` を付けて change の long_only へ回す。あわせて、連鎖の長さを 1 万と 2 万にしたときの確保量の比が 2 倍程度であることを確かめると、機械に依存しない線形性の検査になる。

### 中3 構築器の説明が独自の語「local classification（局所分類）」を使い、用語集にも登録がない

- ファイル: `docs/reference/benitoite.md` 1606 行・1627 行。`crates/benitoite/src/prelude/stdlib/{String,List,Bytes}Builder.bnt` 3 行と、そこから生成した `skill/references/stdlib/*Builder.md` 7 行。`docs/design/01-spec/01-06-type-system.md` の「局所分類」。`docs/design/00-overview/00-04-glossary.md`（構築器・局所分類・ShrinkStep・二引数のクラスの項目がない）。
- 問題: 「通常の型として値に入れられず、宣言した関数の中でだけ直接操作に使える名前」の概念を、「local classification」と呼んでいる。他の言語のコミュニティで、この呼び名が使われている例を確かめられない。利用者と LLM が最初に読むリファレンスと Skill に出る語であり、何を意味するかを本文の外から推測できない。また、用語集に定義がないため、章をまたいで同じ語で揃っているかを照合できない。
- 根拠: 設計者の方針として、新しい概念の名前には他の言語のコミュニティの呼び名を調べて使う（「opaque type＝不透明型」と同じ扱い）。AGENTS.md「文章の規範」は、用語を 00-04 の定義に揃えるよう定める。推測: 近い既存の呼び名に、Osvald ほかの「second-class values」（OOPSLA 2016、"Gentrification gone too far? affordable 2nd-class values for fun and (co-)effect"）がある。ただし、この出典の内容と適否は確かめていない。
- 修正案: 設計者に呼び名を確認する。候補は「second-class value（第二級の値）」、または語を作らず「not a first-class value: it cannot be stored, returned, or captured」と性質で書く形である。決めた呼び名を、00-04 に原語とともに加える。あわせて、構築器（builder）・ShrinkStep・二引数のクラス（Functor2 など）の項目も加える。英語リファレンス・doc だけの三つの標準ソース・01-06 を同じ語へ直し、gen_skill で作り直す。docs/ja は V1 で揃える。

## 軽

### 軽1 const 由来の補助位置の走査は、診断ごとに連鎖全体を辿る

- ファイル: `crates/benitoite/src/typeck/checked_args.rs` 240〜272 行（`origin_labels`）。
- 問題: 保存は直接参照だけになり、確保は線形になった（RV3 中1 の修正として正しい）。しかし、補助位置を選ぶ走査には記憶がない。同じ長い連鎖の末端を引数にした E0457 が M 件あると、時間は O(連鎖の長さ × M) になる。Regex の結果はキャッシュされるが、診断は呼び出しごとに作られる。Scope の診断も同じである。推測（未計測）: 2 万個の連鎖と 2 万件の呼び出し（ソースは合計 1.3 MB 程度）で、数億回の集合操作になる。
- 修正案: 直接参照の集合を鍵にして、`(選んだ位置, 省略数)` を `CheckedArgsState` に覚える。または、一回の走査で訪問する数に上限を設け、超えた分は「N or more」と表示する。

### 軽2 「opaque representation」の旧い語が、診断の説明とリファレンスの見出しに残る

- ファイル: `crates/benitoite/src/diag/codes.rs` 1090 行（E0819 の説明 "An opaque representation cannot also be extensible or external."）、生成物 `skill/references/diagnostics.md` 2240 行、`docs/reference/benitoite.md` 786 行（見出し "### Opaque representations"）。
- 問題: R170 は、語を「不透明型（opaque type）」に統一した。しかし、この二か所は A1 の前から残っていて、直されていない。E0819 の説明は、新しい定義では外部の型も不透明型に含まれるため、「不透明なものは外部にできない」と読めて矛盾する。
- 修正案: E0819 の説明を "`@opaque` cannot be combined with `@extensible` or `@external`; an external type is already opaque." のように改める。見出しを "### Opaque types" に改める（見出しへのリンクはない。`git grep` で確かめた）。gen_skill で作り直す。

### 軽3 decisions.md に R170 が二つある

- ファイル: D/decisions.md 1382 行（RV3中2の不透明型）と 1403 行（G1の開始版）。
- 問題: 同じ番号が別の決定を指している。g1/results.md と plan.md の「R170」がどちらを指すかは、文脈で読み分けるしかない。
- 修正案: G1 の決定を空き番号（R176 など）に振り直し、g1/results.md・plan.md の G1 行の参照を同じ変更で直す。

### 軽4 英語リファレンスの構築器の節の見出しと、上限超過の説明

- ファイル: `docs/reference/benitoite.md` 1604 行（見出し "Function-local string builders"）、1625 行。
- 問題: 見出しは String だけを指すが、節は List・Bytes も扱う。また "A size-limit failure during concatenation leaves the contents unchanged." は、上限超過で実行全体が止まり（既存の Stop）、内容を観察する手段がないことを書いていない。そのため、失敗の後も処理を続けられると読みうる。design 7.3・B2 の R167 は、実行を終えることを前提にしている。
- 修正案: 見出しを "Function-local builders" に改める。説明を "A size-limit failure stops the run with the existing runtime error; the builder is never left partially updated." のように改める。

### 軽5 トップレベル const の評価の受理の境界が、由来の計上で変わった

- ファイル: `crates/benitoite/src/typeck/consts.rs` 90 行（`EvalBudget::traced()`）、1277〜1281 行（初めて参照した const ごとの 64 バイトの `charge`）。`docs/design/02-impl/02-05-typechecker.md` 380 行。
- 問題: トップレベル const の評価は、全 const で共有する予算を使う。直接参照の保存の 64 バイトは、この予算にも計上される。そのため、const どうしの参照が多いプログラムは、以前より早く E0435（budget）になる。ここまでは R169 どおりで、実用上の影響は小さい（およそ 100 万の参照の組が要る）。ただし、02-05 は計上先を「取得予算」と書いており、追加検査の `CheckedArgsState` の 64 MiB と、トップレベル const の予算のどちらを指すか読み分けにくい。
- 修正案: 02-05 の該当文を、「トップレベル const の評価ではその共有予算に、追加検査の取得では `CheckedArgsState` の予算に計上する」と書き分ける。

### 軽6 縮小の Yield の経路は、上限近くの駆動を新たに確かめていない

- ファイル: `crates/benitoite/src/prelude/stdlib/Test/Property.bnt` 461〜484 行（`advance`・`tryCandidates`）。`crates/benitoite/tests/property_library.rs` 696〜721 行（long テスト）。
- 問題: long テストが駆動するのは、合成した Skip 列（advance と tryCandidates の Skip の分岐）だけである。Yield から Ok の後の `advance` と、Error の後の `reduce` は、ネストした match の分岐の末尾から呼ぶ。この経路は、maxShrinks の上限（10 万）近くまで駆動していない。構造は旧版の tryCandidates と同じであり、退行ではないと判断する。しかし、design 11.2 と R128 の「上限に近い駆動でもスタックが溢れない」の確認は、Skip の経路だけになっている。
- 修正案: 次のどちらかを行う。
  - Yield(Ok) が 10 万回続く例と、Error の再開が続く例を、同じ long テストに表として加える。
  - 07-04 か g4/results.md に、Skip の経路だけを確かめたことと、Yield の経路の末尾性を旧版の構造に依拠したことを書く。

## 観点ごとの確認の結果（指摘なし）

### 1. 構築器（String・List・Bytes）

- 評価順と get/set の順: `builder_operation` は `op.args`（型検査で `source_to_param` が 0 でない引数を AST の順に集めたもの）を `pending` へ一度ずつ評価してから get し、純粋な合成を `combine` の let に閉じてから set する（`ir/desugar/builders.rs` 82〜205 行）。Lean の `builderFinish` は `letIn get (letIn combine (set (i+2) var0))`、`builderCombine` は appendAll の String と append の Bytes でだけ内側の let を持つ。この形と一致する。`builderNew` の初期値の let と `Reference.new` も対応する。copy・length の形も一致する。
- Lean との対応: Rust の脱糖は名前付きの局所を使い、Lean は `i + ms.length` の移し替えで同じ位置を指す。`.local i → .var i` の扱いは、B3 の desugarDiff が 52 定義すべてで一致を確かめている。参照先の組み合わせは、Lean の `BuilderRefs.PureOk` のラベルと型に合っている。String は add・join・byteLength、List は append・concatenate・length、Bytes は empty・fromList・concatenate・length である。単一 Byte の追記は一要素の List を fromList へ渡す。
- 捕捉境界: `builder_boundary` を置き換えるのは次の四か所であり、design 7.2 の表と 01-12 の「空のΔ」の位置に一致する。
  - `resolve_lambda`
  - `resolve_lazy`
  - 穴を含む呼び出し（`resolve_call`。部分適用の呼び出し先と固定引数の両方を含む）
  - handle の各節
  
  try の説明、match のガード、with、if、handle の本体は、同じ境界を引き継ぐ。宣言の境界と使用位置の境界が違えば E0465、同じ境界での通常値としての使用は E0464、専用操作の値化・穴・パイプは E0466 になる。トップレベル const は宣言を持てず、純粋なので State を持つ操作を書けない。
- 継続・return・Fail・取消・安全点: 脱糖の後は、通常の let・Call・Reference だけになる。そのため、レジスタ・根・保存継続の扱いは既存の規則に乗る。b2/results.md によれば、resume/drop・早い return・Fail・子タスクの取消・先行 copy の lazy 捕捉を、Direct と Request の両モードで実行し、heap-verify と gc-stress でも各 27 件が成功した。
- 上限超過: 上限超過の前に set しないことは、verify の 4 契約が公開の脱糖の出力のデータ依存で確かめている。

### 2. 局所交換（B3）

- 独立の期待: 構築器の 5 定義は、L7 の手書きの変換元・期待コアと照合している。照合に使う参照名の対応は固定の表であり、Rust のコアから期待を作っていない。R168 の比較用の補正（fn:207 の未使用の引数、末尾 return の続きの型）は、元の注釈を固定値で確かめてから写しだけに加えている。独立入力の JSON は変えていない。
- 0件・欠落: `rust_inputs` は、入力別の定義数・表層の検査数・網羅性の件数を、作業ごとの profile の manifest と厳密に照合する。重複・対象外・除外・表の欠落も拒否する。check-formal.sh は `set -euo pipefail` の下で、次の三つを順に呼ぶ。出力先は実行ごとの `$output_dir` で、過去の出力を使い回さない。
  - 独立入力の検査
  - `--rust-dir "$output_dir/batch3/b3"` の検査
  - `check_batch3.py`
- 失敗の伝播: policy_selftest で確かめている。

### 3. 二引数クラス（M1）

- 実装: `Trait.bnt` の三クラス・三実装は、design 6.1 と一致する。apply は fs の Error を優先し、両方が Ok のときだけ関数を一度呼ぶ。
- 本番コード: 型検査・脱糖・VM の本番コードは変えていない。
- 件数の更新: R165 の件数は 9→12・60→63・62→65 で、厳密な等値のまま更新している。メソッド・上位辞書・束縛の対応の assert は残っている。
- 法則: 有限例の法則（恒等・合成・単位元・結合・apply と flatMap の対応）は、golden の `traits/monad2-result.bnt` で実行している。任意の実装についての証明には広げていない。

### 4. A1（RV3 の直し）

- 中1: const ごとに直接参照だけを `std::mem::take` で保存し、新しい要素ごとに 64 バイトを予算へ計上する。補助位置は、明示の積み重ねと訪問済みの集合で最大 8 件を選び、残りを note に出す。01-06・02-05 の記述と一致する（走査の時間は軽1、受理の境界は軽5）。
- 中2: 用語集・01-05・01-06・01-12・02 部・03 部の各章・英語リファレンス・手書きの Skill・診断の note は、「不透明型（opaque type）」に揃っている。等値の型の定義は、「等値を持たない組み込みの不透明型と外部の型を含まない」に揃っている。08-03 の Scala の調査の表にある「中身を見せない」は、Scala の機能の説明であり用語ではない。残りは軽2 の二か所である。
- 中3: `REGEX_PATTERN_COUNT = 256` を、キャッシュの件数（成功と失敗の両方）で判定する。キャッシュ済みの入力は、上限に達した後も再利用する。
- 軽1〜軽5:
  - 軽1: SKILL.md の非公式モジュールの一覧に Range を加えた。
  - 軽2: G1 の完了条件として実装し、確かめた（下の 5）。
  - 軽3: 公開契約の免除を、構成子の引数と欄だけに限った（`walk.rs` の `decl_signature` が頭の参照を保存して戻す）。
  - 軽4: Scope の表示を、引用の前に切り詰めて引用し直す形にした。一引数 2000 バイト以内に収め、半分ずつ縮めるので停止する。
  - 軽5: 02-05 に一文を足した。

### 5. 生成と縮小（G1〜G4）

- 不透明型の生成の拒否: `generate` は、opaque の型に JSON・Property の要求があるとき、または生成先から構築・検査できないときに、要求全体を `derive.opaque_target` で拒否する。宣言モジュールの中でも同じである。不透明型の欄は `template_type` で unsupported になり、欄全体の手書きの関数を要求する。
- Show・Order: 明示要求の真偽値だけで生成し、欄の順を保つ。Order は最初の非 Equal で終える。辞書の欠落と重複は、生成前に拒否する。
- 手書き部分の保護: 置換するのは、前回の記録の `outputSha256` と本文のハッシュが一致する管理領域だけである。旧版の記録は migration_required、旧版の manifest は incompatible_manifest で拒否する。
- 縮小の駆動: `advance` が、初回の candidates の呼び出しと各続きの呼び出しを、その直前に作業量 1 として数える。Yield は、property の呼び出しを shrinks 1・作業量 1 として数える。予算に達したら、それ以上呼ばずに limitReached を true にする。Done を得ていれば false になる。06-04 と design 11.2 に一致する。
- 候補の生成: 重複除去は、原値との比較と既出の候補との比較を一回ずつの段に分けている。候補順は G3 の既存の assert で保っている。
- G4 の limitReached の変更: 既存のテストは、予算 1・2・3 のそれぞれで、shrinks と limitReached を厳密に比べる形を保っている。予算 2 の期待だけを、新しい契約（続きが未知なら true）に従って false から true に変えた。予算 3（Done を得た場合の false）と、作業量の予算でちょうど Done を得る例（false）も残っている。期待を弱めた変更ではない。
- 移行: 同梱例の移行は、旧本文のハッシュの照合、確認済み manifest のハッシュを指定した apply、通常の check・test、derive check の順で行い、結果を g4 に保存している。手書きの例と文書に、List を返す旧 API の書き方は残っていない。

### 6. 規約

- コード: 追加した本番コードに、unwrap・expect・添字・panic はない（clippy --all-targets も各作業で通過）。新しい大域の状態もない。call_allocations の Mutex はテストのバイナリの中だけにある。内部の不具合の説明の文字列は規約の例外に当たる。利用者向けの文言は `resolve/text.rs` と診断の表に置いている。
- コメント: コメントは設計書の節を引き、作業の ID・R 番号を引いていない（追加行を `git grep` で確かめた）。AST を辿る処理に `#[inline(never)]` を付けて分けている。
- テスト: 既存の assert の削除・緩和・ignore 化はない。
  - 期待値の変更は三つに限る。M1 の件数、G1 の inventory 版 2 の厳密な木への移し替え、G4 の Config の欄の追加と予算 2 の limitReached である。
  - 新しい ignore は、G4 の long テスト一件だけである。
  - 診断の golden の四件は、note の全文だけを新しい文言にした。
- 設計書: 追加した記述に【未決】【要検証】や、まだ実装していない機能の記述は見当たらない。
