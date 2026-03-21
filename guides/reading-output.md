# Reading the Output

The summary table has five columns:

| Column | Meaning |
|---|---|
| **COV** | Coverage percentage for the file |
| **FILE** | Path relative to the project root |
| **LINES** | Total lines in the file |
| **RELEVANT** | Lines Six considers coverable (after filtering out boilerplate) |
| **MISSED** | Relevant lines with zero executions |

Rows are sorted worst-first so the files that need attention are at the top.

## Colors

- **Green** — coverage is at or above the threshold (default 90%)
- **Red** — coverage is below the threshold
- **Yellow** — the file has 0 relevant lines, meaning every executable line was filtered out (all `defmodule`, `use`, `alias`, `end`, etc.). There is nothing to cover, so Six cannot score it. This is normal for files that are purely structural, like a module that only defines a struct or delegates.
