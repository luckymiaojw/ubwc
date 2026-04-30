# Copyright Synopsys, INC.
# This Synopsys IP and all associated documentation are proprietary to
# Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
# written license agreement with Synopsys, Inc. All other use, reproduction,
# modification, or distribution of the Synopsys IP or the associated
# documentation is strictly prohibited.

package testjson;

=head1 NAME

TestJson : a module to read, write and update test.json files used in VIVID

=head1 SYNOPSIS

use testjson;

TODO

=head1 EXPORTS

TODO

=head1 DESCRIPTION

Perl scripts, like runtest, can use this module to update the content of test.json
which will be later used by VIVID to report test status, simulation runtime, etc.
A shell wrapper is also provided to access part of this functionality from shell
scripts.

=head1 AUTHOR

Nicola L'Insalata (lnicola@synopsys.com)

=cut

use 5.008_003;        # -- Minimum version is 5.8.3
use strict;           # -- Follow rigid variable/subroutine declarations
use warnings;         # -- Turn warnings on
use Fcntl qw/:flock/; # -- exclusive access to a file in multithreaded envs
use POSIX;            # -- to format time
use Time::Local;      # -- to manipulate timestamps
use File::Basename;   # -- for breaking down file paths
use Data::Dumper;     # -- for debugging

use FindBin;          # -- to load modules from the same location where this file is located
use lib $FindBin::Bin;
use JSON;             # -- to read/write JSON files

use Exporter();

my @ExportedSubs;
push (@ExportedSubs, qw(flushTestJson));
push (@ExportedSubs, qw(logStartTime logEndTime));
push (@ExportedSubs, qw(logTestResult logTestError));
push (@ExportedSubs, qw(logKnownIssue logOwner));
push (@ExportedSubs, qw(logCustomData));

our @ISA = qw(Exporter);
our @EXPORT = @ExportedSubs;

# timestamp format
our $timeFmt = "%Y%m%d-%H%M%S";


# --------------------------------------------------
# remove the test.json file (or equivalent)
#
# filename is optional, if not specified ./test.json
# is used
# --------------------------------------------------
sub flushTestJson {
  my (%arg) = (
    'jsonfile' => './test.json'
  );

  my $jsonFile = $arg{'jsonfile'};
  unlink($jsonFile);
};


# --------------------------------------------------
# log the start time
# flush all the other times
# --------------------------------------------------
sub logStartTime {
  my (%arg) = (
    'jsonfile'   => './test.json',
    @_
  );

  my $jsonFile = $arg{'jsonfile'};
  my $startTime = &getTimeStamp();

  &logData(
    'jsonfile'   => $jsonFile,
    'fieldName'  => 'StartTime',
    'fieldValue' => $startTime
  );
  &logData(
    'jsonfile'   => $jsonFile,
    'fieldName'  => 'EndTime',
    'fieldValue' => '0'
  );
  &logData(
    'jsonfile'   => $jsonFile,
    'fieldName'  => 'Duration',
    'fieldValue' => '0'
  );
  &logData(
    'jsonfile'   => $jsonFile,
    'fieldName'  => 'CpuTime',
    'fieldValue' => '0'
  );
};


# --------------------------------------------------
# log the end time
# --------------------------------------------------
sub logEndTime {
  my (%arg) = (
    'jsonfile'   => './test.json',
    @_
  );

  my $jsonFile = $arg{'jsonfile'};
  my $endtime = &getTimeStamp();

  # read in the json data to fetch the start time
  my $jsondata = &loadTestJson(
    jsonfile => $jsonFile
  );

  my $duration = -1;
  if ( defined $jsondata->{'StartTime'} ) {
    my $starttime = $jsondata->{'StartTime'};
    $duration = &calcDuration( $starttime, $endtime);
  } else {
    warn("WARNING: Logging EndTime for a test where no StartTime is defined. Duration will not be calculated.");
  }

  &logData(
    'jsonfile'   => $jsonFile,
    'fieldName'  => 'EndTime',
    'fieldValue' => $endtime
  );

  &logData(
    'jsonfile'   => $jsonFile,
    'fieldName'  => 'Duration',
    'fieldValue' => $duration
  );
};


# --------------------------------------------------
# log the test result (PASSED/FAILED)
# --------------------------------------------------
sub logTestResult {
  my (%arg) = (
    'jsonfile'   => './test.json',
    @_
  );

  my $jsonFile = $arg{'jsonfile'};
  my $result = $arg{'Result'} or die("FATAL: logTestResult() invoked without providing Result value");
  &logData(
    'jsonfile'   => $jsonFile,
    'fieldName'  => 'Result',
    'fieldValue' => $result
  );
};

