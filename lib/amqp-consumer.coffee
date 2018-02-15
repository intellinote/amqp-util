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

# An AMQP message consumer.
#
# This class wraps a single connection to an AMQP message broker.
#
# It can be used to create queues, bind queues to exchnages and to subscribe to
# (new or pre-existing) queues.
#
# The typical usage pattern is as follows:
#
# ```
# broker_url = 'amqp://guest:guest@localhost:5672'
# exchange_name = "amq.topic"
# bind_pattern = "#.#"
#
# # create a new consumer instance and connect to the broker:
# consumer = new AmqpConsumer()
# consumer.connect broker_url, (err)->
#  if err?
#    console.error err
#  else
#    # set up a new queue and subscribe to it
#    consumer.subscribe undefined, exchange_name, bind_pattern, message_handler1, (err, queue, queue_name, subscription_tag)->
#      if err?
#        console.error err
#      else
#        console.log "Created queue named #{queue_name} and subscribed to it with tag #{subscription_tag}."
#        # create another subscriber to that same queue
#        consumer.subscribe queue_name, message_handler2, (err, queue2, queue_name2, subscription_tag2)->
#          if err?
#            console.error err
#          else
#            console.log "Created a second subscription on the queue named #{queue_name} and swith tag #{subscription_tag2}."
#            # create a subscriber to a different queue
#            consumer.subscribe "custom-name", message_handler3, (err, queue3, queue_name3, subscription_tag3)->
#              if err?
#                console.error err
#              else
#                console.log "Created queue named #{queue_name3} and subscribed to it with tag #{subscription_tag3}."
# ```
#
# And later:
#
# ```
# consumer.destroy_queue queue_name(()->undefined)
# ```
#
# or:
#
# ```
# consumer.disconnect(()->undefined)
# ```
#
class AmqpConsumer extends AmqpBase

  _on_connect:(callback)=>
    @queues_by_name ?= { }
    @queue_names_by_subscription_tag ?= { }
    callback?()

  _on_disconnect:(callback)=>
    @queues_by_name = undefined  # TODO cleanly unsub from queues?
    @queue_names_by_subscription_tag ?= { }
    callback?()

  @deprecation_warning_shown: false
  @always_show_deprecation_warning: false

  constructor:(args...)->
    if args? and args.length > 0
      if AmqpConsumer.always_show_deprecation_warning or not AmqpConsumer.deprecation_warning_shown
        console.error "WARNING: Passing arguments to the AmqpConsumer constructor is deprecated. Please use the new API."
        AmqpConsumer.deprecation_warning_shown = true
    super()

  # **message_converter** - *a utility method used to convert the message before consuming.*
  #
  # (Default method is the identity function, no conversion occurs.)
  message_converter:(msg)=>msg

  #  ██████  ██    ██ ███████ ██    ██ ███████ ███████
  # ██    ██ ██    ██ ██      ██    ██ ██      ██
  # ██    ██ ██    ██ █████   ██    ██ █████   ███████
  # ██ ▄▄ ██ ██    ██ ██      ██    ██ ██           ██
  #  ██████   ██████  ███████  ██████  ███████ ███████
  #     ▀▀

  # ensures the specified queue exists
  # args:
  #  - queue_name - name of the queue (optional)
  #  - queue_options - (optional)
  #  - exchange_name - (optional)
  #  - bind_pattern  - (optional)
  #  - callback - signature:(err, queue)
  # when exchange_name and/or bind_pattern are included the queue will automatically be bound to the specfied exchange
  create_queue:(args...)=>
    # parse args
    if args?.length > 0 and (typeof args[0] is 'string' or not args[0]?)
      queue_name = args.shift()
    if args?.length > 0 and (typeof args[0] is 'object' or not args[0]?)
      queue_options = args.shift()
    if args?.length > 0 and (typeof args[0] is 'string' or not args[0]?)
      exchange_name = args.shift()
    if args?.length > 0 and (typeof args[0] is 'string' or not args[0]?)
      bind_pattern = args.shift()
    if args?.length > 0 and (typeof args[0] is 'function' or not args[0]?)
      callback = args.shift()
    #
    if exchange_name? and not bind_pattern?
      bind_pattern = exchange_name
      exchange_name = null
    #
    queue_name ?= "q-#{process.pid}-#{Date.now()}-#{RandomUtil.random_alpha(6)}"
    #
    unless @connection?
      callback? new Error("Not connected."), undefined, undefined, undefined, undefined
      return undefined
    else
      @_make_or_get_queue queue_name, queue_options, (err, queue, queue_was_cached)=>
        if err?
          callback? err, queue, queue_name, undefined, undefined
        else unless queue?
          callback?(new Error("Unable to create queue for unknown reasons"), queue, queue_name)
        else
          if (not queue_was_cached) and (bind_pattern? or exchange_name?)
            @bind_queue_to_exchange queue, exchange_name, bind_pattern, (err, queue, exchange_name, bind_pattern)->
              callback? err, queue, queue_name, exchange_name, bind_pattern
          else
            callback? undefined, queue, queue_name, undefined, undefined
      return queue_name

  # an alias for `create_queue`
  get_queue:(args...)=>
    @create_queue args...

  destroy_queue:(queue_or_queue_name, options, callback)=>
    if typeof options is 'function' and not callback?
      callback = options
      options = undefined
    [queue, queue_name] = @_to_queue_queue_name_pair(queue_or_queue_name)
    unless queue?
      callback new Error("Queue #{queue_name} not known.")
    else
      queue.destroy(options)
      unless options.ifUnused or options.ifEmpty # when ifUnused or ifEmpty is set there doesn't seem to be any way to tell if the queue was actually destroyed, so keep the reference
        if queue_name?
          delete @queues_by_name[queue_name]
      callback undefined

  # ██████  ██ ███    ██ ██████  ██ ███    ██  ██████  ███████
  # ██   ██ ██ ████   ██ ██   ██ ██ ████   ██ ██       ██
  # ██████  ██ ██ ██  ██ ██   ██ ██ ██ ██  ██ ██   ███ ███████
  # ██   ██ ██ ██  ██ ██ ██   ██ ██ ██  ██ ██ ██    ██      ██
  # ██████  ██ ██   ████ ██████  ██ ██   ████  ██████  ███████

  bind_queue_to_exchange:(queue_or_queue_name, exchange_name, bind_pattern, callback)=>
    if typeof bind_pattern is 'function' and not callback?
      callback = bind_pattern
      bind_pattern = undefined
    if typeof exchange_name is 'string' and not bind_pattern?
      bind_pattern = exchange_name
      exchange_name = undefined
    exchange_name ?= 'amq.topic'
    [queue, queue_name] = @_to_queue_queue_name_pair queue_or_queue_name
    unless queue? and bind_pattern?
      callback?(new Error("Expected queue and bind-pattern"))
    else
      called_back = false
      queue.once 'error', (err)=>
        unless called_back
          called_back = true
          callback?( err, queue, exchange_name, bind_pattern )
          callback = undefined
      queue.once 'queueBindOk', ()=>
        unless called_back
          called_back = true
          callback?( undefined, queue, exchange_name, bind_pattern )
          callback = undefined
      queue.bind exchange_name, bind_pattern

  unbind_queue_from_exchange:(queue_or_queue_name, exchange_name, bind_pattern, callback)=>
    if typeof bind_pattern is 'function' and not callback?
      callback = bind_pattern
      bind_pattern = undefined
    if typeof exchange_name is 'string' and not bind_pattern?
      bind_pattern = exchange_name
      exchange_name = undefined
    exchange_name ?= 'amq.topic'
    [queue, queue_name] = @_to_queue_queue_name_pair queue_or_queue_name
    unless queue? and bind_pattern?
      callback?(new Error("Expected queue and bind-pattern"))
    else
      called_back = false
      queue.once 'error', (err)=>
        unless called_back
          called_back = true
          callback?( err, queue, exchange_name, bind_pattern )
          callback = undefined
      queue.once 'queueUnbindOk', ()=>
        unless called_back
          called_back = true
          callback?( undefined, queue, exchange_name, bind_pattern )
          callback = undefined
      queue.unbind exchange_name, bind_pattern

  # ███████ ██    ██ ██████  ███████  ██████ ██████  ██ ██████  ████████ ██  ██████  ███    ██ ███████
  # ██      ██    ██ ██   ██ ██      ██      ██   ██ ██ ██   ██    ██    ██ ██    ██ ████   ██ ██
  # ███████ ██    ██ ██████  ███████ ██      ██████  ██ ██████     ██    ██ ██    ██ ██ ██  ██ ███████
  #      ██ ██    ██ ██   ██      ██ ██      ██   ██ ██ ██         ██    ██ ██    ██ ██  ██ ██      ██
  # ███████  ██████  ██████  ███████  ██████ ██   ██ ██ ██         ██    ██  ██████  ██   ████ ███████

  # arguments: queue_or_queue_name, subscription_options, message_handler, callback
  # message_handler signature TODO document me
  # optional callback signature: (err, queue, queue_name, subscription_tag)
  subscribe_to_queue:(queue_or_queue_name, args... )=>
    # parse args
    [queue, queue_name] = @_to_queue_queue_name_pair queue_or_queue_name
    if args?.length > 0 and (typeof args[0] is 'object' or not args[0]?)
      subscription_options = args.shift()
    if args?.length > 0 and (typeof args[0] is 'function' or not args[0]?)
      message_handler = args.shift()
    if message_handler? and args?.length > 0 and (typeof args[0] is 'function' or not args[0]?)
      callback = args.shift()
    unless queue? and message_handler?
      callback?(new Error("Expected queue and message-handler"), undefined, undefined, undefined)
    else
      called_back = false
      basic_consume_ok = false
      timer_one = null
      timer_two = null
      queue.once 'error', (err)=>
        unless called_back
          called_back = true
          callback?( err, queue, queue_name, undefined )
          callback = undefined
      queue.once 'basicConsumeOk', ()=>
        basic_consume_ok = true
        DELAY_ONE = 1000
        DELAY_TWO = DELAY_ONE*2
        timer_one = AsyncUtil.wait DELAY_ONE, ()->
          unless called_back
            console.log "WARNING: basicConsumeOk event emitted but the consumerTag callback was not called within #{DELAY_ONE} milliseconds."
            AsyncUtil.cancel_wait timer_one
        timer_two = AsyncUtil.wait DELAY_TWO, ()->
          unless called_back
            console.log "WARNING: basicConsumeOk event emitted but the consumerTag callback was not called within #{DELAY_TWO} milliseconds. Calling-back regardless."
            AsyncUtil.cancel_wait timer_one
            AsyncUtil.cancel_wait timer_two
            called_back = true
            callback?( err, queue, queue_name, undefined )
            callback = undefined
      # console.log queue.subscribe(subscription_options, ((message,tail...)=>message_handler(@message_converter(message), tail...)))
      queue.subscribe(subscription_options, ((message,tail...)=>message_handler(@message_converter(message), tail...))).addCallback (ok)=>
        AsyncUtil.cancel_wait timer_one
        AsyncUtil.cancel_wait timer_two
        unless called_back
          called_back = true
          if ok?.consumerTag? and queue_name?
            @queue_names_by_subscription_tag[ok?.consumerTag] = queue_name
          callback?( undefined, queue, queue_name, ok?.consumerTag )
          callback = undefined

  unsubscribe_from_queue:(subscription_tag, callback)=>
    queue = @get_queue_for_subscription_tag subscription_tag
    unless queue?
      callback? new Error("No queue found for subscription_tag #{subscription_tag}.")
    else
      queue.unsubscribe(subscription_tag)
      delete @queue_names_by_subscription_tag[subscription_tag]
      callback? undefined

  # Subscribes the given `message_handler` to the specified queue, creating a
  # new queue if necessary.
  #
  # If the queue does not already exist we will attempt to create it.
  #
  # If exchange_name and bind_pattern are also provided, we will bind the queue
  # to the specified exchange.
  #
  # If the queue already exists, we will skip the creation and binding of the
  # queue and simply add the message_handler as a listener.
  #
  # If `queue_or_queue_name` is `null` a name will be generated for the queue.
  #
  # args:
  #  - queue_or_queue_name (required, can be null)
  #  - queue_options (optional)
  #  - exchange_name (optional)
  #  - bind_pattern (optional)
  #  - subscription_options (optional)
  #  - message_handler (required)
  #  - callback - (optional) signature:(err, queue, queue_name, subscription_tag)
  subscribe:(args...)->
    # parse args
    if args?.length > 0 and (typeof args[0] is 'string' or not args[0]?)
      queue_or_queue_name = args.shift()
    else if args?.length > 0 and typeof args[0] is 'object' and @_object_is_queue(args[0])
      queue_or_queue_name = args.shift()
    if args?.length > 0 and (typeof args[0] is 'object' or not args[0]?)
      queue_options = args.shift()
    if args?.length > 0 and (typeof args[0] is 'string' or not args[0]?)
      exchange_name = args.shift()
    if args?.length > 0 and (typeof args[0] is 'string' or not args[0]?)
      bind_pattern = args.shift()
    if args?.length > 0 and (typeof args[0] is 'object' or not args[0]?)
      subscription_options = args.shift()
    if args?.length > 0 and (typeof args[0] is 'function' or not args[0]?)
      message_handler = args.shift()
    if args?.length > 0 and (typeof args[0] is 'function' or not args[0]?)
      callback = args.shift()
    if exchange_name? and not bind_pattern?
      bind_pattern = exchange_name
      exchange_name = null
    # validate args
    unless message_handler?
      err = new Error("message hander is required here.")
      if callback?
        callback err
      else
        throw err
    else
      @_maybe_create_queue queue_or_queue_name, queue_options, exchange_name, bind_pattern, (err, queue)=>
        if err?
          if callback?
            callback err
          else
            throw err
        else
          @subscribe_to_queue (queue ? queue_name), subscription_options, message_handler, callback


  #  ██████  ████████ ██   ██ ███████ ██████
  # ██    ██    ██    ██   ██ ██      ██   ██
  # ██    ██    ██    ███████ █████   ██████
  # ██    ██    ██    ██   ██ ██      ██   ██
  #  ██████     ██    ██   ██ ███████ ██   ██

  # returns the queue with the specfied name (if any)
  get_queue_by_name:(queue_name)=>
    return @queues_by_name?[queue_name]

  # returns the name of the queue associated with the given consumer tag (if any)
  get_queue_name_for_subscription_tag:(subscription_tag)=>
    return @queue_names_by_subscription_tag?[subscription_tag]

  # returns the queue associated with the given consumer tag (if any)
  get_queue_for_subscription_tag:(subscription_tag)=>
    return @queues_by_name?[@get_queue_name_for_subscription_tag(subscription_tag)]

  # ██████  ██████  ██ ██    ██  █████  ████████ ███████
  # ██   ██ ██   ██ ██ ██    ██ ██   ██    ██    ██
  # ██████  ██████  ██ ██    ██ ███████    ██    █████
  # ██      ██   ██ ██  ██  ██  ██   ██    ██    ██
  # ██      ██   ██ ██   ████   ██   ██    ██    ███████

  # args:
  #  - queue_or_queue_name
  #  - queue_options - (optional)
  #  - exchange_name - (optional)
  #  - bind_pattern  - (optional)
  #  - callback - signature:(err, queue)
  _maybe_create_queue:(queue_or_queue_name, args..., callback)=>
    [queue, queue_name] = @_to_queue_queue_name_pair queue_or_queue_name
    if queue?
      callback? undefined, queue, true
    else
      @create_queue queue_name, args..., callback

  _to_queue_queue_name_pair:(queue_or_queue_name)=>
    if typeof queue_or_queue_name is 'string'
      queue_name = queue_or_queue_name
      queue = @queues_by_name[queue_or_queue_name] ? undefined
    else if @_object_is_queue queue_or_queue_name
      queue = queue_or_queue_name
      queue_name = queue?.__amqp_util_queue_name ? undefined
    else
      queue_name = undefined
      queue = undefined
    return [queue, queue_name]

  _make_or_get_queue:(queue_name, queue_options, callback)=>
    if @queues_by_name?[queue_name]?
      callback? undefined, @queues_by_name[queue_name], true
    else
      args_to_pass = []
      args_to_pass.push queue_name
      if queue_options?
        args_to_pass.push queue_options
      @connection.queue args_to_pass..., (queue)=>
        if queue?
          @queues_by_name[queue_name] = queue
          queue.__amqp_util_queue_name = queue_name
        callback? undefined, queue, false


  ##############################################################################
  ##############################################################################
  ##############################################################################
  # ##############################################################################
  #
  #   # if typeof impl_options is 'function' and not callback?
  #   #   callback = impl_options
  #   #   impl_options = null
  #   # if typeof connection_options is 'function' and not callback?
  #   #   callback = connection_options
  #   #   connection_options = null
  #   # if typeof connection_options is 'function' and not callback?
  #   #   callback = connection_options
  #   #   connection_options = null
  #   # if typeof broker_url isnt 'string' and not connection_options?
  #   #   connection_options = broker_url
  #   #   broker_url = null
  #   #
  #   # @connection = amqp.createConnection({url:connection},connection_options)
  #   # @connection.on 'error', (err)=>
  #   #   console.error "error",err
  #   # @connection.once 'ready', ()=>
  #   #   @queue = @connection.queue queue, queue_options, (response...)=>
  #   #     callback?(null,response...)
  #   #
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
  # #  - `queue` is the name of the AMQP Queue on which to listen.
  # #
  # #  - `queue_options` is an optional map of additional AMQP queue options (see
  # #    [node-ampq's documentation](https://github.com/postwait/node-amqp/#connectionqueuename-options-opencallback)
  # #    for details).
  # #
  # #  - `callback` is an optional function that will be invoked once the consumer
  # #    is ready for use.
  # old_connect:(args...)=>
  #   if AmqpConsumer.always_show_deprecation_warning or not AmqpConsumer.deprecation_warning_shown
  #     console.error "WARNING: The AmqpConsumer.old_connect method is deprecated. Please use the new API."
  #     AmqpConsumer.deprecation_warning_shown = true
  #   # Parse out the method parameters, allowing optional values.
  #   connection = args.shift()
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'object')
  #     connection_options = args.shift()
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'string')
  #     queue = args.shift()
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'object')
  #     queue_options = args.shift()
  #   else
  #     queue_options = {}
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'function')
  #     callback = args.shift()
  #   @connection = amqp.createConnection({url:connection},connection_options)
  #   @connection.on 'error', (err)=>
  #     console.log "error",err
  #   @connection.once 'ready', ()=>
  #     @queue = @connection.queue queue, queue_options, (response...)=>
  #       callback?(null,response...)
  #
  # # **subscribe** - *start listening for incoming messages.*
  # #
  # # The method takes two or four parameters:
  # #
  # #  - `exchange_name` is the name of the AMQP exchange to bind to.
  # #
  # #  - `pattern` is a routing-pattern to be used to filter the messages. (See
  # #    [node-ampq's documentation](https://github.com/postwait/node-amqp/#queuebindexchange-routing)
  # #    for details.)
  # #
  # #  - `callback` is the "handle message" function to invoke when a message
  # #    is received. The callback has the following signature:
  # #
  # #            callback(message, headers, deliveryInfo);
  # #
  # #    (See
  # #    [node-ampq's documentation](https://github.com/postwait/node-amqp/#queuesubscribeoptions-listener)
  # #    for details.)
  # #
  # #  - `done` is a callback method that is invoked when the subscription is
  # #    established and active.
  # #
  # # The `exchange_name` and `pattern` are optional. When present, I will attempt
  # # to bind to the specified exchange. When absent, the queue should already
  # # be bound to some exchange.
  # #
  # old_subscribe:(args...)=>  # args:= exchange_name,pattern,subscribe_options,callback,done
  #   if AmqpConsumer.always_show_deprecation_warning or not AmqpConsumer.deprecation_warning_shown
  #     console.error "WARNING: The AmqpConsumer.old_subscribe method is deprecated. Please use the new API."
  #     AmqpConsumer.deprecation_warning_shown = true
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'string')
  #     exchange_name = args.shift()
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'string')
  #     pattern = args.shift()
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'object')
  #     subscribe_options = args.shift()
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'function')
  #     callback = args.shift()
  #   if args.length > 0 and ((not args[0]?) or typeof args[0] is 'function')
  #     done = args.shift()
  #   if exchange_name?
  #     @old_bind exchange_name, pattern, ()=>
  #       @_inner_subscribe(subscribe_options,callback,done)
  #   else
  #     @_inner_subscribe(subscribe_options,callback,done)
  #
  # _inner_subscribe:(subscribe_options,callback,done)=>
  #   @queue.once 'basicConsumeOk',()=>
  #     done?()
  #   @queue.subscribe(
  #     subscribe_options,
  #     (m,h,i,x...)=>callback(@message_converter(m),h,i,x...)
  #   ).addCallback(
  #     (ok)=>@subscription_tag = ok.consumerTag
  #   )
  #
  # old_bind:(exchange_name,pattern,callback)=>
  #   if AmqpConsumer.always_show_deprecation_warning or not AmqpConsumer.deprecation_warning_shown
  #     console.error "WARNING: The AmqpConsumer.old_bind method is deprecated. Please use the new API."
  #     AmqpConsumer.deprecation_warning_shown = true
  #   @queue.once 'queueBindOk', ()=>callback()
  #   @queue.bind(exchange_name,pattern)
  #
  # # **unsubscribe** - *stop listening for incoming messages.*
  # old_unsubscribe:(callback)=>
  #   if AmqpConsumer.always_show_deprecation_warning or not AmqpConsumer.deprecation_warning_shown
  #     console.error "WARNING: The AmqpConsumer.old_unsubscribe method is deprecated. Please use the new API."
  #     AmqpConsumer.deprecation_warning_shown = true
  #   try
  #     @queue.unsubscribe(@subscription_tag).addCallback ()=>
  #       @subscription_tag = null
  #       callback?()
  #   catch err
  #     callback?(err)

