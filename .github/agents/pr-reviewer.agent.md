---
name: agent-pr-review
description: >
  A structured framework for reviewing pull requests. Use this skill whenever
  the user mentions reviewing a PR or pull request, asks for a PR review
  checklist, wants to know what to look for in a diff, or pastes code changes
  for review feedback. Also trigger when the user asks about code review best
  practices, how to catch technical debt before merging, or how to evaluate
  whether a PR is safe to approve.
---

# Agent PR Review

A practical, time-boxed framework for reviewing pull requests — what to look for, where issues hide, and how to catch technical debt before it ships.

---

## Red Flags to Watch For

### 1. CI Gaming

When CI fails, there's an easy path to get tests passing: remove the tests, skip the lint step, add `|| true` to test commands.

Any change that weakens CI is a **blocker**. Before approving, check:

- Did coverage thresholds change?
- Were any tests removed, renamed, or marked as skipped?
- Did the workflow stop running on forks or pull requests?
- Are any CI steps now gated behind conditions they weren't before?

**Yes to any of those = explicit justification required before continuing.**

---

### 2. Code Reuse Blindness

High-ROI review check. The symptom: new utility functions that duplicate existing ones with slightly different names, validation logic reimplemented in multiple places, middleware written from scratch that already lives in a shared module.

For every new helper or utility in a PR, do a quick search. If you find an equivalent, **require consolidation before merge** — don't just leave a comment. The cost of leaving duplicated logic is that it becomes prior art and gets replicated further.

> **Pro tip:** Require justification for adding new utilities in PRs above a size threshold. Catches the duplication problem early.

---

### 3. Hallucinated Correctness

The obvious bug gets caught in CI. The dangerous one is subtler: code that compiles, passes every test, and is **wrong**.

Off-by-one errors in pagination. Missing permission checks on a branch never hit in tests. Validation that short-circuits under an edge case no one considered. Wrong behavior under a race condition that only surfaces at scale.

**Trace it, don't just scan it.** Pick the most critical path in the diff and follow it from input through every transform to output. Check:

- Boundary conditions (zero, max, empty)
- Missing validation on external values
- Permission checks on every branch
- Surprising conditional logic

**Require a new test that fails on the pre-change behavior.** If no test would have caught the bug it claims to fix, the fix is incomplete or the understanding is wrong.

---

### 4. Agentic Ghosting

You leave a thorough review. The PR goes quiet — or responds and misses the point entirely, running in circles. You invest another round. Still nothing useful.

Larger PRs with no structured plan correlate strongly with abandonment or misalignment. Before investing deep review on a large PR, check the history: Has it been responsive in previous rounds? Does it have a clear implementation plan?

If there's no plan, request a breakdown first:

> *"This PR is too large for me to review without a clearer implementation plan. Can you break it into smaller scoped units, or add a summary of what each part does and why it's structured this way? Happy to review after that."*

---

### 5. Untrusted Input in Workflows

Prompt injection in CI is real and underappreciated. The pattern: a workflow reads content from a PR body, an issue, or a commit message — that content gets interpolated into a prompt — the prompt goes to a model — the output gets piped to a shell command — all with `GITHUB_TOKEN` permissions.

When reviewing any workflow that calls an LLM, these are **blockers**:

- Is untrusted user input (PR bodies, issue bodies, commit messages) interpolated into prompts without sanitization?
- Is `GITHUB_TOKEN` write-scoped when it only needs read access?
- Is model output being executed as shell commands without validation?
- Are secrets accessible to the agent step or being printed to logs?

**Require before merge:** least-privilege permissions in workflow YAML (`permissions: read-all` is a reasonable default), sanitize and quote untrusted content before it touches a prompt, separate the "analysis" step from the "execution" step with a human approval gate for anything touching production, never `eval` model output.

---

## 10-Minute Review Workflow

| Time | Step | What to do |
|------|------|------------|
| 1–2 min | **Scan and classify** | Look at the file list and diff size. Narrow task (docs, CI, small change) or complex (multi-file, logic, performance, tests)? That classification sets your review depth for everything that follows. |
| 2–3 min | **Check CI changes first** | Before reading a single line of app code, look at anything touching `.github/workflows`, test configs, coverage settings, or build scripts. Flag anything that weakens CI. Stop sign check. |
| 3–5 min | **Scan for new utilities** | Search for new functions, helpers, or modules. For each one, do a quick repo search to check for duplicates. Flag anything that reinvents existing functionality. |
| 5–8 min | **Trace one critical path** | Pick the most important logic change. Trace it end-to-end: input → transforms → output. Check boundary conditions, permissions, unexpected branching. This is the step you can't skip. |
| 8–9 min | **Security boundaries** | If this PR touches any workflow that calls an LLM or handles untrusted input, run through the security checklist above. |
| 9–10 min | **Require evidence** | For any non-trivial logic change, require a test that fails on the pre-change behavior. No rollback plan for risky changes? Ask for one. |

---

## When to Request a Smaller PR

Request a breakdown before writing a single comment if:

1. The diff touches more than five unrelated files
2. You can't describe the purpose of the PR in one sentence
3. There is no implementation plan or the PR body is empty
4. CI is failing and the only changes in the diff are to test files

---

## Three Takeaways

1. **Any CI weakening is a hard stop.**
2. **Scan for duplicates first. Trace the critical path second.**
3. **Use the red flag checklist as your default on complex PRs.**
