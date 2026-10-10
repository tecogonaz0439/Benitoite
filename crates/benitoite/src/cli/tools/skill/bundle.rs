//! 同梱の Agent Skill の埋め込みの一覧（設計書 06-06「同梱の Agent Skill の構成」）。
//! 生成の道具（`cargo run -p benitoite --example gen_skill`）が書いたファイルであり、手で直さない。

use super::SkillFile;

/// Skill のすべてのファイル。`path` は Skill の中のパスである。
pub const FILES: &[SkillFile] = &[
    SkillFile {
        path: "SKILL.md",
        text: include_str!("../../../../skill/SKILL.md"),
    },
    SkillFile {
        path: "references/common-mistakes.md",
        text: include_str!("../../../../skill/references/common-mistakes.md"),
    },
    SkillFile {
        path: "references/diagnostics.md",
        text: include_str!("../../../../skill/references/diagnostics.md"),
    },
    SkillFile {
        path: "references/grammar.md",
        text: include_str!("../../../../skill/references/grammar.md"),
    },
    SkillFile {
        path: "references/idioms.md",
        text: include_str!("../../../../skill/references/idioms.md"),
    },
    SkillFile {
        path: "references/language-comparison.md",
        text: include_str!("../../../../skill/references/language-comparison.md"),
    },
    SkillFile {
        path: "references/stdlib/Assert.md",
        text: include_str!("../../../../skill/references/stdlib/Assert.md"),
    },
    SkillFile {
        path: "references/stdlib/Boolean.md",
        text: include_str!("../../../../skill/references/stdlib/Boolean.md"),
    },
    SkillFile {
        path: "references/stdlib/Byte.md",
        text: include_str!("../../../../skill/references/stdlib/Byte.md"),
    },
    SkillFile {
        path: "references/stdlib/ByteOrder.md",
        text: include_str!("../../../../skill/references/stdlib/ByteOrder.md"),
    },
    SkillFile {
        path: "references/stdlib/Bytes.md",
        text: include_str!("../../../../skill/references/stdlib/Bytes.md"),
    },
    SkillFile {
        path: "references/stdlib/Character.md",
        text: include_str!("../../../../skill/references/stdlib/Character.md"),
    },
    SkillFile {
        path: "references/stdlib/Csv.md",
        text: include_str!("../../../../skill/references/stdlib/Csv.md"),
    },
    SkillFile {
        path: "references/stdlib/Decimal.md",
        text: include_str!("../../../../skill/references/stdlib/Decimal.md"),
    },
    SkillFile {
        path: "references/stdlib/Encoding.md",
        text: include_str!("../../../../skill/references/stdlib/Encoding.md"),
    },
    SkillFile {
        path: "references/stdlib/Float.md",
        text: include_str!("../../../../skill/references/stdlib/Float.md"),
    },
    SkillFile {
        path: "references/stdlib/Hash.md",
        text: include_str!("../../../../skill/references/stdlib/Hash.md"),
    },
    SkillFile {
        path: "references/stdlib/IO.Clock.md",
        text: include_str!("../../../../skill/references/stdlib/IO.Clock.md"),
    },
    SkillFile {
        path: "references/stdlib/IO.Console.md",
        text: include_str!("../../../../skill/references/stdlib/IO.Console.md"),
    },
    SkillFile {
        path: "references/stdlib/IO.File.md",
        text: include_str!("../../../../skill/references/stdlib/IO.File.md"),
    },
    SkillFile {
        path: "references/stdlib/IO.Process.md",
        text: include_str!("../../../../skill/references/stdlib/IO.Process.md"),
    },
    SkillFile {
        path: "references/stdlib/IO.Random.md",
        text: include_str!("../../../../skill/references/stdlib/IO.Random.md"),
    },
    SkillFile {
        path: "references/stdlib/IO.md",
        text: include_str!("../../../../skill/references/stdlib/IO.md"),
    },
    SkillFile {
        path: "references/stdlib/IOError.md",
        text: include_str!("../../../../skill/references/stdlib/IOError.md"),
    },
    SkillFile {
        path: "references/stdlib/IOErrorKind.md",
        text: include_str!("../../../../skill/references/stdlib/IOErrorKind.md"),
    },
    SkillFile {
        path: "references/stdlib/Integer.md",
        text: include_str!("../../../../skill/references/stdlib/Integer.md"),
    },
    SkillFile {
        path: "references/stdlib/Json.md",
        text: include_str!("../../../../skill/references/stdlib/Json.md"),
    },
    SkillFile {
        path: "references/stdlib/Lazy.md",
        text: include_str!("../../../../skill/references/stdlib/Lazy.md"),
    },
    SkillFile {
        path: "references/stdlib/List.md",
        text: include_str!("../../../../skill/references/stdlib/List.md"),
    },
    SkillFile {
        path: "references/stdlib/Map.md",
        text: include_str!("../../../../skill/references/stdlib/Map.md"),
    },
    SkillFile {
        path: "references/stdlib/Network.Http.md",
        text: include_str!("../../../../skill/references/stdlib/Network.Http.md"),
    },
    SkillFile {
        path: "references/stdlib/NetworkError.md",
        text: include_str!("../../../../skill/references/stdlib/NetworkError.md"),
    },
    SkillFile {
        path: "references/stdlib/NetworkErrorKind.md",
        text: include_str!("../../../../skill/references/stdlib/NetworkErrorKind.md"),
    },
    SkillFile {
        path: "references/stdlib/Option.md",
        text: include_str!("../../../../skill/references/stdlib/Option.md"),
    },
    SkillFile {
        path: "references/stdlib/Pair.md",
        text: include_str!("../../../../skill/references/stdlib/Pair.md"),
    },
    SkillFile {
        path: "references/stdlib/Path.md",
        text: include_str!("../../../../skill/references/stdlib/Path.md"),
    },
    SkillFile {
        path: "references/stdlib/Reference.md",
        text: include_str!("../../../../skill/references/stdlib/Reference.md"),
    },
    SkillFile {
        path: "references/stdlib/Regex.md",
        text: include_str!("../../../../skill/references/stdlib/Regex.md"),
    },
    SkillFile {
        path: "references/stdlib/Result.md",
        text: include_str!("../../../../skill/references/stdlib/Result.md"),
    },
    SkillFile {
        path: "references/stdlib/RoundingMode.md",
        text: include_str!("../../../../skill/references/stdlib/RoundingMode.md"),
    },
    SkillFile {
        path: "references/stdlib/Set.md",
        text: include_str!("../../../../skill/references/stdlib/Set.md"),
    },
    SkillFile {
        path: "references/stdlib/String.md",
        text: include_str!("../../../../skill/references/stdlib/String.md"),
    },
    SkillFile {
        path: "references/stdlib/Task.md",
        text: include_str!("../../../../skill/references/stdlib/Task.md"),
    },
    SkillFile {
        path: "references/stdlib/TaskGroup.md",
        text: include_str!("../../../../skill/references/stdlib/TaskGroup.md"),
    },
    SkillFile {
        path: "references/stdlib/Time.md",
        text: include_str!("../../../../skill/references/stdlib/Time.md"),
    },
    SkillFile {
        path: "references/stdlib/Trait.md",
        text: include_str!("../../../../skill/references/stdlib/Trait.md"),
    },
    SkillFile {
        path: "references/stdlib/Triple.md",
        text: include_str!("../../../../skill/references/stdlib/Triple.md"),
    },
    SkillFile {
        path: "references/stdlib/index.md",
        text: include_str!("../../../../skill/references/stdlib/index.md"),
    },
    SkillFile {
        path: "LICENSE-MIT",
        text: include_str!("../../../../../../LICENSE-MIT"),
    },
    SkillFile {
        path: "LICENSE-APACHE",
        text: include_str!("../../../../../../LICENSE-APACHE"),
    },
];
