# coding: utf-8
from pathlib import Path
import re

D = Path('docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms')
for name in ['decisions.md','plan.md','implementation-request.md','time-policy.md']:
    p = D/name
    s = p.read_text()
    for old,new in [('P10','PM10'),('P20','PM20'),('P30','PM30'),('F10','IF10'),('F20','IF20'),('F30','IF30'),('H10','HR10')]:
        s = re.sub(r'(?<![A-Za-z0-9_-])'+old+r'(?![0-9])',new,s)
    if name != 'decisions.md':
        for old,new in [('Q10','UB10'),('Q20','UB20'),('Q30','UB30')]:
            s = re.sub(r'(?<![A-Za-z0-9_-])'+old+r'(?![0-9])',new,s)
    # 判断の見出しのほかに残る D は調べの問いを指す。
    s = re.sub(r'(?<![A-Za-z0-9_-])D([1-9])(?![0-9])',r'IFC-D\1',s)
    s = re.sub(r'(?<![A-Za-z0-9_-])U([1-8])(?![0-9])',lambda m:f'DET-{int(m[1]):02d}',s)
    s = s.replace('DET-01〜DET-08','DET-01〜09')
    # 「P1」は README の問いと依頼名/歴史的パスだけに残す。
    s = re.sub(r'(?<![A-Za-z0-9_/-])P1(?=の|は|で|時点)', 'WP-01', s)
    s = s.replace('IFC-D1〜D9','IFC-D1〜IFC-D9')
    s = s.replace('情報フロー制御のIFC-', '情報フロー制御の IFC-').replace('のIFC-', 'の IFC-').replace('とIFC-', 'と IFC-')
    s = s.replace('全比較で', '全比較で').replace('kernelへ', 'Lean のカーネルへ')
    p.write_text(s)

p = D/'decisions.md'; s=p.read_text()
s = s.replace('情報フロー制御の問い 判断 1〜9', '情報フロー制御の問い（元文書の D1〜D9）')
s = s.replace('language-rules の未確認 DET-01〜U11 は', 'language-rules の未確認の事実（元文書の U1〜U11）は')
s = s.replace('\n\n| DET-09 |', '\n| DET-09 |')
s = s.replace('0.0.13 の範囲の構文そのものは判断 3', '0.0.13 の範囲の構文そのものは判断 3')
s = s.replace('`io_op` の内容の変更と `io_target` の追加を前提の変更として列挙し、', '純粋な検査と七 IO を既存欄の対象となる表へ加えることは、新しい信頼条件の欄の追加に数えない。既存欄の意味を変える場合と、計画済みの `io_target` 以外の欄を加える場合は停止条件に当たる。`io_op` の内容の変更と `io_target` の追加を前提の変更として列挙し、')
glossary = '''## 表記と略語

用語は [00-04「用語集」](../design/00-overview/00-04-glossary.md) と README の決定にそろえる。四文書で使う作業 ID は、文書作成が WP、権限の独立モデルが PM、情報フロー制御の文書が IF、利用者エフェクトの境界点検が UB、任意の hefty のレビューが HR である。L/R/K/V は既存計画の段名を保つ。いずれも作業を識別する記号であり、新しい言語の用語ではない。README の問いは「README P1」「README Q10」のように出どころを添える。

| 表記 | 本文での意味 |
|---|---|
| LLM、IO、API、CLI | それぞれ大規模言語モデル（large language model）、入出力（input/output）、プログラム間の呼び出しの接点（application programming interface）、コマンドラインの操作の接点（command-line interface） |
| HTTP、URL、IP、CIDR、DNS | それぞれ Hypertext Transfer Protocol、Uniform Resource Locator、Internet Protocol、Classless Inter-Domain Routing、Domain Name System。CIDR はここでは IP の prefix 長で表すアドレス範囲である |
| OS、VM、WASM、IPC | それぞれオペレーティングシステム、仮想機械（virtual machine）、WebAssembly、プロセス間通信（inter-process communication） |
| JSON、EBNF、RFC | それぞれ JavaScript Object Notation、拡張バッカス・ナウア記法（Extended Backus–Naur Form）、Request for Comments |
| LSP、MCP | それぞれ Language Server Protocol、Model Context Protocol。権限の独立モデルには含めない外部の接点を指す |
| WF、norm、shift/subst | WF は整形式性（well-formedness）。norm は原子の構造の整列・重複除去、shift/subst は束縛の位置の移動と代入を表す既存の識別子である |
| Top、pc | Top は同じ種類の全対象を覆う上限。pc は情報フロー制御のプログラムカウンタ（program counter）の印であり、条件分岐などの制御依存を表す |
| 能動時間 | 設計・証明・実装・検査の準備・文書修正に担当が作業する時間。ビルド・長い検査・測定・回答を待つ時間は別に記す |
| 全比較 | scripts/check-formal.sh が行う Rust と Lean の既存六入口・intervalDiff・独立交換等の比較全体。実際の集合は plan の検査表を正とする |

'''
s=s.replace('## 採る判断\n',glossary+'## 採る判断\n')
p.write_text(s)

