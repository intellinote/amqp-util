# # AMQP Consumer

# An AMQP message consumer.

# ## Imports

# The `AMQPConsumer` is a thin wrapper around
# [`node-ampq`](https://github.com/postwait/node-amqp/)
# that can be used directly or as a base class for objects
# that subscribe to
# [AMQP](http://en.wikipedia.org/wiki/Advanced_Message_Queuing_Protocol)
# messages.
amqp = require 'amqp'

# ## Example of Use
#
#      var AMQPConsumer = require('amqp-util').AMQPConsumer;
#
#      var broker       = 'amqp://guest:guest@localhost:5672';
#      var queue        = 'amqp-demo-queue';
#
#      // Create a Consumer.
#      var consumer = new AMQPConsumer();
#
#      // Connect to the exchange, passing a callback to be invoked
#      // when the connection is established.
#      consumer.connect(broker, null, queue, {}, new function() {
#        console.log("Connected.");
#
#        // Define a "handler" method to be invoked when new messages
#        // are recieved.
#        var handler = console.log;
#
#        // Subscribe for incoming messages, passing in the
#        // message handler and callback to be invoked when
#        // when the subscription is established
#        consumer.subscribe(handler, new function() {
#          console.log("Now listening for messages.");
#          console.log("Press Ctrl-C to exit.");
#          consumer.main();
#        });
#
#      });
#

# ## Implemenation

# **AMQPConsumer** -

# `AMQPConsumer` can bind to a messages queue and invoke a
# callback method for any messages it receives.
class AMQPConsumer

  # **constructor** - *create a new `AMQPConsumer`.*
  #
  # Instantiates the consumer and
  # (optionally) connects to an AMQP exchange.
  #
  # When invoked with no arguments, the `AMQPConsumer` instance is created
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
  #  - `queue` is the name of the AMQP Queue on which to listen.
  #
  #  - `queue_options` is an optional map of additional AMQP queue options (see
  #    [node-ampq's documentation](https://github.com/postwait/node-amqp/#connectionqueuename-options-opencallback)
  #    for details).
  #
  #  - `callback` is an optional function that will be invoked once the consumer
  #    is ready for use.
  connect:(args...)=>
    # Parse out the method parameters, allowing optional values.
    connection = args.shift()
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'object')
      connection_options = args.shift()
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'string')
      queue = args.shift()
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'object')
      queue_options = args.shift()
    else
      queue_options = {}
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'function')
      callback = args.shift()
    @connection = amqp.createConnection({url:connection},connection_options)
    @connection.on 'error', (err)=>
      console.log "error",err
    @connection.once 'ready', ()=>
      @queue = @connection.queue queue, queue_options, (response...)=>
        callback?(null,response...)

  # **subscribe** - *start listening for incoming messages.*
  #
  # The method takes two or four parameters:
  #
  #  - `exchange_name` is the name of the AMQP exchange to bind to.
  #
  #  - `pattern` is a routing-pattern to be used to filter the messages. (See
  #    [node-ampq's documentation](https://github.com/postwait/node-amqp/#queuebindexchange-routing)
  #    for details.)
  #
  #  - `callback` is the "handle message" function to invoke when a message
  #    is received. The callback has the following signature:
  #
  #            callback(message, headers, deliveryInfo);
  #
  #    (See
  #    [node-ampq's documentation](https://github.com/postwait/node-amqp/#queuesubscribeoptions-listener)
  #    for details.)
  #
  #  - `done` is a callback method that is invoked when the subscription is
  #    established and active.
  #
  # The `exchange_name` and `pattern` are optional. When present, I will attempt
  # to bind to the specified exchange. When absent, the queue should already
  # be bound to some exchange.
  #
  subscribe:(args...)=>  # args:= exchange_name,pattern,subscribe_options,callback,done
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'string')
      exchange_name = args.shift()
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'string')
      pattern = args.shift()
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'object')
      subscribe_options = args.shift()
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'function')
      callback = args.shift()
    if args.length > 0 and ((not args[0]?) or typeof args[0] is 'function')
      done = args.shift()
    if exchange_name?
      @bind exchange_name, pattern, ()=>
        @_inner_subscribe(subscribe_options,callback,done)
    else
      @_inner_subscribe(subscribe_options,callback,done)

  _inner_subscribe:(subscribe_options,callback,done)=>
    @queue.once 'basicConsumeOk',()=>
      done?()
    @queue.subscribe(
      subscribe_options,
      (m,h,i,x...)=>callback(@message_converter(m),h,i,x...)
    ).addCallback(
      (ok)=>@consumer_tag = ok.consumerTag
    )

  bind:(exchange_name,pattern,callback)=>
    @queue.once 'queueBindOk', ()=>callback()
    @queue.bind(exchange_name,pattern)

  # **unsubscribe** - *stop listening for incoming messages.*
  unsubscribe:(callback)=>
    try
      @queue.unsubscribe(@consumer_tag).addCallback ()=>
        @consumer_tag = null
        callback?()
    catch err
      callback?(err)

  # **message_converter** - *a utility method used to convert the message before consuming.*
  #
  # (Default method is the identity function, no conversion occurs.)
  message_converter:(msg)=>msg

  # **main** - *keep the process open until killed via Ctrl-C (`SIGINT`).*
  main:(options = {})=>
    process.on 'SIGINT', =>
      console.log 'Received kill signal (SIGINT), shutting down.' unless options?.silent
      try
        @unsubscribe ()=>
          @connection.end()
          console.log 'Connection closed.' unless options?.silent
          process.exit()
      catch err
        console.error err
      setTimeout ()=>
        console.error "Unable to close connection in time. Forcefully shutting down." unless options?.silent
        process.exit(1)
      , 5*1000

