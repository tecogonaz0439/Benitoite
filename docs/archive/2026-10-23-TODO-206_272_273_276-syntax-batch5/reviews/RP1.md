# RP1: P1 の判断の記録と実装プランのレビュー

- 対象: `decisions.md`、`plan.md`、`implementation-request.md`、`preflight.md`（Codex、P1。未コミット）
- 前提: [README](../README.md) の二つの「設計者の決定」、`study/` の各文書と問い、`reviews/` の RS1〜RS3 と対応、`docs/workflow/` の雛形、`work/m011/P1-prompt.md`
- 開始版: `a9c4132e`（ブランチ `san_benito`）
- レビュー日: 2026-10-23
- 行った確認: 文書・設計書・ソース・Lean・検査スクリプトの読み取りと、`rg`・`grep` による抜き取りの照合。ビルド・テスト・CLI の実行・Lean のビルド・測定は行っていない。書き込んだのはこの記録だけである。

## 総評

decisions.md は、設計者の決定と推す案を概ね正しく写している。D1〜D27 の決定の中に、study の推す案と食い違うものはない。D28〜D35 は、問いの文書の「計画で決める点」と RS1〜RS3 の対応で計画へ送った項目に収まっている。言語の規則を新しく決めたものはなく、委任の範囲を越えていない。plan.md の段の組み方（Lean を最初に置き、W・A・C を Lean から独立させ、Lean が止まったら V へ進まない）も設計者の指示どおりである。preflight.md の主張は、抜き取りで照合した 15 件すべてが現行のソースと一致した。

重い指摘はない。中程度の指摘は次の 8 件である。

- 検査の割り当ての誤り: Lean の段の作業末の検査が、01-12 の例の検査を外している（指摘 1）。
- 依存の順序: 実装でつまずく危険の最も大きい字句の接続の試行（F0）が、後ろに置かれすぎている（指摘 2）。
- 途中の状態: A1 を取り込んでから A2 を取り込むまで、ファイルの `uses` が黙って無視される（指摘 3）。
- 判断の漏れ: 言語の版の、互換性を壊す変更の表について判断がない（指摘 4）。
- 見積もり: 合計が study の見込みと 2〜3 倍食い違い、理由がない（指摘 5）。
- 作業の大きさ: F4 と L2 が一つのセッションに収まる見込みが薄い（指摘 6）。
- 検査の記述: work の `source_rules` と change の `heap_checks` について、実際の選択と異なる説明がある（指摘 7）。
- 段の検査: S-W・S-C・S-F（の一部）が、直前の work と同じ対象を繰り返している（指摘 8）。

どれも、計画の文書を直せば起動の前に解消できる。

## 読めば確定する指摘

### 中

**指摘 1（plan.md「検査の割り当て」の work L1・L2・L3 の行）: `--only formal_build` だと、01-12 の写しを変えても例の検査が走らない**

L1〜L3 は、`docs/design/01-spec/01-12-core-calculus.md` と 07-04 の写しを変える。自動の work なら、`scripts/check.sh` の classify は `docs/design/01-spec/*` に対して spec_examples と spec_tally を選ぶ。しかし `--level` と `--only` を併用すると分類しないので、この二つが落ちる。`tests/spec_examples.rs` は 01-spec のすべての ` ```text ` を読み、ソースの形の例を解析する。L1〜L3 が新しい書式（`"${e:+08.2f}"` など）を含む表層の例を 01-12 に書くと、F2 で構文解析を実装するまで、その例は解析できない。この失敗は L の work では見えず、後で 01-spec を変える最初の Rust の作業か、G1 の change で初めて現れる。さらに、L3 の行の `python_syntax` が構文を確かめるのは `tools/…` の Python だけで、L3 で加える `formal/tests/test_batch5_exchange.py` は対象外である（`check.sh` の 247 行）。

修正案: L1〜L3 の work は、`--only` を付けない自動の `scripts/check.sh --level work --base B_WORK` にする。変更は formal/ と docs/ だけなので、formal_build・spec_examples・spec_tally が選ばれ、Rust の全 lib は選ばれない。L の作業の節に、次の二つのどちらかを書く。(a) F2 より前は、01-12 に新しい書式の表層の例を ` ```text ` で書かない。(b) 書くなら `EXPECTED_FAILURES` に登録し、F2 が登録を外す。L3 の `python_syntax` は外し、直接の `python3 -B formal/tests/test_batch5_exchange.py` を検査として残す。

