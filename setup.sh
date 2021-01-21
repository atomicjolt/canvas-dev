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

    curl -sS https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
    echo "deb https://deb.nodesource.com/node_10.x xenial main" > /etc/apt/sources.list.d/nodesource.list

    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list
    apt-get update
    # just installing resolvconf enables dnsmasq as a nameserver
    apt-get install -y daemontools-run dnsmasq resolvconf ruby2.6{,-dev} \
        nodejs yarn {zlib1g,libxml2,libsqlite3,libxmlsec1}-dev make g++ \
        git libpq-dev postgresql redis-server

    apt-mark hold yarn
}

function download_canvas {
    pushd "$HOME"
    git clone https://github.com/instructure/canvas-lms.git
    cd canvas-lms
    git checkout release/2020-11-18.29
    popd
}
export -f download_canvas

function download_rce {
    pushd "$HOME"
    git clone https://github.com/instructure/canvas-rce-api.git
    cd canvas-rce-api
    git checkout v1.8
    popd
}
export -f download_rce

function setup_pg_user {
    createuser vagrant
    psql -c "alter user vagrant with superuser" postgres
}
export -f setup_pg_user

function install_canvas_deps {
    pushd "$HOME/canvas-lms"
    bundle config set path 'vendor/bundle'
    bundle install
    yarn install --pure-lockfile
    popd
}
export -f install_canvas_deps

function install_rce_deps {
    pushd "$HOME/canvas-rce-api"
    cp .env.example .env
    npm install
}
export -f install_rce_deps

