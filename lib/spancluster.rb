# frozen_string_literal: true

# TODO: Create documentation
# missing documentation
class SpanCluster
  attr_reader :build, :collection, :max_size, :grace, :ticksize

  def initialize_from_file(file:)
    @file = file
    @build = JSON.parse(File.read(@file))
    @collection = {}
    @build.last['end'] = @build.last['start']
    puts ''
    (0...@build.size).each do |num|
      cluster = @build[num]
      (cluster['start']..cluster['end']).each do |size|
        print "\rRebuilding collection #{size} / #{num} / #{@build.size}" if (size % 10).zero?
        @collection[size] = cluster['value'].to_struct
      end
    end
    @max_size = @build[-2]['end']
    @min_size = @build[-1]['start']
    @collection[@min_size][:peaks].last[:close][:time]
  end

  def initialize(opts = {})
    @symbol = opts[:symbol]
    @ticksize = if EzConfig
                  if opts[:ticksize].nil?
                    @symbol.nil? ? 1.0 : EzConfig.read_ez_symbolconfig(@symbol)['ticksize']
                  else
                    opts[:ticksize]
                  end
                else
                  opts[:ticksize].nil? ? 1.0 : opts[:ticksize]
                end

    @grace = opts[:grace].nil? ? 0 : opts[:grace]
    min = opts[:minspan].nil? ? 5 : opts[:minspan]
    @min_size = min
    @max_size = min
    @maxpeaks = opts[:maxpeaks]
    @format   = opts[:format].nil? ? '%1.2f' : opts[:format]
    @collection = { @min_size => { n: @min_size,
                                   peaks: [],
                                   bull: 0,
                                   bear: 0 } }
  end

  def add_size
    @max_size += 1
    @collection[@max_size] = { n: @max_size,
                               peaks: [@collection[@max_size - 1][:peaks][-1].dup] }
    # bull:  @collection[@max_size-1][:bull],
    # bear:  @collection[@max_size-1][:bear]
  end

  def get_last_high(dev)
    if [:up, 'up'].include? @collection[dev][:peaks][-2][:dir]
      @collection[dev][:peaks][-2][:close][:price]
    elsif [:down, 'down'].include? @collection[dev][:peaks][-2][:dir]
      @collection[dev][:peaks][-2][:open][:price]
    end
  end

  def get_last_low(dev)
    if [:up, 'up'].include? @collection[dev][:peaks][-2][:dir]
      @collection[dev][:peaks][-2][:open][:price]
    elsif [:down, 'down'].include? @collection[dev][:peaks][-2][:dir]
      @collection[dev][:peaks][-2][:close][:price]
    end
  end

  def add(tick)
    # rubocop:disable Metrics/BlockNesting
    @collection.map do |k, v|
      # when open is unset, it is initialized here
      # next if v[:peaks].size > 12 and not k ==  @min_size
      if v[:peaks].empty?
        v[:peaks] << { dir: nil, open: tick, close: tick }
        # especially in the beginning, the algorithm cannot estimate, whether this is
        # an :up or :down move. in this case, :open is :min and :close is :max, until
        # the span :k is filled. At this point eventually dir: can be set, likewise
        # :open and :close
      elsif v[:peaks][-1][:dir].nil?
        v[:peaks][-1][:open]  = tick if v[:peaks][-1][:open][:price]  >= tick[:price]
        v[:peaks][-1][:close] = tick if v[:peaks][-1][:close][:price] <= tick[:price]
        if v[:peaks][-1][:close][:price] - v[:peaks][-1][:open][:price] > k * @ticksize
          # @collection[k].changed = true
          if v[:peaks][-1][:close][:time] < v[:peaks][-1][:open][:time]
            tmp = v[:peaks][-1][:close]
            v[:peaks][-1][:close] = v[:peaks][-1][:open]
            v[:peaks][-1][:open]  = tmp
            v[:peaks][-1][:dir]   = :down
            # v[:bear] = 1
            # v[:bull] = 0
          else
            v[:peaks][-1][:dir]   = :up
            # v[:bull] = 1
            # v[:bear] = 0
          end
        end
      else
        # a new tick will only be saved in curr[:close], if it adds any information to the span.
        if [:up, 'up'].include?(v[:peaks][-1][:dir])
          v[:peaks][-1][:close] = tick if tick[:price] >= v[:peaks][-1][:close][:price]
        else
          # rubocop:disable Style/IfInsideElse
          v[:peaks][-1][:close] = tick if tick[:price] <= v[:peaks][-1][:close][:price]
          # rubocop:enable Style/IfInsideElse
        end

        # and afterwards the length of bull/bear spans are updated
        # first the change of :up -> :down
        if  [:up, 'up'].include?(v[:peaks][-1][:dir]) &&
            (v[:peaks][-1][:close][:price] - (tick[:price] + @grace * @ticksize) > k * @ticksize)
          v[:peaks] << { dir: :down, open: v[:peaks][-1][:close], close: tick }
          if @maxpeaks.positive? && (k != @min_size)
            v[:peaks].shift while v[:peaks].length > @maxpeaks # unless k == @min_size # MAXPEAKS
          end
        elsif [:down, 'down'].include?(v[:peaks][-1][:dir]) &&
              ((tick[:price] - @grace * @ticksize) - v[:peaks][-1][:close][:price] > k * @ticksize)
          v[:peaks] << { dir: :up, open: v[:peaks][-1][:close], close: tick }
          if @maxpeaks.positive? && (k != @min_size)
            v[:peaks].shift while v[:peaks].length > @maxpeaks # unless k == @min_size # MAXPEAKS
          end
        end
      end
    end
    add_size while @max_size <= Integer((@collection[@max_size][:peaks][-1][:open][:price] -
                                          @collection[@max_size][:peaks][-1][:close][:price]
                                        ).abs / @ticksize)
    # rubocop:enable Metrics/BlockNesting
    # puts self.print_collection
  end

  def reduce(parallel = 8)
    check_parallel = lambda do |l, c|
      parallel.times do |i|
        return false if c[:peaks][-1 - i].nil? || (c[:peaks][-1 - i][:open] != l[:peaks][-1 - i][:open])
      end
      return true
    end

    res = [{ start: @min_size, end: @min_size, value: @collection[@min_size] }] # , bulls: [], bears: [] } ]
    @min_size.upto @max_size do |size|
      last = res.last[:value]
      curr = @collection[size]

      # check if curr has as many last peaks as last. if not, decrease parallel until parallel is 1
      parallel = last[:peaks].size if last[:peaks].size < parallel
      # next if curr[:peaks][-4].nil? or curr[:peaks][-3].nil? or curr[:peaks][-2].nil? or
      #        last[:peaks][-4].nil? or last[:peaks][-3].nil? or last[:peaks][-2].nil?

      # now check if the last <parallel> parts of curr and last are equal---
      if check_parallel.call(last, curr)

        # if last[:peaks][-1][:open]  == curr[:peaks][-1][:open]  and
        #   last[:peaks][-2][:open]  == curr[:peaks][-2][:open]  and
        #   last[:peaks][-3][:open]  == curr[:peaks][-3][:open]  and
        #   last[:peaks][-4][:open]  == curr[:peaks][-4][:open]
        res.last[:end] = size
      else
        res << { start: size, end: size, value: curr }
      end
    end
    res << { start: @min_size, end: @max_size, value: @collection[@min_size] }
    res
  end

  def print_single(cluster)
    line = @collection[cluster][:peaks].reverse
    return '' if line.nil?

    to_tod = ->(t) { Time.at(t / 1000).strftime('%H:%M:%S') }
    ppp    = ->(d, t, p) { "#{d}\t#{to_tod.call(t)}\t#{p}\t\t(#{t})" }
    # puts ppp.call(line.first[:dir] == :up ? :down : :up, line.first[:open][:time], line.first[:open][:price])
    line.each do |peak|
      puts ppp.call(peak[:dir], peak[:close][:time], peak[:close][:price])
    end
  end

  def clusters(min = 0)
    res = []
    reduce.each do |line|
      res << line if (not line[:value][:peaks][-2].nil?) && (line[:end] - line[:start] >= min)
    end
    res
  end

  def json_clusters(single = 0)
    if single.zero?
      clusters.to_json
    else
      first = @collection[single][:peaks].first
      first = [first[:open][:time], first[:open][:price], 0, first[:dir] == :up ? :down : :up]
      rest  = @collection[single][:peaks].map { |x| [x[:close][:time], x[:close][:price], 0, x[:dir]] }
      rest.prepend first
      rest.reverse.to_json
    end
  end

  def print_clusters
    # to_tod = ->(t) {
    #    now = (t / 1000) - MIDNIGHT
    #   "#{format('%02d', (now / 3600))
    #   }:#{format('%02d', ((now % 3600) / 60))}:#{format('%02d', (now % 60))}"
    # }
    ppp = lambda do |l, n|
      if l[:value][:peaks][n].nil?
        '       '
      else
        (if [:up, 'up'].include?(l[:value][:peaks][n][:dir])
           (@format % l[:value][:peaks][n][:close][:price]).red
         else
           (@format % l[:value][:peaks][n][:close][:price]).green
         end).to_s
      end
    end
    ret = ''
    sep = '  '
    clusters.each do |line|
      # rubocop:disable Style/FormatString
      # rubocop:disable Layout/ClosingParenthesisIndentation
      ret += "\r  #{'% 5d' % line[:start]
      } - #{ '% 5d' % line[:end]
      }#{sep}#{ppp.call(line, 6)
      }#{sep}#{ppp.call(line, 5)
      }#{sep}#{ppp.call(line, 4)
      }#{sep}#{ppp.call(line, 3)
      }#{sep}#{ppp.call(line, 2)
      }#{sep}#{ppp.call(line, 1)
      }#{sep}#{ppp.call(line, 0)
      }#{sep}E: #{@format % line[:value][:peaks][0][:open][:price]
      }\r\n"
      # rubocop:enable Style/FormatString
      # rubocop:enable Layout/ClosingParenthesisIndentation
    end
    ret
  end

  def print_reduced(arr = [])
    # to_tod = ->(t) { now = (t / 1000) - MIDNIGHT
    #   "#{format('%02d', (now / 3600))}:#{format('%02d', ((now % 3600) / 60))}:#{format('%02d', (now % 60))}"
    # }
    ppp = lambda do |l, n|
      if l[:value][:peaks][n].nil?
        '      '
      else
        "#{[:up, 'up'].include?(l[:value][:peaks][n][:dir]) ? '\\' : '/'
         }#{@format % l[:value][:peaks][n][:open][:price]
          }#{[:up, 'up'].include?(l[:value][:peaks][n][:dir]) ? '/' : '\\'}"
      end
    end
    ret = ''
    reduce.each do |line|
      # print line if arr empty (default) or line(start.[:end]) contains any of arr_elements
      next unless (not line[:value][:peaks][-2].nil?) &&
                  (arr.empty? || (arr.select { |elem| (line[:start] <= elem) && (line[:end] >= elem) }.length == 1))

      # rubocop:disable Style/FormatString
      # rubocop:disable Layout/ClosingParenthesisIndentation
      ret += "              #{'%02d' % line[:start]
        } - #{ '%02d' % line[:end]
        }\t#{ppp.call(line, -4)
        }\t#{ppp.call(line, -3)
        }\t#{ppp.call(line, -2)
        }\t#{ppp.call(line, -1)
        }\tE: #{@format % line[:value][:peaks][-1][:close][:price]
          # }\t#{line.bulls}\t#{line.bears
        }\n\r"
      # rubocop:enable Style/FormatString
      # rubocop:enable Layout/ClosingParenthesisIndentation
    end
    ret
  end

  def print_collection
    res = ''
    @collection.each do |k, v|
      res += "\t#{k}: \t#{@format % v[:peaks].first[:open][:price]}\t"
      v[:peaks].each { |peak| res += "#{@format % peak[:close][:price]}\t" }
      res += "\r\n"
    end
    res
  end
end