**指摘 2（plan.md「作業 F0」と「段とレビュー」の V 行）: F0 を Lean の段と W2 の後に置く理由がない**

F0 は、作業の記録と scratch だけを触る読み取りの試行である。07-04 の「Lean を先行する」の規則は、形式化の内側を処理系で実装する作業に掛かる。処理系の本番を変えない試行には掛からない。W2 との意味の上の依存もない。一方、study 4.2 と 12 節は、案 A の字句の接続が成り立たなければ代案 C（`${e;spec}`）と比べるとしている。区切りの記号を変えるのは言語の規則の変更なので、設計者に尋ねる必要がある（plan も「コロンを別の記号へ無断変更しない」と書く）。設計者が不在の間、この問いが見つかる時期を遅らせるほど、待ちが長くなる。Lean は解析済みの書式を受けるので、区切りの記号が変わっても L1〜L3 はやり直しにならない。

修正案: F0 の先行条件を「B0」に改め、最初の Lean の作業の前か直後に置く。preflight.md「計画で直した食い違い」の、F0 を Lean の後へ置いた理由の行も、この理由で書き直す。F0 を早く置いても、F1 以降の先行条件（段 I のレビューを通っていること）は変えない。

**指摘 3（plan.md「作業 A1」の完了の条件と依存・見込み）: A1 の取り込みから A2 の取り込みまで、ファイルの `uses` が黙って無視される**

A1 で、ファイルの `uses` を構文解析して Module に保持する。合併は A2 で行う。この間に san_benito へ取り込まれた状態では、`uses Console.Write` と書いたファイルの関数が、宣言より小さい契約のまま検査を通る。「A2まで…公開候補は作らない」という文は、この間の取り込みの状態を守らない。その状態で short の測定も行う。F2 には「未接続の新構成を実行させない防御」があるが、A1 にはない。

修正案: A1 の手順と完了の条件に、A2 で外す一時の防御を加える。たとえば、型検査に入る前に、ファイルの宣言があれば処理系の制限として拒否する。または、A1 と A2 を同じ取り込みにまとめる。防御を入れるなら、A2 の完了の条件に「防御を外し、合併の経路へ替える」と書く。

**指摘 4（plan.md「作業 Z1」、decisions.md）: 言語の版の、互換性を壊す変更の表（`modules/package.rs` の `BREAKING_CHANGES`）についての判断がない**

0.0.5〜0.0.10 の版はどれも、この表に項目を登録している。06-09 の「設定ファイルの検査」の段落にも、版ごとの登録が列挙してある。0.0.10 の案内は「derive の版3記録を確認する」よう促す。今回の改造には、利用者に見える互換性の変化が三つある。D33 の derive の inventory 3 と生成器の版（0.0.10 の案内が確認を促した記録が、apply・check に使えなくなる）、D33 の try-actions の manifest 2、D26 の package の Log の記録の変化である。Z1 は CHANGELOG の移行の注意だけを挙げていて、この表に 0.0.11 の項目を加えるかどうかを決めていない。

修正案: decisions.md の「計画で決めた点」に一項を加え、0.0.11 の項目を登録するか（するなら summary と help の内容）、登録しないか（言語の規則を壊さず、道具の版は道具が拒否するため、など）を理由とともに決める。登録するなら、Z1 の触るファイルに `src/modules/package.rs`・`modules/text`・`src/modules/tests.rs` と 06-09 を加える。

**指摘 5（plan.md「残りの作業・検査・測定・レビュー・受け入れ」）: 合計の見込みが study と大きく食い違い、理由が書かれていない**

