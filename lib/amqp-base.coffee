amqp       = require 'amqp'

class AmqpBase

  constructor:()->
    undefined

  # Establish a new connection to the specified broker.
  #
  # Note that each `AmqpConsumer` instance can only have one connection at a time.
  #
  # Arguments:
  #   * `broker_url` - string-type broker URL (e.g., `amqp://guest:guest@localhost:5672`), optional
  #   * `connection_options - map of connection options (see `node-amqp.createConnection` for details), optional
  #   * `impl_options` - map of node-amqp-specific options (see `node-amqp.createConnection` for details), optional
  #   * `callback` - callback method with the signature `(err [,connection])`
  #   * `error_handler` - callback method that subscribes to `connection.on('error')` (optional); when missing a simple console.error-logging handler will be used
  #
  # One of `broker_url` or `connection_options.url` or `connection_options.host` (etc.) is required.
  #
  # Note that if the connection emits an `error` event before the `ready` event `callback(err)` will be invoked.
  # Any errors emitted after `ready` will be sent to the `error_hander`, if any.
  connect:(args...)=>
    # parse input parameters
    if args?.length > 0 and (typeof args[0] is 'string' or not args[0]?)
      broker_url = args.shift()
    if args?.length > 0 and (typeof args[0] is 'object' or not args[0]?)
      connection_options = args.shift()
    if args?.length > 0 and (typeof args[0] is 'object' or not args[0]?)
      impl_options = args.shift()
    if args?.length > 0 and (typeof args[0] is 'function' or not args[0]?)
      callback = args.shift()
    if callback? and args.length > 0 and (typeof args[0] is 'function' or not args[0]?)
      error_handler = args.shift()
    connection_options ?= { }
    impl_options ?= undefined
    if broker_url?
      connection_options.url = broker_url
    error_handler ?= (err)->
      console.error "ERROR in AmqpBase.connect:", err

    # check input parameters
    unless connection_options.url?
      callback? new Error("Expected a broker URL value.")
    else
      # confirm we're not already connected
      if @connection?
        callback? new Error("Already connected; please disconnect first.")
      else
        @queues_by_name ?= { }
        @queue_names_by_subscription_tag ?= { }
        # create the connection
        called_back = false
        @connection = amqp.createConnection connection_options, impl_options
        @connection.once 'error', (err)=>
          unless called_back
            called_back = true
            callback? err, undefined
            callback = undefined
        if error_handler?
          @connection.on 'error', error_handler
        @connection.once 'ready', ()=>
          unless called_back
            called_back = true
            callback? undefined, @connection
            callback = undefined
    return @connection

  disconnect:(callback)=>
    if @connection?.disconnect?
       @connection.disconnect()
       @connection = undefined
       @queues_by_name = undefined  # TODO cleanly unsub from queues?
       @queue_names_by_subscription_tag ?= { }
       callback?(undefined, true)
       return true
    else
       @connection = undefined
       @queues_by_name = undefined
       @queue_names_by_subscription_tag = undefined
       callback?(undefined, false)
       return false

exports.AMQPBase = exports.AmqpBase = AmqpBase
