.pragma library

// Pure formatting and parsing helpers for the sift dumps panel.
//
// Keep this file free of QML imports, filesystem access, globals and
// Date.now(): callers pass `now` explicitly. The Node tests load this file
// after stripping the QML pragma line.

var MINUTE_MS = 60000
var TEN_MINUTES_MS = 10 * MINUTE_MS
var KIB = 1024
var MIB = 1024 * KIB

function toNumber(value) {
  var n = Number(value)
  return isFinite(n) && n > 0 ? n : 0
}

function toText(value) {
  return value === undefined || value === null ? "" : String(value)
}

function toDate(value) {
  if (Object.prototype.toString.call(value) === "[object Date]") return value
  if (typeof value === "number" || typeof value === "string") return new Date(value)
  return null
}

function sameLocalDay(a, b) {
  return a.getFullYear() === b.getFullYear()
    && a.getMonth() === b.getMonth()
    && a.getDate() === b.getDate()
}

function formatTokens(n) {
  var value = toNumber(n)
  if (value < 1000) return Math.round(value) + " tok"
  if (value < 1000000) return (value / 1000).toFixed(1) + "k tok"
  return (value / 1000000).toFixed(1) + "M tok"
}

function formatBytes(n) {
  var value = toNumber(n)
  if (value < KIB) return Math.round(value) + " B"
  if (value < MIB) return Math.round(value / KIB) + " KB"
  return (value / MIB).toFixed(1) + " MB"
}

// Local calendar grouping, so a DST change does not turn a 23-hour-old dump
// into "Earlier" while its calendar day is still yesterday.
function groupLabel(ts, now) {
  var when = toDate(ts)
  var current = toDate(now)
  if (!when || !current
      || isNaN(when.getTime()) || isNaN(current.getTime())) return "Earlier"

  var age = current.getTime() - when.getTime()
  if (age < TEN_MINUTES_MS && age > -TEN_MINUTES_MS) return "Just now"
  if (sameLocalDay(when, current)) return "Today"

  var yesterday = new Date(current.getFullYear(), current.getMonth(), current.getDate() - 1)
  if (sameLocalDay(when, yesterday)) return "Yesterday"
  return "Earlier"
}

function displayPath(root, home) {
  var path = toText(root)
  var base = toText(home)
  if (base === "") return path
  while (base.length > 1 && base.charAt(base.length - 1) === "/") {
    base = base.slice(0, -1)
  }
  if (path === base) return "~"
  if (path.indexOf(base + "/") === 0) return "~" + path.slice(base.length)
  return path
}

// Absolute path to a file:// URI. Each segment is encoded separately so the
// separators stay literal while spaces, #, % and non-ASCII are escaped.
function fileUri(path) {
  var value = toText(path)
  var parts = value.split("/")
  var encoded = []
  for (var i = 0; i < parts.length; i++) {
    encoded.push(encodeURIComponent(parts[i]))
  }
  return "file://" + encoded.join("/")
}

function historyNumber(value) {
  var n = Number(value)
  return isFinite(n) && n > 0 ? Math.round(n) : 0
}

function parseHistory(text) {
  var result = { entries: [], warning: "" }
  if (typeof text !== "string" || text.trim() === "") {
    result.warning = "sift history returned no data."
    return result
  }

  var envelope
  try {
    envelope = JSON.parse(text)
  } catch (e) {
    result.warning = "Could not read sift history."
    return result
  }

  if (!envelope || typeof envelope !== "object" || Array.isArray(envelope)) {
    result.warning = "Could not read sift history."
    return result
  }
  if (envelope.v !== 1) {
    result.warning = "Unsupported sift history version: " + toText(envelope.v)
    return result
  }
  if (!Array.isArray(envelope.entries)) {
    result.warning = "sift history returned no entries."
    return result
  }

  for (var i = 0; i < envelope.entries.length; i++) {
    var item = envelope.entries[i]
    if (!item || typeof item !== "object" || Array.isArray(item)) continue
    result.entries.push({
      id: toText(item.id),
      ts: toText(item.ts),
      cmd: toText(item.cmd),
      root: toText(item.root),
      name: toText(item.name),
      file: toText(item.file),
      bytes: historyNumber(item.bytes),
      tokens: historyNumber(item.tokens),
      files: historyNumber(item.files),
      style: toText(item.style)
    })
  }
  return result
}
