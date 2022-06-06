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
my $indexes= shift || $mystat->_read_indexes() ;#[['1059','141.101.186.2'],['791','141.101.186.2'],['792','141.101.186.2']];u
my $nodes=shift||$mystat->{_interfaces};
#print "HHHHHUY";
#exit;
#$mystat->set_param($indexes,'','','');
if (ref($indexes) eq "ARRAY"){
    print $mystat->set_ini({'_list_desc'=>$indexes})," --ghgg \n";
}else{
    print Dumper($mystat->_write_log($indexes."\n"), $indexes);
    exit 0;
}

if (ref($nodes) eq "HASH"){
    print $mystat->set_ini({'_interfaces'=>$nodes}), " 999999 \n";
}
#print Dumper($mystat)," ---obj \n";
#print $mystat->{_active_indexes_file};
#print $mystat->{_interfaces};
#print $mystat->{_log}," --- logginfile   \n";
#$mystat->_write_indexes($mystat->{_active_indexes_file});
#print ref($mystat)," --- WRITE \n";
#print $mystat->add_counters_data();
#print ref($mystat)," --- ADD \n";
#print  $mystat->_test_make_db(),"--test make_db  \n";
#print $mystat->set_ini({'_list_desc'=>[]})," set empty indexes \n";
#print $mystat->_create_tables();
print Dumper($mystat,$mystat->{_log}),"  <<<<<< \n";
print " HHHHHHHHHHHHHHHHHHHHHHHH \n" if -e $mystat->{_log};
#print $mystat->_write_indexes();
my $timestamp=time();
#print $mystat->_test_make_db()," (((((((((( \n";
if (${\($mystat->_test_make_db())}!~/no/){
    print " tut1 \n";
    if(${\(${\($mystat->_create_tables())})}!~/no/){
        $mystat->_write_log($timestamp.', '.${\($mystat->_write_indexes())}."\n") if ${\(${\($mystat->_create_tables())})}!~/no/;
	print "tut11 \n";
    }else{
	print " tut12 \n";
        $mystat->_write_log($timestamp.', '."no tables exists or cannot be created \n");
    }
}else{
    print " tut2 \n";
    $mystat->_write_log($timestamp.', '."no DB connected \n");
}
print ">>>>>>>>> \n" if -e $mystat->_log_ini();

#print  $mystat->_write_indexes($mystat->{_active_indexes_file})," --arch dropped \n";

#print $mystat->_file_unzip('/usr/share/zabbix/externalscripts/BURST_DIR/ARCH_DIR/COUNTERS_141.101.186.2_27-04-2018/back_counters_1059_141.101.186.2_1524806726.gz')," --UNZZZZZZZZZZZZZZZZZZIP \n";
#print $mystat-> _fullfill_db()," ---fullfill data\n";
