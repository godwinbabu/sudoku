---
name: codex-pr-review
description: >-
  Review a pull request with two reviewers, Claude and Codex (GPT-6.1), and loop
  until both agree there is nothing left to fix. Posts every review, reply and
  verdict on the PR and moves the pr-review/* labels. Use for "codex review PR 7",
  "review this PR with codex", or /codex-pr-review. Never merges.
user-invocable: true
---

# codex-pr-review

Two reviewers check the same PR, and a developer fixes what they find. The loop
ends when Codex says `VERDICT: ALIGNED`, the Claude review finds nothing to fix,
and the tests pass. Then the PR gets `pr-review/lgtm` and a human merges it.

## Roles

| Role | Who | Does |
|---|---|---|
| Codex Reviewer | Codex (GPT-6.1) | Reviews the PR each round |
| Claude Reviewer | A fresh Claude subagent | Reviews the PR each round; posts the final verdict |
| Claude Developer | You (this session) | Replies to each finding, fixes, tests, pushes, moves labels |

The Claude Reviewer is always a fresh subagent, so its review is not shaped by
the code the Claude Developer wrote.

## Hard rules

- **Never merge.** `pr-review/lgtm` is the only "ready" signal.
- **Everything goes on the PR** as a comment: reviews, replies, verdicts. Do not
  keep review files in the repo.
- **Line 1 of every comment is the role name, alone:** `Codex Reviewer`,
  `Claude Reviewer`, or `Claude Developer`.
- **Never claim a fix works without a passing test run** (`/run-tests`).
- Run `gh` and `codex` outside the sandbox. The sandbox blocks the keychain and
  the network these tools need.

## Labels

Use the same three labels as `gb-pr-review`. A PR has exactly one of them.

| Label | Color | Meaning |
|---|---|---|
| `pr-review/review-requested` | `FBCA04` | Waiting for a (re)review |
| `pr-review/changes-requested` | `D93F0B` | A reviewer found must-fix issues |
| `pr-review/lgtm` | `0E8A16` | Both reviewers agree, tests pass; a human may merge |

Create them once per repo (safe to repeat):

```sh
gh label create "pr-review/review-requested"  --force --color FBCA04 --description "Awaiting (re)review"
gh label create "pr-review/changes-requested" --force --color D93F0B --description "Reviewer found must-fix issues"
gh label create "pr-review/lgtm"              --force --color 0E8A16 --description "Reviewed + gate green; human may merge"
```

Change the label in one call, so the PR never has zero or two labels:

```sh
set_label() {  # set_label <PR> <state>
  local pr="$1" new="pr-review/$2" repo body
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
  body=$(gh pr view "$pr" --json labels \
    -q '{labels: ([.labels[].name | select(startswith("pr-review/")|not)] + ["'"$new"'"])}')
  gh api -X PUT "repos/$repo/issues/$pr/labels" --input - <<<"$body" >/dev/null
}
```

## The loop

Round 1 starts with `set_label <PR> review-requested`.

1. **Claude Reviewer reviews.** Start a fresh subagent that runs
   `/ponytail:ponytail-review` on the PR. Round 1 reviews the full diff. Later
   rounds review only the commits since the last round, plus a check that each
   earlier finding is really fixed in the code. Post the review.
2. **Codex Reviewer reviews.** Run Codex (see "Running Codex"). Post its answer
   unchanged, with a line that names the round and the commit it reviewed.
3. **Claude Developer replies.** For each finding from either reviewer, decide:
   agree (fix it) or disagree (give the concrete reason). Post one reply.
4. **Decide:**
   - Any must-fix left → `set_label <PR> changes-requested`. Fix each one, with
     a test that fails without the fix. Run `/run-tests`. Push.
     `set_label <PR> review-requested`. Go to step 1.
   - Codex says `VERDICT: ALIGNED` and the Claude Reviewer found no must-fix →
     run `/run-tests` on the full suite.
     - Fail → treat the failing tests as must-fix and continue as above.
     - Pass → `set_label <PR> lgtm`. The Claude Reviewer posts a one-line
       verdict that cites the passing test line. **Stop.**
5. **Stop and ask a human** (`changes-requested` + a `Claude Developer` comment
   that names the open point) when any of these happen:
   - 10 rounds are done.
   - The same disagreement comes back in 2 rounds in a row.
   - Fixing one finding brings back an earlier one.
   - A finding needs a product or security decision.

## Running Codex

Codex reads the repo and runs `git` itself, so send only a short prompt.
Use `codex exec`, not `codex review`: `codex review --base` does not accept a
custom prompt, so it cannot be asked for the verdict line.

1. Check out the PR branch. Write the prompt file to the scratchpad. It holds
   the review prompt (below), the round number, the base branch, the commit
   range to review, and the earlier findings that are still open.
2. Run it in the background (macOS has no `timeout`). Always feed stdin, or
   `codex exec` waits forever. `-s read-only` stops Codex from changing files:

   ```sh
   codex exec -m gpt-6.1-sol -c model_reasoning_effort="high" -s read-only \
     -C . -o "$SCRATCH/codex-rN.md" - < "$SCRATCH/prompt-rN.md"
   ```
3. If the log shows `timed out negotiating with the code-mode host` and no
   review, the Codex background server is out of date. Ask the user to run
   `codex app-server daemon restart` (it can stop their other Codex sessions).
4. If Codex fails or gives no answer within 15 minutes, retry once. After 3
   failures in one PR, continue with the Claude Reviewer only. Post a
   `Claude Developer` comment that says Codex was skipped and why.

Review prompt for Codex:

> You are a senior reviewer. Run `git diff <base>...HEAD` (or the given commit
> range) and read the changed files and their callers. Do not change any file.
> Review this pull request for bugs, data loss, missing tests for risky logic,
> and code that should not exist. Every finding needs a concrete case: this
> input or situation gives this wrong result. Mark each finding MUST-FIX or NIT.
> For earlier findings, say RESOLVED or not, based on the code, not the reply.
> End with exactly one line: `VERDICT: ALIGNED` (no must-fix left) or
> `VERDICT: NOT ALIGNED`.

## Common mistakes

- Running `codex exec` without stdin: it hangs.
- Posting a comment whose first line is not the role name.
- Letting the Claude Developer review its own fix: use a fresh subagent.
- Treating a reply as a fix: check the code.
- Re-reviewing the whole PR after round 1: review only the new commits.
