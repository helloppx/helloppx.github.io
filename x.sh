#!/usr/bin/expect 
set timeout 30 
spawn git add .
spawn git commit -m "lsl"
spawn git push
expect "Username" 
send "helloppx@gmail.com\r" 
expect "Password" 
send "pythonalvin123\r" 
interact 
