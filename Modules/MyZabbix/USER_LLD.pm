package MyZabbix::USER_LLD;

=pod

=head1 NAME

USER_LLD - performed by Bandurin D.V. bandurin@gmail.com
Module is to supply one with functionality for User LLD problem, external checks, multiinterfaces, and some other usefull stuff in Zabbix
=head1 SYNOPSIS

  my $object = USER_LLD->new(
      foo  => 'bar',
      flag => 1,
  );
  
  $object->dummy;

=head1 DESCRIPTION

The author was too lazy to write a description.

=head1 METHODS

=cut

use 5.010;
use strict;
use warnings;
#use JSON::RPC::Legacy::Client;
use Data::Dumper;
use Net::SNMP;
our $VERSION = '0.01';

=pod

=head2 new
  
  
  my $object = USER_LLD->new(
      foo => 'bar',
  );

The C<new> constructor lets you create a new B<USER_LLD> object.

So no big surprises there...

Returns a new B<USER_LLD> or dies on error.

=cut

sub new {
    my $class = shift;
    my $self  = bless { @_ }, $class;
    return $self;
};

=pod

=head2 dummy

This method does something... apparently.

=cut



sub _set_ini {
    my $self = shift;

    # Do something here

    return 1;
};

# Just trim sub to remove starting and tail spaces of a string
sub  _trim { my $self = shift; my $s = shift; $s =~ s/^\s{1,}|\s{1,}$//g; return $s };

# sub to return snmptable hash ref of {full.view.ifindexe=>values} or scalar string with error
sub _get_snmp_table {
	my $self = shift;
                my $ip=shift; #obligitaory
                my $oid=shift; #obligatory baseoid 
                my $port=shift || '161'; #161 deafalt
                my $version=shift||'v1'; #snmp version 1
                my $community=shift||'public'; #community public
                my $seconds='1';
                # my $res={};
               # my $boolean="false";
                # my $in;
                # my %out;


                my ($session, $error) = Net::SNMP->session(
                           -hostname      => $ip,
                           -port          => $port,
                           -version       => $version,
#                           -delay           => $seconds,
#                           [-localaddr     => $localaddr,]
#                           [-localport     => $localport,]
#                           -nonblocking   => $boolean,
			    -translate   => [-octetstring => 0],
                            -community     => $community    # v1/v2c
                            );
                # print "$ip $port $version $community $oid","\n";
#               print Dumper($session)."\n";

                if ( !defined $session) {
                 #  printAf "ERROR: Failed to queue get request for host '%s': %s.",$session->hostname(), $session->error()," Or error ",$error,"\n";
                    return "Recieved data are: IP:".$ip." OID ".$oid." PORT".$port. ' Cannot initiate snmpsession. Error:'.$error;
                   #return "ERROR to make session for %s. Error:".$error.;
                  #  next;
                }
                my $res = $session->get_table(
#                                   -delay => $seconds,
                                    -baseoid    => $oid
                                    ) ;

	#$session->close();			
        if(! defined $res){       
	    return   "Cannot get snmp_table. Error:".$session->error(); #exists $res->{$oid} ? trim ($res->{$oid}):"No data recieved due to timeout 1"; #"\n";
	}else{
	    return  $res; #exists $res->{$oid} ? trim ($res->{$oid}):"No data recieved due to timeout 1"; #"\n";
	}
        $session->close();

};

#sub to return scalar value for snmpget or scalar with an error
sub _get_snmp_res {
	my $self = shift;
                my $ip=shift;
                my $oid=shift;
                my $port=shift;
                my $version=shift;
                my $community=shift;
                my $seconds='2';
                my $boolean="false";
	# print "ip ",$ip, "  port " ,$port,"  oid ", $oid," v",$version," comm ",$community,"\n";
                my ($session, $error) = Net::SNMP->session(
                           -hostname      => $ip,
                           -port          => $port,
                           -version       => $version,
                           -timeout       => $seconds,
                           -retries       => 1,
#                           -delay           => $seconds,
#                           -localaddr     => $ip,
#                           -localport     => $port,
#                           -nonblocking   => $boolean,
			    -translate   => [-octetstring => 0],
                            -community     => $community    # v1/v2c
                            );
                # print "$ip $port $version $community $oid","\n";
#               print Dumper($session)."\n";

                if ( !defined $session) {
                 #  printf "ERROR: Failed to queue get request for host '%s': %s.",$session->hostname(), $session->error()," Or error ",$error,"\n";
                   return 'Snmp get value session error: '.$error.' IP: '.$ip.' Port: '.$port;
                   #return "";
                  #  next;
                }else{
                   my $res = $session->get_request(
#                           -delay => $seconds,
                            -varbindlist => [$oid]
                            ) ;
		my $file_log='/usr/share/zabbix/externalscripts/file_log.log';
#		open(my $fh,'>>', $file_log);
#		print $fh $res->{$oid}." = $ip:$port $oid \n";
#		close  $fh;
	    #$session->close();			

                   return  (!defined $res or !keys %{$res}) ? 'Cannot get Snmp value. error: '.$session->error().' IP: '.$ip.' Port: '.$port : $res->{$oid};
                   $session->close();
                };

};

#sub to return snmpget scalar for multi-interface nodes or an error if no data recieved. Input $hashref of pairs {'ip1'=>'port1', 'ip2=port2',...}
sub get_snmp_multi {	#hashef us input
	    # One may overload with inherited class method. Child ODclass method must return hash: index => value though
	my $self = shift;
                my $interf=shift; #type of hashreferance {ip => port}. obligatory
                my $oid=shift; #obligatory baseoid for all interfaces inputed
                my $version=shift||'v1'; #snmp version 1 by default
                my $community=shift||'public'; #community public by default
	my $res = 'No interfaces supplied.error'; 
	if (ref($interf) eq "HASH"){
	    while (my ($ip, $port) = each %{$interf}){
		# print $ip," ", $port, "\n";
	     $res=$self->_get_snmp_res($ip, $oid, $port, $version, $community);
	     last if $res !~m/error/; #
	    }
	    return $res;
	}else{
	    return $res;
	}
    #return 1;	
};

#sub to return snmptableget hashref of {ifindexes => value,..} where ifindexes without starting decimal-dotted prefix 1.3.233.323.23.{ifindex}. For single interfaces
sub indexdata_lld {  # method that form input data for lld.it returns hash without_baseoid_index => value
	    # one may overload with inherited class method. Child class method must return hash: index => value
	my $self = shift;
                my $ip=shift; #obligitory
                my $oid=shift; #obligatory baseoid 
                my $port=shift || '161'; #161 deafalt
                my $version=shift||'v1'; #snmp version 1
                my $community=shift||'public'; #community public
	my $hash = $self->_get_snmp_table($ip, $oid, $port, $version, $community);
	if (ref($hash) eq "HASH"){
	    return \%{{map {${\(eval{my $t=$_; $t=~s/$oid\.//; return $t;})} => $hash->{$_} } keys %{$hash}}}; # get rid of oidbase and leave only oidindex/ OIDINDEX=>SNMPVALUE
	}else{
	    return $hash;
	}
    #return 1;
};

#sub returns snmptableget hashref of {ifindexes=>value,..} for multiinterface nodes. ifindexes without starting deciaml-dotted prefixes
sub indexdata_lld_multi {  # method that form input data for lld .it recieve multiinterface inpгt and returns hash without_baseoid_index => value for whatever of the interfaces reachable.
	    # One may overload with inherited class method. Child class method must return hash: index => value though
	my $self = shift;
                my $interfaces=shift; #type of hashreferance {ip => port}. obligatory
                my $oid=shift; #obligatory baseoid for all interfaces inputed
                my $version=shift||'v1'; #snmp version 1 by default
                my $community=shift||'public'; #community public by default
	my $hash = 'No interfaces supplied. error'; 
	if (ref($interfaces) eq "HASH"){
	    while (my ($ip, $port) = each %{$interfaces}){
	     $hash=$self->indexdata_lld($ip, $oid, $port, $version, $community);
	     last if ref($hash) eq "HASH"; #
	    }
	    return $hash; # if $hash is hash it returns first hash recieved. if no it returns snmp get error message here
	}else{
	    return $hash;
	}
    #return 1;
};

#sub returns multiinterface USER defineda LLD data for ZAbbiz. Select external-check option in LLD interface
sub zabbix_user_lld {  # it returns formated data to satisfy zabbix user lld requirements.
        # one may overload with inherited class method
        # by default indexname = 'USERINDEX', valuename ='USERVALUE'
    my $self = shift;
    my $userindex_hash = shift|| ''; # obligatory input one arg of hash type
    my $userindex= shift || 'USERINDEX'; #name of userindex
    my $uservalue=shift || 'USERVALUE';  #name of uservalue
    my $formula=shift || 'f_as_is';  #name of uservalue
    my $first=1;
    $formula = $self->can($formula) ? $formula : 'f_as_is';
    print "{";
    print "\"data\":[";
    if (ref($userindex_hash) eq "HASH"){
        while (my ($index, $val)= each %{$userindex_hash} ){
            print "," if not $first;
            $first = 0;
            $val = $self->$formula($val); 
            print "{";
            print "\"{#$userindex}\":\"$index\",";
            print "\"{#$uservalue}\":\"$val\"";
            print "}";

        }
    }
    print "]";
    print "}";
 return "";
};

#section for formulas. On returning by snmpget data needed to be recalculated one may write sub formula here and use it in ones's code in format $self->$formula($inp_args) where #formula='formula name';
sub f_ekinop_rtx {
    my $self = shift;
    my $s=shift || '1'; #obligatory, numeric
 return sprintf("%.4f",(10*(log($s)/log(10)) - 40));
};
sub f_ekinop_upl {
    my $self = shift;
    my $v = shift;
    return ($v lt 32768) ? ($v/100) : (($v-65535)/100); #obligatory, numeric
 # return sprintf("%.4f",(10*(log($v)/log(10)) - 40));
};

sub f_as_is {
    my $self = shift;
    my $s=shift; #obligatory, numeric
 return $s;
};

sub f_ekinop_cport {
  my $self=shift;
  return $1 if shift =~m/(s\d{1,2}-client\d{1,2})/si;
# my $l=shift;
# $l=hex $l;
# return hex $l;
};

sub f_sfp_to_line{
   my $self=shift;
   my $value=shift;
   my $infter=shift; #||{'192.168.100.101' => '161', '192.168.100.15' => '161'};
   my $ind=shift;
   my $ver=shift||'1'; #'2'; #snmp version 1 by default
   my $com=shift||'public'; #'alsitec'; #community public by default
   my $des ='.1.3.6.1.2.1.2.2.1.2';
   my $alias='.1.3.6.1.2.1.31.1.1.1.18'; 
   my %inf1=%{$infter}; 
   my $h_in={};   
   my $key1='5.5.253.75 '; #'83.220.234.94 ';
   # $inf1{$key1}='1602' if $#{[keys %inf1]}==0;
   # $inf1={'192.168.100.101' => '161'};
    # print("\n---inf1 before--\n",Dumper($infter)); 
    if ($value=~/noSuch/){
        $h_in=$self->indexdata_lld_multi(\%inf1, $des, $ver, $com);
          # $h_in=$self->_get_snmp_table($inf1, $des, $ver, $com);   
       # print("\n---inf1 after--\n",Dumper($inf1));
       $ind=$1 if $ind =~/\.(\d+)$/ ;
       # print "\n---has in--\n", Dumper($h_in),"\n-------\n";
       my @l= map {eval{return $1 if $h_in->{$_}=~/Line Interface[\s\t]+(\d+)/}} grep{$_=~m/$ind/} keys %{$h_in};
       # print Dumper(@l),"\n---L--\n";
       $ind=(defined $l[0] and $l[0]) ? ${\[map {eval{return $_}} grep{$h_in->{$_}=~/SFP Interface[\s\t]+$l[0]$/} keys %{$h_in}]}->[0] : "$ind";
       # print Dumper($ind),"\n---ind--\n";
       # print Dumper(\%inf1),"\n---inpp hash--\n";
       # print ref($inf1) eq "HASH";
       # print "\n---true--\n";
       return ${\($self->get_snmp_multi($infter, $alias.'.'.$ind, $ver, $com))};
       #my $l= map {$h_in{$_}} grep{~m/$ind/} keys %{$h_in};
       
       # return Dumper($l[0]);  
   }else{
      return $value;
   }
 };

sub f_mw_to_dbm{
    my $self=shift;
    my $pmW=shift;
    return ${\(printf("%.2f",10 * (log(0.0001 * $pmW )/log(10))))};
};

1;

=pod

=head1 SUPPORT

No support is available

=head1 AUTHOR

Copyright 2012 Anonymous.

=cut
