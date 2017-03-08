#!/bin/bash

# The email functionality requires you to have one off the following packages installed
# 
# 1) mail
#    https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-as-a-send-only-smtp-server-on-ubuntu-14-04    
#    $ which mail
#    $ sudo apt-get install mailutils
# 
# 2) sendmail (Not supported yet)
# 
# 3) Fallback php
#    requires commandline php access
# 

MAIL=$(which mail)
SENDMAIL=$(which sendmail)
PHP=$(which php)

# Definitions:
# To:      -t (eg. 'johndoe@company.com')
# Subject: -s (eg. 'The subject')
# Body:    -b (eg. 'The body')
#
# Example Call:
# ./cron.email.sh -t 'johndoe@company.com' -s 'The subject' -b 'The body'

SUBJECT="No Subject"
BODY="No Body"
TO="No Recipient"
while getopts ":s:b:t:" opt; do
  case $opt in
    t) TO="$OPTARG"
    ;;
    s) SUBJECT="$OPTARG"
    ;;
    b) BODY="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done


echo "$BODY" | mail -s "$SUBJECT" "$TO"