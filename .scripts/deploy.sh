#!/bin/bash

git_branch="gh-pages"
deploy_dir=".deploy_git"
public_dir="public"

rm "${public_dir}" -frd
rm "${deploy_dir}" -frd
mkdir "${deploy_dir}"

npm run build

(cd "${deploy_dir}" \
    && git clone "git@github.com:${TRAVIS_REPO_SLUG}.git" -b "${git_branch}" . \
    && rm * -frd \
)

mv ${public_dir}/* "${deploy_dir}/"

(cd "${deploy_dir}" \
    && git --no-pager diff \
    && git add . \
    && git commit -m "Site updated: $(date '+%Y-%m-%d %H:%M:%S')" \
    && git push origin "${git_branch}" \
)