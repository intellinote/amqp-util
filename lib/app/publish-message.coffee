# A simple AMQP message producer that publishes a message from the command-line.

# ## Using

# Launch this script via:
#
#     NODE_ENV=THE_CONFIG ./bin/publish-message -m MESSAGE
#
# or
#
#     NODE_ENV=THE_CONFIG coffee lib/app/publish-message.coffee -m MESSAGE
#
# or
#
#     NODE_ENV=THE_CONFIG node lib/app/publish-message.js -m MESSAGE
#
# to publish the given `MESSAGE` on the queue defined by `./config/THE_CONFIG.json`
# (or via command-line parameters).
#
# Use the command-line parameter `--help` for more information.


# See `LoggingListener` for a simple utility that can be used to test or
# demonstrate the other side of this conversation (printing the published
# message to the console).

# ## Imports

# Conditionally load files from the code-coverage-instrumented lib directory
# (`lib-cov`) if available.
path             = require 'path'
fs               = require 'fs'
HOMEDIR          = path.join(__dirname,'..','..')
IS_INSTRUMENTED  = fs.existsSync( path.join(HOMEDIR,'lib-cov') )
LIB_DIR          = if IS_INSTRUMENTED then path.join(HOMEDIR,'lib-cov') else path.join(HOMEDIR,'lib')
BaseProducerApp   = require(path.join(LIB_DIR,'util','base-producer-app')).BaseProducerApp


# ## Implementation

# **PublishMessage**

class PublishMessage extends BaseProducerApp

  # **constructor** - *create a new `PublishMessage` instance, reading
  # default settings from confguration file if available.*
  #
  # (See `BasProducerApp.constructor` for more information.)
  constructor:(config_key)->
    super(config_key)

  # **init_options** - *add application-specific configuration parameters.*
  init_options:()->
    super()
    @options.m = { alias:'message', describe: "JSON representation of the message to publish." }

  # **main** - *the main program loop.*
  main:(callback)->
    super ()=>
      console.log "Connected to broker at \"#{@argv.broker}\"." unless @argv.quiet
      key = @argv['routing-key']
      pub_options = @argv['publishing-options']
      message = @argv.message
      if /^\s*\{|\[/.test(message) and /\}|\]\s*$/.test(message)
        try
          message = JSON.parse(message)
        catch err
          message = message
      @publish_message(message,key,pub_options)
      console.log "Published the payload \"#{JSON.stringify(message)}\" using the routing key \"#{key}\" to the exchange named \"#{@argv.exchange}\"." unless @argv.quiet
      callback?()

# ## Exports

# Exported as `PublishMessage`.
exports.PublishMessage = PublishMessage

# If this file is invoked directly, run the `main` method.
if require.main is module
  (new PublishMessage()).main ()=>process.exit()
