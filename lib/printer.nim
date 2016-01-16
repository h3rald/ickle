import
  config,
  types,
  strutils,
  tables

proc prStr*(p: Printer, form: Node, printReadably = true): string =
  result = ""
  case form.kind:
    of List, Vector:
      let start = if form.kind == List: "(" else: "["
      let finish = if form.kind == List: ")" else: "]"
      result &= start
      var count = 0
      for i in form.seqVal:
        count.inc
        result &= p.prStr(i, printReadably)
        if count < form.seqVal.len:
          result &= " "
      result &= finish
    of HashMap:
      result &= "{"
      var count = 0
      for key, value in form.hashVal.pairs:
        count.inc
        if key[0] == '\xff':
          result &= p.prStr(newKeyword(key[1 .. key.high]), printReadably)
        else:
          result &= p.prStr(newString(key), printReadably)
        result &= " "
        result &= p.prStr(value, printReadably)
        if count < form.hashVal.len:
          result &= " "
      result &= "}"
    of Int:
      result = $form.intVal
    of Bool:
      if form.boolVal:
        result = "true"
      else:
        result = "false"
    of Keyword:
      result = form.keyrep
    of Nil:
      result = "nil"
    of String:
      if printReadably:
        result = "\"" & form.stringVal.replace("\\", "\\\\").replace("\n", "\\n").replace("\"", "\\\"").replace("\r", "\\r") & "\""
      else:
        result = form.stringVal
    of Symbol:
      result = form.stringVal
    of Atom:
      result = "(atom " & p.prStr(form.atomVal) & ")"
    of NativeProc:
      result = "#<native-function>"
    of Proc:
      result = "#<function>"

proc `$`*(n: Node): string =
  var p:Printer
  return p.prStr(n)

proc `$~`*(n: Node): string =
  var p:Printer
  return p.prStr(n, false)
