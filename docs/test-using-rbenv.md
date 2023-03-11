# Test using rbenv

## Prerequisites

It's possible to use rbenv to test this gem on a development machine.
In order to do so you must have (rbenv)[https://github.com/rbenv/rbenv] installed.
Please refer to the official (installation guide)[https://github.com/rbenv/rbenv#installation].

It's important to install (ruby-build)[https://github.com/rbenv/ruby-build#readme] plugin.

## Install rbenv gemset plugin

In order to avoid pollution of system gem list we suggest the use of (gemset plugin)[https://github.com/jf/rbenv-gemset.git]

## Install rubies

After installation of rbenv install required ruby version:
```bash
rbenv install `cat .ruby-version`
```
It can take a while. After installation test it using:
```bash
rbenv version
```
And also with:
```bash
ruby -v
```
Both command should show a version number corresponding to the content of `.ruby-version` file.

## Install gems

Now it's possible to prepare gemset:
```bash
rbenv gemset create `cat .ruby-version` `cat .ruby-gemset`
```
Test it with:
```bash
rbenv gemset active
```
It should show the following text:
```
thecore_auth_commons global
```
Install gems in the new gemset using
```
bundle
```

## Test

Time to run your unit test:
```
bundle exec rails db:reset
bundle exec rails test
```
