require 'ipaddr'

module Netgen
  class IPCalc
    include Enumerable

    def initialize(family, start, prefixlen, step1, step2 = nil, total = nil)
      @family = family
      @start = IPAddr.new(start).to_i
      @prefixlen = prefixlen
      @step1 = IPAddr.new(step1).to_i
      @step2 = IPAddr.new(step2).to_i if step2
      @total = total
    end

    def fetch(step1, step2 = nil, &block)
      address = @start
      address += @step1 * step1
      address += @step2 * step2 if step2
      if block
        yield(self, address)
      else
        print(address)
      end
    end

    def print(address)
      "#{IPAddr.new(address, @family)}/#{@prefixlen}"
    end

    def each(step2 = nil, &block)
      @total.times do |i|
        yield(fetch(i, step2))
      end
    end
  end
end
