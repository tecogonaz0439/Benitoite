# Installing Benitoite

This page explains how to install `benitoite` `0.0.9`, how to update it, and how to build it from source. For the language itself, see the [Benitoite Language Reference](benitoite.md).

## Supported systems

| System | Archive target |
|---|---|
| macOS 11.0 or later on Apple silicon (arm64) | `aarch64-apple-darwin` |
| Linux on x86_64 | `x86_64-unknown-linux-musl` |
| Linux on arm64 | `aarch64-unknown-linux-musl` |

The Linux executables are statically linked and need no other library.

## Install a release

Each release on the GitHub Releases page of the Benitoite repository contains:

- one archive per system, named `benitoite-<version>-<target>.tar.gz`, which contains the executable `benitoite`, the license texts `LICENSE-MIT` and `LICENSE-APACHE`, and `THIRD_PARTY_LICENSES`;
- `SHA256SUMS`, the SHA-256 hash of each archive.

There is no install script; follow the three steps below.

### 1. Download the archive and check its hash

Download the archive for your system and `SHA256SUMS` with `curl`. In the commands below, set `RELEASE` to the download address of the release files shown on the release page (the part before the file name), and `TARGET` to the target of your system from the table above.

```sh
RELEASE=<download address of the release>
TARGET=aarch64-apple-darwin
curl -LO "$RELEASE/benitoite-0.0.9-$TARGET.tar.gz"
curl -LO "$RELEASE/SHA256SUMS"
```

Check the hash. On macOS:

```sh
grep "benitoite-0.0.9-$TARGET.tar.gz" SHA256SUMS | shasum -a 256 -c
```

On Linux:

```sh
grep "benitoite-0.0.9-$TARGET.tar.gz" SHA256SUMS | sha256sum -c
```

The command prints `OK` after the file name when the hash matches. If it does not, download the archive again and do not use it.

`SHA256SUMS` is not signed. Checking the hash confirms that the archive is the one listed on the release page; trusting the release page itself is the basis for trusting the archive.

### 2. Put `benitoite` on your `PATH`

Extract the archive into a new directory, and move the extracted `benitoite` to a directory on your `PATH`, such as `~/.local/bin`:

```sh
mkdir benitoite-0.0.9
tar -xzf "benitoite-0.0.9-$TARGET.tar.gz" -C benitoite-0.0.9
mkdir -p ~/.local/bin
find benitoite-0.0.9 -name benitoite -type f -exec mv {} ~/.local/bin/ \;
benitoite --version
```

Keep `LICENSE-MIT`, `LICENSE-APACHE`, and `THIRD_PARTY_LICENSES` from the archive if you redistribute `benitoite`. `benitoite --licenses` prints the same `THIRD_PARTY_LICENSES`.

`benitoite --version` prints `benitoite 0.0.9` on its first line. If the shell cannot find `benitoite`, add the directory to `PATH` in the startup file of your shell (for example, `export PATH="$HOME/.local/bin:$PATH"`).

