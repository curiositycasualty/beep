#!/usr/bin/env bash

# set -eu
set -x

function dep_version() {
    grep "$1" .requirements | sed -e 's/.*=//' | tr -d '\n'
}

function set_env() {
    export YQ_VERSION='v4.5.0'
    export OPENRESTY="$(dep_version RESTY_VERSION)"
    export LUAROCKS="$(dep_version RESTY_LUAROCKS_VERSION)"
    export OPENSSL="$(dep_version RESTY_OPENSSL_VERSION)"

    export DEPS_HASH=$({
            cat \
                .ci/setup_env.sh \
                .travis.yml \
                .requirements \
                Makefile;
            cat kong-*.rockspec | awk '/dependencies/,/}/';
        } | md5sum | awk '{ print $1 }'
    )

    export INSTALL_CACHE="${INSTALL_CACHE:=\/install-cache}"
    export INSTALL_ROOT="${INSTALL_CACHE}/${DEPS_HASH}"
}

function main() {
    set_env

    mkdir -p "$HOME"/.local/bin
    export PATH=$PATH:$HOME/.local/bin

    if [[ ! -e "$HOME"/.local/bin/yq ]]; then
        wget "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
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
        "$KONG_DEP_LUA_RESTY_OPENSSL_AUX_MODULE_VERSION" \
        "https://github.com/fffonion/lua-resty-openssl-aux-module" \
        "$LUA_RESTY_OPENSSL_AUX_MODULE_DOWNLOAD"

    echo kong-ngx-build \
        --work "$DOWNLOAD_ROOT" \
        --prefix "$INSTALL_ROOT" \
        --openresty "$OPENRESTY" \
        --kong-nginx-module "$KONG_NGINX_MODULE_BRANCH" \
        --luarocks "$LUAROCKS" \
        --openssl "$OPENSSL" \
        --debug \
        --add-module "$LUA_RESTY_OPENSSL_AUX_MODULE_DOWNLOAD" \
        -j "$JOBS"

    if [ -n "$DOWNLOAD_ONLY" ]; then
        kong-ngx-build \
            --download-only \
            --work "$DOWNLOAD_ROOT" \
            --prefix "$INSTALL_ROOT" \
            --openresty "$OPENRESTY" \
            --kong-nginx-module "$KONG_NGINX_MODULE_BRANCH" \
            --luarocks "$LUAROCKS" \
            --openssl "$OPENSSL" \
            --debug \
            --add-module "$LUA_RESTY_OPENSSL_AUX_MODULE_DOWNLOAD" \
            -j "$JOBS"

        exit "$?"
    fi

    kong-ngx-build \
        --work "$DOWNLOAD_ROOT" \
        --prefix "$INSTALL_ROOT" \
        --openresty "$OPENRESTY" \
        --kong-nginx-module "$KONG_NGINX_MODULE_BRANCH" \
        --luarocks "$LUAROCKS" \
        --openssl "$OPENSSL" \
        --debug \
        --add-module "$LUA_RESTY_OPENSSL_AUX_MODULE_DOWNLOAD" \
        -j "$JOBS"
}

main "$@"
