#!/opt/perl/bin/perl

use SNMP::Info;
use lib '/opt/chronicle/prod/bin';
use Chronicle::NetworkUtil qw(getDeviceByType getShortMgmtName saveConfig fixTruncatedName);
use Chronicle::Util qw(GetCname getShortName inform);
use Chronicle::NetDB qw(getIPbyPort);
use Data::Dumper;
use strict;

my @devices = @ARGV;

#debug level - 'my' hides $v from modules
use vars qw($v);
$v = 0;

inform(2, "Testing\n");

# list of devices to loop over is either gotten from cmd line or the DB
unless (@devices) {
    inform(2, "get by db\n");
    @devices = getDeviceByType(5, 'cisco_switch');
}

foreach my $device (@devices) {

    my $info;
    unless ($info = new SNMP::Info( 
                            # Auto Discover more specific Device Class
                            AutoSpecify => 1,
                            Debug       => 0,
                            # The rest is passed to SNMP::Session
                            DestHost    => $device,
                            Community   => 'public',
                            Version     => '2', 
                          )) {
	print "Can't connect to $device\n";
	next;
    }

    my $err = $info->error();
    if (defined $err) {
        print "SNMP Community or Version probably wrong connecting to device. $err\n";
	next;
    }


    # get interface info
    my $i_name = $info->i_name();
    my $i_type = $info->i_type();
    my $i_alias = $info->i_alias();

    #print Data::Dumper->new([$i_name],["$i_name"])->Indent(1)->Quotekeys(0)->Dump;
    #print Data::Dumper->new([$i_type],["$i_type"])->Indent(1)->Quotekeys(0)->Dump;

    # First, get port->MAC->IP mapping info and set port description to DNS name 
    # of computer (IP) connected to port
    my $days = 1;
    foreach my $iid (keys %$i_name) {

	# Fa0/1 or Gi0/3, etc
	my $port = $i_name->{$iid};

	# we use n=SomeString for manually set port descriptions
	# don't reset manually set descriptions
	my $descrip = $i_alias->{$iid};
	if ($descrip =~ /n=/) {
	    inform(2, "Skippping $device : $port : $descrip\n");
	    next;
	}

	my $type = $i_type->{$iid};
	$type =~ s/-//g;
	#print "debug: $type\n";

	# only do ethernet interfaces, skip Vlans, etc
	# ethernet-csmacd
	next unless ($type =~ /ethernetcsmacd/i);


	# get the IP address on this port
	my @ipData = getIPbyPort($days, $device, $port);
	my $ip;
	my $name;
	# get the DNS name for $ip, if it exists
	if (@ipData) {
	    $ip = $ipData[0];
	    $name = getShortName(GetCname($ip)) || $ip;
	} else {
	    # nothing has been seen on this port in the 
	    # last $days days so reset the description to NULL
	    $name = '';
	}

	#print "$device:$port -> $name\n";
	inform(2, "$device:$port -> $name\n") if ($name);

        unless ($info->set_i_alias($name, $iid)) {
            $err = $info->error();
            print "Couldn't set alias for $device:$port:$name - $err\n";
            next;
        }
    }

    # Second, get CDP Neighbor info
    my $c_if       = $info->c_if();
    my $c_ip       = $info->c_ip();
    my $c_name	   = $info->c_id();

    # set port desciption for ports that have CDP neighbors
    foreach my $iid (keys %$c_if) {
	# ifTable and cdpTable are indexed different
	# get the ifIndex for this interface
	my $key = $c_if->{$iid};

	# don't reset manually set descriptions
	my $descrip = $i_alias->{$key};
	if ($descrip =~ /n=/) {
	    inform(2, "Skippping $device : $i_name->{$key} : $descrip\n");
	    next;
	}
	# use ifName since the cdp port (c_port) doesn't seem to be reliable
 	my $l_port = $i_name->{$key};
	my $neighbor_ip = $c_ip->{$iid};
	# use cdp reported name or DNS or IP address
	my $neighbor_name = getShortMgmtName(fixTruncatedName($c_name->{$iid}));
	$neighbor_name = $neighbor_name || getShortMgmtName(GetCname($neighbor_ip)) || $neighbor_ip;

	inform(2, "$device:$l_port -> ");
	inform(2, "$neighbor_name\n") if (defined $neighbor_name);

	unless (defined $neighbor_name) {
	    print "No neighbor name for $device:$l_port\n";
	    next;
	}

	# set the port description
	unless ($info->set_i_alias($neighbor_name, $key)) {
	    $err = $info->error();
	    print "Couldn't set alias for $device:$l_port:$neighbor_name - $err\n";
	    next;
	}
    }

    unless (saveConfig($device)) {
        print "Couldn't save config: $device\n";
        next;
    }
}
