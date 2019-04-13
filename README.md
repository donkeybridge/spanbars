# SpanBar

Tiny tool to produce span bars from time series data, either directly from a time 
series or based on OHLC bars. 

## Description

spanbar reads record-by-record (or line-by-lin) and provides the according span bars. 
The current bar is closed and a new bar is created as soon as the given span is _exceeded_. 

Spanbars are comparable to classic OHLC bars or candle sticks, but have the major
advantage of a CLOSE value always equalling either HIGH or LOW. All data eliminated
can be considered as _noise_.

Therefore exists 4 types of bars:

* TOP:     CLOSE == HIGH
* UP:      CLOSE == HIGH and OPEN == LOW
* BOTTOM:  CLOSE == LOW 
* DOWN:    CLOSE == LOW  and OPEN == HIGH

To output _these_ bars, use the parameter --simple, but this won't work with --ohlc.
In a normal run, the program will 
process the resulting data again, aggregating all bars created in the first run to start
at an absolute HIGH (or LOW) and end at an absolute LOW (or HIGH resp.). Although these
spans of second type might be much larger than _span_, they can be considered to
contain no noise _smaller or equal than_ span.

Creating spanbars from given OHLCs is slightly inaccurate, as even one OHLC might
contain several spanbars, but that cannot be reflected by the given input data. Also, for
processing OHLC-input data, note that the algorithm is run 3 times: 
1. using (span / 2) on input HIGHS
2. using (span / 2) on input LOWS
1. using (span)     on [ resulting Highs, resulting Lows ].sorted\_by\_time

The application area I am writing this gem for is denoising data for trend recognition 
within monitored timeseries. 



## Basic usage
    processor = SpanBar.new(span: 5)
    File.read("./timeseries.csv").map{|x| { t: x[0], v: x[1] } }.sort_by{|x| x[:t]}.each do |data|
      processor.add(data)
    end
    processor.bars.each {|x| puts x}

## Basic usage via commandline

    $ cat timeseries.csv | spanbars 
    $ spanbars --input ./timeseries.csv --format csv    --span 5 --timestamp 1 --value 2 --tableout
    $ spanbars --input ./timeseries.json --format json  --span 2.1 --timestamp :time --ohlc --open :o --high :h --low :l --close :c
    $ spanbars --input ./timeseries.json --format json  --span 2.1 --timestamp :time --ohlc o,h,l,c
    $ spanbars --config ./my_config_for_yahoodata.yml --input ./timeseries.csv

