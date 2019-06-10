

# SpanBarHelpers includes some little helpers for convenient usage in SpanBarProcessor
module SpanBarHelpers

  # creates a new upfollowing tick that has a minimum higher value than the preceeding one
  #
  # @param a [Float]
  # @param t [Integer]
  def tickup(a,t=1)
    { p: a[:p] + 0.000000001, t: a[:t] + t, v: 0 }
  end

  # creates a new upfollowing tick that has a minimum lower value than the preceeding one
  #
  # @param a [Float]
  # @param t [Integer]
  def tickdown(a,t=1)
    { p: a[:p] - 0.000000001, t: a[:t] + t, v: 0 }
  end
end

# The main working class 
class SpanBarProcessor
  include SpanBarHelpers

  # Convenient generator for testing purposes
  #
  # @!visibility private
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

  # Creates a new instance of SpanBarProcessor
  #
  # @param opts [Hash]
  # @option opts [Integer] :span     The span to filter for (defaults to 10)
  # @option opts [Float]   :ticksize The ticksize to apply on timeseries (defaults to 1.0)
  # @option opts [Boolean] :simple   Whether to only create simple bars. (defaults to false)
  # @option opts [Boolean] :both     Whether to output simple AND strict bars. (defaults to false, overrides :simple)

  def initialize(opts = {})
    @span = opts[:span].nil? ? 10 : opts[:span] 
    raise ArgumentError, "Span must by of type Integer and > 1" unless @span.is_a? Integer and @span > 1
    @ts     = opts[:ticksize].nil? ? 1.0 : opts[:ticksize]
    raise ArgumentError, "Ticksize must be Numeric, i.e. Integer, Float, ..." unless @ts.is_a? Numeric and @ts > 0
    @simple = opts[:simple].nil? ? false : opts[:simple] 
    if opts[:both] == true
      @simple = false
      @both   = true
    else
      @both   = false
    end
    @limit  = @ts * @span
    @limitMon = Monitor.new
    @simpleMax, @simpleMin = 0, Float::INFINITY
    @simpleBar  = []
    @simpleBars = []
    @spanBars   = [] 
    @ticks  = []
    @intraday   = false
    if opts[:bullish] or opts[:bearish]
      @grace      = opts[:grace].nil? ? 0 : opts[:grace]
      @checkTrend = true
      @bullish    = {bullish: 1, tick: nil, support: nil, resistance: nil, status: nil, counter: nil } if opts[:bullish]
      @bearish    = {bearish: 1, tick: nil, support: nil, resistance: nil, status: nil, counter: nil } if opts[:bearish]
    end
  end

  def update_span(span)
    @limitMon.synchronize do
      @span = span
      @limit = @span * @ts
    end
  end

  # Sends a new items of the timeseries
  #
  # @option t [Integer] The timestamp (preferrably in JS format, i.e. Milliseconds since 1970-01-01)
  # @option p [Float]   The value
  def add(t, p, v = 0)
    result = false
    raise ArgumentError, "SpanBar#add requires either an Integer (Timestamp) or a Time object as first argument" unless [Integer, Time].include?(t.class)
    raise ArgumentError, "SpanBar#add requires either a Numeric or NilClass as second argument" unless p.is_a? Numeric or p.nil?
    return nil if p.nil?
    tick = {t: (t.class == Integer ? t : t.to_i), p: p.to_f, v: v.to_i}
    @simpleBar << tick
    @simpleMax = [tick[:p],@simpleMax].max
    @simpleMin = [tick[:p],@simpleMin].min
    @limitMon.synchronize do
      if @simpleMax - @simpleMin > @limit
        simple = SpanBar.new(@simpleBar, @ts, false)
        unless @simple
          result = self.create_strict_from(simple)
          #result.map{|x| x.inject_span(@span)} if result
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
        end
      end
    end
    if @checkTrend
      trendStatus = self.check_trend_status(t, p)
      if trendStatus and not result
        result = trendStatus
      elsif trendStatus
        trendStatus.each {|t| result << t } 
      end
    end
    return result
  end

  # Private method to further process simple bars to strict bars
  #
  # @option simple [SpanBar]
  def create_strict_from(simple)
    res = [] 
    @limitMon.synchronize do
      elem0 = @currentBar
      elem1 = simple

      if elem0.nil?  # means this is the very first chunk working on
        case elem1.type
        when :bottom
          tmp0, tmp1 = elem1.split_for :low
          @currentBar = SpanBar.new([tmp0.last, tmp1], @ts)
        when :top
          tmp0, tmp1 = elem1.split_for :high
          @currentBar = SpanBar.new([tmp0.last, tmp1], @ts)
        when *[:up,:down]
          @currentBar = SpanBar.new(elem1.resources, @ts)
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
    end # end limitMon
    return res.empty? ? false : res
  end

  def check_trend_status(t, p) 
    result = []
    # update resistance & support
    return false if @spanBars.last.nil?
    # update supports and resistances if unset or changed
    if @recentBar.nil? or @recentBar != @spanBars.last
      debug = false
      peak = @spanBars.last.to_a

      if peak[3] == :UP

        if @bullish
          puts "  entering bullish UP" if debug
          if @bullish[:resistance].nil? and @bullish[:support].nil?          # initialize if unset
            puts "  bullish resistance nil and support nil" if debug
            # ignore
          elsif @bullish[:resistance].nil?
            puts "  bullish resistance nil" if debug
            @bullish[:resistance]    = [ peak[0], peak[1], false ]
            @bullish[:status]        = :resistance
          else
            puts "  bullish resistance not nil" if debug
            if    peak[1] > @bullish[:resistance][1] and @bullish[:support][2]   
              puts "    1" if debug
              @bullish[:resistance]   = [ peak[0], peak[1], true  ]
              @bullish[:status]       = :resistance
            elsif @bullish[:counter] == 0                                       
              puts "    2" if debug
              @bullish[:resistance]   = [ peak[0], peak[1], false ]
              @bullish[:status]       = :resistance
            else                                                               
              puts "    3" if debug
              # ignore
            end
          end
          puts "  #{@bullish}" if debug
          result << @bullish.dup if @bullish[:status] == :resistance
        end

        if @bearish
          if @bearish[:support].nil? or @bearish[:status] == :stopped
            puts "  bearish support nil or stopped" if debug
            @bearish[:support]  = [ peak[0], peak[1], false]
            @bearish[:status]   = :support
            @bearish[:counter]  = 0
          elsif peak[1] <= @bearish[:support][1] and (@bearish[:counter] == 0 or @bearish[:resistance][2])
            puts "  bearish support += 1" if debug
            @bearish[:support]  = [ peak[0], peak[1], true ]
            @bearish[:status]   = :support
            @bearish[:counter] += 1
          end
          puts "  #{@bearish}" if debug
          result << @bearish.dup if @bearish[:status] == :support
        end


      else  # :DOWN

        if @bullish
          puts "  entering bullish DOWN #{t} #{p}" if debug
          if @bullish[:support].nil? or @bullish[:status] == :stopped
            puts "  bullish support nil or stopped" if debug
            @bullish[:support] = [ peak[0], peak[1], false]
            @bullish[:status]  = :support
            @bullish[:counter] = 0
          elsif peak[1] >= @bullish[:support][1] and (@bullish[:counter] == 0 or @bullish[:resistance][2])
            puts "  bullish support += 1" if debug
            @bullish[:support] = [ peak[0], peak[1], true ]
            @bullish[:status]  = :support  
            @bullish[:counter]   += 1
          else

          end
          puts "  #{@bullish}" if debug
          result << @bullish.dup if @bullish[:status] == :support
        end

        if @bearish
          if @bearish[:resistance].nil? and @bearish[:support].nil?          # initialize if unset
            puts "  bearish resistance nil and support nil" if debug
            # ignored
          elsif @bearish[:resistance].nil?
            puts "  bearish resistance nil" if debug
            @bearish[:resistance]    = [ peak[0], peak[1], false ]
            @bearish[:status]        = :resistance
          else
            puts "  bearish resistance not nil" if debug
            if    peak[1] < @bearish[:resistance][1] and @bearish[:support][2]
              puts "    1" if debug
              @bearish[:resistance]   = [ peak[0], peak[1], true  ]
              @bearish[:status]       = :resistance
            elsif @bearish[:counter] == 0
              puts "    2" if debug
              @bearish[:resistance]   = [ peak[0], peak[1], false ]
              @bearish[:status]       = :resistance
            else
              puts "    3" if debug
              # ignore
            end
          end
          puts "  #{@bearish}" if debug
          result << @bearish.dup if @bearish[:status] == :resistance
        end


      end
    end
    @recentBar = @spanBars.last

    if @bullish
      oldbull = @bullish[:status]
      if @bullish and @bullish[:support] and @bullish[:resistance]
        if    [:stopped, :trailing].include? @bullish[:status] and 
            @bullish[:set] > @bullish[:support][0] and 
            @bullish[:set] > @bullish[:resistance][0]
          # ignore 
        elsif    p < @bullish[:support][1] - @grace * @ts       
          @bullish[:status]  = :stopped
          @bullish[:set]     = t
        elsif p < @bullish[:support][1]
          @bullish[:status]  = :graced
        elsif p > @bullish[:resistance][1]
          @bullish[:status]  = :trailing
          @bullish[:set]     = t
        elsif @bullish[:support][0] < @bullish[:resistance][0] 
          @bullish[:status]  = :waiting
          @bullish.delete(:set)
        else 
          @bullish[:status]  = :gathering
          @bullish.delete(:set)
        end
        @bullish[:tick]      = [t,p]
      end
      result << @bullish.dup unless @bullish[:status] == oldbull
    end

    if @bearish
      oldbear = @bearish[:status]
      if @bearish and @bearish[:support] and @bearish[:resistance]
        if    [:stopped, :trailing].include? @bearish[:status] and
            @bearish[:set] > @bearish[:support][0] and
            @bearish[:set] > @bearish[:resistance][0]
          # ignore 
        elsif p > @bearish[:support][1] + @grace * @ts
          @bearish[:status]  = :stopped
          @bearish[:set]     = t
        elsif p > @bearish[:support][1]
          @bearish[:status]  = :graced
        elsif p < @bearish[:resistance][1]
          @bearish[:status]  = :trailing
          @bearish[:set]     = t
        elsif @bearish[:support][0] < @bearish[:resistance][0]
          @bearish[:status]  = :waiting
          @bearish.delete(:set)
        else
          @bearish[:status]  = :gathering
          @bearish.delete(:set)
        end
        @bearish[:tick]      = [ t, p]
      end
      result << @bearish.dup unless @bearish[:status] == oldbear
    end

    if result.empty?
      result = false
    else
      result.map! do |bar|
        if [:support, :resistance].include? bar[:status]
          [ bar[bar[:status]][0], bar[bar[:status]][1], 0, (bar[:bullish].nil? ? :bearish : :bullish), nil, nil, bar[:status], bar[:counter] ]
        else
          [ bar[:tick][0], bar[:tick][1], 0, (bar[:bullish].nil? ? :bearish : :bullish), nil, nil, bar[:status] ]
        end
      end
    end

    #puts "Inner: #{result}" if result
    return result
  end

end
