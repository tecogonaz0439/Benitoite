from pathlib import Path
import re

D = Path('docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms')
names = ['decisions.md', 'plan.md', 'implementation-request.md', 'time-policy.md']
texts = {name: (D/name).read_text() for name in names}

# 作業と問いの番号は別の系列にする。履歴の保存先は変えない。
for name, s in texts.items():
    s = s.replace('2026-10-27、P1。', '2026-10-27、作業 WP-01（依頼名 P1）の下書きを WP-01b（依頼名 P1b）で修正。')
    s = s.replace('P/F/Q/H', 'PM/IF/UB/HR').replace('P/F/Q', 'PM/IF/UB').replace('F/Q/H', 'IF/UB/HR')
    s = s.replace('P・F・Q', 'PM・IF・UB').replace('P、F、Q', 'PM、IF、UB')
    s = s.replace('F/Q', 'IF/UB')
    s = re.sub(r'\bP(10|20|30)\b', r'PM\1', s)
    s = re.sub(r'\bQ(10|20|30)\b', lambda m: 'UB'+m[1] if (name != 'decisions.md' or m[1] != '10') else m[0], s) if name != 'plan.md' else s
    # plan の README Q10 は保持し、作業として現れる Q10 だけを改名する。
    if name == 'plan.md':
        s = re.sub(r'Q(10|20|30)(?=\.|/|〜| の|/Q|後|と|へ|接続|の成果|の点検|レビュー)', r'UB\1', s)
        s = s.replace('| Q10 ', '| UB10 ').replace('| Q20 ', '| UB20 ').replace('| Q30 ', '| UB30 ')
    s = re.sub(r'\bF(10|20|30)\b', r'IF\1', s)
    s = re.sub(r'\bH10\b', 'HR10', s)
    s = re.sub(r'\bU([1-8])\b', lambda m: f'DET-{int(m[1]):02d}', s)
    # 問い P1 との衝突を避ける。README P1 はそのままにする。
    s = re.sub(r'(?<!README )\bP1\b(?!b|/|\)|〜|・P|\s*の決定)', 'WP-01', s)
    s = s.replace('依頼名 WP-01', '依頼名 P1')
    s = s.replace('純検査', '純粋な検査')
    texts[name] = s

