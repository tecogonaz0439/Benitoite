# 0340. エージェントハーネスが使う LLM の提供者として、OpenAI 互換の API・Sign in with ChatGPT・Anthropic の Messages API・Gemini API を採る

- 状態: 採択
- 日付: 2026-10-08
- 関連章: [サーバモード](../06-tooling/06-07-server.md)
- 関連 ADR: [0194](0194-tui-and-own-coding-agent-with-server-mode.md)
- 関連する未決事項: [OPEN-056](../open-issues.md#open-056), [OPEN-095](../open-issues.md#open-095), [OPEN-096](../open-issues.md#open-096), [OPEN-097](../open-issues.md#open-097), [OPEN-101](../open-issues.md#open-101)

## 背景

処理系は、初回リリース版の後に、自前のコーディングエージェント（利用者の依頼から LLM にスクリプトを書かせ、検査と修正を繰り返す仕組み。以下、エージェントハーネス）を持つ（[ADR 0194](0194-tui-and-own-coding-agent-with-server-mode.md)）。どの LLM をどの方法で呼ぶかは、[OPEN-056](../open-issues.md#open-056) の「対応する LLM の提供元」として残っていた。外部のハーネス（Claude Code、Codex CLI など）から処理系を使う場合は、使うモデルをハーネスの側で設定するので、この問いの対象ではない。

設計者は、2026-10-04 に提供者の候補を A〜L の 12 に分けて検討し、それぞれの採否を決めた（[LLM の提供者の検討メモ](../sources/post-first-release/post-first-release-llm-providers.md)の「設計者の決定」）。本 ADR は、そのうちエージェントハーネスが使う提供者の採否を記録する。Claude の扱い（決定 5）は、2026-10-08 に設計者が改めて決めた。MCP のサンプリング（候補 I）は [OPEN-098](../open-issues.md#open-098) で、既存のエージェントの CLI を包むライブラリ（候補 J）は [ADR 0341](0341-agent-cli-wrapper-library.md) で扱う。

メモが一次資料で確かめた事実（2026-10-04）のうち、判断に関わるものは次のとおりである。

- Sign in with ChatGPT は、利用者が自分の ChatGPT のアカウントでサインインし、OAuth で得たアクセストークンで公開の Responses API を呼ぶ仕組みである。オープンソースのプロジェクトと、手元で動かす個人のプロジェクトは申し込みなしで使える（[OpenAI Cookbook の記事](https://developers.openai.com/cookbook/articles/sign-in-with-chatgpt)）。
- Gemini API には、開発者の API キーに付く無料枠があり、多くのモデルで使える。無料枠では、送った内容が Google の製品の改善に使われる（[Gemini Developer API の料金](https://ai.google.dev/gemini-api/docs/pricing)）。Gemini API の OpenAI 互換の口はベータ版であり、Responses API への対応は挙げられておらず、対応していない引数は誤りにならずに無視される（[Gemini API の OpenAI の互換性](https://ai.google.dev/gemini-api/docs/openai?hl=ja)）。
- Apple の Foundation Models の端末の中のモデルは、文脈の長さが 8,192 トークンである（[What's new in the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2026/241/)）。

## 決定

1. エージェントハーネスは、次の四つの提供者を採る。
   - A. OpenAI 互換の API。Chat Completions と Responses の両方を実装し、設定でどちらを使うかを選ぶ。ベースの URL と API キーを設定で与え、OpenAI のほか、OpenAI 互換の口を持つサービスを同じ実装で呼ぶ。
   - B. Sign in with ChatGPT。呼ぶ先は Responses API なので、A の Responses の実装を使い回し、B に固有の部分は認証（OAuth とトークンの更新）だけとする。
   - D. Anthropic の Messages API。OpenAI 互換の口を通さず、Messages API を直接実装する。
   - E. Google の Gemini API。Gemini API の固有の形で呼ぶ専用の実装を作る。専用の実装を作った後も、利用者が A の設定で Gemini API の OpenAI 互換の口を呼ぶことは妨げない。
2. 手元の推論サーバ（Ollama など。候補 F）と中継のサービス（OpenRouter など。候補 G）は、A の実装で扱い、設定の例として文書に載せる。専用の実装は作らない。
3. 自己ホスト（重みを手元に置き、Rust のライブラリから処理系の中で推論する。候補 C）とクラウドの基盤（Amazon Bedrock、Vertex AI、Azure OpenAI。候補 H）は、検討の対象に残すが、実装の優先度を低くする。
4. Apple の Foundation Models（候補 K）は、今回は採らない。見直す契機は、端末の中のモデルの文脈が長くなったとき、Apple のサーバで動くモデル（Private Cloud Compute）を App Store の外で配る CLI から使えると分かったとき、スクリプトから LLM を呼ぶモジュール（[OPEN-100](../open-issues.md#open-100)）の手元の提供者として短い作業に使う場面が出てきたときとする。
5. エージェントハーネスが Claude を API で呼ぶときは、Claude Platform API（Anthropic の Messages API。D）を API のキーで使う。Claude の購読（Pro、Max）のアカウントで処理系が自らサインインする形（B に当たるもの）は、設計者の判断として候補にしない（2026-10-08）。この判断は、Anthropic が第三者の道具に購読のサインインを許すかという事実に依らない。Agent SDK のページが承認なしに第三者の開発者が claude.ai のログインを提供することを認めないことは確かめてあり（[OPEN-097](../open-issues.md#open-097)）、承認を得る条件などの残る点は [OPEN-096](../open-issues.md#open-096) の【要検証】の項目に残すが、確かめた結果によって本決定は変わらない。
   - D の動作の確認には、設計者のアカウントの API クレジット（Max と Team のプランで毎月付与されるもの）を使う。出典は設計者が示した [Monthly API credits for Max and Team plans](https://support.claude.com/en/articles/17154008-monthly-api-credits-for-max-and-team-plans) であり、付与の条件などの中身は本 ADR では確かめていない。
   - 公式の Claude Code の CLI を経由して Claude の購読を使う候補 L は、処理系が自らサインインする形でも API を直接呼ぶ形でもないので、本決定の対象外とする。L の採否は [OPEN-097](../open-issues.md#open-097) で決める。

本 ADR は、次の点を決めない。

- 提供者を差し替える層の作り方、実装の順、使うクレート、C と H を作る条件（[OPEN-095](../open-issues.md#open-095)）。
- 各社の規約、OpenAI 互換の範囲、地域の制限などの事実の確認（[OPEN-096](../open-issues.md#open-096)）。
- API キーと OAuth のリフレッシュトークンの保管と、利用者への表示（[OPEN-101](../open-issues.md#open-101)）。
- エージェントハーネスを作る時期（[ADR 0194](0194-tui-and-own-coding-agent-with-server-mode.md)）。

## 検討した代替案

- **E を A で代用する（Gemini API の OpenAI 互換の口を A の Chat Completions で呼ぶ）**: 実装が一つ減る。設計者は初めこの方針をとったが、互換の口はベータ版で、対応していない引数を黙って無視する。メモは B を ChatGPT の Plus と Pro のプランに限られるものとしており、費用をかけずにエージェントハーネスを使う手段として Gemini API の無料枠の価値が高く、固有の機能を確実に使える専用の実装を作ることにした（2026-10-04）。
- **D を Anthropic の OpenAI 互換の口で代用する**: 実装が一つ減る。しかし、互換の口は機能の一部に限られる見込みであり（【要検証】。[OPEN-096](../open-issues.md#open-096)）、エージェントハーネスは道具の呼び出しとプロンプトのキャッシュを使うので、Messages API を直接実装する。
- **Claude の購読で処理系が自らサインインする形を、規約の確認の後に候補にする**: 利用者は API キーなしに購読で Claude を使える。しかし、設計者は規約が許すかによらずこの形を採らないと判断した（2026-10-08）。メモ（2026-10-04）は、Agent SDK のページが承認なしの提供を認めないことを理由に挙げていたが、決定 5 はその規約にも、承認を得る条件にも頼らない。
- **K を採る**: 料金がかからず、ネットワークなしで動く。しかし、文脈の 8,192 トークンでは、同梱の Skill の文法の参照、スクリプト、診断を渡すと足りなくなるおそれが大きい。
- **C を早く作る**: ネットワークも API キーも要らない。しかし、手元のモデルは A（手元の推論サーバ）でも使え、C は処理系の実行ファイルを大きくし、ビルドを GPU の環境に依存させる。サーバの導入なしで動くことの価値が確かめられるまで後に回す。

## 帰結

- エージェントハーネスを定める章を設けるときに、本 ADR の決定を【決定】として書く。初回リリース版の処理系には影響しない。
- [OPEN-056](../open-issues.md#open-056) の「対応する LLM の提供元」は、本 ADR で提供者の採否を決め、残りを [OPEN-095](../open-issues.md#open-095)〜[OPEN-097](../open-issues.md#open-097) と [OPEN-101](../open-issues.md#open-101) に分けた。
- LLM の API のクライアントは、言語の中核でも処理系の主要部でもないので、既存の OSS（Rust のクレート）を使ってよい（ADR 0194 の決定 4）。
