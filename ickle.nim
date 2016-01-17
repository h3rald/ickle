import
  parseopt2,
  strutils

import
  lib/config,
  lib/types,
  lib/reader,
  lib/printer,
  lib/environment,
  lib/evaluator,
  lib/core

var
  argv* = newSeq[Node]()

### Parse Options

for kind, key, val in getopt():
  case kind:
    of cmdLongOption, cmdShortOption:
      case key:
        of "debug", "d":
          debug = true
        else:
          discard
    of cmdArgument:
      if file == nil:
        file = key
      else:
        argv.add(newString(val))
    else:
      discard

defconst "*ARGV*", newList(argv)

### REPL

const
  lib = "lib/scm/lib.scm".slurp

lib.evalText

if file.isNil:
  echo "$1 v$2 - (c) $3 $4" % [program, version, CompileDate[0 .. 3], author]
  while true:
    try:
      rep(MAINENV)
    except NoTokensError:
      continue
    except:
      echo getCurrentExceptionMsg()
      echo getCurrentException().getStackTrace()
else:
  try:
    print(eval(readStr("(load-file \"" & file & "\")" % file), MAINENV))
  except NoTokensError:
    discard
  except:
    echo getCurrentExceptionMsg()
    echo getCurrentException().getStackTrace()
