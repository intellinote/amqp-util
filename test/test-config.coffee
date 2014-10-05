should  = require 'should'
fs      = require 'fs'
path    = require 'path'
HOMEDIR = path.join(__dirname,'..')
LIB_COV = path.join(HOMEDIR,'lib-cov')
LIB_DIR = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
config  = require(path.join(LIB_DIR,'config')).config
config  = config.init({},{NODE_ENV:'unit-testing'})

describe 'Config',->

  it 'has an amqp property', (done)->
    config.get('amqp').should.be.ok
    done()
