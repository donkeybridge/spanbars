require './lib/spanbar.rb'
require 'slop'
require 'csv'
require 'json'
require 'colorize'
require 'outputhandler'


module SpanBarHelpers

  def tickup(a,t=1)
    { p: a[:p] + 0.000000001, t: a[:t] + t }
  end

  def tickdown(a,t=1)
    { p: a[:p] - 0.000000001, t: a[:t] + t }
  end
end

class SpanBarProcessor
  include SpanBarHelpers

  def self.generate_random
    p = self.new(5,1)
    i = 5
    t = 1
    s = true
    while s == true
      s = p.add(t,i)
      t += 1 + (Random.rand * 10 ).to_i
      i += Random.rand > 0.5 ? 1 : -1
    end
    s
  end

  attr_reader :simpleBar, :simpleBars, :spanBars

  def initialize(opts = {})
    @span = opts[:span].nil? ? 6 : opts[:span] 
    raise ArgumentError, "Span must by of type Integer and > 1" unless @span.is_a? Integer and @span > 1
    @ts     = opts[:ticksize].nil? ? 1 : opts[:ticksize]
    raise ArgumentError, "Ticksize must be Numeric, i.e. Integer, Float, ..." unless @ts.is_a? Numeric and @ts > 0
    @simple = opts[:simple].nil? ? false : opts[:simple] 
    if opts[:both] == true
      @simple = false
      @both   = true
    else
      @both   = false
    end
    @limit  = @ts * @span
    @simpleMax, @simpleMin = 0, Float::INFINITY
    @simpleBar  = []
    @simpleBars = []
    @spanBars   = [] 
    @ticks  = []
    @intraday = opts[:intraday].nil? ? false : opts[:intraday] 
  end

  def add(t, p)
    raise ArgumentError, "SpanBar#add requires either an Integer (Timestamp) or a Time object as first argument" unless [Integer, Time].include?(t.class)
    raise ArgumentError, "SpanBar#add requires either a Numeric or NilClass as second argument" unless p.is_a? Numeric or p.nil?
    return nil if p.nil?
    tick = {t: (t.class == Integer ? t : t.to_i), p: p.to_f}
    @simpleBar << tick
    @simpleMax = [tick[:p],@simpleMax].max
    @simpleMin = [tick[:p],@simpleMin].min
    if @simpleMax - @simpleMin > @limit
      simple = SpanBar.new(@simpleBar, @ts, false)
      unless @simple
        result = self.create_strict_from(simple)
      end
      @simpleBars << simple
      @simpleMax, @simpleMin = 0, Float::INFINITY
      @simpleBar = []
      if @simple 
        return [ simple ] # we need an Array from caller
      else
        begin 
          result << simple if @both and simple 
        rescue 
          return [ simple ] 
        end
        return result
      end
    end
    return false
  end

  def create_strict_from(simple)
    elem0 = @currentBar
    elem1 = simple

    res   = [ ]
    if elem0.nil?  # means this is the very first chunk working on
      case elem1.type
      when :bottom
        tmp0, tmp1 = elem1.split_for :low
        @currentBar = SpanBar.new([tmp0.last, tmp1], @ts)
      when :top
        tmp0, tmp1 = elem1.split_for :high
        @currentBar = SpanBar.new([tmp0.last, tmp1], @ts)
      when *[:up,:down]
        @currentBar = elem1
      else
        raise "Invalid type for initial simple SpanBar #{elem0}"
      end
    else           # otherwise there is already a preceding element
      case elem0.type
      when :up
        case elem1.type
        when *[:bottom, :up]
          if elem0.close - elem1.low > @limit
            res << elem0
            tmp0, tmp1 = elem1.split_for :low
            res <<        SpanBar.new([ tickup(elem0.resources.last), tmp0 ], @ts)
            @currentBar = SpanBar.new([ tickup(tmp0.last),tmp1], @ts)
          elsif elem0.close - elem1.low <= @limit and elem0.close <= elem1.close
            @currentBar = SpanBar.new([ elem0.resources, elem1.resources], @ts)
          else 
            # silently dropping unneeded fragment
          end
        when *[:top, :down]
          if elem1.high >= elem0.close
            tmp0, tmp1 = elem1.split_for :high
            res << SpanBar.new([ elem0.resources, tmp0 ], @ts)
            @currentBar = SpanBar.new([tickdown(tmp0.last),tmp1], @ts)
          else
            res << elem0
            @currentBar = SpanBar.new([ tickup(elem0.resources.last), elem1.resources], @ts)
          end
        else
          raise "Unknown type for secondary simple SpanBar #{elem1}"
        end
      when :down
        case elem1.type
        when *[:top, :down]
          if elem1.high - elem0.close > @limit # only for percentage !?: or elem1.low <= elem0.low
            res << elem0
            tmp0, tmp1 = elem1.split_for :high
            res <<        SpanBar.new([  tickup(elem0.resources.last), tmp0 ], @ts)
            @currentBar = SpanBar.new([tickdown(tmp0.last),tmp1], @ts)
          elsif elem1.high - elem0.close <= @limit and elem0.close >= elem1.close
            @currentBar = SpanBar.new([elem0.resources, elem1.resources], @ts)
          else
            # silently dropping unneeded fragment 
          end
        when *[:bottom, :up]
          if elem1.low <= elem0.close
            tmp0, tmp1 =  elem1.split_for :low
            res <<        SpanBar.new([ elem0.resources, tmp0 ], @ts)
            @currentBar = SpanBar.new([tickup(tmp0.last),tmp1],  @ts)
          else
            res << elem0
            @currentBar = SpanBar.new([ tickup(elem0.resources.last), elem1.resources], @ts)
          end
        else
          raise "Unknown or invalid type for secondary simple SpanBar #{elem1}"
        end
      else
        raise "Unknown or invalid type for primary simple SpanBar #{elem0}"
      end
    end

    res.each {|x| @spanBars << x }
    return res.empty? ? false : res
  end

  def set_intraday
    @spanBars.each{|bar| bar.set_intraday}
  end

end
