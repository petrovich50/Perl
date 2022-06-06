#!/bin/bash
#собираем значения переданных байт с интерфейсов
echo -n `date --rfc-3339=seconds`" input,"
snmpget -v 2c -c AlSiTeC  141.101.186.5 1.3.6.1.2.1.31.1.1.1.6.1118 | sed 's/.*:\(.*\)$/\1/g'
echo -n `date --rfc-3339=seconds`" output,"
snmpget -v 2c -c AlSiTeC  141.101.186.5 1.3.6.1.2.1.31.1.1.1.10.1118 | sed 's/.*:\(.*\)$/\1/g'
