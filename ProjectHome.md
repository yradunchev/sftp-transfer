# Rationale #

I couldn't find any open source project with pre-meditated best practices for securely and safely transferring files over a network between two servers.

Therefore I decided to roll my own and the result is a set of two very simple scripts to handle the file transfers using sftp. The scripts are meant to be set up as cron jobs. Clever use of lsof, mv and control files prevent files being picked up before they are fully transferred. You need to set up sftp and optionally a chroot jail to use them.

This project is open source, so is open to any improvements and comments. Let me know what you think or contribute your changes!

Hopefully, what is written and published here immediately attends your requirements. If not, I hope these scripts and explanations are a useful starting point. In the latter case, I appreciate any contributions!

Submit any issues you may find here: http://code.google.com/p/sftp-transfer/issues/list

# Features #

The project has the following features:

  * Should run on most Linux platforms.
  * Open source under GPLv3.
  * Transfers files from a pre-selected directory on server A to another pre-selected directory on server B.
  * Scripts are designed to run from a scheduler like _cron_, but you could also run them from the shell.
  * Defers transferring of files that are still open (uses _lsof_).
  * Makes use of standard unix/linux utilities, such that specific requirements can be more easily met or specific setups implemented.
  * Includes full installation instructions for Ubuntu.
  * The destination server doesn't pick up files that haven't been transferred in full.
  * Automated file management (error/archive).

# Negative scope #

  * **The scripts do not detect duplicate file names**. So transferring files with the same name will cause the files to be overwritten with the most recent version, either on the source or destination server.
  * There is no notification in place for failed transfers.
