# TetraWeb PHP CI Kit with Docker

This repository contains a set of utilities for running PHP tests via [Gitlab CI](https://about.gitlab.com/gitlab-ci/).

You need to install Gitlab and Gitlab CI separately. After you are done with that, these tools provide you with:

1. Ability to deploy a runner on separate VM or on already running server inside a Docker container. It is not recommended to install runner right on the production system. Better do it inside the Docker container

2. Set of Docker images for PHP 5.2 - 7.0 based on official Docker PHP images (Few limitations for PHP 5.2)

3. MySQL image with minimized requirements for RAM based on official Docker image

4. Links to redis and mongo images from official Docker

The goal of these tools is to automate as much as possible of routine work related to configuring the runner so you can concentrate on writing tests for your code.
Also these tools are trying to be resources savvy, since in most cases huge in-RAM caches are not needed for just running unit tests with some fixtures. So you can use very small VMs for running tests

## Contents of repository
 - [Gitlab-runner bootstrap script](https://github.com/TetraWeb/docker/tree/master/gitlab-runner-vm) for deploying gitlab-runner
 - [PHP Docker images](https://github.com/TetraWeb/docker/tree/master/php) - based on official Docker images, but include addtional modules and also obsolete versions of PHP 5.3 and 5.2
 - [MySQL Docker images](https://github.com/TetraWeb/docker/tree/master/mysql) - with minimized RAM requirements
 - [Example projects](https://github.com/TetraWeb/docker/tree/master/examples) - Example PHP projects

## Quick start

1. Install [Gitlab](https://about.gitlab.com/) and [Gitlab CI](https://about.gitlab.com/gitlab-ci/)
1. Get a server (VM or metal) with minimal Ubuntu-14.04 installed. It will be used for the runner
1. Login as root to a server and execute `curl -S https://raw.githubusercontent.com/TetraWeb/docker/master/gitlab-runner-vm/bootstrap.sh | bash` and answer the questions. This script will install docker, Gitlab runner, and configure runner for using these docker images.

Script also installs a cronjob for updating images daily, so you will always have the latest versions of PHP images.

Runner is limited for using only these images `tetraweb/php:*` and any service images `*/*`

If you want to use the server for also running other images (`ruby` or whatever), you should add another runners to `/etc/gitlab-runner/config.toml`, and DO NOT overwrite `allowed_images = ["tetraweb/php:*"]` for this runner, since it is a potential security breach.

## TODO
 - MySQL with smaller RAM demands
 - Mongo (Maybe smaller initial size to decrease the time of initialization)

## Requirements
 - Gitlab v`7.13.0` and later
 - Gitlab CI v`7.13.0` and later
 - Gitlab runner v`0.5.0` and later

## Similar projects
 - https://github.com/bobey/docker-gitlab-ci-runner (For old gitlab-ci-runner, misses PHP 5.3)
