# Introduction #

This is the installation manual for the scripts. Probably, you'll want to be a server admin or developer or other geeky computer user to understand this page.

This page explains, step-by-step, how to make adjustments to your system to use the scripts effectively and securely.

For now, **the installation procedure probably only works on Ubuntu**, since that's my method of choice.

The procedure should hopefully be detailed enough to understand what is going on.

The **server** is the system _receiving the files_ to be processed. The **client** is the server or user _sending the files_.

## General ##

Below, you'll need to do most actions as root. In Ubuntu, this means using the 'sudo' command. You can choose to run all commands as root (sudo -s), or prepend each command with the 'sudo' command. Example:

```
alice@:~$ sudo -s
[sudo] password for virtual: *******
root@:~$ 
```

or:

```
alice@:~$ sudo apt-get install .....
........
alice@:~$ sudo apt-get install .....
........
etc.
```

I like to _sudo -s_ to root mostly, so this tutorial assumes that. Don't forget to _exit_ back to a normal user after configuration is complete, as small mistakes can seriously damage your system.


## Prerequisites ##

This section lists the prerequisites for installing it on your system. It is for now based on Ubuntu Linux, both for client and server. It is also assumed that both client and server set up the scripts through a scheduler such as cron.

**Client**
  * Base Ubuntu packages
  * Open SSH client
  * rssh package

**Server**
  * Base Ubuntu packages
  * Open SSH server
  * rssh package

## Client installation ##

On the client, install the Open SSH client and the rssh client. The following steps show you how to do this on Ubuntu:

```
root@myclient:~$ apt-get install openssh-client
root@myclient:~$ apt-get install rssh
```

The rssh package will also install openssh-server on Ubuntu.

## Server installation ##

On the server, install the OpenSSH server and the rssh client. The following steps show you how to do this on Ubuntu:

```
root@myserver:~$ apt-get install openssh-server
root@myserver:~$ apt-get install rssh
```

The packages are now installed, but not yet properly configured. Please see the architecture for details on what we're trying to achieve in total.


## Setting up accounts ##

You need three different accounts in total. One account on the client machine and two accounts on the server machine. The following process describes how to organize user privileges, groups and other stuff in order to use the scripts properly. Make sure that you generate good passwords before creating the accounts, or just use one strong password for all accounts together to make them easier to manage.

_We'll call the client user **alice**, the server restricted user **bob** and the server application user **zoe**._

_The client and server machine are called **myclient** and **myserver** respectively._

Let's create the user to send the files from on the client machine. On Ubuntu:

```
root@myclient:~$ useradd -d /home/alice -m -s /bin/bash alice
root@myclient:~$ passwd alice
Enter new UNIX passwd: *****
Retype new UNIX passwd: *****
passwd: password updated successfully.
root@myclient:~$ chmod o-rwx /home/alice
```

Let's create the two accounts on the server machine:

```
root@myserver:~$ useradd -d /home/bob -m -s /bin/bash bob
root@myserver:~$ useradd -d /home/zoe -m -s /bin/bash zoe
root@myserver:~$ passwd bob
Enter new UNIX passwd: *****
Retype new UNIX passwd: *****
passwd: password updated successfully.
root@myserver:~$ passwd zoe
Enter new UNIX passwd: *****
Retype new UNIX passwd: *****
passwd: password updated successfully.
root@myserver:~$ chmod o-rwx /home/bob
root@myserver:~$ chmod o-rwx /home/zoe
```

Ok, this is fine for a basic setup. You can try to log in to these accounts from any other account, as long as you know the password and you're not logged in as root. That'll tell you whether the accounts actually work for a login:

```
anyuser@myclient:~$ su - alice
Password: *****
alice@myclient:~$
```

and:

```
anyuser@myserver:~$ su - bob
Password: *****
bob@myserver:~$ exit
anyuser@myserver:~$ su - zoe
Password: *****
zoe@myserver:~$ exit
```

Actually, the bob user still has too many privileges and isn't set up properly for the sftp process. We'll work on that later. For now, we keep the account as is, since a couple of things still need to happen and having a bash shell and login make it easier to test the setup.

## Basic validation and verification ##

You should now be able to rssh and ssh into each separate system from your shell. Let's verify the setup now, so that if we run into any strange stuff, we localize it now. **Pay attention to the user that's issuing the commands for each block of code**

