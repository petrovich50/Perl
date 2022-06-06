#!/usr/bin/perl
# by Bandurin D.V.
{
    package BURST;

=pod

=head1 BURST

BURST - im to lazy to write abstract)

=head1 SYNOPSIS

  my $object = BURST->new(
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
use Time::Local;
use Data::Dumper;
use POSIX 'strftime';
our $VERSION = '0.01';

=pod

=head2 new

  my $object = BURST->new(
      foo => 'bar',
  );

The C<new> constructor lets you create a new B<BURST> object.

So no big surprises there...

Returns a new B<BURST> or dies on error.

=cut

sub new {
    my $class = shift;
    my $self  = bless { @_ }, $class;
    return $self;
}
=head2 initial

Initial private class variables

If _month specified date range will be ignored
number _month ="" ("", '2017-09-18 01:50:01', '2017-09-18 01:50:01',"0.5","/tmp/burst.log","600") if one wishs specify date range or vice versa ("2", "","","0.5","/tmp/burst.log","600")
All the current month data will be taken into account if a string 'current' specified instead of month number.

Input args:
["number _month"] , ['2017-09-18 01:50:01', '2017-09-18 01:50:01'],[percent],[_logfile],[delta_time], [datatype], [timeprecision],[lostdata_treshold]
date
2017-09-18 01:50:01

=cut

sub initial {
    my $self = shift;
    return "no input data supplied" if !@_;	
    $self->{_month}=$1 if $_[0] =~/^[\t\s]{0,}([1-9]{1}|10|11|12)[\t\s]{0,}$/;
    $self->{_current}=$1 if $_[0] =~/^[\t\s]{0,}(current)[\t\s]{0,}$/;	
    $self->{_date_beg}=timelocal($7,$6,$5,$4,$3-1,$2) if $_[1] =~m/((\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2}))[+:\d\s]{0,}/;
    $self->{_date_finish}=timelocal($7,$6,$5,$4,$3-1,$2) if $_[2] =~m/((\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2}))[+:\d\s]{0,}/;
    $self->{_percentile}=$_[3] || "0.05"; # default 5%
    $self->{_logfile}=$_[4] || "/tmp/burst.log"; #  default "/tmp/burst.log"
    $self->{_deltatime}=$_[5] || "300"; # in sec defalt 600
    $self->{_datatype}=$_[6] || "input"; # defalt output
    $self->{_timeprecision}=$_[7] || 2; # 2-5 in sec, defalt 1 - exact precision
    $self->{_lost_treshold}=$_[8] || 0.1; # lost data permited in % /100
    $self->{_lostdate}="";
    # print "\n SELF  ",Dumper $self,"\n";
    if (exists $self->{_month}){
     return "month";
    }elsif(exists $self->{_current}){
     return "month current";	
    }elsif(exists $self->{_date_beg} and exists $self->{_date_finish} and ($self->{_date_finish}-$self->{_date_beg}) > 0){
     return "period $self->{_date_beg} - $self->{_date_finish}";
    }else{
     return "no month or date range supplied, dateend < datebegin or wrong formated";
    } 
    
    # Do something here

    # return 1;
}


=pod

=head2 _logparse

This method translates a burstlog into hash arays of format:
{input=> {timestamp => [value, timeinrfc3339], }}
{output=> {timestamp => [value, timeinrfc3339], }}


It returns hashref of such a structure:
{timestamp => [value, timeinrfc3339], }
according to output or input datatype was selected

Input logfile data format as follows:
2017-09-17 02:30:01+04:00 output, 4425614164715655
NB If the precision comparision (look _statvalidity) is off we get rid of extra timing seconds in originating data set by setting them 0.

=cut

