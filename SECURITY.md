# Security Policy

## Reporting a vulnerability

Send reports to **tecogonaz@kusugami-lab.net**. Do not open a public issue for a vulnerability.

Include:

- the version of `benitoite` (`benitoite --version`) and the operating system,
- the script, input, or command that shows the problem, and what happened,
- what you expected instead.

Remove secrets (API keys, tokens, passwords, personal data) from scripts and logs before sending them. This also applies to reports of internal errors ("this is a bug in the implementation") that you file as public issues.

This project is maintained by one person. Reports are answered on a best-effort basis; there is no fixed response time.

## Supported versions

Only the latest release and the default branch receive security fixes.

## What counts as a vulnerability

`benitoite check` guarantees only that a script follows the rules of types and effects: a script that passes the checks performs no built-in operation outside the effects listed in the `uses` of `main`. This release does not restrict what a script does while it runs and has no sandbox; isolation is the job of the agent harness, a container, or the operating system.

Report these as vulnerabilities:

- A script that passes `benitoite check` performs a built-in operation whose effect is not in the `uses` of `main`, or the checker accepts a script that confuses the types of values.
- Untrusted input makes `benitoite` lose memory safety, stop with an internal error, hang, or use memory or time without bound. Untrusted input includes data from network peers, the contents of files a script reads, and source files given to `check`, `fmt`, or `test`.
- A `benitoite` command or a standard library function does something its documentation says it does not do, in a way that affects security (for example, following a symbolic link it promises not to follow).
- A vulnerability in a dependency that `benitoite` uses in an affected way.

These are not vulnerabilities in this release:

- Operations that a script performs within the effects it declares, including which files, commands, or hosts it touches.
- What an external command started by `Process.run` or `Process.shell` does.
- Resource limits of a script itself, such as a script that loops forever or allocates until memory runs out.
- Changes to the file system made by another process between a check in a script and its use of the result.
