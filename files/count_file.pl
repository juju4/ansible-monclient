#!/usr/bin/perl -w
# nagios: -epn
## $Id: count_file.pl 2211 2016-01-10 14:25:21Z julien $
##	julien.t43+nagiosplugins@gmail.com
##
## modified from http://answers.tveasy.co.uk/c.l.p.misc/count-fd.htm
## 	http://exchange.nagios.org/directory/Plugins/Operating-Systems/Linux/count_file/details
## FIXME! pnp4nagios template, recursive option, file pattern matching
## Ubuntu 12.04
##	syslog: "kernel: [  187.819487] non-matching-uid symlink following attempted in sticky world-writable directory by"
##	not triggered by manual call, on /tmp or elsewhere
##	http://utcc.utoronto.ca/~cks/space/blog/linux/Ubuntu1204Symlinks
##	try to remove cups temporary user symlink...

use warnings;
use strict;

$ENV{'PATH'}='';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';

if ($^O eq 'linux') {
        use lib '/usr/lib/nagios/plugins';
} elsif ($^O eq 'darwin') {
        use lib '/opt/local/libexec/nagios';
}

### Nagios plugins elements

use utils qw(%ERRORS &print_revision &support &usage);
use Getopt::Long;

my $VERSION = '0.2';

my $RET = 'OK';
my $TIMEOUT = 60;
my $DEBUG = 0;

sub print_usage ();

my ($help,$version,$warn,$crit,$dir,$dirwarn,$dircrit,$opt_r,$opt_pattern);
GetOptions(    help => \$help,
		debug => \$DEBUG,
		version => \$version,
		'timeout=s' => \$TIMEOUT,
		'd=s' => \$dir, 'directory=s' => \$dir,
		'w=s' => \$warn, 'warn=s' => \$warn,
		'c=s' => \$crit, 'crit=s' => \$crit,
		'x=s' => \$dirwarn, 'swarn=s' => \$dirwarn,
		's=s' => \$dircrit, 'scrit=s' => \$dircrit,
		r => \$opt_r, 'recursive' => \$opt_r,
		'm=s' => \$opt_pattern, 'match=s' => \$opt_pattern,
);
my ($PROGNAME) = $0 =~ m#.*/(.*)#;

if ($help) {
        print_revision($PROGNAME,"\$Rev\$");
        print "Copyright (c) 2014 Julien <julien.t43+nagiosplugins\@gmail.com>

        Perl count files plugin for Nagios

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
                        ." -d|--directory directory"
                        ." -w|--warn [minwarn|minwarn:maxwarn]"
                        ." -c|--crit [mincrit|mincrit:maxcrit]"
                        ." -x|--swarn [maxsizewarn]"
                        ." -s|--scrit [maxsizecrit]"
			."\n";
        print "   examples: $0 -d dir -w 1 -c 10\n";
        print "   examples: $0 -d dir -w 3:10 -c 1:3\n\n";
        print "A good application would be to monitor log directories, crash or tmpdir.\n";
}

### main part

if($#ARGV+1 >=3 || !$dir || !$crit || !$warn){
        print_usage();
        exit($ERRORS{OK});
} elsif (! -d $dir){
        print ("Unknown: dir doesn't exist: $dir\n");
        exit $ERRORS{"UNKNOWN"};
}

my ($maxwarn,$maxcrit,$minwarn,$mincrit);
$maxcrit = $crit;
if ($crit =~ m/([0-9]+):([0-9]+)/) {
        $mincrit = $1;
        $maxcrit = $2;
}
$maxwarn = $warn;
if ($warn =~ m/([0-9]+):([0-9]+)/) {
        $minwarn = $1;
        $maxwarn = $2;
}

my ($count, $msg);

opendir DIR, $dir or die "Could not opendir $dir; Reason: $!";

my @files = grep !/^\.\.?$/ => readdir DIR;
$count = @files ;

closedir DIR;

## get size in KBytes (Note: can be not that precise, and remember du/ls output can be different due to block occupation/slack space)
my $dirsize;
use File::Find;
## catch error message w subdir: Permissions denied
no warnings 'File::Find';
find(sub{ -f and ( $dirsize += -s ) }, $dir );
$dirsize = int($dirsize / 1024);

if ($count>$maxcrit) {
        $msg = "Filecount of '$dir' too large $count > $maxcrit";
	$RET = 'CRITICAL';
} elsif (defined($mincrit) && $count < $mincrit) {
        $msg = "Filecount of '$dir' too small $count < $mincrit";
	$RET = 'CRITICAL';
} elsif ($dircrit && $dirsize>$dircrit) {
        $msg = "Size of '$dir' too large $dirsize > $dircrit";
	$RET = 'CRITICAL';
} elsif ($count>$maxwarn) {
        $msg = "Filecount of '$dir' $count > $maxwarn";
	$RET = 'WARNING';
} elsif (defined($minwarn) && $count < $minwarn) {
        $msg = "Filecount of '$dir' $count < $minwarn";
	$RET = 'WARNING';
} elsif ($dirwarn && $dirsize>$dirwarn) {
        $msg = "Size of '$dir' $dirsize > $dirwarn";
	$RET = 'WARNING';
} else {
	$msg = "Filecount of '$dir' $count, Size $dirsize KB";
	$RET = 'OK';
}

if (!$dirwarn) { $dirwarn = 0; }
if (!$dircrit) { $dircrit = 0; }
## label=value[UOM];[warn];[crit];[min];[max] https://nagios-plugins.org/doc/guidelines.html#AEN200
my $perf_counter = "| filecount=$count;$warn;$crit;0 dirsize=$dirsize;$dirwarn;$dircrit;0";

print "$RET $msg $perf_counter\n";
exit $ERRORS{$RET};

