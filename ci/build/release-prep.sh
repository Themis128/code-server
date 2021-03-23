#!/usr/bin/env bash
# Description: This is a script to make the release process easier
# Run it with `yarn release:prep` and it will do the following:
# 1. Check that you have a $GITHUB_TOKEN set and hub installed
# 2. Update the version of code-server (package.json, docs, etc.)
# 3. Update the code coverage badge in the README
# 4. Open a draft PR using the release_template.md and view in browser

set -euo pipefail

main() {
  cd "$(dirname "$0")/../.."

  # Check that $GITHUB_TOKEN is set
  if [[ -z "${GITHUB_TOKEN}" ]]; then
    echo "We couldn't find an environment variable under GITHUB_TOKEN."
    echo "This is needed for our scripts that use hub."
    echo -e "See docs regarding GITHUB_TOKEN here under 'GitHub OAuth authentication': https://hub.github.com/hub.1.html"
    exit
  fi

  # Check that hub is installed
  if ! command -v hub &>/dev/null; then
    echo "hub could not be found."
    echo "We use this with the release-github-draft.sh and release-github-assets.sh scripts."
    echo -e "See docs here: https://github.com/github/hub#installation"
    exit
  fi

  # Check that they have jq installed
  if ! command -v jq &>/dev/null; then
    echo "jq could not be found."
    echo "We use this to parse the package.json and grab the current version of code-server."
    echo -e "See docs here: https://stedolan.github.io/jq/download/"
    exit
  fi

  # Check that they have rg installed
  if ! command -v rg &>/dev/null; then
    echo "rg could not be found."
    echo "We use this when updating files across the codebase."
    echo -e "See docs here: https://github.com/BurntSushi/ripgrep#installation"
    exit
  fi

  # Check that they have sd installed
  if ! command -v sd &>/dev/null; then
    echo "sd could not be found."
    echo "We use this when updating files across the codebase."
    echo -e "See docs here: https://github.com/chmln/sd#installation"
    exit
  fi

  # Check that they have node installed
  if ! command -v node &>/dev/null; then
    echo "node could not be found."
    echo "That's surprising..."
    echo "We use it in this script for getting the package.json version"
    echo -e "See docs here: https://nodejs.org/en/download/"
    exit
  fi

  # credit to jakwuh for this solution
  # https://gist.github.com/DarrenN/8c6a5b969481725a4413#gistcomment-1971123
  CODE_SERVER_CURRENT_VERSION=$(node -pe "require('./package.json').version")
  # Ask which version we should update to
  # In the future, we'll automate this and determine the latest version automatically
  echo "Current version: ${CODE_SERVER_CURRENT_VERSION}"
  # The $'\n' adds a line break. See: https://stackoverflow.com/a/39581815/3015595
  read -r -p "What version of code-server do you want to update to?"$'\n' CODE_SERVER_VERSION_TO_UPDATE

  echo -e "Great! We'll prep a PR for updating to $CODE_SERVER_VERSION_TO_UPDATE\n"
  # I can't tell you why but
  # when searching with rg, the version needs to in this format: '3\.7\.5'
  # that's why we have the parameter expansion with the regex
  rg -g '!yarn.lock' -g '!*.svg' --files-with-matches "${CODE_SERVER_CURRENT_VERSION//\./\\.}" | xargs sd "$CODE_SERVER_CURRENT_VERSION" "$CODE_SERVER_VERSION_TO_UPDATE"

  # Ensure the tests are passing and code coverage is up-to-date
  echo -e "Running unit tests and updating code coverage...\n"
  yarn test:unit
  # Updates the Lines badge in the README
  yarn badges
  # Updates the svg to be green for the badge
  sd "red.svg" "green.svg" ../../README.md

  git add . && git commit -am "chore(release): bump version to $CODE_SERVER_VERSION_TO_UPDATE"

  CURRENT_BRANCH=$(git branch --show-current)
  # Note: we need to set upstream as well or the gh pr create step will fail
  # See: https://github.com/cli/cli/issues/575
  git push -u origin "$CURRENT_BRANCH"

  RELEASE_TEMPLATE_STRING=$(cat ../../.github/PULL_REQUEST_TEMPLATE/release_template.md)

  echo -e "Opening a draft PR on GitHub\n"
  # To read about these flags, visit the docs: https://cli.github.com/manual/gh_pr_create
  gh pr create --base main --title "release: $CODE_SERVER_VERSION_TO_UPDATE" --body "$RELEASE_TEMPLATE_STRING" --reviewer @cdr/code-server-reviewers --repo cdr/code-server --draft

  # Open PR in browser
  gh pr view --web
}

main "$@"
