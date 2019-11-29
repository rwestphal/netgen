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
$ gem install bundler -v 1.15
$ bundle _1.15_ install
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
$ netgen -f config.yml topology.yml
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

There are two ways of working on the nodes which are configured in the
topology file, the `tmux` plugin or `netgen-exec` (again, you need
superuser permission).

By default a `tmux` session is created an accessible via:

```
/tmp/netgen/tmux.sh
```

Here you will see by default one tab per configured node. The tabs are
named after the node name.

Run a program directly using `netgen-exec` on a given node:

```
$ netgen-exec rt0 vtysh
$ netgen-exec rt1 bash
$ netgen-exec rt1 ifconfig
```

## Development

TODO

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rwestphal/netgen.
