#!/bin/fish

# Project manager written in Fish.
# Functions a bit like `npm`, `mix` or `cargo` would, but is
# compatible with everything, since it wraps common tools
# in user-defined scripts (called handlers, 
# which are in the `.ci` directory).

# Configuration

set -q BIX_GIT_DEFAULT_BRANCH;     or set BIX_GIT_DEFAULT_BRANCH     "master"
set -q BIX_GIT_HOST_SSH;           or set BIX_GIT_HOST               "git@git.geheimesite.nl"

# Gitea/Forgejo specific, used for creating repos with the API
set -q BIX_GITEA_API_BASE;         or set BIX_GITEA_API_BASE         "https://git.geheimesite.nl/api/v1"

# Helpers

function error -a message --description "error <message>"
  set_color brred
  echo "🥴 $message"
  set_color normal
  exit 1
end

function success -a message --description "success <message>"
  echo
  set_color white
  echo $message
  set_color normal
  exit 0
end

function run -a handler --description "run <handler> [args]"
  set --local options 'no-error'
  argparse $options -- $argv

  if test -e ./ci/$handler.sh
    # Caution: the remaining args could include the --no-error flag, which is then also passed to the handler!
    ./ci/$handler.sh $argv[2..-1]
  else
    if not set --query _flag_no_error
      error "Project doesn't provide $handler handler :("
    end
  end
end

function json-get-by-key -a json_string key --description "json-get-by-key <string> <key>"
  jq -n "\$in.$key" --argjson in $json_string --raw-output
end

# Keyring managment helpers

function store-token -a token provider --description "store-secret <secret> <provider>"
  echo $token | secret-tool store \
    --label "$provider API access token" provider $provider setby bix
end

function get-token -a provider --description "store-secret <args>"
  secret-tool lookup provider $provider setby bix
end

# Project management 

function setup
  run "setup"
end

function build --description "build [args]"
  run "build" $argv

  success "🐳 Build succeeded!"
end

function check
  run "check"

  success "🙉 Test succeeded!"
end

function format
  run format

  success "🐺 Source files formatted :)"
end

# CI/CD

function deploy
  run "deploy"
end

# Gitea 

function auth -a provider "auth <provider>"
  switch $provider
    case "gitea"
      set username (read -P "Username: ")
      set password (read -P "Password: ")

      echo "$BIX_GITEA_API_BASE/users/$username/tokens"

      set response (curl "$BIX_GITEA_API_BASE/users/$username/tokens" \
        --fail-with-body --no-progress-meter \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d '{"name":"Bix"}' \
        -u $username:$password)

      if test $status != 0
        echo $response
        error "Gitea API returned an error, see trace above."
      end

      set token (json-get-by-key $response "sha1")
      store-token $token "gitea"
    case "*"
      error "Unsupported authentication provider"
  end
end

function create-remote -a name description "create-remote <repo> <description> [--org=string]"
  set --local options 'org='
  argparse $options -- $argv

  set --local token (get-token "gitea")

  if test -z $token
    error "Missing API token (please run 'bix auth gitea')"
  end

  if test -z $name
    error "Missing required parameter: name"
  end

  set body "{
        \"auto_init\": false,
        \"default_branch\": \"$BIX_GIT_DEFAULT_BRANCH\",
        \"description\": \"$description\",
        \"name\": \"$name\",
        \"private\": false,
        \"template\": false,
        \"trust_model\": \"default\"
      }"

  if set --query _flag_org  
    set response (curl "$BIX_GITEA_API_BASE/orgs/$org/repos" \
      --fail-with-body --no-progress-meter \
      -H "Authorization: token $token"
      -H "Content-Type: application/json" \
      -d $body)

    if test $status != 0
      echo $response
      error "Gitea API returned an error, see trace above."
    end  
  else
    set response (curl "$BIX_GITEA_API_BASE/user/repos" \
      --fail-with-body --no-progress-meter \
      -H "Authorization: token $token" \
      -H "Content-Type: application/json" \
      -d $body)

    if test $status != 0
      echo $response
      error "Gitea API returned an error, see trace above."
    end      
  end

  set url (json-get-by-key $response "html_url")
  success "🧸 Created new remote Git repository on $url :)"
end

# Git wrappers

function new -a name --description "new <name>" 
  mkdir $name && cd $name
  git init
  git branch -M $BIX_GIT_DEFAULT_BRANCH

  success "🐣 Set up a new Git repo for you :)"
end

function add-remote -a remote_repo --description "add-remote <repo>"
  set remote origin
  git remote add $remote "$BIX_GIT_HOST_SSH:$remote_repo"
  git push -U $remote $BIX_GIT_DEFAULT_BRANCH
  
  success "🦑 Set up new remote $remote for you :)"
end

function push --description "push <args>"
  git push $argv
  run "deploy" --no-error 

  success "🐢 Latest changes successfully deployed :D"
end

function merge -a from into --description "merge <from> <into> [merge args]"
  git checkout $into
  git merge --no-ff $from
  push origin $into  

  git branch -d $from

  success "🐙 Branch $from has been merged into $into. Yay!"
end

# Self-updating

function update
  echo "⚡️ Downloading latest release from source"

  set remote_release "https://git.geheimesite.nl/libre0b11/bix/raw/branch/master/install.sh"
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
  echo "    -              Starts the project by it's entrypoint (usually the 'server' handler)"
  echo
  echo "    setup          Fetches and installs project dependencies using the 'setup' handler."
  echo "    build          Builds the project using the 'build' handler."
  echo "    check          Runs the project test suite using the 'check' handler."
  echo "    format         Formats the project using the 'format' handler."
  echo "    deploy         Deploys the current commit using the 'deploy' handler."
  echo
  echo "    auth           Authenticates an external server (rn the only provider is Gitea)."
  echo "    create-remote  Creates a new remote repository using the Gitea API." 
  echo "    add-remote     Adds a remote URL to the current local repo."
  echo "    push           Pushes the current commited changes to the remote and runs the 'deploy' handler."
  echo "    merge          Merges the current branch into another branch branch and then runs the above 'push' command."
  echo
  echo "    help           Prints this help text."
  echo "    update         Pulls the latest bix version from source to replace the current one."
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
      case "auth"
        auth $argv[2..-1]
      case "create-remote"
        create-remote $argv[2..-1]
      case "add-remote"
        add-remote $argv[2..-1]
      case "push"
        push $argv[2..-1]
      case "merge"
        merge $argv[2..-1]
      case "run"
        run $argv[2..-1]
      case "help"
        help
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

