#!/bin/bash

/usr/local/bin/mosquitto_pub -i time_upd -t "eddie/info/time" -m "`date +"%s"`" &>> /tmp/time_pub.log

