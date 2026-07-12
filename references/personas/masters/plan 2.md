plan this

## Overview 
its a claud plugin that mainly it does a research, planning, implementation, review, debugging, QA, testing, stress test. it will never assume, not hallucination, everything unclear will be ask or recommend the solution

## Reference
- https://github.com/multica-ai/andrej-karpathy-skills/tree/main
- everything-claude-code
- superpowers
- gstack
i want the same level or even better than that. discuss with what you find, what can make it better

## Requirement 
- make a git so this plugin can installed using the claude plugins
- have a dynamic model-routing configuration that for each agent what model and effort it will use
- make a custom agent for the subagent executor, the agent have their own : 
    - implementor-agent
    - code-review-agent
    - debugging-agent
    - testing-agent (QA, stress-test, unit test, performance test)
- make a skills : 
    - planning
    - research
    - implementor
    - debugging
    - testing
        - qa
        - stress test
        - performance test
        - unit test
    - session-handoff (creating summary)
- everything using this skill will create a local memory project, every key point updated it will update it 
- recommend me the plugin name and the skills naming

## Plugin Naming & Skills name 
recommend me the naming both for plugin and all the skills

## Installation 
make it ready to install by claude plugin

## Designing
- discuss first for each agent capabilities, spec, dependecies, requirement
- give brief what you take from each reference. what you change to make it better 

## Constraint
- don't assume
- don't guess
- provide definite fact
