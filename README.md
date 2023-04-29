# Bix

Project manager written in Fish.

## WTF?

Bix is a simple tool that wraps package managers. Why? Well I work with a lot of codebases, in a lot of languages and grew tired of accidentally typing `mix phx.server` in a node project, or `cargo run` in an elixir project and vice versa.

## Installation

```shell
curl -sSfL https://git.geheimesite.nl/libre0b11/bix/raw/branch/master/install.sh | fish
```

## Usage

Bix uses user-defined scripts in the `.ci` directory (also called handlers) to run it's commands. Forexample `bix build` runs the `build.sh` script and `bix deploy` runs the `deploy.sh` script.

It also provides some wrappers around common `git` commands to speed up my workflow. These are:

- `bix new <name>` to initialize a local git repo.
- `bix create-remote <user> <repo> <description>` to create a remote repo.
- `bix add-remote` to link a remote repo to your local repo.
- `bix push` to push the current commits to the remote and then run the deploy handler[^1] in async.
- `bix merge <from> <into>` merges the current (or `from`) branch into `into` (usually master).

And last of all, just running `bix` runs the "entrypoint", which is currently hardcoded to `.ci/server.sh`. It should start your app.

## Configuration

Bix can be configured using environment variables:

```fish
set BIX_DEFAULT_BRANCH          "master"
set BIX_GIT_HOST                "git@git.geheimesite.nl"
# Gitea/Forgejo specific, used for creating repos with the API
set BIX_GITEA_API              "https://git.geheimesite.nl/api/v1"
set BIX_GITEA_API_TOKEN        "empty"
```

[^1]: I run my CI/CD locally because I got tired of setting up GitHub actions.
