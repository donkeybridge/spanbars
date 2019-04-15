# SpanBars

SpanBars is a tiny tool to produce span bars from time series data, either directly from a time 
series or based on OHLC bars. 

## Description

SpanBars reads record-by-record (or line-by-line) and provides the according span bars. 
The current bar is closed and a new bar is created as soon as the given span is _exceeded_. 

Spanbars are comparable to classic OHLC bars or candle sticks, but have the major
advantage of a CLOSE value always equalling either HIGH or LOW. All data eliminated
can be considered as _noise_.

Therefore exists 4 types of bars:

* TOP:     CLOSE == HIGH
* UP:      CLOSE == HIGH and OPEN == LOW
* BOTTOM:  CLOSE == LOW 
* DOWN:    CLOSE == LOW  and OPEN == HIGH

When generating spanbars based on a plain time series, these bars can be sent to output using 
the parameter _--simple_. Without it will  
process the resulting data again, aggregating all bars created in the first run to start
at an absolute HIGH (or LOW) and end at an absolute LOW (or HIGH resp.). Although these
spans of second type might be much larger than _--span_, they can be considered to
contain no noise _smaller or equal than_ span.

Creating spanbars from given OHLCs is slightly inaccurate, as even one OHLC might
contain several spanbars, but that cannot be reflected by the given input data. Also, for
processing OHLC-input data, note that the entire algorithm (simple spanbars first, strict spanbars seconds) is run 3 times: 
1. using (span / 2) on input HIGHS
2. using (span / 2) on input LOWS
1. using (span)     on [ resulting Highs, resulting Lows ].sorted\_by\_time

The application area this gem is written for is denoising data for trend recognition 
within monitored timeseries. 

## Basic usage
    processor = SpanBarProcessor.new(span: 5)
    File.read("./timeseries.csv").map{|x| { t: x[0], v: x[1] } }.sort_by{|x| x[:t]}.each do |data|
      processor.add(data)
    end
    processor.bars.each {|x| puts x}

## Basic usage via commandline

Using _spanbars_ on the commandline expects data on STDIN as CSV with timestamps on column 1 and 
values on column 2. With _--ohlc_ enabled, it expects CSV with "timestamps,open,high,low,close".

Provided output will be CSV as well, for

* _simple_: "timestamp\_open,open, timestamp\_high,high, timestamp\_low, low, timestamp\_close, close, direction, path, momentum, direction"
* _strict_: "timestamp\_open,open, timestamp\_close, close, duration, path, momentum, effective\_span, direction"

I currently plan to implement 2 more parameters: _--human_ to create a human-readable table 
(particularly concerning the time format), and _--intraday_ (ommiting the date part when using _--human_).

    $ cat timeseries.csv | spanbars 
    $ spanbars --input ./timeseries.csv  --span 5

## List of parameters

* --span     (defaults to 10)
* --ticksize (default  to 1.0)
* --ohlc     (defaults to false)
* --simple   (defaults to false)
* --human    (planned, defaults to false)
* --intraday (planned, defaults to false)
