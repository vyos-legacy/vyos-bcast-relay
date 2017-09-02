#!/usr/bin/env perl

use lib '/opt/vyatta/share/perl5';
use File::Basename;
use File::Compare;
use Getopt::Long;
use POSIX;
use Vyatta::Config;

use warnings;
use strict;

my $version = q{1.0};
my ( $update, $stop );
my $FALSE      = 0;
my $TRUE       = 1;
my $executable = q{/opt/vyatta/sbin/udp-bcast-relay};
my $pid_file   = q{/var/run/udp-bcast-relay};

############################### script runs here ###############################
exit 0 if &main();
exit 1;
################################################################################

# Process the active configuration
sub get_cfg_actv {
  my $config       = new Vyatta::Config;
  my $input        = shift;
  my $path         = q{service bcast-relay id};
  my $exists       = q{existsOrig};
  my $listNodes    = q{listOrigNodes};
  my $returnValue  = q{returnOrigValue};
  my $returnValues = q{returnOrigValues};

  if ( is_configure() ) {
    $exists       = q{exists};
    $listNodes    = q{listNodes};
    $returnValue  = q{returnValue};
    $returnValues = q{returnValues};
  }

  $config->setLevel($path);
  my @relays = $config->$listNodes();

  for my $relay (@relays) {
    $config->setLevel( $path . q{ } . $relay );
    my $lport      = $config->$returnValue(q{port});
    my @interfaces = $config->$returnValues(q{interface});
    my ( $args, $error );

    if ( scalar(@interfaces) < 2 ) {
      print qq{You must configure at least two valid interfaces!\n}
        . join( q{ }, @interfaces );
      $error = $TRUE;
    }

    if ( !$lport ) {
      print qq{Port must be configured!\n};
      $error = $TRUE;
    }
    exit 1 if $error;

    my $sourceaddress = $config->$returnValue(q{address});
    if ( defined $sourceaddress && $sourceaddress ne q{} ) {
      $args = qq{ -s ${sourceaddress} ${relay} ${lport} }
        . join( q{ }, @interfaces );
    }
    else {
      $args = qq{${relay} ${lport} } . join( q{ }, @interfaces );
    }

    $input->{relays}->{$relay} = $args;
  }
  return $TRUE;
}

# Set up command line options
sub get_options {
  my $input = shift;
  my @opts  = (
    [
      q{--stop   # Restart ubnt-bcast-relay with current configuration},
      q{stop!} => \$stop
    ],
    [
      q{--update   # Restart ubnt-bcast-relay with current configuration},
      q{update!} => \$update
    ],
    [
      q{--help     # Show help and usage text},
      q{help} => sub { usage( { option => q{help}, exit_code => 0 } ) }
    ],
    [
      q{--version  # show program version number},
      q{version} => sub { usage( { option => q{version}, exit_code => 0 } ) }
    ],
  );

  return \@opts if $input->{option};

  # Read command line flags and exit with help message if any are unknown
  return GetOptions( map { my $options = $_; (@$options)[ 1 .. $#$options ] }
      @opts );
  return;
}

# Make sure script runs as root
sub is_admin {
  return $TRUE if geteuid() == 0;
  return;
}

# Check to see if we are being run under configure
sub is_configure {
  qx{/bin/cli-shell-api inSession};
  return $? >> 8 != 0 ? $FALSE : $TRUE;
}

# This is the main function
sub main {
  my $cfg = { relays => {}, };

  # Get command line options or print help if no valid options
  get_options() or usage( { option => q{help}, exit_code => 1 } );
  usage( { option => q{sudo}, exit_code => 1 } ) if not is_admin();

  get_cfg_actv($cfg);

  if ($update) {
    restart_daemon($cfg);
    exit 0;
  }

  if ($stop) {
    stop_daemon($cfg);
    exit 0;
  }
}

# Restart
sub restart_daemon {
  my $cfg = shift;
  stop_daemon($cfg);

  for my $relay ( keys $cfg->{relays} ) {
    my $file = $pid_file . q{.} . ${relay} . q{.pid};
    my $cmd
      = qq{start-stop-daemon --start --quiet --background }
      . q{--make-pidfile --pidfile }
      . $file
      . qq{ --exec }
      . $executable . q{ -- }
      . $cfg->{relays}->{$relay};

    system($cmd) == 0 or die qq{start-stop-daemon failed: $?};
  }
}

# Stop
sub stop_daemon {
  my $cfg = shift;

  for my $relay ( keys $cfg->{relays} ) {
    my $file = $pid_file . q{.} . ${relay} . q{.pid};
    if ( -f $file ) {
      my $cmd = q{start-stop-daemon --quiet --stop --oknodo --pidfile } . $file;
      system($cmd);
      unlink $file;
    }
  }
}

# Process command line options and print usage
sub usage {
  my $input    = shift;
  my $progname = basename($0);
  my $usage    = {
    help => sub {
      my $exitcode = shift;
      local $, = qq{\n};
      print STDERR @_;
      print STDERR qq{usage: $progname <options>\n};
      print STDERR q{options:},
        map( q{ } x 4 . $_->[0],
        sort { $a->[1] cmp $b->[1] } grep $_->[0] ne q{},
        @{ get_options( { option => $TRUE } ) } ),
        qq{\n};
      $exitcode == 1 ? return $TRUE : exit $exitcode;
    },
    sudo => sub {
      my $exitcode = shift;
      print STDERR qq{This script must be run as root, use: sudo $0.\n};
      exit $exitcode;
    },
    version => sub {
      my $exitcode = shift;
      printf STDERR qq{%s version: %s\n}, $progname, $version;
      exit $exitcode;
    },
  };

  # Process option argument
  $usage->{ $input->{option} }->( $input->{exit_code} );
}
