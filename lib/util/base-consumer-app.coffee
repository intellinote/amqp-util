# Extends `BaseApp` to manage the configuration of an `AMQPConsumer`.

# ## Imports

# Conditionally load files from the code-coverage-instrumented lib directory
# (`lib-cov`) if available.
path             = require 'path'
fs               = require 'fs'
HOMEDIR          = path.join(__dirname,'..','..')
IS_INSTRUMENTED  = fs.existsSync( path.join(HOMEDIR,'lib-cov') )
LIB_DIR          = if IS_INSTRUMENTED then path.join(HOMEDIR,'lib-cov') else path.join(HOMEDIR,'lib')
AMQPConsumer     = require(path.join(LIB_DIR,'amqp-consumer')).AMQPConsumer
BaseApp          = require(path.join(LIB_DIR,'util','base-app')).BaseApp
config           = require('inote-util').config.init()

# ## Implementation

# **BaseConsumerApp**
#
# While `BaseConsumerApp` is instantiable, and even executable, it is not
# really intended to be used as-is.
#
# Instead, `BaseConsumerApp` is designed to be extended by other classes
# that implement actual command-line applications that include an
# AMQP consumer.
#
# Specifically, `BaseConsumerApp`:
#
#  1. Adds `AMQPConsumer`-related command-line parameters.
#
#  2. Allows those command-line parameters to be read from
#     a configuration file.
#
#  3. Provides a convenience method for initializing the
#     `AMQPConsumer` and subscribing to a message queue.
#
#  4. Implements a (no-op) `handle_message` method that
#     sub-classes can override to provide their
#     message-handling functionality.
#
# In the simplest case, to extend `BaseConsumerApp`, simply
# override the `handle_message` method and invoke
# the `main` method when appropriate.
#
# For example,
#
#     #!/usr/bin/env coffee
#     BaseConsumerApp = require('amqp-util').util.BaseConsumerApp
#
#     class MyApp extends BaseConsumerApp
#
#       handle_message:(message,headers,info,raw)=>
#         console.log "MESSAGE", message
#
#     if require.main is module
#       (new MyApp()).main()
#
#
class BaseConsumerApp extends BaseApp

  # **consumer** - *my `AMQPConsumer` instance.*
  consumer: null

  # **constructor** - *create a new `BaseConsumerApp` instance.*
  #
  # The method reads default command-line parameter values from a
  # configuration file (using the `Config` type from `inote-util`,
  # which see.)
  #
  # Specifically, this method looks for the following parameters:
  #
  #  - `${PREFIX}:broker`
  #  - `${PREFIX}:connection-options`
  #  - `${PREFIX}:exchange`
  #  - `${PREFIX}:routing-key`
  #  - `${PREFIX}:queue`
  #  - `${PREFIX}:queue-options`
  #  - `${PREFIX}:subscription-options`
  #
  # where `${PREFIX}` is defined by the `config_key` parameter,
  # which defaults to `amqp:consumer`.
  #
  # See the `--help` option for a description of these parameters.
  constructor:(config_key="amqp:consumer")->
    @default_broker_url           = config.get("#{config_key}:broker") ? 'amqp://guest:guest@localhost:5672'
    @default_connection_options   = config.get("#{config_key}:connection-options") ? null
    @default_exchange_name        = config.get("#{config_key}:exchange") ? ""
    @default_key_pattern          = config.get("#{config_key}:key-pattern") ? '*'
    @default_queue_name           = config.get("#{config_key}:queue") ? null
    @default_queue_options        = config.get("#{config_key}:queue-options") ? null
    @default_subscription_options = config.get("#{config_key}:subscription-options") ? null

  # **init_options** - *set up the `options` map with default parameters.*
  #
  # In addition to those options provided by `BaseApp`, this method registers:
  #
  #  - `broker`
  #  - `connection-options`
  #  - `queue`
  #  - `queue-options`
  #  - `subscription-options`
  #  - `key-pattern`
  #  - `exchange`
  #
  # The default value for each of these parameters is determined by the
  # `inote-util`-based configuration.
  init_options:()->
    super()
    @options.b = { alias: 'broker',               default: @default_broker_url,           describe: "Message broker to connect to"                               }
    @options.B = { alias: 'connection-options',   default: @default_connection_options,   describe: "JSON-string representation of connection (broker) options." }
    @options.q = { alias: 'queue',                default: @default_queue_name,           describe: "Queue to subscribe to."                                     }
    @options.Q = { alias: 'queue-options',        default: @default_queue_options,        describe: "JSON-string representation of queue options."               }
    @options.S = { alias: 'subscription-options', default: @default_subscription_options, describe: "JSON-string representation of subscription options."        }
    @options.k = { alias: 'key-pattern',          default: @default_key_pattern,          describe: "Routing key pattern (used when binding to an exchange)"     }
    @options.e = { alias: 'exchange',             default: @default_exchange_name,        describe: "Exchange to bind to (optional)."                            }

  # **init_consumer** - *initialize the `AMQPConsumer`.*
  init_consumer:()=>
    @consumer = new AMQPConsumer()

  # **connect_consumer** - *connect to the message broker (using the `@argv` configuration).*
  #
  # `connect_consumer` will connect to the specified broker (`@argv.broker`)
  # using the `@argv` configuration.
  #
  # The given `callback` method will be invoked when the connection has
  # been established.
  #
  # The `AMQPConsumer` must be initialized (via `init_consumer`) before
  # this method is invoked.
  connect_consumer:(callback)=>
    @init_consumer() unless @consumer?
    broker = @argv.broker
    connection_options = @json_string_to_object( @argv['connection-options'] )
    queue = @argv.queue
    queue_options = @json_string_to_object( @argv['queue-options'] )
    @consumer.connect broker, connection_options, queue, queue_options, callback

  # **subscribe_consumer** - *subscribe to the message queue (using the `@argv` configuration).*
  #
  # `connect_consumer` will subscribe to the message queue using the given
  # `key-pattern` and `subscription-options` parameters.
  #
  # The given `callback` method will be invoked when the subscription is
  # active.
  #
  # The `AMQPConsumer` must be connected (via `connect_consumer`) before
  # this method is invoked.
  subscribe_consumer:(callback)=>
    exchange = @argv.exchange
    key_pattern = @argv['key-pattern']
    options = @argv['subscription-options'] if @argv['subscription-options']? # be careful not to pass null here as it overrides the defaults
    @consumer.subscribe(exchange,key_pattern,options,@handle_message,callback)

  # **main** - *rudimentary implementation of the main program loop.*
  main:(callback)=>
    super()
    @init_consumer()
    console.log "Connecting." if @argv.verbose
    @connect_consumer ()=>
      console.log "Connected." if @argv.verbose
      @subscribe_consumer ()=>
        console.log "Subscribed." if @argv.verbose
        callback?()

  # **handle_message** - *invoked when a message arrives from the message queue.*
  handle_message:(message,headers,info,raw)->

# ## Exports

# Exported as `BaseConsumerApp`.
exports.BaseConsumerApp = BaseConsumerApp

# If this file is invoked directly, run the `main` method.
if require.main is module
  (new BaseConsumerApp()).main()
