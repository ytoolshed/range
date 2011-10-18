#!/bin/sh
/sbin/ldconfig
if [ -r /etc/httpd/conf.d/mod_range.conf ]; then
    /etc/init.d/httpd restart
fi
exit 0
