#!/bin/bash
set -eux

function once {
    [ -f "/state/$1" ] && return
    "$@"
    touch "/state/$1"
}
export -f once

function as {
    local user="$1"
    shift
    su -s /bin/bash -c "set -eux ; $*" "$user"
}

function install_deps {
    apt-get update
    apt-get upgrade -y

    apt-get install -y software-properties-common
    apt-add-repository -y ppa:brightbox/ruby-ng

    apt-key add ./node.gpg
    echo "deb https://deb.nodesource.com/node_8.x xenial main" > /etc/apt/sources.list.d/nodesource.list

    apt-key add ./yarn.gpg
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list
    apt-get update
    apt-get install -y ruby2.4{,-dev} nodejs yarn=1.7.* \
        {zlib1g,libxml2,libsqlite3,libxmlsec1}-dev make g++ git libpq-dev \
        postgresql

    apt-mark hold yarn
}

function download_canvas {
    pushd "$HOME"
    git clone https://github.com/instructure/canvas-lms.git
    cd canvas-lms
    git checkout release/2018-08-25.43
    popd
}
export -f download_canvas

function setup_pg_user {
    createuser vagrant
    psql -c "alter user vagrant with superuser" postgres
}
export -f setup_pg_user

function install_canvas_deps {
    pushd "$HOME/canvas-lms"
    bundle install --path vendor/bundle
    yarn install --pure-lockfile
    popd
}
export -f install_canvas_deps

function config_canvas {
    pushd "$HOME/canvas-lms"

    for config in amazon_s3 delayed_jobs domain file_store outgoing_mail security external_migration database
    do
        cp -v config/$config.yml.example config/$config.yml
    done

    popd
}
export -f config_canvas

function build_assets {
    pushd "$HOME/canvas-lms"
    bundle exec rails canvas:compile_assets
    popd
}
export -f build_assets

function setup_database {
    pushd "$HOME/canvas-lms"
    createdb canvas_development || true
    createdb canvas_test || true
    export CANVAS_LMS_ADMIN_EMAIL=user@example.com
    export CANVAS_LMS_ADMIN_PASSWORD=asdfasdf
    export CANVAS_LMS_ACCOUNT_NAME="Atomic Jolt"
    export CANVAS_LMS_STATS_COLLECTION=opt_out
    bundle exec rails db:initial_setup
    popd
}
export -f setup_database

function setup_rails_shortcut {
    mkdir -p "$HOME/bin"
    pushd "$HOME/bin"
    cat << EOF > rails
#!/bin/bash
cd "$HOME/canvas-lms"
bundle exec rails s --binding 0.0.0.0
EOF
    chmod +x rails
    popd
}
export -f setup_rails_shortcut

cd /vagrant
mkdir -p /state
chmod 777 /state

once install_deps
as vagrant once download_canvas
as postgres once setup_pg_user

gem install bundler --version '< 1.14'
as vagrant install_canvas_deps
as vagrant config_canvas

# you have to do this before running migrations or there's an error with the
# brandable css
as vagrant once build_assets
as vagrant once setup_database
as vagrant setup_rails_shortcut
