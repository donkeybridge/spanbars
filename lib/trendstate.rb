# frozen_string_literal: true

# documented elsewhere
# noinspection RubyScope
class SpanBarProcessor
  def check_trend_status(timestamp:, value:, position: false)
    result = []
    # update resistance & support
    return false if @spanBars.last.nil?

    # update supports and resistances if unset or changed
    #
    # There is a mistake in here (example bullish)
    #   when there is a new support found after a resistance that is higher than previous,
    #   the next support is only valid if it is same support as before
    #   otherwise, it has to be gathered with all possible supports.
    #   the actual next support is found as soon as next "trailing" status is reached.
    #
    if @recentBar.nil? || (@recentBar != @spanBars.last)
      debug = false
      peak = @spanBars.last.to_a

      # rubocop:disable Metrics/BlockNesting
      if peak[3] == :UP

        if @bullish
          puts '  entering bullish UP' if debug
          if @bullish[:resistance].nil? && @bullish[:support].nil? # initialize if unset
            puts '  bullish resistance nil and support nil' if debug
            # ignore / wait for first support
          elsif @bullish[:resistance].nil?
            # puts "  bullish resistance nil" if debug
            @bullish[:resistance]    = [peak[0], peak[1]]
            @bullish[:status]        = :resistance
          else
            puts '  bullish resistance not nil' if debug
            puts @bullish.to_s
            if    peak[1] > @bullish[:resistance][1] # and @bullish[:support][2]
              puts '    1' if debug
              @bullish[:resistance]   = [peak[0], peak[1]]
              @bullish[:status]       = :resistance
            elsif (@bullish[:counter]).zero?
              puts '    2' if debug
              @bullish[:resistance]   = [peak[0], peak[1]]
              @bullish[:status]       = :resistance
            elsif debug
              puts '    3'
            end
          end
          puts "  #{@bullish}" if debug
          result << @bullish.dup if @bullish[:status] == :resistance
        end

        if @bearish
          if @bearish[:support].nil? || (@bearish[:status] == :stopped)
            puts '  bearish support nil or stopped' if debug
            @bearish[:supports] = []
            @bearish[:support]  = [peak[0], peak[1]]
            @bearish[:resistance] = nil
            @bearish[:status]   = :support
            @bearish[:counter]  = 0
          elsif peak[1] <= @bearish[:support][1] # and (@bearish[:counter] == 0) # or @bearish[:resistance][2])
            puts " adding bearish support candidate #{[peak[0], peak[1]]}"
            @bearish[:supports] << [peak[0], peak[1]]
            # @bearish[:status]   = :support
            # @bearish[:counter] += 1
          end
          puts "  #{@bearish}" if debug
          result << @bearish.dup if @bearish[:status] == :support
        end

      else  # :DOWN

        if @bullish
          puts "  entering bullish DOWN #{t} #{p}" if debug
          if @bullish[:support].nil? || (@bullish[:status] == :stopped)
            puts '  bullish support nil or stopped' if debug
            @bullish[:supports] = []
            @bullish[:support] = [peak[0], peak[1]]
            @bullish[:status]  = :support
            @bullish[:counter] = 0
          elsif peak[1] >= @bullish[:support][1] # and (@bullish[:counter] == 0) # or @bullish[:resistance][2])
            puts " adding bullish support candidate #{[peak[0], peak[1]]}"
            @bullish[:supports] << [peak[0], peak[1]]
            # @bullish[:status]  = :support
            # @bullish[:counter]   += 1
          end
          puts "  #{@bullish}" if debug
          result << @bullish.dup if @bullish[:status] == :support
        end

        if @bearish
          if @bearish[:resistance].nil? || @bearish[:support].nil? # initialize if unset
            puts '  bearish resistance nil or support nil' if debug
            # ignored
            # elsif @bearish[:resistance].nil?
            # puts "  bearish resistance nil" if debug
            @bearish[:resistance]    = [peak[0], peak[1]]
            @bearish[:status]        = :resistance
          else
            puts '  bearish resistance not nil' if debug
            if peak[1] < @bearish[:resistance][1] # and @bearish[:support][2]
              puts '    1' if debug
              @bearish[:resistance]   = [peak[0], peak[1]]
              @bearish[:status]       = :resistance
              # elsif @bearish[:counter] == 0
              #  puts "    2" if debug
              #  @bearish[:resistance]   = [ peak[0], peak[1] ]
              #  @bearish[:status]       = :resistance
            elsif debug
              puts '    3'
              # ignore
            end
          end
          puts "  #{@bearish}" if debug
          result << @bearish.dup if @bearish[:status] == :resistance
        end

      end
    end
    @recent_bar = @spanBars.last

    if @bullish
      old_bull = @bullish[:status]
      if @bullish && @bullish[:support] && @bullish[:resistance]
        if %i[stopped trailing].include?(@bullish[:status]) &&
           (@bullish[:set]    > @bullish[:support][0]) &&
           (@bullish[:set]    > @bullish[:resistance][0])
          # ignore
        elsif position ? (value < @bullish[:support][1] - @grace * @ts) : (value < @bullish[:support][1])
          @bullish[:status]   = :stopped
          @bullish[:set]      = timestamp
        elsif p < @bullish[:support][1]
          @bullish[:status]   = :graced
        elsif p > @bullish[:resistance][1]
          unless @bullish[:supports].empty?
            @bullish[:support] = @bullish[:supports].min_by { |s| s[1] }
            puts " Setting bullish supports now #{@bullish[:supports]} --> #{@bullish[:support]}"
            @bullish[:status]   = :support
            @bullish[:supports] = []
            @bullish[:counter] += 1
            result << @bullish.dup
          end
          @bullish[:status]   = :trailing
          @bullish[:set]      = timestamp
        elsif @bullish[:support][0] < @bullish[:resistance][0]
          @bullish[:status]   = :waiting
          @bullish.delete(:set)
        else
          @bullish[:status] = :gathering
          @bullish.delete(:set)
        end
        @bullish[:tick] = [timestamp, value]
      end
      result << @bullish.dup unless @bullish[:status] == old_bull
    end

    if @bearish
      old_bear = @bearish[:status]
      if @bearish && @bearish[:support] && @bearish[:resistance]
        if %i[stopped trailing].include?(@bearish[:status]) &&
           (@bearish[:set] > @bearish[:support][0]) &&
           (@bearish[:set] > @bearish[:resistance][0])
          # ignore
        elsif position ? (p > @bearish[:support][1] + @grace * @ts) : (p > @bearish[:support][1])
          @bearish[:status]   = :stopped
          @bearish[:set]      = timestamp
        elsif p > @bearish[:support][1]
          @bearish[:status]   = :graced
        elsif p < @bearish[:resistance][1]
          unless @bearish[:supports].empty?
            @bearish[:support] = @bearish[:supports].max_by { |s| s[1] }
            puts " Setting bearish supports now #{@bearish[:supports]} --> #{@bearish[:support]}"
            @bearish[:status]   = :support
            @bearish[:supports] = []
            @bearish[:counter] += 1
            result << @bearish.dup
          end
          @bearish[:status]   = :trailing
          @bearish[:set]      = timestamp
        elsif @bearish[:support][0] < @bearish[:resistance][0]
          @bearish[:status]   = :waiting
          @bearish.delete(:set)
        else
          @bearish[:status] = :gathering
          @bearish.delete(:set)
        end
        @bearish[:tick] = [timestamp, value]
      end
      result << @bearish.dup unless @bearish[:status] == old_bear
    end

    if result.empty?
      result = false
    else
      result.map! do |bar|
        if %i[support resistance].include? bar[:status]
          [bar[bar[:status]][0],
           bar[bar[:status]][1], 0,
           (bar[:bullish].nil? ? :bearish : :bullish), nil, nil,
           bar[:status],
           bar[:counter]]
        else
          [bar[:tick][0], bar[:tick][1], 0, (bar[:bullish].nil? ? :bearish : :bullish), nil, nil, bar[:status]]
        end
      end
    end
    result
  end
  # rubocop:enable Metrics/BlockNesting
end
