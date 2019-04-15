Feature: Using spanbars on commandline
  Scenario: When using bin/spanbars on the commandline without parameters
    Given bin/spanbars is run on the commandline and neither parameters nor STDIN is given
    #Then bin/spanbars should display help

  Scenario Outline: Checking known input to produce known output
    Given bin/spanbars is run with following parameters it should ouput
    Then cat <input> | spanbars --both --ticksize <ticksize> --span <span> should produce <output>
    Examples:
      | input | ticksize  | span | output                 |
      | ref1  | 0.25      | 25   | ref1_out_0.25_25       |
      | ref2  |    1      | 25   | ref2_out_1_25          |
      | ref3  | 0.0000005 | 10   | ref3_out_0.0000005_10  |

  Scenario: Checking whether false reference is recognized
    Given bin/spanbars is run with following parameters it should ouput
    Then 'cat ref3 | bin/spanbars --both --span 10 --ticksize 0.0000005' should not produce ref2_out_1_25

      
