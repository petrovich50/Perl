package BURST_CALC::STAT;

=pod

=head1 BURTS STATISTICS

STAT - module class for BURST DATA managing and collecting them into mysql database BURST_DATA
By Bandurin D.V. bandurin@gmail.com

=head1 SYNOPSIS

  my $object = STAT->new(
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
use lib '/usr/share/zabbix/externalscripts/MODULES'; #point out lib of USER_LLD modules here
use POSIX 'strftime';
use IO::Zlib;
use Archive::Tar;
use MyZabbix::USER_LLD '_get_snmp_res';
use Data::Dumper;
use DBI;
our $VERSION = '0.04';

=pod

=head2 new

  my $object = STAT->new(
      foo => 'bar',
  );

The C<new> constructor lets you create a new B<STAT> object.

Here we define a vriable set at the moment of new OBJECT to be constructed. The variables as follows:
_active_indexes_file - holdings of active indexes + ip
_root_dir - root directory for working directory
_main_dir - working directory for counter_dir, Log_dir, calc_dir
_counter_dir - place where allocated active conters
_arch_dir - backup, archiev dir for dropped and history of counters
_conf_dir - configuration directory, where active_indexe file and other conf files allocated
_calc_dir - burst and other statistics allocted
_arch_subdir - subdir prefix for counters fullname mask = _arch_subdir++ip+date(yy-mm-dd) as pare of index and ip totally define interface
_oidfile_prefix - prefix of counter oid file. Full mask= corr{_oidfile_prefix}+index+_+ip
_back_oidfile_prefix - backup subdir for backuped counters. Full mask is = _back_oidfile_prefix+index+_+ip+timestamp

=cut

sub new {
    my $class = shift;
    my $self  = bless { @_ }, $class;
    $self->{_slash}='/';
    $self->{_list_dirs}=['counter_dir','calc_dir','log_dir','arch_dir','conf_dir'];
    $self->{_root_dir}='/usr/share/zabbix/externalscripts';
    $self->{_main_dir}=$self->{_slash}.'BURST_DIR';
    $self->{_oidfile_prefix}=$self->{_slash}.'counters_';
    $self->{_back_oidfile_prefix}=$self->{_slash}.'back_counters_';
    $self->{_arch_subdir}=$self->{_slash}.'COUNTERS_';
    foreach my $d (@{$self->{_list_dirs}}){
        $self->{'_'.$d}=$self->{_slash}.${\uc($d)};
    }
    $self->_make_dirs();
    $self->{_active_indexes_file}=$self->{_root_dir}.$self->{_main_dir}.$self->{_conf_dir}.$self->{_slash}.'active_indexes.log';
    $self->{_counters_log_file}=$self->{_root_dir}.$self->{_main_dir}.$self->{_log_dir}.$self->{_slash}.'counters.log';
    $self->{_ifindexoid}={'desc'=>'.1.3.6.1.2.1.2.2.1.2', 'alias'=>'.1.3.6.1.2.1.31.1.1.1.18'};# Name        ifHCOutOctets - output , ifHCInOctets - input by deafau
    $self->{_counters_log_file}=$self->{_root_dir}.$self->{_main_dir}.$self->{_log_dir}.$self->{_slash}.'counters.log';    
    $self->{_interfaces}={'141.101.186.5'=>['141.101.186.5','161','2','AlSiTeC','MX960_SRT'],
        '141.101.186.2'=>['141.101.186.2','161','2','AlSiTeC', 'MX960_MSK'],
        '141.101.186.243'=>['141.101.186.243','161','2','AlSiTeC', 'EX4550_SRT'],
        '192.168.100.237'=>['192.168.100.237','161','2','AlSiTeC', 'EX4550_OZINKI'],
	'141.101.186.84'=>['141.101.186.84', '161', '2', 'AlSiTeC', 'FRANKFURT_M320'],
	'141.101.186.42'=>['141.101.186.42', '161', '2', 'public', ' Saratov_Switch_extreme_x670'],
	'192.168.78.10'=>['192.168.78.10', '161', '2', 'AlSiTeC', ' JuniperSwitch_Almaty'],
	'141.101.186.85'=>['141.101.186.85', '161', '2', 'AlSiTeC', 'Moscow_M320']};
    $self->{_ini_indexes}=[['1059','141.101.186.2'],['791','141.101.186.2'],['792','141.101.186.2']];;
    $self->{_baseoid}={'input'=>'.1.3.6.1.2.1.31.1.1.1.6.', 'output'=>'.1.3.6.1.2.1.31.1.1.1.10.'};# Name        ifHCOutOctets - output , ifHCInOctets - input by deafau
#    $self->_make_dirs();
    $self->_db_ini();
    $self->_web_ini();
    $self->_log_ini();
    return $self;
};

=pod

=head2 add_counters_data

This method does something... apparently.

=cut

sub set_param {
    my $self=shift;
    $self->{_list_desc}=shift; # arrayref of arrayrefs like: $self->[i]=[index,IP]
    $self->{_month}=$1 if shift =~/^[\t\s]{0,}([1-9]{1}\.\d{4}|10\.\d{4}|11\.\d{4}|12\.\d{4}|current)[\t\s]{0,}$/;
    $self->{_date_beg}=timelocal($7,$6,$5,$4,$3-1,$2) if shift =~m/((\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2}))[+:\d\s]{0,}/;
    $self->{_date_end}=timelocal($7,$6,$5,$4,$3-1,$2) if shift =~m/((\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2}))[+:\d\s]{0,}/;
      my @cur_date=localtime(time);
    if (exists($self->{_list_desc}) and (ref($self->{list_desc}) eq "ARRAY")){
        if (exists $self->{_month} and ($self->{_month} !~/current/)){
         return [$self->{_list_desc}, timelocal($cur_date[0],$cur_date[1],$cur_date[2],$cur_date[3],$cur_date[4],$cur_date[5]), timelocal(0,0,0,1,$cur_date[4],$cur_date[5])];
        }elsif (exists $self->{_month} and ($self->{_month}=~/current/)){
         $self->{_month} =~/(\d+)\.(\d{4})/;
         return [$self->{_list_desc}, timelocal(0,0,0,1,$1,$2), timelocal(0,0,0,1,$1-1,$2)];
        }elsif(exists $self->{_date_beg} and exists $self->{_date_end} and ($self->{_date_end}-$self->{_date_beg}) > 0){
         return [$self->{_list_desc}, $self->{_date_end}, $self->{_date_beg}];
        }else{
         return [$self->{_list_desc}];
        }
    }else{
        return 'no interfaces indexes selected';
    }

};

