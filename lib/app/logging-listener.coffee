# A simple AMQP message consumer that logs messages to the console.

# ## Using

# Launch this script via:
#
#     NODE_ENV=THE_CONFIG ./bin/logging-listener
#
# or
#
#     NODE_ENV=THE_CONFIG coffee lib/app/logging-listener.coffee
#
# or
#
#     NODE_ENV=THE_CONFIG node lib/app/logging-listener.js
#
# and then post a message to the queue to see the message logged
# to STDOUT.
#
# Use the command-line parameter `--help` for more information.

# See `PublishMessage` for a simple utility that can be used to test or
# demonstrate the other side of this conversation (publishing a message
# from the command-line).

# ## Imports

# Conditionally load files from the code-coverage-instrumented lib directory
# (`lib-cov`) if available.
path               = require 'path'
fs                 = require 'fs'
HOMEDIR            = path.join(__dirname,'..','..')
IS_INSTRUMENTED    = fs.existsSync( path.join(HOMEDIR,'lib-cov') )
LIB_DIR            = if IS_INSTRUMENTED then path.join(HOMEDIR,'lib-cov') else path.join(HOMEDIR,'lib')
BaseConsumerApp    = require(path.join(LIB_DIR,'util','base-consumer-app')).BaseConsumerApp
AMQPStringConsumer = require(path.join(LIB_DIR,'amqp-consumer')).AMQPStringConsumer

# ## Implementation

# **LoggingListener**

class LoggingListener extends BaseConsumerApp

  # **constructor** - *create a new `LoggingListener` instance, reading
  # default settings from confguration file if available.*
  #
  # (See `BaseConsumerApp.constructor` for more information.)
  constructor:(config_key)->
    super(config_key)

  # **count** - *the total number of messages we've logged.*
  count: 0

  # **handle_message* - *prints a description of the message to the console.*
  handle_message:(message,headers,deliveryInfo,raw)=>
    @count += 1
    parts = []
    parts.push "[##{@count}]" if @argv.count
    parts.push "[#{(new Date()).toISOString()}]" if @argv.timestamp
    if @argv.message
      if @jsonify
        parts.push JSON.stringify(message)
      else
        parts.push message
    if @argv.headers
      if @jsonify
        parts.push JSON.stringify(headers)
      else
        parts.push headers
    if @argv.info
      if @jsonify
        parts.push JSON.stringify(deliveryInfo)
      else
        parts.push deliveryInfo
    console.log parts...

  # **init_options** - *add application-specific configuration parameters/*
  init_options:()=>
    super()
    @options.M = { alias: 'message', default: true, boolean: true, describe: "Include message body in output" }
    @options.H = { alias: 'headers', default: false, boolean: true, describe: "Include message headers in output" }
    @options.I = { alias: 'info', default: false, boolean: true, describe: "Include delivery info in output" }
    @options.T = { alias: 'timestamp', default: true, boolean: true, describe: "Include timestamp in output" }
    @options.C = { alias: 'count', default: false, boolean: true, describe: "Show count" }
    @options.j = { alias: 'jsonify', default: true, boolean: true, describe: "Convert message contents into a JSON string" }

  # **init_consumer** - *override `BaseConsumerApp` method to create *string*-based consumer.*
  init_consumer:()=>
    @consumer = new AMQPStringConsumer()

  main:()=>
    super ()=>
      unless @argv.quiet
        console.log "LoggingListener connected to broker at \"#{@argv.broker}\" and now listening for messages on queue \"#{@argv.queue}\"."
        console.log "Press Ctrl-C to exit."


# ## Exports

# Exported as `LoggingListener`.
exports.LoggingListener = LoggingListener

# If this file is invoked directly, run the `main` method.
if require.main is module
  (new LoggingListener()).main()
