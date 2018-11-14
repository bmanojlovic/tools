# Various tools or scripts

Just tools which help but not really important to anyone except me...

## AIX bashrc

bashrc for AIX to make it a bit more usable...

## RUN_X_APP_AS_DIFFERENT_USER

RUN_X_APP_AS_DIFFERENT_USER is a script to be used when you would like to run some GUI program as different user (name of script :) )

```bash
PROGRAM=/usr/bin/kodi
PROGRAM_USER=kodi
```
What should be set in script is `PROGRAM_USER` and `PROGRAM`  as program name, 

add sudoers part and that is it run script as you and it will be all set (GUI and sound too)

## export-git-tag.sh

still a bit usable export script. Some things are now integrated into git but will keep it for future reference :)

## import_cert.sh

needed wait to import certs into local cert store - probably there were some easier ways to do it... but hey ()

## rotatelog for rsyslog

This script is to be used in places where you need "simple" log rotation with constant number of backups or keeping unarchived files and archived older than number of configured history files

there are few thing to configure but logic is next

```bash
ARCHIVE=NO
SIZE=104857600
HISTORY=30
```

Set `ARCHIVE=YES` if you require files to be archived - there is one minus with this setup if you do not remove archived files eventually it will overflow (read fill up disk)

Set how many files should be kept as backup in rotation with `HISTORY`

### Simple example of rotation

if your files are for example `mail.log messages secure` go to `/etc/rsyslog.d` and copy `rotatelog` and run next snippet

```bash
cd /etc/rsyslog.d/
for i in mail.info messages secure; do
    cp rotatelog rotatelog-${i}
done
./rotatelog
```

this will create `logrotate.conf` which will have something like this

```
$outchannel log_r_mail.info,/var/log/mail.info,104857600,/etc/rsyslog.d/rotatelog-mail.info
$outchannel log_r_messages,/var/log/messages,104857600,/etc/rsyslog.d/rotatelog-messages
$outchannel log_r_secure,/var/log/secure,104857600,/etc/rsyslog.d/rotatelog-secure
```
Now edit your rsyslog.conf and change all references
from:

```
mail.info                               -/var/log/mail.info
```

to 

```
mail.info                              :omfile:$log_r_mail.info
```

and that is all what is required to make it rotate as you would like it to be rotated on file size