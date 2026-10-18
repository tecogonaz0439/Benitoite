"""F3 の実ソースの局所交換を固定件数と対応する NoFail の負例で検査する。"""
import argparse
import copy
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[4]
SHARED = runpy.run_path(str(ROOT / 'formal/tests/test_named_exchange.py'))


def check(directory):
    manifest = json.loads(Path(__file__).with_name('exchange-manifest.json').read_text())['batch2Failure']
    data = {f: json.loads((directory / f'{f}.json').read_text()) for f in SHARED['FILES']}
    actual = {i['name']: len(i['definitions']) for i in data['corpus']['inputs']}
    assert actual == manifest['definitions'], actual
    # 独立入力の Fail / handleFail / NoFail に対応する実ソースが欠落していないことを守る。
    generic = data['corpus']['inputs'][0]['definitions'][0]['scope']['inScope']['surface']
    assert generic['header']['eff'] == [{'kind': 'fail', 'error': {'tvar': {'index': 1}}}]
    failure = [{'kind': 'fail', 'error': {'base': {'name': 'String'}}}]
    assert data['coverage']['cases'][0]['ty']['eff'] == failure
    assert data['coverage-program']['inputs'][0]['matches'][0]['scrutineeTy']['fn']['eff'] == failure
    selected = next(i for i in data['corpus']['inputs'] if i['name'] == 'failure-nofail')
    header = selected['definitions'][0]['scope']['inScope']['surface']['header']
    assert header['effParams'] == [{'noFail': True}]
    assert len(header['params'][0]['fn']['eff']) == 2
    # Rust の E0515 入力と同じく、明示した Fail だけを署名から除く。
    source = (directory / 'failure-nofail.bnt').read_text()
    assert (directory / 'failure-nofail-rejected.bnt').read_text() == source.replace(
        'uses Failure.Fail[String], Rest', 'uses Rest')
    negative = copy.deepcopy(data)
    selected = next(i for i in negative['corpus']['inputs'] if i['name'] == 'failure-nofail')
    scopes = selected['definitions'][0]['scope']['inScope']
    for scope in ('surface', 'core'):
        header = scopes[scope]['header']
        header['params'][0]['fn']['eff'] = [{'rho': {'index': 0}}]
        header['effParams'] = [{'noFail': False}]
    case = SHARED['ExchangeTests']()
    case.setUp()
    try:
        process, report = case.run_tool('surfaceCheck', negative, None, 'failure-nofail')
        assert process.returncode == 1, (process.returncode, process.stderr, report)
        assert report['result']['ok'] is False, report
        reason = report['result']['error']['reason']
        assert reason == manifest['restViolation'], report
        # 宣言が署名から得る Q と一致しなければ、読者も拒否する。
        malformed = copy.deepcopy(data)
        selected = next(i for i in malformed['corpus']['inputs'] if i['name'] == 'failure-nofail')
        selected['definitions'][0]['scope']['inScope']['surface']['header']['effParams'][0]['noFail'] = False
        process, _ = case.run_tool('surfaceCheck', malformed, None, 'failure-nofail')
        assert process.returncode == 2, (process.returncode, process.stderr)
        assert 'NoFail signature mismatch' in process.stderr, process.stderr
    finally:
        case.doCleanups()
    return {'definitions': actual, 'totalDefinitions': sum(actual.values()),
            'restViolation': reason, 'signatureMismatchExit': 2}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rust-dir', type=Path, required=True)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    result = check(args.rust_dir)
    if args.report:
        args.report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
