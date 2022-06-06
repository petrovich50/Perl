#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use lib '/usr/share/zabbix/externalscripts/MODULES';
#use Data::Dumper;
use MyZabbix::USER_LLD;
use BURST_CALC::STAT;
use Data::Dumper;

my $mystat=BURST_CALC::STAT->new();
my $indexes=$mystat->_read_indexes(); #[['1059','141.101.186.2'],['791','141.101.186.2'],['792','141.101.186.2']];

$mystat->set_ini('_list_desc'=>$indexes);
#print ref($mystat)," ---SET \n";
#print $mystat->{_active_indexes_file};
#print $mystat->{_interfaces};

#$mystat->_write_indexes($mystat->{_active_indexes_file});
#print ref($mystat)," --- WRITE \n";

 $mystat->add_counters_data();
#print ref($mystat)," --- ADD \n";
