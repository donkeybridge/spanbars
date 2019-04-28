# A model for SpanBars
class SpanBar

  attr_reader :type, :resources, :open, :high, :low, :close, :highval, :lowval

  # Checks if instance has a type and is not :error
  def valid? 
    not (@type.nil? or @type == :error)
  end

  # Calculates the path of the instance, i.e. sums up all moves, regardless of up or down
  def path
    return @path unless @path.nil?
    prev = @resources[0][:p]
    @path = 0 
    1.upto(@resources.size-1) do |i| 
      @path += (@resources[i][:p] - prev).abs
      prev  =  @resources[i][:p]
    end
    @path
  end

  # @!visibility private
  def start; @start  ||= @openval[:t];  end
  # @!visibility private
  def end;   @end    ||= @closeval[:t]; end

  # Calculates the momentum, i.e. the speed of move in current instance
  def momentum
    @momentum ||= self.path.to_f / @duration
  end

  # Creates a new instance
  #
  # @option b [Array] expects an Array of measures 
  # @option ticksize [Float] The ticksize of underlying processor (defaults to 1.0)
  # @option strict   [Boolean] Whether this is a strict or a simple SpanBar (defaults to :true)
  def initialize(b, ticksize = 1.0, strict = true)
    a = b.dup.flatten.compact
    return if a.nil? or a.empty?

    # Quick helper to calculate the amount of decimals in the ticksize
    def decimals(a); num = 0; while (a != a.to_i); num += 1; a *= 10; end; num; end

    @ticksize   = ticksize
    @intraday   = false
    @format     = "%1.#{decimals(@ticksize)}f"
    @strict     = strict
    @openval    = a[0]
    @closeval   = a[-1]
    @highval    = a.reverse.max_by{|x| x[:p]}
    @lowval     = a.reverse.min_by{|x| x[:p]}
    @vol        = a.map{|x| x[:v]}.reduce(:+)
    @open       = @openval[:p]
    @high       = @highval[:p]
    @low        = @lowval[:p]
    @close      = @closeval[:p]
    @duration   = (@closeval[:t] - @openval[:t]) / 1000
    @resources  = a 
    @path       = self.path
    @momentum   = self.momentum.round(8)
    if @high == @close
      @type =  @low  == @open ? :up     : :bottom
    elsif @low == @close
      @type =  @high == @open ? :down   : :top
    else
      @type = :error
    end
    #puts self.inspect
    raise "Validation error: Type must be :up or :down for #{self.inspect}" if @strict and not [:up,:down].include?(@type)
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
    return [ @resources, tmp0 ]
  end

  # Introduction of @overdrive (means the amount, that the current bar EXCEEDs span) needed this late injection
  def inject_span(span)
    @span  = span
    @overdrive = ((@openval[:p] - @closeval[:p]).abs / @ticksize - @span).to_i
  end

  # For human output, set output
  def set_intraday
    @intraday = true
  end

  # Returns an inspection string
  def inspect
    pval = lambda {|val| "#{val[:t]}::#{@format % val[:p]}" }
    #if @strict
    #  return "<#SpanBar:0x00#{self.object_id.to_s(16)}, #{@strict ? "strict" : "simple"}, :#{@type
    #                       },\tpath: #{"%g" % self.path}, momentum: #{"%g" % self.momentum
    #                       }, open: #{pval.(@openval)}, close: #{pval.(@closeval)}>"
    #else
      return "<#SpanBar:0x00#{self.object_id.to_s(16)}, #{@strict ? "strict" : "simple"}, :#{@type
                           },\tpath: #{"%g" % self.path}, momentum: #{"%g" % self.momentum
                           }, open: #{pval.(@openval)}, high: #{pval.(@highval)
                           }, low: #{ pval.(@lowval)}, close: #{pval.(@closeval)}>"
    #end
  end

  # Return human readable output of instance
  def to_human
    if @intraday 
      time = lambda{|t| now = (t / 1000) % 86400; "#{"%02d" % (now/3600)}:#{"%02d" % ((now%3600)/60)}:#{"%02d" % (now%60)}" }
    else
      time = lambda{|t| Time.at(t/1000).strftime("%Y %b %d %H:%M:%S")}
    end
    pval = lambda {|v| "[#{time.(v[:t])}, #{@format % v[:p]}]" }
    if @strict 
      #return "STRICT, OPEN: #{pval.(@openval)}, CLOSE: #{pval.(@closeval)
      return "STRICT, #{pval.(@closeval)    
           },\tMOM: #{"%g" % (@momentum / @ticksize) },  \tDUR: #{@duration
           },\tEFF: #{((@close - @open) / @ticksize).to_i}, OVER: #{@overdrive}, \t:#{@type.to_s.upcase}"
    else
      return "SIMPLE, OPEN: #{pval.(@openval)
      }, #{ ([:up, :bottom].include? @type) ? "LOW: #{pval.(@lowval)}" : "HIGH #{pval.(@highval)}" 
      }, CLOSE: #{pval.(@closeval)}, MOM: #{"%g" % (@momentum / @ticksize) 
      },\tDUR: #{@duration},\tEFF: #{((@close - @open) / @ticksize).to_i}, :#{@type.to_s}"
    end
  end

  # Returns an array containing instance values as needed for CSV output
  #
  # Format is 
  #   closetime, 
  #   closeval, 
  #   volume, 
  #   type (UPCASE for strict), 
  #   high/low-time for top/bottom OR nil, 
  #   high/low-val  for top/bottom OR nil,
  #   duration in ms
  #   path
  #   momentum
  #   speed
  #   overdrive (if STRICT) or NIL
  def to_a
    if @strict
      return [ 
               @closeval[:t], @closeval[:p].round(8), @vol,  # so far it is the same as each other tick !!
               @type.to_s.upcase.to_sym,nil,nil, 
               @duration, @path.round(8), @momentum.round(8),
               ((@close - @open) / @ticksize).to_i, @overdrive
             ]  
    else 
      return [ 
              #@@openval[:t],  @openval[ :p].round(8),
              #@highval[:t],  @highval[ :p].round(8),
              #@lowval[:t],   @lowval[  :p].round(8),
               @closeval[:t], @closeval[:p].round(8), @vol, # so far it is the same as each other tick
               @type,
               [:top,:bottom].include?(@type.to_sym) ? 
                 ( @type.to_sym == :top ? @highval[:t] : @lowval[:t] ) : nil,
               [:top,:bottom].include?(@type.to_sym) ?
                 ( @type.to_sym == :top ? @highval[:p] : @lowval[:p] ) : nil,
               @duration, @path.round(8), @momentum.round(8),
             ((@close - @open) / @ticksize).to_i, nil
              ]
    end 
  end
end

