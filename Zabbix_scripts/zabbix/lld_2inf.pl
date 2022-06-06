#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use lib '/usr/share/zabbix/externalscripts/MODULES';
# use Data::Dumper;
use MyZabbix::USER_LLD;

my $ip=shift || '85.115.253.75' ; #'83.220.249.81';
my $port=shift || '1605'; #'142';
my $oid=shift|| '.1.3.6.1.4.1.27142.1.12.25.1.1.2';
my $v=shift || '1';
my $c=shift || 'public';
my $other_ip=shift ||'192.168.101.103'  ;#'' ;
my $snmp_port2= shift ||'161' ;#"161";
my $index=shift || 'USERINDEX';
my $indexvalue=shift || 'USERVALUE';
my $form=shift;

my $inf ={$other_ip=>$snmp_port2, $ip => $port};
my $myzab=MyZabbix::USER_LLD->new();
$myzab->zabbix_user_lld($myzab->indexdata_lld_multi($inf,$oid,$v,$c), $index, $indexvalue, $form);