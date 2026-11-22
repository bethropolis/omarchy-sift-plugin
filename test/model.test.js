const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
  .replace(/^\s*\.pragma\s+library\s*;?\s*$/m, "")

const Model = new Function(
  source + "\nreturn { formatTokens, formatBytes, groupLabel, displayPath, fileUri, parseHistory };"
)()

function localDate(year, month, day, hour, minute, second) {
  return new Date(year, month - 1, day, hour, minute || 0, second || 0)
}

test("formatTokens uses the documented boundaries", () => {
  assert.equal(Model.formatTokens(0), "0 tok")
  assert.equal(Model.formatTokens(842), "842 tok")
  assert.equal(Model.formatTokens(999), "999 tok")
  assert.equal(Model.formatTokens(1000), "1.0k tok")
  assert.equal(Model.formatTokens(58900), "58.9k tok")
  assert.equal(Model.formatTokens(999999), "1000.0k tok")
  assert.equal(Model.formatTokens(1000000), "1.0M tok")
  assert.equal(Model.formatTokens(1234567), "1.2M tok")
  assert.equal(Model.formatTokens("58940"), "58.9k tok")
  assert.equal(Model.formatTokens(-4), "0 tok")
  assert.equal(Model.formatTokens(NaN), "0 tok")
})

test("formatBytes uses 1024-based units", () => {
  assert.equal(Model.formatBytes(0), "0 B")
  assert.equal(Model.formatBytes(812), "812 B")
  assert.equal(Model.formatBytes(1023), "1023 B")
  assert.equal(Model.formatBytes(1024), "1 KB")
  assert.equal(Model.formatBytes(1536), "2 KB")
  assert.equal(Model.formatBytes(1048575), "1024 KB")
  assert.equal(Model.formatBytes(1048576), "1.0 MB")
  assert.equal(Model.formatBytes(1572864), "1.5 MB")
  assert.equal(Model.formatBytes(5555555), "5.3 MB")
  assert.equal(Model.formatBytes(-1), "0 B")
})

test("groupLabel distinguishes just now, today, yesterday and earlier", () => {
  const now = localDate(2026, 11, 22, 12, 0, 0)
  assert.equal(Model.groupLabel(new Date(now.getTime() - 9 * 60000 - 59000).toISOString(), now), "Just now")
  assert.equal(Model.groupLabel(new Date(now.getTime() - 10 * 60000).toISOString(), now), "Today")
  assert.equal(Model.groupLabel(localDate(2026, 11, 22, 1, 0).toISOString(), now), "Today")
  assert.equal(Model.groupLabel(localDate(2026, 11, 21, 23, 59).toISOString(), now), "Yesterday")
  assert.equal(Model.groupLabel(localDate(2026, 11, 20, 23, 59).toISOString(), now), "Earlier")
})

test("groupLabel handles local midnight boundaries", () => {
  const now = localDate(2026, 11, 22, 0, 20, 0)
  assert.equal(Model.groupLabel(localDate(2026, 11, 22, 0, 5).toISOString(), now), "Today")
  assert.equal(Model.groupLabel(localDate(2026, 11, 21, 23, 55).toISOString(), now), "Yesterday")
})

test("groupLabel compares calendar days across DST changes", () => {
  // Spring forward and fall back in the US; the local calendar day still
  // decides the label even though the elapsed time is 23 or 25 hours.
  assert.equal(
    Model.groupLabel(localDate(2026, 3, 8, 12, 0).toISOString(), localDate(2026, 3, 9, 12, 0)),
    "Yesterday"
  )
  assert.equal(
    Model.groupLabel(localDate(2026, 11, 1, 12, 0).toISOString(), localDate(2026, 11, 2, 12, 0)),
    "Yesterday"
  )
})

test("groupLabel is safe with invalid or future timestamps", () => {
  assert.equal(Model.groupLabel("not a date", localDate(2026, 11, 22, 12, 0)), "Earlier")
  const now = localDate(2026, 11, 22, 12, 0)
  assert.equal(Model.groupLabel(new Date(now.getTime() + 5 * 60000).toISOString(), now), "Just now")
  assert.equal(Model.groupLabel(new Date(now.getTime() + 11 * 3600000).toISOString(), now), "Today")
  assert.equal(Model.groupLabel(new Date(now.getTime() + 2 * 86400000).toISOString(), now), "Earlier")
})

