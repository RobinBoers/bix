# Bix

Project manager written in Fish.

## WTF?

Bix is a simple tool that wraps package managers. Why? Well I work with a lot of codebases, in a lot of languages and grew tired of accidentally typing `mix phx.server` in a node project, or `cargo run` in an elixir project and vice versa.

For example, this is what I would normally run to initialize a new project:

```fish
mkdir lok && cd lok
git init
# Edits files etc.

git add .
git commit -m "Initial commit"
# Opens Gitea to create repo

git remote add origin git.geheimesite.nl:RobinBoers/lok
git branch -M master
git push -u origin master
```

Using bix this can be simplified to:

```fish
bix new lok
# Edit files

git add .
git commit -m "Initial commit"
bix create-repo lok "Dynamically typed programming language written in Rust"
bix link-repo RobinBoers/lok
```

## Installation

```shell
curl -sSfL https://git.geheimesite.nl/libre0b11/bix/raw/branch/master/install.sh | fish
```

## Usage

Bix uses user-defined scripts in the `.ci` directory (also called handlers) to run it's commands. Forexample `bix build` runs the `build.sh` script and `bix deploy` runs the `deploy.sh` script.

It also provides some wrappers around common `git` commands to speed up my workflow. These are:

- `bix new <name>` to initialize a local git repo.
- `bix link-repo` to link a remote repo to your local repo.
- `bix push` to push the current commits to the remote and then run the deploy handler[^1] in async.
- `bix merge <from> <into>` merges the current (or `from`) branch into `into` (usually master).

And to make working with git even easier, it also provides Gitea integration to create repos with ease:

- `bix auth gitea` to login with your Gitea account (the API access token gets saved to your login keyring).
- `bix create-repo` to create a new repo in your Gitea account (with optional --org parameter to use an org account).

And last of all, just running `bix` runs the "entrypoint", which is currently hardcoded to `.ci/server.sh`. It should start your app.

## Configuration

Bix can be configured using environment variables:

```fish
set BIX_DEFAULT_BRANCH          "master"
set BIX_GIT_HOST                "git@gitea.your.host"
# Gitea/Forgejo specific, used for creating repos with the API
set BIX_GITEA_API_BASE          "https://gitea.your.host/api/v1"
```

[^1]: I run my CI/CD locally because I got tired of setting up GitHub actions.
