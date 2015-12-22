# Introduction #

This page describes the design of the scripts. It explains what the setup on each server takes care of, the applications that the scripts call and how the overall transfer process was designed.

# Details #

The objective of the system is to transfer files from one server to another quickly, securely and in a managed way. This means that the following objectives must be satisfied:

  1. A user or process should be able to drop a file into a directory without worrying about how to transfer this to another computer securely and quickly.
  1. Files in progress of being written may not be picked up by the transfer process, such that incomplete files are not sent to the destination host.
  1. If a file cannot be transferred for whatever reason, the file must be locally transferred to the local error directory.
  1. If a file is successfully transferred, it must locally archive the file in the local archive directory for possible later inspection or until the administrator / application owner decides the files are no longer needed or have been archived to another persistent medium.
  1. The source and destination of the transfer must both keep a log of processing.
  1. Processing at the destination may not pick up files that have not been entirely transferred.
  1. Any error when moving files should be logged.
  1. The destination must allow for the use of an isolated account for security purposes if so desired.
  1. The two sides should authenticate properly in batch mode and should not require user interaction.

In the following paragraphs, the design will detail how the requirements have been satisfied.


## Source configuration ##

The source side of the transfer uses a number of directories for file management. The main directory of the setup on the source contains the script. The subdirectories are used to insert files for transfer or for logging or archiving purposes. The layout is as follows:

|Sub directory name|Purpose|
|:-----------------|:------|
|archive           |Stores files that were successfully transferred|
|control           |Stores control and command files for executing the transfer.|
|error             |A directory where files are stored that couldn't be transferred for whatever reason|
|log               |Keeps log files, one log file per invocation|
|outbox            |The directory where files need to be put to be transferred|
|processing        |A directory where files are copied to from the outbox to indicate they are being processed|

## Destination configuration ##

The destination side uses two separate accounts for processing. One account is set up for secure transfer only and receiving the files in an inbox. Another account is used to extract the files from the inbox and move it elsewhere for further processing.

|Sub directory name|Purpose|
|:-----------------|:------|
|/home/'<'username'>'/inbox|The inbox where the sftp server processes stores the files that are sent by the source server|
|available         |A directory on the second account where the files from the inbox are copied to, once the files have completely been transferred.|
|log               |The log files for the destination process.|

### Never pick up incomplete files ###

This requirement is met by using different utilities and mechanisms. On the source side where files are transferred from, a process or user would typically store a file in the outbox directory.

If the file is large, or writing the file there takes a considerable time for whatever reason, the file may not yet be picked up and copied to the processing directory before it's closed and complete.

The script therefore uses the _lsof_ utility, available on many UNIX computers, to verify if there are any processes that have this file open. If the file cannot be found by _lsof_, the file is assumed closed. The return code of _lsof_ is then 1. If the file _was_ found by _lsof_, the return code is 0. In that case, the file should be left for this cycle. A log message is printed just in case.

Files that are in processing are about to be sent to the destination server. To signal complete transfer on the destination side, a _control file_ of 0 bytes is sent along. The destination process polls the inbox on these control files.

The transfer process uses a simple naming scheme to complete the transfer. The control file names always start with _control'_'_. The destination scans for any files with that prefix and strips the prefix to get the data file name. If the control file is detected, the destination process knows that the data file has already been transferred in full. It will then copy the data file to the available directory in the processing account._

Further down the stream, there may be other processes consuming from the _available_ directory. To prevent any problems picking up files there, you should typically ensure that the _available_ directory is on the same drive as the _inbox_ directory of the other account. When on the same drive, a _move_ operation creates an inode pointing to the data of the file without a byte-for-byte copy of the entire data area. In that case, the _move_ operation is instantaneous and any other processes will never pick up incomplete files. If the available and inbox directories are on different drives (or worse, on different machines), the _move_ will require a copy operation instead, creating the potential that the file is picked up whilst incomplete.


### Do not attempt to copy files indefinitely on failure ###

To reduce system load, if any problem occurs when moving, deleting or transferring a file on the client, the file is moved to the error directory and a message is written to the log. On success, the file transferred is moved to the archive directory.


### On the use of SFTP ###

SFTP is the protocol of choice for executing the file transfer. SFTP is a utility and server-side process which has a wide range of configuration options and customisations. Using SFTP instead of any other custom means allows administrators to customize the process to meet specific policies or guidelines.

The default instructions require SFTP to be used as part of a batch process, scheduled through a scheduler like _cron_ for example for a particular UNIX user with particular permissions on the system. For this reason, it should be possible to login to a remote server securely non-interactively.

Therefore, the system requires a private/public key pair to be generated on the client machine. The public key is then exchanged with the destination server and installed in the secure account meant for sftp transfers. There, it is stored in the _authorized'_'keys_store for that particular user._

This allows the client UNIX user to login with its private key to the destination machine under that user and get directed to a particular inbox.

On the server side, the SFTP process can optionally be restricted further by a chroot jail. This means that once the client user logs in, they will only have access to a shielded area of the destination machine and cannot see or potentially manipulate system files of that destination system.

The security can be extended even further by only allowing sftp access and not allow any logged in person to start a shell or run custom commands.

The configurations necessary to enable these security settings are described in the installation guide. The installation guide however is not complete in all the possibilities, so you should use an internet search engine to look for more possibilities and alternatives.

The chroot jail, if configured according to the installation guide, uses rssh. There are different methods for configuring chroot and many different configuration options that can be set, enabled or disabled. Please check the specific guides for more information.