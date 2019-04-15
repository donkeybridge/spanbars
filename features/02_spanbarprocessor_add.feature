Feature: Using #add

  Scenario: Falsey input
     Given a simple SpanBarProcessor is initialized with "3", "3"
     Then it should raise ArgumentError when calling #add with less than 2 arguments
     Then it should raise ArgumentError when calling #add and first argument is neither Integer nor Time
     Then it should raise ArgumentError when calling #add and second argument is neither Numeric nor Nil

  Scenario: Correct return values
     Given a simple SpanBarProcessor is initialized with "3", "3"
     Then calling #add with params 123 and nil should return nil
     Then calling #add with params 123 and 2.5 should return false

  Scenario: eesting a linear raising series
     Given a simple SpanBarProcessor is initialized with "3", "1"
     Then  #add with params 1, 1 should return false
     Then  #add with params 2, 2 should return false
     Then  #add with params 3, 3 should return false
     Then  #add with params 4, 4 should return false
     Then  #add with params 5, 5 should return an Array

  Scenario Outline: Running with reference data
    Given a SpanBarProcessor is initialized with "<deviation>", "<ticksize>"
    And a feeder with data from "<file>" is prepared
    Then adding all data from file should not raise any error

    Examples: 
      | file                         | deviation | ticksize   | 
      | ./features/support/ref1.csv  | 5         | 0.25       |
      | ./features/support/ref1.csv  | 8         | 0.1        |
      | ./features/support/ref1.csv  | 12        | 0.66       |
      | ./features/support/ref2.csv  | 5         | 1          |
      | ./features/support/ref2.csv  | 8         | 2          |
      | ./features/support/ref2.csv  | 12        | 5.5        |
      | ./features/support/ref3.csv  | 5         | 0.0000005  |
      | ./features/support/ref3.csv  | 8         | 0.000001   |
      | ./features/support/ref3.csv  | 12        | 0.00000025 |

    

