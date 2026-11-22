# Tests

Run everything from the repository root:

```bash
./test/run.sh
```

The script runs:

- `model.test.js` — Node's built-in test runner (`node --test`), no package
  dependencies. It covers token/byte formatting, grouping boundaries,
  home-path shortening, URI escaping and JSON parsing.
- `omarchy plugin validate` on the repository (or `PLUGIN_DIR`, when set).
- `qmllint -I "$OMARCHY_PATH/shell"` on every QML component.

`fixtures/history-sample.json` is the fixed `sift history --json` envelope used
by the parser test.

The static Phase 2 UI is exercised live through the shell; see
`docs/ENVIRONMENT.md`.
