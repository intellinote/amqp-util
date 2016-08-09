# Automated tests for amqp-util

This directory contains some automated tests of the `amqp-util` module.

These tests require an AMQP-compatible message queue.

The [`unit-testing.json`](./config/unit-testing.json) file in the [`config`](../config) directory specifies how to connect to this message queue.

The default configuration will connect to the exchange `amq.direct` running within a message queue service that is accessed via the URL `amqp://guest:guest@localhost:5672`.

(Note that a default "local" installation of [RabbitMQ](https://www.rabbitmq.com/) will meet those criteria.)

## Setting up a local RabbitMQ instance for these tests

1. [Download and install RabbitMQ](https://www.rabbitmq.com/download.html) from <https://www.rabbitmq.com/download.html> or your preferred package-manager.

2. Start the server under the default configuration by running:

       rabbitmq-server -detached

   where `rabbitmq-server` is found in the RabbitMQ's `sbin` location.

3. Now you should be able to run `make test` to execute this test suite.

4. To stop the local RabbitMQ server, run

       rabbitmqctl stop

   (where `rabbitmqctl` is also found in `sbin` by default).

Note that this test suite assumes that an excnhange named `amq.direct` exists (which it should in any AMQP-compliant message queue).
