assert                = require 'assert'
fs                    = require 'fs'
path                  = require 'path'
HOMEDIR               = path.join(__dirname,'..')
LIB_COV               = path.join(HOMEDIR,'lib-cov')
LIB                   = path.join(HOMEDIR,'lib')
LIB_DIR               = if fs.existsSync(LIB_COV) then LIB_COV else LIB
AmqpBase              = require(path.join(LIB_DIR,'amqp-base')).AmqpBase

describe 'AmqpBase',->

  it "will not disconnect a connection it did not create (unless explicitly asked to)", (done)=>
    mock_connection = {
      disconnect:(cb)=>
        mock_connection.disconnect_called = true
        cb?()
    }
    obj = new AmqpBase(mock_connection)
    obj.disconnect (err)=>
      assert.ok err?
      assert not mock_connection.disconnect_called
      obj.disconnect true, (err)=>
        assert.ok not err?, err
        assert mock_connection.disconnect_called
        done()
