# 第6弾の判断の記録

2026-10-24、P1R（RV-P1対応）。実装前の判断である。[README](README.md)の全ての「設計者の決定」を正とし、調べの未回答という表記や主案IIだけの記述より優先する。D1〜D14は当初の設計者の決定、D15〜D22はその範囲を具体化した計画の判断である。P2のD23・D24は追加項目の決定、D25〜D30は取りまとめのレビューへ渡す計画の判断である。比較の詳細・確認済みの外部の用例は出どころのstudyを参照する。

## 設計者の決定

### D1 改造の範囲

【決定】TODO-022・206の残り・280・281・282を扱う。TODO-142のエフェクトの範囲と実行時の権限制御は扱わない。TODO-022は土台に案I・II・IIIの全てを加える。

理由: 整数の局所解析を中心に、形式化と独立した小さな課題を合わせる。三案の採用は、調べの推す案IIを設計者が広げた決定である。

出どころ: READMEの最初と調べの後の決定、[interval-analysis 5.1・8.3・12.1](study/interval-analysis.md)。

### D2 区間の土台と演算・幅

【決定】局所のbind・shadow、定数との比較、ifの絞り込みと合流、短絡and/or、matchのリテラル・範囲・guardを扱う。Integer64を土台にInteger8/16/32・UnsignedInteger16/32/64を加え、加減算・符号付きの負号・片辺が一点の定数倍・div/modの除数0を追う。Byteの算術と一般の積、商・剰余の結果区間の伝播は加えない。

【計画の判断】D2 の追記（2026-10-25、RV-C2 を受けて）: match のリテラル・範囲のパターンは Integer64 だけが持つ。言語仕様（01-02 のパターンの制約）は六幅の定数・範囲パターンを許さないので、六幅の match の腕は束縛・ワイルドカードと guard だけで扱う。

理由: 複数の値の区間と合流から、小さい幅のあふれも報告できる。相関や不動点を求めずに学べる範囲を定める。

出どころ: [interval-analysis 2.2・8.1・8.2・12.1](study/interval-analysis.md)、Q1。

### D3 Rangeの成功情報

【決定】固定端点の標準Range.checkIntegerの直接呼び出し、または一度局所束縛へ保存してmatchした結果から、Okの同じ成功値に区間を付ける。その値への直接のRange.valueだけへ伝える。Error・逆転・範囲外を新しい警告にしない。CheckedLength・CheckedIndex・NonEmptyListには広げない。

理由: 成功した値と不透明型の射影の対応を学ぶために案Iも採る。一般のRange利用で追加警告が増えるという実績は根拠にしない。

出どころ: [interval-analysis 4.2・8.3・9.3](study/interval-analysis.md)、READMEのQ1。

【計画の判断】D3 の追記（2026-10-26、RV-C3 の軽5 を受けて）: 条件環境の合流（短絡の条件の真偽の枝の入口、`hullEnv`・`joinEnvs`）でも、Range の成功値の由来の記録をすべて忘れる（位置・事実を空にし、番号は再利用しない）。条件の外で束縛した成功値の由来を保っても健全だが、Lean の作業量を増やさず、単純な規則を Rust に写すことを優先した。値の合流・本体の境界・独立入力での忘却と同じ扱いである。

### D4 固定の定義域

【決定】案IIIの全APIを含む。Integerと幅付き整数・Byteのシフト量は[0,w−1]、Process.exitのcodeは[0,255]、Http.listenのportは[0,65535]、Http.respondのResponse.statusは[200,599]、Http.requestのClientRequest.timeoutMillisecondsは[1,max64]と照合する。HTTPの明示したレコード構築・局所束縛・欄更新も対象にする。

理由: 一つの値でなくても、区間全体が定義域の外なら原因を報告できる。HTTPの欄の取得も必要な作業として含める。

出どころ: [interval-analysis 5.1・9.3](study/interval-analysis.md)、Q1。

【決定】D4 の変更（2026-10-26、RV-C4 の重大1 を受けて、設計者の決定）: `Process.exit`・`Http.Listen.listen`・`Http.Listen.respond`・`Http.Connect.send` は組み込みのエフェクトの操作であり、言語のハンドラで差し替えられる（01-07「利用者が定義するエフェクトとハンドラ」の【方針】）。ハンドラが処理した `Process.exit(300)` は停止せず、プログラムは終了状態 0 で終わる（取りまとめが 39768486 の処理系で確認した。`reviews/RV-C4-response.md`）。設計者は、対象構文の評価関係で、操作にハンドラの結果（型の中の任意の正常値と任意の失敗）を許す案を選んだ。局所の解析は呼び出し元のハンドラを知れないので、操作の W0404 の健全性は示せない。そこで、案III の W0404 の対象を Integer と幅付き整数・Byte のシフト量（純粋な関数）に限る。exit・listen・respond・send の直接引数と、HTTP の明示したレコード構築・局所束縛・欄更新は対象から除き、解析の HTTP の欄の追跡も除く。対象構文の評価関係では、具体規則を操作に付けない。

理由: W0404 の説明は呼び出しが実行時に停止すると述べるので、ハンドラが処理しうる操作には付けられない。警告に使う先のない欄の追跡の計上を、HTTP を含まない入力に負わせない。main の本体で、その操作を処理する handle の外にある呼び出しは、どのハンドラも処理しないので警告を残せる。ただし Lean にハンドラの文脈の追跡が要るので、後の改造の候補として docs/todo に加える。

### D5 健全性の基準A1

【決定】新設するSurfaceの対象構文の評価関係に対して正常値の区間への所属と警告位置の失敗を証明する。01-12の脱糖・Release実行との一致は証明せず、対象範囲の値・失敗・到達をVMとの差分テストで確かめる。差分テストは全入力の意味の一致の証明ではないことを07-04へ書く。

理由: 既存の脱糖の型保存から算術の意味の保存は導けない。保証の範囲と、実行比較で確認する接続を明示する。

出どころ: [interval-analysis 9.2〜9.4](study/interval-analysis.md)、Q2とRV-S1-responseのF1・F4。

### D6 警告と通常の受理

【決定】確実な除数0はW0401、確実なあふれはW0402を広げて使う。案IIIには別の警告コードを加える。未知・予算超過を拒否せず、実行時検査を全て残す。警告の意味は対象位置へ到達しオペランドが正常に得られた場合に限り、プログラム全体の失敗・到達・停止を断定しない。

理由: 原因によって診断を検索できる。通常モードの新しい拒否を増やさず、--deny-warningsで受理が狭まる差は棚卸しする。

出どころ: [interval-analysis 7.2・10.3](study/interval-analysis.md)、Q3。

### D7 01-04の既存の不一致の訂正