For the following commands, since you have never connected to this host before, the SSH authentication process sends out the public key of the host you're connecting to. You, as a user (or pretending to be a user), can choose to accept the user's claimed identity and add it to your known hosts file. Any connections in the future you make against the same machine can then be validated against this public key.

For the purpose of this exercise, you don't need to store the key, so you can reply "no".

```
alice@myclient:~$ ssh bob@myserver
< ... messages ... >
bob@myserver's password: 
```

Supply your remote password as if you log in from anywhere else and you should have a shell to the box. Verify the environment if you like before we continue.

```
alice@myclient:~$ rssh bob@myserver
< .... account is restricted message ... > 
```

On standard Ubuntu machines, the only way that rssh can be used is through scp. That is what the message says anyway. But we've validated that things are likely working. We'll reconfigure the services now such that we can use it for our purposes.

```
alice@myclient:~$ sftp bob@myserver
Connecting to myserver...
bob@myserver password: *****
sftp> 
```

So that works. Cool. We're now ready to make things more secure.

## Adding an automatic login method for sftp processes on the bob account ##

Alice has an account on a client machine and wants to gain temporary access to some 3rd party secured account on some server machine to dump files on. We shouldn't want a third party to generate keys for us, because we don't have full visibility how the other party has their key management set up. So, basically:

  1. alice generates keys
  1. alice shares her public key with the remote system
  1. the admin at the other end adds alice's key to the store of authorized keys for the secured user
  1. the server machine can now authenticate alice by her public key and gives alice access to bob's account.


Let's generate a private/public keypair for alice first. We won't use a password protected private key, because we're trying to automate this. If in your case this scenario is different, do add a password.

```
alice@myclient:~$ ssh-keygen -t dsa -f ~/.ssh/id_dsa
< created directory ... >
< Enter passphrase: >
< Enter same passphrase again: >
< ... blurb ... >
alice@myclient:~$ cd .ssh
alice@myclient:~/.ssh$ ls -al
-rw------- 1 alice alice  999 YYYY-MM-DD HH:MM id_dsa
-rw-r--r-- 1 alice alice  999 YYYY-MM-DD HH:MM id_dsa.pub
alice@myclient:~/.ssh$ 
```

The .pub file is the public key, the other the private.

Let's transfer this id\_dsa.pub file to the server machine as follows. It's probably best to give a good name to the file, so it doesn't accidently overwrite anything:

```
alice@myclient:~$ cd .ssh
alice@myclient:~/.ssh$ cp id_dsa.pub id_dsa_alice.pub
```

Then copy the file over to the server. Let's put the file in bob's home directory for now and make it readable for bob. Then log in as bob:

```
bob@myserver:~$ mkdir .ssh
bob@myserver:~$ cat id_dsa_alice.pub >> ~/.ssh/authorized_keys
bob@myserver:~$ chmod 600 ~/.ssh/authorized_keys
```

Then, we need to change the configuration slightly on the client machine to set up SSH client processes to attempt authentication through the identity file. On my machine, I couldn't find this file, but some people say it should be there in the config:

```
root@myclient:~$ cd /etc/ssh
root@myclient:/etc/ssh$ # vi sshd_config
```

Then uncomment the line:

> 'IdentityFile ~/.ssh/id\_dsa'

This should really be it. Before this public/private key authentication, we could only get authenticated through a username/password combination. But now, if we're logged in as alice (since alice's home area contains her .ssh/id\_dsa file), we can log in to the server machine as bob and it will recognize alice immediately. Notice that other users cannot log in 'quietly' as such and will still require to type a password.

```
alice@myclient:~$ sftp bob@myserver
Connecting to myserver...
sftp> exit
alice@myclient:~$ ssh bob@myserver
Linux xxxxxx 2.6.27-7-generic #1 SMP <date> i686

<motd blurb>

bob@myserver:~$ exit
```

Notice how, when connecting through alice, the machine didn't request a password. Trying to log in from any other user however, the password is requested (try it out!).

The last one shows that it's still possible to log in as bob, which isn't normally what we want. Also, if you're allowing third parties to upload data or content through sftp, you don't want to potentially give them access to the entire machine. People could abuse the account for other purposes or read data in other directories from other third parties.

