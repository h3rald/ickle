import
  tables,
  sequtils,
  strutils,
  readline,
  regex,
  os

import
  config,
  types,
  reader,
  printer,
  environment,
  core

var
  p: Printer


proc read*(prompt = prompt): Node =
  var line = readline(prompt)
  historyAdd(line)
  return line.readStr()

proc eval*(ast: Node, env: Env): Node

proc print*(n: Node) =
  echo p.prStr(n)

proc rep*(env: var Env) =
  print(eval(read(), env))

proc isMacroCall(ast: Node, env: Env): bool =
  if ast.kind == List and ast.seqVal[0].kind == Symbol:
    try:
      let f = env.get(ast.seqVal[0].keyval)
      if f.kind == Proc:
        return f.procVal.isMacro
      else:
        return false
    except UnknownSymbolError:
      return false
  return false

proc eval_ast(ast: Node, env: var Env): Node =
  dbg:
    echo "EVAL-AST: " & $ast
  case ast.kind:
    of Symbol:
      return env.get(ast)
    of List:
      var list = newSeq[Node]()
      for i in ast.seqVal:
        list.add eval(i, env)
      return newList(list)
    of Vector:
      var list = newSeq[Node]()
      for i in ast.seqVal:
        list.add eval(i, env)
      return newVector(list)
    of HashMap:
      var hash = initTable[string, Node]()
      for k, v in ast.hashVal.pairs:
        hash[k] = eval(v, env)
      return newHashMap(hash)
    else:
      return ast

### Special Forms

proc quasiquoteFun(ast: Node): Node =
  var list = newSeq[Node]()
  if not ast.isPair:
    list.add newSymbol("quote")
    list.add ast
    return newList(list)
  elif ast.seqVal[0].kind == Symbol and ast.seqVal[0].stringVal == "unquote":
    return ast.seqVal[1]
  elif ast.seqVal[0].isPair and ast.seqVal[0].seqVal[0].kind == Symbol and ast.seqVal[0].seqVal[0].stringVal == "splice-unquote":
    list.add newSymbol("concat")
    list.add ast.seqVal[0].seqVal[1]
    list.add quasiquoteFun(newList(ast.seqVal[1 .. ^1]))
    return newList(list)
  else:
    list.add newSymbol("cons")
    list.add quasiquoteFun(ast.seqVal[0])
    list.add quasiquoteFun(newList(ast.seqVal[1 .. ^1]))
    return newList(list)

proc printEnvFun(env: Env): Node =
  var p:Printer
  echo "Printing environment: $1" % env.name
  for k, v in env.data.pairs:
    echo "'$1'\t\t= $2" % [k, p.prStr(v)]
  return newNil()

proc defExclFun(ast: Node, env: var Env): Node =
  return env.set(ast.seqVal[1].keyval, eval(ast.seqVal[2], env))

proc letStarFun(ast: Node, env: var Env): Node =
  var nEnv = newEnv(outer = env)
  case ast.seqVal[1].kind
  of List, Vector:
    for i in countup(0, ast.seqVal[1].seqVal.high, 2):
      discard nEnv.set(ast.seqVal[1].seqVal[i].keyval, eval(ast.seqVal[1].seqVal[i+1], nEnv))
  else:
    incorrectValueError "let*: First argument is not a list or vector", ast.seqVal[1]
  env = nEnv
  return ast.seqVal[2]
  # Continue loop (TCO)

proc doFun(ast: Node, env: var Env): Node =
  discard eval_ast(newList(ast.seqVal[1 .. <ast.seqVal.high]), env)
  return ast.seqVal[ast.seqVal.high]
  # Continue loop (TCO)

proc ifFun(ast: Node, env: Env): Node =
  if eval(ast.seqVal[1], env).falsy:
    if ast.seqVal.len > 3:
      return ast.seqVal[3]
    else: return newNil()
  else: return ast.seqVal[2]
  # Continue loop (TCO)

proc fnStarFun(ast: Node, env: Env): Node =
  var fnEnv = env
  let fn = proc(args: varargs[Node]): Node =
    var list = newSeq[Node]()
    for arg in args:
      list.add(arg)
    var nEnv = newEnv(outer = fnEnv, binds = ast.seqVal[1], exprs = newList(list))
    return eval(ast.seqVal[2], nEnv)
  return newProc(fn, ast = ast.seqVal[2], params = ast.seqVal[1], env = env)

