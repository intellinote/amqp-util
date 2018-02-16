should    = require 'should'
fs        = require 'fs'
path      = require 'path'
HOMEDIR   = path.join __dirname, '..'
LIB_COV   = path.join HOMEDIR, 'lib-cov'
LIB       = path.join HOMEDIR, 'lib'
LIB_DIR   = if fs.existsSync(LIB_COV) then LIB_COV else LIB
index     = require(path.join(LIB_DIR,'index'))

describe "index",->

  it "exports AmqpProducer", (done)->
    index.AMQPProducer.should.exist
    index.AmqpProducer.should.exist
    done()

  it "exports AmqpConsumer and related types", (done)->
    index.AMQPConsumer.should.exist
    index.AMQPStringConsumer.should.exist
    index.AMQPJSONConsumer.should.exist
    index.AmqpConsumer.should.exist
    index.AmqpStringConsumer.should.exist
    index.AmqpJsonConsumer.should.exist
    done()

  it "exports cli", (done)->
    index.app.AMQPCLI.should.exist
    index.app.AmqpCli.should.exist
    done()

  it "exports AmqpBase", (done)->
    index.AMQPBase.should.exist
    index.AmqpBase.should.exist
    done()
