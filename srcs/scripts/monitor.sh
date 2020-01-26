#!/bin/bash

FILE="/var/tmp/checksum"
FILE_TO_WATCH="/etc/crontab"
VALUE=$(sudo md5sum $FILE_TO_WATCH)

if [ ! -f $FILE ]
then
         echo "$VALUE" > $FILE
         exit 0;
fi;

if [ "$VALUE" != "$(cat $FILE)" ];
        then
        echo "$VALUE" > $FILE
        echo "$FILE_TO_WATCH has been modified ! '*_*" | mailx -s "$FILE_TO_WATCH modified !" root
fi;