# ███████ ██    ██ ██████   ██████ ██       █████  ███████ ███████ ███████ ███████
# ██      ██    ██ ██   ██ ██      ██      ██   ██ ██      ██      ██      ██
# ███████ ██    ██ ██████  ██      ██      ███████ ███████ ███████ █████   ███████
#      ██ ██    ██ ██   ██ ██      ██      ██   ██      ██      ██ ██           ██
# ███████  ██████  ██████   ██████ ███████ ██   ██ ███████ ███████ ███████ ███████

# **AmqpStringConsumer** - *an `AmqpConsumer` that automatically converts inbound messages from Buffers into Strings.*
class AmqpStringConsumer extends AmqpConsumer

  # **constructor** - *create a new `AmqpStringConsumer`.*
  #
  # Accepts 0 to 7 parameters:
  #
  #  - `encoding` - the encoding to use when converting from bytes to characters.
  #  - others - when present, passed to `connect`
  #
  # When invoked with fewer than two, the `AmqpConsumer` instance is created
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


# ███████ ██   ██ ██████   ██████  ██████  ████████ ███████
# ██       ██ ██  ██   ██ ██    ██ ██   ██    ██    ██
# █████     ███   ██████  ██    ██ ██████     ██    ███████
# ██       ██ ██  ██      ██    ██ ██   ██    ██         ██
# ███████ ██   ██ ██       ██████  ██   ██    ██    ███████

