#!/bin/fish

# Project manager written in Fish.
# Functions a bit like `npm`, `mix` or `cargo` would, but is
# compatible with everything, since it wraps common tools
# in user-defined scripts (called handlers, 
# which are in the `.ci` directory).

# Configuration

set -q BIX_GIT_DEFAULT_BRANCH;     or set BIX_GIT_DEFAULT_BRANCH     "master"
set -q BIX_GIT_HOST_SSH;           or set BIX_GIT_HOST_SSH           "git.geheimesite.nl"

# Gitea/Forgejo specific, used for creating repos with the API
set -q BIX_GITEA_API_BASE;         or set BIX_GITEA_API_BASE         "https://git.geheimesite.nl/api/v1"

# Helpers

function error -a message --description "error <message>"
  echo
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

function has-handler -a handler --description "has-handler <handler>"
  test -e ./.ci/$handler.sh
end

function run -a handler --description "run <handler> [args]"
  set --local options 'no-error'
  argparse $options -- $argv

  if has-handler $handler
    # Caution: the remaining args could include the --no-error flag, which is then also passed to the handler!
    ./.ci/$handler.sh $argv[2..-1]
  else
    if not set --query _flag_no_error
      error "Project doesn't provide $handler handler :("
    end
  end
end

function json-get-by-key -a json_string key --description "json-get-by-key <string> <key>"
  jq -n "\$in.$key" --argjson in $json_string --raw-output
end

# Autodetect

function detect-manager 
  if test -e ./mix.exs
    echo "mix"
  else if test -e ./yarn.lock
    echo "yarn"
  else if test -e ./package.json
    echo "npm"
  else if test -e ./cargo.toml
    echo "cargo"
  end
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
  set handler "setup"

  if has-handler $handler
    run $handler
  else
    switch (detect-manager)
      case "mix"
        mix deps.get && mix setup
      case "npm"
        npm install
      case "yarn"
        yarn install
      case "cargo"
        return
      case "*"
        error "Autodetect failed and project doesn't provide $handler handler :("
    end
  end
end

function build --description "build [args]"
  set handler "build"

  if has-handler $handler
    run $handler $argv
  else
    switch (detect-manager)
      case "mix"
        mix compile $argv
      case "npm"
        npm run build $argv
      case "yarn"
        yarn run build $argv
      case "cargo"
        cargo build $argv
      case "*"
        error "Autodetect failed and project doesn't provide $handler handler :("
    end
  end

  success "🐳 Build succeeded!"
end

function check
  set handler "check"

  if has-handler $handler
    run $handler
  else
    switch (detect-manager)
      case "mix"
        mix check
      case "npm"
        npm run check
      case "yarn"
        yarn run check
      case "cargo"
        cargo test
      case "*"
        error "Autodetect failed and project doesn't provide $handler handler :("
    end
  end

  success "🙉 Test succeeded!"
end

function format
  set handler "format"

  if has-handler $handler
    run $handler
  else
    switch (detect-manager)
      case "mix"
        mix format
      case "npm"
        npx prettier --write .
      case "yarn"
        yarn prettier --write .
      case "cargo"
        cargo fmt
      case "*"
        error "Autodetect failed and project doesn't provide $handler handler :("
    end
  end

  success "🐺 Source files formatted :)"
end

# CI/CD

function deploy
  run "deploy"

  success "🐢 Latest changes successfully deployed :D"
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
    case ""
      error "Please provide authentication provider"
    case "*"
      error "Unsupported authentication provider"
  end
end

function create-repo -a name description "create-repo <repo> <description> [--org=string]"
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
  mkdir $name
  cd $name
  git init
  git branch -M $BIX_GIT_DEFAULT_BRANCH

  success "🐣 Set up a new Git repo for you :)"
end

function add-remote -a remote_repo --description "add-remote <repo>"
  set remote origin
  # Delete remote if it already exists
  delete-remote $remote > /dev/null 2> /dev/null

  git remote add $remote "$BIX_GIT_HOST_SSH:/$remote_repo"
  
  if test $status != 0
    delete-remote $remote
    error "Uh oh, that didn't work! Are you sure the remote exists? (It should be 'user/repo', not just 'repo')"
  end   
    
  git push -u $remote $BIX_GIT_DEFAULT_BRANCH

  if test $status != 0
    delete-remote $remote
    error "Uh oh, couldn't push! Are you sure the remote exists and the path is correct? (It should be 'user/repo', not just 'repo')"
  end
  
  success "🦑 Set up new remote $remote for you :)"
end

function delete-remote -a remote --description "delete-remote <remote>"
  git remote remove $remote
end

function push --description "push <args>"
  git push $argv
  run "deploy" --no-error 

  if test -e .ci/deploy.sh
    success "🐢 Latest changes successfully deployed :D"
  else
    success "🧶 Latest changes pushed to remote repo :)"
  end
end

function merge -a from into --description "merge <from> <into> [merge args]"
  git checkout $into
  git merge --no-ff $from
  push origin $into  

  git branch -d $from

  success "🐙 Branch $from has been merged into $into. Yay!"
end

function undo-commit 
  git reset HEAD^
end

function remove -a file --description "remove <file>" 
  git reset file
end

# Self-updating

function update
  echo "⚡️ Downloading latest release from source"

  set remote_release "https://git.geheimesite.nl/libre0b11/bix/raw/branch/master/install.sh"
  curl -sSfL $remote_release | fish
end

# Entrypoint

function entrypoint --description "entrypoint <args>"
  set handler "server"

  if has-handler $handler
    run $handler $argv
  else
    switch (detect-manager)
      case "mix"
        mix phx.server $argv
      case "npm"
        npm start  $argv
      case "yarn"
        yarn serve $argv
      case "cargo"
        cargo run $argv
      case "*"
        error "Project doesn't provide entrypoint (usually .ci/server.sh), and autodetect failed."
    end
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
  echo "    new            Initialize an empty git repository"
  echo "    auth           Authenticates an external server (rn the only provider is Gitea)."
  echo "    create-repo    Creates a new remote repository using the Gitea API." 
  echo "    link-repo      Adds a remote URL to the current local repo."
  echo "    push           Pushes the current commited changes to the remote and runs the 'deploy' handler."
  echo "    merge          Merges the current branch into another branch branch and then runs the above 'push' command."
  echo "    undo-commit    Un-commits the last commit."
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
      case "format"
        format
      case "deploy"
        deploy
      case "new"
        new $argv[2..-1]
      case "auth"
        auth $argv[2..-1]
      case "create-repo"
        create-repo $argv[2..-1]
      case "link-repo"
        add-remote $argv[2..-1]
      case "push"
        push $argv[2..-1]
      case "merge"
        merge $argv[2..-1]
      case "undo-commit"
        undo-commit
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

