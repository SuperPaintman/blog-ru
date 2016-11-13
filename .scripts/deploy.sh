#!/bin/bash

git_branch="gh-pages"
deploy_dir=".deploy_git"
public_dir="public"

rm "${public_dir}" -fr
rm "${deploy_dir}" -fr
mkdir "${deploy_dir}"

npm run build

(cd "${deploy_dir}" \
    && git clone -q "https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git" -b "${git_branch}" . > /dev/null 2>&1 \
    && rm * -fr \
)

mv ${public_dir}/* "${deploy_dir}/"

(cd "${deploy_dir}" \
    && git --no-pager diff \
    && git add -A . \
    && git commit -m "Site updated: $(date -u '+%Y-%m-%d %H:%M:%S')" \
    && git push -q origin "${git_branch}" > /dev/null 2>&1 \
)
