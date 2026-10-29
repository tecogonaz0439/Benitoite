# RV-V10.2b: 英語の reference・Skill・生成物の独立レビュー

2026-10-30。対象は未コミットの差分（基準 `c0a4673a`。英語7ファイル）と `v10.2b/`。ファイルと git の状態は変えず、レビュー用の target で今の CLI と v0.0.12 の CLI（`git archive v0.0.12` から作った）を作り、文書の主張を入力で確かめた。試した入力を `v10.2b/rv-probes/` に写した。

結論: 重大0・中3・軽3。中の3件を直してから取り込む。地の文だけの直しで、W-E のやり直しは要らない。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `skill/references/language-comparison.md` の Functions の比較表（157〜160行） | 追加した段落（"The String-based File entries and `Http.get` above have Top target scope. …"）が表の `requests.get` の行と `assert a == b` の行の間に入り、表を二つに割っている。後ろの `assert` の行は見出し行も区切り行もなく、段落の続きとして描画される。link-audit・skill_docs・skill_examples は検出しない | 段落を表の末尾の後へ移す |
| 中2 | 中 | `skill/references/inspection.md` 52行 | "The candidate reference linked above defines …" の "candidate" はリリースの作業の段階の語で、埋め込みの Skill に入ったまま配布され、公開後は事実でなくなる。埋め込みの Skill の編集は V10.2b で終える決まり | "The v0.0.13 reference linked above defines …" のように版の名前で書く |
| 中3 | 中 | `v10.2b/changelog-draft.md` の「H21: Fixed」 | 公開した 0.0.12 にはこの誤った E0501 がなかった可能性が高い。v0.0.12 の CLI で、Top の File.Read の全11操作の完全ハンドラを持つ lambda を後の `tick` の節から呼ぶ形を二通り（`h21f12b.bnt`・`h21p12.bnt`）試し、どちらも終了0で受理された。RV-R20.4 の中1 は範囲付きの `File.Read["/data/a"]` で見つかり、「退行ではなく新しい機能の取りこぼし」とされている。CHANGELOG は前の公開版との差なので、0.0.12 の利用者が見ていない拒否を "Fixed" と書くと事実に反する | RV-R20.4b の入力（50個・200個）を v0.0.12 で再現する。拒否されなければ H21 の項目を CHANGELOG から外す |
| 軽1 | 軽 | `docs/reference/benitoite.md`「Record generators and shrinkers」、`SKILL.md`「Reference documents」の derive の版の段落 | 補正で既存の手順の文（"Finish pending apply/recovery with the saved old tool before updating it"、"Verify/Authenticate old body hashes"、"run normal check/test and derive check after apply"）が消えた。`tools/derive/README.md` に同じ内容があり、重なる説明を写さない決まりにも合うが、results.md の H19 の行と訳の対応表はこの削除に触れていない | 意図した削除であることを results.md に書き、訳の対応表にも同じ文を消すと書く |
| 軽2 | 軽 | `docs/reference/benitoite.md`「Complete and partial handlers」の File.Write の行 | 並びが `writeBytesIn, appendBytesIn, appendBytes` で宣言の順と違う。数（16）は正しい | `File.bnt` の宣言の順にそろえる |
| 軽3 | 軽 | `SKILL.md` 168行 | "The executable's embedded documents supply the corresponding installed-version text." は、`docs/reference/benitoite.md` の本文がそのまま同梱されていると読める。埋め込みは Skill と生成参照だけ | "The embedded grammar, diagnostics, and standard-library references describe the installed version's syntax, diagnostics, and signatures." のように範囲を限る |

## CLI で確かめたこと（問題がなかった点）

- 部分ハンドラ: readText の節だけ・12操作の節は E0501、13操作で受理。`Http.send` の節だけは Http.Connect が残って E0501、`send` と `sendIn` の両方で受理。`Http.get` も二つの節で処理できる。`File as F` は E0339。
- 宣言した狭い戻り値: bind で widen すると E0519 unknownSource、同じ狭い型のまま `readTextIn` へ渡す形は受理、狭い引数の射影と補間の中の射影は E0519、`const` を条件に使った検査は狭い範囲を選ぶ。
- IP/CIDR: CIDR・正規形の IPv6・`/32` を受理し、`/32` は正確なアドレスと同じ原子で重複は E0419。不正な IPv4・正規形でない IPv6・IPv4 射影の対象は E0460、ホスト部が0でない CIDR・IP の語幹のワイルドカード・角括弧付きは E0459。射影のパターンは受理されどの対象とも一致しない。直接の検査は `127.1` と `2130706433` を名前として受理し、URL では拒否する。
- 新しい入口の既知不良（checkPathIn の E0459・E0462、checkRequestIn のポートの逆転の E0461、不良の URL は実行時の InvalidUrl）、`bounds`・`expanded` の形、IO.All が Log を含まないこと、名前だけの `--allow-effects`、RequestCheckError の `or die` の E0705、E0519 の理由の名前、範囲を取らない効果の範囲の引数の E0513。
- 保証の範囲を広げて読める文、実行時の権限制御・情報フロー制御があると読める文、全比較で証明済みと読める文はない。
- 全操作の数（File.Read 13・File.Write 16・Http.Connect 2、不足の12と15）は宣言と一致し、外部の件数は不明のまま。
- 固定参照14出現・9種類は漏れなく、v0.0.12 の3見出しはタグに実在する。v0.0.13 のタグを取得できたとは書いていない。
- 生成参照66ファイルは不変。`bundle.rs` は `include_str!` の一覧だけで本文のハッシュを持たないので、G の再実行は要らない。
- W-E の後の補正は地の文だけで、W-E の各検査の結果は古くならない。
- 訳の対応表の20箇所は変更位置と一致し、H20 の CHANGELOG の文案は事実だけ。差分に手元のパス・作業の ID・担当の名前はない。
- 確かめていないこと: 文書の check/error の例が空の Effects になる点は、`test --check` の報告に例が対象として現れず確かめられなかった。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1・中2・軽1〜軽3 | 採る | V10.2bb |
| 中3 | V10.2bb で RV-R20.4b の入力を v0.0.12 で再現する。0.0.12 で拒否されなければ、H21 の項目を CHANGELOG の文案から外す（CHANGELOG は前の公開版との差を書くため。設計者の委任による取りまとめの判断、2026-10-30） | V10.2bb |