p=D/'plan.md';s=p.read_text()
s=s.replace('## 前提と依存\n', '表記と作業 ID は [decisions「表記と略語」](decisions.md#表記と略語)に従う。判断は「判断 1〜21」、細則は DET-01〜09、情報フロー制御の問いは IFC-D1〜IFC-D9、language-rules の未確認の事実は LR-U1〜LR-U11 とする。全比較は scripts/check-formal.sh の比較全体を指す。実施した証拠と将来の計画を区別する。\n\n## 前提と依存\n')
s=s.replace('WP-01時点では未記入である。L00のレビュー後、', 'WP-01b の修正を下表に記す。L00 のレビュー後、')
s=s.replace('DET-01〜09の回答と未回答を記し、', 'DET-01〜09 の設計者の回答と格納方式の承認、採用定義の最終配置・候補削除の結果を記し、')
s=s.replace('## 設計書への反映\n', '## 設計書への反映\n')
s=s.replace('現行設計書には実装した内容だけを書く。', '現行設計書には実装した内容だけを書く。L00 の未採択候補の写しは reviews の資料に限り、採用して配置・ビルド済みの定義だけを実際の証明・接続状況とともに反映する。')
s=s.replace('V10の最後の一作業で版・訳・CHANGELOG・最終照合をそろえる', 'V10 の最後の一作業で版・訳・CHANGELOG・最終照合をそろえる。旧ハンドラの帰結の CHANGELOG 記載は DET-09 の回答に従う')
s=s.replace('最大RSSの原値', '最大常駐量（RSS、resident set size）の原値')
s=s.replace('lib全件やlintの段での反復', 'lib 全件や lint の段での反復')
s=s.replace('必須のPM/IF/UB', '必須の PM/IF/UB')
s=s.replace('。Fの各判断', '。IF の各判断').replace('K10、Fの各判断', 'K10、IF の各判断')
p.write_text(s)

p=D/'implementation-request.md';s=p.read_text()
s=s.replace('本書は後の一作業ごとの起動に使う依頼文である。', '表記と略語は [decisions「表記と略語」](decisions.md#表記と略語)に従う。WP は文書作成、PM は権限の独立モデル、IF は情報フロー制御の文書、UB は利用者エフェクトの境界点検、HR は任意の hefty のレビューを識別する作業記号である。\n\n本書は後の一作業ごとの起動に使う依頼文である。')
s=s.replace('decisions DET-01〜09のうち必要な回答、IFC-D2〜IFC-D9の回答の有無。', 'decisions の DET-01〜09 と格納方式の承認、IFC-D2〜IFC-D9 の回答の有無。L10 は全細則の設計者の回答と格納方式の承認、採用定義の配置・レビュー、後続枝の具体化が済んでから起動する。')
s=s.replace('読める公開のjapanese-tech-writingに従う。', 'private 外の公開の japanese-tech-writing が読めれば従う。読めなければ AGENTS.md「文章の規範」に従う。')
s=s.replace('見込みは能動時間であり、', '見込みは能動時間（設計・証明・実装・文書修正などに担当が作業する時間）であり、')
s=s.replace('それ以外の信頼条件の追加は認めない。', '既存の delta_typed・io_typed・io_exists の欄を満たす純粋な検査・七 IO の表の項目の追加は、新しい欄の追加に数えない。既存欄の意味を変える場合は停止条件へ返す。io_target は README の問い P1 で計画済みの欄であり、それ以外の新しい信頼条件の欄の追加は認めない。')
s=s.replace('L00は格納方式、', 'L00 の比較は取りまとめが用意した作業用のディレクトリで、既存の構成子を実際に変えて行う。試行をコミットせず、破損宣言とファイルの数・未検査を記録する。L00.08 で採用定義を最終のモジュールと名前空間へ固定し、不採用候補と比較専用の import を削除する。L10 以降は同じ定義の拡張だけを行う。L00 は格納方式、')
s=s.replace('L00のレビュー後、取りまとめがL10以降を作業単位へ具体化する。', 'DET-01 の領域に関わる答えは L00.02 の前に得る。L00.08 最後のレビューで全細則 DET-01〜09 を設計者へ一括して尋ね、格納方式の承認も得る。七 IO と検査・射影・拡大の公開名はいずれも DET-03 の未決、CHANGELOG と移行案内禁止の関係は DET-09 の未決であり、候補を採択済みとして実装しない。取りまとめはこの回答・承認と採用定義の最終配置を受けて、L10 以降を作業単位へ具体化する。')
s=s.replace('Rustとの全比較は', 'Rust との全比較（scripts/check-formal.sh が行う比較全体）は')
s=s.replace('R10/R20のような共有型の変更は全ての入力読者を対象にする。', 'R10/R20 の共有型と R30 の標準ライブラリの変更は全ての入力読者を対象にし、既定では全統合ターゲットを選ぶ。L の work も原則を自動分類とし、01-12/07-04 の例・集計の選択を dry-run で照合する。')
needle='## 結果の書き方と完了報告'
s=s.replace(needle, 'PM の独立 Lean モデルは単一ファイルの終了0だけを成功とせず、plan の出力検索で sorry を拒否し、全 theorem/lemma と使用定義の #print axioms から sorryAx と未承認の公理を拒否する。R10/R30 は機能を外す境界・32ビット・代数の依存方向をレビューする。現行の入口にない構成の実ビルドを確認済みとしない。LR-U5 の URL 解析器は R30/K10、LR-U7 の外部ハンドラの件数と未確認は R30/V10 が引き継ぐ。具体的な観点と制約は plan の検査表を正とする。\n\n'+needle)
s=s.replace('OSのtimeが示す最大RSS', 'OS の time が示す最大常駐量（RSS、resident set size）')
s=s.replace('MiB/GiBの換算', 'MiB（2^20 バイト）/GiB（2^30 バイト）の換算')
p.write_text(s)

