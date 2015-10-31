#!/bin/bash

###############################################################################
#
# This is a bootstrap script for quickly setting up gitlab-runner
# on virtual (or even metal) machine with Ubuntu-14.04
#
# gitlab-runner is configured below to run the separate 
# docker container (runner) for each version of php
#
# TODO:
# System-related variables:
# TIMEZONE="America/New_York" for setting timezone
# USE_SWAP="1G" for creating swap
#
# Runner-related variables:
# CI_URL - URL of Gitlab-CI installation
# CI_TOKEN - Token for adding runner. Can be found ($CI_URL/admin/runners)
# CONCURRENT=1 Number of runners which can be executed simultaneously
# COMPOSER_GITHUB="TOKEN" - Github oauth token passed to each container
#
# Usage:
# 1. Install fresh ubuntu distribution
# 2.1 Non-interactive mode (doesn't require any input):
#     # export CI_URL=http://git.example.com/ci CI_TOKEN=12345abcdef[ OTHER_VAR=VALUE ...]; curl -SL https://raw.githubusercontent.com/TetraWeb/docker/master/gitlab-runner-vm/bootstrap.sh | bash
# OR
# 2.2 Interactive mode (script will ask for all variables to be typed while run)
#     # curl -SL https://raw.githubusercontent.com/TetraWeb/docker/master/gitlab-runner-vm/bootstrap.sh | bash
#
###############################################################################

set -e

create_swap() {
    dd if=/dev/zero of=/swapfile bs=1024 count=1024k
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile       none    swap    sw      0       0" >> /etc/fstab
    echo 10 | tee /proc/sys/vm/swappiness
    echo vm.swappiness = 10 | tee -a /etc/sysctl.conf
    chown root:root /swapfile
    chmod 0600 /swapfile
}

do_install() {
    while [ -z "$CI_URL" ]; do
        echo -n "Enter URL of your Gitlab CI installation [http://git.example.com/ci]: "
        read CI_URL < /dev/tty
    done

    while [ -z "$CI_TOKEN" ]; do
        echo -n "Enter API key (find it at $CI_URL/admin/runners): "
        read CI_TOKEN < /dev/tty
    done

    if [ -z "$TIMEZONE" ]; then
        echo -n "Timezone name [America/New_York]: "
        read TIMEZONE < /dev/tty
        if [ -z "$TIMEZONE" ]; then
            TIMEZONE="America/New_York"
        fi
        echo "$TIMEZONE" > /etc/timezone
        dpkg-reconfigure -f noninteractive tzdata
    fi

    if [ -z "$COMPOSER_GITHUB" ]; then
        echo -n "Composer Github token (optional): "
        read COMPOSER_GITHUB < /dev/tty
    fi

    if [ ! -z "$USE_SWAP" ]; then
        create_swap
    fi

    if [ -z "$CONCURRENT" ]; then
        echo -n "Number of concurrent processes ($(nproc)): "
        read CONCURRENT < /dev/tty
        if [ -z "$CONCURRENT" ]; then
            CONCURRENT=$(nproc)
        fi
    fi

    export DEBIAN_FRONTEND=noninteractive
    apt-get update && apt-get -y upgrade
    apt-get -y install mc htop ntpdate git curl wget openssh-server

    # Install docker
    wget -qO- https://get.docker.com/ | sh

    # Install multi-runner
    curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.deb.sh | sudo bash
    apt-get install gitlab-ci-multi-runner

    sudo gitlab-ci-multi-runner register -n -r "$CI_TOKEN" -u "$CI_URL" -t 'php,mysql' -e docker --docker-image tetraweb/php:latest --docker-mysql latest
    echo "    allowed_images = [\"tetraweb/php:*\"]" >> /etc/gitlab-runner/config.toml
    echo "    allowed_services = [\"*\", \"*/*\"]" >> /etc/gitlab-runner/config.toml

    sed -i -- "s/concurrent = 1/concurrent = $CONCURRENT/g" /etc/gitlab-runner/config.toml

    if [ ! -z "$COMPOSER_GITHUB" ]; then
        ENVVARS="$ENVVARS, \"COMPOSER_GITHUB=$COMPOSER_GITHUB\""
    fi
    if [ ! -z "$TIMEZONE" ]; then
        ENVVARS="$ENVVARS, \"TIMEZONE=$TIMEZONE\""
    fi
    sed -i -- "s/\"MYSQL_ALLOW_EMPTY_PASSWORD=1\"/\"MYSQL_ALLOW_EMPTY_PASSWORD=1\"$ENVVARS/g" /etc/gitlab-runner/config.toml
    sed -i -- "s/^    services =/    #services =/g" /etc/gitlab-runner/config.toml

    cronjob="#!/bin/bash\n"
    for phpver in 5.2 5.3 5.4 5.5 5.6 7.0
    do
        cronjob+="docker pull tetraweb/php:$phpver\n"
    done

    # Cleanup orphaned images
    cronjob+="docker rmi \$(docker images | grep none | awk '{print \$3}')\n"
    echo -e "$cronjob" > /etc/cron.weekly/docker-update-images
    chmod 755 /etc/cron.weekly/docker-update-images
}

do_install
