#!/usr/bin/env python3
"""main の呼び忘れと順序の変更を target 内の写しで検出し、写しを消す。"""
import json
from pathlib import Path
import runpy
import tempfile

ROOT = Path(__file__).resolve().parents[3]
POLICY = Path('scripts/check/test_policy.py')
NAMED = Path('crates/benitoite/tests/desugar_export/check_named.py')


def main():
    original = (ROOT / NAMED).read_text()
    pair = '    check_remaining_batch3(directory)\n    check_routing(directory, manifest)\n'
    assert original.count(pair) == 1
    variants = {
        'original': original,
        'removed': original.replace(pair, '    check_routing(directory, manifest)\n'),
        'reordered': original.replace(
            pair, '    check_routing(directory, manifest)\n    check_remaining_batch3(directory)\n'),
    }
    results = []
    with tempfile.TemporaryDirectory(prefix='k10.3b-policy-', dir=ROOT / 'target') as temporary:
        root = Path(temporary)
        for relative in (POLICY, NAMED):
            (root / relative).parent.mkdir(parents=True, exist_ok=True)
        (root / POLICY).write_text((ROOT / POLICY).read_text())
        tests = runpy.run_path(str(root / POLICY))['PolicyTests']
        for name, source in variants.items():
            (root / NAMED).write_text(source)
            case = tests('test_formal_remaining_batch3_main_order')
            try:
                case.test_formal_remaining_batch3_main_order()
            except AssertionError as error:
                assert name != 'original', str(error)
                message = str(error)
                expected = ('main must call check_remaining_batch3 once' if name == 'removed'
                            else 'check_remaining_batch3 must precede check_routing')
                assert expected in message, message
                results.append(dict(variant=name, rejected=True, reason=message))
            else:
                assert name == 'original', f'{name}: mutation was accepted'
                results.append(dict(variant=name, rejected=False))
    assert not root.exists()
    print(json.dumps(dict(results=results, temporaryCopyRemoved=True), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
