# Gradle Bash Tools

## Features:

- provides shorthand `gr` for running Gradle
- uses Gradle wrapper when available
- invokes Gradle correctly from any subdirectory of a project (e.g. when you are under `src/main/java`)
- supports auto-completion for projects and tasks across multi-project hierarchies
  - supports leading colon to select subprojects / tasks of root project

## How to install and use it:

- Put `bashCompletion.gradle` under `~/.gradle/init.d/` (Create this directory if it does not exist)
- Put `gradle-bash-tools.sh` somewhere and reference it in ~/.bash_profile with `source /path/to/gradle-bash-tools.sh`
- Completion targets need to be generated / updated by calling `gr bashCompletion` for the specific project