# sub to get class-object variables. Input must be key of scalar. Don't use scalar ref please
sub get_ini{ #inputed SCALAR ref of one name_of_param
    my $self = shift;
    my $key =shift;
    return $self->{$key} if (defined($key) and (ref($key) eq "SCALAR") and exists($self->{$key}));
    return "no data fetched. Param input doesnt specified or not a scalar ref inpeted or value doesn exists";

};
#sub to set class-obj variables. Input args are hashref of view {'key'='value',..} value may have any structure you want to
sub set_ini{ # input as hash ref of key_paraname => value_of_param
    my $self = shift;
    my $hash_param=shift;
    if (defined($hash_param) and (ref($hash_param) eq "HASH")){
        while (my ($k, $v) = each %{$hash_param}){
            $self->{$k}=$v;
        }
        return "ok";
    }else{
        return "no data assigned";
    }

};

# sub to write new active indexes in file of active indexes
sub _write_indexes { #index set to be changed inputed into active index file $index_file
        # method performs comparation to previous index set $prev_indexes into active file $index_file
        # for lost indexes counter log file is copied to archieve and removed from active counter log file directory
    my $self = shift;
    my $index_file = shift||$self->{_active_indexes_file};
    my @curr_indexes=@{$self->{_list_desc}} if (exists $self->{_list_desc} and (ref($self->{_list_desc}) eq "ARRAY"));
    my $prev_indexes=$self->_read_indexes();
    my $curr_timestamp=time();
    my @drop_indexes=();
    my $output="";
#    print "CURRIND ",Dumper(\@curr_indexes),"\n";
#    print "CURRIND2 ",Dumper(\@{[map{join(' ',@{$_})} @curr_indexes]}),"\n";
#    print "PREVIOUS INDEXES ",Dumper(@{[map{join(' ',@{$_})} @{$prev_indexes}]}),"\n";
    my $pattern=join('|', @{[map{join(' ',@{$_})} @curr_indexes]});
    $pattern =~s/\./\\./gi; #escape . in ips to make regrp pattern
#    print "PATTERN ",$pattern,"\n";
    if ($pattern !~/no/ and $pattern){
        @drop_indexes=map{$_} grep{$_!~/^($pattern)/} @{[map{join(' ',@{$_})} @{$prev_indexes}]} ; #compare lines of pair: 'index ip'
        $output.=$self->_delete_countertable(\@drop_indexes);
#        $output.=$self->_delete_indexestable(\@drop_indexes) if $output!~/no/;
        $output.=$self->_arch_dropped(\@drop_indexes) if $output!~/no/;
        #$output.=$self->_remove_table_db(\@drop_indexes); # delete table from db
#       print "OUTPUT ",$output,"\n";
#        $output.=$self->_delete_from_table();
        return $output if $output=~/no/;
        open(my $fh,'>',$index_file);
            foreach  (@curr_indexes){
                print $fh join(' ',@{$_}),"\n"; #yes there is one empty extra line
            }
        close $fh;
        return "ok";
    }elsif($pattern !~/no/ and !$pattern){
#        $output.=$self->_add_to_table();
        $output.=$self->_arch_dropped(\@{[map{join(' ',@{$_})} @{$prev_indexes}]});
        return $output if $output=~/no/;
        return "ok";
    }else{
    # my ;

        return $pattern;
    }
};

sub _read_indexes {
    my $self = shift;
    my $index_f = shift||$self->{_active_indexes_file};
    my @indexes_lines=();
    my $res=[];
    if ( -e $index_f){
    open(my $fh,'<',$index_f);
        @indexes_lines = <$fh>;
    close $fh;
    }else{
	@indexes_lines=@{$self->{_ini_indexes}};
    }
    $res = \@{[map{eval{$_=~/^(\d+)[\t\s]+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/; return [$1, $2]}} grep{$_=~/^(\d+)[\t\s]+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/} @indexes_lines]} ; # filtering nondigits
            # Do something here

    return $res;
};


sub _fullfill_db { #index set to be changed inputed into active index file $index_file
        # method performs comparation to previous index set $prev_indexes into active file $index_file
        # for lost indexes counter log file is copied to archieve and removed from active counter log file directory
    my $self = shift;
    my $index_file = shift||$self->{_active_indexes_file};

    my $prev_indexes=$self->_read_indexes();
    my $curr_timestamp=time();

    my $output="";
#    print "CURRIND ",Dumper(\@curr_indexes),"\n";
#    print "CURRIND2 ",Dumper(\@{[map{join(' ',@{$_})} @curr_indexes]}),"\n";
#    print "PREVIOUS INDEXES ",Dumper(@{[map{join(' ',@{$_})} @{$prev_indexes}]}),"\n";


#    print "PATTERN ",$pattern,"\n";
#    print Dumper($prev_indexes)," ---previous indexes fullfill  \n";
    if ($prev_indexes and (ref($prev_indexes) eq "ARRAY")){
        $output=$self->_insert_update_counterstable($prev_indexes);
        $output.=$self->_arch_dropped(\@{[map{join(" ",@{$_})} @{$prev_indexes}]}) if $output!~/no/; #
        #$output.=$self->_remove_table_db(\@drop_indexes); # delete table from db
#       print "OUTPUT ",$output,"\n";
#        $output.=$self->_delete_from_table();
        return $output if $output=~/no/;

        return "ok";
    }else{
    # my ;

        return "no indexes supplied in index file to insert in db";
    }
};

sub _add_to_file{
      my $self = shift;
      my $file=shift;
      my $line=shift;
      open(my $fh,'>>',$file);
        print $fh $line."\n";
      close $fh;
};

sub _test_make_dir {
      my $self = shift;
      my $dir=shift;
       if (opendir(DIR, $dir)){
         return "dir exists" if closedir(DIR);
        }else{
         return (mkdir $dir) ? "dir created" : "no one dir created";
        }
};


sub add_counters_data{ #
            # Name       ifHCOutOctets - output , ifHCInOctets - input by deafault
    my $self=shift;
    my $inf=shift||$self->{_interfaces};
        my $baseoid=shift||$self->{_baseoid};  #
        my $indexes=shift||$self->{_list_desc};
        my $file_counter_path_prefix=shift ||$self->{_root_dir}.$self->{_main_dir}.$self->{_counter_dir}.$self->{_slash}.$self->{_oidfile_prefix};
    my $snmp=MyZabbix::USER_LLD->new();
    my $res={};
#    print "V ADD_COUNT SUB ",$self->{_active_indexes_file},"\n";
#    print Dumper($inf),"\n";
    $indexes=$self->_read_indexes();
    my ($inp, $out, $timestamp)=("","",0);
    if (ref($indexes) eq "ARRAY"){ # array of indexes
        foreach my $k (@{$indexes}){
#           print Dumper($k),"--KK \n";
#           print Dumper(($k->[1], $baseoid->{'input'}.$k->[0], $inf->{$k->[1]}->[1], $inf->{$k->[1]}->[2], $inf->{$k->[1]}->[3])),"\n";
            $inp=$snmp->_get_snmp_res($k->[1], $baseoid->{'input'}.$k->[0], $inf->{$k->[1]}->[1], $inf->{$k->[1]}->[2], $inf->{$k->[1]}->[3]);
            $out=$snmp->_get_snmp_res($k->[1], $baseoid->{'output'}.$k->[0], $inf->{$k->[1]}->[1], $inf->{$k->[1]}->[2], $inf->{$k->[1]}->[3]);
            $timestamp=time();
            # $res->{$k->[0].' '.$k->[1]}=[$timestamp, $inp, $out] if ($inp=~/^\d+$/ and $out=~/^\d+$/);        #if nondigit this timestamp record is just ommited
            if ($inp=~/error/ or $out=~/error/){
                $self->_write_log('input: '.$inp.' output: '.$out."\n");
                next;
             }
            $self->_add_to_file($file_counter_path_prefix.$k->[0].'_'.$k->[1],"$timestamp, $inp, $out");

        }
    }else{
        return $res;
    }
        return $res;


};

