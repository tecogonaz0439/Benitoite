"""小さい実交換と保存報告で、最終manifestの読者・件数・改変拒否を通す。"""
import gzip
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import audit_saved as audit
sys.path.insert(0, str(ROOT/'scripts/check'))
import formal_interval as final
sys.path.insert(0, str(ROOT/'formal/tests'))
import interval_source_compare as source
import test_interval_exchange as exchange


def main():
    target = ROOT/'target/x05s-records'
    probes = target/'probes'
    output = target/'final-v2'
    output.mkdir()
    roots = {name: output/name for name in ['interval', 'desugar', 'coverage']}
    for directory in roots.values():
        directory.mkdir()
    comparison = roots['interval']/'comparison'
    comparison.mkdir()
    details = json.loads((HERE.parent/'x05a/run2/diagnosis-details.json').read_text())
    # 対象外警告が先頭にある実入力二つで、最終照合用の小さい一系統を作る。
    programs = roots['interval']/'programs'
    programs.mkdir()
    old = ROOT/'target/interval-diff'/audit.RUN/'comparison/real-source-0'
    materials = []
    for index in [28, 40]:
        with gzip.open(old/('source-analysis-'+str(index)+'.json.gz'), 'rt') as stream:
            materials.extend(json.load(stream)['inputs'])
    for filename, doc in [
        ('interval-manifest.json', dict(kind='source-manifest', inputs=[t['manifest'] for t in details['trials']])),
        ('interval-material.json', dict(kind='source-material', inputs=materials)),
        ('interval-observations.json', dict(kind='source-observations', inputs=[t['observation'] for t in details['trials']]))]:
        final.write(programs/filename, doc)
    selected_names = {m['name'] for m in materials}
    reader_inputs = []
    for inp in audit.inputs(ROOT/'target/desugar-diff'/audit.RUN/'named-programs-interval/interval-manifest-corpus.json'):
        if inp['name'] in selected_names:
            reader_inputs.append(inp)
        if len(reader_inputs) == len(selected_names):
            break
    final.write(programs/'interval-manifest-corpus.json', dict(kind='interval-corpus', version=1,
        surfaceVersion=14, traversalVersion=1, profile='domain', inputs=reader_inputs))
    output0 = comparison/'real-source-0'
    output0.mkdir()
    summaries = [source.exercise(exchange.Runner(output0, ROOT/'formal/.lake/build/bin/intervalDiff'), programs)]
    for number, name in enumerate(final.SOURCE_DIRS[1:]):
        subset = probes/('source-'+str(number))
        directory = roots['interval']/name
        directory.mkdir(parents=True)
        for filename in ['interval-manifest.json', 'interval-material.json', 'interval-observations.json']:
            shutil.copy2(subset/filename, directory/filename)
        names = {m['name'] for m in final.read(subset/'interval-material.json')['inputs']}
        doc = final.read(ROOT/'target/interval-diff'/audit.RUN/name/'interval-manifest-corpus.json')
        doc['inputs'] = [i for i in doc['inputs'] if i['name'] in names]
        final.write(directory/'interval-manifest-corpus.json', doc)
        shutil.copytree(subset/'comparison', comparison/('real-source-'+str(number+1)))
        summaries.append(final.read(subset/'comparison/source-analysis-summary.json'))
    final.write(comparison/'real-source-summary.json', summaries)
    profiles = probes/'profiles'
    for path in profiles.iterdir():
        if path.is_file() and not path.is_symlink():
            shutil.copy2(path, comparison/path.name)
    # VMの比較を再起動せず、既に保存された小さい報告を最終の件数読者へ渡す。
    for subdirectory, filename in [('vm', 'vm-summary.json'), ('vm/range', 'range-vm-summary.json'),
                                    ('vm/shifts', 'shift-vm-summary.json')]:
        directory = comparison/subdirectory
        directory.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT/'target/interval-diff'/audit.RUN/'comparison'/subdirectory/filename, directory/filename)
    # 未実行のLog公開利用の最終六入口は、この一入力だけを新しい出力先で確かめる。
    log_source = ROOT/'target/desugar-diff'/audit.RUN/'batch3/g2'
    log_output = roots['desugar']/'batch3/g2'
    shutil.copytree(log_source, log_output)
    check_log = runpy.run_path(str(ROOT/'crates/benitoite/tests/desugar_export/check_batch3.py'))
    check_log['check'](log_output, roots['desugar']/'batch3/g2-exchange-results.json')
    # 旧読者が最終照合で実際に使う配列二つを受け取れないことを再現する。
    text = subprocess.check_output(['git', 'show',
        '51dc0fefe2fc7a75df915a19640afb436d051e9e:scripts/check/interval_artifacts.py'], cwd=ROOT, text=True)
    previous = {}
    exec(compile(text, '<baseline-interval-artifacts>', 'exec'), previous)
    regressions = []
    for path in [comparison/'fuel-selection.json', comparison/'real-source-summary.json']:
        try:
            previous['read'](path)
        except AttributeError as error:
            assert "'list' object has no attribute 'get'" in str(error)
            regressions.append(path.name)
        else:
            raise AssertionError(('baseline array unexpectedly accepted', path.name))
        assert isinstance(final.read(path), list)
    # 全件のK1を代行しない。小さい10系統を、実際のmanifest/verify入口へ渡す。
    final.write(roots['interval']/'input-manifest.json', dict(kind='formal-interval-inputs', version=1,
        artifacts=final.inventory(roots)))
    counts = final.counts(roots)
    final.manifest(roots)
    final.verify(roots)
    bad = []
    changes = [
        (comparison/'profile-manifest.json', lambda d: d['profiles'].pop()),
        (comparison/'real-source-summary.json', lambda d: d.reverse()),
        (comparison/'real-source-summary.json', lambda d: d[0].update(comparedBodies='0'))]
    for index, (path, mutate) in enumerate(changes):
        original = path.read_bytes()
        doc = final.read(path)
        mutate(doc)
        final.write(path, doc)
        try:
            final.counts(roots)
        except AssertionError as error:
            bad.append(dict(index=index, reason=str(error)))
        else:
            raise AssertionError(('bad final count accepted', index))
        finally:
            path.write_bytes(original)
    # 同じ件数を保った本文変更・ファイルの増減も最終verifyが拒む。
    path = comparison/'real-source-summary.json'
    original = path.read_bytes()
    for label in ['hash', 'missing', 'added']:
        extra = roots['coverage']/'unexpected.json'
        if label == 'hash':
            path.write_bytes(original+b' ')
        elif label == 'missing':
            path.unlink()
        else:
            extra.write_text('{}')
        try:
            final.verify(roots)
        except AssertionError as error:
            assert 'artifact missing, added or hash differs' in str(error)
            bad.append(dict(mutation=label, reason=str(error)))
        else:
            raise AssertionError(('bad final artifact accepted', label))
        finally:
            path.write_bytes(original)
            extra.unlink(missing_ok=True)
    final.verify(roots)
    independent = runpy.run_path(str(ROOT/'crates/benitoite/tests/desugar_export/interval/check-manifest.py'))['check_independent'](comparison)
    result = dict(arrayRegressions=regressions, counts=counts, independent=independent,
                  negativeCases=bad, manifestVerified=True, fullK1=False)
    (HERE/'final-probe-details.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')


if __name__ == '__main__':
    main()
