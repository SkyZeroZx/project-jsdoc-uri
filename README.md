# Project-controlled JSDoc links can open unintended VS Code URI providers

## Summary

Angular Language Service turns a project-controlled JSDoc link into the `angular.openJsDocLink` command. The command parses its `file` argument with `vscode.Uri.parse()` and opens the result, so the project can select a URI provider instead of being limited to a local file.

With a crafted `git:` URI, VS Code's built-in Git provider passes an attacker-controlled `ref` to `git show`. The PoC uses Git's `--output` option and a tracked POSIX symlink to overwrite a disposable file outside the generated repository.

The impact is an external-file overwrite with the VS Code user's permissions. The click does not execute code. Code execution is possible only if another application later loads the overwritten file as startup or configuration content; this PoC checks that condition with a disposable `.bashrc` and a harmless marker.

This requires a trusted workspace and a user who displays the hover and clicks **Open component documentation**.

## Tested environment

- VS Code `1.133.0`
- Angular Language Service `22.0.0-rc.0` in WSL
- Locally installed Angular Language Service `22.1.0`
- Git `2.43.0`
- Node.js `22.22.0`

These are the exact versions inspected or tested. No complete affected-version range or shipped fix has been verified.

## Reproduction

Run the PoC from WSL:

```bash
chmod +x poc-wsl.sh
./poc-wsl.sh cleanup
./poc-wsl.sh prepare
./poc-wsl.sh open
```

In the VS Code window:

1. Trust only the generated `./.lab/repo` workspace.
2. Open `src/poc.ts`.
3. Hover over `value` in `template: '{{ value }}'`.
4. Click **Open component documentation**.

Then return to WSL:

```bash
./poc-wsl.sh verify
./poc-wsl.sh cleanup
```

All test targets stay under `./.lab/`. `prepare` validates the Git behavior directly and resets the target before the UI test. Do not run `./poc-wsl.sh direct` between `prepare` and the hover click, because `verify` would no longer prove that the new overwrite came from the UI action.

## Check Validation

- Confirmed: project-controlled JSDoc creates the trusted Angular command link.
- Confirmed: its `file` value reaches `Uri.parse()` without a `file:` scheme restriction.
- Confirmed: the built-in `git:` provider passes the controlled `ref` to Git.
- Confirmed: the direct preflight overwrites the disposable file outside the generated repository.
- Confirmed: later loading of that file creates only the harmless marker.
- Confirmed: the target is reset and the negative control is clean before the UI test.
- Pending: a fresh hover click in the current generated workspace followed by `./poc-wsl.sh verify`.

Other installed URI providers were reviewed, but none produced a stronger local demonstration. GitLens requires another extension, while debugger, Copilot, Angular, `vscode-userdata:`, and `vscode-remote:` providers did not provide a demonstrated write or exfiltration path here. The built-in `git:` provider remains the most realistic local PoC.
