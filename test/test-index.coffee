should    = require 'should'
fs        = require 'fs'
path      = require 'path'
HOMEDIR   = path.join __dirname, '..'
LIB_COV   = path.join HOMEDIR, 'lib-cov'
LIB       = path.join HOMEDIR, 'lib'
LIB_DIR   = if fs.existsSync(LIB_COV) then LIB_COV else LIB
index     = require(path.join(LIB_DIR,'index'))

describe "index",->

  it "exports AMQPProducer", (done)->
    index.AMQPProducer.should.exist
    done()

  it "exports AMQPConsumer and related types", (done)->
    index.AMQPConsumer.should.exist
    index.AMQPStringConsumer.should.exist
    index.AMQPJSONConsumer.should.exist
    done()

  it "exports util classes", (done)->
    index.util.BaseApp.should.exist
    index.util.BaseConsumerApp.should.exist
    index.util.BaseProducerApp.should.exist
    done()
