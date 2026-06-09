---
name: create-pr
description: Commit, push, and create or amend a PR with repo conventions enforced. Trigger on "create pr", "create-pr", "land pr", "push this", "ship this".
allowed-tools: [Bash, Read, AskUserQuestion]
user_invocable: true
---

# Create PR

Commit, push, and create (or amend) a pull request.

## Repo Conventions

- **Commit flags:** Always use `-s` (sign-off) and `-S` (GPG sign)
- **Branch naming:** `builds-VERSION` (e.g., `builds-1.8.0`, `builds-1.6.5-1.7.2`)
- **Commit message:** `Add catalog entries for VERSION_LIST`
- **PR title:** matches commit message
- **PR body:** `# Changes:` header with bullet points per version

## Arguments

The user may pass a version string (e.g., `1.8.0`). If not provided, infer from the changes.

The skill auto-detects new PR vs amend mode from the current branch state.

## Step 1 — Pre-flight

### 1a. Clear staged files

```bash
git reset HEAD
```

### 1b. Verify GitHub auth

Discover the currently logged-in GitHub user:

```bash
gh auth status 2>&1
```

Extract the active account from the output. Store as `GH_USER`. If auth fails entirely, stop and tell the user to run `gh auth login`.

### 1c. Update main

```bash
git checkout main
git pull --ff-only origin main
```

If `git pull` fails, stop and report the error.

## Step 2 — Detect Mode

```bash
BRANCH=$(git branch --show-current)
```

**If `$BRANCH` is `main`** → new PR mode. Continue to Step 3.

**If `$BRANCH` is not `main`** → check for an open PR on this branch:

```bash
gh pr list --head "$BRANCH" --state open --json number,title,url
```

- **Open PR found** → amend mode (default). Show the user and ask to confirm via AskUserQuestion. User can override to add a separate commit if needed.
- **No open PR** → new PR mode on this existing branch. Skip Step 3.

**Amend mode principle:** When amending, rewrite the commit message, PR title, and PR body to cover the entire diff from main as if everything was done in one shot. Never reference "added later", "fixed after review", or incremental changes — the final message should read as a single coherent unit of work.

## Step 3 — Create Branch (new PR mode only)

Use the `builds-VERSION` naming convention:

```bash
git checkout -b builds-<version>
```

## Step 4 — Stage Files

Run `git status --short` to list all changed files.

Present files to the user via AskUserQuestion (multiSelect):
- **Suggested** — files changed in this conversation
- **Other changes** — additional files the user can opt-in to

After confirmation:

```bash
git add <file1> <file2> ...
```

## Step 5 — Commit

### 5a. Analyze the diff

In amend mode, analyze full PR diff:

```bash
git diff main...HEAD
```

In new PR mode, analyze staged changes:

```bash
git diff --cached
```

### 5b. Generate commit message

Write a commit message following repo conventions:
- **Subject line**: `Add catalog entries for VERSION_LIST` — under 72 chars
- **Body**: list of changes
- **End with**: `Co-Authored-By: Claude Code`

Show the commit message to the user for review before committing.

**New PR mode:**

```bash
git commit -s -S -m "$(cat <<'EOF'
Add catalog entries for VERSION_LIST

<body>

Co-Authored-By: Claude Code
EOF
)"
```

**Amend mode:**

```bash
git commit --amend -s -S -m "$(cat <<'EOF'
Add catalog entries for VERSION_LIST

<body covering ALL changes in the PR>

Co-Authored-By: Claude Code
EOF
)"
```

## Step 6 — Push

Detect fork vs upstream for push:

```bash
FETCH_URL=$(git remote get-url origin)
PUSH_URL=$(git remote get-url --push origin)
```

If FETCH_URL != PUSH_URL (fork), push to origin (which has fork as push URL).

**New PR mode:**

```bash
git push -u origin <branch>
```

**Amend mode:**

```bash
git push --force-with-lease
```

## Step 7 — Create or Update PR

If FETCH_URL != PUSH_URL (fork), extract upstream slug and fork owner for `--repo` and `--head` flags.

**New PR mode:**

```bash
gh pr create --repo redhat-openshift-builds/catalog --head <fork-user>:<branch> --title "Add catalog entries for VERSION_LIST" --body "$(cat <<'EOF'
# Changes:
- Add catalog entries for X.Y.Z

Co-Authored-By: Claude Code
EOF
)"
```

**Amend mode:**

Update title and body to reflect the current full diff:

```bash
PR_NUMBER=$(gh pr list --head "$(git branch --show-current)" --state open --json number --jq '.[0].number')
gh pr edit "$PR_NUMBER" --title "Add catalog entries for VERSION_LIST" --body "$(cat <<'EOF'
# Changes:
- Updated bullet points covering ALL changes from main

Co-Authored-By: Claude Code
EOF
)"
```

## Step 8 — Report

Print a summary:

> **PR landed!**
>
> - **URL:** <pr-url>
> - **Branch:** `<branch>`
> - **Commit:** `<short-sha>`
> - **Mode:** New PR / Amended
