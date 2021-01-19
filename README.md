# canvas-dev
Run Canvas LMS in development mode in a virtual machine.

## Set up
1. Install [Vagrant](https://www.vagrantup.com/docs/installation/) and clone this repo.
2. Within the repo run `vagrant up`. This may take some time if you haven't downloaded the base Ubuntu 16 image before.
3. Run `vagrant ssh` and `sudo -i` to become root.
4. Run `/vagrant/setup.sh` to install Canvas. Go play foosball for about 20 minutes.
 Note that this may fail, but *should* be safe to run multiple times.
 This script automates the following tasks:
    1. Installs Ruby, Node, Yarn, Postgres, and other required OS packages.
    2. Clones Canvas and checks out a stable release.
    3. Configures Canvas with default settings.
    4. Installs Ruby gems and npm packages.
    5. Creates and sets up the database.
    6. Compiles assets.
    7. Runs Canvas, delayed jobs, and the RCE api automatically and sends logs
       to syslog

5. Visit canvas in your browser at localhost:8080.
Username:  `admin@example.com`
Password: `asdfasdf`

6. (optional) If you want ssl, copy the provided canvas.conf into your nginx
   sites-enabled directory. This makes the assumption that you use the
   atomicjolt.xyz ssl strategy. Otherwise you will have to modify it. On MacOS,
   you may need to add `canvas.conf` to the your nginx `servers` directory
   instead.

## Running manually
If you'd rather run a service manually, find the directory in /etc/service where
it's run from and run `svc -d [path-to-directory]`. Then start the service as
the vagrant user as described below:

### Rails
```bash
cd ~/canvas-lms
bundle exec rails server --binding 0.0.0.0
```

### Delayed job
```bash
cd ~/canvas-lms
./script/delayed_job run
```

### RCE API
```bash
cd ~/canvas-rce-api
NODE_ENV=production npm start
```