p=D/'time-policy.md';s=p.read_text()
s=s.replace('## 依頼文の文言', '作業 ID と略語は [decisions「表記と略語」](decisions.md#表記と略語)に従う。能動時間は設計・証明・実装・文書修正などに担当が作業する時間であり、検査や回答を待つ時間とは区別する。\n\n## 依頼文の文言')
s=s.replace('各枝の初回の着手は30〜60分を目安とする。', '各枝の初回の着手は30〜60分を目安とする。この時間は最初の状況確認の目安であり、枝全体の見込みとは区別する。')
s=s.replace('L10以降はL00のレビュー後に枝分けする。', 'L10 以降は、L00.08 の全細則への設計者の回答・格納方式の承認・採用定義の最終配置とレビューの後に枝分けする。')
idx=s.index('## 取り込み時に追記する記録')
s=s[:idx]+'''## RV-P1 による見込みの修正

WP-01b は実装や Lean の比較用ビルドを実行していない。以下は RV-P1 で不足を指摘された手順を加えた計画上の見込みであり、実績の表には入れない。work の自動分類によって選ばれる検査、比較用ビルド、独立レビューと設計者の回答待ちは、作業時間と別に記録する。

| 対象 | 修正前 | 修正後と計上先 |
|---|---:|---|
| L00.01 | 0.5〜1時間 | 1〜2時間。構成子を実際に変える試行と破損宣言・ファイルの集計を含む |
| L00.06 | 0.5〜1時間 | 2〜3時間。互換補題と利用側の試行0.5〜1時間、306定理/75ファイルと追加破損宣言の分類1.5〜2時間 |
| L00.08 | 0.5〜1時間 | 1.5〜3時間。一括質問とレビュー資料0.5〜1時間、採用定義の最終配置・候補削除と対応修正1〜2時間 |
| 残る L00 の5枝 | 2.5〜5時間 | 変更なし。各0.5〜1時間 |
| L00 合計 | 4〜8時間 | 7〜13時間。差3〜5時間を Lean の合計へ加える |
| UB10 の先行点検 | UB 予算の1〜3時間 | 変更なし。L00.03/.05 後かつ L00.07 前へ配置する。L00 の7〜13時間へ重ねない。全て直列なら L00 完了まで8〜16時間、待ち時間は不明 |
| Lean 全段／必須全体 | 55〜131／133〜316時間 | 58〜136／136〜321時間。任意 HR の1〜2時間を含める場合137〜323時間 |

L00.01 の最初の30〜60分で比較用ビルドの時間と診断の分布を調べ、その結果から残りを取り直す。L00.06 で格納方式の判断を変えうる未分類が残った場合は、L00.08 より前の追加枝と見込みを提案する。未分類を全件確認済みとして扱わない。見込み上端の2倍を超えた場合の報告と区切りは上の文言に従う。

''' + s[idx:]
s=s.replace('WP-01は表の欄を用意するだけであり、', 'WP-01 と WP-01b は表の欄と計画の見込みを用意するだけであり、')
p.write_text(s)
