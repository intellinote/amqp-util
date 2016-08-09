# A simple command line tool for manipulating Exchanges and Queues within an
# AMQP-compatiable message broker.

# Run it with:
#
#     ./bin/amqp-cli --help
#
# or
#
#     coffee lib/app/amqp-cli.coffee --help
#
#
# or
#
#     node lib/app/amqp-cli.js --help
#
# for more information.

# ## Imports

#
amqp = require 'amqp'

# ## Implementation

# **AMQPCLI**
#
# There's no particular reason to package this utility as a class, we just liked it that way.
class AMQPCLI

  # **report_error** prints the given message to `console.error` then exits with the given `status`.
  report_error:(message_suffix,err,status=1)->
    console.error "[ERROR] Error encountered #{message_suffix}"
    console.error err
    console.error err.stack
    process.exit(status)

  # **report_success** prints the given message to `console.log` then exits with the given `status`.
  report_success:(type,message_suffix,status=0)->
    console.log "#{type} #{message_suffix}"
    process.exit(status)

  # **open_connection** creates a connection to the specified broker, adding a basic error handler before returning it.
  open_connection:(broker_url,connection_options)->
    connection = amqp.createConnection({url:broker_url},connection_options)
    connection.once 'error', (err)=>
      @report_error "while connecting to broker at \"#{broker_url}\".", err
    return connection

  # **log_connection** establishes a connection to the specified broker and then dumps a description of the connection to `console.log`.
  log_connection:(broker_url,connection_options)->
    connection = @open_connection(broker_url,connection_options)
    connection.once 'ready', ()=>
      console.log connection
      @report_success("[LOG]","logged.")

  # **log_exchange** dumps a description of the specified exchange to `console.log`.
  log_exchange:(broker_url,connection_options,exchange_name)->
    connection = @open_connection(broker_url,connection_options)
    connection.once 'ready', ()=>
      exchange_options = { passive:true, noDeclare:true }
      exchange = connection.exchange exchange_name, exchange_options, (exchange)=>
        console.log exchange
        @report_success("[LOG]","logged.")
      exchange.once 'error', (err)=>
        @report_error "Exchange named \"#{exchange_name}\" was NOT found.",err

  # **log_queue** dumps a description of the specified queue to `console.log`.
  log_queue:(broker_url,connection_options,queue_name)->
    connection = @open_connection(broker_url,connection_options)
    connection.once 'ready', ()=>
      queue_options = { passive:true, noDeclare:true }
      queue = connection.queue queue_name, queue_options, (queue)=>
        console.log queue
        @report_success("[LOG]","logged.")
      queue.once 'error', (err)=>
        @report_error "Queue named \"#{queue_name}\" was NOT found.",err

  # **create_exchange** connects to the specified broker and creates the specified exchange.
  create_exchange:(broker_url,connection_options,exchange_name,exchange_options)->
    connection = @open_connection(broker_url,connection_options)
    connection.once 'ready', ()=>
      exchange = connection.exchange exchange_name,exchange_options,(exchange)=>
        @report_success "[SUCCESS]","Exchange named \"#{exchange_name}\" created (or found)."
      exchange.once 'error', (err)=>
        @report_error "while creating exchange named \"#{exchange_name}\".", err

  # **check_exchange** connects to the specified broker and tests whether the specified exchange exists.
  check_exchange:(broker_url,connection_options,exchange_name)->
    connection = @open_connection(broker_url,connection_options)
    connection.once 'ready', ()=>
      exchange_options = { passive:true, noDeclare:true }
      exchange = connection.exchange exchange_name, exchange_options, (exchange)=>
        @report_success "[FOUND]","Exchange named \"#{exchange_name}\" was found."
      exchange.once 'error', (err)=>
        @report_success "[NOT FOUND]","Exchange named \"#{exchange_name}\" was NOT found."

  # **destroy_exchange** connects to the specified broker and deletes the specified exchange.
  destroy_exchange:(broker_url,connection_options,exchange_name,only_if_unused)->
    connection = @open_connection(broker_url,connection_options)
    connection.once 'ready', ()=>
      exchange_options = { passive:true, noDeclare:true }
      exchange = connection.exchange exchange_name, exchange_options, (exchange)=>
        exchange.once 'error', (err)=>
          @report_error "while destroying exchange named \"#{exchange_name}\"."
        exchange.once 'exchangeDeleteOk', (err)=>
          @report_success "[DELETED]","Exchange named \"#{exchange_name}\" deleted."
        exchange.destroy(only_if_unused)
      exchange.once 'error', (err)=>
        @report_success "[GONE]","Exchange named \"#{exchange_name}\" already didn't exist."

  # **create_queue** connects to the specified broker and creates the specified queue.
  create_queue:(broker_url,connection_options,queue_name,queue_options)->
    connection = @open_connection(broker_url,connection_options)
    connection.once 'ready', ()=>
      queue = connection.queue queue_name,queue_options,(queue)=>
        @report_success "[SUCCESS]","Queue named \"#{queue_name}\" created (or found)."
      queue.once 'error', (err)=>
        @report_error "while creating queue named \"#{queue_name}\".", err

  # **check_queue** connects to the specified broker and tests whether the specified queue exists.
  check_queue:(broker_url,connection_options,queue_name)->
    connection = @open_connection(broker_url,connection_options)
    connection.once 'ready', ()=>
      queue_options = { passive:true, noDeclare:true }
      queue = connection.queue queue_name, queue_options, (queue)=>
        @report_success "[FOUND]","Queue named \"#{queue_name}\" was found."
      queue.once 'error', (err)=>
        @report_success "[NOT FOUND]","Queue named \"#{queue_name}\" was NOT found."

  # **destroy_queue** connects to the specified broker and deletes the specified queue.
  destroy_queue:(broker_url,connection_options,queue_name,only_if_unused,only_if_empty)->
    connection = @open_connection(broker_url,connection_options)
    connection.once 'ready', ()=>
      queue_options = { passive:true, noDeclare:true }
      queue = connection.queue queue_name, queue_options, (queue)=>
        queue.once 'queueDeleteOk', (err)=>
          @report_success "[DELETED]","Queue named \"#{queue_name}\" deleted."
        queue.once 'error', (err)=>
          @report_error "while destroying queue named \"#{queue_name}\"."
        queue.destroy({ifUnused:only_if_unused,ifEmpty:only_if_empty})
      queue.once 'error', (err)=>
        @report_success "[GONE]","Queue named \"#{queue_name}\" already didn't exist."

  # **bind_queue** binds the specified queue to the specified exchange (by routing key).
  bind_queue:(broker_url,connection_options,queue_name,exchange_name,routing_key)->
    connection = @open_connection(broker_url,connection_options)
    connection.once 'ready', ()=>
      exchange_options = { passive:true, noDeclare:true }
      exchange = connection.exchange exchange_name, exchange_options, (exchange)=>
        queue_options = { passive:true, noDeclare:true }
        queue = connection.queue queue_name, queue_options, (queue)=>
          queue.once 'error', (err)=>
            @report_error "while binding queue named \"#{queue_name}\" to exchange named \"#{exchange_name}\" using routing key \"#{routing_key}\".",err
          queue.once 'queueBindOk', (err)=>
            @report_success "[BOUND]", "Queue named \"#{queue_name}\" was bound to exchange named \"#{exchange_name}\" using routing key \"#{routing_key}\"."
          queue.bind exchange, routing_key
        queue.once 'error', (err)=>
          @report_error "Queue named \"#{queue_name}\" was NOT found.", err
      exchange.once 'error', (err)=>
        @report_error "Exchange named \"#{exchange_name}\" was NOT found.", err

  # **unbind_queue** unbinds the specified queue from the specified exchange (by routing key).
  unbind_queue:(broker_url,connection_options,queue_name,exchange_name,routing_key)->
    connection = @open_connection(broker_url,connection_options)
    connection.once 'ready', ()=>
      exchange_options = { passive:true, noDeclare:true }
      exchange = connection.exchange exchange_name, exchange_options, (exchange)=>
        queue_options = { passive:true, noDeclare:true }
        queue = connection.queue queue_name, queue_options, (queue)=>
          queue.once 'error', (err)=>
            @report_error "while unbinding queue named \"#{queue_name}\" from exchange named \"#{exchange_name}\" using routing key \"#{routing_key}\".",err
          queue.once 'queueUnbindOk', (err)=>
            @report_success "[UNBOUND]", "Queue named \"#{queue_name}\" was unbound from exchange named \"#{exchange_name}\" using routing key \"#{routing_key}\"."
          queue.unbind exchange, routing_key
        queue.once 'error', (err)=>
          @report_error "Queue named \"#{queue_name}\" was NOT found.", err
      exchange.once 'error', (err)=>
        @report_error "Exchange named \"#{exchange_name}\" was NOT found.", err

  # **connection_options_from_argv** parses a node-amqp-compatible connection options map from the given command line parameters.
  connection_options_from_argv:(argv)->
    opts = {}
    return opts

  # **exchange_options_from_argv** parses a node-amqp-compatible exchange options map from the given command line parameters.
  exchange_options_from_argv:(argv)->
    opts = {}
    opts.type = argv.exchange.type if argv.exchange?.type?
    opts.passive = argv.exchange.passive if argv.exchange?.passive?
    opts.durable = argv.exchange.durable if argv.exchange?.durable?
    opts.confirm = argv.exchange.confirm if argv.exchange?.confirm?
    opts.autoDelete = argv.exchange['auto-delete'] if argv.exchange?['auto-delete']?
    opts.noDeclare = argv.exchange['no-declare'] if argv.exchange?['no-declare']?
    return opts

  # **queue_options_from_argv** parses a node-amqp-compatible queue options map from the given command line parameters.
  queue_options_from_argv:(argv)->
    opts = {}
    opts.passive = argv.queue.passive if argv.queue?.passive?
    opts.durable = argv.queue.durable if argv.queue?.durable?
    opts.exclusive = argv.queue.exclusive if argv.queue?.exclusive?
    opts.autoDelete = argv.queue['auto-delete'] if argv.queue?['auto-delete']?
    opts.durable = argv.queue.durable if argv.queue?.durable?
    opts.noDeclare = argv.queue['no-declare'] if argv.queue?['no-declare']?
    opts.arguments = JSON.parse(argv.queue.arguments) if argv.queue?.arguments?
    opts.closeChannelOnUnsubscribe = argv.queue['close-channel-on-unsubscribe'] if argv.queue?['close-channel-on-unsubscribe']?
    return opts

  # **main** reads the command line parameters and executes the appropriate command.
  main:()->
    # Set up the command line parameters using node-optimist.
    optimist = require('optimist').options({
      'h': { alias: 'help', boolean: true, describe: "Show help" }
      'b': { alias: 'broker', default: 'amqp://guest:guest@localhost:5672', describe: "Message broker to connect to" }
      'e.name': { alias: 'exchange.name', describe: "Exchange name." }
      'e.type': { alias: 'exchange.type', default: 'topic', describe: "If set when creating a new exchange, the exchange will be of the indicated type (direct, fanout or topic)." }
      'e.passive': { alias: 'exchange.passive', boolean:true, describe: "If set, the server will not create the exchange if it doesn't already exist." }
      'e.durable': { alias: 'exchange.durable', boolean: true, describe: "If set when creating a new exchange, the exchange will be marked as durable." }
      'e.confirm': { alias: 'exchange.confirm', boolean: true, describe: "If set when creating a new exchange, the exchange will be in confirm mode." }
      'e.auto-delete': { alias: 'exchange.auto-delete', boolean: true, describe: "If set, the exchange is deleted when there are no longer queues bound to it." }
      'e.only-if-unused': { alias: 'exchange.only-if-unused', boolean: true, describe: "If set when destroying an exchange, the exchange is deleted only if there are no queues bound to it." }
      'q.name': { alias: 'queue.name', describe: "Queue name." }
      'q.passive': { alias: 'queue.passive', boolean: true, describe: "If set, the server will not create the queue if it doesn't already exist." }
      'q.durable': { alias: 'queue.durable', boolean: true, describe: "If set when creating a new queue, the queue will be marked as durable." }
      #{ 'q.exclusive': { alias: 'queue.exclusive', boolean: false, describe: "Exclusive queues may only be consumed from the current connection (implies 'auto-delete')." } # exclusive isn't really meaningful here
      'q.auto-delete': { alias: 'queue.auto-delete', boolean: true, describe: "If set when creating an new queue, the queue is deleted when all consumers have finished using it." }
      'q.no-declare': { alias: 'queue.no-declare', boolean: true, describe: "If set, the queue will not be declared." } # ??? Is this the same as `passive`?
      'q.only-if-empty': { alias: 'queue.only-if-empty', boolean: true, describe: "If set when destroying a queue, the queue is deleted only if there are no messages pending within it." }
      'q.only-if-unused': { alias: 'queue.only-if-unused', boolean: true, describe: "If set when destroying a queue, the queue is deleted only if there are no consumers subscribed to it." }
      'k': { alias: 'routing-key', default:'*', describe: "When binding a queue to an exchange, the routing key value to bind with." }
    }).usage('Usage: $0 [check|create|destroy|bind|unbind] [exchange|queue] [OPTIONS]')
    argv = optimist.argv

    # Show a help message if needed.
    if optimist.argv.help or optimist.argv._.length is 0 or optimist.argv._[0] is 'help'
      console.log ""
      console.log "A command line tool for manipulating AMQP Queues and Exchanges."
      console.log ""
      optimist.showHelp()
      console.log ""
      console.log "Examples:"
      console.log " #{optimist['$0']} create exchange --e.name my-exchange"
      console.log "   creates a new exchange named \"my-exchange\" (unless it already exists)."
      console.log " #{optimist['$0']} create queue --q.name my-queue"
      console.log "   creates a new queue named \"my-queue\" (unless it already exists)."
      console.log " #{optimist['$0']} bind queue --q.name my-queue --e.name my-exchange"
      console.log "   binds the queue named \"my-queue\" to the exchange named \"my-exchange\"."
      console.log ""
      console.log "Also see"
      console.log "  https://github.com/postwait/node-amqp/"
      console.log "for more detail on the parameters above, or"
      console.log "  rabbitmqctl"
      console.log "for a more sophisticated client for working with a RabbitMQ broker."
      console.log ""
      process.exit()

    # Otherwise run the appropriate command (as stored in `argv._[0]` and `argv._[1]`).
    else
      broker = argv.broker
      conn_opts = @connection_options_from_argv(argv)
      switch optimist.argv._[0]
        when 'log'
          switch optimist.argv._[1]
            when 'exchange'
              unless argv.exchange?.name?.length > 0
                console.error "Exchange name is required when logging an exchange. Use --help for help."
                process.exit(1)
              else
                @log_exchange broker, conn_opts, argv.exchange.name
            when 'queue'
              unless argv.queue?.name?.length > 0
                console.error "Queue name is required when logging a queue. Use --help for help."
                process.exit(1)
              else
                @log_queue broker, conn_opts, argv.queue.name
            when 'connection','channel'
              @log_connection broker, conn_opts
            else
              console.error "OBJECT",optimist.argv._[1],"NOT RECOGNIZED HERE."
              process.exit(1)
        when 'bind'
          switch optimist.argv._[1]
            when 'queue'
              unless argv.queue?.name?.length > 0
                console.error "Queue name is required when binding a queue. Use --help for help."
                process.exit(1)
              unless argv.exchange?.name?.length > 0
                console.error "Exchange name is required when binding a queue. Use --help for help."
                process.exit(1)
              else
                @bind_queue broker, conn_opts, argv.queue.name, argv.exchange.name, argv['routing-key']
            else
              console.error "OBJECT",optimist.argv._[1],"NOT RECOGNIZED HERE."
              process.exit(1)
        when 'unbind'
          switch optimist.argv._[1]
            when 'queue'
              unless argv.queue?.name?.length > 0
                console.error "Queue name is required when unbinding a queue. Use --help for help."
                process.exit(1)
              unless argv.exchange?.name?.length > 0
                console.error "Exchange name is required when unbinding a queue. Use --help for help."
                process.exit(1)
              else
                @unbind_queue broker, conn_opts, argv.queue.name, argv.exchange.name, argv['routing-key']
            else
              console.error "OBJECT",optimist.argv._[1],"NOT RECOGNIZED HERE."
              process.exit(1)
        when 'create'
          switch optimist.argv._[1]
            when 'exchange'
              unless argv.exchange?.name?.length > 0
                console.error "Exchange name is required when creating an exchange. Use --help for help."
                process.exit(1)
              else
                opts = @exchange_options_from_argv(argv)
                @create_exchange broker, conn_opts, argv.exchange.name, opts
            when 'queue'
              unless argv.queue?.name?.length > 0
                console.error "Queue name is required when creating a queue. Use --help for help."
                process.exit(1)
              else
                opts = @queue_options_from_argv(argv)
                @create_queue broker, conn_opts, argv.queue.name, opts
            else
              console.error "OBJECT",optimist.argv._[1],"NOT RECOGNIZED HERE."
              process.exit(1)
        when 'check'
          switch optimist.argv._[1]
            when 'exchange'
              unless argv.exchange?.name?.length > 0
                console.error "Exchange name is required when checking an exchange. Use --help for help."
                process.exit(1)
              else
                @check_exchange broker, conn_opts, argv.exchange.name
            when 'queue'
              unless argv.queue?.name?.length > 0
                console.error "Queue name is required when checking a queue. Use --help for help."
                process.exit(1)
              else
                @check_queue broker, conn_opts, argv.queue.name
            else
              console.error "OBJECT",optimist.argv._[1],"NOT RECOGNIZED HERE."
              process.exit(1)
        when 'delete','destroy'
          switch optimist.argv._[1]
            when 'exchange'
              unless argv.exchange?.name?.length > 0
                console.error "Exchange name is required when destroying an exchange. Use --help for help."
                process.exit(1)
              else
                only_if_unused = argv.exchange['only-if-unused']
                @destroy_exchange broker, conn_opts, argv.exchange.name, only_if_unused
            when 'queue'
              unless argv.queue?.name?.length > 0
                console.error "Queue name is required when destroying a queue. Use --help for help."
                process.exit(1)
              else
                only_if_unused = argv.queue['only-if-unused']
                only_if_empty = argv.queue['only-if-empty']
                @destroy_queue broker, conn_opts, argv.queue.name, only_if_unused, only_if_empty
             else
              console.error "OBJECT",optimist.argv._[1],"NOT RECOGNIZED HERE."
              process.exit(1)
        else
          console.log "ACTION",optimist.argv._[0],"NOT RECOGNIZED HERE."
          process.exit(1)

# Run the `main` method when this file is loaded directly (rather than included via a `require` call).
if require.main is module
  cli = new AMQPCLI()
  cli.main()

exports.AMQPCLI = AMQPCLI
