# Global working agreements (personal)

## Implementation

- Clone throwaway/agentic git repos under `~/projects/mystuff/agents/<repo>`,
  never under `/tmp` (macOS tmp_cleaner deletes `/tmp` entries idle about 3
  days). The gitconfig includeIf on `~/projects/mystuff/` sets the personal
  author email there; `/tmp` clones silently use the wrong work email.
- `agents/` is janitor-managed (agents-gc): name disposable build caches with
  a `-cache` suffix. After a branch passes a milestone (review, freeze), push
  it to the backup bare repo `~/projects/mystuff/agents/.backups/<repo>.git`
  (create with `git init --bare` on first use) so unpushed commits never live
  in exactly one `.git`.
