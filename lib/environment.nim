import
  tables,
  strutils,
  sequtils

import
  config,
  types,
  printer

proc newEnv*(outer: Env = nil, binds, exprs: Node = newNil()): Env =
  result = Env(outer: outer, data: initTable[string, Node]())
  if binds.kind in {List, Vector}:
    for i, b in binds.seqVal:
      if b.stringVal == "&":
        var list: Node
        if exprs.seqVal.len == 0:
          list = newList(exprs.seqVal)
        else:
          list = newList(exprs.seqVal[i .. ^1])
        result.data.setKey(binds.seqVal[i+1].stringVal, list)
        break
      else:
        result.data.setKey(b.stringVal,  exprs.seqVal[i])

proc set*(env: Env, sym: string, n: Node): Node {.discardable.} =
  discard $n # TODO investigate why this makes evalText work!
  dbg:
    echo "ENV SET: $1 = $2" % [sym, $n]
  env.data.setKey(sym, n)
  return n

proc lookup*(env: Env, key: string): Env =
  if env.data.hasKey(key):
    return env
  if not env.outer.isNil:
    return env.outer.lookup(key)

proc get*(env: Env, sym: string): Node =
  let res = env.lookup(sym)
  if not res.isNil:
    return res.data[sym]
  else:
    raise newException(UnknownSymbolError, "'$1' not found" % sym)

proc get*(env: Env, sym: Node): Node =
  let res = env.lookup(sym.keyval)
  if not res.isNil:
    return res.data[sym.keyval]
  else:
    raise newException(UnknownSymbolError, "'$1' not found $2" % [sym.keyval, printPosition(sym)])

var MAINENV* = newEnv()

proc defineFunction(sym: string, p: NodeProc) =
  discard MAINENV.set(sym, newNativeProc(p))

proc defconst*(sym: string, n: Node) =
  discard MAINENV.set(sym, n)

template defun*(s: string, args: expr, body: stmt): stmt {.immediate.} =
  defineFunction(s) do (args: varargs[Node]) -> Node:
    body