sub _logparse {
    my $self = shift;
        my %res=();
        my $ss=0;
        # print $self->{_logfile};
    open(my $fh, "<", "$self->{_logfile}") or return "no logfile specified"; # return empty if it file with total path
	while (<$fh>){
	#print $_."\n";
	#my $time = timelocal($7,$6,$5,$4,$3-1,$2); https://stackoverflow.com/questions/7726514/how-to-convert-text-date-to-timestamp
	    chomp $_;        
	    $_=~m/^((\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})[+:\d]+)[\s]+(input|output),\s*([\d\D]+)/;
	    # $res{$8}={} if ! exists $res{$8};
	    if ($self->{_timeprecision}){$ss = $7;} else {$ss = 0;};  # if time precised (_timeprecision not specified) $7 set to 0. that is to get rid of seconds due to crontab bash_script timing.
	    $res{$8}->{${\timelocal($ss,$6,$5,$4,$3-1,$2)}}=[$9, $1] if $8 eq qq($self->{_datatype});  
	};
    close $fh;
    # print "\n records ", $#{\[values $res{$self->{_datatype}}]} +1 , "\n";
    # print Dumper $res{$self->{_datatype}};
    return $res{$self->{_datatype}}; 
}

=pod

=head2 _statvalidity

This method checks validity of the data recieved from private _logparse in format timestamp => [valid_value, date]
It returns an array of actual valid data that are in the valid date range specified. The array format:
 {timestamp_valid => valid_value, }
timelocal( $sec, $min, $hour, $mday, $mon, $year );
_timeprecision precision in second is due to timing in recording to burst logffile by the snmpburst script.
THe default _timeprecision = 1 means absolute exact coincidence. The precision comparision is off.
If _timeprecision is gt 2 the precision comparision is on.
The precision comparision (boundary locking) means the $time_end(or $time_beg) being between 2 neghbour timestamp data boundaries 
is assigned to that one which closer than _timeprecision. If not so $time_end (and $time_beg) is assigned to the lower
 (and to the upper) boundary.

=cut

