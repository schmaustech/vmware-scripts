#!/usr/bin/perl
#################################################################################
# Script that prints out status of VMware tools for given DataCenter		#
# (C) Benjamin Schmaus July, 2009						#
################################################################################# 
use strict;
use warnings;
use Socket;
use VMware::VIRuntime;
use VMware::VILib;
use VMware::VIM25Stub;
use Getopt::Long;

### Main Logic ###
my ($help,$prefix,$vcserver,$username,$password,$dc);
my ($esxhost,$vmname,$adhostname,$ipaddress,$toolstat,$guestos,$datastore,$gueststate);
options();
my $url = "https://$vcserver/sdk/vimService";
Vim::login(service_url => $url, user_name => $username, password => $password);
my $datacenter_views = Vim::find_entity_views(view_type => 'Datacenter',filter => { name => $dc });
my $dcds = Vim::find_entity_view(view_type => "Datacenter", filter => {'name' => $dc } );
my $ds = $dcds->datastore;
getclients();
print "\n\n";
Vim::logout();
exit;

sub getclients {
	foreach (@$datacenter_views) {
		my $datacenter = $_->name;
		my $host_views = Vim::find_entity_views(view_type => 'HostSystem',begin_entity => $_ );
		foreach (@$host_views) {
			$esxhost = $_->name;
			my $vm_view = Vim::find_entity_views(view_type => 'VirtualMachine',begin_entity => $_ , filter => { 'guest.guestState' => 'running' });
			foreach (@$vm_view) {
				$vmname = $_->name;
				#print "$vmname\n";
				$adhostname = $_->summary->guest->hostName;
				$ipaddress = $_->summary->guest->ipAddress;
				$toolstat = $_->summary->guest->toolsStatus->val;
				$guestos = $_->summary->guest->guestFullName;
				$datastore = $_->summary->config->vmPathName;
				$gueststate = $_->guest->guestState;
				if ($toolstat !~ /toolsOk/) {
					print "TOOLS STATUS: $toolstat\tVM: $vmname\n";
				}
			}
		}
	}
}

sub options {
        $vcserver="";$username="";$password="";$dc="";
        GetOptions ('h|help'=>\$help,'v|vcserver=s'=>\$vcserver,'u|username=s'=>\$username,'p|password=s'=>\$password,'d|datacenter=s'=>\$dc);
        if ($help) {
                print "Usage: vmtoolchk.pl -v <vc server> -u <username> -p <password> -d <datacenter in vc> \n";
                exit;
        }
        if (($vcserver eq "") || ($username eq "") || ($password eq "") || ($dc eq "")) {
		print "Missing required parameters - Type -help for options\n";
                exit;
        }
}