sub _write_log{
    my $self=shift;
    my $line=shift;
    my $file=shift|| $self->{_counters_log_file};    
#    print $file," ----COUNTER_LOOOG \n";
    return 0  if !$file;
    open(my $fh,'>>',$file);
       print $fh $line; 
    close $fh;
    return 1;    
    
};

sub _make_dirs {
    my $self=shift;
    my $ind=shift||$self->{_list_dirs};
        if (opendir(DIR, $self->{_root_dir})){
         closedir(DIR);
        }else{
         mkdir $self->{_root_dir};
         mkdir $self->{_root_dir}.$self->{_main_dir};
        }
        if (opendir(DIR, $self->{_root_dir}.$self->{_main_dir})){
         closedir(DIR);
        }else{
         mkdir $self->{_root_dir}.$self->{_main_dir};
         foreach my $d (@{$self->{_list_dirs}}){
        mkdir $self->{_root_dir}.$self->{_main_dir}.$self->{'_'.$d};
         }
        }
        foreach my $d (@{$ind}){
            if (opendir(DIR, $self->{_root_dir}.$self->{_main_dir}.$self->{'_'.$d})){
             closedir(DIR);
            }else{
            mkdir $self->{_root_dir}.$self->{_main_dir}.$self->{'_'.$d};

            }
        }


};


