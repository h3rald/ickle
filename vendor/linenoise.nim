{.compile: "liblinenoise.c".}
{.push importc.}
const
  LINENOISE_H* = true
type
  LinenoiseCompletions* = object
    len*: csize
    cvec*: cstringArray
  linenoiseCompletionCallback* = proc (s: cstring, completions: ptr LinenoiseCompletions)

proc linenoiseSetCompletionCallback*(a2: ptr linenoiseCompletionCallback)
proc linenoiseAddCompletion*(a2: ptr LinenoiseCompletions; a3: cstring)
proc linenoise*(prompt: cstring): cstring
proc linenoiseHistoryAdd*(line: cstring): cint
proc linenoiseHistorySetMaxLen*(len: cint): cint
proc linenoiseHistoryGetMaxLen*(): cint
proc linenoiseHistorySave*(filename: cstring): cint
proc linenoiseHistoryLoad*(filename: cstring): cint
proc linenoiseHistoryFree*()
proc linenoiseHistory*(len: ptr cint): cstringArray
proc linenoiseColumns*(): cint
