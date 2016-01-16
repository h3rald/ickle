import
  strutils,
  ../vendor/lwre


type
  Regex* = object
    data: PRE
    atStart: bool
    atEnd: bool
    caseInsensitive: bool

const
  REGEX_MACROS = [
    ["\\d", "0-9"],
    ["\\D", "^0-9"],
    ["\\s", " \9-\13"],
    ["\\n", "\10\13"],
    ["\\w", "a-zA-Z0-9_"],
    ["\\a", "a-zA-Z"],
  ]

proc re*(s: string): Regex =
  var rStart = 0
  var rEnd = s.len-1
  result.atStart = false
  result.atEnd = false
  result.caseInsensitive = false
  if s.startsWith("\\i"):
    rStart.inc(2)
    result.caseInsensitive = true
  if s.startsWith("^"):
    rStart.inc
    result.atStart = true
  if s.endsWith("$"):
    result.atEnd = true
    rEnd.dec
  var regex = s.substr(rStart, rEnd)
  if not result.atStart:
    regex = ".*?" & regex
  for i in REGEX_MACROS:
    regex = regex.replace(i[0], i[1])
  result.data = re_new(regex)


proc prepareString(s: string, pattern: Regex, start = 0): string =
  result = s & " " # Add an extra character otherwise it doesn't seem to work
  if pattern.caseInsensitive:
    result = result.toLower()
  result = result.substr(start, result.len-1)


proc checkEndMatch(s: string, pattern: Regex, res: int): bool =
  if pattern.atEnd:
    if res == s.len-1:
      if res >= 0:
        return true
  elif res >= 0:
    return true
  else:
    return false

proc match*(str: string, pattern: Regex, start = 0): bool =
  let s = prepareString(str, pattern, start)
  let res = re_match(pattern.data, s.substr(start,s.len-1))
  return checkEndMatch(s, pattern, res)

proc match*(str: string, pattern: Regex, matches: var openArray[string], start = 0): bool =
  let s = prepareString(str, pattern, start)
  let res = re_match(pattern.data, s)
  if pattern.data.nmatches >= 2:
    var rMatches: cstringArray = pattern.data.matches
    var rMatch: string
    for i in 0..(pattern.data.nmatches/2).int-1:
      rMatch = $rMatches[2*i]
      let start = (str & " ").toLower().find(rMatch.toLower())
      matches[i] = $str.substr(start, start + rMatches[2*i].len - rMatches[2*i+1].len-1)
  return checkEndMatch(s, pattern, res)


when isMainModule:
  import unittest

  suite "Regex matching":

    test "Simple matching":
      check:
        "This is a test".match(re"is a")
        "This is a test".match(re"^Th.*")
        "This is a test".match(re"test$")
        "AAA BBB CCC".match(re"\ibbb")

    test "Capture submatches":
      var
        matches: array[0..1, string]
        res: bool
      res ="AAA BBBB CCC".match(re"\i({[b]+})", matches)
      check:
        res == true
        matches == ["BBBB", nil]
      res = "192.168.1.1".match(re"({[0-9][0-9][0-9]}).({[0-9]+})", matches)
      check:
        res == true
        matches == ["192", "168"]

    test "Macros":
      var
        matches: array[0..1, string]
        res: bool
      res = "192.168.1.1".match(re"({[\d]+})\.({[\d]+})", matches)
      check:
        res == true
        matches == ["192", "168"]
      check:
        "   This is a test".match(re"^[\s]+This")
      res = "1 2 3 4".match(re"^({[\d]+})", matches)
      check:
        res == true
        matches == ["1", "168"]
