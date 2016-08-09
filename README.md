# AMQP-UTIL

**AMQP** is the [Advanced Message Queuing Protocol](http://en.wikipedia.org/wiki/Advanced_Message_Queuing_Protocol), an [international standard](http://www.amqp.org/) protocol by which applications can publish to and subscribe from a message broker such as [ActiveMQ](http://en.wikipedia.org/wiki/Apache_ActiveMQ) or [RabbitMQ](http://www.rabbitmq.com/).

**amqp-util** is a [Node.js](http://nodejs.org/) library that defines convenience and utility classes on which to build AMQP producers and consumers in Node.js.

*amqp-util* depends heavily on [*node-amqp*](https://github.com/postwait/node-amqp) (which see). This module provides utilities and base-classes which wrap *node-amqp* in support of common use-cases.

<!-- toc -->

- [AMQP-UTIL](#amqp-util)
	- [Installing](#installing)
	- [Contents](#contents)
	- [Quick Start](#quick-start)
	- [Prerequisites](#prerequisites)
	- [Hacking](#hacking)
		- [Obtaining Make](#obtaining-make)
		- [Basics](#basics)
		- [Using the Makefile](#using-the-makefile)
	- [Licensing](#licensing)
	- [How to contribute](#how-to-contribute)
	- [About Intellinote](#about-intellinote)
		- [Work with Us](#work-with-us)

<!-- tocstop -->

## Installing

### Via npm

*amqp-til* is deployed as an [npm module](https://npmjs.org/) under
the name [`amqp-util`](https://npmjs.org/package/amqp-util). Hence you
can install a pre-packaged version with the command:

```bash
npm install amqp-util
```

and you can add it to your project as a dependency by adding a line like:

```javascript
"amqp-util": "latest"
```

to the `dependencies` or `devDependencies` part of your `package.json` file.

### From source

The source code and documentation for *amqp-util* is available on GitHub at [intellinote/amqp-util](https://github.com/intellinote/amqp-util).

You can clone the repository via:

```bash
git clone git@github.com:intellinote/amqp-util
```

Once cloned run `make install bin` to download and compile the module's dependencies and generate the command-line utilities.

## Contents

*amqp-util* provides the following:

 * **AMQPConsumer** - an AMQP message consumer (subscriber) that can be used as-is or extended via sub-classes.

 * **AMQPProducer** - an AMQP message producer (publisher) that can be used as-is or extended via sub-classes.

 * **util.BaseConsumerApp** - a base class for command-line applications that consume messages from a Message Queue.

 * **util.BaseProducerApp** - a base class for command-line applications that publish messages to a Message Queue.

 * **amqp-cli** - a command-line utility for manipulating exchanges and queues.

 * **logging-listener** - a simple command-line application that logs messages to the console.

 * **message-publisher** - a simple command-line application that can publish messages from the command-line.

Explore the [lib](./lib) directory for more.

## Quick Start

For a quick and "easy" demonstration of the framework:

1. Install Node.js and RabbitMQ.

2. Make sure RabbitMQ is running.

2. Run `make clean test bin` to:

    - install any external dependencies defined in `package.json`.

    - run the unit test suite to confirm everything is running properly.

    - generate the executable scripts in the `./bin` directory.

3. Generate the `MyExchange` and `MyQueue` objects used for the demonstration.

   From the project's root directory (the directory containing this file), run:

        NODE_ENV=demo ./bin/amqp-cli create exchange --e.name MyExchange --e.type fanout --e.durable true --e.auto-delete false
        NODE_ENV=demo ./bin/amqp-cli create queue --q.name MyQueue --q.durable true --q.auto-delete false
        NODE_ENV=demo ./bin/amqp-cli bind queue --q.name MyQueue --e.name MyExchange

   (You can replace `./bin/amqp-cli` with `node lib/app/amqp-cli.js` or `coffee lib/app/amqp-cli.coffee`, if preferred.)

4. Launch a `logging-listener`, an AMQP consumer that prints any messages it receives to the console.

   From the project's root directory (the directory containing this file), run:

        NODE_ENV=demo ./bin/logging-listener

   (You can replace `./bin/logging-listener` with `node lib/app/logging-listener.js` or `coffee lib/app/logging-listener.coffee`, if preferred.)

5. Use `message-publisher` to publish a message to the exchange from the command line.

   From the project's root directory (the directory containing this file), run:

        NODE_ENV=demo ./bin/publish-message -m "Hello World!"

   (You can replace `./bin/publish-message` with `node lib/app/publish-message.js` or `coffee lib/app/publish-message.coffee`, if preferred.)

6. If everything is working properly, the `logging-listener` should echo the published message to the console.

## Prerequisites

In order to build this library you'll need to install Node.js as described at <http://nodejs.org/>.

In addition, to run the unit test suite or other demonstrations you'l need to install an AMQP-compatible message broker such as [RabbitMQ](http://www.rabbitmq.com/).

See the [`README`](./test/README.md) file in the `test` directory for details.


## Hacking

While not strictly required, you are *strongly* encouraged to take advantage of the [`Makefile`](./Makefile) when working on this module.

[`make`](http://www.gnu.org/software/make/) is a *very* widely supported tool for dependency management and conditional compilation.

### Obtaining Make

`make` is probably pre-installed on your Linux or Unix distribution (if not, you can use `rpm`, `yum`, `apt-get`, etc. to install it).

On Mac OSX, one simple way to add `make` to your system is to install the Apple Developer Tools from <https://developer.apple.com/>.

On Windows, you can install [MinGW](http://www.mingw.org/), [GNUWin](http://gnuwin32.sourceforge.net/packages/make.htm) or [Cygwin](https://www.cygwin.com/), among other sources.

### Basics

Ensure that an AMQP message broker (such as RabbitMQ) is running locally (or as configured in [`config/unit-testing.json`](./config/unit-testing.json)).

With `make` installed, run:

    make clean test

to download any missing dependencies, compile anything that needs to be compiled and run the unit test suite.

Run:

    make docs

to generate various documentation artifacts, largely but not exclusively in the `docs` directory.

### Using the Makefile

From this project's root directory (the directory containing this file), type `make help` to see a list of common targets, including:

 * `make install` - download and install all external dependencies.

 * `make clean` - remove all generated files.

 * `make test` - run the unit-test suite.

 * `make bin` - generate the executable scripts in `./bin`.

 * `make docs` - generate HTML documentation from markdown files and annotated source code.

 * `make docco` - generate an HTML rendering of the annotated source code into the `docs/docco` directory.

 * `make coverage` - generate a test-coverage report (to the file `docs/coverage.html`).

 * `make module` - package the module for upload to npm.

 * `make test-module-install` - generates an npm module from this repository and validates that it can be installed using npm.


## Licensing

The amqp-util library and related documentation are made available under an [MIT License](http://opensource.org/licenses/MIT).  For details, please see the file [LICENSE.txt](LICENSE.txt) in the root directory of the repository.

## How to contribute

Your contributions, [bug reports](https://github.com/intellinote/amqp-util/issues) and [pull-requests](https://github.com/intellinote/amqp-util/pulls) are greatly appreciated.

We're happy to accept any help you can offer, but the following guidelines can help streamline the process for everyone.

 * You can report any bugs at [github.com/intellinote/amqp-util/issues](https://github.com/intellinote/amqp-util/issues).

    - We'll be able to address the issue more easily if you can provide an demonstration of the problem you are encountering. The best format for this demonstration is a failing unit test (like those found in [./test/](https://github.com/intellinote/amqp-util/tree/master/test)), but your report is welcome with or without that.

 * Our preferered channel for contributions or changes to the source code and documentation is as a Git "patch" or "pull-request".

    - If you've never submitted a pull-request, here's one way to go about it:

        1. Fork or clone the repository.
        2. Create a local branch to contain your changes (`git checkout -b my-new-branch`).
        3. Make your changes and commit them to your local repository.
        4. Create a pull request [as described here](https://help.github.com/articles/creating-a-pull-request).

    - If you'd rather use a private (or just non-GitHub) repository, you might find [these generic instructions on creating a "patch" with Git](https://ariejan.net/2009/10/26/how-to-create-and-apply-a-patch-with-git/) helpful.

 * If you are making changes to the code please ensure that the [automated test suite](./test) still passes.

 * If you are making changes to the code to address a bug or introduce new features, we'd *greatly* appreciate it if you can provide one or more [unit tests](./test) that demonstrate the bug or exercise the new feature.

**Please Note:** We'd rather have a contribution that doesn't follow these guidelines than no contribution at all.  If you are confused or put-off by any of the above, your contribution is still welcome.  Feel free to contribute or comment in whatever channel works for you.

## About Intellinote

Intellinote is a multi-platform (web, mobile, and tablet) software application that helps businesses of all sizes capture, collaborate and complete work, quickly and easily.

Users can start with capturing any type of data into a note, turn it into a Task, assign it to others, start a discussion around it, add a file and share – with colleagues, managers, team members, customers, suppliers, vendors and even classmates. Since all of this is done in the context of Private and Public Workspaces, users retain end-to-end control, visibility and security.

For more information about Intellinote, visit <https://www.intellinote.net/>.

### Work with Us

Interested in working for Intellinote?  Visit [the careers section of our website](https://www.intellinote.net/careers/) to see our latest techincal (and non-technical) openings.
