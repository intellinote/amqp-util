# How to Use the Configuration Framework

All environment specific configuration information for this system is
stored within [JSON](http://json.org) files located in this `config`
directory.

### For Administrators

To manage the configuration settings:

1. Create a JSON file in this directory containing your configuration
   settings.  You may want to use one of the existing files as a
   template.

2. Set the `NODE_ENV` environment variable to the name of that file
   (with no extension), either in your overall shell environment or
   directly on the command line when launching the application.

   The application will read the associated `.json` file to determine
   the configuration settings.

   E.g., given:

       NODE_ENV=foo node lib/my-app.js

   The application will load the configuration file found at
   `./config/foo.json` (relative to the "project root" directory).

3. Note that the configuration file MUST be a valid JSON document.

### For Developers

To read the configuration settings within your code:

1. `require` `lib/config.coffee` (or `lib/config.js`), and invoke the
   `init` method to load the default (`NODE_ENV`-based) configuration.
   For example,

       var config = require('config')).config.init();

2. Invoke `config.get(key)` to access a given property, where `key` is
   a string identifying an attribute in the underlying JSON file.
   E.g., given a configuration file containing:

       { "foo": 1123 }

   The JavaScript snippet:

       config.get('foo');

   will yield `1123`.

3. The `config.get` method will return whatever JSON type appears in
   the configuration file itself--numbers, booleans, `null`, strings,
   even arrays and maps.  E.g., given a configuration file containing:

       { "foo: { "bar": true } }

   The JavaScript snippet:

       config.get('foo');

   will yield `{ "bar": true }`.

4. Use the `:` character in a key-name to access nested properties.
   E.g., given a configuration file containing:

       { "foo: { "bar": true } }

   The JavaScript snippet:

       config.get('foo:bar');

   will yield the boolean value `true`.

5. Note that configuration parameters do not need to be declared or
   defined anywhere other than the configuration files themselves.

   To add a new configuration parameter, simply add the value to the
   JSON document.
