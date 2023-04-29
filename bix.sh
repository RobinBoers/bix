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

function run -a handler --description "run <handler> [args]"
  set --local options 'no-error'
  argparse $options -- $argv

  if test -e ./ci/$handler.sh
    # Caution: the remaining args could include the --no-error flag, which is then also passed to the handler!
    ./ci/$handler.sh $argv[2..-1]
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

function build --description "build [args]"
  run "build" $argv
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

# Self-updating

function update
  echo "Downloading latest release from source"

  set $remote_release "https://git.geheimesite.nl/libre0b11/bix/raw/branch/master/install.sh"
  curl -sSfL $remote_release | fish
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
  echo "    update       Pulls the latest bix version from source to replace the current one."
  echo
end

if test "$argv[1]" = "--help"
  help
else
  if test (count $argv) -gt 0
    set subcommand $argv[1]
    switch $subcommand 
      case "setup"
        setup
      case "build"
        build $argv[2..-1]
      case "check"
        check
      case "deploy"
        deploy
      case "push"
        push $argv[2..-1]
      case "merge"
        merge $argv[2..-1]
      case "run"
        run $argv[2..-1]
      case "update"
        update 
      case "*"
        echo "Unknown subcommand $subcommand"
        exit 1
    end
  else
    entrypoint
  end
end