So you could secure the account further using a jail (chroot), such that the logged in user can never access the major part of the system and remains constricted to a controlled area. This step however is **_optional_**.

## Securing bob through chroot ##

I've got this method from: http://ubuntuforums.org/showthread.php?t=128206

A slightly alternative method is here: http://ubuntuforums.org/showthread.php?t=1057657

The following changes are quite specific for this setup and Ubuntu, so it's very likely it won't work for your machine. I hope there are other tutorials on chroot-ing sftp for your setup that you can use in that case.

Let's get started on this. Assuming you're not using specific configurations for rssh already, let's create a backup first and start editing it. We only need to make changes on the server:

```
root@myserver:~$ cd /etc
root@myserver:/etc$ cp rssh.conf rssh.orig.conf
root@myserver:/etc$ vi rssh.conf
```

Then uncomment the allow**lines to set up specific process types. For sftp, we need to uncomment the line:**

> '# allowsftp'
> 'allowsftp'

Also, the chrootpath should be set to '/home/bob'.

See the above tutorial link for more information on securing this environment better.  In short, the "PermitUserEnvironment" parameter should be set to "no" in the sshd configuration file.

Ubuntu comes with a standard 'mkchroot' package. This package is a shell script to very quickly set up the necessary binaries and directory structure to allow this user to become jailed.

On my machine and the newest Ubuntu, this file is already unpacked and can be used as follows:

```
root@myserver:~$ cp /usr/share/doc/rssh/examples/mkchroot.sh /home/bob
root@myserver:~$ cd /home/bob
root@myserver:/home/bob$ vi mkchroot.sh
```

Before using this script, check the paths somewhere down the middle are correct. you can check the correctness by the 'rssh -v' command:

> 'rssh -v'

If things are ok, let's get started. The commands do the following:

  1. User bob gets the rssh shell
  1. The mkchroot.sh script is made executable and executed for the /home/bob directory.
  1. We're creating a directory 'home/bob' inside the /home/bob directory.
  1. The /etc/passwd is modified, such that bob's homedrive is now within the chroot jail.
  1. We should create the new chroot'ed home dir for bob.
  1. Since the home dir changed, the .ssh for login validation moves along to accomodate that change.
  1. The rssh shell is added to the list of valid shells
  1. The chroot helper is setuid to root (ubuntu has alternative setup possibility through "dpkg-reconfigure rssh")

```
root@myserver:/home/bob$ usermod -s /usr/bin/rssh bob
root@myserver:/home/bob$ chmod u+x mkchroot.sh
root@myserver:/home/bob$ ./mkchroot.sh /home/bob
root@myserver:/home/bob$ vi /home/bob/etc/passwd
( see comments below. Remove all lines except bob, verify the shell and modify /home/bob to /files. You should be able to just maintain:

 'bob:x:9999:9999::/home/bob:/usr/bin/rssh'

root@myserver:/home/bob$ vi /etc/passwd

 'bob:x:9999:9999::/home/bob/home/bob:/usr/bin/rssh'

root@myserver:/home/bob$ mkdir -p /home/bob/home/bob
root@myserver:/home/bob$ mv .ssh/ home/bob
root@myserver:/home/bob$ add-shell /usr/bin/rssh
root@myserver:/home/bob$ chmod u+s /usr/lib/rssh/rssh_chroot_helper
root@myserver:/home/bob$ chown -R root:root home
root@myserver:/home/bob$ chown -R bob:bob home/bob
root@myserver:/home/bob$ chmod o-rwx home/bob
```

We've now made a number of changes to the system. Before attempting the log in, let's ensure that we're getting error output to the syslog, just in case something failed. For this reason, we're using an "-a" flag on the syslog, which opens another _socket_ that the system logger will listen to. See 'man sysklogd' for details. The configuration for the sysklogd on Ubuntu is done through /etc/default. Other locations may exist on other distributions.

**careful! any mistakes made here can mess up your system!**

```
root@myserver:/home/bob$ cd /etc/default
root@myserver:/etc/default$ vi syslogd
```

Then search for the line:

> 'SYSLOGD=""'

( you actually may have something in there. If so, just append the following terms) and change it to:

> 'SYSLOGD="-a /home/bob/dev/log"'

Then restart sysklogd:

> 'root@myserver:/etc/default$ /etc/init.d/sysklogd restart'

