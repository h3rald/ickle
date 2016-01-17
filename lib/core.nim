import
  sequtils,
  strutils,
  tables,
  times,
  readline

import
  config,
  types,
  reader,
  printer,
  environment

### Constants

defconst "*host-language*", newString("nim")

### Functions working with all types

defun "=", args:
  return newBool(args[0] == args[1])

defun "throw", args:
  raise (ref LangException)(value: newList(args))

defun "with-meta", args:
  new(result)
  result[] = args[0][]
  result.meta = args[1]

defun "meta", args:
  if args[0].meta.isNil:
    return newNil()
  else:
    return args[0].meta

defun "deref", args:
  return args[0].atomVal

defun "time-ms", args:
  return newInt(int(epochTime() * 1000))

defun "readline", args:
  if args.len > 0:
    var line = readline(args[0].stringVal)
    historyAdd(line)
    return newString(line)
  else:
    var line = readline(prompt)
    historyAdd(line)
    return newString(line)

### Constructors

defun "atom", args:
  return newAtom(args[0])

defun "symbol", args:
  return newSymbol(args[0].stringVal)

defun "keyword", args:
  if args[0].kind == Keyword:
    return args[0]
  else:
    return newKeyword(args[0].stringVal)

defun "list", args:
  var list = newSeq[Node]()
  for a in args:
    list.add(a)
  return newList(list)

defun "vector", args:
  var list = newSeq[Node]()
  for a in args:
    list.add(a)
  return newVector(list)

defun "hash-map", args:
  var hash = initTable[string, Node]()
  for i in countup(0, args.high, 2):
    if args[i].kind == Keyword:
      hash[args[i].keyval] = args[i+1]
    else:
      hash[args[i].stringVal] = args[i+1]
  return newHashMap(hash)

### Predicates

defun "atom?", args:
  return newBool(args[0].kind == Atom)

defun "nil?", args:
  return newBool(args[0] == newNil())

defun "true?", args:
  return newBool(args[0] == newBool(true))

defun "false?", args:
  return newBool(args[0] == newBool(false))

defun "symbol?", args:
  return newBool(args[0].kind == Symbol)

defun "keyword?", args:
  return newBool(args[0].kind == Keyword)

defun "empty?", args:
  case args[0].kind
  of List, Vector:
    if args[0].seqVal.len == 0:
      return newBool(true)
  else:
    incorrectValueError "empty?: First argument is not a list or vector", args[0]
  return newBool(false)

defun "list?", args:
  return newBool(args[0].kind == List)

defun "vector?", args:
  return newBool(args[0].kind == Vector)

defun "sequential?", args:
  return newBool(args[0].kind in {List, Vector})

defun "map?", args:
  return newBool(args[0].kind == HashMap)

defun "contains?", args:
  if args[0] == newNil():
    return newBool(false)
  elif args[1].kind in {String, Keyword}:
    return newBool(args[0].hashVal.hasKey(args[1].keyval))
  return newBool(false)

defun "apply", args:
  let f = args[0]
  var list = newSeq[Node]()
  if args.len > 2:
    for i in 1 .. args.high-1:
      list.add args[i]
  let last = args[args.high]
  if last.seqVal.isNil:
    list.add newSeq[Node]()
  else:
    list.add last.seqVal
  return f.getFun()(list)

defun "map", args:
  result = newList()
  for i in 0 .. args[1].seqVal.high:
    result.seqVal.add args[0].getFun()(args[1].seqVal[i])

### Numeric Functions

defun "<", args:
  return newBool(args[0].intVal < args[1].intVal)

defun "<=", args:
  return newBool(args[0].intVal <= args[1].intVal)

defun ">", args:
  return newBool(args[0].intVal > args[1].intVal)

defun ">=", args:
  return newBool(args[0].intVal >= args[1].intVal)

defun "+", args:
  return newInt(args[0].intVal + args[1].intVal)

defun "-", args:
  return newInt(args[0].intVal - args[1].intVal)

defun "*", args:
  return newInt(args[0].intVal * args[1].intVal)

defun "/", args:
  return newInt(int(args[0].intVal / args[1].intVal))

### List/Vector Functions

defun "count", args:
  case args[0].kind:
  of Nil:
    return newInt(0)
  of List, Vector:
    return newInt(args[0].seqVal.len)
  else:
    incorrectValueError "count: First argument is not a list or vector", args[0]

defun "cons", args:
  var list = newSeq[Node]()
  list.add args[0]
  return newList(list & args[1].seqVal)

defun "concat", args:
  var list: seq[Node]
  for arg in args:
    list = list & arg.seqVal
  return newList(list)

defun "nth", args:
  let i = args[1].intVal
  let list = args[0].seqVal
  if i >= list.len:
    incorrectValueError "nth: Index out of bounds", args[1]
  return args[0].seqVal[args[1].intVal]

defun "car", args:
  if args[0].seqVal.len == 0:
    return newNil()
  return args[0].seqVal[0]

defun "cdr", args:
  if args[0].seqVal.len == 0:
    return newList(args[0].seqVal)
  return newList(args[0].seqVal[1 .. ^1])

defun "conj", args:
  var list = newSeq[Node]()
  if args[0].kind == List:
    for i in countdown(args.high, 1):
      list.add args[i]
    list.add args[0].seqVal
    result = newList(list)
  else:
    list.add args[0].seqVal
    for i in 1 .. args.high:
      list.add args[i]
    result = newVector(list)
  result.meta = args[0].meta

### HashMap Functions

defun "assoc", args:
  var hash = args[0].hashVal
  for i in countup(1, args.high, 2):
    hash.setKey(args[i].keyval, args[i+1])
  return newHashMap(hash)

defun "dissoc", args:
  var hash = args[0].hashVal
  for i in 1 .. args.high:
    hash.del(args[i].keyval)
  return newHashMap(hash)

defun "get", args:
  if args[0] == newNil():
    return newNil()
  var hash = args[0].hashVal
  if args[1].kind in {String, Keyword} and hash.hasKey(args[1].keyval):
    return hash[args[1].keyval]
  else:
    return newNil()

defun "keys", args:
  var a = args[0]
  if args[0].kind == Atom:
    a = args[0].atomVal
  let hash = a.hashVal
  var list = newSeq[Node]()
  for i in hash.keys:
    if i[0] == '\xff':
      list.add newKeyword(i[1 .. i.high])
    else:
      list.add newString(i)
  return newList(list)

defun "vals", args:
  let hash = args[0].hashVal
  var list = newSeq[Node]()
  for i in hash.values:
    list.add i
  return newList(list)


### String Functions

defun "read-string", args:
  return readStr(args[0].stringVal)

defun "pr-str", args:
  return newString(args.map(proc(n: Node): string = return $n).join(" "))

defun "str", args:
  return newString(args.map(proc(n: Node): string = return $~n).join())

defun "prn", args:
  echo args.map(proc(n: Node): string = return $n).join(" ")
  return newNil()

defun "println", args:
  echo args.map(proc(n: Node): string = return $~n).join(" ")
  return newNil()

defun "slurp", args:
  return newString(readFile(args[0].stringVal))

### Atom Functions

defun "reset!", args:
  args[0].atomVal = args[1]
  return args[1]

defun "swap!", args:
  var nArgs = newSeq[Node]()
  nArgs.add args[0].atomVal
  for i in 2 .. args.high:
    nArgs.add args[i]
  args[0].atomVal = args[1].getFun()(nArgs)
  return args[0].atomVal

### Other Functions

defun "debug", args:
  if args[0].falsy:
    debug = false
    return newBool(false)
  else:
    debug = true
    return newBool(true)
