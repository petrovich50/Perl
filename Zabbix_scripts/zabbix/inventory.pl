#!/usr/bin/perl -w
# Inventory script to fullfill data about equipment by its  Template correspondence, IP, OID
# by Bandurin DV
#use 5.010;
#use 5.010;
use strict;
use warnings;
# use AutoLoader 'AUTOLOAD';
use JSON::RPC::Legacy::Client;
use Data::Dumper;
use Net::SNMP;


my $ip_in=shift || '85.115.254.42';
my $oid_in=shift || '.1.3.6.1.4.1.17409.1.3.1.4.0'; # serial NO by default 
my $temp_name= shift || "Amplifier Template";
my $url_api = 'http://141.101.186.250/zabbix/api_jsonrpc.php'; # 'http://141.101.186.250/zabbix/api_jsonrpc.php';
my $client = new JSON::RPC::Legacy::Client;
my $response;
my $authID;



my %inv_keys=("4"=>"alias","11"=>"asse_ag","28"=>"chassis","23"=>"conac","32"=>"conrac_number",
"47"=>"dae_hw_decomm","46"=>"dae_hw_expiry","45"=>"dae_hw_insall","44"=>"dae_hw_purchase",
"34"=>"deploymen_saus","14"=>"hardware","15"=>"hardware_full","39"=>"hos_nemask","38"=>"hos_neworks",
"40"=>"hos_rouer","30"=>"hw_arch","33"=>"insaller_name","24"=>"locaion","25"=>"locaion_la",
"26"=>"locaion_lon","12"=>"macaddress_a","13"=>"macaddress_b","29"=>"model","3"=>"name","27"=>"noes",
"41"=>"oob_ip","42"=>"oob_nemask","43"=>"oob_rouer","5"=>"os","6"=>"os_full","7"=>"os_shor",
"61"=>"poc_1_cell","58"=>"poc_1_email","57"=>"poc_1_name","63"=>"poc_1_noes","59"=>"poc_1_phone_a",
"60"=>"poc_1_phone_b","62"=>"poc_1_screen","68"=>"poc_2_cell","65"=>"poc_2_email","64"=>"poc_2_name",
"70"=>"poc_2_noes","66"=>"poc_2_phone_a","67"=>"poc_2_phone_b","69"=>"poc_2_screen","8"=>"serialno_a",
"9"=>"serialno_b","48"=>"sie_address_a","49"=>"sie_address_b","50"=>"sie_address_c","51"=>"sie_ciy",
"53"=>"sie_counry","56"=>"sie_noes","55"=>"sie_rack","52"=>"sie_sae","54"=>"sie_zip","16"=>"sofware",
"18"=>"sofware_app_a","19"=>"sofware_app_b","20"=>"sofware_app_c","21"=>"sofware_app_d",
"22"=>"sofware_app_e","17"=>"sofware_full","10"=>"tag","1"=>"ype","2"=>"ype_full","35"=>"url_a",
"36"=>"url_b","37"=>"url_c","31"=>"vendor");
    
    sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s }; # lead and last space trimming
    sub snmp_req { #oid, %hash hostid
#	use Exporter();
#	our @ISA = qw(Net::SNMP);
		my $ip;
	        my $oid;
	        my $port;
	        my $version;
	        my $community;
	        my $seconds='1';
	        my $boolean="false";
		my $in;
		my %out;
        
	if(($oid = shift) and ($in = shift)){

    	    while (my ($k,$v)=each %{$in}) {
		$ip=shift @{$v};
	        $port = shift @{$v};
	        $version="snmpv".shift (@{$v}) || "snmpv1"; 
	        $community = shift @{$v} || "public";


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
		   printf "ERROR: Failed to queue get request for host '%s': %s.",$session->hostname(), $session->error()," Or error ",$error,"\n";
	    	   $out{"$k"}= ${$session->error()}."ERROR: Failed to queue get request for host 1 '%s': %s.".${$session->hostname()};
    	    	  #  next;
    		}
		my $res = $session->get_request(
#				    -delay => $seconds,
				    -varbindlist => [$oid]
				    ) ;
		$out{"$k"}=exists $res->{$oid} ? trim ($res->{$oid}):"Nothing recieved due to timeout "; #"\n";		
		$session->close();
	    };
	} else {
	    return {};
	};
	    return %out;
	};






