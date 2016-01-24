import
  regex,
  types,
  strutils,
  printer,
  critbits

import
  config

let
  # Original PCRE:  """[\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*"|;.*|[^\s\[\]{}('"`,;)]*)"""
  REGEX_TOKEN   = re"""[\s,]*{(~@|[\[\]\{\}()'`~^@]|"(\\.|[^\\"])*"|;[^\\n]*|[^\s\[\]\{\}('"`,;)]*)}"""

const
  UNMATCHED_PAREN = "expected ')', got EOF"
  UNMATCHED_BRACKET = "expected ']', got EOF"
  UNMATCHED_BRACE = "expected '}', got EOF"
  UNMATCHED_DOUBLE_QUOTE = "expected '\"', got EOF"
  INVALID_HASHMAP_KEY = "invalid hashmap key"

proc tokenizer*(str: string): seq[Token] =
  result = newSeq[Token](0)
  var
    matches: array[0..0, string]
    s = str
    token: Token
    position = 0
    tokstart = 0
    tokend = 0
    linestart = 0
    column = 0
  while s != "" and s.match(REGEX_TOKEN, matches) and matches[0] != nil and matches[0] != "":
    tokstart = s.find(matches[0])
    tokend = matches[0].len
    position = position + tokstart + tokend
    linestart = max(str[0 .. position].rfind("\n"), 0)
    column = position - linestart - 1
    token = Token(value: matches[0], line: str[0 .. position].count("\n")+1, column: column)
    #echo "---"
    #echo "Token: ", token.value
    #echo "Position: ", position, " Line Start:", linestart
    #echo "String: ", s[0 .. position]
    #echo "Line: ", token.line, " Column: ", token.column
    if not token.value.match(re"^;"):
      result.add(token)
    s = s.substr(tokstart + tokend, s.len-1)
    matches[0] = nil
  if token.value.len == 0:
    parsingError UNMATCHED_DOUBLE_QUOTE, token

proc readForm*(r: var Reader): Node

proc readStr*(str: string): Node =
  var r:Reader
  r.tokens = str.tokenizer()
  r.pos = 0
  if r.tokens.len == 0:
    noTokensError()
  return r.readForm()

proc peek*(r: Reader): Token =
  return r.tokens[r.pos]

proc peekprevious(r: Reader): Token =
  return r.tokens[r.pos-1]

proc next*(r: var Reader): Token {.discardable.} =
  result = r.tokens[r.pos]
  r.pos = r.pos + 1

proc readAtom*(r: var Reader): Node =
  let token = r.peek()
  if token.value.match(re"^:[\w]+$"):
    result = newKeyword(token)
  elif token.value.match(re"""^".*"$"""):
    result = newString(token)
  elif token.value.match(re"^[\d]+$"):
    result = newInt(token)
  elif token.value == "#f" or token.value == "#t":
    result = newBool(token)
  else:
    result = newSymbol(token)
  dbg:
    echo "Token: <$1>" % token.value
    echo "READ ATOM: $1 -- $2" % [$result, result.kindname]

proc isEmpty*(n: Node): bool =
  return n.kind == List and n.seqVal.len == 0

proc toList*(n: Node): Node = 
  var car = n.seqVal[0]
  var cdr = n.seqVal[1]
  var list = newSeq[Node]()
  list.add car
  if cdr.isEmpty:
    return newList(list)
  elif cdr.kind == List:
    return newList(list & cdr.seqVal)
  elif cdr.kind == Pair:
    let rest = cdr.toList
    if rest.kind == List:
      return newList(list & rest.seqVal)
    else:
      list.add rest
      return newList(list)
  else:
    return n

proc readList*(r: var Reader): Node =
  var list = newSeq[Node]()
  var hasPair = false
  try:
    discard r.peek()
  except:
    parsingError UNMATCHED_PAREN, r.peekprevious
  while r.peek.value != ")":
    if r.peek.value == ".": 
      hasPair = true
      discard r.next()
      continue
    if hasPair:
      if list.len == 0:
        parsingError "Invalid Pair", r.peekprevious
      var pair = newSeq[Node]()
      pair.add list.pop
      pair.add r.readForm()
      list.add newPair(pair)
    else:
      list.add r.readForm()
    #if isPair and list.len != 2:
    #  parsingError "Invalid Pair", r.peekprevious
    discard r.next()
    if r.tokens.len == r.pos:
      parsingError UNMATCHED_PAREN, r.peekprevious
    try:
      discard r.peek()
    except:
      parsingError UNMATCHED_PAREN, r.peekprevious
  if hasPair:
    if list[0].kind == Pair and list.len == 1:
      # ((1 . 2))
      return list[0].toList
    else:
      return newPair(list).toList
  else:
    return newList(list)

proc readVector*(r: var Reader): Node =
  var vector = newSeq[Node]()
  try:
    discard r.peek()
  except:
    parsingError UNMATCHED_BRACKET, r.peekprevious
    return
  while r.peek.value != "]":
    vector.add r.readForm()
    discard r.next()
    if r.tokens.len == r.pos:
      parsingError UNMATCHED_BRACKET, r.peekprevious
    try:
      discard r.peek()
    except:
      parsingError UNMATCHED_BRACKET, r.peekprevious
  return newvector(vector)

proc readHashMap*(r: var Reader): Node =
  var p: Printer
  var map: NodeMap
  try:
    discard r.peek()
  except:
    parsingError UNMATCHED_BRACE, r.peekprevious
  var key: Node
  while r.peek.value != "}":
    key = r.readAtom()
    discard r.next()
    if key.kind in {String, Keyword}:
      map[key.keyval] = r.readForm()
      discard r.next()
      if r.tokens.len == r.pos:
        parsingError UNMATCHED_BRACE, r.peekprevious
      try:
        discard r.peek()
      except:
        parsingError UNMATCHED_BRACE, r.peekprevious
    else:
      parsingError(INVALID_HASHMAP_KEY & " - got: '$value' ($type)" % ["value", p.prStr(key), "type", key.kindName], r.peekprevious)
  return newhashMap(map)

proc readForm*(r: var Reader): Node =
  case r.peek.value:
    of "{":
      discard r.next()
      result = r.readHashMap()
    of "[":
      discard r.next()
      result = r.readVector()
    of "(":
      discard r.next()
      result = r.readList()
    of "'":
      discard r.next()
      result = newList(@[newSymbol("quote"), r.readForm()])
    of "`":
      discard r.next()
      result = newList(@[newSymbol("quasiquote"), r.readForm()])
    of "~":
      discard r.next()
      result = newList(@[newSymbol("unquote"), r.readForm()])
    of "~@":
      discard r.next()
      result = newList(@[newSymbol("splice-unquote"), r.readForm()])
    of "@":
      discard r.next()
      let sym = r.readForm()
      result = newList(@[newSymbol("deref"), sym])
    of "^":
      discard r.next()
      if r.peek.value == "{":
        discard r.next()
        let h = r.readHashMap()
        discard r.next()
        let v = r.readForm()
        result = newList(@[newSymbol("with-meta"), v, h])
      else:
        incorrectValueError "A HashMap is required by the with-meta macro"
    else:
      result = r.readAtom()