test("displayPath shortens only a leading home directory", () => {
  const home = "/home/user"
  assert.equal(Model.displayPath("/home/user", home), "~")
  assert.equal(Model.displayPath("/home/user/Projects/sift", home), "~/Projects/sift")
  assert.equal(Model.displayPath("/home/user/", home), "~/")
  assert.equal(Model.displayPath("/home/user/Projects", "/home/user/"), "~/Projects")
  assert.equal(Model.displayPath("/home/other/Projects", home), "/home/other/Projects")
  assert.equal(Model.displayPath("/home/user/Projects", ""), "/home/user/Projects")
  assert.equal(Model.displayPath("/", home), "/")
  assert.equal(Model.displayPath("relative/path", home), "relative/path")
})

test("fileUri percent-encodes each path segment", () => {
  assert.equal(
    Model.fileUri("/home/user/Projects/sift/codebase.md"),
    "file:///home/user/Projects/sift/codebase.md"
  )
  assert.equal(
    Model.fileUri("/home/user/My Project/context #1 100%.md"),
    "file:///home/user/My%20Project/context%20%231%20100%25.md"
  )
  assert.equal(
    Model.fileUri("/home/user/café/日本.md"),
    "file:///home/user/caf%C3%A9/%E6%97%A5%E6%9C%AC.md"
  )
  assert.equal(Model.fileUri("/tmp/100% done?x=1&y=2"), "file:///tmp/100%25%20done%3Fx%3D1%26y%3D2")
  assert.equal(Model.fileUri("/"), "file:///")
})

test("parseHistory reads the fixture and drops unknown fields", () => {
  const text = fs.readFileSync(path.join(__dirname, "fixtures", "history-sample.json"), "utf8")
  const result = Model.parseHistory(text)
  assert.equal(result.warning, "")
  assert.equal(result.entries.length, 4)

  const first = result.entries[0]
  assert.equal(first.id, "20260101T120000Z-0001")
  assert.equal(first.name, "dummy-alpha")
  assert.equal(first.root, "/home/user/projects/dummy-alpha")
  assert.equal(first.file, "/home/user/.cache/sift/dumps/dummy-alpha-20260101-120000.md")
  assert.equal(first.bytes, 1024)
  assert.equal(first.tokens, 1000)
  assert.equal(first.files, 2)
  assert.equal(first.style, "markdown")
  assert.equal("extra" in first, false)

  const envelope = JSON.parse(text)
  envelope.extra = true
  envelope.entries[0].extra = true
  const noisy = Model.parseHistory(JSON.stringify(envelope))
  assert.equal(noisy.warning, "")
  assert.equal(noisy.entries.length, 4)
  assert.equal("extra" in noisy.entries[0], false)
})

test("parseHistory rejects unknown schemas and malformed input without throwing", () => {
  const unknown = Model.parseHistory('{"v":2,"entries":[]}')
  assert.deepEqual(unknown.entries, [])
  assert.match(unknown.warning, /version/i)

  const malformed = Model.parseHistory('{"v":1,"entries":[')
  assert.deepEqual(malformed.entries, [])
  assert.match(malformed.warning, /read/i)

  for (const input of ["", "   ", "null", "[]", '{"v":1,"entries":{}}']) {
    const result = Model.parseHistory(input)
    assert.deepEqual(result.entries, [])
    assert.notEqual(result.warning, "")
  }
})

test("parseHistory normalizes numbers and skips non-object entries", () => {
  const result = Model.parseHistory(JSON.stringify({
    v: 1,
    entries: [
      null,
      "nope",
      {
        id: 7,
        ts: 123,
        root: "/tmp/project",
        name: "project",
        file: "/tmp/dump.md",
        bytes: -10,
        tokens: "12.7",
        files: "3",
        style: 1
      }
    ]
  }))
  assert.equal(result.warning, "")
  assert.equal(result.entries.length, 1)
  assert.deepEqual(result.entries[0], {
    id: "7",
    ts: "123",
    cmd: "",
    root: "/tmp/project",
    name: "project",
    file: "/tmp/dump.md",
    bytes: 0,
    tokens: 13,
    files: 3,
    style: "1"
  })
})
