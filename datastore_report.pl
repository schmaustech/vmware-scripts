#!/usr/bin/perl -w
#########################################################################################
# This script generates an xls report file of the datastores in Virtual Center		#
# (C) Benjamin Schmaus 06/2009								#
#########################################################################################
use strict;
use warnings;
use VMware::VIRuntime;
use Spreadsheet::WriteExcel;
my $username = "nagios";
my $password = "VMware2009";
my ($datacenter,$dsfree,$dscapacity,$dsname,$dsdevice,$dstype,$message,$mailit,$emails,$dspercent); 
my $prefix = "---";
my $subject = "Weekly_DataStore_Report";
my $counter="2";
my @emails = ('benjamin.schmaus\@baesystems.com');

### Setup Excel Worksheet ###
my $workbook  = Spreadsheet::WriteExcel->new('/tmp/datastore.xls');
my $worksheet = $workbook->add_worksheet();
my $format = $workbook->add_format();
my $header = $workbook->add_format();
create_excel();

Vim::login(service_url => "https://asdmnesxvc2/sdk/vimService", user_name => "$username", password => "$password");
my $dc = Vim::find_entity_views(view_type => 'Datacenter');
foreach (@$dc) {
	$datacenter = $_->name;
	my $ds = $_->datastore;
	my @dslist = ();
	foreach(@$ds) {
		my $ds_ref = Vim::get_view(mo_ref => $_);
        	$dsname = $ds_ref->info->name;
		$dsfree = $ds_ref->summary->freeSpace;
		$dscapacity = $ds_ref->summary->capacity;
		$dspercent = int(($dsfree / $dscapacity) * 100);
		$dsfree = int($dsfree/1073741824);
		$dscapacity = int($dscapacity/1073741824);
		$dstype = $ds_ref->summary->type;
		$dsdevice = $ds_ref->summary->url;
        	if (($ds =~ /$prefix/) && ($prefix ne "---")) {
			#print "$datacenter\t$dsname\t$dsfree\t$dscapacity\t$dstype\t$dsdevice\n";
                	$worksheet->write($counter,0,$datacenter);
                	$worksheet->write($counter,1,$dsname);
                	$worksheet->write($counter,2,$dsfree);
                	$worksheet->write($counter,3,$dscapacity);
			$worksheet->write($counter,4,$dspercent);
                	$worksheet->write($counter,5,$dstype);
                	$worksheet->write($counter,6,$dsdevice);

			++$counter;
		} elsif  ($prefix eq "---") {
                        #print "$datacenter\t$dsname\t$dsfree\t$dscapacity\t$dstype\t$dsdevice\n";
                        $worksheet->write($counter,0,$datacenter);
                        $worksheet->write($counter,1,$dsname);
                        $worksheet->write($counter,2,$dsfree);
                        $worksheet->write($counter,3,$dscapacity);
                        $worksheet->write($counter,4,$dspercent);
                        $worksheet->write($counter,5,$dstype);
                        $worksheet->write($counter,6,$dsdevice);

         		++$counter;
		}
	}
}
$workbook->close();

### Mail Off Results ###
mailit();
exit;

### Setup Excel Format Subroutine ###
sub create_excel {
        $format->set_bold();
        $format->set_size(16);
        $format->set_align('center');
        $header->set_bold();
        $header->set_align('center');
        $worksheet->set_column(0, 1, 20);
        $worksheet->set_column(2, 3, 15);
	$worksheet->set_column(4, 5, 10);
        $worksheet->set_column(6, 6, 50);
        $worksheet->write(1, 0,  'Datacenter', $header);
        $worksheet->write(1, 1,  'Datastore', $header);
        $worksheet->write(1, 2,  'Free Space(GB)', $header);
        $worksheet->write(1, 3,  'Capacity(GB)', $header);
        $worksheet->write(1, 4,  '%Free', $header);
        $worksheet->write(1, 5,  'Type', $header);
	$worksheet->write(1, 6,  'Device Name', $header);
        $worksheet->merge_range('A1:G1','Weekly Datastore Report',$format); 
}

### Mail Subroutine ###
sub mailit {
        $message = `echo "Weekly Datastore Report Attached">/tmp/dsr-body.txt`;
        $message = `echo "">>/tmp/dsr-body.txt`;
        $message = `/usr/bin/uuencode /tmp/datastore.xls datastore.xls > /tmp/dsr-attachment.txt`;
        $message = `cat /tmp/dsr-body.txt /tmp/dsr-attachment.txt > /tmp/dsr.txt`;
        foreach $emails (@emails) {
                $mailit = `/usr/bin/mailx -s $subject $emails < /tmp/dsr.txt`;
        }
}
