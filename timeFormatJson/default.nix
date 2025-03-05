{ writeText }:
# TODO: No proper escaping done on the command.
writeText "time-format-json" ''
  {
    "time": {
      "real": %e,
      "user": %U,
      "sys": %S
    },
    "memory": {
      "maxRss": %M,
      "avgRss": %t,
      "avgTotal": %K,
      "avgUnsharedData": %D,
      "avgUnsharedStack": %p,
      "avgSharedText": %X,
      "pageSize": %Z
    },
    "io": {
      "majorPageFaults": %F,
      "minorPageFaults": %R,
      "swapsOutOfMainMemory": %W,
      "voluntaryContextSwitches": %w,
      "involuntaryContextSwitches": %c,
      "fileSystemInputs": %I,
      "fileSystemOutputs": %O,
      "socketMessagesSent": %s,
      "socketMessagesReceived": %r,
      "signalsDelivered": %k
    },
    "cmd": {
      "exitStatus": %x,
      "command": "%C"
    }
  }
''
