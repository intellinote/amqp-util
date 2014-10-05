amqp                  = require 'amqp'
should                = require 'should'
fs                    = require 'fs'
path                  = require 'path'
HOMEDIR               = path.join(__dirname,'..')
LIB_COV               = path.join(HOMEDIR,'lib-cov')
LIB                   = path.join(HOMEDIR,'lib')
LIB_DIR               = if fs.existsSync(LIB_COV) then LIB_COV else LIB
AMQPConsumer          = require(path.join(LIB_DIR,'amqp-consumer')).AMQPConsumer
AMQPJSONConsumer      = require(path.join(LIB_DIR,'amqp-consumer')).AMQPJSONConsumer
AMQPStringConsumer    = require(path.join(LIB_DIR,'amqp-consumer')).AMQPStringConsumer
config                = require(path.join(LIB_DIR,'config')).config
config                = config.init({},{NODE_ENV:'unit-testing'})
TEST_BROKER           = config.get 'amqp:unit-test:broker'
TEST_QUEUE            = config.get 'amqp:unit-test:queue'
TEST_QUEUE_OPTIONS    = config.get 'amqp:unit-test:queue-options'
TEST_EXCHANGE         = config.get 'amqp:unit-test:exchange'
TEST_EXCHANGE_OPTIONS = config.get 'amqp:unit-test:exchange-options'
TEST_ROUTING_KEY      = config.get 'amqp:unit-test:routing-key'

describe 'AMQPConsumer',->

  beforeEach (done)=>
    @connection = amqp.createConnection({url:TEST_BROKER})
    @connection.once 'ready', ()=>
      @exchange = @connection?.exchange TEST_EXCHANGE, TEST_EXCHANGE_OPTIONS, ()=>
        done()

  afterEach (done)=>
    @exchange?.destroy(false)
    @exchange = null
    @connection?.end()
    @connection = null
    done()

  it 'can accept published messages',(done)=>
    received_count = 0
    amqpc = new AMQPConsumer TEST_BROKER, null, TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
      handler = (message,headers,info)=>
        received_count += 1
        message.data.toString().should.equal "my-test-message-#{received_count}"
        if received_count is 3
          amqpc.unsubscribe ()->
            done()
        else
          received_count.should.not.be.above 3
      amqpc.subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
        @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
        @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'

  it 'supports optional arguments in the constructor',(done)=>
    received_count = 0
    amqpc = new AMQPConsumer TEST_BROKER, TEST_QUEUE, ()=>
      handler = (message,headers,info)=>
        received_count += 1
        message.data.toString().should.equal "my-test-message-#{received_count}"
        if received_count is 3
          amqpc.unsubscribe ()->
            done()
        else
          received_count.should.not.be.above 3
      amqpc.subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
        @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
        @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'

  it 'can defer connection to the message broker',(done)=>
    received_count = 0
    amqpc = new AMQPConsumer()
    amqpc.connect TEST_BROKER, TEST_QUEUE, ()=>
      handler = (message,headers,info)=>
        received_count += 1
        message.data.toString().should.equal "my-test-message-#{received_count}"
        if received_count is 3
          amqpc.unsubscribe ()->
            done()
        else
          received_count.should.not.be.above 3
      amqpc.subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
        @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
        @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'

  it 'can use a pre-established queue without specifying an exchange',(done)=>
    queue = @connection.queue TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
      queue.once 'queueBindOk', ()=>
        received_count = 0
        amqpc = new AMQPConsumer TEST_BROKER, null, TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
          handler = (message,headers,info)=>
            received_count += 1
            message.data.toString().should.equal "my-test-message-#{received_count}"
            if received_count is 3
              amqpc.unsubscribe ()->
                queue.destroy()
                done()
            else
              received_count.should.not.be.above 3
          amqpc.subscribe handler, ()=>
            @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
            @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
            @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'
      queue.bind(TEST_EXCHANGE,TEST_ROUTING_KEY)


  it 'accepts "subscribe options" in subscribe method',(done)=>
    queue = @connection.queue TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
      queue.once 'queueBindOk', ()=>
        received_count = 0
        amqpc = new AMQPConsumer TEST_BROKER, null, TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
          handler = (message,headers,info)=>
            received_count += 1
            message.data.toString().should.equal "my-test-message-#{received_count}"
            if received_count is 3
              amqpc.unsubscribe ()->
                queue.destroy()
                done()
            else
              received_count.should.not.be.above 3
          amqpc.subscribe {exclusive:true}, handler, ()=>
            @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
            @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
            @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'
      queue.bind(TEST_EXCHANGE,TEST_ROUTING_KEY)

  it 'can accept a JSON-valued message as a JSON object',(done)=>
    amqpc = new AMQPConsumer TEST_BROKER, null, TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
      handler = (message,headers,info)->
        message.foo.should.equal 'bar'
        message.a.should.equal 1
        info.contentType.should.equal 'application/json'
        amqpc.unsubscribe ()->
          done()
      amqpc.subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, { foo:'bar', a:1 }

  it 'passes raw message from node-amqp to message handler',(done)=>
    amqpc = new AMQPConsumer TEST_BROKER, null, TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
      handler = (message,headers,info,raw)->
        message.foo.should.equal 'bar'
        message.a.should.equal 1
        info.contentType.should.equal 'application/json'
        should.exist raw
        amqpc.unsubscribe ()->
          done()
      amqpc.subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, { foo:'bar', a:1 }

  it 'supports a payload converter for transforming messages before they are consumed',(done)=>
    amqpc = new AMQPConsumer TEST_BROKER, null, TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
      amqpc.message_converter = (message)->message.data.toString().toUpperCase()
      handler = (message,headers,info)->
        message.should.equal "THE QUICK BROWN FOX JUMPED."
        amqpc.unsubscribe ()->
          done()
      amqpc.subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, "the quick brown fox jumped."

  it 'AMQPJSONConsumer accept a JSON-valued message as a JSON object',(done)=>
    amqpc = new AMQPJSONConsumer TEST_BROKER, null, TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
      handler = (message,headers,info)->
        message.foo.should.equal 'bar'
        message.a.should.equal 1
        info.contentType.should.equal 'application/json'
        amqpc.unsubscribe ()->
          done()
      amqpc.subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, { foo:'bar', a:1 }

  it 'AMQPStringConsumer can accept a Buffer-valued message as a String',(done)=>
    amqpc = new AMQPStringConsumer TEST_BROKER, null, TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
      handler = (message,headers,info)->
        message.should.equal "The quick brown fox jumped." #note that in the AMQPConsumer case, message.data.toString() would be needed instead
        amqpc.unsubscribe ()->
          done()
      amqpc.subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, "The quick brown fox jumped."
