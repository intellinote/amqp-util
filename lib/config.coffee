fs               = require 'fs'
path             = require 'path'
HOMEDIR          = path.join(__dirname,'..')
CONFIG_DIR       = path.join(HOMEDIR,'config')

class Config
  constructor:(init=false,defaults=null,overrides=null)->
    if typeof init is 'object'
      overrides = defaults
      defaults = init
      init = true
    @init(defaults,overrides) if init? and init

  _load_if_exists:(file)=>
    if file?
      if fs.existsSync(file)
        @nconf.file(file)
        return true
      else
        return false
    else
      return true

  init:(defaults=null,overrides=null)->
    @nconf = require 'nconf'
    @nconf.overrides(overrides) if overrides?                           # First, use any overrides that are provided.
    @nconf.argv()                                                       # Next, command line parameters.
    @nconf.env ['NODE_ENV','config_file','config_dir']                  # Then, fetch certain values from the environment variables (but nothing else yet), if they aren't already set.
    config_dir = @nconf.get('config_dir') ? @nconf.get('config-dir')    # Now, if there is a `config_dir` directory specified, use that instead of the default `CONFIG_DIR`.
    if config_dir?
      if fs.existsSync(config_dir)
        CONFIG_DIR = config_dir
      else
        console.error "Custom config_dir #{config_dir} not found."
        process.exit(1)
    @_load_if_exists(path.join(CONFIG_DIR,'config.json'))               # If there is a `[CONFIG_DIR]/config.json` configuration file, use that.
    if @nconf.get('NODE_ENV')?                                          # If there is a `[CONFIG_DIR]/[NODE_ENV].json` file, try to load that.
      @_load_if_exists(path.join(CONFIG_DIR,"#{@nconf.get('NODE_ENV')}.json"))
    config_file = @nconf.get('config_file') ? @nconf.get('config-file') # If there is a `config_file` variable, try to load that.
    if config_file?
      unless @_load_if_exists(config_file)
        console.error "Custom config_file #{config_file} not found."
        process.exit(1)
    @nconf.env()                                                        # Finally, pull remaining values from the environment variables
    @nconf.defaults(defaults) if defaults?                              # ...and use any provided defaults.
    return @nconf

exports = exports ? this
exports.config = new Config()
