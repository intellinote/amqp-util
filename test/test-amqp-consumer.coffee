amqp                  = require 'amqp'
should                = require 'should'
assert                = require 'assert'
fs                    = require 'fs'
path                  = require 'path'
HOMEDIR               = path.join(__dirname,'..')
LIB_COV               = path.join(HOMEDIR,'lib-cov')
LIB                   = path.join(HOMEDIR,'lib')
LIB_DIR               = if fs.existsSync(LIB_COV) then LIB_COV else LIB
AMQPConsumer          = require(path.join(LIB_DIR,'amqp-consumer')).AMQPConsumer
AMQPJSONConsumer      = require(path.join(LIB_DIR,'amqp-consumer')).AMQPJSONConsumer
AMQPStringConsumer    = require(path.join(LIB_DIR,'amqp-consumer')).AMQPStringConsumer
config                = require('inote-util').config.init({},{NODE_ENV:'unit-testing'})
TEST_BROKER           = config.get 'amqp:unit-test:broker'
TEST_QUEUE            = config.get 'amqp:unit-test:queue'
TEST_QUEUE_2          = TEST_QUEUE + ":2"
TEST_QUEUE_OPTIONS    = config.get 'amqp:unit-test:queue-options'
TEST_EXCHANGE         = config.get 'amqp:unit-test:exchange'
TEST_EXCHANGE_OPTIONS = config.get 'amqp:unit-test:exchange-options'
TEST_ROUTING_KEY      = config.get 'amqp:unit-test:routing-key'


