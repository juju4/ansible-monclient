#!/usr/bin/perl -w
#!/opt/local/bin/perl -w
## $Id: check_updates.pl 2211 2016-01-10 14:25:21Z julien $
## http://nagios.sourceforge.net/docs/3_0/embeddedperl.html
# nagios: -epn
##
## Check unix security updates: debian/ubuntu, macosx
##
## from http://exchange.nagios.org/directory/Plugins/Operating-Systems/Linux/check-debian-packages/details
##	combined w http://exchange.nagios.org/directory/Plugins/Operating-Systems/Linux/check_ubuntu_packages-2Epatch/details
## alternatives
## 	http://superuser.com/questions/199869/check-number-of-pending-security-updates-in-ubuntu
##
## dest path: ubuntu: /usr/lib/nagios/plugins/
##	mac: install -m 755 /Users/touche/script/ext/check_updates.pl /opt/local/libexec/nagios/
## NEED: libhtml-strip-perl / p5-html-strip
#
# check_debian_packages - nagios plugin
#
#
# Copyright (C) 2005 Francesc Guasch
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# Report bugs to: frankie@etsetb.upc.edu
#
use strict;
use warnings;

if ($^O eq 'linux') {
	use lib '/usr/lib/nagios/plugins';
} elsif ($^O eq 'darwin') {
	# macports
	use lib '/opt/local/libexec/nagios';
}

use utils qw(%ERRORS &print_revision &support &usage);
use Getopt::Long;

my $VERSION = '0.07';

my $RET = 'OK';
#my $TIMEOUT = 60;
my $TIMEOUT = 180;	## Mac/Darwin softwareupdate is usually a bit slow...
			## Alternative: scheduled task to do 'softwareupdate -l'
my $DEBUG	= 0;

## for debian/ubuntu
my $LOCK_FILE = "/var/lib/dpkg/lock";
my $CMD_APT = "/usr/bin/apt-get -s upgrade";
#my $CMD_APT = "/usr/bin/aptitude -v -s -y safe-upgrade";
#my $CMD_APT = "/usr/lib/update-notifier/apt-check";

## FIXME! for Macosx/Darwin: if true, executing script read previously generated value(quicker) and fork a process to regen values
my $enable_pregenerate = 0;
use File::Temp qw/ tempfile tempdir /;
my $tmp_file = '/tmp/check_update-values.tmp';

#####################################################################
#
# Command line arguments
#

sub print_usage ();

my ($help,$version);
GetOptions(    help => \$help,
			  debug => \$DEBUG,
		    version => \$version,
		'timeout=s' => \$TIMEOUT
);
my ($PROGNAME) = $0 =~ m#.*/(.*)#;

if ($help) {
	print_revision($PROGNAME,"\$Revision: 2211 $VERSION \$");
	print "Copyright (c) 2005 Francesc Guasch - Ortiz

	Perl Check debian packages plugin for Nagios

";
	print_usage();
	exit($ERRORS{OK});
}

if ($version) {
	print_revision($PROGNAME,"\$Revision: 2211 $VERSION \$");
	exit($ERRORS{OK});
}

#
# unlikely but compliant
#
$SIG{'ALRM'} = sub {
	print ("ERROR: Timeout\n");
	exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);


######################################################################
#
# subs
#

sub print_usage () {
	print "Usage: $PROGNAME [--debug] [--version] [--help]"
			." [--timeout=$TIMEOUT]\n";
}

sub trim($) {
        my $string = shift;
        if ($string) {
                $string =~ s/^\s+//;
                $string =~ s/\s+$//;
        }   
        return $string;
}

sub add_info {
	my ($info,$perfdata, $type,$pkg) = @_;
	if ($$info) {
		$$info .= '; ';
	}	
	$$info .= scalar(keys %$pkg)." new pkgs in $type";
	$$perfdata .= " $type=".(keys %$pkg);
	if (keys %$pkg > 0 && keys %$pkg< 5 ) {
		$$info .= ':';
		$$info .= join " ",keys %$pkg," ";
	} elsif (keys %$pkg >= 5) {
		$$info .= ':';
		my $alguns = join " ",keys %$pkg;
		$alguns = substr($alguns,0, 50);
		$alguns .= "... ";
		$$info .= $alguns;
	}
}

sub exit_unknown {
	my ($info) = @_;
	chomp $info;
    $RET='UNKNOWN';
    print "$RET: $info\n";
    exit $ERRORS{$RET};
};

