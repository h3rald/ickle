import
  strutils,
  ../vendor/linenoise

proc completionCallback*(str: cstring, completions: ptr LinenoiseCompletions) =
  let symbols = newSeq[string](0) # TODO populate with completion targets
  var words = ($str).split(" ")
  var w = if words.len > 0: words.pop else: ""
  var sep = ""
  if words.len > 0:
    sep = " "
  for s in symbols:
    if startsWith(s, w):
      linenoiseAddCompletion completions, words.join(" ") & sep & s

proc readline*(prompt: string): string =
  let res = linenoise(prompt)
  if res != nil:
    return $res
  else:
    quit("Exiting.")

proc historyAdd*(line: string) =
  discard linenoiseHistoryAdd(line)
