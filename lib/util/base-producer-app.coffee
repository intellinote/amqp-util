path             = require 'path'
fs               = require 'fs'
HOMEDIR          = path.join(__dirname,'..','..')
IS_INSTRUMENTED  = fs.existsSync( path.join(HOMEDIR,'lib-cov') )
LIB_DIR          = if IS_INSTRUMENTED then path.join(HOMEDIR,'lib-cov') else path.join(HOMEDIR,'lib')
AMQPProducer     = require(path.join(LIB_DIR,'amqp-producer')).AMQPProducer
BaseApp          = require(path.join(LIB_DIR,'util','base-app')).BaseApp
config           = require('inote-util').config.init()

class BaseProducerApp extends BaseApp

  producer: null


  # **constructor** - *create a new `BaseProducerApp` instance.*
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
  #  - `${PREFIX}:exchange-options`
  #  - `${PREFIX}:routing-key`
  #  - `${PREFIX}:publishing-options`
  #
  # where `${PREFIX}` is defined by the `config_key` parameter,
  # which defaults to `amqp:producer`.
  #
  # See the `--help` option for a description of these parameters.
  constructor:(config_key="amqp:producer")->
    @default_broker_url           = config.get("#{config_key}:broker") ? 'amqp://guest:guest@localhost:5672'
    @default_connection_options   = config.get("#{config_key}:connection-options") ? null
    @default_exchange_name        = config.get("#{config_key}:exchange") ? ""
    @default_exchange_options     = config.get("#{config_key}:exchange-options") ? null
    @default_routing_key          = config.get("#{config_key}:routing-key") ? 'amqp-test-key'
    @default_publishing_options   = config.get("#{config_key}:publishing-options") ? null

  # **init_options** - *set up the `options` map with default parameters.*
  #
  # In addition to those options provided by `BaseApp`, this method registers:
  #
  #  - `broker`
  #  - `connection-options`
  #  - `exchange`
  #  - `exchange-options`
  #  - `subscription-options`
  #  - `routing-key`
  #  - `publishing-options`
  #
  # The default value for each of these parameters is determined by the
  # `inote-util`-based configuration.
  init_options:()->
    super()
    @options.b = { alias: 'broker', default: @default_broker_url, describe: "Message broker to connect to" }
    @options.B = { alias: 'connection-options', describe: "JSON-string representation of connection (broker) options.", default: @default_connection_options }
    @options.e = { alias: 'exchange', default: @default_exchange_name, describe: "Exchange to publish to." }
    @options.E = { alias: 'exchange-options', describe: "JSON-string representation of exchange options.", default: @default_exchange_options }
    @options.O = { alias: 'publishing-options', describe: "JSON-string representation of publishing options (such as headers).", default: @default_publishing_options }
    @options.k = { alias: 'routing-key', describe: "Default routing key.", default: @default_routing_key  }

  # **publish_message** - *publish the given message to the exchange*
  publish_message:(body,key,pub_options)=>
    pub_options ?= @argv['publishing-options']
    key ?=  @argv['routing-key']
    if @argv.verbose
      console.log "Publishing:",body,key,pub_options
    @producer.publish(body,key,pub_options)

  # **init_producer** - *initialize the producer*
  init_producer:()=>
    @producer = new AMQPProducer()

  # **connect_producer** - *connect the producer*
  connect_producer:(callback)=>
    @init_producer() unless @producer?
    broker = @argv.broker
    exchange = @argv.exchange
    connection_options = @json_string_to_object( @argv['connection-options'] )
    exchange_options = @json_string_to_object( @argv['exchange-options'] )
    console.log exchange_options
    @producer.connect(broker, connection_options, exchange, exchange_options, callback)

  # **main** - *rudimentary implementation of the main program loop.*
  main:(callback)=>
    super()
    @init_producer()
    @connect_producer ()=>
      console.log "Connected." if @argv.verbose
      callback?()

exports.BaseProducerApp = BaseProducerApp

if require.main is module
  (new BaseProducerApp()).main ()->
    console.log "done"
    process.exit()
