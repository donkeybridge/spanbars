require './lib/spanbar.rb'
require './lib/spanbarprocessor.rb'

Given "a new SpanBarProcessor created with span that is not Integer or <= 1 should raise ArgumentError" do
  expect{ SpanBarProcessor.new(span: "t") }.to raise_error(ArgumentError)
  expect{ SpanBarProcessor.new(span: 1.6) }.to raise_error(ArgumentError)
  expect{ SpanBarProcessor.new(span: 1)   }.to raise_error(ArgumentError)
end
  
Given "a new SpanBarProcessor created with a valid span but non-Numeric ticksize or <= 0 should raise ArgumentError" do 
  expect{ SpanBarProcessor.new(span: 2, ticksize: "foo")}.to raise_error(ArgumentError)
  expect{ SpanBarProcessor.new(span: 2, ticksize: 0)}.to raise_error(ArgumentError)
  expect{ SpanBarProcessor.new(span: 2, ticksize: -1.2)}.to raise_error(ArgumentError)
end

Given /^a SpanBarProcessor is initialized with "([^"]*)", "([^"]*)"$/ do |span, ticksize|
  @s = SpanBarProcessor.new(span: span.to_i, ticksize: ticksize.to_f)
end

Given /^a simple SpanBarProcessor is initialized with "([^"]*)", "([^"]*)"$/ do |span, ticksize|
    @s = SpanBarProcessor.new(span: span.to_i, ticksize: ticksize.to_f, simple: true)
end


Then /^it should respond to "([^"]*)"$/ do |method| 
  expect(@s).to respond_to(method.to_sym)
end

Then /^([^\s]*) should be set to ([^\s]*)$/ do |var,value|
  expect(@s.instance_variable_defined?(var.to_sym)).to be_truthy
  res = eval "@s.instance_variable_get(var.to_sym) == #{value}"
  expect(res).to be_truthy
end
