Feature: Initializiation of SpanBar
  Scenario: Testing provided arguments during initialization
    * a new simple SpanBar created without options should raise ArgumentError
    * a new simple SpanBar created by SpanBarProcessor should not raise 

  Scenario Outline: Testing well initialized instance_variables
    Given a valid simple SpanBar is created by SpanBarProcessor
    Then <instance_var> should be set to <value>
    Examples: 
      | instance_var | value | 
      | @strict      | false | 
      | @type        | :up   |
      | @open        | 1     |
      | @momentum    | Float::INFINITY   |
    
 

  Scenario Outline: Testing methods and attr of SpanBar
     Given a valid simple SpanBar is created by SpanBarProcessor
     Then it should respond to "<method>"
     Examples:
       | method   |
       | inspect  | 
       | to_human |
       | to_a     |
       | valid?   |
       | path     |
       | momentum |
       | split_for|

