#!/usr/bin/perl -w
# The script by Bandurin D.V. performs Usermacros of HOSTs to fullfill/ Stable v1.1
# Here the hosts are just phisical hosts
# Next it should be adopted to the HOST template usermacrosess of equipment varieties/ They are like serial, soft, model OIDS
use warnings;
# use AutoLoader 'AUTOLOAD';
use JSON::RPC::Legacy::Client;
use Data::Dumper;
use Net::SNMP;
#use DateTime;
use Data::Serializer;
# use Strorable;
use POSIX qw(strftime);
my $url_api = 'http://172.16.3.16/zabbix/api_jsonrpc.php';
my $client = new JSON::RPC::Legacy::Client;
my $authID;
my $timestamp = localtime(time);
# auth key request 
my $json = {
    jsonrpc => "2.0",
    method => "user.login",
    params => {
    user =>  'api',   # md5 and salt after
    password => 'V0ybnjhbyU2015' #
    },
    id => 1
    };

$response = $client->call($url_api, $json);
# Check if response was successful
die "Authentication failed\n" unless $response->content->{'result'};
$authID = $response->content->{'result'}; # AUTH is determened here

    sub macros_update {
#        global $authID,  $url_api, $client;
        my $hash=shift;
  #      print "dOOOOOOOOOOO",Dumper(%{$hash}),"\n";   
       while (my ($k,$v)=each %{$hash}){
        my $js={
            "jsonrpc"=> "2.0",
             "method"=> "host.update",
                "params"=> {
                "hostid"=> $k,
		"inventory_mode"=> "1", # automatic field focusingA
                "macros" =>[@{$v}]
                },
            "auth"=> $authID,
            "id"=> 1
           };
        
           
         #  print "djepkwdwend",Dumper($js),"\n";    
           my $response = $client->call($url_api, $js);
#           print Dumper($response),"\n";
           return  "Authentication failed1\n" unless $response->content->{'result'};
          }; 
           return 1;
    };

   $json = {
        jsonrpc => "2.0",
        method=> "hostinterface.get",
        params=> {
            output=> "extend"    
        },
        auth=>$authID,
        id=> 1
    };
    $response = $client->call($url_api, $json);

# Check if response was successful
die "Authentication failed\n" unless $response->content->{'result'};
    my $i=0;
    my $h={};
#    print Dumper($response->content->{'result'}),"\n";
    while (my $k= $response->content->{'result'}->[$i]){
#        print Dumper($k),"\n",$i,"\n";
        my $key=$k->{'type'}; #interface type here
        my $val= $k->{'port'}; # interface type port here
        my $idhost=$k->{'hostid'}; #host id
        
        my $ip=$k->{'ip'}; #interface ip here
        my $ip_macro='{$HOST_IP}'; # ip macros variable defined here
        
        if ($key=='1') {
            $key='{$HOST_PORT}';  # host interface port macros variable defined here
         } elsif($key=='2') {
             $key='{$SNMP_PORT}'; # host snmp port macros variable defined here
        }else{
            $key="";
            $val="";
        };
        
                 my @keys=(); 
         foreach my $e (@{$h{$idhost}}){
             push @keys, values %{$e};             
         }
         my $pattern=$key;
         $pattern =~ s/([\\'\{}\$])/\\$1/g;  # supple escapes into regexp pattern
         @keys=grep /$pattern/i, @keys;
         if (my $t=scalar (@keys)){
           $key=~s/\}/$t\}/;	
         };

       
        push (@{$h{$idhost}}, {"macro" => $key, "value" => $val}); # add Host and snmp macroses
        push (@{$h{$idhost}}, {"macro" => $ip_macro, "value" => $ip}); # add host_ip / And we could add any other user macroses here
        #print $idhost," rr=> ",Dumper ($h[$idhost]),"\n";
      $i++;
    }; 
   
   
    # now let us get rid of repeated elements
    # but key cannot be an assotiated array ;(
    # so let serialize it to a string!! ))
    my $obj = Data::Serializer->new();

    # my $obj = Data::Serializer->new(    # to serialize more completly
                          # serializer => 'Storable',
                          # digester   => 'MD5',
                          # cipher     => 'DES',
                          # secret     => 'my secret',
                          # compress   => 1,
                        # );
                       # print " OOOO ",Dumper (%h),"\n";
    while (my ($k, $v)=each(%h)){
        my $tmp={};
        @{$v} = map ($obj->raw_serialize($_), @{$v});
        @{$v} = grep {! $tmp->{$_}++} @{$v}; 
        @{$v} = map ($obj->raw_deserialize($_), @{$v});

        
      # print $k,"=>",Dumper ($v);
    };
      if ( (my $flag =macros_update(\%h)) =="1"){
       print "Last host usermacroses update performed from ".$timestamp." up to ",$timestamp=localtime(time);
      }else{
	print $flag;
      }
      
      # here must be throw catching next ))
