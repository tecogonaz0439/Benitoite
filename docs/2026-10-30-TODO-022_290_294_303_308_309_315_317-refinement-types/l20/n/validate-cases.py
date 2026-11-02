"""表の件数・葉・構成子・定義本体の検査を、小さい改変で確かめる。"""
from pathlib import Path
import contextlib
import io
import json
import tempfile
import validate


def main():
    source = validate.HERE
    original_signatures = (source / "signatures.md").read_text()
    original_leaves = (source / "leaves.md").read_text()
    cases = []
    with tempfile.TemporaryDirectory(prefix="benitoite-leaves-") as directory:
        validate.HERE = Path(directory)
        for name in ["h04-handoff.lean", "h04-counterexample.lean"]:
            (validate.HERE / name).write_bytes((source / name).read_bytes())
        def run(name, signatures, leaves, accepted):
            (validate.HERE / "signatures.md").write_text(signatures)
            (validate.HERE / "leaves.md").write_text(leaves)
            try:
                with contextlib.redirect_stdout(io.StringIO()):
                    validate.main()
            except AssertionError:
                assert not accepted, name
                cases.append({"case": name, "rejected": True})
                return
            assert accepted, name
            result = json.loads((validate.HERE / "validation.json").read_text())
            cases.append({"case": name, "inherited": result["general_inherited"], "added": result["general_added"]})
        run("unchanged", original_signatures, original_leaves, True)
        run("reclassify_one_row", original_signatures,
            original_leaves.replace("| 継承 |", "| 追加 |", 1), True)
        assert (cases[-1]["inherited"], cases[-1]["added"]) == (68, 8)
        run("missing_leaf", original_signatures,
            original_leaves.replace("StateTyE.builder_new`", "StateTyE.missing_leaf`", 1), False)
        run("wrong_constructor", original_signatures,
            original_leaves.replace("`BuilderStateLeaves`：`StateTyE.builder_new`",
                "`ClosureStateLeaves`：`StateTyE.let_step`", 1), False)
        run("missing_definition_body", original_signatures.replace("| .invalidBounds lo hi => [lo,hi]", "", 1), original_leaves, False)
    (source / "validation-cases.json").write_text(json.dumps(cases, indent=2) + "\n")
    print(json.dumps(cases))


if __name__ == "__main__":
    main()
