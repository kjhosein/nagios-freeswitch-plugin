#! /usr/bin/perl -w

# check_freeswitch_health.pl
#
# Written by Khalid J Hosein, kjh@pobox.com
# July 2013
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Many thanks to Ton Voon for writing the original Nagios::Plugin Perl module
#   http://search.cpan.org/~tonvoon/Nagios-Plugin-0.36/
# New plugin maintained by Nagios Plugin dev team: Nagios::Monitoring::Plugin
#   https://metacpan.org/pod/Nagios::Monitoring::Plugin
#
# Remember to modify the $fs_cli_location variable below to suit your install.
#
# The queries that you can pass to this plugin *resemble* but *do not*
# completely match queries that you can give fs_cli (in the -x argument)
# The reason for this is that those queries sometimes spit back too
# much data to process in one Nagios check. Additionally, they've all
# been transformed to hyphenated versions in order not to trip up NRPE.
#
# Note that since it's less complicated for Nagios to deal with one check at a 
# time, this script only accepts one (1) -q query.
#
# Checks that you can run currently and what type of results to expect:
#  sofia-status-internal - looks for the 'internal' Name and expects to
#       find a state of RUNNING. Sets the result to 1 if successful, 0 otherwise.
#       You'll need to set -c 1:1 (or -w 1:1) in Nagios if you want to
#       alert on it. See Nagios Thresholds for more info:
#       http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT
#       This check also returns # of calls as performance data.
#  sofia-status-external - looks for the 'external' Name and expects to
#       find a state of RUNNING. Same format as the 'internal' test above.
#  show-calls-count - reports total # of current calls.
#  sofia-status-profile-internal-failed-calls-in - reports the FAILED-CALLS-IN
#       parameter in the 'sofia status profile internal' query.
#  sofia-status-profile-internal-failed-calls-out - reports the FAILED-CALLS-OUT
#       parameter in the 'sofia status profile internal' query.
#  show-registrations-count - reports total # of current registrations.
#

# TO DO IN FUTURE VERSIONS:
# 1. (DONE) Include an option (perhaps -a) to list all allowed queries.
#       Decided to refer the user back to the docs in the comments.
# 2. (DONE) Remove excess whitespace from $rawdata
# 3. Refine the use of the $perfdatatitle (better logic on selecting the title)
# 4. Look for fs_cli, and report back via cmd line output and perfdata if can't find



# I. Prologue
use strict;
use warnings;

# Look for 'feature' pragma (Perl 5.10+), otherwise use Switch module (Perl 5.8)
eval {
  # require feature 'switch';
  require feature;
  feature->import();
};
unless($@) {
  use Switch 'Perl6';
}

use Nagios::Monitoring::Plugin;

# use vars qw($VERSION $PROGNAME $result);
our ( $VERSION, $PROGNAME, $result, $rawdata );
$VERSION = '0.5';

# get the base name of this script for use in the examples
use File::Basename;
$PROGNAME = basename( $0 );

# Fully qualified path to fs_cli. Modify this to suit:
my $fs_cli_location = "/usr/bin/fs_cli";

# Declare some vars
my @fs_cli_output;
my $subquery;
my $result2;
my $label2;

# Currently processed fs_cli queries:
my @allowed_checks = (
    "show-calls-count",
    "show-registrations-count",
    "sofia-status-internal",
    "sofia-status-external",
    "sofia-status-profile-internal-failed-calls-in",
    "sofia-status-profile-internal-failed-calls-out"
);

