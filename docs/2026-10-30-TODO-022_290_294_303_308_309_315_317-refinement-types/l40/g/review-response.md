# RV-L40.g への応答（L40.39）

2026-11-04。再開3として、中2件・軽4件・情報4件へ応答する。実装担当の自己点検と、取りまとめによる独立の再確認・設計者の受け入れを分ける。

## request

設計者の再開3の依頼は、[段末の独立レビュー](../../reviews/RV-L40.g.md)の所見へ必要な箇所だけで応答し、古くなった検査を更新するものである。中1は (a) を先に試し、最初の20分で見積もり、2時間超の見込み又は燃料に新たな前提が要る場合は (b) へ切り替える。plan.md は取りまとめの注記を保持する。

## report

レビューの総合判定は条件付き可（重0・中2・軽4・情報4）である。中1は型付き Equality でも InternalComparison が起きないことが結論にない点、中2は算術 δ の方針が設計者の見直し表にない点である。レビューの原本と他群の記録は変更していない。

## response

| 所見 | 処置と根拠 | 残る作業 |
|---|---|---|
| 中1 | (a) の[部分試行](resume3-equality-trial.lean)で深さの二補題・整数・列の帰納を確認した。型付き全構造の観測、Map の縮約・整列後の部分木と燃料の合成には2時間30分〜4時間と見積もったため、最初の20分以内に (b) を選択。stage-results の構造等号の行・段落と01-12・07-04に、Boolean は正常枝だけであり、型付き入力で失敗枝が起きないことは結論しない旨を明記した | R50 の表に StandardStructuralEqualityResponse と「型の付いた Equality の値で structuralEqual が none にならないこと」を追加。処理系の Stop::Internal、snapshotDepth の燃料、共有走査・深さの境界を含めて照合する |
| 中2 | stage-results の見直しの表と初回の確認点の一覧に「算術 δ の追加（plan 2026-11-04、群 G 再開2）」を追加。34行の δ、Decimal・String の写し、Float の模型による NaN の payload と符号の正準化、Rust との差を明記。扱いは「取りまとめが採択、設計者の見直しの対象」 | 設計者の見直し。型付けの規則・公開署名の変更なし |
| 軽1 | [obligations.md](obligations.md)の O135 は decoder の接続だけ、O062/O065 は演算子と構造等号の response、O022/O034/O144 は .28 の標準の具体 δ と .25 の decoder の同じ Result・欄順・全体条件へ理由を付けて割り付けた。三条件・全sort・標準葉の供給という各行の役割に対応する。単独の表の table_response を L60 用の証拠から外した | 任意の P/B の StandardOperatorResponse.response と StandardStructuralEqualityResponse.response を L60 へ渡す。全表の合成は L60 |
| 軽2 | stage-results の R50・R40・L60 の行に再開2の申し送りを追加。Float/Rust、Decimal/Wide、String、構造等号、生成 decoder と同じ後処理・順番、Def 登録時の同値、単独の sig の表と328 API の合成を記載 | 受け手ごとの表の記載を正とする |
| 軽3 | stage-results の二つの全名を StandardDecode.decodeThen_normal/decodeThen_firstReturn（StandardDecodeConnection）と StandardDecode.postprocess_all（StandardDecodeBodies）へ訂正 | なし |
| 軽4 | 作業中の予告を確定値の節の参照へ変更。旧反例が再開2で対照に置き換わったことと旧入力の識別の節を明記。現行を[resume2-contrast.lean](resume2-contrast.lean)へ改名し、verify 台本・JSON・本文の参照を更新。再開1の JSON は旧内容の bytes/SHA-256・実行記録を保持し、改名前の実コマンドを historical_command として残した。plan.md は指定どおり変更なし | 現行の対照は resume3-contrast-check.json、旧反例は results.md「旧反例の置き換え前の識別」で区別する |
| 情報1 | R50 の行に NaN の payload と符号の具体例を追加。Float64 の入力0x7ff8000000000001は Rust で加算後も同じ payload、負号で0xfff8000000000001、Lean は双方0x7ff8000000000000。Float32 の入力0x7fc00001の負号は Rust 0xffc00001、Lean 0x7fc00000。正準 NaN の負号の差も記載 | レビューで確認した arm64 の例として渡す。R50 の全照合を今回済ませたとはしない |
| 情報2 | R50 の行に Decimal の到達しない分岐の読み替えを追加。roundMagnitude の none で Rust は候補を更新せず継続、Lean は全体を overflow にするが q≤limit・r<d の下では到達しない。negate の make の失敗排除も未証明と記載 | Wide の照合時に読み替えを確認する |
| 情報3 | L70 に decoded の型付けを通常 decoder の型付けと保存の定理から供給することを追加。R40 に二整数・一条件の代表から任意の欄数・型・複数条件の record への一般化を生成器が担うことを追加 | Def 呼出しを採るなら decodeThen の let の合成との対応も R40 で確認する |
| 情報4 | 処置不要。64義務（技術50・継承6・運用3・他段1・共通4）と33申し送り（今回25・継承3・他段5）の分類を保持。義務全体の閉鎖は0のまま | 共通4行の独立の再確認・正式 RSS・設計者の受け入れは取りまとめが管理する |

## handling

今回の応答で所見への実装担当の処置を終える。検査の結果と開始・終了の時刻は[results.md「再開3（L40.39）」](results.md#再開3l4039)、最新の照合は resume3-verification.json を正とする。段末の公理監査の宣言一覧は最新の一回分だけを保存する。

本番の Lean の定義・言明・仮定・既定 import の変更は0である。部分試行の資料を型付き Equality 全体の正常性の証拠として扱わない。構造等号の応答契約と、失敗枝の排除の未証明を分けたまま R50 へ渡す。取りまとめが独立に再確認し、正式 RSS・設計者の見直し・受け入れを判断する。この応答だけで段全体を受け入れ済みとはしない。
