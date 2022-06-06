#!/usr/bin/perl
# Inventory script to fullfill data about equipment by its  Template correspondence, IP, OID
# by Bandurin DV
#use 5.010;
#use 5.010;
#use strict;
#use warnings;
# use AutoLoader 'AUTOLOAD';
#this script to do something
use JSON::RPC::Legacy::Client;
use Data::Dumper;
use Net::SNMP;


my $ip_in=shift || '192.168.100.9';
my $oid_mant=shift || '.1.3.6.1.4.1.4515.1.1.15.2.1.1.3.1360640';
my $oid_exp=shift || '.1.3.6.1.4.1.4515.1.1.15.2.1.1.4.1360640';
my $port= shift || "161";
my $version=shift || "snmpv2";
my $c=shift || "read";

    sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s }; # lead and last space trimming
    sub snmp_req { #oid, %hash h osti
		my $ip=shift;
	        my $oid_m=shift;
	        my $oid_e=shift;
	        my $port=shift;
	        my $version=shift;
	        my $community=shift;
	        my $seconds='1';
	        my $boolean="false";
		# my $in;
		# my %out;
        
                my @oid= ($oid_m, $oid_e);
    		my ($session, $error) = Net::SNMP->session(
                           -hostname      => $ip,
                           -port          => $port,
                           -version       => $version,
#			    -delay           => $seconds,
#                           [-localaddr     => $localaddr,]
#                           [-localport     => $localport,]
#			    -nonblocking   => $boolean,
                            -community     => $community    # v1/v2c
                            );
		# print "$ip $port $version $community $oid","\n";
#		print Dumper($session)."\n";

		if ( !defined $session) {
		 #  printf "ERROR: Failed to queue get request for host '%s': %s.",$session->hostname(), $session->error()," Or error ",$error,"\n";
		    return "Recieved data are: IP:".$ip."  PORT".$port. " Session Error is ".$error;
	    	   #return "ERROR to make session for %s. Error:".$error.;
    	    	  #  next;
    		}
		my $res = $session->get_request(
#				    -delay => $seconds,
				    -varbindlist => \@oid
				    ) ;
		return $res;# ? trim ($res->{$oid}):"No data recieved due to timeout 1"; #"\n";		
		$session->close();

	};

 my $res1=snmp_req ($ip_in, $oid_mant,$oid_exp, $port, $version, $c);
 my $fecc= $res1->{$oid_mant}*10**$res1->{$oid_exp};
 my $a=abs $res1->{$oid_exp};
 my $format= $res1->{$oid_exp} < 0? '%.'.$a.'f' : '%d';
 printf  $format,  $fecc;
