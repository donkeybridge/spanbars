class SpanBar

  attr_reader :type, :resources, :open, :high, :low, :close

  def valid? 
    not (@type.nil? or @type == :error)
  end

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

  def start; @start  ||= @openval[:t];  end
  def end;   @end    ||= @closeval[:t]; end


  def momentum
    @momentum ||= self.path.to_f / @duration
  end

  def initialize(b, ticksize = 1, strict = true)
    a = b.dup.flatten.compact
    return if a.nil? or a.empty?
    def decimals(a); num = 0; while (a != a.to_i); num += 1; a *= 10; end; num; end
    @ticksize   = ticksize
    @format     = "%1.#{decimals(@ticksize)}f"
    @strict     = strict
    @openval    = a[0]
    @closeval   = a[-1]
    @highval    = a.reverse.max_by{|x| x[:p]}
    @lowval     = a.reverse.min_by{|x| x[:p]}
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
    raise "Validation error: Type must be :up or :down for #{self.inspect}" if @strict and not [:up,:down].include?(@type)
  end

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

  def set_intraday
    @intraday = true
  end

  def inspect
    pval = lambda {|val| "#{val[:t]}::#{@format % val[:p]}" }
    if @strict
      return "<#SpanBar:0x00#{self.object_id.to_s(16)}, #{@strict ? "strict" : "simple"}, :#{@type
                           },\tpath: #{"%g" % self.path}, momentum: #{"%g" % self.momentum
                           }, open: #{pval.(@openval)}, close: #{pval.(@closeval)}>"
    else
      return "<#SpanBar:0x00#{self.object_id.to_s(16)}, #{@strict ? "strict" : "simple"}, :#{@type
                           },\tpath: #{"%g" % self.path}, momentum: #{"%g" % self.momentum
                           }, open: #{pval.(@openval)}, high: #{pval.(@highval)
                           }, low: #{ pval.(@lowval)}, close: #{pval.(@closeval)}>"
    end
  end

  def to_human
    if @intraday 
      time = lambda{|t| now = (t / 1000) % 86400; "#{"%02d" % (now/3600)}:#{"%02d" % ((now%3600)/60)}:#{"%02d" % (now%60)}" }
    else
      time = lambda{|t| Time.at(t/1000).strftime("%Y %b %d %H:%M:%S")}
    end
    pval = lambda {|v| "[#{time.(v[:t])}, #{@format % v[:p]}]" }
    if @strict 
      return "STRICT, OPEN: #{pval.(@openval)}, CLOSE: #{pval.(@closeval)
           }, MOM: #{"%g" % (@momentum / @ticksize) },\tDUR: #{@duration
           },\tEFF: #{((@close - @open) / @ticksize).to_i}, :#{@type.to_s.upcase}"
    else
      return "SIMPLE, OPEN: #{pval.(@openval)
      }, #{ ([:up, :bottom].include? @type) ? "LOW: #{pval.(@lowval)}" : "HIGH #{pval.(@highval)}" 
      }, CLOSE: #{pval.(@closeval)}, MOM: #{"%g" % (@momentum / @ticksize) 
      },\tDUR: #{@duration},\tEFF: #{((@close - @open) / @ticksize).to_i}, :#{@type.to_s.upcase}"
    end
  end

  def to_a
    if @strict
      return [ "strict", 
               @openval[:t],  @openval[ :p].round(8),
               @closeval[:t], @closeval[:p].round(8),
               @duration, @path.round(8), @momentum.round(8),
             ((@close - @open) / @ticksize).to_i, 
             @type ]
    else 
      return [ "simple", 
               @openval[:t],  @openval[ :p].round(8),
               @highval[:t],  @highval[ :p].round(8),
               @lowval[:t],   @lowval[  :p].round(8),
               @closeval[:t], @closeval[:p].round(8),
               @duration, @path.round(8), @momentum.round(8),
             ((@close - @open) / @ticksize).to_i,
             @type ]
    end 
  end
end

