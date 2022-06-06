#!/usr/bin/perl -w
use Net::SNMP;
use strict;
use warnings;
# when leaving the console clear the screen to increase privacy
    my $ip   = shift || "";
    my $oid  = shift || "";
    my $port = (shift || "161");
    my $version="snmpv1";
    my $community = "public";
    my $seconds="3";
    if($ip && $oid){
     sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s }; # lead and last space trimming
     my ($session, $error) = Net::SNMP->session(
                           -hostname      => $ip,
                           -port          => $port,
                           -version       => $version,
#			    -delay           => $seconds,
#                           [-localaddr     => $localaddr,]
#                           [-localport     => $localport,]
#                           [-nonblocking   => $boolean,]
                            -community     => $community    # v1/v2c
                            );
	if (!defined $session) {
          printf "ERROR %s.", $error;
          exit 1;
       }
	 my $res = $session->get_request(-varbindlist => [ $oid]);
      if (!defined $res) {
         printf "ERROR: Failed to queue get request for host '%s': %s.",$session->hostname(), $session->error()." \n";
	 exit 1;
      }
	#foreach (keys %{$res}){

	    print trim($res->{$oid}); #," ",$ip; #," ",$port," ",$oid;
#	    print join("",map(hex(split(" ","0x53 0x43 0x33 0x31 0x30 0x37 0x39 0x37 0x2E 0x30 0x30 0x31 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00")));
	#}
#	print $res,"\n";
#	open (MYFILE, '>> /usr/lib/zabbix/externalscripts/data.txt'); print MYFILE trim($res->{$oid}); close (MYFILE);
	$session->close();
    }else{
	print "IP or OID is not defined";
    }
#    print "test a";