#!/usr/bin/perl -w
# nagios: -epn
## from http://blog.kintoandar.com/2011/01/nagios-nrpe-ossec-check.html
## 201405 customized by Julien <julien.t43+nagiosplugins@gmail.com>
## FIXME! check log file is current/not too old or interval time
## install on debian
##	sudo install -m 755 check_ossec.pl /usr/lib/nagios/plugins/
##	sudo usermod -G ossec nagios

######################
# blog.kintoandar.com
######################

use strict;
use warnings;

#--------------------------- Variables ------------------------------
my $alert_log;
if ($^O eq 'linux') {
        use lib '/usr/lib/nagios/plugins';
	# Where is the ossec alert.log?
	# (nagios must belong to ossec /etc/group so it can open the log)
	#my $alert_log="/opt/ossec/logs/alerts/alerts.log";
	$alert_log="/var/ossec/logs/alerts/alerts.log";

} elsif ($^O eq 'darwin') {
	## macports location + Add nagios to ossec group
	## $ sudo dseditgroup -o edit -a nagios -t user ossec
        use lib '/opt/local/libexec/nagios';
	$alert_log="/opt/local/var/ossec/logs/alerts/alerts.log";
}
## DEBUG
#$alert_log="/tmp/alerts.log";


# What level is critical for you?
my $critical="7";

#--------------------------- Plugins ------------------------------

use utils qw(%ERRORS &print_revision &support &usage);
use Getopt::Long;

my $VERSION = '0.1';

my $RET = 'OK';
my $TIMEOUT = 60;
my $DEBUG = 0;
my $nagwarn = 10;
my $nagcrit = 50;

sub print_usage ();

my ($help,$version);
GetOptions(	help => \$help,
		debug => \$DEBUG,
		version => \$version,
		'timeout=s' => \$TIMEOUT, 't=s' => \$TIMEOUT,
		'warning=s' => \$nagwarn, 'w=s' => \$nagwarn,
		'critical=s' => \$nagcrit, 'c=s' => \$nagcrit
);
my ($PROGNAME) = $0 =~ m#.*/(.*)#;

if ($help) {
        print_revision($PROGNAME,"\$Rev\$");
        print "
        Perl Check ossec alerts plugin for Nagios

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
                        ." [--timeout=$TIMEOUT] -w warningcount -c criticalcount\n";
}

#---------------------------- Parser --------------------------------

my $msg="";
my @alertstype = ();
my $count = 0;

print "Starting to check $alert_log\n" if $DEBUG;
if (-f $alert_log) {

	open(FILE, "$alert_log") or die "Can't open file $alert_log: $!\n";
	while (<FILE>) {
		if (m/Rule: (\d+) \(level (\d+)\) -> '(.*)'/) {
			if ($2 >= $critical) {
				print "New alerts: $_\n" if $DEBUG;
				$alertstype[$2]{$3}++;
				$count++;
			}
		}
        }
	close(FILE);

	#use Data::Dumper if $DEBUG;
	use Data::Dumper;
	print Dumper(\@alertstype) if $DEBUG;
	for my $l (0..$#alertstype) {
		foreach my $alert (keys %{$alertstype[$l]}) {
          		$msg=$msg."[level=$l '$alert'](x".($alertstype[$l]{$alert}).")";
		}
	}
	print "Close file $alert_log ($count)\n" if $DEBUG;
} else {
	$RET = 'CRITICAL';
	$msg = "file '$alert_log' does not exist or can't access it!";
	print "$RET $msg\n";
	exit $ERRORS{$RET};
}

#-------------------------- Send to Nagios ---------------------------
if ($count < 1){
	$msg = "No security threats found";
}else{
	$msg = "$count alerts found with level >= $critical: $msg";
	if ($count >= $nagcrit) {
		$RET = 'CRITICAL';
	} elsif ($count >= $nagwarn) {
		$RET = 'WARNING';
	}
}

print "$RET $msg | alerts=$count;$nagwarn;$nagcrit minlevel=$critical\n";
exit $ERRORS{$RET};

