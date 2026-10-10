# Installing Benitoite

This page explains how to install `benitoite` `0.0.2`, how to update it, and how to build it from source. For the language itself, see the [Benitoite Language Reference](benitoite.md).

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
curl -LO "$RELEASE/benitoite-0.0.2-$TARGET.tar.gz"
curl -LO "$RELEASE/SHA256SUMS"
```

Check the hash. On macOS:

```sh
grep "benitoite-0.0.2-$TARGET.tar.gz" SHA256SUMS | shasum -a 256 -c
```

On Linux:

```sh
grep "benitoite-0.0.2-$TARGET.tar.gz" SHA256SUMS | sha256sum -c
```

The command prints `OK` after the file name when the hash matches. If it does not, download the archive again and do not use it.

`SHA256SUMS` is not signed. Checking the hash confirms that the archive is the one listed on the release page; trusting the release page itself is the basis for trusting the archive.

### 2. Put `benitoite` on your `PATH`

Extract the archive into a new directory, and move the extracted `benitoite` to a directory on your `PATH`, such as `~/.local/bin`:

```sh
mkdir benitoite-0.0.2
tar -xzf "benitoite-0.0.2-$TARGET.tar.gz" -C benitoite-0.0.2
mkdir -p ~/.local/bin
find benitoite-0.0.2 -name benitoite -type f -exec mv {} ~/.local/bin/ \;
benitoite --version
```

Keep `LICENSE-MIT`, `LICENSE-APACHE`, and `THIRD_PARTY_LICENSES` from the archive if you redistribute `benitoite`. `benitoite --licenses` prints the same `THIRD_PARTY_LICENSES`.

`benitoite --version` prints `benitoite 0.0.2` on its first line. If the shell cannot find `benitoite`, add the directory to `PATH` in the startup file of your shell (for example, `export PATH="$HOME/.local/bin:$PATH"`).

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

The Skill tells agents to show you the effects of a script (such as writing files or starting commands) before running it, and to ask before running scripts that write files, start commands, or use the network. `benitoite` itself does not restrict what a script does while it runs, so let agents run scripts inside their sandbox.

## Update

To update, repeat steps 1 and 2 with the new version to replace the executable, and then run step 3 again:

```sh
benitoite skill install
```

The Skill describes only the version of `benitoite` it comes with. When the versions differ, the Skill tells the agent to ask you to run `benitoite skill install` again. Read the [CHANGELOG](../../CHANGELOG.md) before updating to a new minor version (for example, from `0.1.x` to `0.2.0`): minor versions may contain incompatible changes.

## Build from source

You need a Rust toolchain with `cargo` (see the `rust-version` in `Cargo.toml` of the repository for the minimum version). Get the source of the repository, and from its root run:

```sh
cargo install --locked --path crates/benitoite
```

This installs `benitoite` into `~/.cargo/bin`. Then install the Agent Skill as in [step 3](#3-install-the-agent-skill). The Skill documents are kept in the repository and embedded into the executable at build time.

A build from source differs from a release in two ways:

- `benitoite --licenses` does not list the licenses of the third-party software, because the list is made only by the release process. It says that the list is not included in this build.
- On Linux, the executable links to the system C library (glibc) by default. Use a release archive when you need a statically linked executable.

## Uninstall

Remove the Skill first, while `benitoite` is still installed, and then the executable:

```sh
benitoite skill uninstall
rm ~/.local/bin/benitoite
```

If you used `--project` or `--agent` when installing, pass the same options to `uninstall`.

> Note: `0.0.2`, like `0.0.1`, is a source-only release; no executables are provided. Executables will be provided from `0.1.0`.
