# Validation record

## Finding

**ALS-JSDOC-URI-001 — project-controlled JSDoc can select unintended VS Code URI providers**

Candidate source/reference: supplied private Angular security report. No public issue or advisory is linked because disclosure is not coordinated.

## Rubric

- [x] Project-controlled JSDoc produces a trusted `angular.openJsDocLink` command link.
- [x] Attacker-controlled `file` reaches a general URI parser without a scheme allowlist.
- [x] Current local VS Code routes `git:` to a provider that places attacker-controlled `ref` in Git argv.
- [x] Disposable Git/POSIX primitive overwrites a file outside the generated repository and its later loading creates only the benign marker.
- [ ] Fresh UI click in the generated workspace is recorded by `./poc-wsl.sh verify`.

## Local evidence

Environment inspected on 2026-08-18:

- VS Code `1.133.0`, commit `a5b500951314efd502d07465bd138dfbd714a960`
- WSL Angular Language Service `22.0.0-rc.0`
- Windows Angular Language Service `22.1.0`
- Git `2.43.0`
- Node.js `22.22.0`

Exact installed Angular client path:

```text
trusted Markdown enabledCommands: ["angular.openJsDocLink"]
openJsDocLinkCommand: vscode.Uri.parse(args.file)
openJsDocLinkCommand: vscode.workspace.openTextDocument(uri)
```

Both locally installed Angular extension versions retain the `Uri.parse(args.file)` sink.

Exact installed VS Code Git path:

```text
git URI query -> JSON.parse(uri.query) -> {path, ref}
readFile(uri) -> repository.buffer(ref, path)
buffer(ref, path) -> git show --textconv `${ref}:${relativePath}`
```

The local `sanitizeRef` equivalent only normalizes special internal refs such as `~` and `~<digit>`; it returns other values unchanged. A ref beginning `--output=` therefore remains a Git option.

## Source / control / sink

- Source: Markdown in project-controlled JSDoc, rendered by Angular Language Service.
- Missing control: `angular.openJsDocLink` accepts an object with arbitrary `file` string and uses `Uri.parse`, with no `file:` allowlist or `Uri.file` construction.
- Sink: VS Code Git provider parses the crafted query and invokes Git with attacker-controlled `ref` before `:<path>`.
- Impact: Git's legitimate `--output=<path>` option follows a tracked POSIX symlink and overwrites the disposable target outside the repository.
- Preconditions: trusted workspace, official Angular extension active, hover displayed, user click, Linux/WSL Git and knowledge of repository absolute path.

## Alternative URI providers reviewed

Local provider inventory was derived from installed VS Code/extension JavaScript registrations.

| Scheme/provider | Local behavior | Assessment |
| --- | --- | --- |
| `git:` (built in) | Read-only VS Code provider shells out to Git; crafted semantic `ref` becomes an option | Strongest universal local primitive; keep as primary PoC |
| `gitlens:` / `gitlens-virtual:` | Third-party GitLens read-only providers | Extra extension precondition; not stronger or suitable as primary evidence |
| JavaScript debugger virtual resources | Read-only, session-bound provider | Requires active debugger and opaque in-memory identifiers; no standalone impact established |
| Copilot preview/chat virtual resources | Read-only, extension-state-bound providers | Requires separate extension/state; no external write established |
| Angular virtual documents | Read-only in-memory providers | Demonstrates scheme confusion only; no stronger impact |
| `vscode-userdata:` / `vscode-remote:` core resources | Can expose/navigation-open local editor resources under applicable authority | No attacker-side exfiltration or write established from `openTextDocument` alone |
| `untitled:` and output/content schemes | Creates or reads editor-only virtual content | UI effect only; no stronger security consequence |

Conclusion: no second locally installed, broadly available scheme produced a more realistic one-click impact than built-in `git:`. A custom canary `TextDocumentContentProvider` can prove arbitrary provider dispatch, but requiring a helper extension weakens realism and is intentionally excluded from the minimal PoC.

## Confidence and remaining proof gap

Current assessment: **high confidence / reportable** for unrestricted provider dispatch and external-file overwrite. Static source-to-sink evidence uses exact installed product code; `prepare`/`direct` dynamically validates the Git/POSIX write primitive and marker-only startup-file consequence.

Only fresh-session manual proof gap is the UI gesture itself. Run `prepare`, perform the documented hover click, then `verify`; retain `.lab/verify.log` and terminal output as the fresh end-to-end receipt. A prior supplied validation transcript reports this full UI chain successfully, but it is not represented here as a new run.