sub run_apt {
	my ($pkg,$ver,$type,$release);
	my $distrib = shift;
	open APT,"$CMD_APT 2>&1|" or exit_unknown("Can't execute apt command: $!");
	my (%stable,%updates,%backports,%security,%other);

	while (<APT>) {
		print "APT: $_" if $DEBUG;
		exit_unknown($_) if /(Could not open lock file)|(Could not get lock)/;
		next unless /^Inst/;
		($pkg,$ver,$release) = /Inst (.*?) .*\((.*?) (.*?)\)/;
		print "$_\npkg=$pkg ver=$ver release=$release\n" if $DEBUG;
		die "$_\n" unless defined $release;
		if ($distrib eq 'debian') {
			$release = 'stable'  
					if $release =~ /stable$/ && $release !~/security/i;
			$release = 'security' 
					if $release =~ /security/i;
		} elsif ($distrib eq 'ubuntu') {
			$release = 'updates'  
					if $release =~ /updates/;
			$release = 'backports'  
					if $release =~ /backports/;
			$release = 'security' 
					if $release =~ /security/i;
		}
	
		if ($release eq 'stable') {
			$stable{$pkg} = $ver;
		} elsif ($release eq 'security') {
			$security{$pkg} = $ver;
		} elsif ($release eq 'updates') {
			$updates{$pkg} = $ver;
		} elsif ($release eq 'backports') {
			$backports{$pkg} = $ver;
		} else {
			$other{$pkg}=$ver;
		}
	}
	close APT;
	my $info = '';
	my $perfdata = '|';
	if (keys (%security)) {
		$RET = 'CRITICAL';
		add_info(\$info,\$perfdata, 'security',\%security);
	} else {
		add_info(\$info,\$perfdata, 'security', () );
	}
	if ((keys (%other) or keys(%stable)) and $distrib eq 'debian') {
    		$RET = 'WARNING';
		add_info(\$info,\$perfdata, 'stable',\%stable);
		add_info(\$info,\$perfdata, 'other',\%other) if keys %other;
	} elsif ($distrib eq 'debian') {
		add_info(\$info,\$perfdata, 'stable', () );
		
	}
	if ((keys (%other) or keys(%updates)) and $distrib eq 'ubuntu') {
    		$RET = 'WARNING';
		add_info(\$info,\$perfdata, 'updates',\%updates);
		add_info(\$info,\$perfdata, 'other',\%other) if keys %other;
		add_info(\$info,\$perfdata, 'backports',\%backports) if keys %backports;
	} elsif ($distrib eq 'ubuntu') {
		add_info(\$info,\$perfdata, 'updates', () );
	}
	if ($info eq '') { $info = 'No updates pending'; }
	my ($total); 
	$total = 0;
	my $CMD_SW = "dpkg -l";
	open OUT,"$CMD_SW 2>&1|" or exit_unknown("Can't execute '$CMD_SW' command: $!");
	while (<OUT>) {
		if (m/^ii/) {
			$total += 1;
		}		
	}
	$perfdata .= " totalpkg=$total";
	print "$RET: $info $perfdata\n";
}

sub run_mac_softwareupdate {
	my $info = '';
	my $perfdata = '|';

	## Note: only listed Apple software, even if AppStore has some more...
	my $CMD_SW = "/usr/sbin/softwareupdate -l";
	open OUT,"$CMD_SW 2>&1|" or exit_unknown("Can't execute '$CMD_SW' command: $!");
	my (%updates,%recommended, $pkg, $release, $ver);
	$release = $ver = '';

	while (<OUT>) {
		print "SW: $_" if $DEBUG;
		if (!$pkg) {
			next unless /^   \* /;
			#next unless /^$/;
			#($pkg) = /^   \* (.*) $/;
			if (m/^   \* (.*)/) {
				$pkg = ($1);
			}
			print "$_ => pkg=$pkg\n" if $DEBUG;
			#die "$_\n" unless defined $pkg;
		} else {
			if ($pkg && m/\((.*)\), .*K \[recommended\]/i) {
			#if ($pkg && m/\[recommended\]/i) {
			#if ($pkg && m/\[recommended\]/i) {
				$release = 'recommended' ;
				$ver = $1;
				print "$_ ==>pkg=$pkg ver=$ver release=$release\n" if $DEBUG;
			} elsif ($pkg && $release =~ m/^.* \((.*)\), .*K/i) {
				$release = 'updates' ;
				$ver = $1;
				print "$_ ==>pkg=$pkg ver=$ver release=$release\n" if $DEBUG;
			}
		}
		if ($pkg && $release eq 'recommended') {
			$recommended{$pkg} = $ver;
			$pkg = '';
		} elsif ($pkg && $release eq 'updates') {
			$updates{$pkg}=$ver;
			$pkg = '';
		}
	}
	close OUT;
	if (keys (%recommended)) {
		$RET = 'CRITICAL';
		add_info(\$info,\$perfdata, 'recommended',\%recommended);
		add_info(\$info,\$perfdata, 'updates',\%updates);
	} elsif (keys (%updates)) {
    		$RET = 'WARNING';
		add_info(\$info,\$perfdata, 'recommended',\%recommended);
		add_info(\$info,\$perfdata, 'updates',\%updates);
	} else {
		$info .= 'No new system software updates; ';
		$perfdata .= ' recommended=0 updates=0';
	}
	return($RET,$info,$perfdata);
}