sub _arch_dropped{
    my $self = shift;
    my $dropped_indexes=shift;
    my $arch_subdir=shift ||$self->{_root_dir}.$self->{_main_dir}.$self->{_arch_dir}.$self->{_arch_subdir};
    my $counter_dir=shift ||$self->{_root_dir}.$self->{_main_dir}.$self->{_counter_dir};
    my $MY = POSIX::strftime("%d-%m-%Y", localtime(time));
    my $timestamp = time();
    my ($count,$res)=(0,"");
    return "no drop indexes aray inputed" if ((ref($dropped_indexes) ne "ARRAY") or !defined($dropped_indexes) or !$dropped_indexes);
    foreach my $ind (@{$dropped_indexes}){
        if($ind=~/^(\d+)[\t\s]+(\d+\.\d+\.\d+\.\d+)/){
            $res=$self->_data_backup($counter_dir.$self->{_oidfile_prefix}.$1.'_'.$2,   # origin counter log file
                        $arch_subdir.$2.'_'.$MY,                        # back archive subdir ip_day_month_year
                        $arch_subdir.$2.'_'.$MY.$self->{_back_oidfile_prefix}.$1.'_'.$2.'_'.$timestamp); # back archieve index_timestamp.gz
            $count++ if $res=~/no/;
#        print Dumper($ind,$counter_dir.$self->{_oidfile_prefix}.$1.'_'.$2,   # origin counter log file
#                        $arch_subdir.$2.'_'.$MY,                        # back archive subdir ip_day_month_year
#                        $arch_subdir.$2.'_'.$MY.$self->{_back_oidfile_prefix}.$1.'_'.$2.'_'.$timestamp)," =====tttttt=== \n";
        }else{
            $count++;
        }
        # return "no arch_subdir exists or cant make one." if ${\($self->_test_make_dir($arch_subdir.$ind.'_'.$MY))}=~/no/; # 1.make back dir for dropped indexes
        # return "no original file exists: ".$log_dir.$self->{_slash}.$self->{_oidfile_prefix}.$ind if !$self->_copy_zip($log_dir.$self->{_slash}.$self->{_oidfile_prefix}.$ind, $arch_subdir.$ind.'_'.$MY.$self->{_slash}.$self->{_back_oidfile_prefix}.$ind); #copy original  dropped index counter file to gz file
        # unlink $log_dir.$self->{_slash}.$self->{_oidfile_prefix}.$ind or return "no file to delete: ".$log_dir.$self->{_slash}.$self->{_oidfile_prefix}.$ind;

    }
#    print Dumper($dropped_indexes,$#{$dropped_indexes},$res,$count)," ---dropped index \n";
#    print Dumper($dropped_indexes),$#{$dropped_indexes},$res,$count," ---dropped index \n";
    return "no one of indexes normally backuped" if (($#{$dropped_indexes}+1)==$count and ($#{$dropped_indexes}+1)>0);
    return "ok";

};




sub _data_backup{
    my $self = shift;
    # my $indexes=shift||[];
    my $origin_file=shift;
    my $dir_to_file=shift;
    my $file_back=shift;
#        print Dumper($origin_file, $dir_to_file, $file_back),"--data backup \n";
#       exit "HHHHHUY";
        return "no arch_subdir: $dir_to_file exists or cant be made." if ${\($self->_test_make_dir($dir_to_file))}=~/no/; # 1.make back dir for dropped indexes
        return "no original file exists: ".$origin_file if !$self->_copy_zip($origin_file, $file_back); #copy original  dropped index counter file to gz file
        return "no file to delete: ".$origin_file if !unlink $origin_file;
        return "ok";

};




sub _copy_zip {
    my $self = shift;
    my $from_file_original=shift;
    my $to_file_gz=shift;
    my $tar = Archive::Tar->new();
    $tar->add_files($from_file_original );
    if ($tar) {
        $tar->add_files($from_file_original);
	$tar->write($to_file_gz.'.tgz', COMPRESS_GZIP);
        return 1;
    }else{
        return 0;
    }

};

sub _file_unzip{
    my $self=shift;
    my $file=shift;
    my $fh = new IO::Zlib;
        if ($fh->open($file,'rb')) {
            print uncompress($fh);
            $fh->close;
        }
};

=pod

=head2 DB treatment methods

This method does something... apparently.

=cut

sub _read_from_file{
      my $self = shift;
      my $file=shift;
      my @lines=();
      return @lines  if ! -e $file;
      open(my $fh,'<',$file);
        @lines=<$fh>;
      close $fh;
      return @lines;
};


=pod

=head2 DB treatment methods

_taste_make_db - perform initial db preparation
it tests if the db exists and makes it if no


=cut
sub _db_ini{
    my $self=shift;
    $self->{_database}='BURST_DATA';
    #fiels
    $self->{_log}=$self->{_root_dir}.$self->{_main_dir}.$self->{_conf_dir}.$self->{_slash}."tits";
    $self->{_db_tables}={'counters'=>{'counters_tb'=>'counters','id'=>'id','timestamp'=>'timestamp','ind_id'=>'ind_id','input'=>'input','output'=>'output'},
                        'indexes'=>{'indexes_tb'=>'indexes','id'=>'id','index'=>'ifindex','id_ip'=>'id_ip','description'=>'description','alias'=>'alias'},
                        'ip'=>{'ip_tb'=>'ip', 'id'=>'id', 'ip'=>'ip','snmp_v'=>'snmp_v','snmp_port'=>'snmp_port','community'=>'community','name'=>'name'}};
     $self->{_statement}=[qq( CREATE TABLE $self->{_db_tables}->{ip}->{ip_tb} (
                        $self->{_db_tables}->{ip}->{id} INT(8)unsigned  NOT NULL AUTO_INCREMENT,
                        $self->{_db_tables}->{ip}->{ip} INT(8) unsigned NOT NULL UNIQUE,
                        $self->{_db_tables}->{ip}->{snmp_v} INT(4) unsigned NOT NULL,
                        $self->{_db_tables}->{ip}->{snmp_port} INT(8) unsigned NOT NULL,
                        $self->{_db_tables}->{ip}->{community} VARCHAR(25) NOT NULL,
                        $self->{_db_tables}->{ip}->{name} VARCHAR(25) NOT NULL,
                        PRIMARY KEY ($self->{_db_tables}->{ip}->{id})))
                        ,
                        qq(CREATE TABLE $self->{_db_tables}->{indexes}->{indexes_tb} (
                        $self->{_db_tables}->{indexes}->{id} INT(8) unsigned NOT NULL AUTO_INCREMENT,
                        $self->{_db_tables}->{indexes}->{index} INT(8) unsigned NOT NULL,
                        $self->{_db_tables}->{indexes}->{id_ip} INT(8) unsigned NOT NULL,
                        $self->{_db_tables}->{indexes}->{description} VARCHAR(25) NOT NULL,
                        $self->{_db_tables}->{indexes}->{alias} VARCHAR(25) NOT NULL,
                        PRIMARY KEY ($self->{_db_tables}->{indexes}->{id}),
                        FOREIGN KEY ($self->{_db_tables}->{indexes}->{id_ip})
                                REFERENCES $self->{_db_tables}->{ip}->{ip_tb}($self->{_db_tables}->{ip}->{id})
                                ON UPDATE CASCADE))
                        ,
                        qq(CREATE TABLE $self->{_db_tables}->{counters}->{counters_tb} (
                        $self->{_db_tables}->{counters}->{id} INT(8) unsigned NOT NULL AUTO_INCREMENT,
                        $self->{_db_tables}->{counters}->{timestamp} INT(8) unsigned NOT NULL,
                        $self->{_db_tables}->{counters}->{input} BIGINT NOT NULL,
                        $self->{_db_tables}->{counters}->{output} BIGINT NOT NULL,
                        $self->{_db_tables}->{counters}->{ind_id} INT(8) unsigned NOT NULL,
                        PRIMARY KEY ($self->{_db_tables}->{counters}->{id}),
                        FOREIGN KEY ($self->{_db_tables}->{counters}->{ind_id})
                                REFERENCES $self->{_db_tables}->{indexes}->{indexes_tb}($self->{_db_tables}->{indexes}->{id})))
                        ];

    return 1;
};

sub _create_db{
    my $self = shift;
    my $f_log=shift||$self->{_log};    
    my $log=$self->_get_log($f_log);
#    print Dumper($log)," DBBBBB  LOOOOOG \n";
    my ($u, $p)=(shift||$log->[0], shift||$log->[1]);
    my $db_name=shift||$self->{_database};
    my %atr= (PrintError => 0,
              PrintWarn  => 0,
              RaiseError => 0,
              AutoCommit => 1);
    my $dbh = DBI->connect( "DBI:mysql:", $u, $p, \%atr);
    return "no connection to mysql or wrong loggin. Error: ".DBI->errstr if !$dbh;
    return "no databases created, Error: ".DBI->errstr if ($dbh->do("CREATE DATABASE $db_name",\%atr)!~/(1|-1)/);
    return "ok database created0";

};

sub _create_tables{
    my $self = shift;
    my $f_log=shift||$self->{_log};
#    print Dumper($self->{_log},$f_log), " ==={{{{{{{{ \n";
    my $log=$self->_get_log($f_log);    
#    print Dumper($log)," LOOOOOG \n";
    my ($u, $p)=(shift||$log->[0], shift||$log->[1]);
    my $db_name=shift||$self->{_database};
    my @create_statments=shift||@{$self->{_statement}};
    my %atr =(PrintError => 0,
              PrintWarn  => 0,
              RaiseError => 0,
              AutoCommit => 1);
    my $dbh = DBI->connect( "DBI:mysql:".$db_name, $u, $p, \%atr);
    return "no database connected to create tables" if (!$dbh and ${\($self->_create_db($f_log))}=~/no/);
    $dbh = DBI->connect( "DBI:mysql:".$db_name, $u, $p, \%atr) if !$dbh; # if we've gone through previous so..try to connect one more
#    print Dumper($dbh),"--create tables \n";
#    print Dumper(\@create_statments)," --statements\n";
    my $out='';
    foreach my $statement (@create_statments){
#        print $statement," ---statement \n";
        $out.="no table has been created. Error: ".$DBI::errstr if (!${\($dbh->do($statement,\%atr))} and 
								    $DBI::errstr  and 
								    $DBI::errstr!~/(already exists|Duplicate column name)/);
#        print " ",$DBI::errstr, " ---do in creat tables \n"
    }
    print "\n result outtput: ",$out," --out from _create table \n";
#    print ref($dbh),"  ---dbh ref \n";
    return "not all tables created." if $out=~/no/;
    $out.=$self->_insert_update_iptable($dbh); #, "--insert \n";
    $out.=$self->_insert_update_indexestable($dbh); #, "--insert INDEX \n";
    return "no or not all data inserted " if $out=~/no/;
    return "ok all tables created";

};

sub _is_tables{
    my $self=shift;
    my $db_obj=shift || $self->_test_db();
    my $counters_data=shift||$self->{_interfaces};
    my $table_def=shift|| $self->{_db_tables};    
    my $cond_table=(exists($table_def->{indexes}->{indexes_tb}) and exists($table_def->{ip}->{ip_tb}) and 
                    exists($table_def->{counters}->{counters_tb}));
    my $cond_obj= ($db_obj and (ref($db_obj) eq "DBI::db"));    
    my %atr= (PrintError => 0,
              PrintWarn  => 0,
              RaiseError => 0,
              AutoCommit => 1) ;      
    my @selects=();
    if ($cond_obj and $cond_table){
        @selects=(qq[SELECT count(*) FROM $table_def->{indexes}->{indexes_tb}], qq[SELECT count(*) FROM $table_def->{ip}->{ip_tb}],
                    qq[SELECT count(*) FROM $table_def->{counters}->{counters_tb}]);
    }else{
        return "no one or not all tables exists";
    }
#    print Dumper(@selects)," 00000000 \n";
    return "no or not all tables exists" if ${\(join(':',@{[map{"no selected this DBI->errstr "} grep{!$db_obj->do($_, \%atr) and DBI->errstr} @selects]}))};
    return "ok";
};

sub _log_ini{
    my $self=shift;
    my $file=shift||$self->{_log};
#    print $file," UUUU \n";
    return 0 if !$file;
        open(my $fh,">",$file);
        print $fh "root Ntcnbhjdobr134";
        close $fh;
};

sub _test_make_db{
    my $self = shift;
    my $f_log=shift||$self->{_log};
    my $log=$self->_get_log($f_log);
    my $dsn="DBI:mysql:$self->{_database}";
    my %atr= (PrintError => 0,
              PrintWarn  => 0,
              RaiseError => 0,
              AutoCommit => 1);
#    print Dumper($log)," from get_log  \n";
#    print ref($log),"--reflog \n";
#    print ${\($#{$log}+1)}, "   llllll \n";

#    print "\n\n\n";
    if ((ref($log) eq "ARRAY") and (($#{$log}+1)==2)){
#       $log=$log->[0];
        my $dbh = DBI->connect( $dsn,
                        $log->[0],
                        $log->[1],
                        \%atr); # or return ("no connection to DB Error: ".DBI->errstr."\n");
        if (!$dbh or (DBI->errstr and (${(DBI->errstr)} =~/Unknown database/))){
            return 'no or cannot create db'.$self->{_database} if ${\($self->_create_db($f_log))}=~/no/;
            return "ok database created1";
        }else{
            return "ok database created2";
        }
    }else{
        return 'no loggin data or wrong supplied';
    }
};

sub _test_db{
    my $self = shift;
    my $f_log=shift||$self->{_log};
    my $dsn="DBI:mysql:$self->{_database}";
    my $log=$self->_get_log($f_log);
    my %atr= (PrintError => 0,
              PrintWarn  => 0,
              RaiseError => 0,
              AutoCommit => 1);
#    print Dumper($log)," from get_log  \n";
#    print ref($log),"--reflog \n";
#    print ${\($#{$log}+1)}, "   llllll \n";
    if ((ref($log) eq "ARRAY") and (($#{$log}+1)==2)){
        my $dbh = DBI->connect( $dsn,
                        $log->[0],
                        $log->[1],
                        \%atr);
        if (!$dbh or (DBI->errstr and (${(DBI->errstr)} =~/Unknown database/))){
            return 'no or cannot create db'.$self->{_database} if ${\($self->_create_db($log->[0],$log->[1],$self->{_database}))}=~/no/;
            $dbh = DBI->connect( $dsn,
                        $log->[0],
                        $log->[1],
                        \%atr);
            return "no DB connected" if !$dbh;
            return $dbh;
        }else{
            return $dbh;
        }
    }else{
        return 'no or wrong passwd to db';
    }
};

sub _get_log{
    my $self = shift;
    my $file=shift||$self->{_log};
#    print $self->_log_ini()  if ! -e $file;    
    my @lines=$self->_read_from_file($file);
#    print Dumper(\@{[$self->_read_from_file($file)]}),"-- \n";
#    print Dumper(\@lines)," --lines \n";
#    print Dumper(\@{[map{eval{$_=~/^(\w+)[\t\s]+(\w+)/; return ($1, $2)}}@lines]}),"--hhh \n";
    return "no loggin file"  if (! -e $file or !@lines);
    return \@{[map{eval{$_=~/^(\w+)[\t\s]+(\w+)/; return ($1, $2)}} @lines]}; #->[0];
#    return \@{map{eval{$_=~/^(\w+)[\t\s]+(\w+)/; return [$1, $2]}} @lines}; #->[0];    

};

sub _insert_update_iptable{
    my $self = shift;
    my $db_obj=shift;
    my $interfaces=shift||$self->{_interfaces};
    my $table_def=shift|| $self->{_db_tables};
    my $cond_table=(exists($table_def->{ip}->{snmp_port}) and exists($table_def->{ip}->{community}) and exists($table_def->{ip}->{snmp_port}) and exists($table_def->{ip}->{ip}));
    my $cond_data=($interfaces and (ref($interfaces) eq "HASH"));
    my $cond_obj= ($db_obj and (ref($db_obj) eq "DBI::db"));
    my %atr= (PrintError => 0,
              PrintWarn  => 0,
              RaiseError => 0,
              AutoCommit => 1) ;
#     print Dumper($table_def)," --table def \n",Dumper($interfaces)," --interfaces \n";
#     print Dumper($cond_obj,$cond_data, $cond_table), " conditions \n";
    if ($cond_obj and $cond_data and $cond_table) {
        my %hash_inf= %{$interfaces}; # lets make hash of arrayrefs
        my %sentences = map{$_ => qq(UPDATE $table_def->{ip}->{ip_tb} SET $table_def->{ip}->{snmp_port}='$hash_inf{$_}->[1]',
                                                                $table_def->{ip}->{snmp_v} ='$hash_inf{$_}->[2]',
                                                                $table_def->{ip}->{community}='$hash_inf{$_}->[3]',
                                                                $table_def->{ip}->{name}= '$hash_inf{$_}->[4]'
                                                                WHERE $table_def->{ip}->{ip}=INET_ATON('$hash_inf{$_}->[0]'))}
                                                                keys %hash_inf;

#        my %sentences = map{$_ => qq(UPDATE $table_def->{ip}->{ip_tb} SET $table_def->{ip}->{snmp_port}=\'$hash_inf{$_}->[1]\',
#                                                                $table_def->{ip}->{snmp_v} =\'$hash_inf{$_}->[2]\',
#                                                                $table_def->{ip}->{community}=\'$hash_inf{$_}->[3]\',
#                                                                $table_def->{ip}->{name}= \'$hash_inf{$_}->[4]\'
#                                                                WHERE $table_def->{ip}->{ip}=INET_ATON(\'$hash_inf{$_}->[0]\'))}
#                                                                keys %hash_inf;
#         print Dumper(%sentences)," --1 \n",Dumper(%hash_inf)," -- hash 1 \n";
        %hash_inf= map{$_=>"(".${\(join(",", @{[map{eval{return "INET_ATON($1)" if $_=~/('\d+\.\d+\.\d+\.\d+')/; return $_;}}
                   @{[map{"\'$_\'"} @{$hash_inf{$_}}]}]}))}.")"} grep{$db_obj->do($sentences{$_},\%atr)=='0E0'}
                   keys %sentences;
#        print Dumper($db_obj->do($sentences{'141.101.186.243'},\%atr))," <<--sentenciya \n";
#        print Dumper(\%hash_inf)," ------HASH NEW \n ";
        return "ok all was updated" if (($#{[keys %hash_inf]}+1)==0 and ($#{[keys %sentences]}+1)>0);
        # my $count_to_indert=$#{[keys %hash_inf]};
        my $insert_sentence=join(", ",@{[map {$_} grep{$_!~/\([\s\t,]*\)/} values %hash_inf]}); #those who not updated will be inserted['141.101.186.243','161','2','AlSiTeC', 'EX4550_SRT'],
#         print $insert_sentence," --inssentence1 \n",Dumper(%hash_inf)," -- hash 1.5 \n";
        $insert_sentence=qq[INSERT INTO $table_def->{ip}->{ip_tb}
         ($table_def->{ip}->{ip},$table_def->{ip}->{snmp_port},$table_def->{ip}->{snmp_v}, $table_def->{ip}->{community}, $table_def->{ip}->{name})
         VALUES $insert_sentence] if $insert_sentence;
#         print Dumper($insert_sentence)," --inssentence2 \n",Dumper(%hash_inf)," -- hash 2 \n";
        return "no one was inserted. Error: ".DBI->errstr if (!$db_obj->do($insert_sentence, \%atr) and DBI->errstr);
        return "ok everyone of ".${\($#{[keys %hash_inf]}+1)}." was inserted";

    }else{
        return "no data or wrong data for insert";
    }
};

sub _delete_iptable{
    my $self = shift;
};


sub _insert_update_indexestable{
    my $self = shift;
    my $db_obj=shift;
    my $counters_data=shift||$self->{_interfaces};
    my $table_def=shift|| $self->{_db_tables};
    my $indexes=shift|| $self->{_ifindexoid};
#'indexes'=>{'indexes_tb'=>'indexes','id'=>'id','index'=>'ifindex','id_ip'=>'id_ip','description'=>'description','alias'=>'alias'},
    my $cond_table=(exists($table_def->{indexes}->{indexes_tb}) and exists($table_def->{indexes}->{index}) and
            exists($table_def->{indexes}->{id_ip}) and exists($table_def->{indexes}->{description}) and
            exists($table_def->{indexes}->{alias}) and
            exists($table_def->{ip}->{ip_tb}) and exists($table_def->{ip}->{ip}) and exists($table_def->{ip}->{id}));
    my $cond_data=($counters_data and (ref($counters_data) eq "HASH"));
    my $cond_obj= ($db_obj and (ref($db_obj) eq "DBI::db"));
    my $cond_ifoids=(exists($indexes->{desc}) and exists($indexes->{alias}));
    my $mylld=MyZabbix::USER_LLD->new();

    my %atr= (PrintError => 0,
              PrintWarn  => 0,
              RaiseError => 0,
              AutoCommit => 1) ;
#     print Dumper($table_def)," --table def \n",Dumper($counters_data)," --interfaces \n";
#     print Dumper($cond_obj,$cond_data, $cond_table,$cond_ifoids), " conditions \n";
    if ($cond_obj and $cond_data and $cond_table and $cond_ifoids) {
#        my %desc=map{$_=>$mylld->indexdata_lld(@{[unshift(@{[eval{pop(@{$interfaces->{$_}}); return @{$interfaces->{$_}};}]},$_,$indexes->{desc})]})} keys %{$interfaces};
#        my %alias=map{$_=>$mylld->indexdata_lld(@{[unshift(@{[eval{pop(@{$interfaces->{$_}}); return @{$interfaces->{$_}};}]},$_,$indexes->{alias})]})} keys %{$interfaces};
        my %desc=map{$_=>$mylld->indexdata_lld(@{[eval{my @a=@{$counters_data->{$_}};pop(@a);shift(@a);unshift(@a,$_,$indexes->{desc}); return @a}]})} keys %{$counters_data};
        my %alias=map{$_=>$mylld->indexdata_lld(@{[eval{my @a=@{$counters_data->{$_}};pop(@a);shift(@a);unshift(@a,$_,$indexes->{alias}); return @a}]})} keys %{$counters_data};
#        my %desc=map{$_=>$mylld->indexdata_lld(@{[unshift(@{pop(@{$interfaces->{$_}})},$_,$indexes->{desc})]})} keys %{$interfaces};
#        my %alias=map{$_=>$mylld->indexdata_lld(@{[unshift(@{pop(@{$interfaces->{$_}})},$_,$indexes->{alias})]})} keys %{$interfaces};
        # %desc=map{$_=>map{eval{my @}} keys %{$desc{$_}}} keys %desc;
        my @data=();
#        print Dumper(@{[eval{my @a=@{$counters_data->{'141.101.186.243'}};pop(@a);shift @a;unshift(@a,'141.101.186.243',$indexes->{desc}); return @a;}]})," --DESC ARGS \n";

#        print Dumper(@{[eval{my @a=@{$counters_data->{'141.101.186.243'}};pop(@a);shift@a;shift(@a);unshift(@a,'141.101.186.243',$indexes->{alias}); return @a;}]})," --ALIAS ARGS \n";
#        print Dumper(%desc, %alias)," ---DESC+ALIAS";
        while (my ($k, $v) = each %desc){ # ip, index, desc, alias||NULL
#                print $k," - ",Dumper($desc{$k})," ---DESC \n";
            if (exists($alias{$k})){
               @data= @{[eval{unshift(@data ,@{[map{eval{my @a=($k, $_, $v->{$_});
               push(@a,${\( exists($alias{$k}->{$_}) ?$alias{$k}->{$_}:"NULL")});return \@a;}} keys %{$v}]});return @data;}]};
#               @data= push(@{[map{eval{return push(@{[$k, $_, $v->{$_}]},${\(eval{return exists($alias{$k}->{$_}) ?$alias{$k}->{$_}:"NULL";})});}} keys%{$v}]}, @data);
            }else{
               @data= @{[eval{unshift(@data ,@{[map{eval{my @a=($k, $_, $v->{$_});push(@a,"NULL"); return \@a;}} keys %{$v}]});return @data;}]};
#               @data= push(@{[map{eval{return push(@{[$k, $_, $v->{$_}]},"NULL");}} keys%{$v}]}, @data);
            }
        }
        #my %hash_inf= %{$interfaces}; # lets make hash of arrayrefs
#        print Dumper(@data)," ---DATA \n";
        my @sentences = @{[map{eval{push($_,qq[UPDATE $table_def->{indexes}->{indexes_tb} SET
                                                                $table_def->{indexes}->{description}='$_->[2]',
                                                                $table_def->{indexes}->{alias}='$_->[3]'
                                                                WHERE $table_def->{indexes}->{index}=$_->[1] AND
                                                                $table_def->{indexes}->{id_ip} IN
                                                                (SELECT $table_def->{ip}->{ip_tb}.$table_def->{ip}->{id} FROM $table_def->{ip}->{ip_tb}
                                                                WHERE $table_def->{ip}->{ip_tb}.$table_def->{ip}->{ip}=INET_ATON('$_->[0]'))]); return $_;}}
                                                                @data]};
#        print Dumper(@sentences)," ---HHHH";
        my $foreign_str=qq[SELECT $table_def->{ip}->{ip_tb}.$table_def->{ip}->{id} FROM $table_def->{ip}->{ip_tb} WHERE $table_def->{ip}->{ip_tb}.$table_def->{ip}->{ip}=];
        my $insert_sentence= join(', ',@{[map{qq[('$_->[1]','$_->[2]','$_->[3]',(${foreign_str}INET_ATON('$_->[0]')))]}
                                                    grep{$db_obj->do(pop($_), \%atr)=='0E0'} @sentences]});
#          print $insert_sentence," ---INSERT INDEXES1\n";
#'indexes'=>{'indexes_tb'=>'indexes','id'=>'id','index'=>'ifindex','id_ip'=>'id_ip','description'=>'description','alias'=>'alias'},
        $insert_sentence=qq[INSERT INTO $table_def->{indexes}->{indexes_tb}
         ($table_def->{indexes}->{index},$table_def->{indexes}->{description},$table_def->{indexes}->{alias},
            $table_def->{indexes}->{id_ip}) VALUES $insert_sentence] if $insert_sentence;
#          print $insert_sentence," ---INSERT INDEXES2\n";
        return "ok all was updated" if (!$insert_sentence and ($#sentences+1)>0);
        return "no one was inserted. Indexes Error: ".DBI->errstr if (!$db_obj->do($insert_sentence, \%atr) and DBI->errstr);
        return "ok everyone of INDEXES were inserted";

     }else{
        return "no data or wrong data to insert/update iptable supplied";

     }
};

sub _delete_indexestable{
    my $self = shift;
    my $indexes_delete=shift;
    my $dbh=$self->_test_db();
    my %atr= (PrintError => 0,
              PrintWarn  => 0,
              RaiseError => 0,
              AutoCommit => 1) ;
    my $table_def=shift|| $self->{_db_tables};
#'indexes'=>{'indexes_tb'=>'indexes','id'=>'id','index'=>'ifindex','id_ip'=>'id_ip','description'=>'description','alias'=>'alias'},
# 'counters'=>{'counters_tb'=>'counters','id'=>'id','timestamp'=>'timestamp','ind_id'=>'ind_id','input'=>'input','output'=>'output'},
    my $cond_table=(exists($table_def->{indexes}->{indexes_tb}) and exists($table_def->{indexes}->{index}) and
            exists($table_def->{indexes}->{id_ip}) and
            exists($table_def->{ip}->{ip_tb}) and exists($table_def->{ip}->{ip}) and exists($table_def->{ip}->{id}) and
            exists($table_def->{counters}->{counters_tb}) and exists($table_def->{counters}->{timestamp}) and
            exists($table_def->{counters}->{ind_id}));
    my $cond_ind=($indexes_delete and (ref($indexes_delete) eq "ARRAY"));
    my $cond_db=($dbh and (ref($dbh) eq "DBI::db"));
    my $sentence='';
    my $res='';
    my ($ind,$ip)=('','');
        if ($cond_ind  and $dbh and $cond_db and $cond_table){
         foreach my $k (@{$indexes_delete}){
           if (ref($k) eq "ARRAY"){
                   ($ind,$ip)=($k->[0],$k->[1]);

         }elsif($k=~/(\d+)[\t\s]+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/){
                   ($ind,$ip)=($1,$2);
         }else{
            return "no indexes or wromg indexes data supplied to delete from table";
         }
            $sentence=qq[DELETE FROM $table_def->{indexes}->{indexes_tb}
                                WHERE $table_def->{indexes}->{indexes_tb}.$table_def->{indexes}->{index}=$ind AND
                                $table_def->{indexes}->{indexes_tb}.$table_def->{indexes}->{id_ip} IN
                                (SELECT $table_def->{ip}->{ip_tb}.$table_def->{ip}->{id} FROM $table_def->{ip}->{ip_tb}
                                WHERE $table_def->{ip}->{ip_tb}.$table_def->{ip}->{ip}=INET_ATON('$ip'))];
            $res.= "no one indexes were deleted. Error: ".DBI->errstr if (!$dbh->do($sentence, \%atr) and DBI->errstr);

        }
            return  $res if $res=~/no/;
            return 'ok all dropped counters were deleted';
        }else{
            return "no indexes, db connected or wrong tables data supplied to delete from table indexes";
        }


};

sub _delete_countertable{
    my $self = shift;
    my $indexes_delete=shift;
    my $dbh=$self->_test_db();
    my %atr= (PrintError => 0,
              PrintWarn  => 0,
              RaiseError => 0,
              AutoCommit => 1) ;
    my $table_def=shift|| $self->{_db_tables};
#'indexes'=>{'indexes_tb'=>'indexes','id'=>'id','index'=>'ifindex','id_ip'=>'id_ip','description'=>'description','alias'=>'alias'},
# 'counters'=>{'counters_tb'=>'counters','id'=>'id','timestamp'=>'timestamp','ind_id'=>'ind_id','input'=>'input','output'=>'output'},
    my $cond_table=(exists($table_def->{indexes}->{indexes_tb}) and exists($table_def->{indexes}->{index}) and
            exists($table_def->{indexes}->{id_ip}) and
            exists($table_def->{ip}->{ip_tb}) and exists($table_def->{ip}->{ip}) and exists($table_def->{ip}->{id}) and
            exists($table_def->{counters}->{counters_tb}) and exists($table_def->{counters}->{timestamp}) and
            exists($table_def->{counters}->{ind_id}));
    my $cond_ind=($indexes_delete and (ref($indexes_delete) eq "ARRAY"));
    my $cond_db=($dbh and (ref($dbh) eq "DBI::db"));
    my $sentence='';
    my $res='';
    my ($ind,$ip)=('','');
        if ($cond_ind  and $dbh and $cond_db and $cond_table){
         foreach my $k (@{$indexes_delete}){
           if (ref($k) eq "ARRAY"){
                   ($ind,$ip)=($k->[0],$k->[1]);

         }elsif($k=~/(\d+)[\t\s]+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/){
                   ($ind,$ip)=($1,$2);
         }else{
            return "no indexes or wrong indexes data supplied to delete from table counter";
         }
            $sentence=qq[DELETE FROM $table_def->{counters}->{counters_tb} WHERE
                        $table_def->{counters}->{ind_id} IN
                        (SELECT $table_def->{indexes}->{indexes_tb}.$table_def->{indexes}->{id} FROM $table_def->{indexes}->{indexes_tb}
                                WHERE $table_def->{indexes}->{indexes_tb}.$table_def->{indexes}->{index}=$ind AND
                                $table_def->{indexes}->{indexes_tb}.$table_def->{indexes}->{id_ip} IN
                                (SELECT $table_def->{ip}->{ip_tb}.$table_def->{ip}->{id} FROM $table_def->{ip}->{ip_tb}
                                WHERE $table_def->{ip}->{ip_tb}.$table_def->{ip}->{ip}=INET_ATON('$ip')))];
            $res.= "no one conter for pare  of index $k->[0]  and IP $k->[1] were deleted. Indexes Error: ".DBI->errstr if (!$dbh->do($sentence, \%atr) and DBI->errstr);
         }
            return  $res if $res=~/no/;
            return 'ok all dropped counters were deleted';
        }else{
            return "no indexes, db connected or wrong tables data supplied to delete from table";
        }

};

sub _insert_update_counterstable{
    my $self = shift;
    my $ind_ip=shift; #array ref [[ind,ip],[ind,ip]]
#    my $file_pref=shift ||$self->{_root_dir}.$self->{_main_dir}.$self->{_arch_dir}.$self->{_arch_subdir}.$self->{_oidfile_prefix};
    my $file_pref=shift ||$self->{_root_dir}.$self->{_main_dir}.$self->{_counter_dir}.$self->{_oidfile_prefix};
    my $dbh=$self->_test_db();
    my %atr= (PrintError => 0,
              PrintWarn  => 0,
              RaiseError => 0,
              AutoCommit => 1) ;
    my $table_def=shift|| $self->{_db_tables};
#'indexes'=>{'indexes_tb'=>'indexes','id'=>'id','index'=>'ifindex','id_ip'=>'id_ip','description'=>'description','alias'=>'alias'},
# 'counters'=>{'counters_tb'=>'counters','id'=>'id','timestamp'=>'timestamp','ind_id'=>'ind_id','input'=>'input','output'=>'output'},
    my $cond_table=(exists($table_def->{indexes}->{indexes_tb}) and exists($table_def->{indexes}->{index}) and
            exists($table_def->{indexes}->{id_ip}) and
            exists($table_def->{ip}->{ip_tb}) and exists($table_def->{ip}->{ip}) and exists($table_def->{ip}->{id}) and
            exists($table_def->{counters}->{counters_tb}) and exists($table_def->{counters}->{timestamp}) and
            exists($table_def->{counters}->{ind_id}) and exists($table_def->{counters}->{input}) and exists($table_def->{counters}->{output}));
    my $cond_ind=($ind_ip and (ref($ind_ip) eq "ARRAY"));
    my $cond_db=($dbh and (ref($dbh) eq "DBI::db"));
    my @arr=();
    my $sentence='';
    my $res='';
#    print Dumper($cond_table,$cond_ind, $cond_db, $dbh, $table_def, $ind_ip)," ---YYYYYY \n";
    if ($cond_ind  and $dbh and $cond_db and $cond_table){
        foreach my $k (@{$ind_ip}){
#            print Dumper($k)," ---kkkk\n";
            $sentence=qq[(SELECT $table_def->{indexes}->{indexes_tb}.$table_def->{indexes}->{id} FROM $table_def->{indexes}->{indexes_tb}
                                WHERE $table_def->{indexes}->{indexes_tb}.$table_def->{indexes}->{index}=$k->[0] AND
                                $table_def->{indexes}->{indexes_tb}.$table_def->{indexes}->{id_ip} IN
                                (SELECT $table_def->{ip}->{ip_tb}.$table_def->{ip}->{id} FROM $table_def->{ip}->{ip_tb}
                                WHERE $table_def->{ip}->{ip_tb}.$table_def->{ip}->{ip}=INET_ATON('$k->[1]')))];
#           print Dumper($file_pref.$k->[0].'_'.$k->[1],$sentence), "---SENTENC234 \n";
#           print Dumper(@{[$self->_read_from_file($file_pref.$k->[0].'_'.$k->[1])]})," ----read from file \n";
           @arr = map{eval{$_=~/(\d+)[\s\t]*,[\s\t]*(\d+)[\s\t]*,[\s\t]*(\d+)/; return qq[('$1', '$2', '$3', $sentence)];}}
                            @{[$self->_read_from_file($file_pref.$k->[0].'_'.$k->[1])]};
#           print Dumper(\@arr)," --ARARARARRA \n";
           $sentence=qq[INSERT INTO $table_def->{counters}->{counters_tb}
           ($table_def->{counters}->{timestamp}, $table_def->{counters}->{input}, $table_def->{counters}->{output}, $table_def->{counters}->{ind_id})
            VALUES ${\(join(', ',@arr))}];
#       print Dumper($sentence),"---final SENTENCE \n";
        $res.= "no one of  counters were inserted. Indexes Error: ".DBI->errstr if (!$dbh->do($sentence, \%atr) and DBI->errstr);
        }
        return $res."\n" if $res=~/no/;
        return 'ok all counters inserted';
    }else{
        return "no indexes, db connected or wrong tables data supplied";
    }


};

sub _web_ini{
    my $self=shift;
    $self->{_db_tables}->{clients}={'clients_tb'=>'clients','id'=>'id','name'=>'name','login'=>'login','passwd'=>'passwd', 'session'=>'session'};
    $self->{_db_tables}->{indexes}->{cl_id}='cl_id';
    push(@{$self->{_statement}},qq[CREATE TABLE $self->{_db_tables}->{clients}->{clients_tb} 
	    ($self->{_db_tables}->{clients}->{id} INT(8) unsigned NOT NULL AUTO_INCREMENT,
	    $self->{_db_tables}->{clients}->{name} VARCHAR(255),
	    $self->{_db_tables}->{clients}->{login} VARCHAR(15) NOT NULL, 
	    $self->{_db_tables}->{clients}->{passwd} VARCHAR(15) NOT NULL, 
	    $self->{_db_tables}->{clients}->{session} VARCHAR(255), 
	    PRIMARY KEY ($self->{_db_tables}->{clients}->{id}))], 
	    qq[alter table $self->{_db_tables}->{indexes}->{indexes_tb} add column 
	    $self->{_db_tables}->{indexes}->{cl_id}  INT(8) unsigned NOT NULL  default '0']);
};

1;

#CREATE TABLE 'counters' (
#`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
#'timestamp' INT(4) NOT NULL,
#'input' BIGINT NOT NULL,
#'output' BIGINT NOT NULL,
#'desc_id' INT NOT NULL,
#FOREIGN KEY ('desc_id')
#        REFERENCES descriptions(id)
#)

=pod

=head1 SUPPORT

No support is available

=head1 AUTHOR

Copyright 2012 Anonymous.

=cut
