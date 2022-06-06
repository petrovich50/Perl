#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use lib '/usr/share/zabbix/externalscripts/MODULES';
#use Data::Dumper;
use MyZabbix::USER_LLD;
use BURST_CALC::STAT;
use Data::Dumper;
use Archive::Extract;
use IO::Zlib;
use  Archive::Tar;

my $mystat=BURST_CALC::STAT->new();
my $indexes=[['1059','141.101.186.2'],['791','141.101.186.2'],['792','141.101.186.2']];
#print "HHHHHUY";
#exit;
#$mystat->set_param($indexes,'','','');
print $mystat->set_ini({'_list_desc'=>$indexes}),"- set nonempty indexes file \n";
#print Dumper($mystat)," ---obj \n";
#print $mystat->{_active_indexes_file};
#print $mystat->{_interfaces};
print $mystat->{_log}," --- logginfile   \n";
#$mystat->_write_indexes($mystat->{_active_indexes_file});
print ref($mystat)," --- WRITE \n";
#print $mystat->add_counters_data();
#print ref($mystat)," --- ADD \n";
#print  $mystat->_test_make_db(),"--test make_db  \n";
#print $mystat->set_ini({'_list_desc'=>[]})," set empty indexes \n";
#print $mystat->_create_tables();
#print  $mystat->_write_indexes($mystat->{_active_indexes_file})," --arch dropped \n";
#print $mystat->_write_log(); #$mystat->{_counters_log_file};
#print $mystat->_file_unzip('/usr/share/zabbix/externalscripts/BURST_DIR/ARCH_DIR/COUNTERS_141.101.186.2_27-04-2018/back_counters_1059_141.101.186.2_1524806726.gz')," --UNZZZZZZZZZZZZZZZZZZIP \n";
#print $mystat-> _fullfill_db()," ---fullfill data\n";
my $ae = Archive::Extract->new(archive => '/usr/share/zabbix/externalscripts/BURST_DIR/ARCH_DIR/COUNTERS_141.101.186.2_29-04-2018/back_counters_1059_141.101.186.2_1524972147.gz',type => 'gz');
print $ae->extract(to=>'/usr/share/zabbix/externalscripts/BURST_DIR/ARCH_DIR/COUNTERS_141.101.186.2_29-04-2018');


my $fh = new IO::Zlib;

if ($fh->open("/usr/share/zabbix/externalscripts/BURST_DIR/ARCH_DIR/COUNTERS_141.101.186.2_29-04-2018/back_counters_1059_141.101.186.2_1524972147.gz", "rb")) {
#    print <$fh>;
    
    print Dumper($fh->getlines); 
    

    $fh->close;
}





my $tar = Archive::Tar->new();

# Add some files:
#$tar->add_files( '/usr/share/zabbix/externalscripts/BURST_DIR/COUNTER_DIR/counters_789_141.101.186.2' );
# */ fix syntax highlighing in stackoverflow.com

# Finished:
#$tar->write( '/usr/share/zabbix/externalscripts/BURST_DIR/ARCH_DIR/COUNTERS_141.101.186.2_29-04-2018/t.gz', COMPRESS_GZIP);



my $l=${\($tar->read('/usr/share/zabbix/externalscripts/BURST_DIR/ARCH_DIR/COUNTERS_141.101.186.2_30-04-2018/back_counters_1059_141.101.186.2_1525034399.tgz', COMPRESS_GZIP, {opt=>'extract'}))}->{'data'};
print $l;
#$tar->read("/usr/share/zabbix/externalscripts/BURST_DIR/ARCH_DIR/COUNTERS_141.101.186.2_30-04-2018/*.tgz", COMPRESS_GZIP);
#print Dumper($tar->get_files());