plan.md は 21 作業の実装・文書を「約16〜21時間」とする。study の見込みは次のとおりである。format-and-width 12 節は TODO-273・272 だけで 21〜41 時間とし、そのうち Lean の段 1 は 1〜3 時間で、段 2〜5 は未校正としている。file-effects 6 節は A・C で 9〜18 時間とする。合わせると約 30〜59 時間になる。plan は「studyの総時間は…工数短縮とは扱わない」と書くが、2〜3 倍の差の理由を説明していない。各作業の仮予算を足すと 15.5〜20 時間で、表の「16〜21」とも少し合わない。

修正案: 表の下に、study の見込み（30〜59 時間、未校正）と、作業ごとの目安の合計（15.5〜20 時間）を並べて書く。差の理由（30〜60 分は一作業の上限の目安であり、所要時間の予測ではないこと、第4弾の L 作業の約 10 分の記録など）を書き、L1 と F0 の後に更新する規則に結び付ける。合計の値を算術と合わせる。

**指摘 6（plan.md「作業 F4」「作業 L2」）: 一つのセッションに収まる見込みが薄く、分け方が決まっていない**

F4 は次をすべて 60 分に含める。型集合と E0468、C2 の由来による抑制、脱糖、定数評価とサイズの算定、VM と参照評価器の接続、F2 の防御の付け替え、01-06・02-05・02-06・英語のリファレンス・Skill。L2 は、study 8.1 の見込みで直接手を入れる 15〜30 箇所と、機械的に追随する 10〜20 箇所の大半を受け持つ。plan は「超過時に再見積もり」とだけ書き、どこで分けるかを決めていない。分け方をその場で決めると、後半の作業の節が「この節だけで実装できる」粒度を失う。

修正案: 分ける位置を先に決めて書く。F4 は F4a（型集合・適合の検査・E0468・C2 との接続、型と診断の文書）と F4b（脱糖・定数評価・VM と参照評価器・防御の付け替え・リファレンスと Skill）に分ける。L2 は L2a（型付け・脱糖・型保存・範囲と捕捉）と L2b（Check・健全性・計算可能性・有限支持）に分ける。分けた後も sorry なしで既定のビルドが通る区切りかどうかを、L2a の完了の条件に書く。一つのセッションで済んだ場合は、続けて行ってよいと書けば足りる。

**指摘 7（plan.md「基準・実行と保存の共通条件」の第1段落、「全比較・特殊構成・測定・候補の照合」の check-heap.sh の行、preflight.md「検査と見積もりの点検」）: 検査の中身についての記述が、実際の選択と違う**

(a) `source_rules` は `check_placeholder_allows` と `check_unsafe_allows` だけを実行する（`check.sh` の 551〜553 行）。リンク・見出し・採番は確かめない。plan は P1 の作業末について「--only source_rules を…実行し、リンク・見出し・採番・編集範囲を静的に確認する」と書いていて、確認の手段を取り違えて読める。F0 と G1 の work 行も、文書だけの作業に `--only source_rules` を使っている。(b) change は、`crates/benitoite/src/runtime/heap/*` を変えた場合にだけ heap_checks（`check-heap.sh`）を選ぶ（classify の heap の種類）。plan と preflight は「G1のchangeのheap_checks」を前提にしている。

修正案: (a) `check.sh` には文書のリンクの検査がないことを明記し、P1・F0・G1 の文書の確認の手段（preflight で使った読み取りのスクリプトなど）と記録先を書く。work の行は、自動の work（文書だけなら選ばれる検査がない）か、`source_rules` の中身をそのとおり書いた行にする。(b) check-heap の行を「heap の配下を変えた作業があれば、change が選ぶ。なければ要らない理由を g1/results.md に記す」と改め、preflight も合わせる。

**指摘 8（plan.md の stage S-W・S-C・S-F の行）: 直前の work と同じ対象を繰り返している**

S-W の `runtime_builtins`・`cli_process` は、W2 の work の対象に含まれる。S-C の `declarations`・`golden` は、C2 の work の対象に含まれる。どちらも基準は、直前の取り込みでそろっている。S-F の `runtime_builtins`・`declarations`・`golden` は、F5 が処理系の本番を変えない場合（plan の「数と幅のランタイム本体はこの作業で改造しない」）、F4 の work と同じ関係状態になる。07-03 は、最後の作業で同じ接続まで確かめていれば引用し、段の数を理由に全件の検査をしないと定めている。

