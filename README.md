# Angular Language Service JSDoc URI PoC

Private, local-only reproduction for coordinated disclosure. It demonstrates:

```text
project-controlled JSDoc Markdown
-> trusted `angular.openJsDocLink` command URI
-> attacker-controlled `git:` URI
-> VS Code Git FileSystemProvider
-> `git show --output` option injection
-> tracked POSIX symlink
-> overwrite outside the opened repository
-> later loading of that disposable file
-> benign marker creation
```

## Safety

Everything except installed tools stays under `./.lab/`. The PoC never targets the real home directory, shell profile, credentials, or network. Its only execution payload is `touch` against:

```text
./.lab/code-exec-marker.txt
```

Cleanup verifies the exact laboratory path before recursive deletion.

## Requirements

- WSL/Linux
- Git, Node.js, npm, and VS Code CLI
- official `Angular.ng-template` extension installed in the WSL extension host
- trusted disposable workspace for the UI step

The tested vulnerable local setup was VS Code `1.133.0` with Angular Language Service `22.0.0-rc.0`. The locally installed Windows extension `22.1.0` contains the same `Uri.parse(args.file)` sink.

## Reproduce

Run every command inside WSL:

```bash
chmod +x poc-wsl.sh
./poc-wsl.sh cleanup
./poc-wsl.sh prepare
./poc-wsl.sh open
```

`prepare` requests only the pinned direct dependency `@angular/core@22.0.0-rc.0`, matching the tested WSL extension, using `--ignore-scripts`. npm may resolve its declared dependency/peer graph. No Angular CLI, application build, task, SSR server, package script, or lifecycle script runs.

In the new VS Code WSL window:

1. Trust the generated `./.lab/repo` workspace.
2. Open `src/poc.ts`.
3. Hover `value` inside `template: '{{ value }}'`.
4. Click **Open component documentation**.
5. Return to WSL and run:

```bash
./poc-wsl.sh verify
```

Expected proof:

```text
[OK] external disposable file overwritten through Angular -> git: chain
[OK] exact overwritten rcfile created benign marker
[OK] normal disposable HOME loading created benign marker
```

Useful commands:

```bash
./poc-wsl.sh inspect
./poc-wsl.sh direct
./poc-wsl.sh cleanup
```

`direct` tests only the underlying Git option-injection primitive. `prepare` also runs this preflight once, then resets the target so later overwrite can only come from the Angular/VS Code action.

## Preconditions and claim boundary

Victim must open an attacker-controlled Angular project in a trusted VS Code workspace, have official Angular Language Service enabled, display the prepared hover, and click its documentation link. Restricted Mode is not bypassed. The click causes external-file overwrite; code execution is a later consequence when the chosen startup/configuration file is loaded.

See [VALIDATION.md](VALIDATION.md) for source-to-sink evidence and review of alternative URI schemes.
