# netgen

_The swiss army knife of network simulation._

`netgen` is a low footprint tool using linux namespaces to set
up a topology of virtual nodes, network interfaces and switches on your
local machine. There is a strong builtin support for `FRR` which can be
configured to run on such a virtual node to simulate routing scenarios.
Nevertheless `netgen` follows a plugin architecture and can be used in
many different ways, not necessarily related to `FRR`.

## Installation

### Install ruby:

Debian-based Linux distributions:

```
$ apt-get install ruby ruby-dev
```

RHEL/Fedora-based Linux distributions:

```
$ yum install ruby ruby-devel
```

### Install the bundler gem (version 1.15 is needed):

```
$ gem install bundler -v 2.5.20
$ bundle _2.5.20_ install
```

If you are getting timeouts you might have run into an [IPv6 issue](https://help.rubygems.org/discussions/problems/31074-timeout-error).
On systemd enabled systems you can use

```
$ sysctl -w net.ipv6.conf.all.disable_ipv6=1
$ sysctl -w net.ipv6.conf.default.disable_ipv6=1
```

to disable IPv6.

### Download and install netgen:

```
$ git clone https://github.com/rwestphal/netgen.git
$ cd netgen/
$ bundle install
$ bundle exec rake install
```

## Usage

Two configuration files are needed to set up a `netgen` topology:

1. The netgen configuration `config.yml`
2. The topology configuration, see e.g. `/examples/frr-isis-tutorial.yml`

Then `netgen` can be started like this (using superuser permissions):

```
$ netgen -c config.yml topology.yml
```

By default the `config.yml` is taken from the current directory, so a
'quick' way to get something running would be for example:

```
$ netgen examples/frr-isis-tutorial.yml
```

If this doesn't work out, make sure you have `FRR` installed and
executables (like `zebra`) in your `$PATH`.

`netgen` follows a plugin architecture and those plugins can be
configured in the `config.yml`. The most important plugin here is `frr`.
Have a look into the provided example `config.yml` to get an overview.
By default `netgen` stores all information in `/tmp/netgen` including
PCAP files for all interfaces and `FRR` logs from every node. This
makes introspection quite easy.


### Working with Nodes

There are two ways of working on the nodes which are configured in the
topology file, the `tmux` plugin or `netgen-exec` (again, you need
superuser permission).

By default a `tmux` session is created an accessible via:

```
$ /tmp/netgen/tmux.sh
```

Here you will see by default one tab per configured node. The tabs are
named after the node name.

Run a program directly using `netgen-exec` on a given node:

```
$ netgen-exec rt0 vtysh
$ netgen-exec rt1 bash
$ netgen-exec rt1 ifconfig
```


### Topology Configuration

There is an example topology configuration at `/examples/frr-isis-tutorial.yml`
which will teach you how to

* setup a node (with and without `FRR`)
* setup interfaces
* setup switches
* use the `frr` plugin
* use the `shell` plugin
* introspect interfaces and nodes

What is _not_ further explained here are networking and `FRR` related configuration
basics. The example is about IS-IS and it is assumed that the reader is
somewhat familiar with it. `FRR` configuration docu is available
[here](http://docs.frrouting.org/en/latest/isisd.html).

The example can be run using:

```
$ netgen examples/frr-isis-tutorial.yml
```

As explained above you can use `tmux` or `netgen-exec` to perform e.g. a ping
test on the `src` node to check if the `dst` node is available by executing
`ping 9.9.9.2`. It might take a minute until this test is successful because
IS-IS distribution was not established yet.

Note that by default the `tmux` session, PCAPs, logs etc. are available in
`/tmp/netgen`:

```
$ ls /tmp/netgen/
frrlogs/  mounts/   pcaps/    perf/     pids.yml  tmux.sh

$ ls /tmp/netgen/pcaps/
dst/ rt1/ rt2/ rt3/ rt4/ rt5/ rt6/ src/ sw1/
```


#### Basic Configuration Structure

```
routers:

  some_node:
    links:
      some_interface:
        peer: [some_other_node, some_other_interface]
        ipv4: 1.2.3.4/32
        [further interface configuration]
    frr:
      zebra:
        run: yes
        config:
        [further zebra config]
      [further FRR config]
    shell: |
      echo "Hello World!"
      [further shell commands executed at node start]
    some_other_plugin:
      [further plugin configuration]
    [further node configuration]

  some_other_node
    [node configuration]

switches:
  sw1:
    links:
      some_switch_interface:
        peer: [peer-interface1, peer-interface2]
      [further interfaces]
  [further switch nodes]

frr:
  perf: yes
  valgrind: yes
  base-configs:
    all: |
      hostname %{node}
      password 12345
      [further configuration for all FRR nodes]
    zebra: |
      debug zebra kernel
      [further zebra configuration for all nodes]
    [further configuration for other daemons on all nodes]
```

There is one very important thing here to remember: many
configuration parts are forwarded to `FRR` and its daemons
as literal blocks and those blocks must be preserved in
YAML e.g. using the `|` sign. This also means that newlines
must be taken special care of using `!` as connector in the
following sense:

```
config: |
  some_config:
    [some sub configuration]
  !
  some_other_config:
    [some other sub configuration]
```


## Development

TODO

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rwestphal/netgen.
