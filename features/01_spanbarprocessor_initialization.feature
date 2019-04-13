Feature: Initializiation of SpanBarProcessor
  Scenario: Testing provided arguments during initialization
    * a new SpanBarProcessor created with span that is not Integer or <= 1 should raise ArgumentError
    * a new SpanBarProcessor created with a valid span but non-Numeric ticksize or <= 0 should raise ArgumentError

  Scenario Outline: Testing well initialized instance_variables
    Given a SpanBarProcessor is initialized with "3", "3"
    Then <instance_var> should be set to <value>
    Examples: 
      | instance_var | value | 
      | @ticks       |  []   |
      | @limit       |  9    |
      | @simpleMax   |  0    |
      | @simpleMin   |  Float::INFINITY | 
      | @simpleBar   |  []   | 
      | @simpleBars  |  []   | 

  Scenario Outline: Testing methods and attr
    Given a SpanBarProcessor is initialized with "4", "3"
    Then it should respond to "<method>"
    Examples:
      | method |
      | add    |
      | simpleBars | 
      | create_strict_from |

