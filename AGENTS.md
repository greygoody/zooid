# AGENTS.md

## Shared agent invariants

These rules are a common floor for agentic work. Repository-specific rules in this file, and more-specific nested `AGENTS.md` files, take precedence where they genuinely narrow the work.

1. **Repository authority**
   - Treat current repository state, repository-local instructions, and explicitly accepted durable tasks/decisions as authoritative.
   - Chat history, memory, old branches, old PRs, and prior agent output are evidence, not authority.

2. **Establish fresh coordinates**
   - Before changing anything, determine the current branch/base, relevant task or PR, working-tree state when applicable, and applicable instructions.
   - Never assume previously observed state is still current.
   - Do not overwrite unrelated or user-owned changes.

3. **Bound authority and effects**
   - Distinguish exploration, proposed work, and authorized mutation.
   - Do not create durable tasks, schemas, APIs, infrastructure, cross-repository dependencies, or external effects merely because they seem useful.
   - Technical access does not imply authority.

4. **Keep work bounded**
   - Solve the smallest coherent problem that satisfies the current objective.
   - Do not silently widen scope or couple repositories that own separate concerns.
   - Prefer existing repository, platform, language, and tooling mechanisms over new abstractions.

5. **Prove claims**
   - A claimed behavior or effect requires relevant executable evidence.
   - Qualification must identify the exact code/state tested and include important failure paths, not only the happy path.
   - Do not describe unverified work as complete.

6. **Requalify after change**
   - Evidence becomes stale when relevant inputs, base, dependencies, environment, or authority change.
   - Before promotion or merge, verify the candidate against the current authoritative state.

7. **Close the loop**
   - Completion means the intended effect is verified and durable state reflects reality.
   - Reconcile or close superseded PRs, branches, issues, temporary worktrees, documentation, and other residue when they are part of the work.
   - Leave an explicit blocker or next durable owner when closure is not possible.

8. **Stop at genuine uncertainty**
   - Do not turn unresolved design questions into implementation by momentum.
   - Surface the uncertainty and preserve the evidence needed for the next decision.

### Development method

For ordinary software-development workflow, use the current maintained repository/environment-provided method rather than inventing another general methodology. When available and not superseded by repository-specific instructions, prefer the current `mattpocock/skills` workflow and `/ask-matt`.

Repository-specific architecture, commands, qualification procedures, ownership boundaries, and operational rules belong in repository-local instructions.
