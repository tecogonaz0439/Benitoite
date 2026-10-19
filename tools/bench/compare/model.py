"""Scenario contract shared by the runner and independently registered families."""
from dataclasses import dataclass, field
EMPTY = 'function main() -> Unit\nend function\n'

@dataclass
class Case:
    id: str
    section: str
    family: str
    n: int
    files: dict
    command: str = 'check'
    states: tuple = ()
    codes: tuple = ()
    params: dict = field(default_factory=dict)
    expected_stdout: str = ''
    expected_status: int = 0
    validator: str = 'stdout'
    cross_equal: bool = True
    arguments: tuple = ()
    requires: tuple = ()
    variant_feature: str = ''
    tags: tuple = ('quick', 'targets', 'full')

    def variant(self, capabilities):
        return 'modern' if self.variant_feature and capabilities.get(self.variant_feature, False) else 'legacy'

    def sources(self, variant):
        return self.files[variant]

def common(text, extra=None):
    files = {'main.bnt': text, **(extra or {})}
    return dict(legacy=files, modern=files)
