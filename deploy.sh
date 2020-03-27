#!/bin/bash
set -eux # see http://jvns.ca/blog/2017/03/26/bash-quirks/

SOURCE_BRANCH="master"
TARGET_BRANCH="gh-pages"

function buildResume {
  npm install -g resume-cli@1.2.7
  npm install -g jsonresume-theme-paper-v2
  cp ../resume.json ./resume.json
  resume export --theme paper-v2 --format pdf resume.pdf
  resume export index.html
}

# Pull requests and commits to other branches shouldn't try to deploy, just build to verify
if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    echo "Skipping deploy;"
    exit 0
fi

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`

# Clone the existing gh-pages for this repo into out/
# Create a new empty branch if gh-pages doesn't exist yet (should only happen on first deply)
git clone $REPO out
cd out
git checkout $TARGET_BRANCH || git checkout --orphan $TARGET_BRANCH
cd ..

# Clean out existing contents
rm -rf out/**/* || exit 0

# Now let's go have some fun with the cloned repo
cd out

# Run our compile script
buildResume

git config user.name "Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"

# Commit the "changes", i.e. the new version.
# The delta will show diffs between new and old versions.
echo "/deploy_key" > ./.gitignore #only ignore deploy_key
git add --all
git commit -m "Deploy to GitHub Pages: ${SHA}"

chmod 600 ../deploy_key
eval `ssh-agent -s`
ssh-add ../deploy_key

# Now that we're all set up, we can push.
git push $SSH_REPO $TARGET_BRANCH