sub run_macports {
	## FIXME! for some reason, on my test setup, it seems I always get 1 outdated port... (call through nrpe, direct call or sudo nagios correct)
	my $CMD_MP = "/opt/local/bin/port -q outdated";
	open OUT,"$CMD_MP 2>&1|" or exit_unknown("Can't execute '$CMD_MP' command: $!");
	my (%macports, $pkg, $release, $ver);
	$release = $ver = '';
	my $info = '';
	my $perfdata = '';
	
	while (<OUT>) {
		print "MP: $_" if $DEBUG;
		($pkg,$ver,$release) = /(.*?)\s+(.*?) \< (.*?)/;
		print "$_ =>pkg=$pkg ver=$ver release=release\n" if $DEBUG;
		$macports{$pkg}=$ver;
	}
	my ($total,$inactive); 
	$total = $inactive = 0;
	$CMD_MP = "/opt/local/bin/port -q installed";
	open OUT,"$CMD_MP 2>&1|" or exit_unknown("Can't execute '$CMD_MP' command: $!");
	while (<OUT>) {
		$total += 1;
	}
	$CMD_MP = "/opt/local/bin/port -q installed inactive";
	open OUT,"$CMD_MP 2>&1|" or exit_unknown("Can't execute '$CMD_MP' command: $!");
	while (<OUT>) {
		$inactive += 1;
	}
	close OUT;

	if (keys (%macports)) {
	    	$RET = 'WARNING';
		add_info(\$info,\$perfdata, 'macports',\%macports);
	} else {
		if ($info) { $info .= '; '; }	
		$info .= 'No outdated ports in macports';
		$perfdata .= ' macports=0';
	}
	$perfdata .= " macportstotal=$total macportsinactive=$inactive";
	return($RET,$info,$perfdata);
}

if ($^O eq 'linux') {
	my $pm;

	do{
	    if (-x qx(type -p $_ | tr -d "\n")) {
	        $pm = $_;
	        last;
	    }
	} for qw/apt-get aptitude yum emerge pacman urpmi zypper/;

	if ($pm) { print $pm };

	my $distrib;
	if (-f "/etc/os-release" ) {
		open(OSR, "/etc/os-release") or die("Can't open file /etc/os-release.");
		while (my $line = <OSR>) {
			if ($line =~ /NAME="Ubuntu"/) {
				$distrib = "ubuntu";
			} elsif ($line =~ /NAME="Debian"/) {
				$distrib = "debian";
			}
		}
	} elsif (-f "/etc/debian-release") {
		$distrib = "debian";
	}

	#if ($pm eq 'apt-get') {
	if ($distrib eq 'debian' or $distrib eq 'ubuntu') {
		print "DEBUG $distrib\n" if $DEBUG;
		run_apt($distrib);
	}

} elsif ($^O eq 'darwin' && $enable_pregenerate == 0) {

	my ($RET,$info,$perfdata) = run_mac_softwareupdate();

	if (-d '/opt/local/etc/macports') {
		my ($RET2,$info2,$perfdata2) = run_macports();
		$info .= $info2;
		$perfdata .= $perfdata2;
	}
	print "$RET: $info $perfdata\n";

#} elsif ($^O eq 'openbsd') {
#need to check http://www.openbsd.org/errataXX.html
} elsif ($^O eq 'darwin' && $enable_pregenerate == 1) {

	my ($info,$perfdata);

	use Storable;
	my $RET = retrieve $tmp_file;
	my $string = retrieve $tmp_file;
	## cleaning, just in case
	use HTML::Strip;
  	my $hs = HTML::Strip->new();
  	my $str = $hs->parse( $string );
  	$hs->eof;
	if ($RET ne 'OK' && $RET ne 'WARNING' && $RET ne 'CRITICAL' && $RET ne 'UNKNOWN') {
		$RET = 'UNKNOWN';
		$str .= 'WARNING! RET seems to have been tampered...';
	}
	
	print "$RET: $str\n";

	## fork process to generate next value
		$string = "$info $perfdata";
		store \$RET, $tmp_file;
		store \$string, $tmp_file;
}

exit $ERRORS{$RET};