describe 'AMQPConsumer (new methods)',->

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
    amqpc = new AMQPConsumer()
    subscription_tag = null
    amqpc.connect TEST_BROKER, (err)=>
      assert.ok not err?, err
      amqpc.queue TEST_QUEUE, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, (err)=>
        assert.ok not err?, err
        handler = (message,headers,info)=>
          received_count += 1
          message.data.toString().should.equal "my-test-message-#{received_count}"
          if received_count is 3
            amqpc.unsubscribe_from_queue subscription_tag, (err)->
              assert.ok not err?, err
              done()
          else
            received_count.should.not.be.above 3
        amqpc.subscribe_to_queue TEST_QUEUE, handler, (err, queue, queue_name, st)=>
          assert.ok not err?, err
          assert.ok st?
          subscription_tag = st
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'

  it 'allows subscription options in subscribe call',(done)=>
    received_count = 0
    amqpc = new AMQPConsumer()
    subscription_tag = null
    amqpc.connect TEST_BROKER, (err)=>
      assert.ok not err?, err
      amqpc.queue TEST_QUEUE, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, (err)=>
        assert.ok not err?, err
        handler = (message,headers,info)=>
          received_count += 1
          message.data.toString().should.equal "my-test-message-#{received_count}"
          if received_count is 3
            amqpc.unsubscribe_from_queue subscription_tag, (err)->
              assert.ok not err?, err
              done()
          else
            received_count.should.not.be.above 3
        amqpc.subscribe_to_queue TEST_QUEUE, {exclusive:true}, handler, (err, queue, queue_name, st)=>
          assert.ok not err?, err
          assert.ok st?
          subscription_tag = st
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'

  it 'can accept a JSON-valued message as a JSON object',(done)=>
    amqpc = new AMQPConsumer()
    subscription_tag = null
    amqpc.connect TEST_BROKER, (err)=>
      assert.ok not err?, err
      amqpc.queue TEST_QUEUE, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, (err)=>
        assert.ok not err?, err
        handler = (message,headers,info, raw)=>
          message.foo.should.equal 'bar'
          message.a.should.equal 1
          info.contentType.should.equal 'application/json'
          should.exist raw
          amqpc.unsubscribe_from_queue subscription_tag, (err)->
            done()
        amqpc.subscribe_to_queue TEST_QUEUE, handler, (err, queue, queue_name, st)=>
          assert.ok not err?, err
          assert.ok st?
          subscription_tag = st
        @exchange.publish TEST_ROUTING_KEY, { foo:'bar', a:1 }

  it 'AMQPJSONConsumer can accept a JSON-valued message as a JSON object',(done)=>
    amqpc = new AMQPConsumer()
    subscription_tag = null
    amqpc.connect TEST_BROKER, (err)=>
      assert.ok not err?, err
      amqpc.queue TEST_QUEUE, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, (err)=>
        assert.ok not err?, err
        handler = (message,headers,info, raw)=>
          message.foo.should.equal 'bar'
          message.a.should.equal 1
          info.contentType.should.equal 'application/json'
          should.exist raw
          amqpc.unsubscribe_from_queue subscription_tag, (err)->
            done()
        amqpc.subscribe_to_queue TEST_QUEUE, handler, (err, queue, queue_name, st)=>
          assert.ok not err?, err
          assert.ok st?
          subscription_tag = st
        @exchange.publish TEST_ROUTING_KEY, { foo:'bar', a:1 }

  it 'AMQPStringConsumer can accept a Buffer-valued message as a String',(done)=>
    amqpc = new AMQPStringConsumer()
    subscription_tag = null
    amqpc.connect TEST_BROKER, (err)=>
      assert.ok not err?, err
      amqpc.queue TEST_QUEUE, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, (err)=>
        assert.ok not err?, err
        handler = (message,headers,info, raw)=>
          message.should.equal "The quick brown fox jumped."
          amqpc.unsubscribe_from_queue subscription_tag, (err)->
            done()
        amqpc.subscribe_to_queue TEST_QUEUE, handler, (err, queue, queue_name, st)=>
          assert.ok not err?, err
          assert.ok st?
          subscription_tag = st
        @exchange.publish TEST_ROUTING_KEY, "The quick brown fox jumped."

  it 'supports a payload converter for transforming messages before they are consumed',(done)=>
    amqpc = new AMQPJSONConsumer()
    amqpc.message_converter = (message)->message.data.toString().toUpperCase()
    subscription_tag = null
    amqpc.connect TEST_BROKER, (err)=>
      assert.ok not err?, err
      amqpc.queue TEST_QUEUE, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, (err)=>
        assert.ok not err?, err
        handler = (message,headers,info, raw)=>
          message.should.equal "THE QUICK BROWN FOX JUMPED."
          amqpc.unsubscribe_from_queue subscription_tag, (err)->
            done()
        amqpc.subscribe_to_queue TEST_QUEUE, handler, (err, queue, queue_name, st)=>
          assert.ok not err?, err
          assert.ok st?
          subscription_tag = st
        @exchange.publish TEST_ROUTING_KEY, "the quick brown fox jumped."

  # in this case we have multiple subscribers on top of a single queue; each message is sent to one or the other subscriber but not both
  it 'can create multiple subscription channels on top of a single queue and single connection (create-queue+subscribe-to-queue case)',(done)=>
    handler1_received_count = 0
    handler2_received_count = 0
    amqpc = new AMQPConsumer()
    subscription_tag1 = null
    subscription_tag2 = null
    amqpc.connect TEST_BROKER, (err)=>
      assert.ok not err?, err
      amqpc.queue TEST_QUEUE, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, (err)=>
        assert.ok not err?, err
        handler1 = (message,headers,info)=>
          handler1_received_count += 1
          message.data.toString().should.equal "my-test-message-#{(handler1_received_count + handler2_received_count)}"
          if (handler1_received_count + handler2_received_count) is 3
            amqpc.unsubscribe_from_queue subscription_tag1, (err)->
              assert.ok not err?, err
              amqpc.unsubscribe_from_queue subscription_tag2, (err)->
                assert.ok not err?, err
                done()
          else
            (handler1_received_count + handler2_received_count).should.not.be.above 3
        handler2 = (message,headers,info)=>
          handler2_received_count += 1
          message.data.toString().should.equal "my-test-message-#{(handler1_received_count + handler2_received_count)}"
          if (handler1_received_count + handler2_received_count) is 3
            amqpc.unsubscribe_from_queue subscription_tag2, (err)->
              assert.ok not err?, err
              amqpc.unsubscribe_from_queue subscription_tag1, (err)->
                done()
          else
            (handler1_received_count + handler2_received_count).should.not.be.above 3
        amqpc.subscribe_to_queue TEST_QUEUE, handler1, (err, queue, queue_name, st1)=>
          assert.ok not err?, err
          assert.ok st1?
          subscription_tag1 = st1
          amqpc.subscribe_to_queue TEST_QUEUE, handler2, (err, queue, queue_name, st2)=>
            assert.ok not err?, err
            assert.ok st2?
            subscription_tag2 = st2
            @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
            @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
            @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'

  # in this case we have multiple subscribers on top of a single queue; each message is sent to one or the other subscriber but not both
  it 'can create multiple subscription channels on top of a single queue and single connection (create-queue-during-subscribe case)',(done)=>
    handler1_received_count = 0
    handler2_received_count = 0
    amqpc = new AMQPConsumer()
    subscription_tag1 = null
    subscription_tag2 = null
    amqpc.connect TEST_BROKER, (err)=>
      assert.ok not err?, err
      handler1 = (message,headers,info)=>
        handler1_received_count += 1
        message.data.toString().should.equal "my-test-message-#{(handler1_received_count + handler2_received_count)}"
        if (handler1_received_count + handler2_received_count) is 3
          amqpc.unsubscribe_from_queue subscription_tag1, (err)->
            assert.ok not err?, err
            amqpc.unsubscribe_from_queue subscription_tag2, (err)->
              assert.ok not err?, err
              done()
        else
          (handler1_received_count + handler2_received_count).should.not.be.above 3
      amqpc.subscribe TEST_QUEUE, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, handler1, (err, queue1, queue_name1, st1)=>
        assert.ok not err?, err
        assert.ok queue1?
        assert.ok queue_name1?
        assert.ok st1?
        subscription_tag1 = st1
        #
        handler2 = (message,headers,info)=>
          handler2_received_count += 1
          message.data.toString().should.equal "my-test-message-#{(handler1_received_count + handler2_received_count)}"
          if (handler1_received_count + handler2_received_count) is 3
            amqpc.unsubscribe_from_queue subscription_tag2, (err)->
              assert.ok not err?, err
              amqpc.unsubscribe_from_queue subscription_tag1, (err)->
                done()
          else
            (handler1_received_count + handler2_received_count).should.not.be.above 3
        amqpc.subscribe TEST_QUEUE, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, handler2, (err, queue2, queue_name2, st2)=>
          assert.ok not err?, err
          assert.ok queue2?
          assert.ok queue_name2?
          assert.ok queue_name2 is queue_name1
          assert.ok st2?
          assert.ok st2 isnt st1
          subscription_tag2 = st2
          #
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'

  # in this case we have multiple QUEUES on top of a single connection; each message is sent to both subscribers
  it 'can create multiple queues on top of a single connection (create-queue+subscribe-to-queue case)', (done)=>
    handler1_received_count = 0
    handler2_received_count = 0
    amqpc = new AMQPConsumer()
    subscription_tag1 = null
    subscription_tag2 = null
    handler1_done = false
    handler2_done = false
    amqpc.connect TEST_BROKER, (err)=>
      assert.ok not err?, err
      amqpc.queue TEST_QUEUE, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, (err)=>
        assert.ok not err?, err
        handler1 = (message,headers,info)=>
          handler1_received_count += 1
          message.data.toString().should.equal "my-test-message-#{(handler1_received_count)}"
          if (handler1_received_count) is 3
            amqpc.unsubscribe_from_queue subscription_tag1, (err)->
              handler1_done = true
              assert.ok not err?, err
              if handler2_done
                done()
          else
            (handler1_received_count).should.not.be.above 3
        amqpc.subscribe_to_queue TEST_QUEUE, handler1, (err, queue, queue_name, st1)=>
          assert.ok not err?, err
          assert.ok st1?
          subscription_tag1 = st1
          #
          amqpc.queue TEST_QUEUE_2, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, (err)=>
            assert.ok not err?, err
            handler2 = (message,headers,info)=>
              handler2_received_count += 1
              message.data.toString().should.equal "my-test-message-#{(handler2_received_count)}"
              if (handler2_received_count) is 3
                amqpc.unsubscribe_from_queue subscription_tag2, (err)->
                  handler2_done = true
                  assert.ok not err?, err
                  if handler1_done
                    done()
              else
                (handler2_received_count).should.not.be.above 3
            amqpc.subscribe_to_queue TEST_QUEUE_2, handler2, (err, queue, queue_name, st2)=>
              assert.ok not err?, err
              assert.ok st2?
              subscription_tag2 = st2
              @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
              @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
              @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'

  # in this case we have multiple QUEUES on top of a single connection; each message is sent to both subscribers
  it 'can create multiple queues on top of a single connection (create-queue-during-subscribe case)',(done)=>
    handler1_received_count = 0
    handler2_received_count = 0
    amqpc = new AMQPConsumer()
    subscription_tag1 = null
    subscription_tag2 = null
    handler1_done = false
    handler2_done = false
    amqpc.connect TEST_BROKER, (err)=>
      assert.ok not err?, err
      handler1 = (message, headers, info)=>
        handler1_received_count += 1
        message.data.toString().should.equal "my-test-message-#{(handler1_received_count)}"
        if (handler1_received_count) is 3
          amqpc.unsubscribe_from_queue subscription_tag1, (err)=>
            handler1_done = true
            assert.ok not err?, err
            if handler2_done
              done()
        else
          (handler1_received_count).should.not.be.above 3
      amqpc.subscribe TEST_QUEUE, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, handler1, (err, queue1, queue_name1, st1)=>
        assert.ok not err?, err
        assert.ok queue1?
        assert.ok queue_name1?
        assert.ok st1?
        subscription_tag1 = st1
        #
        handler2 = (message, headers, info)=>
          handler2_received_count += 1
          message.data.toString().should.equal "my-test-message-#{(handler2_received_count)}"
          if (handler2_received_count) is 3
            amqpc.unsubscribe_from_queue subscription_tag2, (err)=>
              handler2_done = true
              assert.ok not err?, err
              if handler1_done
                done()
          else
            (handler2_received_count).should.not.be.above 3
        amqpc.subscribe TEST_QUEUE_2, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, handler2, (err, queue2, queue_name2, st2)=>
          assert.ok not err?, err
          assert.ok queue2?
          assert.ok queue_name2?
          assert.ok queue_name2 isnt queue_name1
          assert.ok st2?
          assert.ok st2 isnt st1
          subscription_tag2 = st2
          #
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'


  # in this case we have multiple QUEUES on top of a single connection; each message is sent to both subscribers
  it 'can create multiple queues on top of a single connection (create-queue-during-subscribe with null name case)',(done)=>
    handler1_received_count = 0
    handler2_received_count = 0
    amqpc = new AMQPConsumer()
    subscription_tag1 = null
    subscription_tag2 = null
    handler1_done = false
    handler2_done = false
    amqpc.connect TEST_BROKER, (err)=>
      assert.ok not err?, err
      handler1 = (message, headers, info)=>
        handler1_received_count += 1
        message.data.toString().should.equal "my-test-message-#{(handler1_received_count)}"
        if (handler1_received_count) is 3
          amqpc.unsubscribe_from_queue subscription_tag1, (err)=>
            handler1_done = true
            assert.ok not err?, err
            if handler2_done
              done()
        else
          (handler1_received_count).should.not.be.above 3
      amqpc.subscribe undefined, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, handler1, (err, queue1, queue_name1, st1)=>
        assert.ok not err?, err
        assert.ok queue1?
        assert.ok queue_name1?
        assert.ok st1?
        subscription_tag1 = st1
        #
        handler2 = (message, headers, info)=>
          handler2_received_count += 1
          message.data.toString().should.equal "my-test-message-#{(handler2_received_count)}"
          if (handler2_received_count) is 3
            amqpc.unsubscribe_from_queue subscription_tag2, (err)=>
              handler2_done = true
              assert.ok not err?, err
              if handler1_done
                done()
          else
            (handler2_received_count).should.not.be.above 3
        amqpc.subscribe undefined, TEST_QUEUE_OPTIONS, TEST_EXCHANGE, TEST_ROUTING_KEY, handler2, (err, queue2, queue_name2, st2)=>
          assert.ok not err?, err
          assert.ok queue2?
          assert.ok queue_name2?
          assert.ok queue_name2 isnt queue_name1
          assert.ok st2?
          assert.ok st2 isnt st1
          subscription_tag2 = st2
          #
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
          @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'