# --------------------------------------------------
# log one error message or a list of errors
# --------------------------------------------------
sub logTestError {
  my (%arg) = (
    'jsonfile'   => './test.json',
    @_
  );

  my $jsonFile = $arg{'jsonfile'};
  my $err = $arg{'Error'}
    or die("FATAL: logTestError() invoked without providing an error message");
  die("FATAL: logTestError() accepts a single error message or a list")
    unless( !ref($err) or ref($err) eq "ARRAY" );
  my $errList = &listify( $err );
  &logData(
    'jsonfile'   => $jsonFile,
    'fieldName'  => 'Errors',
    'fieldValue' => $errList,
  );
};

# --------------------------------------------------
# log known issue
# --------------------------------------------------
sub logKnownIssue {
  my (%arg) = (
    'jsonfile'   => './test.json',
    @_
  );

  my $jsonFile = $arg{'jsonfile'};
  my $issueId = $arg{'IssueId'}
    or die("FATAL: logKnownIssue() invoked without providing an IssueID");
  my $issue = $arg{'Issue'}
    or die("FATAL: logKnownIssue() invoked without providing an Issue");
  die("FATAL : logKnownIssue() Issue argument must be a hash")
    unless( ref($issue) eq "HASH");

  # ensure users was provided, then make it into a list
  my $users = $issue->{'Users'}
    or die("FATAL: logKnownIssue() IssueId $issueId: no 'Users' field not found");
  $issue->{'Users'} = &listify( $issue->{'Users'} );

  # ensure source was provided, then make it into a list
  my $source = $issue->{'Source'}
    or die("FATAL: logKnownIssue() IssueId $issueId: no 'Source' field not found");
  $issue->{'Source'} = &listify( $issue->{'Source'} );

  # ensure links was provided, then make it into a list
  my $links = $issue->{'Links'}
    or die("FATAL: logKnownIssue() IssueId $issueId: no 'Links' field not found");
  $issue->{'Links'} = &listify( $issue->{'Links'} );

  &logData(
    'jsonfile'     => $jsonFile,
    'fieldName'    => 'KnownIssues',
    'subfieldName' => $issueId,
    'fieldValue'   => $issue,
  );
}

# --------------------------------------------------
# log test owner
# --------------------------------------------------
sub logOwner {
  my (%arg) = (
    'jsonfile'   => './test.json',
    @_
  );

  my $jsonFile = $arg{'jsonfile'};
  my $owner = $arg{'Owner'}
    or die("FATAL: logOwner() invoked without providing an Owner");
  die("FATAL : logOwner() Owner argument must be a hash")
    unless( ref($owner) eq "HASH");

  # ensure owners was provided, then make it into a list
  my $owners = $owner->{'Owners'}
   or die("FATAL: logOwner() 'Owners' field not found");
  $owner->{'Owners'} = &listify( $owner->{'Owners'} );

  # components is optional, if provided listify its arguments
  if ( defined $owner->{'Components'} ) {
    my $components = $owner->{'Components'};
    while (my ($key, $value) = each(%{$components})) {
      # ensure owners for this component was provided, then make it into a list
      my $owners = $value->{'Owners'}
        or die("FATAL: logOwner() 'Owners' field not found for component $key");
      $value->{'Owners'} = &listify( $value->{'Owners'} );
    }
  }

  &logData(
    'jsonfile'     => $jsonFile,
    'fieldName'    => 'Owner',
    'fieldValue'   => $owner,
  );
}


#####################################################################
#
# internal functions below this point
# if you need to invoke these directly, you're doing it wrong
#
#####################################################################

# --------------------------------------------------
# get the current time
# --------------------------------------------------
sub getTimeStamp {
  return POSIX::strftime($timeFmt, localtime);
}