function config_dnsmasq {
    cat << EOF > /etc/dnsmasq.d/atomicjolt.xyz
address=/atomicjolt.xyz/10.0.2.2
address=/*.atomicjolt.xyz/10.0.2.2
EOF
    service dnsmasq restart
}
export -f config_dnsmasq

function config_canvas {
    pushd "$HOME/canvas-lms/config"

    for config in amazon_s3 delayed_jobs domain file_store outgoing_mail security external_migration database
    do
        cp -v $config.yml.example $config.yml
    done

    # redis is required for oauth
    cat << EOF > redis.yml
development:
  servers:
    - redis://localhost
  database: 1
EOF

    cat << EOF > domain.yml
development:
  domain: "canvas.atomicjolt.xyz"
  ssl: true
EOF

    cat << EOF > dynamic_settings.yml
development:
  config:
    canvas:
      canvas:
        encryption-secret: "astringthatisactually32byteslong"
        signing-secret: "astringthatisactually32byteslong"
      rich-content-service:
        app-host: "canvasrce.atomicjolt.xyz"
  store:
    canvas:
      lti-keys:
        # these are all the same JWK but with different kid
        # to generate a new key, run the following in a Canvas console:
        #
        # key = OpenSSL::PKey::RSA.generate(2048)
        # key.public_key.to_jwk(kid: Time.now.utc.iso8601).to_json
        jwk-past.json: "{\"kty\":\"RSA\",\"e\":\"AQAB\",\"n\":\"uX1MpfEMQCBUMcj0sBYI-iFaG5Nodp3C6OlN8uY60fa5zSBd83-iIL3n_qzZ8VCluuTLfB7rrV_tiX727XIEqQ\",\"kid\":\"2018-05-18T22:33:20Z\",\"d\":\"pYwR64x-LYFtA13iHIIeEvfPTws50ZutyGfpHN-kIZz3k-xVpun2Hgu0hVKZMxcZJ9DkG8UZPqD-zTDbCmCyLQ\",\"p\":\"6OQ2bi_oY5fE9KfQOcxkmNhxDnIKObKb6TVYqOOz2JM\",\"q\":\"y-UBef95njOrqMAxJH1QPds3ltYWr8QgGgccmcATH1M\",\"dp\":\"Ol_xkL7rZgNFt_lURRiJYpJmDDPjgkDVuafIeFTS4Ic\",\"dq\":\"RtzDY5wXr5TzrwWEztLCpYzfyAuF_PZj1cfs976apsM\",\"qi\":\"XA5wnwIrwe5MwXpaBijZsGhKJoypZProt47aVCtWtPE\"}"
        jwk-present.json: "{\"kty\":\"RSA\",\"e\":\"AQAB\",\"n\":\"uX1MpfEMQCBUMcj0sBYI-iFaG5Nodp3C6OlN8uY60fa5zSBd83-iIL3n_qzZ8VCluuTLfB7rrV_tiX727XIEqQ\",\"kid\":\"2018-06-18T22:33:20Z\",\"d\":\"pYwR64x-LYFtA13iHIIeEvfPTws50ZutyGfpHN-kIZz3k-xVpun2Hgu0hVKZMxcZJ9DkG8UZPqD-zTDbCmCyLQ\",\"p\":\"6OQ2bi_oY5fE9KfQOcxkmNhxDnIKObKb6TVYqOOz2JM\",\"q\":\"y-UBef95njOrqMAxJH1QPds3ltYWr8QgGgccmcATH1M\",\"dp\":\"Ol_xkL7rZgNFt_lURRiJYpJmDDPjgkDVuafIeFTS4Ic\",\"dq\":\"RtzDY5wXr5TzrwWEztLCpYzfyAuF_PZj1cfs976apsM\",\"qi\":\"XA5wnwIrwe5MwXpaBijZsGhKJoypZProt47aVCtWtPE\"}"
        jwk-future.json: "{\"kty\":\"RSA\",\"e\":\"AQAB\",\"n\":\"uX1MpfEMQCBUMcj0sBYI-iFaG5Nodp3C6OlN8uY60fa5zSBd83-iIL3n_qzZ8VCluuTLfB7rrV_tiX727XIEqQ\",\"kid\":\"2018-07-18T22:33:20Z\",\"d\":\"pYwR64x-LYFtA13iHIIeEvfPTws50ZutyGfpHN-kIZz3k-xVpun2Hgu0hVKZMxcZJ9DkG8UZPqD-zTDbCmCyLQ\",\"p\":\"6OQ2bi_oY5fE9KfQOcxkmNhxDnIKObKb6TVYqOOz2JM\",\"q\":\"y-UBef95njOrqMAxJH1QPds3ltYWr8QgGgccmcATH1M\",\"dp\":\"Ol_xkL7rZgNFt_lURRiJYpJmDDPjgkDVuafIeFTS4Ic\",\"dq\":\"RtzDY5wXr5TzrwWEztLCpYzfyAuF_PZj1cfs976apsM\",\"qi\":\"XA5wnwIrwe5MwXpaBijZsGhKJoypZProt47aVCtWtPE\"}"

EOF

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
    export CANVAS_LMS_ADMIN_EMAIL=admin@example.com
    export CANVAS_LMS_ADMIN_PASSWORD=asdfasdf
    export CANVAS_LMS_ACCOUNT_NAME="Atomic Jolt"
    export CANVAS_LMS_STATS_COLLECTION=opt_out
    bundle exec rails db:initial_setup
    popd
}
export -f setup_database

function enable_canvas_options {
    cat << EOF | psql canvas_development
INSERT INTO settings(name, value) VALUES ('enable_lti_content_migration', 'true');
EOF
    pushd "$HOME/canvas-lms"
    cat << EOF | bundle exec rails c
account = Account.first
account.settings[:global_includes] = true
account.save!
EOF
    popd
}
export -f enable_canvas_options

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

function setup_rails_service {
    mkdir -p /etc/service/canvas/log
    pushd /etc/service/canvas

    cat << EOF > run
#!/bin/bash
exec su vagrant -c "cd /home/vagrant/canvas-lms && bundle exec rails s --binding 0.0.0.0"
EOF

    chmod 700 run

    cd log

    cat << EOF > run
#!/bin/bash
exec 2>&1
exec setuidgid vagrant logger -t canvas-lms
EOF

    chmod 700 run
    popd
}

function setup_job_service {
    mkdir -p /etc/service/delayed_job/log
    pushd /etc/service/delayed_job

    cat << EOF > run
#!/bin/bash
exec su vagrant -c "cd /home/vagrant/canvas-lms && ./script/delayed_job run"
EOF

    chmod 700 run

    cd log

    cat << EOF > run
#!/bin/bash
exec 2>&1
exec setuidgid vagrant logger -t canvas-delayed-jobs
EOF

    chmod 700 run
    popd
}

function setup_rce_service {
    mkdir -p /etc/service/rce/log
    pushd /etc/service/rce

    cat << EOF > run
#!/bin/bash
export NODE_ENV=production
exec su vagrant -c "cd /home/vagrant/canvas-rce-api && npm start"
EOF

    chmod 700 run

    cd log

    cat << EOF > run
#!/bin/bash
exec 2>&1
exec setuidgid vagrant logger -t canvas-rce-api
EOF

    chmod 700 run
    popd
}

cd /vagrant
mkdir -p /state
chmod 777 /state

once install_deps
as vagrant once download_canvas
as postgres once setup_pg_user
config_dnsmasq

gem install bundler --version '< 2.1.4'

as vagrant install_canvas_deps
as vagrant config_canvas

# you have to do this before running migrations or there's an error with the
# brandable css
as vagrant once build_assets
as vagrant once setup_database
as vagrant enable_canvas_options

as vagrant once download_rce
as vagrant install_rce_deps

setup_rails_service
setup_job_service
setup_rce_service
