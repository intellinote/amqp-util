################################################################################
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
LogUtil    = require('inote-util').LogUtil
process    = require 'process'
################################################################################
AmqpBase   = require(path.join(LIB_DIR, 'amqp-base')).AmqpBase
################################################################################
DEBUG      = /(^|,)((all)|(amqp-?util)|(amqp-?consumer))(,|$)/i.test process.env.NODE_DEBUG # add `amqp-util` or `amqp-consumer` to NODE_DEBUG to enable debugging output
LogUtil    = LogUtil.init({debug:DEBUG, prefix: "AmqpConsumer:"})
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

  constructor:(args...)->
    super(args...)

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
      LogUtil.tpdebug "Creating (or fetching) the queue named `#{queue_name}`..."
      @_make_or_get_queue queue_name, queue_options, (err, queue, queue_was_cached)=>
        if err?
          LogUtil.tpdebug "...encountered error:", err
          callback? err, queue, queue_name, undefined, undefined
        else unless queue?
          LogUtil.tpdebug "...no queue was generated for some reason, but also no error was generated."
          callback?(new Error("Unable to create queue for unknown reasons"), queue, queue_name)
        else
          if queue_was_cached
            LogUtil.tpdebug "...pre-existing queue was found in cache."
          else
            LogUtil.tpdebug "...queue was created or fetched from AMQP server."
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
      unless options?.ifUnused or options?.ifEmpty # when ifUnused or ifEmpty is set there doesn't seem to be any way to tell if the queue was actually destroyed, so keep the reference
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
      LogUtil.tpdebug "Binding queue named `#{queue_name}` to the exchange named `#{exchange_name}` with bind-pattern `#{bind_pattern}`..."
      called_back = false
      queue.once 'error', (err)=>
        unless called_back
          called_back = true
          LogUtil.tpdebug "...encountered error:", err
          callback?( err, queue, exchange_name, bind_pattern )
          callback = undefined
      queue.once 'queueBindOk', ()=>
        unless called_back
          called_back = true
          LogUtil.tpdebug "...queueBindOk."
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
      LogUtil.tpdebug "Unbinding queue named `#{queue_name}` from the exchange named `#{exchange_name}` with bind-pattern `#{bind_pattern}`..."
      called_back = false
      queue.once 'error', (err)=>
        unless called_back
          called_back = true
          LogUtil.tpdebug "...encountered error:", err
          callback?( err, queue, exchange_name, bind_pattern )
          callback = undefined
      queue.once 'queueUnbindOk', ()=>
        unless called_back
          called_back = true
          LogUtil.tpdebug "...queueUnbindOk."
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
      LogUtil.tpdebug "Subscribing to queue named #{queue_name}..."
      called_back = false
      basic_consume_ok = false
      timer_one = null
      timer_two = null
      queue.once 'error', (err)=>
        unless called_back
          called_back = true
          LogUtil.tpdebug "...encountered error:", err
          callback?( err, queue, queue_name, undefined )
          callback = undefined
      queue.once 'basicConsumeOk', ()=>
        basic_consume_ok = true
        DELAY_ONE = 1000
        DELAY_TWO = DELAY_ONE*2
        timer_one = AsyncUtil.wait DELAY_ONE, ()->
          unless called_back
            LogUtil.tpdebug "WARNING: basicConsumeOk event emitted but the consumerTag callback was not called within #{DELAY_ONE} milliseconds."
            AsyncUtil.cancel_wait timer_one
        timer_two = AsyncUtil.wait DELAY_TWO, ()->
          unless called_back
            LogUtil.tpwarn "WARNING: basicConsumeOk event emitted but the consumerTag callback was not called within #{DELAY_TWO} milliseconds. Calling-back regardless."
            AsyncUtil.cancel_wait timer_one
            AsyncUtil.cancel_wait timer_two
            called_back = true
            LogUtil.tpdebug "...subscribed but no consumerTag was returned in #{DELAY_TWO} milliseconds, giving up waiting on consumerTag."
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
          LogUtil.tpdebug "...subscribed with consumerTag #{ok?.consumerTag}."
          callback?( undefined, queue, queue_name, ok?.consumerTag )
          callback = undefined

  unsubscribe_from_queue:(subscription_tag, callback)=>
    LogUtil.tpdebug "Unsubscribing from consumerTag `#{subscription_tag}`..."
    [subscription_tag, chain] = @_resolve_subscription_tag_alias subscription_tag
    if chain?.length > 1
      LogUtil.tpdebug "...after de-aliasing, consumerTag resolved to `#{subscription_tag}` via chain #{JSON.stringify(chain)}..."
    queue = @get_queue_for_subscription_tag subscription_tag
    unless queue?
      LogUtil.tpdebug "...no associated queue found for `#{subscription_tag}`, calling back with error."
      callback? new Error("No queue found for subscription_tag #{subscription_tag}."), subscription_tag, chain
    else
      queue.unsubscribe(subscription_tag)
      for tag in chain
        delete @queue_names_by_subscription_tag[tag]
        delete @subscription_tag_aliases[tag]
      LogUtil.tpdebug "...successfully unsubscribed."
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
      #
      if typeof queue_or_queue_name is 'string'
        LogUtil.tpdebug "Subscribing to the queue named #{queue_or_queue_name} via the queue+bind+subscribe convenience method..."
      else
        LogUtil.tpdebug "Subscribing to a queue object (name=#{queue_or_queue_name?.__amqp_util_queue_name}?) via the queue+bind+subscribe convenience method..."
      @_maybe_create_queue queue_or_queue_name, queue_options, exchange_name, bind_pattern, (err, queue)=>
        if err?
          LogUtil.tpdebug "...encountered error:", err
          if callback?
            callback err
          else
            throw err
        else
          LogUtil.tpdebug "...queue created (and optionally bound) or fetched from cache. Subscribing."
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

  _on_connect:(callback)=>
    @queues_by_name ?= { }
    @queue_names_by_subscription_tag ?= { }
    @subscription_tag_aliases ?= {}
    @connection.on "tag.change", @_handle_tag_change
    callback?()

  _on_disconnect:(callback)=>
    if @connection?.removeListener?
      @connection.removeListener "tag.change", @_handle_tag_change
    @queues_by_name = undefined  # TODO cleanly unsub from queues?
    @queue_names_by_subscription_tag = undefined
    @subscription_tag_aliases = undefined
    callback?()


  _resolve_subscription_tag_alias:(tag)=>
    chain = []
    while @subscription_tag_aliases?[tag]?
      chain.push tag
      tag = @subscription_tag_aliases[tag]
    chain.push tag
    return [tag, chain]

  _handle_tag_change:(event)=>
    # if the given event is valid and referneces an oldConsumerTag we're tracking
    if event?.oldConsumerTag? and event?.consumerTag? and (@subscription_tag_aliases?[event.oldConsumerTag]? or @queue_names_by_subscription_tag?[event.oldConsumerTag]?)
      LogUtil.tpdebug "handling tag.change event #{JSON.stringify(event)}."
      if @subscription_tag_aliases?
        @subscription_tag_aliases[event.oldConsumerTag] = event.consumerTag
      if @queue_names_by_subscription_tag?
        @queue_names_by_subscription_tag[event.consumerTag] = @queue_names_by_subscription_tag[event.oldConsumerTag]

# ███████ ██    ██ ██████   ██████ ██       █████  ███████ ███████ ███████ ███████
# ██      ██    ██ ██   ██ ██      ██      ██   ██ ██      ██      ██      ██
# ███████ ██    ██ ██████  ██      ██      ███████ ███████ ███████ █████   ███████
#      ██ ██    ██ ██   ██ ██      ██      ██   ██      ██      ██ ██           ██
# ███████  ██████  ██████   ██████ ███████ ██   ██ ███████ ███████ ███████ ███████

# **AmqpStringConsumer** - *an `AmqpConsumer` that automatically converts inbound messages from Buffers into Strings.*
class AmqpStringConsumer extends AmqpConsumer

  constructor:(args...)->
    if args?.length > 0 and (typeof args[0] is 'object' or not args[0]?)
      connection = args.shift()
    if args?.length > 0 and (typeof args[0] is 'string' or not args[0]?)
      @encoding = args.shift()
    super(connection)

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
