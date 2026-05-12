---
name: PR Reviewer
description: Run the PR reviewer agent whenever a pull request is created or updated.
engine: copilot
on:
  pull_request:
    types: [opened, synchronize, reopened, edited, ready_for_review]
permissions:
  contents: read
  pull-requests: write
tools:
  github:
    toolsets: [context, pull_requests]
safe-outputs:
  submit-pull-request-review:
    max: 1
  create-pull-request-review-comment:
    max: 20
  add-comment:
    max: 1
imports:
  - ../agents/pr-reviewer.agent.md
---

# PR Reviewer

Run the shared PR reviewer agent for pull requests when they are created or updated.
