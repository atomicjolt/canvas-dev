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
 
5. As the vagrant user, start rails. This can be done in two ways:
```bash
cd ~/canvas-lms
bundle exec rails --binding 0.0.0.0
```
or simply `rails` which is a script on your path that does that for you.

6. Visit canvas in your browser at localhost:8080.
Username:  `user@example.com`
Password: `asdfasdf`
