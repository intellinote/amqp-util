# ## Calculate LIB_DIR

# As we do throughout the source files in this module, in order to
# support test coverage analysis, we deterime whether we should load
# additional local files from the default `lib` directory or from the
# `lib-cov` directory that contains an instrumented version of
# the source code (when present).

fs        = require 'fs'
path      = require 'path'
HOMEDIR   = path.join __dirname, '..'
LIB_COV   = path.join HOMEDIR, 'lib-cov'
LIB       = path.join HOMEDIR, 'lib'
LIB_DIR   = if fs.existsSync(LIB_COV) then LIB_COV else LIB

# ## Export Objects to the External Namespace

# `sources` enumerates the files from which we'll load objects to export.

sources = [
  'amqp-consumer'
  'amqp-producer'
  [ 'util', 'base-app' ]
  [ 'util', 'base-consumer-app' ]
  [ 'util', 'base-producer-app' ]
  [ 'app',  'amqp-cli' ]
 ]

# Now we simply load (`require`) the requisite files and pass along whatever
# they've exported to the module's `exports` object.

for file in sources
  target = exports
  if Array.isArray(file)
    for p in file[0...-1]
      target[p] ?= {}
      target = target[p]
    file = path.join(file...)
  exported = require path.join(LIB_DIR,file)
  for k,v of exported
    target[k] = v