sub _statvalidity {
    my $self = shift;
    my ($timeperiod, $time_beg, $time_end, $old, $precision, $lostdata, $data_treshold) = (0, 0, 0, 0, 1, 0, 0.05);
    my @actualdata = ();
    my @lost = ();
    my %reshash = ();
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =localtime(time);
    # my $i=0;
    my $v=$self->_logparse();
    %reshash = (ref($v) eq "HASH" ) ? shift || %{$v} : return "no data from _statvalidity: $v";
    # %reshash = shift || %{$self->_logparse()};
    $precision = $self->{_timeprecision} if $self->{_timeprecision};
    
    
    foreach (@{[sort {$a <=> $b} keys %reshash]}){ # let's make list in an ascending order!

	if (exists $self->{_month}) {
	 $time_beg = $_ if abs ($_ - timelocal(0,0,0,1,$self->{_month}-1,18)) < $precision;
	 $time_end = $_ if abs ($_ - timelocal(0,0,0,1,$self->{_month},18)) < $precision;
	 
	}elsif(exists $self->{_current}) { 
	 $self->{_date_beg} = timelocal(0,0,0,1,$mon,$year);
	 $self->{_date_finish} = timelocal($sec,$min,$hour,$mday,$mon,$year);
	 $time_beg = $_ if (abs ($_ - $self->{_date_beg}) <= $precision ); # in precision range of $_ - exact case
	 $time_end = $_ if $old and (abs ($_ - $self->{_date_finish}) < $precision ); # in precision range of $__ - exact case
	 # print "\n current do $precision inibeg $self->{_date_beg} iniend $self->{_date_finish} curr $_ old $old beg_recieved $time_beg \n" if $i<10;		 
	 $time_beg = $_ if ($old < $self->{_date_beg}) and ($_ > $self->{_date_beg}) and (abs($_- $self->{_date_beg}) >= $precision) ;  # if between time beg sets to upper value of 2 neigbour dates
	 $time_end = $old if $old and ($old < $self->{_date_finish}) and ($_ > $self->{_date_finish}) and (abs ($_ - $self->{_date_finish}) >= $precision ); # if betwenn time end sets to lower value of 2 neigbour dates		 
	 
	 # print "\n  currentposl $precision ini $self->{_date_beg}  curr $_ old $old beg_recieved $time_beg \n" if $i<10;		 
                 $time_end = $_ if $old and ($old < $self->{_date_finish}) and ($_ < $self->{_date_finish}) and (abs ($_ - $self->{_date_finish}) >= $precision ); # if gt   time end sets to upper value of 2 neigbour dates
	 
	}elsif(exists $self->{_date_beg} and exists $self->{_date_finish}){
	 $time_beg = $_ if (abs ($_ - $self->{_date_beg}) <= $precision ); # in precision range of $_ - exact case
	 $time_end = $_ if $old and (abs ($_ - $self->{_date_finish}) < $precision ); # in precision range of $__ - exact case
	 # print "\n datrange do $precision inibeg $self->{_date_beg} iniend $self->{_date_finish} curr $_ old $old beg_recieved $time_beg \n" if $i<10;		 
	 $time_beg = $_ if ($old < $self->{_date_beg}) and ($_ > $self->{_date_beg}) and (abs($_- $self->{_date_beg}) >= $precision) ;  # if between time beg sets to upper value of 2 neigbour dates
	 $time_end = $old if $old and ($old < $self->{_date_finish}) and ($_ > $self->{_date_finish}) and (abs ($_ - $self->{_date_finish}) >= $precision ); # if betwenn time end sets to lower value of 2 neigbour dates		 
	 
	 # print "\n datrange posl $precision ini $self->{_date_beg}  curr $_ old $old beg_recieved $time_beg \n" if $i<10;		 
                 $time_end = $_ if $old and ($old < $self->{_date_finish}) and ($_ < $self->{_date_finish}) and (abs ($_ - $self->{_date_finish}) >= $precision ); # if gt   time end sets to upper value of 2 neigbour dates
	}else{
	  return "no date range initialized in the method initial()";
	};
	
     $old=$_;
     # $i++;
    };
    # print "\n begin ",$time_beg," end ",$time_end,"\n";
    return "no or not full data for the month or date range specified" if ! $time_beg or ! $time_end;
    $self->{period_start}=POSIX::strftime("%Y-%m-%d %H:%M:%S",localtime($time_beg));
    $self->{period_end}=POSIX::strftime("%Y-%m-%d %H:%M:%S",localtime($time_end));;
    
    # print  "\n do stsvalidity", scalar @{[keys %reshash]},"\n";
    # print "\n do stsvalidity", scalar @{[keys %reshash]},"\n";
    
    @actualdata = grep {($reshash{$_}->[0] =~/^\d+$/) and ($_ >= $time_beg) and ($_ <= $time_end)} sort {$a <=> $b} keys %reshash;

    @lost = @{[grep {($reshash{$_}->[0] =~/\D+/) and ($_ >= $time_beg) and ($_ <= $time_end)} sort {$a <=> $b} keys %reshash]}; #NONE DIGITE. lost due to none digite data
    $lostdata = scalar @lost;

    $lostdata = $lostdata + (int (($time_end - $time_beg)/$self->{_deltatime}) - $#actualdata); #NOT ALL DATA. lost due to no data at every time interval = deltatime
    $self->{lostdate} = join " : ", map {POSIX::strftime("%Y-%m-%d %H:%M:%S",localtime($_))} @lost;
    # print "\n posle", scalar @actualdata,"\n";
    # print Dumper \@actualdata,"\n $lostdata \n",ref(\%reshash);
    $data_treshold = $self->{_lost_treshold} if $self->{_lost_treshold};
    return "no valid data recieved due to big data lost gt $data_treshold" if ($lostdata / ($lostdata + $#actualdata+1)) >= $data_treshold; 
    my $res= \%{{map {$_=> $reshash{$_}->[0]} @actualdata}};
    # print Dumper $res,"\n ffff";	
        return $res;  #hash of timestamp => value
    
}


=head2 bandwidth_rate



This method recieves actual valid data from _statvalidity method
It returns bandidth rates as a hash
{timestamp => ratevalue, }
in simple case approximation, that is ratevalue set to (delta value/ delta time min)
NB timestamp is the upper one in an every delta time range
NB We get pass by data after which counter was droped down by snmpmanagement protocol in oid ifHCInOctets
Quote from snmp OID ifHCInOctets description:
Discontinuities in the value of this counter can occur at
re-initialization of the management system, and at other
times as indicated by the value of
ifCounterDiscontinuityTime.


=cut

sub _bandwidth_rate {
    my $self = shift;
    my $valid_data = {};
    my ($old, $value_old) = (0, 0);
    my %rate_values = ();
    my $v=$self->_statvalidity();
    $valid_data = (ref($v) eq "HASH" ) ? shift || $v : return "no data from _statvalidity: $v";
    # print "\n inpin _bandwidth_rate \n",Dumper %{$valid_data}, "\n __endinp\n";
    # print "\n do _bandwidth_rate number \n",scalar @{[sort {$a <=> $b} keys $valid_data]}, "\n __endinp\n";
     if (ref($valid_data) eq "HASH" ){
      open (my $ff, ">", './log_rate.txt');
      foreach (@{[sort {$a <=> $b} keys $valid_data]}){  # body of approximation / We use here simple line  approximation delta value/ delta time 
        if (exists $valid_data->{$old}){
         # $value_old=0 if ($valid_data->{$old} > $valid_data->{$_});
         if ($valid_data->{$old} > $valid_data->{$_} ){  # here we pass by
             $old=$_; 
             $value_old=$valid_data->{$_};
             $self->{lostdate} .= " : ". ${\POSIX::strftime("%Y-%m-%d %H:%M:%S",localtime($_))};
             next;
             };
         $rate_values{$_} = (($valid_data->{$_}-$value_old) /($_ - $old)); #*(8/1000000000);
         print $ff POSIX::strftime("%d.%m.%Y %H:%M:%S",localtime($_)),";", 8*$rate_values{$_},"\n";
        };
        
            $old=$_; 
            $value_old=$valid_data->{$_};	
      };
      close $ff;
      # continue{
       # $rate_values{$_} = (($valid_data->{$_}-$value_old) / ($_ - $old)); #*(8/1000000000);
       # };
     }else{
      return $valid_data;
     };
        # print "\n posle_bandwidth_rate number \n",scalar @{[sort {$a <=> $b} keys %rate_values]}, "\n __endinp\n";
    return \%rate_values;
}

=head2 burst_rate

This method returns burst rate in accordance to method of  https://www.atlex.ru/baza-znanij/chavo/chto-takoe-burstable-billing/
{input => {timeinrfc3339 => burst_rate, output => {timeinrfc3339 => burst_rate}}}



=cut

sub burst {
    my $self = shift;
    my $rate = {};
    my $v=$self->_bandwidth_rate();
    my $fact = 8; #/1000000000
    # print "\n 111111 ",$self->{period_start};
    # print "\n 2222222 ",$self->{period_end};
        $rate= (ref($v) eq "HASH" ) ? shift || $v : return "no data from _bandwidth_rate: $v";
        if (ref($rate) eq "HASH" ) {
          my @burst_rate = sort {$b <=> $a} values %{$rate}; # lets make descending list
          # print Dumper "\n burst list here \n",\@burst_rate,"\n";
          my $countall=$#burst_rate + 1;
          # print "\n befor burst list here \n","\n", scalar @burst_rate, "\n";
          while ((($#burst_rate+1)/$countall) > (1-$self->{_percentile})){shift @burst_rate;};
          # print "\n burst list here \n","\n ", scalar @burst_rate, " \n";
          return $fact * shift @burst_rate;  #octet/Gbite factoring here
        }else{
         return "no input data recieved due to". $rate;
        };
        
        
    # Do something here

print 	
}
sub getvalidperiod {
    my $self = shift;
    my @list= ($self->{period_start},$self->{period_end}) ;
        # print @list;
        return $self->{period_start}."-".$self->{period_end} if exists $self->{period_start} and exists $self->{period_end};
        return "no valid data datetime period defined ";
        
        
    # Do something here

    
}


sub getlostdate {
    my $self = shift;
    
        return " $self->{lostdate} " if exists $self->{lostdate};
        return "no lost data datetime found";
        # return "no valid data datetime period defined ";
        
        
    # Do something here

    
}
sub gettimeperiod {
    my $self = shift;
    # my $stat=$self->initial || "";
         if (exists $self->{_date_beg} and exists $self->{_date_finish}){
           return ${\POSIX::strftime("%Y-%m-%d %H:%M:%S",localtime($self->{_date_beg}))}." - ".${\POSIX::strftime("%Y-%m-%d %H:%M:%S",localtime($self->{_date_finish}))};
         }elsif(exists $self->{_month}){
          return "month ",$self->{_month};
         }else{
          return " no date period supplied by user";
         }
 

    
}



1};

=pod

=head1 SUPPORT

No support is available

=head1 BandurinDV

Copyright 2017 Bandurin 

=cut
# use Data::Dumper;
#use POSIX;
my $obj=BURST->new();
#my $ini = $obj->initial("", '2017-09-17 23:50:01', '2017-09-19 07:29:56') ; #,[percent],[_logfile],[delta_time], [datatype], [timeprecision])


#input params: DIR, DIR_OUT, ["number _month"] , ['2017-09-18 01:50:01', '2017-09-18 01:50:01'],[percent],[_logfile],[delta_time], [datatype], [timeprecision],[lostdata_treshold]

my $dir= shift || "/usr/share/zabbix/BURSTS";
my $dir_out= $dir."/BURST_CALC";
my $fileout=shift || $dir_out."/logfile_calc_uplinks.log";
my $ini='';
my %uplinks=("792" => "RASCOM", "791" => "GLOBAL", "789" => "DATA-IX");
my $exec_date=POSIX::strftime("%Y-%m-%d %H:%M:%S",localtime(time));
my $upl="";
 if (opendir(DIR, $dir)){
  closedir(DIR);
 }else{
  mkdir $dir;

 }
     if (opendir(DIR, $dir_out)){
         closedir(DIR);
     }else{
          mkdir $dir_out;
    }


 opendir (DIR, $dir);
 chdir $dir;
 open (my $fh,">>", $fileout);
 my @list_files= readdir(DIR);
 foreach my $file (@list_files) {
  if ($file =~/_(\d{1,})/ and -f './'.$file){
    $upl = $uplinks{$1} ;
        #$ini = $obj->initial(shift || "current", shift || "", shift || "","", './'. $file); #,[delta_time], [datatype], [timeprecision]);
        $ini = $obj->initial(shift || "current", shift || "", shift || "","0.05",'./'. $file); #,[delta_time], [datatype], [timeprecision]);
#        $ini = $obj->initial(shift || "", shift || "2018-03-01 00:00:00", shift || "2018-03-21 00:00:00","0.05", './'. $file); #,[delta_time], [datatype], [timeprecision]);        

    my $bur=$obj->burst();
    if ($ini!~/^no\s+/){
      
      print $upl." file ".$file,"\n";
      print $fh $upl.":" ;
      print $fh " Burst: ".$bur;
      print $fh " Period: ".$obj->gettimeperiod;
      print $fh "\nValid period:", $obj->getvalidperiod;
      print $fh " Lost dates:".$obj->getlostdate;
      print $fh "\n";
       open (my $fh1,">>", $dir_out."/burst_".$upl.'.log'); 
       print $fh1 $exec_date." ".$bur;
       print $fh1 "\n";
       close $fh1;
    }else{
      print $fh $ini;
    }
   
   
  }
 }
 print $fh "\n";
 close $fh;
 closedir(DIR);