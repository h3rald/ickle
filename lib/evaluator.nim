import
  critbits,
  sequtils,
  strutils,
  readline,
  regex

import
  config,
  types,
  reader,
  printer,
  environment

var
  p: Printer


proc read*(prompt = prompt): Node =
  var line = readline(prompt)
  historyAdd(line)
  return line.readStr()

proc eval*(ast: Node, env: Env): Node {.discardable.}

proc print*(n: Node) =
  echo p.prStr(n)

proc rep*(env: var Env) =
  print(eval(read(), env))

proc isMacroCall(ast: Node, env: Env): bool =
  if ast.kind == List and ast.seqVal.len > 0 and ast.seqVal[0].kind == Symbol:
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
    echo "EVAL-AST: $1 -- $2" % [$ast, ast.kindname]
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
      var hash: NodeMap
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
  echo "Printing environment: $1"
  for k, v in env.data.pairs:
    echo "'$1'\t\t= $2" % [k, $v]
  return newNil()

proc lambdaFun(ast: Node, env: Env): Node =
  var fnEnv = env
  let fn = proc(args: varargs[Node]): Node =
    var list = newSeq[Node]()
    for arg in args:
      list.add(arg)
    var nEnv = newEnv(outer = fnEnv, binds = ast.seqVal[1], exprs = newList(list))
    return eval(ast.seqVal[2], nEnv)
  return newProc(fn, ast = ast.seqVal[2], params = ast.seqVal[1], env = env)

proc defineFun(ast: Node, env: var Env): Node =
  var first = ast.seqVal[1]
  let second = ast.seqVal[2]
  var value: Node
  if first.kind == List:
    # Assuming Function name with arguments: (define (plus a b) (+ a b))
    let fn = newList(newNil(), newList(first.seqVal[1 .. ^1]), second)
    # Reset identifier to first item of the first list  
    first = first.seqVal[0]
    value = lambdaFun(fn, env)
  elif first.kind == Pair:
    # Assuming Function name with rest argument: (define (plus . x) (+ (car x) (cdr x)))
    let fn = newList(newNil(), first.seqVal[1], second)
    first = first.seqVal[0]
    value = lambdaFun(fn, env)
  else:
    value = eval(second, env)
  return env.set(first.keyval, value)

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

proc letFun(ast: Node, env: var Env): Node =
  var nEnv = newEnv(outer = env)
  var syms = newSeq[string]()
  var bodies = newSeq[Node]()
  case ast.seqVal[1].kind
  of List, Vector:
    for i in countup(0, ast.seqVal[1].seqVal.high, 2):
      syms.add ast.seqVal[1].seqVal[i].keyval
      bodies.add eval(ast.seqVal[1].seqVal[i+1], nEnv)
    for i in 0..ast.seqVal[1].seqVal.high:
      discard nEnv.set(syms[i], bodies[i])
  else:
    incorrectValueError "let: First argument is not a list or vector", ast.seqVal[1]
  env = nEnv
  return ast.seqVal[2]
  # Continue loop (TCO)


proc beginFun(ast: Node, env: var Env): Node =
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

proc andFun(ast: Node, env: Env): Node =
  if ast.seqVal.len == 1:
    return newBool(true)
  else:
    var expr: Node
    for i in 1..ast.seqVal.high:
      result = eval(ast.seqVal[i], env)
      if result == newBool(false):
        return newBool(false)

proc orFun(ast: Node, env: Env): Node =
  if ast.seqVal.len == 1:
    return newBool(false)
  else:
    var expr: Node
    for i in 1..ast.seqVal.high:
      result = eval(ast.seqVal[i], env)
      if result != newBool(false):
        return result
    return newBool(false)

proc condFun(ast: Node, env: Env): Node =
  let f = newBool(false)
  for i in 1..ast.seqVal.high:
    if i == ast.seqVal.high:
      if ast.seqVal[i].seqVal[0].kind == Symbol and ast.seqVal[i].seqVal[0].keyval == "else":
        # Execute else clause
        return ast.seqVal[i].seqVal[1]
    else:
      if eval(ast.seqVal[i].seqVal[0], env) != f:
        return ast.seqVal[i].seqVal[1]
  return newNil()

###

proc eval(ast: Node, env: Env): Node =
  var ast = ast
  var env = env
  dbg:
    echo "EVAL: $1 -- $2" % [$ast, ast.kindname]
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
      of "define":      return defineFun(ast, env)
      of "let*":        ast = letStarFun(ast, env)
      of "let":         ast = letFun(ast, env)
      of "begin":       ast = beginFun(ast, env)
      of "if":          ast = ifFun(ast, env)
      of "lambda":      return lambdaFun(ast, env)
      of "defmacro!":   return defMacroExclFun(ast, env)
      of "macroexpand": return macroExpandFun(ast.seqVal[1], env)
      of "quote":       return ast.seqVal[1]
      of "quasiquote":  ast = quasiquoteFun(ast.seqVal[1])
      of "try*":        return tryFun(ast, env)
      of "and":         ast = andFun(ast, env)
      of "or":          ast = orFun(ast, env)
      of "cond":        ast = condFun(ast, env)
      else: apply()
    else: apply()

proc evalText*(s: string): Node {.discardable.}=
  var r = Reader(tokens: s.tokenizer(), pos: 0)
  if r.tokens.len == 0:
    noTokensError()
  while r.pos < r.tokens.len:
    result = eval(r.readForm(), MAINENV)
    r.next()

#proc defnative*(s: string) =
#  eval(readStr(s), MAINENV)

### Native Functions

#defnative "(define not (lambda (x) (if x false true)))"

#defnative "(defmacro! cond (lambda (& xs) (if (> (count xs) 0) (list 'if (car xs) (if (> (count xs) 1) (nth xs 1) (throw \"odd number of forms to cond\")) (cons 'cond (cdr (cdr xs)))))))"

#defnative "(defmacro! or (lambda (& xs) (if (empty? xs) nil (if (= 1 (count xs)) (car xs) `(let* (or_FIXME ~(car xs)) (if or_FIXME or_FIXME (or ~@(cdr xs))))))))"
