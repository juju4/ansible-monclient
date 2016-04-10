#!/usr/bin/perl
#!/opt/local/bin/perl5.16
## 	check snort or suricata alerts for nagios
# nagios: -epn
## NEED: perl, libdatetime-format-strptime-perl
##	sudo chmod 2751 /var/log/snort
## FIXME! time interval check

use strict;
use warnings;
use DateTime::Format::Strptime;

#--------------------------- Variables ------------------------------
my $alert_log;
if ($^O eq 'linux') {
        use lib '/usr/lib/nagios/plugins';
	$alert_log="/var/log/snort/alerts";
	if (! -f $alert_log) {
		$alert_log = '/var/log/snort/alert.fast';
	}

} elsif ($^O eq 'darwin') {
        use lib '/opt/local/libexec/nagios';
	$alert_log="/opt/local/var/log/snort/snort.fast";
	#$alert_log="/opt/local/var/log/suricata/fast.log";	## timestamp is different format else same
}


# What level is critical for you?
my $priority="1";

#--------------------------- Plugins ------------------------------

use utils qw(%ERRORS &print_revision &support &usage);
use Getopt::Long;

my $VERSION = '0.1';

my $RET = 'OK';
my $TIMEOUT = 60;
my $DEBUG = 0;
my $nagwarn = 10;
my $nagcrit = 50;
#my $interval = 5;	# last 5min ?
my $interval = 60*24;	# last 24h?

sub print_usage ();

my ($help,$version);
GetOptions(	help => \$help,
		debug => \$DEBUG,
		version => \$version,
		'timeout=s' => \$TIMEOUT, 't=s' => \$TIMEOUT,
		'warning=s' => \$nagwarn, 'w=s' => \$nagwarn,
		'critical=s' => \$nagcrit, 'c=s' => \$nagcrit,
		'interval=s' => \$interval, 'i=s' => \$interval,
		'file=s' => \$alert_log , 'f=s' => \$alert_log
);
my ($PROGNAME) = $0 =~ m#.*/(.*)#;

if ($help) {
        print_revision($PROGNAME,"\$Rev\$");
        print "
        Perl Check Snort alerts file plugin for Nagios

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
                        ." [--timeout=$TIMEOUT]"
			." [-w warningcount] [-c criticalcount]"
			." [--interval|-i interval]"
			." [--file|-f file]\n"
			."\nInterval to the number of minutes you want to check compare to current time (default 24h).\nBy default, input file is snort.fast log file, but can be used for suricata fast.log too.\n";
}

#---------------------------- Parser --------------------------------

my $msg="";
my @alertstype = ();
my $count = 0;
my $logtype = 'snort';

## http://datetime.mongueurs.net/Perl/faq.html		snort: 04/24-04:49:25.113251
my $analyzer;
my $dt;

print "Starting to check $alert_log\n" if $DEBUG;
if (-f $alert_log) {
	if ($alert_log =~ m/suricata/) {
		$logtype = 'suricata';
		$analyzer = DateTime::Format::Strptime->new( pattern => '%m/%d/%Y-%H:%M:%S' );
	} else {
		$analyzer = DateTime::Format::Strptime->new( pattern => '%Y %m/%d-%H:%M:%S' );
	}
	## FIXME! will probably cause issue during new year but ... why snort log without
	#my $dt = DateTime->new( year => DateTime->now->year );
	my $current_year = DateTime->now->year;
	my $now = DateTime->now;
	my ($logtime, $logmin);

	open(FILE, "$alert_log") or die "Can't open file $alert_log: $!\n";
	while (<FILE>) {
		if (m/(.*)\..*?\[\*\*\] \[[0-9:]*\] (.*) \[\*\*\] (.*) \[Priority: (\d+)\]/) {
			
			#if ($interval && $analyzer->parse_datetime($1) >= $now - DateTime::Duration->new( minutes => $interval)) {
			#$logtime = $analyzer->parse_datetime($current_year.' '.$1);
			#$logmin = $now - DateTime::Duration->new( minutes => $interval );
			#print "Time ($1): $logtime vs $logmin\n" if $DEBUG;
			if ($interval && $analyzer->parse_datetime($current_year.' '.$1) >= $now - DateTime::Duration->new( minutes => $interval)) {
			#if ($interval && $logtime >= $logmin) {
				if ($4 >= $priority) {
					print "New alerts (I): $_\n" if $DEBUG;
					$alertstype[$4]{$2}++;
					$count++;
				}
			} elsif (!$interval) {
				if ($4 >= $priority) {
					print "New alerts: $_\n" if $DEBUG;
					$alertstype[$4]{$2}++;
					$count++;
				}
			}
		}
        }
	close(FILE);
	use Data::Dumper;
	print Dumper(\@alertstype) if $DEBUG;
	my @alertsprio = sort {$b cmp $a} keys @alertstype;
	#for my $l (0..$#alertstype) {
	for my $l (@alertsprio) {
		## FIXME! select top 3 alerts?
		foreach my $alert (keys %{$alertstype[$l]}) {
          		$msg=$msg."[P=$l '$alert'](x".($alertstype[$l]{$alert}).")";
		}
	}
	if (length($msg) >= 100) {
		$msg = substr($msg, 0, 200).'...';
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
	$msg = "No snort alerts found";
}else{
	$msg = "$count snort alerts found with level >= $priority: $msg";
	if ($count >= $nagcrit) {
		$RET = 'CRITICAL';
	} elsif ($count >= $nagwarn) {
		$RET = 'WARNING';
	}
}
if ($interval) {
	$msg .= " in last $interval min";
}

print "$RET $msg | alerts=$count;$nagwarn;$nagcrit minlevel=$priority interval=$interval\n";
exit $ERRORS{$RET};

