should  = require 'should'
config  = require('inote-util').config.init({},{NODE_ENV:'unit-testing'})

describe 'Config',->

  it 'has an amqp property', (done)->
    config.get('amqp').should.be.ok
    done()
