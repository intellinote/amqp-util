amqp                  = require 'amqp'
should                = require 'should'
assert                = require 'assert'
fs                    = require 'fs'
path                  = require 'path'
HOMEDIR               = path.join(__dirname,'..')
LIB_COV               = path.join(HOMEDIR,'lib-cov')
LIB                   = path.join(HOMEDIR,'lib')
LIB_DIR               = if fs.existsSync(LIB_COV) then LIB_COV else LIB
AMQPProducer          = require(path.join(LIB_DIR,'amqp-producer')).AMQPProducer
config                = require('inote-util').config.init({},{NODE_ENV:'unit-testing'})
TEST_BROKER           = config.get 'amqp:unit-test:broker'
TEST_QUEUE            = config.get 'amqp:unit-test:queue'
TEST_QUEUE_OPTIONS    = config.get 'amqp:unit-test:queue-options'
TEST_EXCHANGE         = config.get 'amqp:unit-test:exchange'
TEST_EXCHANGE_OPTIONS = config.get 'amqp:unit-test:exchange-options'
TEST_ROUTING_KEY      = config.get 'amqp:unit-test:routing-key'

describe 'AMQPProducer',->

  beforeEach (done)=>
    @connection = amqp.createConnection url:TEST_BROKER
    @connection.once 'ready', ()=>
      @exchange = @connection?.exchange TEST_EXCHANGE, TEST_EXCHANGE_OPTIONS, ()=>
        @queue = @connection?.queue TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
          done()

  afterEach (done)=>
    @queue?.destroy(false)
    @queue = null
    @exchange?.destroy(false)
    @exchange = null
    @connection?.end()
    @connection = null
    done()

  it "can publish messages",(done)=>
    # Thanks to the magic of node.js callbacks, this test case reads backwards.

    # In a moment we'll subscribe to messages from the Queue.
    # Once our subscription is set up, we will publish a couple of messages.
    @queue.once 'basicConsumeOk',()=>
      amqpp = new AMQPProducer()
      amqpp.connect TEST_BROKER, (err)=>
        assert.ok not err?, err
        amqpp.create_exchange TEST_EXCHANGE, TEST_EXCHANGE_OPTIONS, (err)=>
          assert.ok not err?, err
          amqpp.publish TEST_EXCHANGE, {body:"test-message"}, TEST_ROUTING_KEY, (err)->
            should.not.exist err
          amqpp.publish TEST_EXCHANGE, {body:"test-message"}, TEST_ROUTING_KEY, (err)->
            should.not.exist err

    # The `received` array will contain the messages that have been received by our handler.
    received = []

    # In a moment we'll bind the test Queue to the Exchange.
    # Once we've bound the Queue, we'll subscribe to incoming messages
    # with a handler that validates the data.
    @queue.once 'queueBindOk', ()=>
      consumer_tag = null
      handler = (message,headers,info)=>
        received.push { message:message, headers:headers, info:info }
        if received.length is 2
          received[0].message.body.should.equal 'test-message'
          received[1].message.body.should.equal 'test-message'
          done()
        else
          received.length.should.be.above 0
          received.length.should.not.be.above 2
      @queue.subscribe(handler)
    # Now we can bind the Queue to the Exchange (triggering the callbacks above).
    @queue.bind(TEST_EXCHANGE, TEST_ROUTING_KEY)

  it "supports a default routing key",(done)=>
    @queue.once 'basicConsumeOk',()=>
      amqpp = new AMQPProducer()
      amqpp.connect TEST_BROKER, (err)=>
        assert.ok not err?, err
        amqpp.create_exchange TEST_EXCHANGE, TEST_EXCHANGE_OPTIONS, (err)=>
          amqpp.default_routing_key = TEST_ROUTING_KEY
          amqpp.publish TEST_EXCHANGE, "test-message"
    @queue.once 'queueBindOk', ()=>
      @queue.subscribe (message,headers,info)->
        message.data.toString().should.equal 'test-message'
        done()
    @queue.bind(TEST_EXCHANGE, TEST_ROUTING_KEY)

  it "supports default publishing options",(done)=>
    @queue.once 'basicConsumeOk',()=>
      amqpp = new AMQPProducer()
      amqpp.connect TEST_BROKER, (err)=>
        assert.ok not err?, err
        amqpp.create_exchange TEST_EXCHANGE, TEST_EXCHANGE_OPTIONS, (err)=>
          assert.ok not err?, err
          amqpp.set_default_publish_header "Foo", "Bar"
          amqpp.publish TEST_EXCHANGE, "test-messageX", TEST_ROUTING_KEY
    @queue.once 'queueBindOk', ()=>
      @queue.subscribe (message,headers,info)->
        message.data.toString().should.equal 'test-messageX'
        headers.Foo.should.equal 'Bar'
        done()
    @queue.bind(TEST_EXCHANGE, TEST_ROUTING_KEY)

  it "supports a payload converter that changes the message before it is published.",(done)=>
    @queue.once 'basicConsumeOk',()=>
      amqpp = new AMQPProducer()
      amqpp.connect TEST_BROKER, (err)=>
        assert.ok not err?, err
        amqpp.create_exchange TEST_EXCHANGE, TEST_EXCHANGE_OPTIONS, (err)=>
          assert.ok not err?, err
          amqpp.payload_converter = (str)->str.toUpperCase()
          amqpp.publish TEST_EXCHANGE, "test-message", TEST_ROUTING_KEY
    @queue.once 'queueBindOk', ()=>
      @queue.subscribe (message,headers,info)->
        message.data.toString().should.equal 'TEST-MESSAGE'
        done()
    @queue.bind(TEST_EXCHANGE, TEST_ROUTING_KEY)
