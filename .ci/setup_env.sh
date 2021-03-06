#!/usr/bin/env bash

function dep_version() {
    grep "$1" .requirements | sed -e 's/.*=//' | tr -d '\n'
}

function set_env() {
    _YQ_VERSION='v4.5.0'
    _OPENRESTY="$(dep_version RESTY_VERSION)"
    _LUAROCKS="$(dep_version RESTY_LUAROCKS_VERSION)"
    _OPENSSL="$(dep_version RESTY_OPENSSL_VERSION)"
    _KONG_DEP_LUA_RESTY_OPENSSL_AUX_MODULE_VERSION="$(
        dep_version KONG_DEP_LUA_RESTY_OPENSSL_AUX_MODULE_VERSION
    )"

    DEPS_HASH=$({
            cat \
                .ci/setup_env.sh \
                .travis.yml \
                .requirements \
                Makefile;
            cat kong-*.rockspec | awk '/dependencies/,/}/';
        } | md5sum | awk '{ print $1 }'
    )

    INSTALL_CACHE="${INSTALL_CACHE:=\/install-cache}"
    INSTALL_ROOT="${INSTALL_CACHE}/${DEPS_HASH}"

    export \
        _YQ_VERSION \
        _OPENRESTY \
        _LUAROCKS \
        _OPENSSL \
        _KONG_DEP_LUA_RESTY_OPENSSL_AUX_MODULE_VERSION \
        DEPS_HASH \
        INSTALL_CACHE \
        INSTALL_ROOT

    env | sort
}

function main() {
    set_env

    mkdir -p "$HOME"/.local/bin
    export PATH=$PATH:$HOME/.local/bin

    if [[ ! -e "$HOME"/.local/bin/yq ]]; then
        wget "https://github.com/mikefarah/yq/releases/download/${_YQ_VERSION}/yq_linux_amd64" \
            -O "$HOME"/.local/bin/yq \
                && chmod +x "$HOME"/.local/bin/yq
    fi

    DOWNLOAD_ROOT="${DOWNLOAD_ROOT:=\/download-root}"
    BUILD_TOOLS_DOWNLOAD="${INSTALL_ROOT}/kong-build-tools"
    LUA_RESTY_OPENSSL_AUX_MODULE_DOWNLOAD="${INSTALL_ROOT}/lua-resty-openssl-aux-module"

    KONG_NGINX_MODULE_BRANCH="${KONG_NGINX_MODULE_BRANCH:-$(
        dep_version KONG_NGINX_MODULE_BRANCH
    )}"

    git clone "https://github.com/Kong/kong-build-tools.git" \
        "$BUILD_TOOLS_DOWNLOAD"

    KONG_BUILD_TOOLS_BRANCH='master'

    pushd "$BUILD_TOOLS_DOWNLOAD"
        git fetch --all
        git reset --hard "$KONG_BUILD_TOOLS_BRANCH" \
            || git reset --hard "origin/${KONG_BUILD_TOOLS_BRANCH}"
    popd

    export PATH="${BUILD_TOOLS_DOWNLOAD}/openresty-build-tools:${PATH}"

    [ -d "$LUA_RESTY_OPENSSL_AUX_MODULE_DOWNLOAD" ] \
        && rm -rf "$LUA_RESTY_OPENSSL_AUX_MODULE_DOWNLOAD"

    git clone -b \
        "$_KONG_DEP_LUA_RESTY_OPENSSL_AUX_MODULE_VERSION" \
        "https://github.com/fffonion/lua-resty-openssl-aux-module" \
        "$LUA_RESTY_OPENSSL_AUX_MODULE_DOWNLOAD"

    echo kong-ngx-build \
        --add-module "$LUA_RESTY_OPENSSL_AUX_MODULE_DOWNLOAD" \
        --debug \
        --kong-nginx-module "$KONG_NGINX_MODULE_BRANCH" \
        --luarocks "$_LUAROCKS" \
        --openresty "$_OPENRESTY" \
        --openssl "$_OPENSSL" \
        --prefix "$INSTALL_ROOT" \
        --work "$DOWNLOAD_ROOT" \
        -j "$JOBS"

    if [ -n "$DOWNLOAD_ONLY" ]; then
        kong-ngx-build \
            \
            --donwload-extract-only \
            \
            --add-module "$LUA_RESTY_OPENSSL_AUX_MODULE_DOWNLOAD" \
            --debug \
            --kong-nginx-module "$KONG_NGINX_MODULE_BRANCH" \
            --luarocks "$_LUAROCKS" \
            --openresty "$_OPENRESTY" \
            --openssl "$_OPENSSL" \
            --prefix "$INSTALL_ROOT" \
            --work "$DOWNLOAD_ROOT" \
            -j "$JOBS"

        exit "$?"
    fi

    kong-ngx-build \
        --add-module "$LUA_RESTY_OPENSSL_AUX_MODULE_DOWNLOAD" \
        --debug \
        --kong-nginx-module "$KONG_NGINX_MODULE_BRANCH" \
        --luarocks "$_LUAROCKS" \
        --openresty "$_OPENRESTY" \
        --openssl "$_OPENSSL" \
        --prefix "$INSTALL_ROOT" \
        --work "$DOWNLOAD_ROOT" \
        -j "$JOBS"
}

set -x
main "$@"
set +x
