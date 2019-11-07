# Netgen

TODO

## Installation

1 - Install ruby:

Debian-based Linux distributions:
```
# apt-get install ruby ruby-dev
```

RHEL/Fedora-based Linux distributions:
```
# yum install ruby ruby-devel
```

2- Install the bundler gem (version 1.15 is needed):
```
# gem install bundler -v 1.15
# bundle _1.15_ install
```

If you are getting timeouts you might have run into an [IPv6 issue](https://help.rubygems.org/discussions/problems/31074-timeout-error).
On systemd enabled systems you can use

```
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
```

to disable IPv6.

3 -Download and install netgen:
```
$ git clone https://github.com/rwestphal/netgen.git
$ cd netgen/
$ bundle install
$ bundle exec rake install
```

## Usage

1 - Edit netgen's configuration file (optional):
```
$ vim config.yml
```

Default values that are important to be aware of:
* pcap files are stored in _/tmp/netgen/pcaps/_
* FRR logs are stored in _/tmp/netgen/frrlogs/_

2 - Run netgen (needs superuser permissions):
```
# netgen ~/netgen-topologies/frr-ospf.yml
```

3 - Run a program on a given virtual router:
```
# netgen-exec rt0 vtysh
# netgen-exec rt1 bash
# netgen-exec rt1 ifconfig
```

4 - You can also run _/tmp/netgen/tmux.sh_ to open a tmux session with a panel for each node. Example:
[![asciicast](https://asciinema.org/a/eMNd36SBODiHxE4rF51RYnKun.svg)](https://asciinema.org/a/eMNd36SBODiHxE4rF51RYnKun)

## Development

TODO

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rwestphal/netgen.