For an agent or harness, use `benitoite --version=json` as the first and only argument to query version, build, and supported-format information. Verify the required `formats` keys and understood integer versions instead of inferring capabilities from the release number. The output is one UTF-8 JSON object followed by LF. Success exits with 0, usage errors with 2, internal errors with 3, and output failures with 1. See [Version and supported formats](benitoite.md#version-and-supported-formats) for the fields and [Build information](#build-information) for the meaning of unknown values.

#### If macOS blocks `benitoite`

The macOS executable is not signed or notarized by Apple. A file downloaded with `curl` as above is not blocked. A file downloaded with a web browser is marked as downloaded from the internet, and Gatekeeper stops it from starting, with a dialog saying that Apple could not verify that it is free of malware.

If you downloaded the archive with a browser, remove the mark from the extracted executable before running it for the first time:

```sh
xattr -d com.apple.quarantine ~/.local/bin/benitoite
```

`xattr` reports `No such xattr` when the file has no mark; that is not a problem. You can also allow the executable in System Settings, under Privacy & Security, after macOS has blocked it once.

### 3. Install the Agent Skill

`benitoite` contains an Agent Skill that teaches coding agents (Claude Code, Codex CLI, and opencode) how to write, check, and run Benitoite scripts. Write it to the places where the agents read skills:

```sh
benitoite skill install
```

The command prints each directory it writes. By default it installs for your user, for all supported agents:

| Agent (`--agent`) | `--user` (default) | `--project` |
|---|---|---|
| `claude-code` | `~/.claude/skills/benitoite/` | `./.claude/skills/benitoite/` |
| `codex` | `~/.agents/skills/benitoite/` | `./.agents/skills/benitoite/` |
| `opencode` | `~/.agents/skills/benitoite/` | `./.agents/skills/benitoite/` |

Use `--project` to install into the current directory instead, and `--agent <name>` (repeatable) to install for some agents only:

```sh
benitoite skill install --project --agent claude-code
```

`install` replaces a `benitoite/` directory only when an earlier `install` wrote it; it does not overwrite a directory of the same name that you made yourself, and ends with exit status 1 instead. `benitoite skill uninstall` takes the same options and removes what `install` wrote.

The Skill tells agents to show you the effects of a script (such as writing files or starting commands) before running it, and to ask before running scripts that write files, start commands, or use the network. An agent or harness can use `check --report=json` for `main` or `test --check --report=json` for tests, review a complete successful report, and pass the accepted atomic effect names to `run --allow-effects=...` or executing `test --allow-effects=...`. `Assert.Check` remains part of test contracts and allowed sets. See [Inspection reports](benitoite.md#inspection-reports) and [Effect limits before execution](benitoite.md#effect-limits-before-execution) for arguments, failure handling, and output contracts.

These checks compare static declared effect sets. They do not enforce permissions while a script runs, fix its source between inspection and execution, or fix the file paths, contents, and commands used within an accepted set. Run scripts inside the agent's or harness's sandbox.

### Read the Skill without installing it

An agent or harness can retrieve the documents embedded in the executable without writing an installation or inspecting `HOME`, the working directory, or an installed copy:

```sh
benitoite skill list
benitoite skill show SKILL.md
benitoite skill show references/stdlib/IO.File.md
benitoite skill list --format=json
benitoite skill show --format=json SKILL.md
```

`list` prints all embedded logical names, including license files, in lexical order, one per line. `show` prints only the selected document's UTF-8 text, without adding a newline. Its text is the same as `install` would write from that executable: the version placeholder in `SKILL.md` is replaced with the executable's version.

Logical names are case-sensitive and use `/`; they must match the list exactly. They are not OS paths. Empty names, leading `/`, empty components, `.` or `..` components, backslashes, and colons (including drive prefixes) are rejected. `list` accepts no document name, and `show` requires exactly one. `--format=text` is the default; `--format=json` must use `=`, may appear before or after the logical name, and may occur once. Neither query accepts `--user`, `--project`, or `--agent`, and `install` and `uninstall` do not accept `--format`.

JSON queries return one object followed by LF:

| Query | Fields |
|---|---|
| `list --format=json` | `schemaVersion: 1`, `kind: "skillList"`, `producer`, and `documents: [{name, byteLength, contentHash}]` in lexical name order. |
| `show --format=json <logical-name>` | `schemaVersion: 1`, `kind: "skillDocument"`, `producer`, `name`, `byteLength`, `contentHash`, and `text`. |

`producer` is `{name, version, build}`, with the same values as the version query. `byteLength` counts bytes of the rendered UTF-8 text, after version replacement, and `contentHash` is `{algorithm: "sha256", value: "<64 lowercase hexadecimal digits>"}` over those same bytes. `list`, `show`, and `install` use the same rendered text. They do not read document contents from disk.

Query success exits with 0; invalid syntax or logical names and unknown documents exit with 2, with an explanation on standard error and empty standard output, even with `--format=json`. An internal error exits with 3. A write or flush failure exits with 1 and does not guarantee complete output.

## Update

To update, repeat steps 1 and 2 with the new version to replace the executable, and then run step 3 again:

```sh
benitoite skill install
```

The Skill describes only the version of `benitoite` it comes with. When the versions differ, the Skill tells the agent to ask you to run `benitoite skill install` again. Read the [CHANGELOG](../../CHANGELOG.md) before updating to a new minor version (for example, from `0.1.x` to `0.2.0`): minor versions may contain incompatible changes.

See [Functions and lambdas](benitoite.md#6-functions-and-lambdas) for calling rules and function contracts. Use the Skill installed from the same executable to look up parameter names and callback contracts.

### Updating from 0.0.8 to 0.0.9

This version is source-only: use the build instructions below, then reinstall the Skill from the new executable. Read the [0.0.9 migration](../../CHANGELOG.md#009-san-benito) before updating language declarations and dependency hashes. Review Regex constant rejection, Scope's spelling checks, Range's runtime Error, and any added @opaque boundary. Builders require State and cannot be captured. A harness using documentation examples must request --doc and understand report version 2; ordinary calls retain version 1.

For Property, migrate handwritten Shrinkers to deferred ShrinkStep sequences, supply Config.maxShrinkWork, and retain Counterexample.shrinkWork and libraryVersion 2.0.0 for replay. Development derive users must finish old recovery first, rebuild the reader and CLI, and review a fresh version 2 manifest and record before applying its exact SHA-256; configuration remains version 1. See the [combined generation migration](../../tools/derive/README.md#markers-records-and-review-artifacts). Save concrete failures and handwritten sources as well as the seed and tool/library versions. Reinstalling the Skill or changing language alone does not migrate code or generated records.

## Build from source

You need a Rust toolchain with `cargo` (see the `rust-version` in `Cargo.toml` of the repository for the minimum version).

You also need a C compiler to build Wasmtime: install the Xcode command line tools on macOS, or `cc` on Linux.

Get the source of the repository, and from its root run:

```sh
cargo install --locked --path crates/benitoite
```

This installs `benitoite` into `~/.cargo/bin`. Then install the Agent Skill as in [step 3](#3-install-the-agent-skill). The Skill documents are kept in the repository and embedded into the executable at build time.

A build from source differs from a release in two ways:

- `benitoite --licenses` does not list the licenses of the third-party software, because the list is made only by the release process. It says that the list is not included in this build.
- On Linux, the executable links to the system C library (glibc) by default. Use a release archive when you need a statically linked executable.

### Build information

The build embeds a commit ID, dirty state, Cargo target, and the origin of each value. `benitoite --version=json` and JSON reports return those embedded values; setting the inputs when running the executable does not change them.

| Build-time input | Accepted values | When omitted |
|---|---|---|
| `BENITOITE_BUILD_COMMIT` | A full ASCII hexadecimal Git object ID of 40 or 64 digits (normalized to lowercase), or `unknown`. | Try Git in the verified repository workspace; otherwise `null` with provenance `"unknown"`. |
| `BENITOITE_BUILD_DIRTY` | `true`, `false`, or `unknown`. | Do not collect dirty state; `null` with provenance `"notCollected"`. |

Explicit inputs take precedence independently and have provenance `"environment"`, including an explicit `unknown` that produces `null`. Setting the commit input also disables Git lookup and monitoring. Empty values, surrounding whitespace, abbreviated IDs, non-UTF-8 values, and other invalid inputs fail the build rather than falling back to Git. The target comes from Cargo's build target, not an inference from the host system.

Automatic commit lookup verifies the workspace and its Git root, supports Git worktrees, and does not search a parent repository when building an extracted source archive. Git absence or lookup failure leaves the commit unknown and does not prevent a build. Git is used only at build time. A `null` dirty value never means that the tree was clean: dirty state is not automatically inspected, even when Git supplies a commit.

Build information is collected again when the build script or either explicit input changes. For automatic commit lookup, it monitors existing Git `HEAD`, the referenced branch's ref, `packed-refs`, and the worktree's HEAD reflog (`logs/HEAD`) at their actual management paths. It does not monitor the index, working files, or whole directories, so staging, editing, and adding untracked or ignored files do not collect a new dirty state. Recompiling changed Rust sources alone does not recollect build information.

Only existing monitoring files are registered. If the required HEAD, management paths, or branch monitoring cannot be established, or Git uses reftable storage, the commit is unknown. Changes that leave every registered file unchanged can go unnoticed: examples include creating a loose ref from a packed ref when there is no HEAD reflog, making the first commit on an unborn branch, installing Git, or adding Git management to an archive. In those cases, change an explicit build input or clean-build the package to collect information again. Commit information is a build-time self-report; it does not prove current Git state, complete source identity, or trust in the executable.

### Explicit environment settings for child commands

`Process.run` and `Process.runAttached` reject `Command.environment` names starting with `DYLD_` or `LD_` (ASCII case-insensitive), including `LD_RUN_PATH`, before starting a child. Empty values and setting the same inherited value also fail, returning `IOErrorKind.InvalidInput` as a value. This rule applies to all operating systems and does not remove inherited variables; `Process.shell` still inherits them. Allowing `Process.Run` also permits a command such as `env` or a shell to set loader variables itself. The rule does not control the initial environment, `PATH`, command-specific settings, grandchildren, or all Windows DLL searches. See [IO and network behavior](benitoite.md#io-and-network-behavior) for the full contract, and keep isolation in the harness or OS.

## Uninstall

Remove the Skill first, while `benitoite` is still installed, and then the executable:

```sh
benitoite skill uninstall
rm ~/.local/bin/benitoite
```

If you used `--project` or `--agent` when installing, pass the same options to `uninstall`.

> Note: Releases `0.0.1` through `0.0.9` are source-only releases; no executables are provided. Executables will be provided from `0.1.0`.
