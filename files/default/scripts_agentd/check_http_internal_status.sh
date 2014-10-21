#!/bin/bash
JSAWK=$( which jsawk )
code=0
msg="OK"
# $1 = http://taxonomy01.priv.cloud.kbrwadventure.com/
# $2 = url page
# $3 = --ipv4  --ipv6
# $4 = s or nothing

if [ $# -lt 1 ]; then echo "Url missing"; exit 1; fi
url=$(curl $3 -s http$4://$1/$2)
if  [ "$(echo $url)" == "" ]; then 
msg="Service not available"; code=1 ;else
if [ "$(echo $url | $JSAWK 'return this.status')" == "ko" ] ; then
msg=$(echo $url | $JSAWK 'return this.errors')
msg="Service in error : $msg"
code=1
fi
fi
echo $msg
exit $code