# II. Usage/Help
my $p = Nagios::Monitoring::Plugin->new(
    usage => "Usage: %s 
       [ -q|--query=These are mapped to specific fs_cli -x checks
                    e.g. show-calls-count is mapped to 'show calls count'
       [ -w|--warning=threshold that generates a Nagios warning ]
       [ -c|--critical=threshold that generates a Nagios critical warning ]
       [ -f|--perfdatatitle=title for Nagios Performance Data. 
                            Note: don't use spaces. ]

       See the documentation in this script's comments for accepted queries.
       For example, you can run 'head -n 50 check_freeswitch_health.pl'
       ",
    version => $VERSION,
    blurb   => "This plugin requires the FreeSWITCH fs_cli command to perform checks.",
    extra   => qq(
    An example query:   
    ./check_freeswitch_health.pl -q show-calls-count -w 100 -c 150 -f Total_Calls
    ),
    license =>
      "This Nagios plugin is subject to the terms of the Mozilla Public License, v. 2.0.",
);

# III. Command line arguments/options
# See Getopt::Long for more
$p->add_arg(
    spec     => 'query|q=s',
    required => 1,
    help     => "-q, --query=STRING
    What check to run. E.g. show-calls-count, sofia-status-internal, etc. 
    REQUIRED."
);

$p->add_arg(
    spec => 'warning|w=s',
    help => "-w, --warning=INTEGER:INTEGER
    Minimum and maximum number of allowable result, outside of which a
    warning will be generated. If omitted, no warning is generated."
);

$p->add_arg(
    spec => 'critical|c=s',
    help => "-c, --critical=INTEGER:INTEGER
    Minimum and maximum number of allowable result, outside of which a
    an alert will be generated.  If omitted, no alert is generated."
);

$p->add_arg(
    spec     => 'perfdatatitle|f=s',
    required => 0,
    help     => "-f, --perfdatatitle=STRING
    If you want to collect Nagios Performance Data, you may
    give the check an appropriate name. OPTIONAL"
);

# Parse arguments and process standard ones (e.g. usage, help, version)
$p->getopts;

# IV. Sanity check the command line arguments
# Ensure that only one of the supported fs_cli queries are called:
my $query = $p->opts->query;
unless ( grep /^$query$/i, @allowed_checks ) {
    $p->nagios_die( "Sorry, that's not an allowed check (yet?)!" );
}


# V. Check the stuff

# Set up and run the specific queries
given ( $query ) {

    # Perform a 'show calls count'
    when ( "show-calls-count" ) {
        @fs_cli_output = `$fs_cli_location -x "show calls count"`;
        foreach ( @fs_cli_output ) {
            if ( /total/i ) {
                my @temp = split( /\s+/, $_ );
                $rawdata = $_;
                $result  = $temp[0];
                last;
            }
        }
    }

    when ( "sofia-status-internal" ) {
        @fs_cli_output = `$fs_cli_location -x "sofia status"`;
        $subquery      = 'internal';
        foreach ( @fs_cli_output ) {
            if ( /internal/i ) {
                my @temp = split( /\s+/, $_ );
                if ( $temp[1] eq 'internal' ) {
                    $rawdata = $_;
                    $temp[5] =~ s/[^0-9]//g;    # strip out parens
                    $result2 = $temp[5];
                    $label2  = "# of Calls";
                    if ( $temp[4] =~ /^running$/i ) {
                        $result = 1;
                    } else {
                        $result = 0;
                    }
                    last;
                }
            }
        }
    }

    when ( "sofia-status-external" ) {
        @fs_cli_output = `$fs_cli_location -x "sofia status"`;
        $subquery      = 'external';
        foreach ( @fs_cli_output ) {
            if ( /external/i ) {
                my @temp = split( /\s+/, $_ );
                if ( $temp[1] eq 'external' ) {
                    $rawdata = $_;
                    $temp[5] =~ s/[^0-9]//g;    # strip out parens
                    $result2 = $temp[5];
                    $label2  = "# of Calls";
                    if ( $temp[4] =~ /^running$/i ) {
                        $result = 1;
                    } else {
                        $result = 0;
                    }
                    last;
                }
            }
        }
    }

    when ( "sofia-status-profile-internal-failed-calls-in" ) {
        @fs_cli_output = `$fs_cli_location -x "sofia status profile internal"`;
        $subquery      = 'failed-calls-in';
        foreach ( @fs_cli_output ) {
            if ( /failed-calls-in/i ) {
                my @temp = split( /\s+/, $_ );
                $rawdata = $_;
                $result  = $temp[1];
            }
        }
    }

    when ( "sofia-status-profile-internal-failed-calls-out" ) {
        @fs_cli_output = `$fs_cli_location -x "sofia status profile internal"`;
        $subquery      = 'failed-calls-out';
        foreach ( @fs_cli_output ) {
            if ( /failed-calls-out/i ) {
                my @temp = split( /\s+/, $_ );
                $rawdata = $_;
                $result  = $temp[1];
            }
        }
    }

    when ( "show-registrations-count" ) {
        @fs_cli_output = `$fs_cli_location -x "show registrations"`;
        foreach ( @fs_cli_output ) {
            if ( /total/i ) {
                my @temp = split( /\s+/, $_ );
                $rawdata = $_;
                $result  = $temp[0];
                last;
            }
        }
    }
}


# VI. Performance Data gathering

my $threshold = $p->set_thresholds(
    warning  => $p->opts->warning,
    critical => $p->opts->critical
);

my $perfdatatitle = $query;
if ( defined $p->opts->perfdatatitle ) {
    $perfdatatitle = $p->opts->perfdatatitle;
}
$perfdatatitle =~ s/\s/_/g;    # replace whitespaces with underscores

$p->add_perfdata(
    label     => $perfdatatitle,
    value     => $result,
    threshold => $threshold,
    uom       => "",               # Bug in Nagios::Plugin version 0.15
);

# is there a 2nd set of performance data:
if ( defined $result2 ) {
    $p->add_perfdata(
        label => $label2,
        value => $result2,
        uom   => "",               # Bug in Nagios::Plugin version 0.15
    );
}

# VIII. Exit Code
# Output in Nagios format and exit.

# remove excess whitespace:
$rawdata =~ s/\s+/ /g;

$p->nagios_exit(
    return_code => $p->check_threshold( $result ),
    message     => "Result of check is: $rawdata",
);
