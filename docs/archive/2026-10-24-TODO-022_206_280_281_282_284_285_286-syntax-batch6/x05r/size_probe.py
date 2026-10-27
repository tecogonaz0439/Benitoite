"""X05a の件数と短い実比較の保存量から、K1 の区間出力を推定する。"""
from pathlib import Path
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
BASE = ROOT/'target/interval-diff/x05r-indexed-final'
prior = HERE.parent/'x05a'
index = json.loads((prior/'k1-records-index.json').read_text())['files']
old_programs = sum(r['bytes'] for r in index if r['path'].startswith('interval/programs/'))
old_other = sum(r['bytes'] for r in index if r['path'].startswith('interval/') and not r['path'].startswith('interval/programs/'))
with zipfile.ZipFile(prior/'k1-records.zip') as archive:
    old_summary = json.loads(archive.read('interval/programs/interval-summary.json'))['inputs']
old_counts = {group: sum(int(i['counts'].get('analyzedBodies', '0')) for i in old_summary if i['group'] == group)
              for group in ('random', 'golden')}
source = BASE/'programs'
import sys
sys.path.insert(0, str(ROOT/'scripts/check'))
from interval_artifacts import read
manifests = [i for i in read(source/'interval-manifest.json')['inputs'] if i['checker'] == 'succeeded']
comparison = BASE/'indexed-comparison'
samples = []
for n, m in enumerate(manifests):
    files = [f for f in comparison.iterdir() if re.match('source-analysis-'+str(n)+r'(?:\.|-definition-)', f.name)]
    count = int(m['counts']['analyzedBodies'])
    size = sum(f.stat().st_size for f in files)
    if count:
        samples.append(dict(input=m['input'], group=m['group'], bodies=count, bytes=size,
                            bytesPerBody=size/count))
rates = {group: max(row['bytesPerBody'] for row in samples if row['group'] == group)
         for group in old_counts}
projected_reports = sum(old_counts[group]*rates[group] for group in old_counts)
# 全件読者の復元用圧縮入力も残す。元の compact reader corpus との実測比で推定する。
reader_bytes = (comparison/'source-manifest.input.json.gz').stat().st_size
material_bytes = sum((ROOT/path).stat().st_size for path in [
    'target/desugar-diff/x05r-local/named-programs-interval/interval-manifest-corpus.json',
    'target/desugar-diff/x05r-local/independent-program-interval/interval-manifest-corpus.json'])
old_reader = next(r['bytes'] for r in index if r['path'] == 'desugar/named-programs-interval/interval-manifest-corpus.json')
projected_reader = old_reader*reader_bytes/material_bytes
# 残る既存の独立入力・VM 等に、追加の局所入力と最終ハッシュ索引の余裕を加える。
allowance = 64*1024*1024
projected = int(projected_reports+projected_reader+old_other+allowance)
result = dict(kind='short-trial-storage-projection', fullK1Run=False, targetBytes=2000000000,
    priorCopiedProgramsBytes=old_programs, priorOtherIntervalBytes=old_other,
    indexBytes=sum(f.stat().st_size for f in source.iterdir()), priorAnalyzedBodies=old_counts,
    samples=samples, maximumSampleBytesPerBody=rates,
    projectedSourceComparisonsBytes=int(projected_reports),
    readerSampleBytes=reader_bytes, readerOriginalBytes=material_bytes,
    projectedFullReaderBytes=int(projected_reader), extraAllowanceBytes=allowance,
    projectedIntervalBytes=projected, belowTarget=projected <= 2000000000,
    limitation='Two fixed random seeds and selected golden inputs; full K1 output remains unmeasured')
(HERE/'size-summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(result, ensure_ascii=False))
assert result['belowTarget'], 'storage projection exceeds target'
