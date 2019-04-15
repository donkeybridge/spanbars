Given /^bin\/spanbars is run on the commandline and neither parameters nor STDIN is given$/ do
end

Then /^bin\/spanbars should display help$/ do
  expect{ system("bin/spanbars --help") }.to output(/usage/).to_stdout_from_any_process
end

Given /^bin\/spanbars is run with following parameters it should ouput$/ do
end

Then /^cat ([^ ]*) \| spanbars --both --ticksize ([^ ]*) --span ([^ ]*) should produce ([^ ]*)$/ do |input, ticksize, span, output|
  inputfile = "features/support/#{input}.csv"
  outputfile = "features/support/#{output}.csv"
  result = `cat #{inputfile} | bin/spanbars --both --span #{span} --ticksize #{ticksize}`
  reference = File.read(outputfile)
  expect(result).to eq(reference)
end

Then /^'cat ([^ ]*) \| bin\/spanbars --both --span ([^ ]*) --ticksize ([^' ]*)' should not produce ([^"$ ]*)$/ do |input, span, ticksize, output|
  inputfile = "features/support/#{input}.csv"
  outputfile = "features/support/#{output}.csv"
  result = `cat #{inputfile} | bin/spanbars --both --span #{span} --ticksize #{ticksize}`
  reference = File.read(outputfile)
  expect(result).not_to eq(reference)
end

