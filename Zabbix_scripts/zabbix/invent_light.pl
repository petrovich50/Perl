#!/usr/bin/perl -w
# Inventory script to fullfill data about equipment by its  Template correspondence, IP, OID
# by Bandurin DV
#use 5.010;
#use 5.010;
#use strict;
use warnings;
# use AutoLoader 'AUTOLOAD';
use JSON::RPC::Legacy::Client;
use Data::Dumper;
use Net::SNMP;


my $ip_in=shift || '83.220.246.199';
my $oid_in=shift || '.1.3.6.1.4.1.17409.1.3.1.3.0';
my $port= shift || "161";
my $version=shift || "snmpv1";
my $c=shift || "public";
my $lan_ip= shift || "";

    sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s }; # lead and last space trimming
    sub snmp_req { #oid, %hash h osti
		my $ip=shift;
	        my $oid=shift;
	        my $port=shift;
	        my $version=shift;
	        my $community=shift;
	        my $seconds='1';
	        my $boolean="false";
		# my $in;
		# my %out;
        

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
		    return "No data recieved for IP:".$ip." OID ".$oid." PORT".$port. " Error is ".$error;
	    	   #return "ERROR to make session for %s. Error:".$error.;
    	    	  #  next;
    		}
		my $res = $session->get_request(
#				    -delay => $seconds,
				    -varbindlist => [$oid]
				    ) ;
		return exists $res->{$oid} ? trim ($res->{$oid}):"No data recieved due to timeout 1"; #"\n";		
		$session->close();

	};

my $r = snmp_req($lan_ip, $oid_in, "161", $version, $c) if $lan_ip; 
my $r1 = (defined $r and $r !~/^No/i) ? $r : snmp_req ($ip_in, $oid_in, $port, $version, $c);

 print $r1;