# --------------------------------------------------
# return the difference in seconds between two
# timestamps generated by getTimeStamp
#
# implementation adapted from:
# https://www.perlmonks.org/?node_id=408168
#
# picked up this solution as it works with minimal
# module dependencies; other solutions would have
# required perl > 5.8.3 which could have been an
# issue when deploying this across teams
# --------------------------------------------------
sub calcDuration {
  my ($start, $end) = @_;
  my @parts;
  my $start_secs;
  my $end_secs;
  my $diff;

  # http://perldoc.perl.org/Time/Local.html#timelocal()-and-timegm()
  # It is worth drawing particular attention to the expected ranges for the
  # values provided. The value for the day of the month is the actual day
  # (i.e. 1..31), while the month is the number of months since January
  # (0..11). This is consistent with the values returned from localtime()
  # and gmtime().

  eval {
    @parts = $start =~ /^(.{4})(.{2})(.{2})-(.{2})(.{2})(.{2})$/;
    $parts[1] = $parts[1] - 1;
    $start_secs = 0;
    $start_secs += timegm reverse @parts;

    @parts =   $end =~ /^(.{4})(.{2})(.{2})-(.{2})(.{2})(.{2})$/;
    $parts[1] = $parts[1] - 1;
    $end_secs = 0;
    $end_secs += timegm reverse @parts;

    $diff = $end_secs - $start_secs;
  };
  if ( $@ ) {
    printf "DEBUG StartTime (secs) $start ($start_secs) EndTime (secs) $end ($end_secs) Diff $diff \n";
    die("ERROR(calcDuration): unable to calculate duration: $@\n");
  }

  return $diff;
}

# --------------------------------------------------
# take a scalar or a list reference and return a
# list reference
#
# this is needed to handle those fields which can
# be either a scalar or a list, but we want to store
# them as list in json
# --------------------------------------------------
sub listify {
  my ( $in ) = @_;

  my @list;
  if ( !ref($in) ) {
    @list = ( $in );
  } else {
    @list = @{$in};
  }
  return \@list;
}

# --------------------------------------------------
# generic function to register data
# implements a cheap nesting
# --------------------------------------------------
sub logData {
  my %arg = ( @_ );

  my $jsonFile = $arg{'jsonfile'};
  my $fieldName = $arg{'fieldName'};
  my $subfieldName = $arg{'subfieldName'};
  my $fieldValue = $arg{'fieldValue'};

  # read in the json data
  my $jsondata = &loadTestJson(
    jsonfile => $jsonFile
  );

  if ( defined $subfieldName ) {
    $jsondata->{$fieldName}->{$subfieldName} = $fieldValue;
  } else {
    $jsondata->{$fieldName} = $fieldValue;
  }

  # update the json file
  &writeTestJson(
    jsonfile => $jsonFile,
    hashref  => $jsondata
  );
};

# --------------------------------------------------
# Read a test.json file and return its content
# in a hash
# --------------------------------------------------
sub loadTestJson {
  my (%arg) = ( @_ );

  my $jsonFile = $arg{'jsonfile'};
  my($filename, $dirs, $suffix) = fileparse($jsonFile);
  my $hashref = {};

  # check if the file exists, so we can read its content
  if ( -r $jsonFile ) {
    eval {
      # read the json
      my $jsonText;
      open(my $json_fh, "<:encoding(UTF-8)", $jsonFile);
      flock($json_fh, LOCK_EX);
      {
        local $/;
        $jsonText = <$json_fh>;
      };
      flock($json_fh, LOCK_UN);
      my $json = JSON->new;
      $hashref = $json->decode($jsonText);
    };
    if ( $@ ) {
      die("ERROR(loadTestJson): unable to read from $jsonFile : $@\n");
    }
  }

  # return the hash reference
  return $hashref;
}


# --------------------------------------------------
# write the hash content into a json file
# --------------------------------------------------
sub writeTestJson {
  my (%arg) = ( @_ );

  my $jsonFile = $arg{'jsonfile'};
  my($filename, $dirs, $suffix) = fileparse($jsonFile);
  my $jsonData = $arg{'hashref'};

  eval {
    # write the json file
    my $json = JSON->new->allow_nonref;
    open(my $json_fh, ">:encoding(UTF-8)", $jsonFile);
    flock($json_fh, LOCK_EX);
    print $json_fh $json->pretty->encode( $jsonData );
    flock($json_fh, LOCK_UN);
  };
  if ( $@ ) {
    die("ERROR(writeTestJson): unable to write to $jsonFile : $@\n");
  }
};

# --------------------------------------------------
# log custom data
# --------------------------------------------------
sub logCustomData {
  my (%arg) = (
    'jsonfile'   => './test.json',
    @_
  );

  my $jsonFile = $arg{'jsonfile'};
  my $data = $arg{'data'}
    or die("FATAL: logCustomData() invoked without providing the data");
  die("FATAL : logCustomData() Owner argument must be a hash")
    unless( ref($data) eq "HASH");

  &logData(
    'jsonfile'     => $jsonFile,
    'fieldName'    => 'customData',
    'fieldValue'   => $data,
  );
}


#####################################################################

1;

__END__

