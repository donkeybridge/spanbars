## 0.3.10 (November 21, 2020)


## 0.1.0 (November 21, 2020)
  - Add VERSION and CHANGELOG.md files, Bump version to v0.1.0.
  - lib/trendstate: moved .check_trend_state into separate file
  - lib/spancluster.rb: applied linting
  - bin/*: Applied linting
  - features: updated tests to match keyword arguments
  -   lib/spanbars.rb: applied linting to main includer
  -   lib/spanbarprocessor.rb: applied linting, added keyword arguments where appropriate
  -   lib/spanbars.rb: applied linting, added keyword arguments where to .initialize
  - Starting major rework in 2020: At first, clean up and update Gem stuff
  - modified #reduce function to support arbitrary parallels
  - added :waiting status between resistance and new support
  - added #change_span, remove @overdrive
  - Added new output for status, support and resistance on trendanalysis
  - added json-feature to spancluster
  - included spanclusters, did slight mod to spanbar (on path and momentum)
  - added symbol parameter, allowing for selective symbols in CSV with prepending symbols
  - minor fix of re-using constant names
  - minor change in yardoc
  - added script rectify.sh for postprocessing; changed default CSV output to match tick data format; added volume processing
  - fixed failing test due to missing @intraday
  - added gemspec, tested gem build and installation
  - added yardoc, add --ohlc support, #needs further testing
  - added reference tests
  - Initial commit