修正案: S-W と S-C は、W2・C2 の work を引用する形に改め、省く理由を書く。S-F は、F5 が src を変えた場合だけ走らせ、変えない場合は F4 の work を引用すると条件を書く。S-A は、A3〜A6 の相互作用を確かめるので残してよい。

### 軽

| # | 箇所 | 問題 | 修正案 |
|---|---|---|---|
| 9 | decisions.md D7・D4 | 「study 5.2の表をそのまま採る」は型ごとの受理表だけを指す。5.1 の意味の表にある「`#` は値0にも接頭辞を付ける」「p=0 なら小数点を付けない」「ゼロは符号・接頭辞の後、数字の前に補う」は、D4〜D8 のどこにも写っていない | D7 に「5.1 の文法（FormatSpec）と、指定と意味の表もそのまま採る」と加える |
| 10 | decisions.md D9 | study 6.2 の「負から丸めた零も負号を保つ」（`${-0.4:.0f}` は `-0`）が、「Float系の負の零を残し」だけでは読み取れない | 「負の零と、負の値から丸めた零の負号を保つ」と明記する |
| 11 | decisions.md D1、plan.md A2 の完了の条件 | 対象外の一覧に、study 3.2 が除外するエフェクトの操作の宣言・定数・ハンドラの節・局所の関数値と、文書の例（外側の宣言を引き継がない）がない。A2 の負の対照も trait/implement/ラムダ/関数型に限られる | D1 の対象外にこれらを加え、A2 の負の対照に、エフェクトの操作の宣言と定数を加える。文書の例は A3 にあるので、D1 から A3 を参照する |
| 12 | decisions.md D24、plan.md A3 | 06-01 の「報告の受け手は…schemaVersion と kind、status:ok、complete:true、終了状態0のすべてを確認」という条件のうち、D24 は status と complete だけを挙げる | D24 と A3 で 06-01 の受け手の条件の全体を参照する |
| 13 | plan.md「作業 F4」の触るファイル | E0468 を加えるのに、`src/diag/codes.rs` と 02-10 がない（D34 と preflight は「A1/F2/F4 で codes.rs・02-10」とする）。A2（E0506・E0514 等に追加元の補助位置）と A3（E0512 の補助位置。02-10 の E0512 の【決定】に関わる）も 02-10 を挙げていない | F4・A2・A3 の触るファイルに `diag/codes.rs`（必要なら）と 02-10 を加える |
| 14 | plan.md「作業 A2」の触るファイル | `tests/…typed_failure` という統合テストはない（`typed_failure` は `tests/io_modes.rs`・`vm_handlers.rs` の中の名前）。Fail・NoFail を変えるのに、work A2 の行に `vm_handlers` がない | 実在のターゲットに直し、Fail の合併を確かめる統合テストの読者（`vm_handlers` など）を work A2 の `--test` に加えるか、要らない理由を書く |
| 15 | plan.md「作業 A5」 | リポジトリには生成記録の例 `tools/derive/examples/derive.generated.json`（inventoryVersion 2、generatorVersion `3.0.0-syntax-batch4`）と、`People.bnt`・`Address.bnt` がある。`test_derive.py` も 975 行でこれを写して使う。D33 の版の上げで、これを作り直すのか、旧記録の対照として残すのかが書かれていない | 触るファイルに三つを名指しし、新しい preview→確認済みのハッシュで apply→check の手順で作り直すか、旧版の対照として残すかを決める |
| 16 | plan.md「性能比較short」の行と残りの表 | A5 は examples と tools だけを変え、処理系の本体を変えない。それでも short が割り当ててある（benchmark のスキルは「処理系を変えた作業の取り込みごと」）。W1 も、どこからも呼ばれない関数と依存を加えるだけである | A5 の short を外す。W1 は W2 と合わせて段の区切りで一回にしてよいと書く |
| 17 | plan.md 07-04 の内外の割り当て | 「07-04の対応表へそれぞれの内外を記す」としているが、TODO-272（表示の幅の算法は対象外）の行を書く作業がない。L・A2・C2・F5 は、それぞれ 273・206・276 の分しか受け持たない | W2 か F5 の触るファイルに 07-04 を加え、272 の行を割り当てる |
| 18 | plan.md W1・W2 | 「表示の幅」は設計書と用語集にない新しい語である。plan の中でも「表示幅」（7 行）と「表示の幅」（D10）が混ざっている | 語を「表示の幅」（README と D10 に合わせる）に揃え、W2 の触るファイルに 00-04 を加えて行を足す |
| 19 | plan.md D28・F1、preflight | 「補間の枠」「文字列の枠」の「枠」は、用語集ではコア計算の frame（266 行）と呼び出しの枠（115 行）の語である。F1 が 02-03 にこの語を書くと、用語集と衝突する | 02-03 では「補間の入れ子」や字句解析器の既存の呼び方など、別の語で書くよう F1 に注記する |
| 20 | plan.md「作業 F0」 | 「必要な最小の試行用差分」を作ると src を一時的に変えることになる。作業の終わりに戻す条件がない | 試行の差分は scratch にパッチとして残し、作業ツリーの src を開始版に戻してから終える、と書く |
| 21 | plan.md「段とレビュー」の段落 | Lean の段が止まり、II〜IV を終えた後の扱い（G1・Z1 に進まない、版を上げない、設計者に報告する）が明文化されていない | 「Lean の停止が解けるまで VI に進まず、II〜IV の取り込みと short を終えたら報告して待つ」と書く |
| 22 | plan.md（RS1-response の X5） | 実行ファイルの大きさの増分を測るかどうかは「計画で了承を得る」とされていたが、plan に記述がない | 「今回は測らない（targets・full と同じく了承が要る）」と、測らない理由を一行書く |
| 23 | plan.md「作業 A1」 | 設定ファイル `package.bnt` には import と宣言を書けない（00-04、06-09）。ファイルの `uses` を `package.bnt` に書いた場合の負の対照がない | A1 の完了の条件に、`package.bnt` の `uses` を拒否する対照を加える |
| 24 | plan.md「作業 A1」「作業 F2」の検査 | work の Rust の単位は examples をビルドしない（lint_default は `--lib --tests`、examples のビルドは change で行う）。A1 は Module を、F2 は InterpSegment を変える。`examples/try_actions_inventory.rs`（244 行で `segments` を走査する）と `derive_inventory` は、A5・A6 か G1 まで、ビルドされない可能性がある | A1・F2（と F4）の局所の検査に `cargo build -p benitoite --examples` を加える |
| 25 | implementation-request.md 3〜4 行と 20〜21 行 | 段落の直後に見出しが空行なしで続き、別の箇所には空行が二つ続く | 空行を整える |