s = texts['decisions.md']
s = s.replace('ここでの D 番号は本書の番号であり、[questions.md](study/questions.md) の D1〜D9 は「調べ D1」のように区別する。', '本書の判断は「判断 1〜21」、細則は DET-01〜09 と書く。[questions.md](study/questions.md) の情報フロー制御の問い D1〜D9 は、本書と計画では IFC-D1〜IFC-D9 と表記する。language-rules の未確認 U1〜U11 は LR-U1〜LR-U11 と表記する。元文書の番号は変更しない。')
# 情報フロー制御の問いを保護してから判断の見出しと参照を改める。
s = re.sub(r'調べ\s*D(\d+)', r'IFC-D\1', s)
cut = s.index('### 情報フロー制御の設計者への問い')
a, b = s[:cut], s[cut:]
a = re.sub(r'(?<!IFC-)\bD(\d+)\b', r'判断 \1', a)
b = re.sub(r'(?<!IFC-)\bD(\d+)\b', r'IFC-D\1', b)
b = b.replace('構文そのものは IFC-D3 を再選択しない', '構文そのものは判断 3 を再選択しない')
s = a+b
s = s.replace('〜判断 ', '〜')
s = s.replace('【決定】次の七入口を既存の種類の新しい操作として登録する。表の R、H,P は一つの閉じた範囲または Top である。型・引数とエフェクトの添字は同じ範囲を指す。', '【決定】次の七操作を既存の種類の新しい操作として登録する。操作の集合と型契約を決定とし、公開名と契約引数名は、検査・射影・拡大の名前とともに DET-03 の未決とする。表の名前は A4 にある候補名である。R、H,P は一つの閉じた範囲または Top を表し、型・引数とエフェクトの添字は同じ範囲を指す。')
s = s.replace('| 操作 | 型契約 |', '| 操作の候補名（未採択） | 型契約 |')
s = s.replace('この仕様上の帰結と不足節を記録する。', 'この仕様上の帰結と不足節を、現行仕様の反映と改造の記録に残す。CHANGELOG に書くかは DET-09 の回答に従う。')
s = s.replace('格納先と中心の定義の最終形は、この比較のレビューで決める。', '比較は取りまとめが用意した作業用のディレクトリで行い、既存の構成子を実際に変えたビルドで壊れる宣言・ファイルを数える。試行をコミットしない。格納先と中心の定義の最終形は L00.08 のレビューで決め、設計者が承認する。採った定義を最終のモジュールと名前空間に置いて固定し、L10 以降はその拡張だけを行う。L00.08 が採らなかった候補と比較専用の import を削除する。')
s = s.replace('L00 の後に L10 以降を作業単位へ具体化し、', 'L00.08 では DET-01〜09 をまとめて設計者へ尋ねる。DET-01 のうち領域に関わる答えは L00.02 より前に得て、同レビューで再掲する。L10 の起動条件は、全細則に対する設計者の回答、格納方式の承認、採用定義の配置とレビュー、および後続枝の具体化である。その後、')
s = s.replace('以下は採択済みの Q1〜Q14 を再度問う表ではない。study が「細則の案」「具体化する案」「候補」と明記した部分、または L00 の結果で決める実装方法だけを載せる。設計者の回答・取りまとめのレビュー結果は、出どころと日付を添えて追記する。', '以下は採択済みの README P1〜P6・Q1〜Q14 を再度問う表ではない。study が「細則の案」「具体化する案」「候補」と明記した部分、または L00 の結果で決める実装方法だけを載せる。DET-01〜09 は L00.08 の最後のレビューで一括して設計者へ尋ね、回答・格納方式の承認・取りまとめのレビュー結果を出どころと日付つきで記す。L00 の途中で領域の定義に必要な DET-01 だけは L00.02 の前に尋ね、回答を最後の一括表にも再掲する。他の未回答部分に依存する試行は比較用に限り、未採択の細則を本番の定義へ埋め込まない。')
s = s.replace('L00 で最終分類を設計し、L10 の該当枝を起動する前に設計者が細則と旧 API の変更を確認する', 'L00.02 の前に、旧 Scope の IP への拡張、mapped の族、最大 prefix の完全一致への正規化を含む領域と等号に関わる細則を設計者へ尋ねる。残る字句制限も L00.08 の一括回答で確定する')
s = s.replace('L00 の契約点検を経て R10 の起動前に確定する。', 'L00 の契約点検を経て L00.08 の一括回答で確定する。')
s = s.replace('検査・射影・拡大の公開名と契約引数名を A4 の候補で固定するか。', '七 IO（判断 8 の表）と検査・射影・拡大の公開名・契約引数名を A4 の候補で固定するか。七 IO には `File.readTextIn`・`readBytesIn`・`writeTextIn`・`appendTextIn`・`writeBytesIn`・`appendBytesIn` と `Http.sendIn` を推す。')
s = s.replace('L20 の署名表の枝の前に、引数名・戻り型・具体化の方法を一表に確定する', 'L00.08 の一括回答で、全候補の公開名・引数名・戻り型・具体化の方法を同じ表に確定する')
s = s.replace('L20/L40 の該当契約の前に確定し、', 'L00.08 の一括回答で確定し、')
s = s.replace('R40 の起動前に一覧と独立期待値をレビューする', 'L00.08 の一括回答で一覧と独立期待値を確定する。L50 の交換の拒否理由も同じ回答に従う')
s = s.replace('R40 前に既存読者との互換を確認し、', 'L00.08 の一括回答に既存読者との互換の点検を添え、')
s = s.replace('L00.01〜.08 の実物と影響分類を見て取りまとめがレビューし、必要な設計判断を設計者へ戻す。', 'L00.01〜.08 の実物と影響分類を取りまとめがレビューし、L00.08 の一括質問で格納方式と配置の承認を設計者へ求める。')
s = s.replace('L00.05 で候補と計上点を整理し、L40 の該当枝の前に確定する', 'L00.05 で候補と計上点を整理し、L00.08 の一括回答で確定する')
needle = '\n### 情報フロー制御の設計者への問い'
s = s.replace(needle, '\n| DET-09 | 旧 `Http.send` の節だけでは部分ハンドラとなる帰結を CHANGELOG に書くか。推す案は、操作の追加と効果が残る事実だけを短く書き、節の書き換え方・前後のコード・移行例・移行の手順は一切載せないことである | README Q2 は `0.1.0` の公開まで移行案内を一切書かない決定である。事実だけの変更記録もこの禁止に含めるかを L00.08 で尋ねる。含める回答なら CHANGELOG にはこの帰結を書かず、改造の記録と現在の仕様の説明に限る。V10 は回答を実行する |\n'+needle)
texts['decisions.md'] = s

for name in ['plan.md', 'implementation-request.md']:
    s = texts[name]
    s = re.sub(r'decisions D(\d+)〜D(\d+)', r'decisions の判断 \1〜\2', s)
    s = re.sub(r'decisions D(\d+)', r'decisions の判断 \1', s)
    s = re.sub(r'調べ\s*D(\d+)', r'IFC-D\1', s)
    s = re.sub(r'(?<!IFC-)\bD(\d+)\b', r'IFC-D\1', s)
    s = s.replace('DET-01〜DET-08', 'DET-01〜09')
    # 個別の判断参照を保護する。
    s = s.replace('判断 IFC-D', '判断 ')
    texts[name] = s

for name in names:
    (D/name).write_text(texts[name])
