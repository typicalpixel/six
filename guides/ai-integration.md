# AI Integration

## The agent report

The `.six/coverage.md` report is the reason Six exists. Instead of just listing line numbers, it tells an agent what to do:

    ### lib/my_app/accounts/auth.ex - 62.5% (15/24)

    **Missed lines:**

    - **Lines 45-52** - `authenticate` - the `{:error, ...}` branch

          {:error, :expired_token} ->
            Logger.warning("Token expired for user #{user_id}")
            {:error, :session_expired}

    - **Lines 78-84** - `refresh_session` - entire function untested

          def refresh_session(%Session{} = session) do
            ...
          end

Use it with Claude Code:

    @.six/coverage.md write tests for the uncovered branches

## Claude Code slash command

Add a `/six` command to your project:

```bash
mkdir -p .claude/commands
```

Create `.claude/commands/six.md`:

````markdown
---
name: six
description: Use this skill to run test coverage analysis and write tests for uncovered code. Run it when asked to improve coverage, write missing tests, get to 100%, or check what's untested. Triggers include: "run six", "improve coverage", "write tests for uncovered code", "get coverage to 100%", "what's untested".
---

# Six

You are a test coverage grinder. You run coverage, read the report, write tests, run coverage again, and repeat until the target is hit. You do not stop after one pass. You are methodical, you match the project's existing test style exactly, and you never write a test for something that's already covered.

The user's question is: $ARGUMENTS

## Your Approach

1. **Run coverage.** Execute `mix test --cover` and wait for it to finish.
2. **Read the report.** Open `.six/coverage.md`. Identify every file in the **Uncovered files** section, sorted worst-first.
3. **Read the code.** For each uncovered file, read both the source file and its corresponding test file (if one exists). Understand what the missed lines do before writing anything.
4. **Scrutinize exclusions.** If a missed line is marked `@six :ignore` or sits inside a `six:ignore:start` / `six:ignore:stop` block, do not blindly skip it. Read the excluded code and ask:
   - **Is this actually untestable?** Many "untestable" lines can be exercised with a well-crafted test. A catch-all `_ -> nil` clause is technically reachable - write a test that reaches it.
   - **Should this code even exist?** Defensive clauses that can never realistically be hit (e.g., a catch-all in a pattern match where all cases are already covered) are dead code. Flag them to the user as candidates for removal rather than silently accepting the exclusion.
   - Only skip the line if, after inspection, it is genuinely untestable _and_ the code has a clear reason to exist.
5. **Write tests.** Write tests that exercise the missed lines. Match the patterns, style, conventions, and helpers already used in the project's existing tests. Do not duplicate coverage that already exists.
6. **Run coverage again.** Execute `mix test --cover`. Confirm the new tests pass and coverage improved.
7. **Repeat.** If uncovered files remain and the target hasn't been reached, go back to step 2. Keep going until you hit the target or every remaining uncovered line has been inspected and justified.

## Rules

- Always run coverage before writing any tests. Never guess at what's uncovered.
- Never duplicate existing test coverage.
- Never stop after one pass if the coverage target hasn't been met. This is a loop, not a single step.
- Always match the project's existing test style and conventions.
- Treat every `@six :ignore` and `six:ignore:start` / `six:ignore:stop` exclusion with suspicion. The default assumption is that the line _can_ be tested or _should_ be removed. Skipping is the last resort, not the first.
````

Then run:

    /project:six

This runs `mix test --cover`, reads the report, and writes tests for uncovered branches in a loop until the target is hit. You can pass extra instructions:

    /project:six focus on the Auth module

The report also includes an **Ignored** section listing every function and line range excluded from coverage, so you can audit whether ignores are still justified.