# auth key request 
my $json = {
    jsonrpc => "2.0",
    method => "user.login",
    params => {
    user => "bandurin",
    password => "76<Ltybc"
    },
    id => 1
    };

$response = $client->call($url_api, $json);
# Check if response was successful
die  unless $response->content->{'result'}; #die in silence without stdout loading
$authID = $response->content->{'result'}; # AUTH is determened here

 #  print Dumper($response->content->{'result'})."\n"; 



#looking for equipment Themplate ID.

    $json={
        jsonrpc=>"2.0",
        method=>"template.get",
        params=> {
            output=> "extend",
#            parentTemplateids=>"25256",
            filter=> {
#		 templateids=> $temp_id  
                host=>[$temp_name]                #var 3 TAKOYTO TEMPLATE
	    }
        },
        auth=> "$authID",
        id=> 2
    };

    $response = $client->call($url_api, $json);
    die  unless $response->content->{'result'};
    # print Dumper($response->content->{'result'}->[0])."\n";
    # print $response->content->{'result'}->[0]->{'name'},"\n";
    my $temp_id=$response->content->{'result'}->[0]->{'templateid'};
#   die "ffff";
    # print "Authentication successful. Temp ID: " . $temp_id . "\n";

# let us fetch inventory link by template id and oid
#  $script=~s/\.\///g ;
  my $s=$oid_in; #'hex_dec.pl'.'["{HOST.CONN}", "'."\""; #.$ip_in, $oid_in;
  
     $json={
	jsonrpc=> "2.0",
	method=> "item.get",
	params=> {
	    output=> "extend",
	    hostids=> $temp_id,
#	    filter=> {
#		templateid=> $temp_id
#		},
	    search=>{
		key_=>$s
		    },
	    sortfield=> "name"
	},
	auth=> $authID,
	id=> 1
       };
       
   $response = $client->call($url_api, $json);
   die  unless $response->content->{'result'}; 
   # print Dumper($response->content->{'result'})." uuu\n";
#   print $temp_id=$response->content->{'result'}->[0]->{'templateid'},"\n";
   my $inv_link=$response->content->{'result'}->[0]->{'inventory_link'};
  #print $inv_keys{$inv_link}."\n";
#   die "wfwwfer";


# hosts fetching connected to the equipment with this IP/ 
# With the same IP a port correspons to one hostid fetched
    $json={
        jsonrpc=> "2.0",
        method=> "host.get",
        params=> {
            output=> "extend",
            templateids => "$temp_id",
            filter=> {
#                ip=>$ip_in,  #IP
                type=>['1','4','6']
            },
            sortfield=>"hostid"
        },
        auth=> "$authID",
        id=> 3
    };
    $response = $client->call($url_api, $json);
    die unless $response->content->{'result'};
    # print Dumper($response->content->{'result'})." HOSTS \n";
#    die "wfwwfer";
    my @host_id;
    
    my $i=0;
    
    my $MMMMM=$response->content->{'result'};
     # print "HOST STRUCT ARE \n", Dumper(\@{$MMMMM}),"\n";
#    die "hoedeo";
    while (my $k= $response->content->{'result'}->[$i++]->{'hostid'}){push (@host_id, $k);}; #print $k." <-host ID\n";
    my $host_id = $response->content->{'result'}->[0]->{'hostid'};
#    my $community= $response->content->{'result'}->[0]->{'snmp_community'};
    # print "Authentication successful Host ID: " . $host_id . "\n";
#    print "Authentication successful Community: " . $community . "\n";

# looking for ports of hostids fetched
    $json = {
        jsonrpc => "2.0",
        method=> "hostinterface.get",
        params=> {
            output=> "extend",
            hostids=> [@host_id],
            filter=> {
                type=>"2"
            }
    
        },
        auth=>$authID,
        id=> 4
    };
    $response = $client->call($url_api, $json);