Now, let's see if syslog is working and at the same time test our setup. Let the root shell tail on the syslog file and attempt a login:

```
root@myserver:/etc/default$ cd /var/log
root@myserver:/etc/default$ tail -f syslog
```

From another shell, become alice and sftp in:

```
alice@myclient:~$ sftp bob@myserver
Connecting to myserver...
sftp> exit
alice@myclient:~$ ssh bob@myserver
<motd blurb>
This account is restricted by rssh.
Allowed commands: sftp 

If you believe this is in error, please contact your system administrator.

Connection to localhost closed.
alice@myclient:~$ 
```

and from any other user:

```
anyuser@myclient:~$ sftp bob@myserver
Connecting to myserver...
bob@myserver's password: 
sftp> 
```

Then check for any messages on the root tail shell. You should just see messages float by which do not indicate any errors.

Other users can still log in because the system also allows password authentication. You could set 'PasswordAuthentication no' in the sshd\_config file to disable this if you only want people to be able to login through the key authentication method.

There are plenty of other tweaks possible that are far beyond the scope of this installation manual. You should be able to find lots of information about those.

_You should also verify that you are in the /home/bob/home/bob directory when you login through sftp and not the chroot jail /home/bob_.

# Installing scripts #

It's finally time to install the scripts, now that everything is working. This section shows you which scripts go where, how to set up the directory structures and how to set up the cron jobs so that the scripts get called frequently.

## Setting up scripts on the server ##

Log in as zoe on the server. This is the user that picks up the files from the chroot jail and moves them to another area on your server for processing. This move uses the 'mv' command, because this command doesn't require extra disk space and is much less likely to fail than a complete 'copy' operation. For this reason, you want to make sure the source and destination directories are on the same drive!

If 'cp' were used explicitly, it'd always perform a copy, thus copying bytes to a new file on another system. This means that a copy failure might leave around unfinished files in the target directory. Also, a copy might take a bit of time and any further processes might start picking up incomplete files. The 'mv' command is instantaneous, as long as it's executed with source and destination on the same drive.

The steps are as follows. We'll be using zoe's home directory to demonstrate the installation:

  1. Install the receive and general functions script in zoe's home directory.
  1. Set the execution permissions for zoe.
  1. Create zoe's directories.

```
zoe@myserver:~$ cp /<path-to-download>/sftp-transfer/general-scripts/transfer-gen-functions.sh ./
zoe@myserver:~$ cp /<path-to-download>/sftp-transfer/receive-scripts/transfer-receive.sh ./
zoe@myserver:~$ chmod u+x transfer-*
zoe@myserver:~$ mkdir log
zoe@myserver:~$ mkdir available
zoe@myserver:~$ ls -R .
.:
available  log  transfer_gen_functions.sh  transfer_receive.sh

./available:

./log:

```

_**If you're using different directories, change the configuration in the "transfer\_receive.sh" script at the top of the file.**_

Now, the user bob needs one directory where files are copied to from the client. Since bob cannot log in (it has the rssh shell), root should create the inbox for bob and set the required permissions. Note that I chose to add zoe to the "bob" group to give access to the inbox. There are very likely alternatives for setting this up differently:

```
root@myserver:~$ cd /home/bob/home/bob
root@myserver:/home/bob/home/bob$ mkdir inbox
root@myserver:/home/bob/home/bob$ chown bob:bob inbox
root@myserver:/home/bob/home/bob$ chmod g+w inbox
root@myserver:/home/bob/home/bob$ groups zoe
zoe
root@myserver:/home/bob/home/bob$ usermod --groups bob -a zoe
root@myserver:/home/bob/home/bob$ groups zoe
zoe bob
```

You may need to re-login after these changes to zoe, as any open shells don't pick up these changes automatically. Close the shell and log back in as zoe. Let's confirm we've got the right permissions set up. The next commands are sanity checks for zoe. Note that the

```
zoe@myserver:~$ groups
zoe bob
zoe@myserver:~$ ./transfer_receive.sh
zoe@myserver:~$ cat log/*
Starting script @ 12:24:28
Processing files in /home/bob/home/bob/inbox
Script exited @ 12:24:28 with retval: 0
```

Good, so we've got the server end working. Let's set up the client end now.

## Setting up scripts on the client ##

