#!/usr/bin/env ruby
#
THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__
require File.dirname(THIS_FILE) + '/../lib/spanbarprocessor.rb'
require File.dirname(THIS_FILE) + '/../lib/spanbar.rb'
