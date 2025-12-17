#!/bin/bash

# -----------------------------
# ----------- Utils -----------
# -----------------------------
function to_lower {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

function is_enabled {
  if [[ "$(to_lower "$1")" =~ [y(es)?|t(rue)?|1|on?] ]]; then
    return 0
  else
    return 1
  fi
}

function is_have_sudo {
  if [[ -n "$(which sudo)" ]]; then
    return 0
  else
    return 1
  fi
}

function log_error {
  >&2 echo "[ERROR] $1"
}

function log_warn {
  if [[ -z "$DRBD_BUILDER_LOG_LEVEL" || "$(to_lower "$DRBD_BUILDER_LOG_LEVEL")" != 'error' ]]; then
    echo "[WARN] $1"
  fi
}

function log_info {
  if [[ -z "$DRBD_BUILDER_LOG_LEVEL" || "$(to_lower "$DRBD_BUILDER_LOG_LEVEL")" != 'error' && "$(to_lower "$DRBD_BUILDER_LOG_LEVEL")" != 'warn' ]]; then
    echo "[INFO] $1"
  fi
}

function log_debug {
  if [[ -n "$DRBD_BUILDER_LOG_LEVEL" || "$(to_lower "$DRBD_BUILDER_LOG_LEVEL")" == 'debug' ]]; then
    echo "[DEBUG] $1"
  fi
}

function replaceOrAdd {
  if [[ $(cat "$3" | grep -Ec "$1") -gt 0 ]]; then
    sed -i "s/$1/$2/" "$3"
  else
    echo "$2" >> "$3"
  fi
}

# -----------------------------
# ------- Preparations --------
# -----------------------------

function apt_preparation {
  log_debug "Started APT preparation"

  if [[ -n "$DRBD_BUILDER_APT_HTTP_PROXY" ]]; then
    replaceOrAdd "Acquire::http::Proxy.*" "Acquire::http::Proxy \"$DRBD_BUILDER_APT_HTTP_PROXY\";" /etc/apt/apt.conf.d/90proxy
  fi

  if [[ -n "$DRBD_BUILDER_APT_HTTPS_PROXY" ]]; then
    replaceOrAdd "Acquire::https::Proxy.*" "Acquire::https::Proxy \"$DRBD_BUILDER_APT_HTTPS_PROXY\";" /etc/apt/apt.conf.d/90proxy
  elif [[ -n "$DRBD_BUILDER_APT_HTTP_PROXY" ]]; then
    replaceOrAdd "Acquire::https::Proxy.*" "Acquire::https::Proxy \"DIRECT\";" /etc/apt/apt.conf.d/90proxy
  fi

  log_debug "Finished APT preparations"
}

function git_preparation {
  log_debug "Started Git preparations"

  apt-get update

  if ! apt-get install -y git; then
    log_error "Can not make a preparation for Git. Can not install 'git' package by 'apt-get' package manager"
    return 1
  fi

  git config --global user.email "drbd-builder@example.com"
  git config --global user.name  "Drbd Builder"

  return 0;
}

function prepare_for_build_coccinele {
  log_debug "Started preparations for building Coccinele"

  if ! git_preparation; then
    log_error "Can not make preparations for building Coccinele, because failed preparations for Git"
    return 1
  fi

  apt-get update
  if ! apt-get install -y \
          "linux-headers-$(uname -r)" \
          build-essential \
          git \
          automake \
          make \
          pkg-config \
          ocaml-native-compilers \
          ocaml-findlib \
          texlive-fonts-extra \
          hevea \
          libpython3-dev \
          libparmap-ocaml-dev;
  then
    log_error "Can not make preparations for building Coccinele. Can not install requirement packages"
        return 1
  fi

  log_debug "Finished preparations for building Coccinele"
}

function prepare_for_build_drbd_kernel_module {
  log_debug "Started preparations for building DRBD Kernel Module"

  if ! git_preparation; then
    log_error "Can not make preparations for building DRBD Kernel Module, because failed preparations for Git"
    return 1
  fi

  apt-get update
  if ! apt-get install -y \
          "linux-headers-$(uname -r)" \
          git \
          build-essential \
          debhelper \
          dkms;
  then
    log_error "Can not make preparations for building DRBD Kernel Module. Can not install requirement packages"
    return 1
  fi

  log_debug "Finished preparations for building DRBD Kernel Module"
}

function prepare_for_build_drbd_utils {
  log_debug "Started preparations for building DRBD Utils"


  if ! git_preparation; then
    log_error "Can not make preparations for building DRBD Utils, because failed preparations for Git"
    return 1
  fi
  apt-get update


  if ! apt-get install -y \
          "linux-headers-$(uname -r)" \
          build-essential \
          git \
          automake \
          make \
          pkg-config \
          flex \
          docbook-xsl \
          xsltproc \
          libkeyutils-dev;
  then
    log_error "Can not make preparations for building DRBD Utils. Can not install requirement packages"
    return 1
  fi

  log_debug "Finished preparations for building DRBD Utils"
}

# -----------------------------
# ---------- Build ------------
# -----------------------------

function build_coccinele {

  if ! is_enabled "$DRBD_BUILDER_COCCINELE_ENABLED_BUILD" && ! is_enabled "$DRBD_BUILDER_COCCIENELE_ENABLED_INSTALL"; then
    return 0
  fi

  if is_enabled "$DRBD_BUILDER_COCCIENELE_ENABLED_INSTALL"; then
    log_info "Coccinele will be installed by package manager instead of builded"
    apt-get update
    if ! apt-get install coccinele; then
      log_error "Can not install Coccinele by package manager"
      return 1
    fi
    log_info "Finished Coccinele installation"
    return 0;
  fi;

  log_debug "Started building Coccinele"

  if ! prepare_for_build_coccinele; then
    log_error "Can not build Coccinele. Can not make preparations for build"
    return 1
  fi

  local temp_folder;
  local last_tag;
  temp_folder=$(mktemp -d)

  cd "$temp_folder" || exit 1;

  if ! git clone --recursive https://github.com/coccinelle/coccinelle.git coccinele; then
    log_error "Can not build Coccinele. Can not clone git repository"
    return 1
  fi

  cd coccinele || exit 1;

  last_tag=$(git describe --tags --abbrev=0)

  if [[ -n "$DRBD_BUILDER_COCCINELE_VERSION" ]]; then
    last_tag="$DRBD_BUILDER_COCCINELE_VERSION"
  fi

  log_debug "Will use version '$last_tag' of Coccinele"

  if ! git checkout "$last_tag" || ! git submodule update || ! ./autogen || ! ./configure || ! make; then
    log_error "Can not build Coccinele. Can not check out to tag '$last_tag'"
    return 1
  fi

  if ! make install; then
    log_error "Can not build Coccinele. Failed on build"
    return 1
  fi

  cd ~/ || exit 1;
  rm -r "$temp_folder"

  log_debug "Finished building Coccinele"
  return 0
}


function build_drbd_kernel_module {

  if ! is_enabled "$DRBD_BUILDER_DRBD_KERNEL_MODULE_ENABLED_BUILD"; then
    return 0;
  fi

  log_debug "Started building DRBD Kernel Module"

  if ! build_coccinele || ! prepare_for_build_drbd_kernel_module; then
    log_error "Can not build DRBD Kernel Module. Can not install or compile coccinele"
    return 1
  fi

  local temp_folder;
  local last_tag;
  temp_folder=$(mktemp -d)

  cd "$temp_folder" || exit 1;

  if ! git clone --recursive https://github.com/LINBIT/drbd.git kernel_module; then
    log_error "Can not build DRBD Kernel Module. Can not clone git repository"
    return 1
  fi

  cd kernel_module || exit 1;

  last_tag=$(git describe --tags --abbrev=0)

  if [[ -n "$DRBD_BUILDER_DRBD_KERNEL_MODULE_VERSION" ]]; then
    last_tag="$DRBD_BUILDER_DRBD_KERNEL_MODULE_VERSION"
  fi

  log_debug "Will use version '$last_tag' of DRBD Kernel Module"

  local dst_folder;
  dst_folder=/result/kernel/module

  if ! git checkout "$last_tag" || ! git submodule update || ! mkdir -p "$dst_folder"; then
    log_error "Can not build DRBD Kernel Module. Can not check out to tag '$last_tag'"
    return 1
  fi

  if ! make clean all; then
    log_error "Can not build DRBD Kernel Module. Failed on build"
    return 1
  fi

  cp ./drbd/build-current/*.ko "$dst_folder"

  log_debug "Finished building DRBD Kernel Module"
}


function build_drbd_utils {
  if ! is_enabled "$DRBD_BUILDER_DRBD_UTILS_ENABLED_BUILD"; then
    return 0
  fi

  log_debug "Started building DRBD Utils"

  if ! prepare_for_build_drbd_utils; then
    log_error "Can not build DRBD Utils. Can not make preparations for build"
  fi

  local temp_folder;
  local last_tag;
  temp_folder=$(mktemp -d)

  cd "$temp_folder" || exit 1;

  if ! git clone --recursive https://github.com/LINBIT/drbd-utils.git utils; then
    log_error "Can not build DRBD Utils. Can not clone repository from GitHub"
    return 1
  fi

  cd utils || exit 1;

  last_tag=$(git describe --tags --abbrev=0)

  if [[ -n "$DRBD_BUILDER_DRBD_UTILS_VERSION" ]]; then
    last_tag="$DRBD_BUILDER_DRBD_UTILS_VERSION"
  fi

  log_debug "Will use version '$last_tag' of DRBD Utils"

  local dst_folder;
  dst_folder=/result/utils

  if ! git checkout "$last_tag" || ! git submodule update || ! mkdir -p "$dst_folder"; then
    log_error "Can not build DRBD Utils. Failed on build"
    return 1
  fi

  if ! autoconf || ! autoreconf || ! ./configure --prefix="$dst_folder" --without-udev --without-pacemaker --without-rgmanager --without-bashcompletion --without-manual || ! make; then
    log_error "Can not build DRBD Utils. Failed on build"
    return 1
  fi

  if ! make install; then
    log_error "Can not build DRBD Utils. Failed on build"
    return 1
  fi

  log_debug "Finished building DRBD Utils"
  return 0
}

function finalize_results {

  local user;
  local group;

  if [[ -n "$DRBD_BUILDER_RESULT_UID" ]]; then
    user="$DRBD_BUILDER_RESULT_UID"
  else
    user=1000
  fi

  if [[ -n "$DRBD_BUILDER_RESULT_GUID" ]]; then
    group="$DRBD_BUILDER_RESULT_GUID"
  else
    group=1000;
  fi

  if ! chmod -R 700 /result || ! chown -R "$user:$group" /result; then
    log_error "Can not set a owner for result folder"
    return 1
  fi

}

function main {

  apt_preparation;
  build_drbd_kernel_module;
  build_drbd_utils;

  finalize_results;

}

main;