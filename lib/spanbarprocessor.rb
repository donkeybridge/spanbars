# frozen_string_literal: true

# SpanBarHelpers includes some little helpers for convenient usage in SpanBarProcessor
module SpanBarHelpers
  # creates a new successor tick that has a minimum higher value than the preceding one
  #
  # @param tick [Hash]
  # @param dist [Integer]
  def tick_up(tick, dist: 1)
    { p: tick[:p] + 0.000000001, t: tick[:t] + dist }
  end

  # creates a new successor tick that has a minimum lower value than the preceding one
  #
  # @param tick [Hash]
  # @param dist [Integer]
  def tick_down(tick, dist: 1)
    { p: tick[:p] - 0.000000001, t: tick[:t] + dist }
  end
end

# The main working class
class SpanBarProcessor
  include SpanBarHelpers

  # Convenient generator for testing purposes
  #
  # @!visibility private
  def self.generate_random
    p = SpanBarProcessor.new(span: 5)
    i = 5
    t = 1
    s = true
    while s
      s = p.add(timestamp: t, value: i)
      t += 1 + (Random.rand * 10).to_i
      i += Random.rand > 0.5 ? 1 : -1
    end
    s
  end

  attr_reader :simple_bar, :simple_bars, :span_bars

  # Creates a new instance of SpanBarProcessor
  #
  # @param opts [Hash]
  # @option opts [Integer] :span     The span to filter for (defaults to 10)
  # @option opts [Float]   :ticksize The ticksize to apply on timeseries (defaults to 1.0)
  # @option opts [Boolean] :simple   Whether to only create simple bars. (defaults to false)
  # @option opts [Boolean] :both     Whether to output simple AND strict bars. (defaults to false, overrides :simple)

  def initialize(span:, # rubocop:disable Metrics/ParameterLists
                 ticksize: 1.0, simple: false, both: false,
                 grace: 0, bullish: false, bearish: false, **key_args)
    @span = span
    raise ArgumentError, 'Span must by of type Integer and > 1' unless @span.is_a?(Integer) && (@span > 1)

    @ts = ticksize
    raise ArgumentError, 'Ticksize must be Numeric, i.e. Integer, Float, ...' unless @ts.is_a?(Numeric) && @ts.positive?

    @simple = simple
    if both
      @simple = false
      @both   = true
    else
      @both   = false
    end
    @limit = @ts * @span
    @limit_mon = Monitor.new
    @simple_max = 0
    @simple_min = Float::INFINITY
    @simple_bar  = []
    @simple_bars = []
    @span_bars   = []
    @ticks = []
    @intraday = false
    return unless bullish || bearish

    @grace = grace
    @check_trend = true
    @bullish    = { bullish: 1, tick: nil, support: nil, resistance: nil, status: nil, counter: nil } if bullish
    @bearish    = { bearish: 1, tick: nil, support: nil, resistance: nil, status: nil, counter: nil } if bearish
  end

  # Sends a new items of the timeseries
  #
  # @option timestamp [Integer] The timestamp (preferably in JS format, i.e. milliseconds since 1970-01-01)
  # @option value [Float]   The value
  def add(timestamp:, value:, position: false)
    result = false
    unless [Integer, Time].include?(timestamp.class)
      raise ArgumentError, 'SpanBar#add requires either an Integer (Timestamp) or a Time object as first argument'
    end
    unless value.is_a?(Numeric) || value.nil?
      raise ArgumentError, 'SpanBar#add requires either a Numeric or NilClass as second argument'
    end
    return nil if value.nil?

    tick = {
      t: timestamp.instance_of?(Integer) ? timestamp : timestamp.to_i,
      p: value.to_f
    }
    @simple_bar << tick
    @simple_max = [tick[:p], @simple_max].max
    @simple_min = [tick[:p], @simple_min].min
    @limit_mon.synchronize do
      if @simple_max - @simple_min > @limit
        simple = SpanBar.new(@simple_bar, ticksize: @ts, strict: false)
        result = create_strict_from(simple) unless @simple
        @simple_bars << simple
        @simple_max = 0
        @simple_min = Float::INFINITY
        @simple_bar = []
        return [simple] if @simple

        begin
          result << simple if @both && simple
        rescue StandardError
          return [simple]
        end
      end
    end
    if @check_trend
      trend_status = check_trend_status(timestamp: timestamp, value: value, position: position)
      if trend_status && (not result)
        result = trend_status
      elsif trend_status
        trend_status.each { |t_s| result << t_s }
      end
    end
    result
  end

  # Private method to further process simple bars to strict bars
  #
  # @option simple [SpanBar]
  def create_strict_from(simple)
    res = []
    @limit_mon.synchronize do
      elem0 = @currentBar
      elem1 = simple

      # rubocop:disable Metrics/BlockNesting
      if elem0.nil?  # means this is the very first chunk working on
        case elem1.type
        when :bottom
          tmp0, tmp1 = elem1.split_for :low
          @current_bar = SpanBar.new([tmp0.last, tmp1], ticksize: @ts)
        when :top
          tmp0, tmp1 = elem1.split_for :high
          @current_bar = SpanBar.new([tmp0.last, tmp1], ticksize: @ts)
        when :up, :down
          @current_bar = SpanBar.new(elem1.resources, ticksize: @ts)
        else
          raise "Invalid type for initial simple SpanBar #{elem0}"
        end
      else           # otherwise there is already a preceding element
        case elem0.type
        when :up
          case elem1.type
          when :bottom, :up
            if elem0.close - elem1.low > @limit
              res << elem0
              tmp0, tmp1 = elem1.split_for :low
              res << SpanBar.new([tick_up(elem0.resources.last), tmp0], ticksize: @ts)
              @current_bar = SpanBar.new([tick_up(tmp0.last), tmp1], ticksize: @ts)
            elsif (elem0.close - elem1.low <= @limit) && (elem0.close <= elem1.close)
              @current_bar = SpanBar.new([elem0.resources, elem1.resources], ticksize: @ts)
            end
          when :top, :down
            if elem1.high >= elem0.close
              tmp0, tmp1 = elem1.split_for :high
              res << SpanBar.new([elem0.resources, tmp0], ticksize: @ts)
              @current_bar = SpanBar.new([tick_down(tmp0.last), tmp1], ticksize: @ts)
            else
              res << elem0
              @current_bar = SpanBar.new([tick_up(elem0.resources.last), elem1.resources], ticksize: @ts)
            end
          else
            raise "Unknown type for secondary simple SpanBar #{elem1}"
          end
        when :down
          case elem1.type
          when :top, :down
            if elem1.high - elem0.close > @limit # only for percentage !?: or elem1.low <= elem0.low
              res << elem0
              tmp0, tmp1 = elem1.split_for :high
              res << SpanBar.new([tick_up(elem0.resources.last), tmp0], ticksize: @ts)
              @current_bar = SpanBar.new([tick_down(tmp0.last), tmp1], ticksize: @ts)
            elsif (elem1.high - elem0.close <= @limit) && (elem0.close >= elem1.close)
              @current_bar = SpanBar.new([elem0.resources, elem1.resources], ticksize: @ts)
            end
          when :bottom, :up
            if elem1.low <= elem0.close
              tmp0, tmp1 =  elem1.split_for :low
              res <<        SpanBar.new([elem0.resources, tmp0], ticksize: @ts)
              @current_bar = SpanBar.new([tick_up(tmp0.last), tmp1], ticksize: @ts)
            else
              res << elem0
              @current_bar = SpanBar.new([tick_up(elem0.resources.last), elem1.resources], ticksize: @ts)
            end
          else
            raise "Unknown or invalid type for secondary simple SpanBar #{elem1}"
          end
        else
          raise "Unknown or invalid type for primary simple SpanBar #{elem0}"
        end
      end

      res.each { |x| @spanBars << x }
    end
    res.empty? ? false : res
    # rubocop:enable Metrics/BlockNesting
  end

  # noinspection RubyScope
end
