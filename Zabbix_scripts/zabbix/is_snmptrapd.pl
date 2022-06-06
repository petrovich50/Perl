#!/usr/bin/perl

use 5.010;
#use strict;
#use warnings;
use Data::Dumper;

my $options=shift||"";
my $cmd = 'ps aux | grep snmptrapd';
my $result = `$cmd`;
$result=`snmptrapd -c /etc/snmp/snmptrapd.conf $options`  if $result!~m/snmptrapd[\s\t\-c]*\/etc\/snmp\/snmptrapd\.conf/;