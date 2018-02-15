fs        = require 'fs'
path      = require 'path'
HOME_DIR  = path.join __dirname, '..'
LIB_COV   = path.join HOME_DIR, 'lib-cov'
LIB       = path.join HOME_DIR, 'lib'
LIB_DIR   = if fs.existsSync(LIB_COV) then LIB_COV else LIB
################################################################################
amqp       = require 'amqp'
RandomUtil = require('inote-util').RandomUtil
AsyncUtil  = require('inote-util').AsyncUtil
process    = require 'process'
################################################################################
AmqpBase   = require(path.join(LIB_DIR, 'amqp-base')).AmqpBase
################################################################################

class AmqpProducer extends AmqpBase

  constructor:()->
    super()

  # **default_routing_key** - *the default key value to use in `publish`.*
  default_routing_key: null

  # **default_publish_options** - *map of the default publishing options for `publish`.*
  default_publish_options: null

  # **set_default_publish_option** - *sets one of the default publishing options.*
  set_default_publish_option:(name,value)=>
    @default_publish_options ?= {}
    @default_publish_options[name] = value

  # **set_default_publish_header** - *sets one of the default publishing headers.*
  set_default_publish_header:(name,value)=>
    @default_publish_options ?= {}
    @default_publish_options.headers ?= {}
    @default_publish_options.headers[name] = value

  # **payload_converter** - *a utility method used to convert the payload before publishing.*
  #
  # (The default method is the identity function, no conversion occurs.)
  payload_converter:(payload)=>payload


  _on_connect:(callback)=>
    @exchanges_by_name ?= { }
    callback?()

  _on_disconnect:(callback)=>
    @exchanges_by_name = undefined
    callback?()

  # args:
  #  - exchange_name
  #  - exchange_options
  #  - callback
  create_exchange:(exchange_name, exchange_options, callback)=>
    if typeof exchange_options is 'function' and not callback?
      callback = exchange_options
      exchange_options = undefined#
    unless @connection?
      callback? new Error("Not connected.")
      return undefined
    else
      if @exchanges_by_name[exchange_name]?
        callback?(undefined,@exchanges_by_name[exchange_name],exchange_name,true)
      else
        called_back = false
        exchange = @connection.exchange exchange_name, exchange_options, (x...)=>
          exchange.__amqp_util_exchange_name = exchange_name
          @exchanges_by_name[exchange_name] = exchange
          callback?(undefined,exchange,exchange_name,false)
      return exchange_name

  get_exchange:(exchange_name, exchange_options, callback)=>
    @create_exchange exchange_name, exchange_options, callback


  # args: exchange_or_exchange_name, payload, routing_key, publish_options, callback
  publish:(args...)=>
    if args?.length > 0 and (typeof args[0] is 'string' or not args[0]?)
      exchange_or_exchange_name = args.shift()
    else if args?.length > 0 and typeof args[0] is 'object' and @_object_is_exchange(args[0])
      exchange_or_exchange_name = args.shift()
    if args?.length > 0
      payload = args.shift()
    if args?.length > 0 and (typeof args[0] is 'string' or not args[0]?)
      routing_key = args.shift()
    if args?.length > 0 and (typeof args[0] is 'object' or not args[0]?)
      publish_options = args.shift()
    if args?.length > 0 and (typeof args[0] is 'function' or not args[0]?)
      callback = args.shift()
    #
    @_maybe_create_exchange exchange_or_exchange_name, (err, exchange, exchange_name)=>
      if err?
        callback?(err)
      else
        unless routing_key?
          routing_key = @default_routing_key
        unless publish_options?
          publish_options = @default_publish_options
        payload = @payload_converter(payload)
        exchange.publish routing_key, payload, publish_options, (error_occured)=>
          if error_occured
            callback?(error_occured)
          else
            callback?(null)

  get_exchange_by_name:(exchange_name)=>
    return @exchanges_by_name[exchange_name]

  _maybe_create_exchange:(exchange_or_exchange_name, args..., callback)=>
    [exchange, exchange_name] = @_to_exchange_exchange_name_pair exchange_or_exchange_name
    if exchange?
      callback? undefined, exchange, exchange_name, true
    else
      @create_exchange exchange_name, args..., callback

  _to_exchange_exchange_name_pair:(exchange_or_exchange_name)=>
    if typeof exchange_or_exchange_name is 'string'
      exchange_name = exchange_or_exchange_name
      exchange = @exchanges_by_name[exchange_or_exchange_name] ? undefined
    else if @_object_is_exchange exchange_or_exchange_name
      exchange = exchange_or_exchange_name
      exchange_name = exchange?.__amqp_util_exchange_name ? undefined
    else
      exchange_name = undefined
      exchange = undefined
    return [exchange, exchange_name]

  #
  #
  #
  #
  # # **connect** - *connects to a new or existing AMQP exchange.*
  # #
  # # Accepts four arguments:
  # #
  # #  - `broker_url` is the URL by which to connect to the message broker
  # #    (e.g., `amqp://guest:guest@localhost:5672`)
  # #
  # #  - `connection_options` is a partially AMQP-implementation-specific map of
  # #    options. See
  # #    [postwait's node-amqp documentation](https://github.com/postwait/node-amqp/#connection-options-and-url)
  # #    for details.
  # #
  # #  - `exchange_name` is the name of the AMQP Exchange to which the
  # #    producer will post messages.
  # #
  # #  - `exchange_options` is a map of options to be used when creating the
  # #    Exchange (if needed). See
  # #    [postwait's node-amqp documentation](https://github.com/postwait/node-amqp/#connectionexchangename-options-opencallback)
  # #    for details.
  # #
  # #  - `callback` is a method that is invoked when this producer is ready to
  # #    start publishing, it has the signature `(err,producer)`.
  # connect:(args...)=>
  #   # Parse out the method parameters, allowing optional values.
  #   broker_url = args.shift()
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'object')
  #     connection_options = args.shift()
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'string')
  #     exchange_name = args.shift()
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'object')
  #     exchange_options = args.shift()
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'function')
  #     callback = args.shift()
  #   # Now connect.
  #   @connection = amqp.createConnection({url:broker_url},connection_options)
  #   @connection.once 'ready', ()=>
  #     @exchange = @connection.exchange exchange_name, exchange_options
  #     @exchange.on 'error', @on_error
  #     @exchange.once "open", ()=>
  #       callback?(null,this)
  # # **publish** - *post a message to the message queue.*
  # #
  # # The message is posted to the current `exchange`, as configured in the
  # # constructor or `connect` method.
  # #
  # #  - `payload` is the message itself, typically a Buffer or Object
  # #
  # #  - `routing_key` - the routing key (as used by direct and topic exchanges).
  # #    When not specified, the value of `default_routing_key` is used.
  # #
  # #  - `options` a map of message publishing options. When not specified,
  # #    the value of `default_publish_options` is used. See
  # #    [postwait's node-amqp documentation](https://github.com/postwait/node-amqp/#exchangepublishroutingkey-message-options-callback)
  # #    for details.
  # #
  # #  - `callback` is an optional callback method that is used with the Exchange
  # #    is operating in "confirm" mode.  If an error occured the `callback` will
  # #    be passed a single non-`null` argument.
  # #
  # publish:(payload,routing_key,options,callback)=>
  #   #{ allow `routing_key`, `options` to be optional arguments while still supplying `callback`
  #   unless callback?
  #     if typeof options is 'function'
  #       callback = options
  #       options = null
  #     else if typeof routing_key is 'function' and (not options?)
  #       callback = routing_key
  #       routing_key = null
  #   #{ use the default values for `routing_key` and `options` if they aren't otherwise specified
  #   routing_key = @default_routing_key unless routing_key?
  #   options = @default_publish_options unless options?
  #   payload = @payload_converter(payload)
  #   @exchange.publish routing_key, payload, options, (error_occured)=>
  #     if error_occured
  #       callback?(error_occured)
  #     else
  #       callback?(null)
  #
  # on_error:(err)=>console.error "AMQPProducer encountered error",err


# ## Exports

# Exported as `AMQPProducer`.
exports.AMQPProducer = exports.AmqpProducer = AmqpProducer

# When loaded directly, use `AMQPProducer` to publish a simple message.
#
# Accepts up to 4 command line parameters:
#  - the payload (message contents)
#  - the routing key
#  - the exchange name
#  - the broker URI
#
if require.main is module
  payload  = (process.argv?[2]) ? 'Example Payload'
  key      = (process.argv?[3]) ? 'amqp-demo-queue'
  exchange_name = (process.argv?[4]) ? 'foobar' #'amq.topic'
  broker_url   = (process.argv?[5]) ? 'amqp://guest:guest@localhost:5672'
  producer = new AmqpProducer()
  # producer.set_default_publish_option("confirm", true)
  producer.connect broker_url, (err)->
    if err?
      console.error err
      process.exit 1
    else
      console.log "AmqpProducer connected to broker at \"#{broker_url}\"."
      producer.create_exchange exchange_name, {confirm:true}, (err)->
        if err?
          console.error err
          process.exit 1
        else
          console.log "AmqpProducer fetched or created exchange \"#{exchange_name}\"."
          producer.publish exchange_name, payload, key, {}, ()=>
            console.log "Confirmed."
            process.exit()
