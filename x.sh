#!/usr/bin/expect 
set timeout 30 
spawn git pull
expect "password:" 
send "ispass\r" 
interact 
