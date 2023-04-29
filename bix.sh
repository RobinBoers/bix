#!/bin/fish

# Project manager written in Fish.
# Functions a bit like `npm`, `mix` or `cargo` would, but is
# compatible with everything, since it wraps common tools
# in user-defined scripts (called handlers, 
# which are in the `.ci` directory).

function error -a message --description "error <message"
  set_color brred
  echo "ERROR: $message"
  set_color normal
  exit 1
end

function run -a handler --description "run <handler>"
  set --local options 'no-error'
  argparse $options -- $argv

  if test -e ./ci/$handler.sh
    ./ci/$handler.sh
  else
    if not set --query _flag_no_error
      error "Project doesn't provide $handler handler."
    end
  end
end

# Project management 

function setup
  run "setup"
end

function build
  run "build"
end

function check
  run "check"
end

# CI/CD

function deploy
  run "deploy"
end

# Git wrappers

function push --description "push <args>"
  git push $argv
  run "deploy" --no-error 
end

function merge -a from into --description "merge <from> <into> [merge args]"
  git checkout $into
  git merge --no-ff $from
  push origin $into  
end

# Entrypoint

function entrypoint
  if test -e .ci/server.sh
    .ci/server.sh
  else
    error "Project doesn't provide entrypoint (usually .ci/server.sh)"
  end
end

function help
  echo "Project manager written in Fish."
  echo 
  echo "Usage: bix [subcommand] [args]"
  echo 
  echo "SUBCOMMANDS:"
  echo
  echo "    -            Starts the project by it's entrypoint (usually .ci/server.sh)"
  echo "    setup        Fetches and installs project dependencies using the 'setup' handler."
  echo "    build        Builds the project using the 'build' handler."
  echo "    check        Runs the test suite using the 'check' handler."
  echo "    deploy       Deploys the current changes using the 'deploy' handler."
  echo "    push         Pushes the current commited changes to the remote and runs the 'deploy' handler."
  echo "    merge        Merges the current branch into another branch branch and then runs the above 'push' command."
  echo
end

if test "$argv[1]" = "--help"
  help
else
  if test (count $argv) -gt 0
    set subcommand $argv[1]
    switch $subcommand 
      case "setup"
        setup $argv[2..-1]
      case "build"
        build $argv[2..-1]
      case "check"
        check $argv[2..-1]
      case "deploy"
        deploy $argv[2..-1]
      case "push"
        push $argv[2..-1]
      case "merge"
        merge $argv[2..-1]
      case "run"
        run $argv[2..-1]
      case "*"
        echo "Unknown subcommand $subcommand"
        exit 1
    end
  else
    entrypoint
  end
end

