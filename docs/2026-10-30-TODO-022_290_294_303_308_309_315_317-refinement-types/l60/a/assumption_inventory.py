"""Rustの登録形と専用操作を読み、仮定側154行の区分・Builtins欄を付けて照合する。"""
import argparse
from collections import Counter
import json
import re
from inventory import HERE, ROOT, FORMAL, digest, write
from ledger import pages
from rust_inventory import expand, group


SCOPE_FILE = 'docs/design/07-quality/07-04-formal-semantics.md'
TASK_SCOPE = {'file': SCOPE_FILE, 'heading': '証明する性質',
              'statement': '- 並行処理のタスクと、タスクが引き継いだハンドラ（[並行処理](../01-spec/01-11-concurrency.md)。01-12 も状態の型付けに含めない）。'}


def modes(file):
    source = expand(file.read_text())
    result = {}
    for match in re.finditer(r'\bbuiltin!\s*\{', source):
        body, _ = group(source, match.end() - 1)
        name = json.loads(re.search(r'\bname\s*=\s*("(?:\\.|[^"\\])*")', body)[1])
        mode = re.search(r'\b(pure|io|state)\s+fn\b', body)[1]
        assert name not in result
        result[name] = mode
    return result


def metadata(row, rust, mode):
    name = row['lean_name']
    fields = ['sig']
    if name == 'Reference.new':
        category = '専用の遷移'
        detail = 'kind=refNew、CoreAssumptions.store_shapeとStep.E_RefNewでセルを作る。δ・IO応答で代用しない'
    elif name == 'Reference.update':
        category = '専用の遷移'
        fields += ['refGet', 'refSet']
        detail = 'kind=refUpdate、store_shape/ref_get/ref_setとStep.E_RefUpdateを読む。RustもUPDATE専用命令で処理する'
    elif name == 'Lazy.force':
        category = '専用の遷移'
        detail = 'kind=force、store_shapeとStep.E_ForceDone/E_Forceを読む。Rustのpure登録はFORCE命令用の印でありδの実算法ではない'
    elif name == 'Process.exit':
        category = '専用の遷移'
        fields += ['ioResponse', 'effects', 'effKind']
        detail = 'kind=exit、ioResponseのexit結果とStep.E_Exit/終了時の解放遷移を読む'
    elif name.startswith(('Task.', 'TaskGroup.')):
        category = '形式化の外'
        if name.startswith('TaskGroup.'):
            fields += ['isResource', 'releaseResponse']
        detail = 'Rustのstate登録による起動・待機。現在のPrimKind/StepにTask専用欄・遷移はなく、sigは対応を調べる入口だけである。並行実行の状態は形式化外'
        if name.startswith('TaskGroup.'):
            detail += '。TaskGroupの通常解放の境界はisResource/releaseResponse（五実資源の別表）であり、起動・待機を証明するものではない'
    elif (name in {'File.openReader', 'File.readLine', 'File.closeReader'} or
          rust['part'] == 'file::RESOURCE_DECLS' or rust['part'] == 'http_server::DECLS'):
        category = '通常資源の状態'
        fields += ['isResource', 'releaseResponse']
        if mode == 'io':
            fields += ['ioResponse', 'effects', 'effKind']
        detail = '通常資源の作成・参照・解放の実状態。isResource/releaseResponseは分類と抽象解放の境界であり、実資源の状態の対応証拠はない'
        if mode == 'io':
            detail += '。この登録のIO結果はioResponseの照合対象である'
        else:
            detail += '。state登録の資源操作そのものに対応する専用Builtins欄はなく、IO応答とは数えない'
    elif mode == 'io':
        category = 'IO 応答'
        fields += ['ioResponse', 'effects', 'effKind']
        detail = 'Rustのio登録の結果と観測対象をioResponse、操作の所属と対象の種類をeffects/effKindで照合する'
    elif mode == 'pure':
        category = 'δ'
        fields += ['delta']
        detail = 'Rustのpure登録の実算法をdeltaの応答条件へ照合する'
    else:
        category = '形式化の外'
        detail = 'Rustのstate登録。現行のPrimKind/Stepにはこの操作の専用欄・遷移がなく、sigは対応を調べる入口だけである。δ・IO応答の充足を主張しない'
    result = {'assumption_kind': category, 'builtins_fields': fields,
            'rust_mode': mode, 'assumption_detail': detail,
            'reason': f"{rust['name']} は「{category}」に分類する。{detail}。E01〜E15に同名の実算法・状態の対応証拠はない。新しい意味や定数errで補わず、R50が実登録との対応と形式化の内外を確認する"}
    if category == '形式化の外':
        # 未知のstate登録を仮定へ混ぜず、07-04の根拠を特定するまで拒む。
        assert name.startswith(('Task.', 'TaskGroup.')), (name, '07-04の対象外の根拠が未特定')
        result['scope_basis'] = TASK_SCOPE
        result['status'] = '形式化の外。対応する専用欄・遷移なし。R50で内外を確認する'
        result['reason'] = (f"{rust['name']} は「形式化の外」に分類する。{detail}。"
                            '07-04「証明する性質」は並行処理のタスクと引継ぎハンドラを対象外とする。'
                            'この起動・待機の操作を仮定として量化する範囲に含めず、R50が実登録と形式化の内外を確認する')
    return result


def run(apply=False):
    summary = json.loads((HERE / 'ledger-summary.json').read_text())
    def read(key):
        result = []
        for page in summary[key]:
            assert digest(HERE / page['file']) == {k: page[k] for k in ['bytes', 'sha256']}
            result += json.loads((HERE / page['file']).read_text())
        return result
    rows = read('ledger_pages')
    rust = {r['id']: r for r in read('rust_pages')}
    cache = {}
    counts = Counter()
    valid = set(re.findall(r'^  (\w+) :', (FORMAL / 'Syntax.lean').read_text().split('structure Builtins where')[1].split('/-- 宣言は')[0], re.M))
    for row in rows:
        if row['classification'] != '仮定':
            continue
        assert len(row['rust_references']) == 1
        source = rust[row['rust_references'][0]]
        file = ROOT / source['source']
        if file not in cache:
            cache[file] = modes(file)
        expected = metadata(row, source, cache[file][source['name']])
        assert expected['builtins_fields'] and set(expected['builtins_fields']) <= valid
        if expected['assumption_kind'] == '形式化の外':
            basis = expected['scope_basis']
            scope = (ROOT / basis['file']).read_text()
            section = scope.split('### ' + basis['heading'] + '\n', 1)[1].split('\n### ', 1)[0]
            assert basis['statement'] in section, (row['id'], '07-04の対象外の根拠なし')
        if apply:
            row.update(expected)
        else:
            assert all(row.get(k) == value for k, value in expected.items()), row['id']
        counts[row['assumption_kind']] += 1
    assert sum(counts.values()) == 154
    if apply:
        summary['ledger_pages'] = pages('ledger', rows)
        write(HERE / 'ledger-summary.json', summary)
    return dict(counts)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    print(json.dumps(run(parser.parse_args().apply), ensure_ascii=False))
