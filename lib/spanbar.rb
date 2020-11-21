# frozen_string_literal: true

# A model for SpanBars
class SpanBar
  attr_reader :type, :resources, :open, :high, :low, :close, :high_val, :lowval

  # Checks if instance has a type and is not :error
  def valid?
    not (@type.nil? or @type == :error)
  end

  # Calculates the path of the instance, i.e. sums up all moves, regardless of up or down
  def path
    return @path unless @path.nil?

    prev = @resources[0][:p]
    @path = 0
    1.upto(@resources.size - 1) do |i|
      @path += (@resources[i][:p] - prev).abs
      prev  =  @resources[i][:p]
    end
    @path /= @ticksize
  end

  # @!visibility private
  def start
    @start  ||= @open_val[:t]
  end

  # @!visibility private
  def end
    @end    ||= @close_val[:t]
  end

  # Calculates the momentum, i.e. the speed of move in current instance
  def momentum
    @momentum ||= path.to_f / @duration
  end

  def direction
    @type
  end

  # Creates a new instance
  #
  # @option b [Array] expects an Array of measures
  # @option ticksize [Float] The ticksize of underlying processor (defaults to 1.0)
  # @option strict   [Boolean] Whether this is a strict or a simple SpanBar (defaults to :true)
  def initialize(bar, ticksize: 1.0, strict: true)
    a = bar.dup.flatten.compact
    return if a.nil? || a.empty?

    # Quick helper to calculate the amount of decimals in the ticksize
    decimals = lambda do |param|
      num = 0
      while param != param.to_i
        num += 1
        param *= 10
      end
      num
    end

    @ticksize   = ticksize
    @intraday   = false
    @format     = "%1.#{decimals.call(@ticksize)}f"
    @strict     = strict
    @open_val   = a[0]
    @close_val  = a[-1]
    @high_val    = a.reverse.max_by { |x| x[:p] }
    @low_val     = a.reverse.min_by { |x| x[:p] }
    @open       = @open_val[:p]
    @high       = @high_val[:p]
    @low        = @low_val[:p]
    @close      = @close_val[:p]
    @duration   = (@close_val[:t] - @open_val[:t]) / 1000
    @resources  = a
    @path       = path
    @momentum   = momentum.round(8)
    @type = if @high == @close
              @low  == @open ? :up : :bottom
            elsif @low == @close
              @high == @open ? :down : :top
            else
              :error
            end
    # puts self.inspect
    raise "Validation error: Type must be :up or :down for #{inspect}" if @strict && (not %i[up down].include?(@type))
  end

  # Method that splits the @resources Array (containing all measures of the bar) at peak
  #
  # @option peak (Symbol) Can be either :high or :low
  def split_for(peak)
    tmp0 = []
    case peak
    when :high
      tmp0.prepend(@resources.pop) while @resources.last[:p] < @high
    when :low
      tmp0.prepend(@resources.pop) while @resources.last[:p] > @low
    else
      raise "Unknown peak #{peak} found in :split_for."
    end
    [@resources, tmp0]
  end

  # For human output, set output
  def set_intraday
    @intraday = true
  end

  # Returns an inspection string
  def inspect
    pval = ->(val) { "#{val[:t]}::#{@format % val[:p]}" }
    # rubocop:disable Layout/ClosingParenthesisIndentation
    # rubocop:disable Style/FormatString
    if @strict
      "<#SpanBar:0x00#{object_id.to_s(16)
      }, strict, :#{@type
      },\tpath: #{'%g' % path
      }, momentum: #{'%g' % momentum
      }, open: #{pval.call(@open_val)
      }, close: #{pval.call(@close_val)
      }>"
    else
      "<#SpanBar:0x00#{object_id.to_s(16)
      }, simple, :#{@type
      },\tpath: #{'%g' % path
      }, momentum: #{'%g' % momentum
      }, open: #{pval.call(@open_val)
      }, high: #{pval.call(@high_val)
      }, close: #{pval.call(@close_val)
      }>"
    end
    # rubocop:enable Layout/ClosingParenthesisIndentation
    # rubocop:enable Style/FormatString
  end

  # Return human readable output of instance
  def to_human
    time = if @intraday
             lambda do |t|
               now = (t / 1000) % 86_400
               "#{format('%02d', (now / 3600))}:#{format('%02d', ((now % 3600) / 60))}" \
               ":#{format('%02d', (now % 60))}"
             end
           else
             ->(t) { Time.at(t / 1000).strftime('%Y %b %d %H:%M:%S') }
           end
    pval = ->(v) { "[#{time.call(v[:t])}, #{@format % v[:p]}]" }
    # rubocop:disable Layout/ClosingParenthesisIndentation
    if @strict
      "STRICT, #{pval.call(@close_val)
      },\tMOM: #{format('%g', (@momentum / @ticksize))
      },\tDUR: #{@duration
      },\tEFF: #{((@close - @open) / @ticksize).to_i
      },\t:#{@type.to_s.upcase
      }"
    else
      "SIMPLE, OPEN: #{pval.call(@open_val)
      }, #{ %i[up bottom].include?(@type) ? "LOW: #{pval.call(@low_val)}" : "HIGH #{pval.call(@high_val)}"
      }, CLOSE: #{pval.call(@close_val)
      }, MOM: #{format('%g', (@momentum / @ticksize))
      },\tDUR: #{@duration
      },\tEFF: #{((@close - @open) / @ticksize).to_i}, :#{@type}"
    end
    # rubocop:enable Layout/ClosingParenthesisIndentation
  end

  # Returns an array containing instance values as needed for CSV output
  #
  # Format is
  #   closing_time,
  #   close_val,
  #   volume,
  #   type (UPCASE for strict),
  #   high/low-time for top/bottom OR nil,
  #   high/low-val  for top/bottom OR nil,
  #   duration in ms
  #   path
  #   momentum
  #   move
  #   overdrive (if STRICT) or NIL
  #   recognition_time
  def to_a
    if @strict
      [
        @close_val[:t], @close_val[:p].round(8), @vol, # so far it is the same as each other tick !!
        @type.to_s.upcase.to_sym, nil, nil,
        @duration, @path.round(8), @momentum.round(8),
        ((@close - @open) / @ticksize).to_i, # @overdrive,
        (Time.now.to_f * 1000).to_i
      ]
    else
      [
        @close_val[:t], @close_val[:p].round(8), @vol, # so far it is the same as each other tick
        @type,
        if %i[top bottom].include?(@type.to_sym)
          (@type.to_sym == :top ? @high_val[:t] : @low_val[:t])
        end,
        if %i[top bottom].include?(@type.to_sym)
          (@type.to_sym == :top ? @high_val[:p] : @low_val[:p])
        end,
        @duration, @path.round(8), @momentum.round(8),
        ((@close - @open) / @ticksize).to_i, nil, (Time.now.to_f * 1000).to_i
      ]
    end
  end
end
