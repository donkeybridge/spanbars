require 'json'
require 'slop'
require 'colorize'
require 'csv'

class SpanCluster

  attr_reader :build, :collection, :max_size, :grace, :ticksize

  def initialize_from_file(opts = {})
    opts.require_keys(:file)
    @file     = opts[:file]
    @build = JSON.parse(File.read(@file))
    @collection = {}
    @build.last["end"] = @build.last["start"]
    puts ""
    for num in (0...@build.size)
      cluster = @build[num]
      for size in (cluster["start"]..cluster["end"])
        print "\rRebuilding collection #{size} / #{num} / #{@build.size}" if size % 10 == 0 
        @collection[size] = cluster["value"].to_struct
      end
    end
    @max_size = @build[-2]["end"]
    @min_size = @build[-1]["start"]
    @collection[@min_size][:peaks].last[:close][:time]
  end


  def initialize(opts = {})

    @ticksize = opts[:ticksize].nil? ? 1.0 : opts[:ticksize]
    @grace    = opts[:grace].nil? ? 0 : opts[:grace]
    min = opts[:min].nil? ? 5 : opts[:min]
    @min_size = min
    @max_size = min
    @maxpeaks = opts[:maxpeaks]
    @format   = opts[:format].nil? ? "%1.2f" : opts[:format]
    @collection = {@min_size => { n:      @min_size, 
                                  peaks:  [],
                                  bull:   0, 
                                  bear:   0 
                                } 
		  }
  end

  def add_size
    @max_size += 1
    dir = @collection[@max_size-1][:peaks][-1][:dir]
    @collection[@max_size] = { n:     @max_size, 
                               peaks: [@collection[@max_size-1][:peaks][-1].dup]
                               #bull:  @collection[@max_size-1][:bull],
                               #bear:  @collection[@max_size-1][:bear] 
                             }
  end

  def get_last_high(dev)
    if [:up,"up"].include? @collection[dev][:peaks][-2][:dir] 
      return @collection[dev][:peaks][-2][:close][:price]
    elsif [:down, "down"].include? @collection[dev][:peaks][-2][:dir]
      return @collection[dev][:peaks][-2][:open][:price]
    end
  end

  def get_last_low(dev)
    if [:up,"up"].include? @collection[dev][:peaks][-2][:dir]
      return @collection[dev][:peaks][-2][:open][:price]
    elsif [:down, "down"].include? @collection[dev][:peaks][-2][:dir]
      return @collection[dev][:peaks][-2][:close][:price]
    end
  end

   def add(tick)
    @collection.map do |k,v|
      # wenn open nicht gesetzt ist, erfolgt hier die Initialisierung.
      next if v[:peaks].size > 12 and not k ==  @min_size
      if v[:peaks].empty?
        v[:peaks] << { dir: nil, open: tick, close: tick } 
        # Inbesondere am Anfang kann der Algorithmus nicht wissen, ob es sich um eine
        # :up oder :down Bewegung handelt. In diesem Fall wird open: als min: und close:
        # als max: verwendet, bis die Spanne (k:) erreicht wurde. Erst dann wird dir: 
        # und auch open: / close: korrekt gesetzt
      elsif v[:peaks][-1][:dir].nil?
        v[:peaks][-1][:open]  = tick if v[:peaks][-1][:open][:price]  >= tick[:price]
        v[:peaks][-1][:close] = tick if v[:peaks][-1][:close][:price] <= tick[:price]
        if v[:peaks][-1][:close][:price] - v[:peaks][-1][:open][:price] > k * @ticksize
          #@collection[k].changed = true
          if v[:peaks][-1][:close][:time] < v[:peaks][-1][:open][:time]
            tmp = v[:peaks][-1][:close]
            v[:peaks][-1][:close] = v[:peaks][-1][:open]
            v[:peaks][-1][:open]  = tmp
            v[:peaks][-1][:dir]   = :down
            #v[:bear] = 1
            #v[:bull] = 0
          else
            v[:peaks][-1][:dir]   = :up
            #v[:bull] = 1 
            #v[:bear] = 0
          end
        end
      else
        # a new tick will only be saved in curr[:close], if it adds any information to the span.
        if [:up,"up"].include?(v[:peaks][-1][:dir])
          if tick[:price] >= v[:peaks][-1][:close][:price]
            v[:peaks][-1][:close] = tick
          end
        else
          if tick[:price] <= v[:peaks][-1][:close][:price]
            v[:peaks][-1][:close] = tick
          end
        end

        # and afterwards the length of bull/bear spans are updated
        # first the change of :up -> :down
        if [:up,"up"].include?(v[:peaks][-1][:dir]) and v[:peaks][-1][:close][:price] - (tick[:price] + @grace * @ticksize) > k * @ticksize
          v[:peaks] <<  { dir: :down, open: v[:peaks][-1][:close], close: tick } 
          if @maxpeaks > 0 
            v[:peaks].shift while v[:peaks].length > @maxpeaks unless k == @min_size# MAXPEAKS
          end
        elsif [:down,"down"].include?(v[:peaks][-1][:dir]) and (tick[:price] - @grace * @ticksize) - v[:peaks][-1][:close][:price] > k * @ticksize
          v[:peaks] << { dir: :up, open: v[:peaks][-1][:close], close: tick } 
          if @maxpeaks > 0 
            v[:peaks].shift while v[:peaks].length > @maxpeaks unless k == @min_size# MAXPEAKS
          end
        end
      end
    end
    self.add_size while @max_size <= Integer((@collection[@max_size][:peaks][-1][:open][:price] - @collection[@max_size][:peaks][-1][:close][:price]).abs / @ticksize)
    #puts self.print_collection
  end

  def reduce
    res = [ { start: @min_size, end: @min_size, value: @collection[@min_size] } ] #, bulls: [], bears: [] } ]
    @min_size.upto @max_size do |size|
      last = res.last[:value]
      curr = @collection[size]
      next if curr[:peaks][-4].nil? or curr[:peaks][-3].nil? or curr[:peaks][-2].nil? or
              last[:peaks][-2].nil? or last[:peaks][-3].nil? or last[:peaks][-4].nil? 
      if last[:peaks][-1][:open]  == curr[:peaks][-1][:open]  and
         last[:peaks][-2][:open]  == curr[:peaks][-2][:open]  and
         last[:peaks][-3][:open]  == curr[:peaks][-3][:open]  and
         last[:peaks][-4][:open]  == curr[:peaks][-4][:open]  
        res.last[:end]    = size
      else
        res <<  { start: size, end: size, value: curr } 
      end
    end
    res <<  { start: @min_size, end: @max_size, value: @collection[@min_size] } 
    res
  end

  def print_single(x)
    line = @collection[x]
    return "" if line.nil?
    to_tod = lambda{|t| now = (t / 1000) % 86400; "#{"%02d" % (now/3600)}:#{"%02d" % ((now%3600)/60)}:#{"%02d" % (now%60)}" }
    ppp = lambda do |l,n|
      l[:peaks][n].nil? ? "      " : "#{[:up,"up"].include?(l[:peaks][n][:dir]) ? "\\" : "/"
                                         }#{@format % l[:peaks][n][:open][:price]
                                         }#{[:up,"up"].include?(l[:peaks][n][:dir]) ? "/" : "\\"}"
    end
    "\t#{x}:\t#{ppp.(line,-4)}\t#{ppp.(line,-3)}\t#{ppp.(line,-2)}\t#{ppp.(line,-1)
     }\tE: #{@format % line[:peaks][-1][:close][:price]
     }\t#{line.bull}\t#{line.bear}"
   end

  def clusters( min = 2 )
    res = [] 
    self.reduce.each do |line|
      if (not line[:value][:peaks][-2].nil?) and line[:end] - line[:start] >= min
        res << line
      end
    end
    res
  end

  def print_clusters
    to_tod = lambda{|t| now = (t / 1000)-MIDNIGHT; "#{"%02d" % (now/3600)}:#{"%02d" % ((now%3600)/60)}:#{"%02d" % (now%60)}" }
    ppp = lambda do |l,n|
      l[:value][:peaks][n].nil? ? "       " : "#{[:up, "up"].include?(l[:value][:peaks][n][:dir]) ?
      (@format % l[:value][:peaks][n][:close][:price]).red : (@format % l[:value][:peaks][n][:close][:price]).green}"
    end
    ret = ""
    sep = "  "
    self.clusters.each do |line|
      ret += "\r  #{"% 5d" % line[:start]} - #{ "% 5d" % line[:end]
      }#{sep}#{ppp.(line,6)}#{sep}#{ppp.(line,5)}#{sep}#{ppp.(line,4)
      }#{sep}#{ppp.(line,3)}#{sep}#{ppp.(line,2)}#{sep}#{ppp.(line,1)}#{sep}#{ppp.(line,0)
      }#{sep}E: #{@format % line[:value][:peaks][0][:open][:price]
      }\r\n"
    end
    return ret
  end

  def print_reduced( arr = [] )
    to_tod = lambda{|t| now = (t / 1000)-MIDNIGHT; "#{"%02d" % (now/3600)}:#{"%02d" % ((now%3600)/60)}:#{"%02d" % (now%60)}" }
    ppp = lambda do |l,n|
      l[:value][:peaks][n].nil? ? "      " : "#{[:up, "up"].include?(l[:value][:peaks][n][:dir]) ? "\\" : "/"
      }#{@format % l[:value][:peaks][n][:open][:price]
      }#{[:up, "up"].include?(l[:value][:peaks][n][:dir]) ? "/" : "\\"}"
    end
    ret = ""
    self.reduce.each do |line|
      # print line if arr empty (default) or line(start.[:end]) contains any of arr_elements
      if (not line[:value][:peaks][-2].nil?) and (arr.empty? or arr.select{|elem| line[:start] <= elem and line[:end] >= elem}.length == 1 )
        ret += "              #{"%02d" % line[:start]} - #{ "%02d" % line[:end]
        }\t#{ppp.(line,-4)}\t#{ppp.(line,-3)}\t#{ppp.(line,-2)}\t#{ppp.(line,-1)
        }\tE: #{@format % line[:value][:peaks][-1][:close][:price]
        # }\t#{line.bulls}\t#{line.bears
        }\n\r"
      end
    end
    return ret
  end

  def print_collection
    res = "" 
    @collection.each do |k,v|
        res += "\t#{k}: \t#{@format % v[:peaks].first[:open][:price]}\t"
        v[:peaks].each {|peak| res += "#{@format % peak[:close][:price]}\t" }
        res += "\r\n"
    end
    res
  end

end