## 実行しないと分からない点

次は、読んだだけでは確定しない。実装の作業の中で、再現か観測で確かめる。

| 点 | 確かめる作業と方法 |
|---|---|
| 指摘 1 の失敗が実際に起きるか（L が 01-12 にどんな例を書くかによる） | L1〜L3 の work を自動の水準で走らせ、spec_examples の結果で確かめる |
| 本体のない `@builtin`・`@external` の関数の次の行に `uses X` を書いた場合、ヘッダの続きを書いたつもりの利用者に、E0261（遅い宣言）だけが出る。改行の規則では、行頭の `uses` は前の行の続きにならない（`newline.rs` の `continues_before` に KwUses がない） | A1 で対照の例を一つ加え、診断の文が「関数の `uses` は同じ物理行に書く」ことに触れるかを判断する |
| 指摘 24 の examples が実際に壊れるか（欄の追加だけなら壊れない可能性が高い） | A1・F2 の局所の examples のビルドで確かめる |
| `displayWidthUnicodeVersion` を常に出すか（06-01 の 92 行の「無視しても意味が変わらない任意欄」に当たる） | W2 で、06-01 の表に、出す条件と旧版で欠けることを書き、`cli_process` で確かめる |
| study の段0 に当たる字句の接続（D28）が成り立つか、それにかかる時間 | F0（指摘 2 の位置） |

## 確かめて正しかった主張