【決定】幅付き整数の標準関数にも既に定数警告が出る点を01-04へ反映する。Integer8.absolute等の現在の振る舞いを変えず、新しい局所解析の条件の拡張とは区別して説明する。

理由: 01-04の記述が実装・02-05と一致していない。文書の訂正を、新機能による変更と混ぜない。

出どころ: [interval-analysis 2.2・7.2](study/interval-analysis.md)、Q4。

### D8 解析の境界と予算

【決定】新構文・公開部分型・関数型の篩・SMT・無限の端を加えない。自作の区間判定を用い、関数の境界を越えず、本体ごとの予算と検査全体の上限を併用する。

理由: 有界整数の局所情報だけで実装でき、中核を自作する原則を守れる。未知に退避できるため、注釈や外部solverを利用者に求めない。

出どころ: [interval-analysis 7.1・8.1〜8.4・9.1](study/interval-analysis.md)、READMEの既定案。

### D8a 未知の形の子の独立した解析（2026-10-24、設計者。RV-C1 の中5）

【決定】未知の形の直接の子のうち評価順の定まる式（呼び出しの頭と引数、補間・リスト・レコードの要素、パイプの両辺、try のオペランド、with の束縛式）と、with の本体・handle の保護された本体を、外の局所位置を `forget` した環境と元のキーで、独立した入力として解析する。外の事実は持ち込まない。D8 の「関数の境界を越えない」は関数本体へ入らないことを指し、この解析と両立する。中心の命題・評価関係は変えず、予算の計上と番号の消費は skip の代わりにこの解析を使う形で定める。

理由: 部分木の内側だけで分かる事実を警告に使え、利用者に届く警告の範囲が大きく広がる。中心定理は任意の入力と `Models` について成り立つので、ラムダの本体と同じ条件付きの保証がそのまま得られる。

### D9 ログの既定書式と出力先

【決定】案A'を採る。純粋なLog.formatRecord(record: Log.Record) -> Stringを公開し、開いたWriterとwithSinksを組み合わせる実行可能なテキスト例、利用側でJsonへ変換する例を文書とSkillに置く。水準と位置も記録する。出力先の実行時許可はサーバモードまで残す。

理由: 既存のハンドラとWriterで書けることは保存した小例で確認済みである。既定書式を利用側で再実装せずに済み、preludeのLogからJsonへの依存も増やさない。

