# AMQP-UTIL

Convenience and utility classes on which to build AMQP producers and consumers in Node.js.

<!-- toc -->

## Prerequisites

In order to build this ilbrary you'll need to install Node.js as
described at <http://nodejs.org/> or in the
[Installing Node.js](./docs/installing-nodejs.md) file in the
[`docs`](./docs) directory.

In addition, to run the unit test suite or other demonstrations you'll
need to install an AMQP-compatiable message broker such as
[RabbitMQ](http://www.rabbitmq.com/).

## Hacking

While not strictly required, you are *strongly* encouraged to take
advantage of the [`Makefile`](./Makefile) when working on this module.

[`make`](http://www.gnu.org/software/make/) is a *very* widely
supported tool for dependency management and conditional compilation.

### Obtaining Make

`make` is probably pre-installed on your Linux or Unix distribution (if
not, you can use `rpm`, `yum`, `apt-get`, etc. to install it).

On Mac OSX, one simple way to add `make` to your system is to install
the Apple Developer Tools from <https://developer.apple.com/>.

On Windows, you can install [MinGW](http://www.mingw.org/),
[GNUWin](http://gnuwin32.sourceforge.net/packages/make.htm) or
[Cygwin](https://www.cygwin.com/), among other sources.

### Quickstart

Ensure that an AMQP message broker (such as RabbitMQ) is running
locally (or as configured in
[`config/unit-testing.json`](./config/unit-testing.json).

With `make` installed, run:

    make clean test

to download any missing dependencies, compile anything that needs to
be compiled and run the unit test suite.

Run:

    make docs

to generate various documentation artifacts, largely but not
exclusively in the `docs` directory.

### Using the Makefile

From this project's root directory (the directory containing this
file), type `make help` to see a list of common targets, including:

 * `make install` - download and install all external dependencies

 * `make clean` - remove all generated files

 * `make test` - run the unit-test suite

 * `make docs` - generate HTML documenation from markdown files and
   annotated source code

 * `make docco` - generate an HTML rendering of the annoated source
   code into the `docs/docco` directory.

 * `make coverage` - generate a test-coverage report (to the file
   `docs/coverage.html`).

 * `make module` - packages the module for upload to npm

 * `make test-module-install` - generates an npm module from this
   repository and validates that it can be installed using npm
