#!/usr/bin/perl

use 5.010;
#use strict;
#use warnings;
use lib '/usr/share/zabbix/externalscripts/MODULES';
use Data::Dumper;
use MyZabbix::USER_LLD;

my $ip=shift || '83.220.246.199' ; #'83.220.249.81';
my $port=shift || '1005'; #'142';
my $oid=shift|| '.1.3.6.1.4.1.27142.1.12.25.1.1.7.1';
my $v=shift || '1';
my $c=shift || 'public';
my $other_ip=shift ||'192.168.101.93'  ;#'' ;
my $snmp_port2= shift ||'161' ;#"161";
my $formula=shift||'f_as_is';

my $inf ={$other_ip=>$snmp_port2, $ip => $port};
my $myzab=MyZabbix::USER_LLD->new();


my $l = $myzab->get_snmp_multi($inf,$oid,$v,$c);
#printf ($format,$1) if $l=~m/(?<!\d)([\-]*\d+\.{0,1}\d*)(?!\d)/;
#my $file_out='/usr/share/zabbix/externalscripts/file_out.log';
#open (my $fh,">>", $file_out);

$formula = $myzab->can($formula) ? $formula : 'f_as_is'; 
#print $l,"n" ; #"\n botva\n" if $formula=='f_ekinop_cport';
if($l !~/error/){
  print $myzab->$formula($l, $inf, $oid, $v, $c);
#  print $l;
# print $fh $l." = UNFILTEED = $ip:$port  $other_ip:$snmp_port2 $oid \n";
}else{
 print 'error';#'-500.01';
# print $fh $l." = FILTER: -500  = $ip:$port $other_ip:$snm_port2 $oid \n";
 }
#close $fh;