Login as alice on the client. Alice will be the user / process which frequently transmits files to another server using the client scripts. You determine the schedule using the cron jobs.

We'll do the following:

  1. Copy alice's scripts to her home directory
  1. Set execute permissions
  1. Create alice's directories
  1. Set read permissions for all others
  1. Test the scripts are working properly

```
alice@myclient:~$ cp /<path-to-download>/sftp-transfer/general-scripts/transfer-gen-functions.sh ./
alice@myclient:~$ cp /<path-to-download>/sftp-transfer/send-scripts/transfer-send.sh ./
alice@myclient:~$ chmod u+x transfer-*
alice@myclient:~$ mkdir outbox
alice@myclient:~$ mkdir log
alice@myclient:~$ mkdir processing
alice@myclient:~$ mkdir control
alice@myclient:~$ mkdir error
alice@myclient:~$ mkdir archive
alice@myclient:~$ chmod -R o-rwx .
```

We should now be able to send files across. The 'outbox' directory is the directory where other processes should dump files in to be sent over. Preferably, any other process uses the 'mv' command for putting the file there, where the source and destination directory are on the same drive.

This send script however will verify if the file is closed and not in use by any other process before it attempts to pick up the file.

Sanity checks:

```
alice@myclient:~$ ls -R
.:
archive  control  error  log  outbox  processing  transfer_gen_functions.sh  transfer_send.sh

./archive:

./control:

./error:

./log:

./outbox:

./processing:

alice@myclient:~$ ./transfer_send.sh
alice@myclient:~$ cat log/*
Starting script @ 12:41:34
Processing files in /home/alice/outbox
Script exited @ 12:41:34 with retval: 0
alice@myclient:~$ rm -f log/*
alice@myclient:~$ touch outbox/testfile
alice@myclient:~$ ./transfer_send.sh 
alice@myclient:~$ cat log/*
Starting script @ 12:43:16
Processing files in /home/alice/outbox
sftp> cd inbox
sftp> put /home/alice/processing/testfile
Uploading /home/alice/processing/testfile to /home/bob/inbox/testfile
sftp> put /home/alice/control/control_testfile
Uploading /home/alice/control/control_testfile to /home/bob/inbox/control_testfile
removing /home/alice/processing/testfile
Script exited @ 12:43:16 with retval: 0
alice@recife:~$ ls -R
.:
archive  control  error  log  outbox  processing  transfer_gen_functions.sh  transfer_send.sh

./archive:
testfile

./control:

./error:

./log:
20090730_124316

./outbox:

./processing:
root@myserver:/home/bob/home/bob/inbox# ls -R
.:
control_testfile  testfile
zoe@myserver:~$ ./transfer_receive.sh 
zoe@myserver:~$ ls -R
.:
available  log  transfer_gen_functions.sh  transfer_receive.sh

./available:
testfile

./log:
20090730_124833
zoe@myserver:~$ cat log/*
Starting script @ 12:48:33
Processing files in /home/bob/home/bob/inbox
Script exited @ 12:48:33 with retval: 0
```

Ok, so that's basically done. Congratulations, you can now already transfer files from one system to another in a very managed way by just dropping files into directories.

## Setting up cron jobs ##

Now for scheduling the transfers. This depends on your requirements, file sizes, etc. how you want to set this up. See http://en.wikipedia.org/wiki/Cron for easy setup details. Let's start with zoe, then do alice. I'm specifying a run of every minute so that it's possible to verify the crons can be run by the cron daemon. Afterwards, you should change this to the required frequency.

First we set up the crontab, then verify the script was executed by inspecting the 'log' directories of zoe and alice. If log files accumulate, we've got a winner. For a final verification, inspect the contents of the latest log messages just to be sure.

```
zoe@myserver:~$ crontab -e
zoe@myserver:~$ crontab -l
# m h  dom mon dow   command
* * * * * /home/zoe/transfer_receive.sh
alice@myclient:~$ crontab -e
alice@myclient:~$ crontab -l
# m h  dom mon dow   command
* * * * * /home/alice/transfer_send.sh

.. wait a minute ...

alice@myclient:~$ ls log/*
< log files created every minute >
zoe@myserver:~$ ls log/*
< log files created every minute >

```

_**Don't forget to modify the crontab settings for the required frequency.**_.


**DONE!**