# **AMQPStringConsumer** - *an `AMQPConsumer` that automatically converts inbound messages from Buffers into Strings.*
class AMQPStringConsumer extends AMQPConsumer

  # **constructor** - *create a new `AMQPStringConsumer`.*
  #
  # Accepts 0 to 7 parameters:
  #
  #  - `encoding` - the encoding to use when converting from bytes to characters.
  #  - others - when present, passed to `connect`
  #
  # When invoked with fewer than two, the `AMQPConsumer` instance is created
  # but no connection is established.  (A connection can be established later
  # by calling `connect`.)
  #
  # When 2 or more arguments *are* passed, they are immediately passed to the
  # `connect` function.
  #
  constructor:(@encoding,connection,connection_options,queue,queue_options,callback)->
    if typeof queue_options is 'function' and (not callback?)
      callback = queue_options
      queue_options = queue
      queue = connection_options
      connection_options = connection
      connection = @encoding
      @encoding = null
    if connection? or queue?
      super(connection,connection_options,queue,queue_options,callback)
    else
      super()

  # **message_converter** - *converts a Buffer to a String.*
  message_converter:(msg)=>
    if msg.data instanceof Buffer
      msg = msg.data.toString(@encoding)
    return msg

# The `AMQPConsumer`, `AMQPStringConsumer` and `AMQPJSONConsumer` types are exported.
exports.AMQPConsumer = AMQPConsumer
exports.AMQPStringConsumer = AMQPStringConsumer
# Note that `node-amqp` already handles the object-to-JSON case, but we'll
# publish a JSONConsumer for consistency.
exports.AMQPJSONConsumer = AMQPConsumer

#
# When loaded directly, use `AMQPConsumer` to listen for messages.
#
# Accepts up to 2 command line parameters:
#  - the broker URI
#  - the queue name
#
if require.main is module
  broker = (process.argv?[2]) ? 'amqp://guest:guest@localhost:5672'
  queue  = (process.argv?[3]) ? 'namqp-demo-queue'
  consumer = new AMQPConsumer broker, null, queue, {}, ()=>
    consumer.subscribe console.log, ()=>
      console.log "AMQPConsumer connected to broker at \"#{broker}\" and now listening for messages on queue \"#{queue}\"."
      console.log "Press Ctrl-C to exit."
      consumer.main()