proc defMacroExclFun(ast: Node, env: var Env): Node =
  var fun = ast.seqVal[2].eval(env)
  fun.procVal.isMacro = true
  return env.set(ast.seqVal[1].keyval, fun)

proc macroExpandFun(ast: Node, env: Env): Node =
  result = ast
  while result.isMacroCall(env):
    let f = env.get(ast.seqVal[0].keyval)
    result = f.procVal.fun(ast.seqVal[1 .. ^1]).macroExpandFun(env)

proc tryFun(ast: Node, env: Env): Node =
  var cEnv = env
  if ast.seqVal[2].kind in {List, Vector} and ast.seqVal[2].seqVal[0].stringVal == "catch*":
    try:
      return eval(ast.seqVal[1], env)
    except LangException:
      let e = (ref LangException) getCurrentException()
      var nEnv = newEnv(outer = cEnv, binds = newList(ast.seqVal[2].seqVal[1]), exprs = e.value)
      return eval(ast.seqVal[2].seqVal[2], nEnv)
    except:
      let e = getCurrentException()
      var nEnv = newEnv(outer = cEnv, binds = newList(ast.seqVal[2].seqVal[1]), exprs = newList(newString(e.msg)))
      return eval(ast.seqVal[2].seqVal[2], nEnv)
  else:
    return eval(ast.seqVal[1], env)

###

proc eval(ast: Node, env: Env): Node =
  var ast = ast
  var env = env
  dbg:
    echo "EVAL: " & $ast
  template apply =
    let el = eval_ast(ast, env)
    let f = el.seqVal[0]
    case f.kind
    of Proc:
      ast = f.procVal.ast
      env = newEnv(outer = f.procVal.env, binds = f.procVal.params, exprs = newList(el.seqVal[1 .. ^1]))
    else:
      # Assuming NativeProc
      return f.nativeProcVal(el.seqVal[1 .. ^1])
  while true:
    if ast.kind != List: return ast.eval_ast(env)
    ast = macroExpandFun(ast, env)
    if ast.kind != List or ast.seqVal.len == 0: return ast
    case ast.seqVal[0].kind
    of Symbol:
      case ast.seqVal[0].stringVal
      of "print-env":   return printEnvFun(env)
      of "def!":        return defExclFun(ast, env)
      of "let*":        ast = letStarFun(ast, env)
      of "do":          ast = doFun(ast, env)
      of "if":          ast = ifFun(ast, env)
      of "fn*":         return fnStarFun(ast, env)
      of "defmacro!":   return defMacroExclFun(ast, env)
      of "macroexpand": return macroExpandFun(ast.seqVal[1], env)
      of "quote":       return ast.seqVal[1]
      of "quasiquote":  ast = quasiquoteFun(ast.seqVal[1])
      of "try*":        return tryFun(ast, env)
      else: apply()
    else: apply()

defun "eval", args:
  return eval(args[0], MAINENV)

defun "load-file", args:
  let f = args[0].stringVal
  let oldfile = file
  if not f.existsFile:
    incorrectValueError "load-file: File '$1' does not exist" % f, args[0]
  else:
    file = f
    try:
      result = eval(readStr(f.readFile), MAINENV)
    finally:
      file = oldfile

proc defnative*(s: string) =
  discard eval(readStr(s), MAINENV)

### Native Functions

defnative "(def! not (fn* (x) (if x false true)))"

#defnative "(def! load-file (fn* (f) (eval (read-string (str \"(do \" (slurp f) \")\")))))"

defnative "(defmacro! cond (fn* (& xs) (if (> (count xs) 0) (list 'if (first xs) (if (> (count xs) 1) (nth xs 1) (throw \"odd number of forms to cond\")) (cons 'cond (rest (rest xs)))))))"

defnative "(defmacro! or (fn* (& xs) (if (empty? xs) nil (if (= 1 (count xs)) (first xs) `(let* (or_FIXME ~(first xs)) (if or_FIXME or_FIXME (or ~@(rest xs))))))))"
