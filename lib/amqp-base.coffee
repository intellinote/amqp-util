amqp       = require 'amqp'
LogUtil    = require('inote-util').LogUtil
DEBUG      = /(^|,)((all)|(amqp-?util)|(amqp-?base))(,|$)/i.test process.env.NODE_DEBUG # add `amqp-util` or `amqp-base` to NODE_DEBUG to enable debugging output
LogUtil    = LogUtil.init({debug:DEBUG, prefix: "AmqpBase:"})

class AmqpBase

  constructor:(@connection)->
    if @connection?
      LogUtil.tpdebug "Shared connection passed to AmqpBase constructor."
      @connection_shared = true
      @_on_connect()
    else
      @connection_shared = false

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
      LogUtil.tperr "amqp-connection emitted an error:", err
    # check input parameters
    unless connection_options.url?
      callback? new Error("Expected a broker URL value.")
    else
      # confirm we're not already connected
      if @connection?
        callback? new Error("Already connected; please disconnect first.")
      else
        LogUtil.tpdebug "Connecting to #{broker_url}..."
        # create the connection
        called_back = false
        @connection = amqp.createConnection connection_options, impl_options
        @connection.once 'error', (err)=>
          unless called_back
            called_back = true
            LogUtil.tpdebug "...encountered error while connecting:", err
            callback? err, undefined
            callback = undefined
        if error_handler?
          @connection.on 'error', error_handler
        @connection.once 'ready', ()=>
          @_on_connect ()->
            unless called_back
              called_back = true
              LogUtil.tpdebug "...successfully connected."
              callback? undefined, @connection
              callback = undefined
    return @connection

  disconnect:(force, callback)=>
    if typeof force is 'function' and not callback?
      callback = force
      force = undefined
    if @connection_shared and not force
      err = new Error("This class did not create the current connection and hence will not disconnect from it unless `true` is passed as the `force` parameter.")
      LogUtil.tpdebug "Asked to disconnect an amqp-connection that this class did not create.", err
      callback(err)
    else
      LogUtil.tpdebug "Disconnecting..."
      if @connection?.disconnect?
         @_on_disconnect ()=>
           @connection.disconnect()
           @connection_shared = false
           @connection = undefined
           LogUtil.tpdebug "...disconnected."
           callback?(undefined, true)
         return true
      else
         @_on_disconnect ()=>
           @connection_shared = false
           @connection = undefined
           LogUtil.tpdebug "...not connected in the first place."
           callback?(undefined, false)
         return false

  # hook for subclasses to clear or set state on connect
  _on_connect:(callback)->callback?()

  # hook for subclasses to clear or set state on disconnect
  _on_disconnect:(callback)->callback?()

  _object_is_queue:(obj)->
    return obj?.constructor?.name is 'Queue'

  _object_is_exchange:(obj)->
    return obj?.constructor?.name is 'Exchange'

exports.AMQPBase = exports.AmqpBase = AmqpBase
