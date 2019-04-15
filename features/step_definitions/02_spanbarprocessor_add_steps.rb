Then "it should raise ArgumentError when calling #add with less than 2 arguments" do
  expect{ @s.add }.to raise_error(ArgumentError)
  expect{ @s.add(1)}.to raise_error(ArgumentError)
end

Then "it should raise ArgumentError when calling #add and first argument is neither Integer nor Time" do
  expect{ @s.add("foo", "bar") }.to raise_error(ArgumentError)
  expect{ @s.add(124, 1.22) }.not_to raise_error
  expect{ @s.add(Time.now, 1.22) }.not_to raise_error
end

Then "it should raise ArgumentError when calling #add and second argument is neither Numeric nor Nil" do
  expect{ @s.add(123, "foo") }.to raise_error(ArgumentError)
  expect{ @s.add(123, 11234) }.not_to raise_error
  expect{ @s.add(123, nil  ) }.not_to raise_error
end

Then /^calling #add with params (\d+) and nil should return nil$/ do |timestamp|  
  expect(@s.add(timestamp, nil)).to be_nil
end

Then /^calling #add with params (\d+) and ([0-9.]+) should return false$/ do |timestamp, value|
  expect(@s.add(timestamp, value.to_f)).to be(false)
end

Then /^#add with params (\d+), ([0-9.]+) should return false$/ do |timestamp, value|
  expect(@s.add(timestamp, value.to_f)).to be(false)
end

Then /^#add with params (\d+), ([0-9.]+) should return an Array$/ do |timestamp, value|
  result = @s.add(timestamp, value.to_f)
  expect(result.class).to be(Array)
end

Given /^a feeder with data from "([^"]+)" is prepared$/ do |filename| 
  require 'csv'
  @data = CSV.read(filename).map{|x| [ x[0].to_i, x[1].to_f] }
end

Then "adding all data from file should not raise any error" do 
  expect { @data.each {|d| @s.add(d[0],d[1]) } } .not_to raise_error
end