出どころ: [riders「TODO-206」の選択肢・A'の公開性](study/riders.md)、[保存例](study/riders-probes/README.md)、ridersの問い1。

### D10 deriveの事前拒否の範囲

【決定】案Cを採る。ファイル単位の宣言がある生成対象へのPropertyまたはJSONの生成は拒否し、Show・Orderだけなら受理する。複数対象の一つが該当すれば全体を非書き込みで拒否する。prepareの共通入口でpreview・初回apply・checkの判断をそろえる。

理由: 純粋なトップレベル関数を作る機能の契約を守る。JSONへの拡大も設計者の承認済みであり、実装時には容器内レコードの反例を再現する。

出どころ: [riders「TODO-280」の生成する宣言・selftest](study/riders.md)、問い2。

### D11 deriveの版を保つ条件

【決定】案aを採り、生成器3.1.0-syntax-batch5、inventory/manifest/receipt/記録/意味ハッシュ3、設定1、Property.libraryVersion 2.0.0を保つ。この事前拒否をBREAKING_CHANGESに登録しない。受理入力の生成本文・意味ハッシュ・記録が一致することを条件とし、崩れたら作業を止めて版と移行を再判断する。

理由: 無関係な現行記録の一律移行を避ける。道具自身の入力ハッシュで古いmanifestを拒否しうるため、更新前manifestの無条件な再利用は案内せず、途中復旧は保存した旧道具で先に終える。

出どころ: [riders「生成器の版とBREAKING_CHANGESの登録」](study/riders.md)、問い3。

### D12 deriveの現行説明と移行節

【決定】Skillと英語リファレンスの現行の説明をD11の版へ直す。過去版の移行節を保ち、日本語のSkillとリファレンスは最後のリリース準備で同期する。

理由: 現行の使い方と過去の移行の説明を読み分けられるようにする。生成器を上げずに旧版表記だけを直す。

出どころ: [riders「現在の重複と対応」の旧版表記の表](study/riders.md)、問い4。

### D13 workのexamplesのlint

【決定】案Aを採り、新水準のlint_defaultに常に--examplesを足す。旧--only・--fullの経路とlegacy-commands.jsonは保つ。

理由: READMEの設計者が確認した温まったキャッシュの比較では増分は約2秒で、判断基準30秒以下だった。この計画で測定をやり直す必要はない。

出どころ: READMEの調べの後の決定、[riders「TODO-281」](study/riders.md)、問い5の条件を満たした決定。

### D14 版の記述の置き場所

【決定】案Bを採る。01-03にはlanguage宣言の意味・配置・照合規則を残し、版ごとの登録内容と具体的な移行案内を06-09へ集める。見出し・spec印と登録の意味を保つ。

理由: 道具の版の具体的な記述を言語仕様から除き、処理系の登録表と移行案内を一か所で保守する。

出どころ: [riders「TODO-282」](study/riders.md)、問い6。

## 計画で決めた点

### D15 区切りと停止条件

【計画の判断】作業は一列に直列で進める。推す順は、独立した相乗りと処理系の前提の準備、Leanの土台C0/C1とL26、S作業群、処理系の土台A01〜A12、案IIのC2とA13〜A15、案IのC3とA16〜A18、案IIIのC4とA19〜A21、交換C5とXである。C1とL26の閉鎖後にD23〜D30のS作業群を行い、その受け入れ後、拡張全部の完了を待たずA01〜A12へ進める。各区切りは既定lake buildのsorryなしの成功と、定義・言明・仮定のレビューを要する。

拡張のLが見込みの2倍を超えたら、取りまとめが設計者に、閉じた範囲で処理系へ進むかを尋ねる。公理やBuiltins.Assumptionsの追加、旧主定理または今回の正常値・警告の中心定理の前提・結論の変更、A2の意味保存が必要なら、当該作業を止めて報告する。補助補題で保証を変えずに済む場合は続けてよい。三案全てを終えるまで0.0.12の受け入れを完了にしない。

理由: 各拡張でLeanと処理系を交互に閉じると、証明した規則と実装の対応を小さい範囲でレビューできる。並列の取り込みとレビューの負荷を避け、未証明の拡張を処理系の前提にしない。

出どころ: READMEのQ2、P1Rの取りまとめの判断、interval-analysis 9.3・9.4・12.2。

【計画の判断】D15 の追記（2026-10-26、L20d の再開と RV-C3）: L20d の最初の起動は、内部の補助定理 `expr_normal`・`bodyWork_normal` が開始キーの違う場合まで正常値の保存を主張し、Range の精密化と両立しないことで止まった。取りまとめは、言明を変えずに保つ対象を中心二命題・公開の入口の主定理・`Models`・公理とし、内部の補助定理には解析と評価の開始キーの対応と内部の RangeState.Models の条件を加えてよく、公開の入口でその条件を構成すると判断した。言明の文字列が同じでも、参照する定義の変更で公開の定理の意味が弱まる場合は、この判断の範囲に含めない（RV-C3 の中2）。RV-C3 の中2 は、既存の公開の定理の文字列と型を保ち、未認定の call の内側を除く別の公開の定理を加えて閉じた（案 (b)）。構文的な到達可能性を抽象環境に依存させる案 (a) は、式と本体の公開の定理の型を変えるので採らなかった。

【計画の判断】D15 の追記（2026-10-26、L24 の停止を受けて）: 公開の構文的な到達可能性の定理（`analyzeExpr_warning_syntactic_reach`・`analyze_warning_syntactic_reach`・`analyzeBody_warning_syntactic_reach`、独立入力の `IndependentResult.Sound`）と `WarningsInCallReach` の定理は、警告の演算を算術（binary・neg）に限っており、案III の W0404 の警告（対象演算が standard）を排除する。案III は設計者の決定（README の Q1・Q2 と D4・D19）なので、取りまとめは、案III の具体規則を加える範囲（固定の定義域の契約を持つ、標準宣言と元のキーで認定した標準 call 自身と、具体評価を接続する HTTP のレコードの構築・更新の子）に限って、これらの公開の定理が参照する警告範囲の述語を拡張すると判断した。算術の警告についての今の性質（算術の演算を持つ警告は従来の範囲にある）は系として公開の定理で保ち、既存の警告の保証は弱めない。未認定の call・利用者関数・案III の対象外の標準 call の内側を範囲に入れない（L21R の `WarningsInCallReach` の除外を保つ）。中心二命題の本文・前提・結論、`Models`、公理は保つ。設計者の就寝中の指示（「問い合わせがありましたら推奨の方法で作業を進めておいてください」）による判断であり、公開の定理の意味の拡張なので設計者へ報告する。

【計画の判断】D15 の追記（2026-10-26、RV-C4 を受けて）: D4 の変更により、公開の警告範囲の拡張は、固定の定義域の契約を持つ純粋な標準関数（シフト）の call 自身と、その認定した call の引数に限る。HTTP のレコードの構築・更新の子への拡張は除く。構文的な到達可能性の `concreteRule` は record・recordUpdate を候補に含めない形へ戻す。算術の系は、算術の演算を持つ警告について演算の同定（`arithmeticOperationAt` の等式）を保つと述べる。未認定の call の内側の除外は `WarningsInCallReach` の定理が担う（RV-C4 の中2 の修正案の一つ目）。`WarningLocated`・`targetOperationAt` の L22 の拡張（標準束縛の二表と元のキーによる同定）も、公開の定理の意味の拡張として設計者への報告に含める。

### D16 予算の初期値と超過

【計画の判断】操作回数は本体ごと10万回、検査全体100万回から開始する。式の訪問、環境の参照または更新、合流の一項、由来の一箇所、番号付けと分類の追加走査を各1回と数える。読み込み済みモジュールのソース順で処理し、同じ入力と予算では同じ位置で退く。

記憶量はホストに依存しない保持項目数で数える。環境の一項、Rangeの由来の一記録、レコードの一欄、番号の対応表の一要素、警告候補の一件、補助位置の一件、作業スタックの一枠を各1項とする。同じ内容を二か所へ保存した場合は2項と数え、固定長の区間端点など各項の内部は重ねて数えない。既存AST・型表の読み取り専用参照先と、解析前からある診断は対象外とする。追加する直前に計上し、削除時に戻す。本体の最大同時保持は10万項、検査全体の最大同時保持は100万項を初期値とし、終了後も残す対応表と警告候補を全体から落とさない。LeanのBudgetとRustはこの同じ定義を使い、size_of・Vecの容量・ポインタ幅で超過位置を決めない。

上限を超えた部分はUnknownに戻し、既に得た健全な警告と旧定数警告を保つ。超過そのものでは警告も注記も出さず、非実行報告と比較報告の件数だけに残す。本体上限・全体上限・番号を取得できなかった本体の件数を区別する。操作数と保持項目数の実消費はU01の開発用記録に残し、未取得を0としない。

理由: 操作数の初期値にはE1010の型の展開の予算（型ごと100,000節点、検査全体1,000,000節点）という先例がある。この数は本解析の費用の実測根拠ではないため、U01で既存入力の最大消費と上限到達0件を確認する。E1010のdeclaration_budgetとは異なり、追加解析の予算超過で--deny-warningsの受理を狭めないため、超過の診断は出さない。

全体上限により、無関係な本体の追加で後の新警告が消える場合がある。警告なしを安全と解釈しない。初期値を調整するときは、短い試行の根拠と新旧値を計画へ残し、Lean・Rust・交換入力を同時にそろえる。

出どころ: interval-analysis 8.4、crates/benitoite/src/diag/codes.rsのE1010、P1Rの取りまとめの判断。

### D16 の追記（2026-10-25、RV-A07 を受けて）

【計画の判断】RV-A07 の中2について案 B を採る。D16 の計上の対象から、診断の説明に使う束縛・比較の由来と補助位置を外す。由来の追加・合成・複写・打ち切りを操作数に含めず、その列と診断への複写を独立の保持項目として数えない。正常区間、候補の有無、解析の停止位置と分類の判定に由来を使わない。Range の成功値を同定する由来、独立入力・別本体の結果枠など、ほかの `auxiliary` の計上は残す。候補一件の `Warning`、識別対応、環境、作業枠の計上も変えない。

由来は、値・整数の局所位置・候補ごとに最大8件の位置を持つ固定長の列とする。新しい束縛・比較の位置を先頭に置き、それまでの列を順に続ける。二つの値の合成は左辺、右辺の順、if の正常値の合流は到達しうる then、else の順とする。各追加・合成で同じ span（ファイル・開始・終了が一致する位置）の最初の出現だけを残し、8件で打ち切る。打ち切った過去の位置は後の合成でも復元しない。短絡の条件環境の合流は、左右の区間が同じなら左の列、異なるなら両枝の入口にあった列を保ち、新しい位置を足さない。

別名は参照時の列をコピーし、後の絞り込みを遡って反映しない。新しい束縛位置は整数の局所位置へ書くときだけ付ける。非整数・専用構築器・破棄の束縛には由来を新設しない。構造パターンから Top で始める整数位置も空の列とする。定数の埋め込み本体へ呼び出し元の局所区間と由来を渡さず、成功・停止とも元の環境へ戻す。除数0の候補には除数の列だけを、あふれの候補には左辺、右辺の順に合成した列を保存し、診断へ同じ順で渡す。

本体全体の履歴表、無制限の履歴走査、訪問済み集合を置かない。環境の復元用の接頭辞や解析中の値のコピーも、それぞれ最大8件である。由来の保持量は、予算で制限する環境・作業枠・結果枠・候補の個数の定数倍に収まり、各候補から作る診断も最大8件の補助位置を持つ。

Lean の実行定義・定理・公理と、01-12 の Lean の写しは変えない。X02 は改定後の解析予算の操作数・保持数・停止位置・分類を厳密に比較し、由来分の事後減算や予算境界の一括除外を使わない。補助位置の件数・選択・ラベルは Rust の独立期待値と診断の検査で確認する。由来による早期停止を外して増える候補と `--deny-warnings` の変化は U01 の棚卸しへ含める。

理由: 補助位置は警告の説明に使い、正常区間と拒否原因の証明には使わない。途中の保持と合成も固定上限で抑えれば、Lean の保証を保ち、解析予算についての厳密な一致を検査できる。

### D16 の追記（2026-10-26、RV-C3 を受けて）

【計画の判断】Range の成功値の由来は、保存の直前に保持一項（auxiliary）として計上し、操作数は加えない。操作数は、認定の走査（`rangeCall`・`rangeOrigin`・`rangeMatch`・`rangeArm`/`readRangeArm`）が読む要素ごとに数える。本文の「由来の一箇所を各1回と数える」は、この Range の由来には当てはめない。走査の正確な順序と回数は Lean の `BudgetRange`・`BudgetRangeBorrow` の各関数を正とする。

### D16 の追記（2026-10-26、L25R・L25S を受けて）

【計画の判断】固定の定義域（シフト）の認定の走査、引数の選択、W0404 の候補の保存の順序と回数は、Lean の `BudgetRange`（`rangeCall`・`rangeStandardAt`・`rangeStandard`・`domainCallShape`）、`BudgetDomainScan`（`domainEntry` ほか）、`BudgetSelect`（`selectArguments`・`bindingArgument`・`selectedFixedOwn`）、`BudgetAnalyze`（`expr`・`fixedOwn`・`saveWarnings`）の各関数を正とする。標準表の照会は型引数のない `.funName` の頭だけで行う。この形で予算の固定表は A18 の後の表と一致するので、A19〜A21 は表を作り直さない。（2026-10-26 の訂正、RV-A21 の軽1: L25T で、型引数とエフェクト引数のない `.primName` の頭も照会の対象に加えた。交換は組み込みの関数と組み込みの操作の両方を `.primName` の頭で書き出す。A19b で予算の固定表を作り直した。操作の除外は頭ではなく、標準表に操作の固定域の項を置かないことに依る。）

### D17 識別と独立した交換

【計画の判断】式のキーは、モジュールを含む定義名と、型付きSurfaceを先行順に訪問した番号の組とする。53構成子と相互帰納の子のフィールド順・列順を固定する。解析が未対応の部分木にも番号を付ける。番号付けの予算を超えた後は、番号を取得できなかったと報告して停止し、残りを詰めた番号で再開しない。

独立したinterval-corpusの初版1を設ける。既存corpus14とsidecar6の版は上げない。型、標準宣言、定数、予算の消費、正常値の区間、失敗、未知の理由、警告の位置を比較する。全ての結果がTopであるだけの一致は受け入れない。

理由: 既存の六入口へ新解析のデータを混ぜず、識別規則と深い欄の拒否を独立して確かめられる。識別の失敗を正常な未知と取り違えない。

出どころ: interval-analysis 9.4。形の詳細はplanの「受け渡す契約」。

### D18 Rangeと固定の定義域の評価規則

【計画の判断】標準Rangeと固定の定義域を持つAPIの振る舞いは、新設する対象構文の評価関係の定義として与える。交換で渡す標準束縛の表に評価規則を付ける。中心定理の前提にもReleaseのδの仮定にも加えない。

【決定】（2026-10-24、設計者。RV-C0 の中3）標準束縛の同定は、抽象環境に標準束縛の表と出現の同定表を持たせ、`Models` に具体環境の `standards`・`apiAt` が抽象環境のものと等しいことを加えて扱う（案 a）。中心の命題の文面は変えない。同定の一致は、標準 API の振る舞いや δ との一致の仮定ではないので、上の「前提に加えない」に反しない。C1 の閉鎖までに `Models` をこの形にし、L18 以降はこれを使う。

Rangeの規則は、解決済みcheckInteger/valueとResult.Okの同一性、三入力のInteger64表現可能性、端点の順序、三欄の保存、InvalidBoundsを先にする結果を定義する。同じ成功値への対応は束縛番号で表す。Checked.Range.make_okと射影の補題を使って、この定義の内側で所属を証明する。固定域の規則も、標準宣言と引数または欄の同定、正常域とその外の失敗を定義する。

これらの規則とRange.bnt・VMの一致はA1の信頼の範囲であり、証明せずVMとの比較で確かめると07-04へ書く。独立期待値は定義の内側の検査であり、VMとの一致の証拠を代用しない。X03では比べられるAPIと比べられないAPIを分け、後者もA1の限界として記す。L02のレビューで、profileごとの拡張が中心定理の前提を増やさないことを確かめる。この形では済まず前提や公理が必要と判明したらD15の停止条件に従う。

理由: 小モデルの証明だけから標準ソースと実行時の振る舞いの一致を結論しない。A1の範囲を保ち、接続の条件を新しい仮定として隠さない。

出どころ: interval-analysis 8.3・9.3、現行Checked/Range.lean、P1Rの取りまとめの判断。

### D19 警告W0404と既存警告の文言

【計画の判断】未使用のW0404を予約する。diag::codesの既存行と同じ、コード・種類・主文・ラベル・注記・説明の形を次で固定する。fixは付けない。field_messageは欄の場合に主文として選ぶ型板であり、診断を追加で一件作るものではない。

```rust
W0404 Check "argument `{parameter}` to `{function}` is always out of range" "always out of range"
    [field_message: "field `{field}` of argument `{parameter}` to `{function}` is always out of range",
     inferred_range: "the inferred interval is {interval}",
     allowed_range: "the allowed range is {range}",
     local_analysis: "this local analysis applies only if execution reaches this call and all arguments are evaluated successfully",
     origin: "this binding or comparison contributes to the inferred interval"]
    "Local interval analysis shows that the argument or field is always out of range. If execution reaches this call and all arguments are evaluated successfully, the call stops the program at runtime.";
```

欄の主文の具体例は ``field `status` of argument `response` to `Http.respond` is always out of range`` とする。日本語の説明は「この呼び出しに到達して全引数の評価が正常に終わった場合、引数または欄が許される範囲の外にあるため、呼び出すと実行時に停止する」である。一次位置は対象引数または欄、補助位置はbind・比較を最大8箇所とする。区間は閉区間として表示する。

W0401・W0402は主文と一次ラベルを保ち、追加する注記と英語の説明を次で固定する。既存定数評価の診断には取得できた注記だけを付け、新しい局所解析の候補にはlocal_analysisを付ける。

```rust
W0401 Check "this divides by zero" "the divisor is always 0"
    [inferred_range: "the inferred divisor interval is {interval}",
     local_analysis: "this local analysis applies only if execution reaches this operation and all operands are evaluated successfully",
     origin: "this binding or comparison contributes to the inferred interval"]
    "Constant evaluation or local interval analysis shows that the divisor is always zero. If execution reaches this operation and all operands are evaluated successfully, the division stops the program at runtime.";
W0402 Check "this calculation overflows `{ty}`" "always overflows"
    [inferred_range: "the inferred result interval before the range check is {interval}",
     allowed_range: "the range of `{ty}` is {range}",
     local_analysis: "this local analysis applies only if execution reaches this operation and all operands are evaluated successfully",
     origin: "this binding or comparison contributes to the inferred interval"]
    "Constant evaluation or local interval analysis shows that the result does not fit the type. If execution reaches this operation and all operands are evaluated successfully, the calculation stops the program at runtime.";
```

01-04では、新しい局所解析について「処理系は、予算の範囲で確実と判定した除数0・あふれ・固定域外の引数を警告してよい」と定める。旧定数式の警告の規範は保つ。

理由: 実行時R0701のout of rangeに語をそろえ、欄と直接引数を同じ警告コードで説明する。局所解析の網羅的な警告を言語仕様の義務にすると、予算で未知へ退く扱いと衝突するため、許可の規範にする。

出どころ: interval-analysis 5.1・7.2、crates/benitoite/src/diag/codes.rsのW0401・W0402・E1010・R0701。

【計画の判断】D19 の追記（2026-10-26、D4 の変更を受けて）: W0404 の対象はシフトの直接引数だけになったので、field_message の型板は登録しない。説明の「the argument or field is always out of range」は「the argument is always out of range」とする。ほかの型板と説明の文は変えない。

### D20 数値と構成の境界

【計画の判断】端点と加減算・符号付き定数倍はi128、UnsignedInteger64の積はu128で比較後に戻す。保持項目数はD16の抽象の単位で数え、カウンタは検査付き演算を用いる。予算定数は32ビットにも収まる値とし、JSON端点は十進文字列で交換する。Range/HTTP等は構成に実在し解決済みの宣言だけを表で認め、中核へネットワーク・Wasmtime・暗号の依存を増やさない。

理由: 最大u64同士の積はi128に収まらない。言語の幅をホスト幅と混同せず、モジュール不在を解析で補わない。

出どころ: interval-analysis 8.1・11、AGENTS.md「改造の設計で守ること」。

### D21 用語・検査報告・到達の観測

【計画の判断】用語集へ区間解析（interval analysis）を加える。Rangeの入力と結果の規則、および対象構文の評価関係の呼び名は、末尾の設計者の選択に従って用語集と02-05・07-04へそろえる。

解析の未実施数と理由は、内部集計と非実行の検査報告の追加欄へ出す。追加欄はintervalAnalysis.coverageのall/some/noneを使い、既存の報告全体のpartialという説明と重ねない。既存completeは、型・エフェクトの検査と契約抽出の完了の意味に保つ。coverageは報告の受け入れ判定を変えず、警告なしを安全の証明にも変えない。06-01・06-04・02-10・06-06と、手書きのinspection.md・SKILL.mdの受け入れ規則を同じ契約にそろえる。

VMとの差分テストの到達は、比較専用ソースの標識出力と実行時診断の位置で観測する。VM本体へ観測用フラグを足さない。

理由: 報告全体の成功と、追加解析が覆った範囲を別々に読めるようにする。試験のためにVMの実装を変えず、観測できないAPIを比較済みに数えない。

出どころ: interval-analysis 1.1・8.4・9.4、現行cli/check_report.rsとSkill。詳細はplanの契約表。

### D22 検査・比較・公開候補

【計画の判断】型検査・診断のRust作業のworkは統合ターゲットを絞らず全件とする。check-formal全体は接続を閉じる区切りと最終の関係状態に割り当てる。取り込みごと（少なくとも処理系の段ごと）にB0とのshortを行い、targets/fullは割り当てない。最後の作業だけで0.0.12・訳・CHANGELOG・同梱物をそろえ、集約・タグ・pushは設計者の指示を待つ。

理由: 前回のnamed_argumentsの見落としを繰り返さない。性能目標を約束せずソースだけの候補を準備するため、了承を要するtargets/fullを一律には加えない。

出どころ: 今回の依頼、07-03、benchmark・git-workflowの公開スキル。


## 設計者の選択（2026-10-24）

設計者は2026-10-24に二つの表記を次のとおり選んだ。(1) は原語 function summary とする。(2) は「対象構文の評価関係」とし、英語の表記 evaluation relation for the target fragment を併記する。U02では、この二語を用語集へ加え、02-05・07-04にそろえる。この節は機能の範囲やA1を問い直すものではない。以下の外部資料の確認日は2026-10-24である。

### (1) function summaryの表記

候補は原語 **function summary**、**関数要約**、**関数のサマリ**である。原語を推し、設計者は原語を選んだ。関数の本体を都度解析せず、入力と結果の関係を規則として使うという意味を、他の解析器の用例と対応させやすいためである。

英語の用例はangrの一次資料[Symbolic Function Summaries](https://docs.angr.io/en/latest/core-concepts/loading.html#symbolic-function-summaries)にある。study 1.1には、Clangの[StdLibraryFunctionsChecker](https://clang.llvm.org/doxygen/StdLibraryFunctionsChecker_8cpp_source.html)のSummary/ArgConstraintと、日本語訳の「関数のサマリ」の用例も挙がる。「関数要約」が定着した訳語だとは断定しない。studyが日本語の用例として挙げた[angr日本語訳](https://ntddk.github.io/angr-doc-ja/docs/loading.html)は今回も開いたが、現在のそのページでは該当する見出しを再確認できなかったため、studyの確認記録として参照するにとどめる。

### (2) 対象の構文に限った評価関係の呼び名

旧稿の「部分評価器」は、確立した術語である部分評価（partial evaluation）と重なる。Jones・Gomard・Sestoftの著者公開資料[Partial Evaluation and Automatic Program Generation](https://studwww.itu.dk/people/sestoft/pebook/)は、既知の入力に合わせてプログラムを特殊化し、残りの入力を受け取るプログラムを生成する技法を説明する。本計画は特殊化後のプログラムを生成せず、対象構文の値・失敗・到達を定める関係を作るため、この術語を当てない。

| 候補 | 原語・一次資料と日本語の用例 | 本計画での意味と推す理由 |
|---|---|---|
| **対象構文の評価関係（evaluation relation for the target fragment）（推す。選ばれた）** | Software Foundationsの[Imp: Evaluation as a Relation](https://softwarefoundations.cis.upenn.edu/lf-current/Imp.html)に評価を関係で定義する用例がある。日本語の一次資料である五十嵐の[ソフトウェア基礎論配布資料(2) §3](https://www.fos.kuis.kyoto-u.ac.jp/~igarashi/class/sf07w/resume2.pdf)は「評価関係」を帰納的な規則で定める | EvalPartialを指す。対象を限定する修飾を既存の術語「評価関係」に添える普通の説明であり、新しい術語を作らず、未対応を非決定的に扱う関係にも使える |
| **対象構文の大ステップ操作的意味論** | 同じ評価スタイルの原語はbig-step operational semanticsである。水野・住井の一次論文[無限の入出力を行う関数型プログラムのK正規化の形式的検証 §6.1](https://jssst.or.jp/files/user/taikai/2016/PPL/ppl8-2.pdf)に、日本語「大ステップ操作的意味論」と評価関係を入出力列で拡張する定義がある | 結果とtraceを一つの関係で与える点を説明できる。ただし意味論全体の名称として読まれやすく、本計画の限定した範囲には第一候補の方が短い |

evalClosedは、この関係に対応する閉じた対象入力用の実行可能な評価関数と呼び分ける。上の文献の体系と本計画の未知・失敗の規則が同一だという主張はしない。


## セキュリティの追加項目（2026-10-24、P2）

READMEの「設計者の決定（2026-10-24、Lean の作業の途中）」に従い、TODO-284・285・286を第6弾に含める。C1とL26を閉じた後、A01より前にS01〜S05を直列で受け入れる。実装担当はdocs/todoを読まず、以下とplanのS作業群を使う。2026-10-24の設計者の追加指示に従い、P2RでD25・D26・D30と作業の割り当てを改めた。照合の時点・最後の検査での表示だけの扱い・独立して呼べるスキルの追加は決定済みであり、自動選択の範囲などの実装案を取りまとめが確認する。

第6弾の最初の依存の勧告照合は、2026-10-24にP2で実施済みである。ワークスペースとfuzzは同じ19件を検出し、TODO-284・285の既知の19件に一致した。設計者はその対応を第6弾へ組み込むと決めた。根拠と入力はpreflightのP2記録に残す。ツールチェーンの網羅的な照合まで済んだという意味ではない。

### D23 TLSの依存の更新と今回の境界

【決定】`crates/benitoite/Cargo.toml`のrustlsを`=0.23.46`へ上げる。間接依存のrustls-webpkiは0.103.16以降の0.103系列、webpki-root-certsは1.0.10以降の1.0系列へ更新し、ルートと`fuzz/Cargo.lock`で同じ版にする。間接依存を固定するためだけの直接依存は増やさない。ureq・rustls-graviola・OSの検証器の選択とCargo機能は保つ。

理由: rustlsの四件は0.23.46で直り、経路の検証とルート証明書の二つの更新も必要である。対象構成で検出されない間接依存も、ロックを別途照合して更新漏れを防ぐ。

影響の評価: rustlsのRUSTSEC-2026-0349は、認証前に記録した鍵交換の選択が後の接続に影響するため対象になりうる。0346（独自のセッション保存でのDebug）・0347（ECH）・0348（brotli）は現行の設定では該当しないと見込むが、ignoreで除かず修正版へ上げる。rustls-webpkiの0382はLinuxの証明書経路の検証に関わる。webpki-root-certsの0383はロックに存在するが、現在の対象構成には現れない。webpki-rootsの0381は依存にない。

CRL・OneCRLの導入と、Linux利用者へのca-certificatesの更新の案内は今回扱わず、docs/todoのTODO-284に残す。更新だけで一般の失効確認を実装したとは書かない。

出どころ: docs/todoのTODO-284、[rustls 0349](https://rustsec.org/advisories/RUSTSEC-2026-0349.html)、[webpki 0382](https://rustsec.org/advisories/RUSTSEC-2026-0382.html)、[root-certs 0383](https://rustsec.org/advisories/RUSTSEC-2026-0383.html)。外部資料の確認日は2026-10-24。

### D24 Wasmtimeの修正版と勧告の照合

【決定】Wasmtimeを`=49.0.2`から`=49.0.4`へ上げ、`fuzz/Cargo.lock`も揃える。機能は`default-features = false`と`runtime`・`component-model`・`std`・`cranelift`を保ち、async・component-model-async・WASIを足さない。50系列への移行は別の判断とする。`deny.toml`へ`[advisories]`を加え、ルートとfuzzを別々に照合する。

理由: 49.0.2に当たる14件のうち、aarch64のCraneliftによるsandboxからの脱出を含む二件は49.0.4で直る。同系列の修正に絞り、構成と同期呼び出しの契約を維持する。

影響の評価: 0379は対象のaarch64構成に影響し、0359（型の破棄の再帰）・0363（取っ手の増加）も到達しうる。0364は既定で有効な例外機能に関わる。0360の補助コンポーネント間の文字列転送への影響は未再現であり、更新時に既存の転送検査を通す。0353〜0358・0361・0362・0378は非同期経路なので到達しないと見込むが、検証での拒否はS02aで確かめる。非到達という見込みをignoreの根拠として修正版への更新を省かない。

出どころ: docs/todoのTODO-285・286、[Wasmtime 0379](https://rustsec.org/advisories/RUSTSEC-2026-0379.html)、[取っ手の上限の勧告](https://github.com/bytecodealliance/wasmtime/security/advisories/GHSA-q554-3cjc-rx7p)。確認日は2026-10-24。

### D25 最初の勧告照合と検査での表示

【決定】勧告の照合は改造の最初の段階で行い、影響の評価を見て、改造へ組み込むか別に対応するかを設計者が決める。公開のAGENTS.md「改造の進め方」では、改造のディレクトリを作った後、対象と実装プランを確定する前の手順に加える。共通のchange-plan-template.mdの「前提と依存」には照合日・記録・対象・設計者の判断を置き、段の最初に照合と判断の行を用意する。共通のimplementation-request.mdには、取りまとめが起動前にその記録と判断を確認し、実装担当へ必要な内容を写す規則を加える。この公開手順の更新はS04、具体的な照合手順のスキルはD30/S05へ割り当てる。privateのorchestrationは読まず変更しない。

【決定】検査の`advisories`単位は、勧告を検出しても終了0とし、検出した勧告を目立つ形で表示する。ルートとfuzzの二照合へルートの設定を明示して適用し、それぞれの結果を表示する。取得不能・照合不能と、照合できた上での検出0件を区別する。表示と終了の詳細はD26による。

【計画の判断】表示だけの単位としてreleaseとchangeで常に自動選択し、workは依存のmanifest・二つのlock・deny設定を変えた場合に選ぶ案を引き続き推す。work/stage/change/releaseの名指しも受け付け、旧水準なしの`--only`・`--full`の集合は保つ。選択肢はreleaseだけ、changeにも加える、全workで行う、依存変更時のworkにも加える、である。理由: 最初の判断後に公表された勧告と、依存更新後の照合結果を報告でき、検出によって最後の検査を不合格にしない。無関係なworkごとの取得は省く。releaseの自動選択はS03以降`release_stack,advisories`になるので、07-03・公開手順・スクリプト・自己検査を同じ変更でそろえる。

### D26 照合結果の表示・記録と新しい勧告の引き継ぎ

【決定】change・releaseで新しい勧告を検出した場合は、表示し、結果の記録に残し、取りまとめが設計者へ報告する。その検出を理由に検査を不合格にせず、受け入れを止める条件にも加えない。次の改造の最初の照合で、対応を組み込むかを設計者が決める。改造がない時の手動・周期的な対応にはD30のスキルを使い、別に直すかも設計者へ判断を仰ぐ。

【計画の判断】`advisories`の結果は対象別に「勧告あり」「照合済み・検出0件」「取得不能・照合不能」の見出しで、色なしでも識別できるように表示する案を推す。勧告ありではID・クレートと版・件数・一次資料・修正版を示す。取得不能では失敗した対象と理由を目立つ形で示し、片方が未照合なら全体を検出0件としない。取得不能や道具不在も表示と記録の対象として単位は終了0とし、最後の検査にネットワークや道具の有無を新しい不合格条件として加えない。設定の誤りや実行器自体の不具合は通常の終了1で扱い、勧告の検出・取得不能とは区別する。生のcargo-denyの終了状態を丸ごと無視せず、二照合の状態と単位の終了状態を別々に保存する。

DBは照合時に更新し、URL・コミット・取得日時、cargo-denyの版、各lockのハッシュ・対象構成・検出ID・生の終了状態を記録する。取得できない欄は未取得と書く。担当は依存経路・機能/API・影響の根拠と修正版を追記し、最初の照合との差を取りまとめへ渡す。同じlockだけを根拠に過去の「最新の照合」を引用しない。

ignoreの例外運用は新設しない。`deny.toml`のignoreは空とし、勧告を表示から除外せず、非到達・対応済み・次回に判断する事項は照合記録とdocs/todoの項目で管理する。ignoreの期限の経過や未追加を候補の停止条件にする旧案は取り下げる。最初に組み込むと決めたS01/S02の修正版と挙動の完了条件は維持し、最後に新しく見つかった勧告の扱いと分ける。

出どころ: 2026-10-24の設計者の指示。cargo-denyの設定キーはP2で確認した[0.20.2の実装](https://github.com/EmbarkStudios/cargo-deny/blob/0.20.2/src/advisories/cfg.rs)に合わせ、未確認のキーを追加しない。

### D27 取得元の制限

【計画の判断】`[sources]`は同じ変更に加えない案を推す。選択肢はcrates.io以外のレジストリとgitを拒否する設定・sources検査も加える案、勧告の照合に絞る案である。理由: sourcesはadvisoriesと別の検査であり、節だけを加えても検査されない。現在の二つのlockの外部取得元はcrates.ioだけであり、取得元の規則と例外の運用を今回の修正版更新から独立して判断できる。取得元の制限、公開先でのDependabotの有効化、Leanの独立したカーネル検査器の評価はdocs/todoのTODO-286に残す。

出どころ: [cargo-denyのsources設定](https://embarkstudios.github.io/cargo-deny/checks/sources/cfg.html)（2026-10-24確認）。

### D28 コンポーネントの取っ手の上限と診断

【計画の判断】`Store`ごとの生存する取っ手を専用の資源として数え、上限100,000を処理系の定数で明示し、共通の`new_store`で`Store::set_max_component_handles`へ渡す案を推す。上限超過の報告先はR0906とする。選択肢はWasmtimeの既定に任せてR0601を許す案、既存のコアインスタンス数16または表の要素数10,000と同じ値へ下げる案、別単位として100,000を固定する案である。

理由: インスタンス数・コアの表の要素数と、コンポーネントの取っ手の数は異なる。既定より下げる根拠はまだなく、同じ数へそろえると受理範囲を狭める。専用の上限・資源名とR0906を02-09・02-10・03-10へそろえ、既定値の変更に依存させない。

APIの存在と上限の意味は上流の勧告で確認したが、現行処理系で超過がR0906かR0601かは未実行である。S02bは更新直後の実コンポーネントでまず再現し、原因の型・原因列と報告を記録する。公開の型で識別できればそれを使い、非公開なら49.0.4で確認した厳密な原因だけをtext.rsへ加える。広い部分一致でゲストの任意のトラップを資源不足にしない。必要数を取得できないときは架空の数を表示せず、上限と超過の事実を示す診断へ調整する。分類の新しい文言・保持方式の変更が必要なら取りまとめへ戻す。上限直下・超過・drop後の再利用と、中断・燃料・メモリの分類の優先を確かめる。

出どころ: D24の取っ手の上限の勧告、現行runtime.rsの`new_store`・`failure`とtext.rs。

【計画の判断】（2026-10-25、取りまとめ。S02b の停止を受けて）Wasmtime 49.0.4 の取っ手の上限の超過は、原因が数を含まない一件の文字列（`cannot allocate another handle: store handle limit exceeded`）で、公開の `Trap` にも当たらない（`s02b/results.md`）。そこで、既存の `ResourceError::ExternalObjects` の必須欄（必要数 size）は保ち、取っ手専用に `ExternalComponentHandles { function, component, limit }` を加える。R0906 に必要数を要求しない文言の variant を加え、本文を ``the external function `{function}` exceeded the limit of {limit} component handles`` とする。分類は 49.0.4 の原因の文言の完全一致で行い、広い部分一致を使わない。統計の `reached_limits` に取っ手の項目を加え、02-09・02-10・03-10 をそろえる。理由: 架空の必要数を表示せず、既存の四つの資源の保持形式と利用箇所を変えないためである。

【決定】（2026-10-27、設計者。RV-G 中2）component handle は「コンポーネントハンドル（component handle）」と表記する。各章の初出と用語集で原語を併記する。言語の値としてゲストの資源を参照する外部ハンドルと、Wasmtime が Store 内で数えるコンポーネントハンドルは区別する。過去の結果とレビューの表記は変えない。

出典: 日本語の handle の用例は Microsoft Learn の [GCHandle 構造体](https://learn.microsoft.com/ja-jp/dotnet/api/system.runtime.interopservices.gchandle?view=net-8.0)で「ハンドル」を確認した。原語と資源の意味は [Wasmtime 49.0.4 の `Store::set_max_component_handles`](https://github.com/bytecodealliance/wasmtime/blob/v49.0.4/crates/wasmtime/src/runtime/component/store.rs)の配布ソースで確認した。Store 全体で同時に生存する項目を数え、`resource.drop` による解放で枠を返す API である（2026-10-27確認。Web の同版の API とソースのページは取得できず、取得済みの配布ソースを読んだ）。GCHandle は日本語の用例の根拠であり、同じ資源の仕様を示すものではない。

【決定】（同日、設計者）「到達記録（evaluation trace）」の語は保つ。原語の用例の根拠は Acar・Ahmed・Cheney・Perera の [A Core Calculus for Provenance](https://arxiv.org/abs/1310.6299)の第3節、特にトレースを伴う評価規則とトレースの性質（3.1・3.2節）である。論文は評価の結果とトレースをともに与える。Benitoite では対象演算のキー・演算・正常に得た引数・結果の列に範囲を限る。この定義は用語集と 01-12 を正とし、論文のトレース全体と同一とはしない（2026-10-27確認）。

### D29 WASMの例外機能

【計画の判断】今回`Config::wasm_exceptions(false)`を加えず、修正版の既定を保つ案を推す。選択肢は、今無効にして例外を使うパッケージを拒否する案、既定を維持する案である。理由: 0364は修正版で直り、例外を使う外部パッケージがないとは確認できていない。機能を無効にして受理範囲を変える必要はない。S02aで既存ゲストと、例外・非同期機能を持つ最小ゲストの受理/拒否を確認し、現行構成の境界を記録する。新しい非同期機能を有効にして検査を通さない。

### D30 ツールチェーンの照合と独立して呼べるスキル

【決定】改造がない時にも手動・周期的に呼べる、セキュリティの勧告に対応するプロジェクトのスキルを追加する。【計画の判断】名前は`security-advisories`を推す。実体を`.claude/skills/security-advisories/SKILL.md`へ置き、`.agents/skills/security-advisories`から`../../.claude/skills/security-advisories`への相対のシンボリックリンクを作る。AGENTS.mdのディレクトリ構成の表にも名前を加える。S05が担当し、同梱の言語利用者向けSkillとは分ける。

スキルには、ワークスペースとfuzzの依存の照合、Rust・Cargo・Lean・elanの版と勧告の照合、対象構成と使用する機能/APIからの影響の評価、docs/todoのREADMEに従う項目の追加・既存項目への追記、改造へ組み込むか別に直すかを設計者へ判断を仰ぐ手順を置く。改造中の記録は改造の`security-advisories.md`、作業中は当該results.mdから参照する。改造がない時はdocs/todoの該当項目に日付・根拠・判断を残す。公開文書には非公開の記録へのリンクを作らず、項目番号で受け渡す。

【計画の判断】公開のgit-workflowのソースだけのリリース手順にも、二lockとRust・Cargo・Lean・elanの固定版の再照合を加える案を推す。具体的な照合先と評価手順は新スキルへ集め、S04はその参照と候補の記録・報告の責任を記す。新しい勧告はD26と同じ表示・記録・報告にとどめ、公開候補を不合格にしない。理由: cargo-denyはコンパイラやLeanカーネルの勧告を代わりに確認しない。Lean担当のビルドや証明の規則を今回変えず、版と影響を人が確認する。

照合先は[Rustの告知](https://blog.rust-lang.org/)、[rust-lang/rust](https://github.com/rust-lang/rust/security/advisories)・[rust-lang/cargo](https://github.com/rust-lang/cargo/security/advisories)、[leanprover/lean4](https://github.com/leanprover/lean4/security/advisories)・[leanprover/elan](https://github.com/leanprover/elan/security/advisories)と[CVEの記録](https://www.cve.org/)とする。Leanの固定版はLean担当が引き渡す候補の情報から受け取り、例として[カーネルのCVE-2026-72844](https://www.cve.org/CVERecord?id=CVE-2026-72844)と修正版の範囲も照合する。P2/P2Rでは今日のツールチェーンの無影響を新たに実証したとは書かない。S05で手順を揃え、Z01bで実候補に対して実施する。

周期的な呼び出しの候補は、Claude Codeの`/loop 1d /security-advisories`と、Claude Code DesktopのローカルのScheduled tasksで同じスキルの実行を指示する方法である。[公式の/loop手順](https://code.claude.com/docs/en/scheduled-tasks)では、間隔付きのプロンプトとスキルを繰り返し実行でき、開いたセッションを要することを確認した。[Desktopの公式手順](https://code.claude.com/docs/en/desktop-scheduled-tasks)では、ScheduledからNew taskを作り、ローカルフォルダ・指示・周期を設定でき、起動中のアプリと起きている端末を要することを確認した（2026-10-24）。手動は`/security-advisories`またはスキル名を指定した依頼とする。手元の版での利用可否と実動作は未確認であり、S05が出典と確認範囲を記す。定期実行の登録やLLMの実呼び出しは今回の実装・検証に含めず、運用者が周期と実行環境を選ぶ。

### (3) 警告の出る構文上の範囲の呼び名（2026-10-25）

設計者は、C1Rb1 で「警告領域」と仮に呼んだ集合（一つの解析入力の根から対象構文の評価関係の具体規則だけで辿れる構文上の出現の集合）を、原語 syntactic reachability、日本語「構文的な到達可能性」と呼ぶことに決めた。用例は Frama-C の Metrics plug-in の文書（syntactic reachability を、実際に解析した範囲の過大近似として区別する）。日本語の定着した用例は確認できていない。実行の到達可能性とは違うことを用語集と 01-12 の定義に書く。候補と出典は `c1rb3c/results.md` にある。
