"""完了した検査のログと件数を、検査を再実行せずに集計する。"""
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent

def totals(text):
    rows = re.findall(r'^test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored;', text, re.M)
    return dict(targets=len(rows), passed=sum(int(row[0]) for row in rows),
                failed=sum(int(row[1]) for row in rows), ignored=sum(int(row[2]) for row in rows))

def main():
    log = (HERE / 'work-scoped.log').read_text()
    body = json.loads((HERE / 'work-check-scoped.json').read_text())
    outer = json.loads((HERE / 'work-scoped.json').read_text())
    assert body['exit'] == 0 and 'selected checks passed' in log
    lib = log.split('== lib_default\n', 1)[1].split('== tests_related\n', 1)[0]
    integration = log.split('== tests_related\n', 1)[1].split('== source_rules\n', 1)[0]
    result = dict(base='0341dfe350598fb3626137d4d47121301acea382',
                  command=body['command'], exit=body['exit'], seconds=body['seconds'],
                  outerExit=outer['exit'], outerSeconds=outer['seconds'],
                  lib=totals(lib), integration=totals(integration),
                  integrationExecutables=len(re.findall(r'^     Running tests/', integration, re.M)),
                  maximumResidentSetSize=None,
                  resourceMeasurementUnavailable='sysctl kern.clockrate: Operation not permitted' in log)
    assert result['integrationExecutables'] == result['integration']['targets'] == 40
    assert result['lib']['passed'] == 1332
    assert result['lib']['failed'] == result['integration']['failed'] == 0
    (HERE / 'work-summary.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result))

if __name__ == '__main__':
    main()
