Gearman HTTP Exchange
=====================
A RabbitMQ exchange type that submits Gearman jobs.

:boom:**Important**:boom: This project is deprecated and no longer maintained.

Details
-------

Download
--------
To download the gearman_http_exchange plugin, select the appropriate file
that matches the RabbitMQ version you are running:

+---------+------------+----------+-----------------------+----------------------------------+
| Version |  Released  | RabbitMQ | Short URL             | MD5 Hash                         |
+=========+============+==========+=======================+==================================+
|  0.1.0  | 2014-12-05 | v 3.4.x  |                       |                                  |
+---------+------------+----------+-----------------------+----------------------------------+
|  0.1.0  | 2014-12-05 | v 3.3.x  |                       |                                  |
+---------+------------+----------+-----------------------+----------------------------------+

The file is a zip file containing both the gearman-http-exchange plugin ez file
and the ibrowse dependency ez file. Distributable zip files are committed in the
binaries branch of this repository. Files are served via GitHub's RAW download
functionality.

Installation
------------
Extract the contents of the zip file into your RabbitMQ plugins directory. Once
extracted, run ``rabbitmq-plugins enable gearman-http-exchange``.

Configuration
-------------
Configuration for submitting metrics to Gearman can be configured when
declaring the exchange, via policy, or via the rabbitmq.config configuration
file. If no configuration is provided, a default URL of
``http://localhost:8080`` will be used for submitting metrics.

**Argument Based Configuration**

To subit metrics to Gearman using something other than the default URI of
``http://localhost:8080``, you can add arguments when declaring the exchange:

+--------------+-----------------------------------------+-----------+
| Setting      | Description                             | Data Type |
+==============+=========================================+===========+
| x-host       | The Gearman server hostname             | String    |
+--------------+-----------------------------------------+-----------+
| x-port       | The port to connect on                  | Number    |
+--------------+-----------------------------------------+-----------+

**Policy Based Configuration**

To apply configuration via a policy, the following settings are available:

+-------------------------+-----------------------------------------+-----------+
| Setting                 | Description                             | Data Type |
+=========================+=========================================+===========+
| gearman-host            | The Gearman server hostname             | String    |
+-------------------------+-----------------------------------------+-----------+
| gearman-port            | The port to connect on                  | Number    |
+-------------------------+-----------------------------------------+-----------+

**Configuration in rabbitmq.config**

You can also change the default connection values in the ``rabbitmq.config`` file:

+--------------+--------------------------------------+-----------+---------------+
| Setting      | Description                          | Data Type | Default Value |
+==============+======================================+===========+===============+
| host         | The Gearman server hostname          | list      | "localhost"   |
+--------------+--------------------------------------+-----------+---------------+
| port         | The port to connect on               | integer   | 8080          |
+--------------+--------------------------------------+-----------+---------------+

*Exaple rabbitmq.config*

..  code-block:: erlang

    [{gearman_http_exchange,
      [
        {host: "localhost"},
        {port: 8080}
      ]}
    ].

Building
--------
Steps to custom build a version of the influx-storage exchange plugin:

.. code-block:: bash

    hg clone http://hg.rabbitmq.com/rabbitmq-public-umbrella
    cd rabbitmq-public-umbrella
    make co
    make BRANCH=rabbitmq_v3_4_2 up_c
    git clone https://github.com/gmr/ibrowse-wrapper.git
    git clone https://github.com/aweber/gearman-http-exchange.git
    cd gearman-http-exchange
    make
