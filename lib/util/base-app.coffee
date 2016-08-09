# A base class for simple command-line applications.

# ## Imports

#
optimist         = require 'optimist'

# ## Implementation

# **BaseApp**
#
# While `BaseApp` is instantiable, and even executable, it is not
# really intended to be used as-is.
#
# Instead, `BaseApp` is designed to be extended by other classes
# that implement actual command-line applications.
#
# To extend `BaseApp`:
#
# 1. Override `init_options` to set up the appropriate command line
#    parameters.  (Be sure to call `super()` if you want to inherit
#    the default options that `BaseApp` creates.)
#
# 2. Implement override or implement a `main` method to launch your
#    actual service. (Be sure to invoke `super()` if you want to
#    inherit the command-line processing that `BaseApp` performs.)
#
# For example, the following CoffeeScript snippet demonstrates
# the creation of a simple application that extends from `BaseApp`.
#
#     #!/usr/bin/env coffee
#     BaseApp = require('amqp-util').util.BaseApp
#
#     class MyApp extends BaseApp
#
#       init_options:()=>
#         super() # initialize `@options` map and default options
#         @options.foo = {describe:"A new option.",default:"bar"}
#         @options.bar = {describe:"Another option.",default:19}
#
#       main:()=>
#         super() # process command line arguments to populate `@argv`
#         if @argv.verbose
#           console.log "--foo was #{@argv.foo}."
#           console.log "--bar was #{@argv.bar}."
#         console.log "...Do some processing here..."
#         process.exit()
#
#     if require.main is module
#       (new MyApp()).main()
#
# The file above implements a console application that supports
# `--help`, (also `-h`), `--verbose`, `--quiet`, `--env` as well as the
# `--foo` and `--bar` parameters described in the file itself.
#
class BaseApp

  # **options** - *a description of the command line parameters, as suitable for use with `optimist`.*
  options: null

  # **argv** - *command line parameters, as parsed by `optimist`.*
  argv: null

  # **init_options** - *set up the `options` map with default parameters.*
  init_options:()=>
    @options = {
      h:       { describe: "Show help.",              boolean:true, default:false, alias:'help' }
      verbose: { describe: "Be more chatty.",         boolean:true, default:false               }
      quiet:   { describe: "Be less chatty.",         boolean:true, default:false               }
      env:     { describe: "Print my configuration.", boolean:true, default:false               }
    }

  # **init_argv** - *process the command-line parameters and initialize `argv`.*
  init_argv:()=>
    @argv = optimist.options(@options).usage('Usage: $0 [OPTIONS]').argv
    if @argv.quiet and @argv.verbose
      @argv.verbose = @argv.v = false

  # **on_interrupt** - *a callback that *may* be used to handle the `SIGINT` (kill) signal.*
  on_interrupt:(signal)=>
    if signal is 'SIGINT'
      console.log 'Received kill signal (SIGINT), shutting down.' unless @argv.quiet
      process.exit()

  # **on_help** - *show help on command line parameters, then exit.*
  on_help:()->
    optimist.showHelp()
    process.exit()

  # **on_env** - *print the current configuration to the console.*
  on_env:()=>
    console.log "Current Configuration:"
    console.log @argv

  # **json_string_to_object** - *conditionally parse a string as a JSON document.*
  #
  # If `value` is a string that is wrapped in `{ }`, `[ ]` or `" "`, then it
  # will be parsed as a JSON representation of an object. Otherwise `value` is
  # returned as-is.
  json_string_to_object:(value)=>
    if typeof value is 'string' and /^\s*((\".*\")|(\[.*\])(\{.*\}))\s*$/.test(value)
      return JSON.parse(value)
    else
      return value

  # **main** - *rudimentary implementation of the main program loop.*
  #
  # This method will:
  #
  #  - process the command line parameters (using `optimist`
  #    and the configured `options`).
  #
  #  - handle the `--help` and `--env` parameters when provided.
  #
  #  - register `on_interrupt` to handle the kill signal.
  #
  # That's all.
  #
  # This method is not meant to be stand-alone.  It doesn't do
  # very much on its own.
  #
  # This method is intended to be extended by sub-classes, which
  # delegate this method to handle the initial command-line processing
  # and then follow up with the *actual* main program loop.
  #
  # EXAMPLE OF USE
  #
  #      class MyApp extends BaseApp
  #        main:()=>
  #          super()
  #          init_service()
  #          launch_service()
  #
  main:(callback)=>
    # If the node-optimist options haven't been defined, do so now.
    @init_options() unless @options?
    # If the command line parameters haven't been parsed, do so now.
    @init_argv() unless @argv?
    # If `--env` is passed, print the current configuration.
    if @argv.env
      @on_env()
    # If `--help` is passed, show help and exit.
    if @argv.help
      @on_help()
    # Register the `SIGINT` handler.
    process.on 'SIGINT',()=>@on_interrupt('SIGINT')
    callback?()

# ## Exports

# Exported as `BaseApp`.
exports.BaseApp = BaseApp

# If this file is invoked directly, run the `main` method.
if require.main is module
  (new BaseApp()).main()
