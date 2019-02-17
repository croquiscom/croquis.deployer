# How to test sample
1. Setup sample server using docker
    ```
    $ docker run -d -P --name sample rastasheep/ubuntu-sshd:18.04
    $ docker port sample 22
    0.0.0.0:32770
    $ ssh-copy-id root@localhost -p 32770
    $ ssh root@localhost -p 32770
    # apt-get update
    # apt-get install curl rsync cron
    # curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
    # nvm install 8
    ```
2. Setup SSH config
    ```
    $ cat ~/.ssh/config
    Host deployer-sample
        HostName localhost
        Port 32770
        User root
    ```
3. Run `npm run deploy`
