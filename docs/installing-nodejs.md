# Installng Node.js

<!-- toc -->

This is a Node.js-based system.

To run or modify it, you'll need to install [Node.js](https://nodejs.org/).

## Installing nvm

You can install Node.js directly from the links at <https://nodejs.org>, but if your computer readily supports Bash or a Bash-like shell, I'd recommend installing Node through the Node Version Manager, [nvm](https://github.com/creationix/nvm).  nvm makes it easy to install and manage one or more instances of Node.js on the same machine.

To install nvm, follow the instructions at <https://github.com/creationix/nvm>, but generally speaking you can just run one of these commands:

    curl https://raw.githubusercontent.com/creationix/nvm/v0.13.1/install.sh | sh

or

    wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.13.1/install.sh | sh

or

    git clone https://github.com/creationix/nvm.git ~/.nvm

In all three cases, this will create a directory called `.nvm` in your
`$HOME` directory.  (You might want to visit
https://github.com/creationix/nvm to check if more recent version than
0.13.1 is available if your are running one of the first two.)

Once installed, you'll need to source the file at `~/.nvm/nvm.sh`.  **Note that it's not enough to simply execute the file, you'll need to *source* it (as if the commands were executed directly in your shell, rather than in a sub-process).**

You can do that via:

    source ~/.nvm/nvm.sh

or

    . ~/.nvm/nvm.sh

You can add this line to your `~/.bashrc` or `~/.profile` (or some equivalent script that is run on log in) so that `nvm` is always available.

If everything is installed properly you should now be able to run `nvm --help` and see a help message.

## Install Node.js using nvm

Now that nvm is installed, you can use it to install (and "mount") an arbitrary version of Node.

To see a list of the available Node versions, enter:

    nvm ls-remote

This should give you a list of version numbers, such as:

    v0.10.19
    v0.10.20
    v0.10.21
    v0.10.22
    v0.10.23
    v0.10.24
    v0.10.25
    v0.10.26
     v0.11.0
     v0.11.1
     v0.11.2

You will want to install the largest *even-numbered* release. (Like Linux, Node.js uses odd-valued version numbers to denote development versions.)  In the listing above, the most recent stable version of Node.js that is avaiable is `v0.10.26`.  The `v0.11.x` versions are "unstable" development branches, as indicated by the odd-valued `11` version number.

To install verion 0.10.26, run:

    nvm install 0.10.26

Once installed, you can "mount" that version of Node.js by running:

    nvm use 0.10.26

After which a command like:

    which node

should point to something like `~/.nvm/v0.10.26/bin/node` and a command like:

    node -v

should yield something like `v0.10.26`.

You can add that `nvm use` command to your `.bashrc` or `.profile` to mount that version of Node automatically on login.

For example, in my `~/.profile`, I have these lines:

    . ~/.nvm/nvm.sh  # initialize the node version manager
    nvm use 0.10.26  # mount a specific version of node

## Add ./node_modules/.bin to your PATH

Node.js and npm install local dependencies into a local directory
named `node_modules`. Any executable script included with these
installed modules are placed in `node_modules/.bin`.

Hence if you want to run an program installed by npm dependencies
(e.g., `coffee` or `docco`), you must use:

    ./node_modules/.bin/coffee

or

    ./node_modules/.bin/docco

You *can* but do not *need* to add `./node_modules/.bin` to your
`$PATH` to avoid this.  To do this, run:

    PATH=${PATH}:/node_modules/.bin

or add:

    export PATH=${PATH}:./node_modules/.bin # add the local node_modules bin to the path

to your` ~/.profile` or similiar log-in script.

Be aware that this is somewhat controversial from a security standpoint since it means your `$PATH` changes depending upon your current directory.  It is optional, but convenient when working with Node.js projects.

## Install the Node module's dependencies

Node has an excellent dependency management framework built-in to the core library.  It's called `npm`, for "Node Package Manager".

npm can be used to install arbitrary Node modules. npm can also be used to manage a host of things about a Node module through the [`package.json`](../package.json) configuration file.

Thanks to npm and the package.json file, installing the external modules used by this project is trivial.  Simply run:

    npm install

from within this project's root directory.

(This may take a while as it will often locally-compile some of the dependencies.)

You can also use the command:

    make npm

or

    make install

to accomplish this task using this module's [Makefile](../Makefile).

## That's it

Now you are done with the Node.js setup.
