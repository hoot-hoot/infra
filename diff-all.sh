#!/bin/bash

git diff
git diff origin/master master

cd ..

cd common-js
git diff
git diff origin/master master
cd ..

cd common-server-js
git diff
git diff origin/master master
cd ..

cd identity
git diff
git diff origin/master master
cd ..

cd identity-sdk-js
git diff
git diff origin/master master
cd ..

cd content
git diff
git diff origin/master master
cd ..

cd content-sdk-js
git diff
git diff origin/master master
cd ..

cd adminfe
git diff
git diff origin/master master
cd ..

cd sitefe
git diff
git diff origin/master master
cd ..

cd infra