describe '[DEPRECATED] AMQPConsumer (old methods)',->

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
          amqpc.old_unsubscribe ()->
            done()
        else
          received_count.should.not.be.above 3
      amqpc.old_subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
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
          amqpc.old_unsubscribe ()->
            done()
        else
          received_count.should.not.be.above 3
      amqpc.old_subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, 'my-test-message-1'
        @exchange.publish TEST_ROUTING_KEY, 'my-test-message-2'
        @exchange.publish TEST_ROUTING_KEY, 'my-test-message-3'

  it 'can defer connection to the message broker',(done)=>
    received_count = 0
    amqpc = new AMQPConsumer()
    amqpc.old_connect TEST_BROKER, TEST_QUEUE, ()=>
      handler = (message,headers,info)=>
        received_count += 1
        message.data.toString().should.equal "my-test-message-#{received_count}"
        if received_count is 3
          amqpc.old_unsubscribe ()->
            done()
        else
          received_count.should.not.be.above 3
      amqpc.old_subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
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
              amqpc.old_unsubscribe ()->
                queue.destroy()
                done()
            else
              received_count.should.not.be.above 3
          amqpc.old_subscribe handler, ()=>
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
              amqpc.old_unsubscribe ()->
                queue.destroy()
                done()
            else
              received_count.should.not.be.above 3
          amqpc.old_subscribe {exclusive:true}, handler, ()=>
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
        amqpc.old_unsubscribe ()->
          done()
      amqpc.old_subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, { foo:'bar', a:1 }

  it 'passes raw message from node-amqp to message handler',(done)=>
    amqpc = new AMQPConsumer TEST_BROKER, null, TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
      handler = (message,headers,info,raw)->
        message.foo.should.equal 'bar'
        message.a.should.equal 1
        info.contentType.should.equal 'application/json'
        should.exist raw
        amqpc.old_unsubscribe ()->
          done()
      amqpc.old_subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, { foo:'bar', a:1 }

  it 'supports a payload converter for transforming messages before they are consumed',(done)=>
    amqpc = new AMQPConsumer TEST_BROKER, null, TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
      amqpc.message_converter = (message)->message.data.toString().toUpperCase()
      handler = (message,headers,info)->
        message.should.equal "THE QUICK BROWN FOX JUMPED."
        amqpc.old_unsubscribe ()->
          done()
      amqpc.old_subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, "the quick brown fox jumped."

  it 'AMQPJSONConsumer accept a JSON-valued message as a JSON object',(done)=>
    amqpc = new AMQPJSONConsumer TEST_BROKER, null, TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
      handler = (message,headers,info)->
        message.foo.should.equal 'bar'
        message.a.should.equal 1
        info.contentType.should.equal 'application/json'
        amqpc.old_unsubscribe ()->
          done()
      amqpc.old_subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, { foo:'bar', a:1 }

  it 'AMQPStringConsumer can accept a Buffer-valued message as a String',(done)=>
    amqpc = new AMQPStringConsumer TEST_BROKER, null, TEST_QUEUE, TEST_QUEUE_OPTIONS, ()=>
      handler = (message,headers,info)->
        message.should.equal "The quick brown fox jumped." #note that in the AMQPConsumer case, message.data.toString() would be needed instead
        amqpc.old_unsubscribe ()->
          done()
      amqpc.old_subscribe TEST_EXCHANGE, TEST_ROUTING_KEY, handler, ()=>
        @exchange.publish TEST_ROUTING_KEY, "The quick brown fox jumped."
