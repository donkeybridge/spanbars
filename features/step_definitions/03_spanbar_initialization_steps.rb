Then "a new simple SpanBar created without options should raise ArgumentError" do
  expect { SpanBar.new }.to raise_error(ArgumentError)
end

Then "a new simple SpanBar created by SpanBarProcessor should not raise" do
  @p = SpanBarProcessor.new(span: 5, simple: true)
  expect { for i in (1..5); @p.add(timestamp: i, value: i); end }.not_to raise_error
end

Given "a valid simple SpanBar is created by SpanBarProcessor" do 
  @p = SpanBarProcessor.new(span: 5, simple: true);  @s = true; i = 1; 
  while (not @s.is_a?(Array)) do @s = @p.add(timestamp: i, value: i); i+=1; end
  @s = @s[0]
end


  

