{.compile: "liblwre.c".}
type
  RE_Insn* = object

type
  Jmp_Buf* {.importc: "jmp_buf", header: "<setjmp.h>".} = distinct pointer
  RE_Compiled* = object
    size*: cint
    first*: ptr RE_Insn
    last*: ptr RE_Insn
  RE* = object
    expression*: cstring
    position*: cstring
    error_env*: Jmp_Buf
    error_code*: cint
    error_message*: cstring
    code*: RE_Compiled
    matches*: cstringArray
    nmatches*: cint
  PRE* = ptr RE

const
  RE_ERROR_NONE* = 0
  RE_ERROR_NOMATCH* = - 1
  RE_ERROR_NOMEM* = - 2
  RE_ERROR_CHARSET* = - 3
  RE_ERROR_SUBEXP* = - 4
  RE_ERROR_SUBMATCH* = - 5
  RE_ERROR_ENGINE* = - 6

{.push importc.}
proc re_new*(expression: cstring): PRE
proc re_match*(re: PRE; input: cstring): cint
proc re_release*(re: PRE)
proc re_reset*(re: PRE; expression: cstring)
proc re_free*(re: PRE)
proc re_escape*(string: cstring; liberal: cint): cstring
{.pop.}
