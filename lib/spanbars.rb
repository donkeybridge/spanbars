# frozen_string_literal: true

require 'slop'
require 'csv'
require 'colorize'
%i[spancluster spanbarprocessor spanbar trendstate].each { |f| require "#{__dir__}/#{f}" }
