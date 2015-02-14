#!/bin/sh

cd demo-src
logfile=../demo_`date +%Y%m%d%H%M%S`.log
../persona.pl demo.desc ../demo $logfile en cs
