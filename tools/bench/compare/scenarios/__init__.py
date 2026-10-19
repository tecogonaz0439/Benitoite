"""Add a family here; the runner does not know release-specific grids."""
from model import Case, common, EMPTY
from scenarios import functions, constraints, shrinking, builders, runtime
VALIDATORS = {'shrinking': shrinking.validate_output}
FAMILIES = (functions, constraints, shrinking, builders, runtime)

def corpus(quick=False, repeats=1, fixtures=None):
    cases = []
    for family in FAMILIES:
        generated = family.cases(quick, repeats, fixtures)
        for case in generated:
            case.tags = ('full', *(('quick',) if quick else ()),
                         *(('short',) if family.short_point(case) else ()))
        cases.extend(generated)
    return cases

def resource_point(case):
    return 'short' in case.tags


def target_ids(config):
    """Explicit observations plus every expression leaf, independent of release names."""
    ids = set(config.get('cases', []))
    def visit(value):
        if isinstance(value, dict):
            if value.get('op') == 'median':
                ids.add(value['case'])
            for child in value.values(): visit(child)
        elif isinstance(value, list):
            for child in value: visit(child)
    visit(config.get('targets', []))
    return ids


def select_tier(cases, tier, targets=None, quick=False):
    if quick or tier == 'full':
        return cases
    if tier == 'short':
        return [c for c in cases if 'short' in c.tags]
    wanted = target_ids(targets or {})
    known = {c.id for c in cases}
    if wanted - known:
        raise ValueError('unknown target cases: ' + ', '.join(sorted(wanted-known)))
    return [c for c in cases if c.id in wanted]
