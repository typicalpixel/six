# Reading the Output

The summary table has five columns:

| Column | Meaning |
|---|---|
| **COV** | Coverage percentage for the file |
| **FILE** | Path relative to the project root |
| **LINES** | Total lines in the file |
| **RELEVANT** | Lines Six considers coverable (after filtering out boilerplate) |
| **MISSED** | Relevant lines with zero executions |

Rows are sorted worst-first so the files that need attention are at the top. Only files with missed lines get a row; fully covered files are collapsed into a single `N files fully covered (not shown)` line above the total.

## Colors

- Green means coverage is at or above the threshold (default 90%).
- Red means coverage is below the threshold.