# Check if response was successful
    die  unless $response->content->{'result'};
    my @res_ports = $response->content->{'result'};
    # print Dumper (\@res_ports);
 #  die "wfwwfer";
    
# looking for snmp type, snmp_commuity and add them to result_hash. Key hostid
    my %version=("1"=>"1","4"=>"2","6"=>"3");  # 1-v1 4-v2 6 - v3 SNMP in item JSON response
    # print Dumper (sort keys %version)."vrsion \n";
    $json = {
        jsonrpc=> "2.0",
        method=> "item.get",
        params=> {
        output=>"extend",
        hostids=> [@host_id],
        selectHosts=>"true",
        filter=> {
        #    key_=> "system",
             type=>[keys %version] 
        },
        sortfield=> "name"
    },
        auth=> $authID,
        id=> 1
    };
    $response = $client->call($url_api, $json);

# Check if response was successful
    die unless $response->content->{'result'}; 
    my @res_snmpdata = $response->content->{'result'};
    $i=0; # zeroing counter


 #   print "\n\n snmp ".Dumper(\@res_snmpdata)." \n";
 #  die "wfwwfer";
 #   print "\n\n HOSTS ".Dumper(\@host_id)." \n";
    # print scalar @{[keys %{$res_snmpdata[0]->[10]}]}." prooperties per item \n";
    my %res_hash;
    foreach my $v (@host_id){
	$i=0;
	while( $i< scalar @{$res_snmpdata[0]}){  #
	    # print $i." ".$res_snmpdata[0]->[$i]->{'hostid'}."<>  $v"." \n";
	    if (exists ($res_snmpdata[0]->[$i]->{'hostid'}) and $res_snmpdata[0]->[$i]->{'hostid'}==$v) { 
		$res_hash{"$v"}=[$version{$res_snmpdata[0]->[$i]->{'type'}},$res_snmpdata[0]->[$i++]->{'snmp_community'}];
		# print Dumper (%res_hash)."\n";
		last; 
	    }else{
		$i++;
	    };       
       };
	$i=0;
	while( $i< scalar @{$res_ports[0]}){  #
	    if (exists $res_ports[0]->[$i]->{'hostid'} and $res_ports[0]->[$i]->{'hostid'}==$v) {  			 # the only hostid corresponds to a couple of port and ip. so no senes look for henceforth
		unshift $res_hash{"$v"},$res_ports[0]->[$i]->{'ip'},$res_ports[0]->[$i++]->{'port'};   	#ip, port, typesnmp, community
		# print Dumper (%res_hash)."\n";
		last; 
	    }else{
		$i++;
	    };       
       };

    };
#   print Dumper (\@host_id)." PORTS\n";
    undef @res_snmpdata; undef @host_id; undef @res_ports;  # flushing them..
    # print "\n\n RESULT HASH ".Dumper(\%res_hash)." \n";




my %hash_info =snmp_req ($oid_in,\%res_hash);
# print Dumper (\%hash_info)." info \n";
# die "jjj \n";
# FIELDS TO UPDATE HERE   
    
	while (my ($k,$v)=each(%hash_info)){

	     $json={
		jsonrpc=> "2.0",
		method=> "host.update",
		params=> {
		    hostid=> $k,
		    inventory_mode=> "0",
	    #	ID=>"5",
		    inventory=> {
			$inv_keys{$inv_link}=> $v
		    }
		},
		auth=> $authID,
		id=> 1
		};
	#	print Dumper($json)."\n";
		$response = $client->call($url_api, $json);
	#       print "\n\n trtrt  ".Dumper($response)." \n"; 
	       die "Hosts updating failed\n" unless $response->content->{'result'};        
	};
   #     print "\n\n trtrt  ".Dumper(\%{$response})." \n";

  #      print "\n\n trtrt  ".Dumper(\%ENV)." \n"; 
