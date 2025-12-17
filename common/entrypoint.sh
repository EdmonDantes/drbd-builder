#!/bin/bash

if [[ -n "$(which sudo)" ]]; then
  sudo ./install.sh
else
  ./install.sh
fi