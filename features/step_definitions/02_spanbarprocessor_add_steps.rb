Then "it should raise ArgumentError when calling #add with less than 2 arguments" do
  expect{ @s.add }.to raise_error(ArgumentError)
  expect{ @s.add(timestamp: 1)}.to raise_error(ArgumentError)
end

Then "it should raise ArgumentError when calling #add and first argument is neither Integer nor Time" do
  expect{ @s.add(timestamp: "foo", value: "bar") }.to raise_error(ArgumentError)
  expect{ @s.add(timestamp: 124, value: 1.22) }.not_to raise_error
  expect{ @s.add(timestamp: Time.now, value: 1.22) }.not_to raise_error
end

Then "it should raise ArgumentError when calling #add and second argument is neither Numeric nor Nil" do
  expect{ @s.add(timestamp: 123, value: "foo") }.to raise_error(ArgumentError)
  expect{ @s.add(timestamp: 123, value: 11234) }.not_to raise_error
  expect{ @s.add(timestamp: 123, value: nil  ) }.not_to raise_error
end

Then /^calling #add with params (\d+) and nil should return nil$/ do |timestamp|  
  expect(@s.add(timestamp: timestamp, value: nil)).to be_nil
end

Then /^calling #add with params (\d+) and ([0-9.]+) should return false$/ do |timestamp, value|
  expect(@s.add(timestamp: timestamp, value: value.to_f)).to be(false)
end

Then /^#add with params (\d+), ([0-9.]+) should return false$/ do |timestamp, value|
  expect(@s.add(timestamp: timestamp, value: value.to_f)).to be(false)
end

Then /^#add with params (\d+), ([0-9.]+) should return an Array$/ do |timestamp, value|
  result = @s.add(timestamp: timestamp, value: value.to_f)
  expect(result.class).to be(Array)
end

Given /^a feeder with data from "([^"]+)" is prepared$/ do |filename| 
  require 'csv'
  @data = CSV.read(filename).map{|x| [ x[0].to_i, x[1].to_f] }
end

Then "adding all data from file should not raise any error" do 
  expect { @data.each {|d| @s.add(timestamp: d[0], value: d[1]) } } .not_to raise_error
end