# The `AmqpConsumer`, `AmqpStringConsumer` and `AMQPJSONConsumer` types are exported.
exports.AMQPConsumer       = exports.AmqpConsumer       = AmqpConsumer
exports.AMQPStringConsumer = exports.AmqpStringConsumer = AmqpStringConsumer
exports.AMQPJSONConsumer   = exports.AmqpJsonConsumer   = AmqpConsumer # Note that `node-amqp` already handles the object-to-JSON case, but we'll publish a JSONConsumer for consistency.



# ███    ███  █████  ██ ███    ██
# ████  ████ ██   ██ ██ ████   ██
# ██ ████ ██ ███████ ██ ██ ██  ██
# ██  ██  ██ ██   ██ ██ ██  ██ ██
# ██      ██ ██   ██ ██ ██   ████

#
# When loaded directly, use `AmqpConsumer` to listen for messages.
#
# Accepts up to 2 command line parameters:
#  - the broker URI
#  - the queue name
#
# if require.main is module
#   broker = (process.argv?[2]) ? 'amqp://guest:guest@localhost:5672'
#   queue  = (process.argv?[3]) ? 'namqp-demo-queue'
#   consumer = new AmqpConsumer broker, null, queue, {}, ()=>
#     consumer.subscribe console.log, ()=>
#       console.log "AmqpConsumer connected to broker at \"#{broker}\" and now listening for messages on queue \"#{queue}\"."
#       console.log "Press Ctrl-C to exit."
#       consumer.main()

if require.main is module
  broker_url = (process.argv?[2]) ? 'amqp://guest:guest@localhost:5672'
  queue_name  = (process.argv?[3]) ? undefined #'namqp-demo-queue'
  consumer = new AmqpConsumer()
  consumer.connect broker_url, (err, x...)=>
    consumer.create_queue queue_name, null, "#.#", (err, queue, queue_name, x...)=>
      if queue? and not err?
        consumer.subscribe_to_queue queue, console.log, ()=>
          console.log "AmqpConsumer connected to broker at \"#{broker_url}\" and now listening for messages on queue \"#{queue_name}\"."
          console.log "Press Ctrl-C to exit."
          process.on 'SIGINT', ()->
            console.log 'Received kill signal (SIGINT), shutting down.'
            process.exit(0)
      else
        process.exit 1
