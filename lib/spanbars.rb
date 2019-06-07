#!/usr/bin/env ruby
##

require 'slop'
require 'csv'
require 'colorize'
require 'ezconfig' 

THIS_MAIN_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__
require File.dirname(THIS_MAIN_FILE) + '/spancluster.rb'
require File.dirname(THIS_MAIN_FILE) + '/spanbarprocessor.rb'
require File.dirname(THIS_MAIN_FILE) + '/spanbar.rb'
#require File.dirname(THIS_MAIN_FILE) + '/trendstate.rb'




