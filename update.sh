#!/usr/bin/env bash

sed -i -e "s/v[0-9]\+\.[0-9]\+\.[0-9]\+/$1/g" README.md
