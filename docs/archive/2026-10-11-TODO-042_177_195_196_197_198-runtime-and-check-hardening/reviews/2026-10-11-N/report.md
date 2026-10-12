# 作業 N のコードレビュー

Opus のサブエージェントが行ったレビューである。サブエージェントがファイルを書けなかったので、オーケストレータが返答から写した（一部を縮めた）。

## 対象と方法

- 対象: ブランチ `impl/hardening-N` の、基準 8ed94af からコミット 4a3cc0c までの差分（10 ファイル、追加 272 行・削除 45 行）。
- 読んだもの: 依頼文（事前点検の補足 1〜15 を含む）、報告、`study-uses.md` と `decisions.md`、差分の全体。
- 確かめたこと: 作業ディレクトリで作った `target/debug/benitoite` に、リポジトリの外に置いた `.bnt` を `check` と `run` で渡した（`study-uses.md` の表の 6 つの形、同じ名前の別名、純粋なモジュールへの別名、`as Benitoite`、利用者のモジュール `IO/Console.bnt`・`Lib/Console.bnt`、E0323・E0324・E0305・E0321・E0332・E0501 との組み合わせ）。基準の `imports.rs` に戻した一時の写しで、新しいテストが直す前に落ちることを確かめた。`cargo test -p benitoite --lib resolve::`（27 件）、`effects::tests`（17 件）、`BENITOITE_GOLDEN_FILTER=todo177` のゴールデン、`skill_docs`（8 件）が通り、`gen_skill` の後に差は残らない。

## 所見

要修正の所見はない。

### 1. 対象のモジュールに別名がある衝突で、要らない修正案を重ねて出す（望ましい）

- 場所: `crates/benitoite/src/resolve/imports.rs` の E0323 の振り分け（85〜96 行付近）と E0305 の `if declares_effects`（132 行付近）。
- 問題: 対象のモジュールの import が既に別名を持つとき（E0339 を出す形）は、E0339 の修正案（`as` を消す）だけで名前の衝突も消える。ところが E0323 は利用者のモジュールの import を書き換える編集を、E0305 は宣言の改名を勧める文を、重ねて出す。
- 直し方の案: 「対象のモジュールで、かつ別名がある」import は、E0323 では `alias` の修正案を付けず、E0305 では `rename` も `import` も付けない。テストに、E0339 の修正案だけを適用すると診断が消えることを足す。

### 2. E0324 と E0339 の編集が同じ行で重なる（参考）

- 問題: `import Benitoite.Unofficial.IO.Console` の後に `import Benitoite.Unofficial.IO.Console as Console` と書くと、E0324（2 行目全体を消す）と E0339（` as Console` を消す）の編集が重なる。修正案をまとめて適用する道具では扱いがその道具しだいになる。
- 直し方の案: 二度目の取り込みに当たる import では E0339 を出さない。

### 3. E0339 の編集だけを適用すると、次の E0332 が別のモジュールの取り込みを勧める（参考）

- 問題: `import Benitoite.Unofficial.IO.File as Console` の下で `Console.writeText(...)` を呼ぶスクリプトに E0339 の編集だけを適用すると、参照の `Console.` が残り、E0332 が `import Benitoite.Unofficial.IO.Console` を勧める。E0339 の文が参照の書き換えを指示しているので、偽装の経路は開かない。`study-uses.md` が指摘した E0501 → E0332 → E0324 の食い違いは解消した。
- 直し方の案: E0339 の編集に、同じファイルの `{name}.` の参照を `{original}.` に書き換える編集を加える（依頼文の決定を変えるので、docs/todo の項目にする）。

### 4. E0321 の修正案が別名を残し、適用すると E0339 になる（参考）

- 場所: `crates/benitoite/src/modules/find.rs` の E0321（差分の外）。
- 問題: `import Benitoite.IO.File as F` の E0321 の修正案は `import Benitoite.Unofficial.IO.File as F` で、適用すると E0339 になる（2 段で通る）。
- 直し方の案: 後の項目にしてよい。

### 5. コメントの根拠と説明の文の言い回し（参考）

- E0339 の検査に、根拠の設計書の節を示すコメントがない。
- E0339 の説明の文 "so that `uses` always shows their original names" の `their` は modules を指して読める。"so that `uses` always shows the original effect names, such as `Console.Write` and `File.Write`." の方が誤読しにくい。

## 確かめて問題がなかったこと（要点）

- 偽装の経路: `study-uses.md` の表の 6 つの形（`File as Console`、入れ替え、`Process as Console`、`Benitoite.IO as Pure`、`Benitoite.Assert as Log`、`Network.Http as Clock`）は、すべて `check` で E0339 になり、`run` も実行前に止まってファイルを書かなかった。`IO.Clock as C`・`IO.Random as R` も E0339 になる。
- 対象の判定は `BUILTIN_EFFECTS` と取り込み先の `ModuleInfo` の種類と名前で決めており、綴りに依らない。純粋なモジュールと利用者のモジュール `IO/Console.bnt` への別名は通る。
- E0339 の位置・文言・編集は依頼文のとおりで、本来の名前と同じ別名では編集を適用すると通る。E0339 の後も束縛を作るので、偽装の形の `main` は E0339 の 1 件だけになり、存在しない名前は本来のモジュール名で E0303 を示す。
- E0323・E0305 の振り分けは補足のとおりで、既存のゴールデンの出力は変わらない。規約に反する箇所はない。新しい 4 件のうち 3 件は直す前に落ち、もう 1 件は負の場合を守る。Skill の文と生成物は正しい。

## 総評

偽装の経路は、`study-uses.md` が挙げた形のすべてで閉じた。要修正の所見はない。所見 1 は小さな変更で直せるので、取り込みの前に直すのが望ましい。所見 2〜4 は修正案をたどる経路の遠回りで、取り込みを妨げない。
