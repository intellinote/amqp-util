# # AMQP Producer

# An AMQP message publisher.

# The `AMQPProducer` is a thin wrapper around
# [`node-ampq`](https://github.com/postwait/node-amqp/)
# that can be used directly or as a base class for objects
# that publish
# [AMQP](http://en.wikipedia.org/wiki/Advanced_Message_Queuing_Protocol)
# messages.
amqp = require 'amqp'

# ## Example of Use
#
#      var AMQPProducer = require('amqp-util').AMQPProducer;
#
#      var payload      = 'Example Payload';
#      var key          = 'amqp-demo-queue';
#      var exchange     = '';
#      var broker       = 'amqp://guest:guest@localhost:5672';
#
#      // Create a Producer.
#      var producer = new AMQPProducer();
#
#      // Connect to the exchange, passing a callback to be invoked
#      // when the connection is established.
#      producer.connect(broker, null, exchange, {confirm:true}, new function() {
#        console.log("Connected.");
#
#        // Publish a message, passing a callback to be invoked when
#        // when the message is delivered to the exchange.
#        producer.publish({payload:payload}, key, {}, new function() {
#          console.log("Confirmed.");
#          console.log("Published the payload.");
#        });
#
#      });
#

# ## Implemenation

# **AMQPProducer**
class AMQPProducer

  # **constructor** - *create a new `AMQPProducer`.*
  #
  # Instantiates the producer and
  # (optionally) connects to an AMQP exchange.
  #
  # When invoked with no arguments, the `AMQPProducer` instance is created
  # but no connection is established.  (A connection can be established later
  # by calling `connect`.)
  #
  # When method arguments *are* passed, they are immediately passed to the
  # `connect` function.
  constructor:(args...)->
    if args? and args.length > 0
      @connect(args...)

  # **connect** - *connects to a new or existing AMQP exchange.*
  #
  # Accepts four arguments:
  #
  #  - `broker_url` is the URL by which to connect to the message broker
  #    (e.g., `amqp://guest:guest@localhost:5672`)
  #
  #  - `connection_options` is a partially AMQP-implementation-specific map of
  #    options. See
  #    [postwait's node-amqp documentation](https://github.com/postwait/node-amqp/#connection-options-and-url)
  #    for details.
  #
  #  - `exchange_name` is the name of the AMQP Exchange to which the
  #    producer will post messages.
  #
  #  - `exchange_options` is a map of options to be used when creating the
  #    Exchange (if needed). See
  #    [postwait's node-amqp documentation](https://github.com/postwait/node-amqp/#connectionexchangename-options-opencallback)
  #    for details.
  #
  #  - `callback` is a method that is invoked when this producer is ready to
  #    start publishing, it has the signature `(err,producer)`.
  connect:(args...)=>
    # Parse out the method parameters, allowing optional values.
    broker_url = args.shift()
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'object')
      connection_options = args.shift()
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'string')
      exchange_name = args.shift()
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'object')
      exchange_options = args.shift()
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'function')
      callback = args.shift()
    # Now connect.
    @connection = amqp.createConnection({url:broker_url},connection_options)
    @connection.once 'ready', ()=>
      @exchange = @connection.exchange exchange_name, exchange_options
      @exchange.on 'error', @on_error
      @exchange.once "open", ()=>
        callback?(null,this)

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

  # **publish** - *post a message to the message queue.*
  #
  # The message is posted to the current `exchange`, as configured in the
  # constructor or `connect` method.
  #
  #  - `payload` is the message itself, typically a Buffer or Object
  #
  #  - `routing_key` - the routing key (as used by direct and topic exchanges).
  #    When not specified, the value of `default_routing_key` is used.
  #
  #  - `options` a map of message publishing options. When not specified,
  #    the value of `default_publish_options` is used. See
  #    [postwait's node-amqp documentation](https://github.com/postwait/node-amqp/#exchangepublishroutingkey-message-options-callback)
  #    for details.
  #
  #  - `callback` is an optional callback method that is used with the Exchange
  #    is operating in "confirm" mode.  If an error occured the `callback` will
  #    be passed a single non-`null` argument.
  #
  publish:(payload,routing_key,options,callback)=>
    #{ allow `routing_key`, `options` to be optional arguments while still supplying `callback`
    unless callback?
      if typeof options is 'function'
        callback = options
        options = null
      else if typeof routing_key is 'function' and (not options?)
        callback = routing_key
        routing_key = null
    #{ use the default values for `routing_key` and `options` if they aren't otherwise specified
    routing_key = @default_routing_key unless routing_key?
    options = @default_publish_options unless options?
    payload = @payload_converter(payload)
    @exchange.publish routing_key, payload, options, (error_occured)=>
      if error_occured
        callback?(error_occured)
      else
        callback?(null)

  on_error:(err)=>console.error "AMQPProducer encountered error",err


# ## Exports

# Exported as `AMQPProducer`.
exports.AMQPProducer = AMQPProducer

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
  exchange = (process.argv?[4]) ? ''
  broker   = (process.argv?[5]) ? 'amqp://guest:guest@localhost:5672'
  producer = new AMQPProducer broker, null, exchange, {confirm:true}, ()=>
    console.log "AMQPProducer connected to broker at \"#{broker}\"."
    producer.publish {payload:payload}, key, {}, ()=>
      console.log "Confirmed."
    console.log "AMQPProducer published the payload \"#{payload}\" using the routing key \"#{key}\" to the exchange named \"#{exchange}\"."
    process.exit()
