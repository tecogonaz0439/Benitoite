# D32 OPEN-060 の事実の確認

- 依存する作業: —
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 小（500 行未満。記録の文書が主）
- ブランチ: impl/D32-open-060

## 目的

配布と Skill の導入が前提にする外部の事実（[OPEN-060](../../design/open-issues.md#open-060)）を、一次資料と試行で確かめ、結果を OPEN-060 と [配布形態](../../design/05-platform/05-01-distribution.md)（と [Agent Skills 対応](../../design/06-tooling/06-06-agent-skills.md)）に記録する。リリースのスクリプト（D31）は、この結果に従って道具と手順を決めるので、D31 より前に行う（[README](../README.md) の「U3・U4 で決めたこと」の 17）。

処理系のコードは書かない。依存する作業はないので、いつ始めてもよい。ただし、x86_64 の模倣の上で処理系のテストが動くかの確かめ（下の 2）は、処理系のテストが多いほど意味がある。U2 第 2 段の後に行うのがよい。

## 読む設計書の節

- [OPEN-060](../../design/open-issues.md#open-060) の全体
- [配布形態](../../design/05-platform/05-01-distribution.md): 「対応環境（初回リリース版）」「導入の手順（初回リリース版）」「リリースの試験（初回リリース版）」
- [Agent Skills 対応](../../design/06-tooling/06-06-agent-skills.md): 「Skill の導入（初回リリース版）」
- [ADR 0176](../../design/decisions/0176-first-release-targets-and-static-linux-build.md)、[ADR 0233](../../design/decisions/0233-distribution-via-github-releases.md)、[ADR 0234](../../design/decisions/0234-release-tests-on-development-machine.md)
- AGENTS.md の「事実と出典」（外部の事実は一次資料で確かめたものだけを断定の形で書く）
- 開発機の Apple の `container` の使い方は、プロジェクトの環境のスキル `apple-container` を読む

## 担当と、設計者が行う手順

この作業は、ネットワーク（各エージェントと Apple の文書）と、開発機の上でのコンテナの試行と、設計者の機械での試行を要する。Codex の `workspace-write` のサンドボックスはネットワークを使えないので、Codex に割り当てず、オーケストレータが設計者と行う（[ADR 0292](../../design/decisions/0292-release-checks-needing-network-by-orchestrator.md)、00-03「担当と起動の方法」）。オーケストレータは、本作業の文書に従って自ら調べ、試し、記録する。

次の二つは、設計者の機械を使う試行である。オーケストレータが手順を示し、設計者が行って結果を伝え、オーケストレータが記録する。設計者と日を合わせる。

| 試行 | 行う場所 | 設計者が行うこと |
|---|---|---|
| Gatekeeper | 設計者の macOS の機械（開発機） | 署名と公証のない実行ファイル（試しにビルドした `benitoite` をアーカイブにし、GitHub の非公開のリリースか、ほかの手段でブラウザからダウンロードできる場所に置いたもの）を、(a) ブラウザでダウンロードし、(b) `curl` でダウンロードして、それぞれ展開して端末から実行する。止められたときの表示と、`xattr -d com.apple.quarantine` などの対処で実行できるようになるかを確かめる。ダウンロードの場所を用意できなければ、ブラウザでダウンロードしたファイルと同じ隔離の属性を `xattr -w` で付けたファイルで代わりに試し、代わりの方法であることを記録する |
| WSL2 への SSH | 設計者の Windows の機械（WSL2 の Ubuntu 26.04 LTS） | WSL2 の中で SSH のサーバを動かし、開発機から SSH でログインできるようにする（WSL の networking mode の選び方、ポートの転送、Windows のファイアウォール）。Windows にログインしていない間も WSL2 が動き続けるか（ログインしないで SSH で入れるか）を確かめる。使った設定を手順として記録できる形で伝える |

## 作るもの

パスはリポジトリの根からの相対パスである。

- `doc/design/open-issues.md` の OPEN-060: 項目ごとに、確かめた日、確かめ方（一次資料の URL か試行の手順）、結果を書き加える。確かめられなかった項目は、理由と次に確かめる方法を書く。
- `doc/design/05-platform/05-01-distribution.md`: 「導入の手順」の Gatekeeper の【要検証】と、「リリースの試験」の道具と WSL2 の【要検証】を、確かめた事実（出典つき）に改める。選んだ道具は【方針】として書く。
- `doc/design/06-tooling/06-06-agent-skills.md`: 「Skill の導入」の置き場所の確かめ直しの日と、opencode が同じ名前の Skill を二か所から読むときの振る舞い（確かめたとき）を書く。
- 試行の記録 `doc/implement/studies/u4-release/open-060.md`（手順、コマンドと出力の要約、使った道具の版）。

OPEN-060 のすべての項目を確かめたら、決着の ADR の案（`doc/design/decisions/` の次の番号）を書き、設計者の確認を待つ（AGENTS.md「決定の書き方」の「決着した未決事項は、ADR を作成してから」）。Skill の置き場所はリリースのたびに確かめ直す事項なので、決着の後も 05-01「リリースの試験」の手順に残す。

## 手順の要点

1. Gatekeeper: Apple の一次資料（Gatekeeper と隔離の属性の説明）を読み、設計者の試行（上の表）の結果と合わせて、利用者向けの文書（D33 の導入の手順）に書く対処を決める。
2. 開発機の上のコンテナと仮想機械: 開発機の Apple の `container` を候補として試す（[README](../README.md) の「U3・U4 で決めたこと」の 17）。次を確かめる。
   - Linux（arm64）のコンテナで、`rust-toolchain.toml` の版の Rust を入れ、`aarch64-unknown-linux-musl` のビルドと `scripts/check.sh` が通るか。
   - x86_64 の Linux のコンテナ（Rosetta か QEMU による模倣）で、`x86_64-unknown-linux-musl` のビルドと `scripts/check.sh` が通るか。かかる時間。
   - 実行ファイルだけを入れた最小の像（glibc も musl の共有ライブラリもないもの）を作って動かせるか。
   - `container` で足りない点があれば、ほかの道具（Docker Desktop、Lima、OrbStack、UTM など）を一次資料で調べ、候補と理由を記録する。導入は設計者に確かめてから行う。
3. WSL2 への SSH: 設計者の試行の結果を手順として記録する。開発機から `ssh` で受け入れテストを動かすために要るもの（WSL2 の中の道具、送るファイル）を書く。
4. Skill の置き場所: Claude Code・Codex CLI・opencode の文書で、Skill を読み込む場所を確かめ直す（06-06 の表の出典の URL）。opencode が `.claude/skills` と `.agents/skills` の両方に同じ名前の Skill があるときにどう振る舞うかを、開発機の opencode で試す（`benitoite` の代わりに、同じ名前の小さな Skill を二か所に置く）。
5. 書く文は、確かめたことだけを断定の形で書き、確かめられなかったことは【要検証】のまま残す。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| OPEN-060 | 四つの項目のそれぞれに、確かめた日・方法・結果（または確かめられなかった理由）がある |
| 05-01 | 【要検証】を改めた箇所に出典か試行の記録への参照がある。確かめられなかった箇所は【要検証】のまま |
| D31 が使える記録 | 使う道具、x86_64 の模倣の方法、最小の像の作り方、WSL2 への接続の手順が、D31 がそのまま使える形で `studies/u4-release/open-060.md` にある |

## 完了条件

- 受け入れテストのすべての場合を満たし、完了の報告に要約を書いている
- 設計者の試行が済んでいない項目があれば、それを完了の報告の「残したこと」に書き、D31 を起動する前に済ませるよう示している

## 難易度の理由

調べることと試すことの作業で、コードを書かない。手間は、設計者と日を合わせることと、コンテナの中で処理系のテストを動かす準備にある。