| 主張 | 確かめた根拠 |
|---|---|
| decisions D1〜D27 は、README の二つの決定と、format-and-width の問い 1〜13・file-effects の Q3〜Q8・Q10・Q12〜Q14 の推す案と一致する | 各問いの推す案、study 4.2・5.1〜5.3・6・9・10、3.1〜3.6・5.3 と照合した。指摘 9〜12 の落ちを除き、条件と留保も写っている |
| D28〜D35 は、問いの「計画で決める点」と RS1〜RS3 の対応で計画へ送った項目に限られる | format-and-width-questions の末尾の 6 項、file-effects-questions の末尾の 4 項、RS1-response の L3・L7、RS2-response の中3・中4・軽4 |
| 呼び名「ファイル単位のエフェクトの宣言」は study 2.2 の推す案である | study 2.2。設計者に戻ったら報告する項目として扱えばよい |
| `Module` は header/imports/decls を別に持ち、file_uses はない。ファイルの構文解析の入口は `parser/decls.rs` の `parse_module` | `syntax/ast.rs:46`、`parser/mod.rs:98` が `decls::parse_module` を呼ぶ |
| 署名の収集は `self.uses(f.uses.as_ref(), &scope)` の後に `signature_no_fail` を呼ぶ | `typeck/decls.rs:612–616`（426 行の呼び出しは FnType のもので、対象外） |
| 入口の検査は AST の uses を読む | `typeck/effects/declarations.rs:92` |
| derive の inventory は version 2 と preambleEnd を出す。derive.py は `GENERATOR_VERSION = '3.0.0-syntax-batch4'`、`INVENTORY_VERSION = 2`、`HASH_VERSION = 3` | `examples/derive_inventory/mod.rs:478・495`、`tools/derive/derive.py:26–28` |
| try-actions の inventory に版の欄はなく、migrate.py は `VERSION = 1` | `examples/try_actions_inventory.rs`、`tools/try-actions-migrate/migrate.py:18` |
| migrate_selftests は source-migrate と try-actions だけで、derive を含まない | `scripts/check.sh:560–563` |
| package の短縮名の特別扱いは State と IO.All だけ | `cli/tools/package/effects.rs:150` |
| 交換形式は corpus 8〜13・sidecar 2〜5。batch4 の Python にも 13・5 が埋め込まれている | `formal/Benitoite/Exchange/Version.lean:140・172`、`formal/tests/test_batch4_exchange.py:200・248` |
| unicode-width 0.2.2 は lock にあるが、通常の直接の依存にはない | `Cargo.lock:1450`、`crates/benitoite/Cargo.toml` の `[dev-dependencies]` に wat だけがある |
| `--version` は二行、`--version=json` は schemaVersion 1 と Character の unicodeVersion を出す。任意の欄を加えても版は上げなくてよい | `cli/mod.rs:465–500`、06-01 の 42・50・92 行 |
| E0261・E0262・E0468 は未使用である。E02nn は構文、E04nn は型の区分 | `diag/codes.rs`（E0260・E0467 が各区分の末尾）、02-10 の 112・114 行 |
| 脱糖の章は 02-06 である | `docs/design/02-impl/02-06-ir-and-lowering.md` |
| 計画が名指す check.sh の単位と統合テストは、`typed_failure` を除いて実在する | `check.sh:41–46` の単位名、`crates/benitoite/tests/*.rs` |
| short は取り込みごとに了承を待たずに行い、targets・full は了承が要る | `.claude/skills/benchmark/SKILL.md` の 18・105・117 行 |

## 公開の文書としての点検

- docs/todo へのリンクはない。「docs/todo の TODO-nnn」と文字で書いている。
- 非公開の内容はない。`Codex` の語と `private/` の名前は出てくるが、第4弾の公開の implementation-request にも先例がある。`work/m011/scratch/`（git で無視される場所）の記述は RS1〜RS3 にも先例があり、F0 の結果は `f0/results.md` に残す計画なので問題はない。
- 造語として直すべきものは、指摘 18（表示の幅の表記の揺れ）と指摘 19（「枠」の衝突）だけである。「整形頭」は内部の説明の語で、設計書へ写す語ではない。設計書に写すときは、既存の「直接の頭」に合わせればよい。
