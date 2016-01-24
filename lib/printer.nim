import
  config,
  types,
  strutils,
  critbits

proc prStr*(p: Printer, form: Node, printReadably = true): string =
  result = ""
  case form.kind:
    of List, Vector, Pair:
      let start = if form.kind == Vector: "[" else: "("
      let finish = if form.kind == Vector: "]" else: ")"
      result &= start
      let els = form.seqVal
      for i in 0.countup(els.high): 
        let res = p.prStr(els[i], printReadably)
        if els[i].kind == Pair and i == els.high:
          # Pair in last position -> do not print surrounding parens
          result &= res[1 .. ^2]
        else:
          result &= p.prStr(els[i], printReadably)
        if i < els.high:
          if form.kind == Pair:
            result &= " . "
          else:
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
        result = "#t"
      else:
        result = "#f"
    of Keyword:
      result = form.keyrep
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
