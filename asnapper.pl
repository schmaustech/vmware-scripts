#!/usr/bin/perl
#################################################################################
# Script that autodiscovers VM's and places the client name into prexisting     #
# policies based on the datastore names discovered                              #
# (C) Benjamin Schmaus May, 2009                                                #
#################################################################################
use strict;
use warnings;
use Socket;
use VMware::VIRuntime;
use VMware::VILib;
use VMware::VIM25Stub;
use Getopt::Long;
my ($help,$vcserver,$username,$password,$dc,$removesnapshot,$children,$snapshotname);
$children="0";
options();
my $url = "https://$vcserver/sdk/vimService";
Vim::login(service_url => $url, user_name => $username, password => $password);
my $datacenter_views = Vim::find_entity_views(view_type => 'Datacenter',filter => { name => $dc });
list_snapshot();
exit;

sub list_snapshot {
	my $datacenter_views = Vim::find_entity_views(view_type => 'Datacenter',filter => { name => $dc });
   	foreach (@$datacenter_views) {
		my $datacenter = $_->name;
		my $host_views = Vim::find_entity_views(view_type => 'HostSystem',begin_entity => $_ );
		foreach (@$host_views) {
			my $esxhost = $_->name;
			my $vm_view = Vim::find_entity_views(view_type => 'VirtualMachine',begin_entity => $_ , filter => { 'guest.guestState' => 'running' });
			foreach (@$vm_view) {
      				my $mor_host = $_->runtime->host;
      				my $hostname = Vim::get_view(mo_ref => $mor_host)->name;
				my $ref = undef;
				my $nRefs = 0;
      				my $count = 0;
      				my $snapshots = $_->snapshot;
      				if(defined $snapshots) {
         				Util::trace(0,"\nSnapshots for Virtual Machine ".$_->name . " under host $hostname\n");
         				printf "\n%-47s%-16s %s %s\n", "Name", "Date","State", "Quiesced";
         				print_tree ($_->snapshot->currentSnapshot, " ", $_->snapshot->rootSnapshotList);
					if(defined $_->snapshot) {
                                        	($ref, $nRefs) = find_snapshot_name ($_->snapshot->rootSnapshotList, $snapshotname);
                                	}
					if ($snapshotname =~ /$removesnapshot/) {
						print "Snapshot name: $snapshotname matches for delete\n";

      						if (defined $ref && $nRefs == 1) {
        						 my $snapshot = Vim::get_view (mo_ref =>$ref->snapshot);
        						 eval {
            							$snapshot->RemoveSnapshot (removeChildren => $children);
             							Util::trace(0, "\nRemove Snapshot ". $snapshotname . " For Virtual Machine ". $_->name . " under host $hostname" ." completed sucessfully\n");
							};
         						if ($@) {
            							if (ref($@) eq 'SoapFault') {
               								if(ref($@->detail) eq 'InvalidState') {
                  								Util::trace(0,"\nOperation cannot be performed in the current state of the virtual machine");
               								} elsif(ref($@->detail) eq 'HostNotConnected') {
                  								Util::trace(0,"\nhost not connected.");
               								} else {
                  								Util::trace(0, "\nFault: " . $@ . "\n\n");
               								}
            							} else {
               								Util::trace(0, "\nFault: " . $@ . "\n\n");
            							}
         						}
      						} else {
         						if ($nRefs > 1) {
            							Util::trace(0,"\nMore than one snapshot exits with name" ." $snapshotname in Virtual Machine ". $_->name ." under host ". $hostname ."\n");
         						}
         						if($nRefs == 0 ) {
            							Util::trace(0,"\nSnapshot Not Found with name" ." $snapshotname in Virtual Machine ". $_->name ." under host ". $hostname ."\n");
         						}
						}
					}
      				#} else {
         			#	Util::trace(0,"\nNo Snapshot of Virtual Machine ".$_->name ." exists under host $hostname\n");
      				}
			}
		}
	}
}

sub options {
        $vcserver="";$username="";$password="";$dc="";$removesnapshot="";
        GetOptions ('h|help'=>\$help,'v|vcserver=s'=>\$vcserver,'u|username=s'=>\$username,'p|password=s'=>\$password,,'d|datacenter=s'=>\$dc,'sm|snapmatch=s'=>\$removesnapshot);
        if ($help) {
                print "Usage: snapper.pl -v <vc server> -u <username> -p <password> -d <datacenter in vc> -sm <pattern match for snapshot name>\n";
                exit;
        }
        if (($vcserver eq "") || ($username eq "") || ($password eq "") || ($dc eq "") || ($removesnapshot eq "")) {
                print "Missing required parameters - Type -help for options\n";
                exit;
        }

}

sub print_tree {
	my ($ref, $str, $tree) = @_;
   	my $head = " ";
   	foreach my $node (@$tree) {
      		$head = ($ref->value eq $node->snapshot->value) ? " " : " " if (defined $ref);
      		my $quiesced = ($node->quiesced) ? "Y" : "N";
      		$snapshotname = $node->name;
      		printf "%s%-48.48s%16.16s %s %s\n", $head, $str.$node->name,
             	$node->createTime, $node->state->val, $quiesced;
      		print_tree ($ref, $str . " ", $node->childSnapshotList);
   	}
   	return;
}

sub find_snapshot_name {
	my ($tree, $name) = @_;
   	my $ref = undef;
   	my $count = 0;
   	foreach my $node (@$tree) {
      		if ($node->name eq $name) {
         		$ref = $node;
         		$count++;
      		}
      		my ($subRef, $subCount) = find_snapshot_name($node->childSnapshotList, $name);
      		$count = $count + $subCount;
      		$ref = $subRef if ($subCount);
   	}
   	return ($ref, $count);
}
