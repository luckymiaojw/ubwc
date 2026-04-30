#!/usr/bin/perl
# -------------------------------------------------------------------------------
# 
# Copyright 2006 - 2020 Synopsys, INC.
# 
# This Synopsys IP and all associated documentation are proprietary to
# Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
# written license agreement with Synopsys, Inc. All other use, reproduction,
# modification, or distribution of the Synopsys IP or the associated
# documentation is strictly prohibited.
# 
# Component Name   : DW_axi_x2x
# Component Version: 1.08a
# Release Type     : GA
# -------------------------------------------------------------------------------


use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

use FindBin;
use lib "$FindBin::Bin";
use testjson;


#####################################################
# define & parse command line options
#####################################################
my $opt_log;
my $opt_json = "./test.json";
my $help     = 0;

&Getopt::Long::Configure('no_autoabbrev', 'ignore_case');

GetOptions(
           'log=s'      => \$opt_log,  # result to log
           'json=s'     => \$opt_json, # where to write the json file
           'help|h'     => \$help,     # ask for help
         ) or pod2usage(2);
pod2usage(1) if $help;

# check for mandatory arguments
die("No --log option found.") unless ( defined $opt_log );
die("Invalid result $opt_log. Valid values are 'pass' or 'fail'")
  unless ( $opt_log =~ /pass|fail/ );


#####################################################
# main body
#####################################################
my $result = ( $opt_log eq "pass" ) ? "PASSED" : "FAILED";
&logTestResult(
  jsonfile => $opt_json,
  Result => $result
);

# we're done
exit 0;



__END__

=head1 NAME

logresult.pl

=head1 SYNOPSIS

logresult.pl --log <type> [--json <path to json file>]

command line utility to log a test result in a test.json file

 Options:
   --log  <pass|fail> : mandatory argument ; it's the result to log
   --json <..>        : path to json file. Default: ./test.json
   --help             : print this message

=cut

