#!/usr/bin/perl -w
## $Id: check_aide.pl 2211 2016-01-10 14:25:21Z julien $
# nagios: -epn
## get some quick stats from aide/HIDS log file to nagios w perfdata
##
## https://nagios-plugins.org/doc/guidelines.html
## FIXME! if aide.log empty and non-empty error.log: configuration error
##	+ warning/critical threshold
## Note: have to adjust aide.log rotating settings to be 644 in /etc/cron.daily/aide
## $ sudo install -m 755 /Users/julien/script/ext/check_aide.pl /opt/local/libexec/nagios/

use warnings;
use strict;

my ($total, $add, $rm, $ch, $host, $info, $f, $strf);

if ($^O eq 'linux') {
        use lib '/usr/lib/nagios/plugins';
	## Note: debian permission are 640 by default
	## need to adjust /etc/cron.daily/aide
	$f = '/var/log/aide/aide.log';
	## ubuntu 12.04
	#$strf = 'files';
	## ubuntu 14.04
	$strf = 'entries';
} elsif ($^O eq 'darwin') {
        use lib '/opt/local/libexec/nagios';
	$f = '/opt/local/var/log/aide/aide.log';
	$strf = 'files';
}

### Nagios plugins elements

use utils qw(%ERRORS &print_revision &support &usage);
use Getopt::Long;

my $VERSION = '0.1';

my $RET = 'OK';
my $TIMEOUT = 60;
my $DEBUG = 0;

sub print_usage ();

my ($help,$version);
GetOptions(    help => \$help,
		debug => \$DEBUG,
		version => \$version,
		'timeout=s' => \$TIMEOUT,
		'file=s' => \$f
);
my ($PROGNAME) = $0 =~ m#.*/(.*)#;

if ($help) {
        print_revision($PROGNAME,"\$Rev\$");
        print "Copyright (c) 2014 Julien <julien.t43+nagiosplugins\@gmail.com>

        Perl Check aide.log plugin for Nagios

";
        print_usage();
        exit($ERRORS{OK});
}

if ($version) {
        print_revision($PROGNAME,"\$Revision\$ $VERSION ");
        exit($ERRORS{OK});
}

$SIG{'ALRM'} = sub {
        print ("ERROR: Timeout\n");
        exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

sub print_usage () {
        print "Usage: $PROGNAME [--debug] [--version] [--help]"
                        ." [--file /path/aide.log] [--timeout=$TIMEOUT]\n";
}

## main part

$total = $add = $rm = $ch = $host = '';
if (-f $f) {

	open(FILE, "$f") or die "Can't open file $f: $!\n";
	while (<FILE>) {
		if (/Total number of $strf:\s+(\d+)/) {
			$total = $1;
		} elsif (/Added $strf:\s+(\d+)/) {
			$add = $1;
		} elsif (/Removed $strf:\s+(\d+)/) {
			$rm = $1;
		} elsif (/Changed $strf:\s+(\d+)/) {
			$ch = $1;
		} elsif (/aide run on (.*?) started at/) {
			$host = $1;
		}
	}
	$info = "Add/Deleted/Changed files $add/$rm/$ch on total $total files from $host: '$f'";

} else {
	$RET = 'CRITICAL';
	$info = "file '$f' does not exist!";
}

close(FILE);
print "$RET $info | total=$total add=$add del=$rm change=$ch\n";
exit $ERRORS{$RET};


