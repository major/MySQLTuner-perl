#!/usr/bin/env perl
# mysqltuner.pl - Version 1.6.0
# High Performance MySQL Tuning Script
# Copyright (C) 2006-2015 Major Hayden - major@mhtx.net
#
# For the latest updates, please visit http://mysqltuner.com/
# Git repository available at http://github.com/major/MySQLTuner-perl
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This project would not be possible without help from:
#   Matthew Montgomery     Paul Kehrer          Dave Burgess
#   Jonathan Hinds         Mike Jackson         Nils Breunese
#   Shawn Ashlee           Luuk Vosslamber      Ville Skytta
#   Trent Hornibrook       Jason Gill           Mark Imbriaco
#   Greg Eden              Aubin Galinotti      Giovanni Bechis
#   Bill Bradford          Ryan Novosielski     Michael Scheidell
#   Blair Christensen      Hans du Plooy        Victor Trac
#   Everett Barnes         Tom Krouper          Gary Barrueto
#   Simon Greenaway        Adam Stein           Isart Montane
#   Baptiste M.            Cole Turner          Major Hayden
#   Joe Ashcraft           Jean-Marie Renouard
#
# Inspired by Matthew Montgomery's tuning-primer.sh script:
# http://forge.mysql.com/projects/view.php?id=44
#

# ---------------------------------------------------------------------------
# BEGIN TEXT TEMPLATE MODULE
# ---------------------------------------------------------------------------
# Text::Template.pm
#
# Fill in `templates'
#
# Copyright 2013 M. J. Dominus.
# You may copy and distribute this program under the
# same terms as Perl itself.  
# If in doubt, write to mjd-perl-template+@plover.com for a license.
#
# Version 1.46

package Text::Template;
require 5.004;
use Exporter;
#use no strict;
@ISA = qw(Exporter);
@EXPORT_OK = qw(fill_in_file fill_in_string TTerror);
use vars '$ERROR';
use strict;

$Text::Template::VERSION = '1.46';
my %GLOBAL_PREPEND = ('Text::Template' => '');

sub Version {
  $Text::Template::VERSION;
}

sub _param {
  my $kk;
  my ($k, %h) = @_;
  for $kk ($k, "\u$k", "\U$k", "-$k", "-\u$k", "-\U$k") {
    return $h{$kk} if exists $h{$kk};
  }
  return;
}

sub always_prepend
{
  my $pack = shift;
  my $old = $GLOBAL_PREPEND{$pack};
  $GLOBAL_PREPEND{$pack} = shift;
  $old;
}

{
  my %LEGAL_TYPE;
  BEGIN { 
    %LEGAL_TYPE = map {$_=>1} qw(FILE FILEHANDLE STRING ARRAY);
  }
  sub new {
    my $pack = shift;
    my %a = @_;
    my $stype = uc(_param('type', %a) || "FILE");
    my $source = _param('source', %a);
    my $untaint = _param('untaint', %a);
    my $prepend = _param('prepend', %a);
    my $alt_delim = _param('delimiters', %a);
    my $broken = _param('broken', %a);
    unless (defined $source) {
      require Carp;
      Carp::croak("Usage: $ {pack}::new(TYPE => ..., SOURCE => ...)");
    }
    unless ($LEGAL_TYPE{$stype}) {
      require Carp;
      Carp::croak("Illegal value `$stype' for TYPE parameter");
    }
    my $self = {TYPE => $stype,
    PREPEND => $prepend,
                UNTAINT => $untaint,
                BROKEN => $broken,
    (defined $alt_delim ? (DELIM => $alt_delim) : ()),
         };
    # Under 5.005_03, if any of $stype, $prepend, $untaint, or $broken
    # are tainted, all the others become tainted too as a result of
    # sharing the expression with them.  We install $source separately
    # to prevent it from acquiring a spurious taint.
    $self->{SOURCE} = $source;

    bless $self => $pack;
    return unless $self->_acquire_data;
    
    $self;
  }
}

# Convert template objects of various types to type STRING,
# in which the template data is embedded in the object itself.
sub _acquire_data {
  my ($self) = @_;
  my $type = $self->{TYPE};
  if ($type eq 'STRING') {
    # nothing necessary    
  } elsif ($type eq 'FILE') {
    my $data = _load_text($self->{SOURCE});
    unless (defined $data) {
      # _load_text already set $ERROR
      return undef;
    }
    if ($self->{UNTAINT} && _is_clean($self->{SOURCE})) {
      _unconditionally_untaint($data);
    }
    $self->{TYPE} = 'STRING';
    $self->{FILENAME} = $self->{SOURCE};
    $self->{SOURCE} = $data;
  } elsif ($type eq 'ARRAY') {
    $self->{TYPE} = 'STRING';
    $self->{SOURCE} = join '', @{$self->{SOURCE}};
  } elsif ($type eq 'FILEHANDLE') {
    $self->{TYPE} = 'STRING';
    local $/;
    my $fh = $self->{SOURCE};
    my $data = <$fh>; # Extra assignment avoids bug in Solaris perl5.00[45].
    if ($self->{UNTAINT}) {
      _unconditionally_untaint($data);
    }
    $self->{SOURCE} = $data;
  } else {
    # This should have been caught long ago, so it represents a 
    # drastic `can't-happen' sort of failure
    my $pack = ref $self;
    die "Can only acquire data for $pack objects of subtype STRING, but this is $type; aborting";
  }
  $self->{DATA_ACQUIRED} = 1;
}

sub source {
  my ($self) = @_;
  $self->_acquire_data unless $self->{DATA_ACQUIRED};
  return $self->{SOURCE};
}

sub set_source_data {
  my ($self, $newdata) = @_;
  $self->{SOURCE} = $newdata;
  $self->{DATA_ACQUIRED} = 1;
  $self->{TYPE} = 'STRING';
  1;
}

sub compile {
  my $self = shift;

  return 1 if $self->{TYPE} eq 'PREPARSED';

  return undef unless $self->_acquire_data;
  unless ($self->{TYPE} eq 'STRING') {
    my $pack = ref $self;
    # This should have been caught long ago, so it represents a 
    # drastic `can't-happen' sort of failure
    die "Can only compile $pack objects of subtype STRING, but this is $self->{TYPE}; aborting";
  }

  my @tokens;
  my $delim_pats = shift() || $self->{DELIM};

  

  my ($t_open, $t_close) = ('{', '}');
  my $DELIM;      # Regex matches a delimiter if $delim_pats
  if (defined $delim_pats) {
    ($t_open, $t_close) = @$delim_pats;
    $DELIM = "(?:(?:\Q$t_open\E)|(?:\Q$t_close\E))";
    @tokens = split /($DELIM|\n)/, $self->{SOURCE};
  } else {
    @tokens = split /(\\\\(?=\\*[{}])|\\[{}]|[{}\n])/, $self->{SOURCE};
  }
  my $state = 'TEXT';
  my $depth = 0;
  my $lineno = 1;
  my @content;
  my $cur_item = '';
  my $prog_start;
  while (@tokens) {
    my $t = shift @tokens;
    next if $t eq '';
    if ($t eq $t_open) {  # Brace or other opening delimiter
      if ($depth == 0) {
  push @content, [$state, $cur_item, $lineno] if $cur_item ne '';
  $cur_item = '';
  $state = 'PROG';
  $prog_start = $lineno;
      } else {
  $cur_item .= $t;
      }
      $depth++;
    } elsif ($t eq $t_close) {  # Brace or other closing delimiter
      $depth--;
      if ($depth < 0) {
  $ERROR = "Unmatched close brace at line $lineno";
  return undef;
      } elsif ($depth == 0) {
  push @content, [$state, $cur_item, $prog_start] if $cur_item ne '';
  $state = 'TEXT';
  $cur_item = '';
      } else {
  $cur_item .= $t;
      }
    } elsif (!$delim_pats && $t eq '\\\\') { # precedes \\\..\\\{ or \\\..\\\}
      $cur_item .= '\\';
    } elsif (!$delim_pats && $t =~ /^\\([{}])$/) { # Escaped (literal) brace?
  $cur_item .= $1;
    } elsif ($t eq "\n") {  # Newline
      $lineno++;
      $cur_item .= $t;
    } else {      # Anything else
      $cur_item .= $t;
    }
  }

  if ($state eq 'PROG') {
    $ERROR = "End of data inside program text that began at line $prog_start";
    return undef;
  } elsif ($state eq 'TEXT') {
    push @content, [$state, $cur_item, $lineno] if $cur_item ne '';
  } else {
    die "Can't happen error #1";
  }
  
  $self->{TYPE} = 'PREPARSED';
  $self->{SOURCE} = \@content;
  1;
}

sub prepend_text {
  my ($self) = @_;
  my $t = $self->{PREPEND};
  unless (defined $t) {
    $t = $GLOBAL_PREPEND{ref $self};
    unless (defined $t) {
      $t = $GLOBAL_PREPEND{'Text::Template'};
    }
  }
  $self->{PREPEND} = $_[1] if $#_ >= 1;
  return $t;
}

sub fill_in {
  my $fi_self = shift;
  my %fi_a = @_;

  unless ($fi_self->{TYPE} eq 'PREPARSED') {
    my $delims = _param('delimiters', %fi_a);
    my @delim_arg = (defined $delims ? ($delims) : ());
    $fi_self->compile(@delim_arg)
      or return undef;
  }

  my $fi_varhash = _param('hash', %fi_a);
  my $fi_package = _param('package', %fi_a) ;
  my $fi_broken  = 
    _param('broken', %fi_a)  || $fi_self->{BROKEN} || \&_default_broken;
  my $fi_broken_arg = _param('broken_arg', %fi_a) || [];
  my $fi_safe = _param('safe', %fi_a);
  my $fi_ofh = _param('output', %fi_a);
  my $fi_eval_package;
  my $fi_scrub_package = 0;
  my $fi_filename = _param('filename') || $fi_self->{FILENAME} || 'template';

  my $fi_prepend = _param('prepend', %fi_a);
  unless (defined $fi_prepend) {
    $fi_prepend = $fi_self->prepend_text;
  }

  if (defined $fi_safe) {
    $fi_eval_package = 'main';
  } elsif (defined $fi_package) {
    $fi_eval_package = $fi_package;
  } elsif (defined $fi_varhash) {
    $fi_eval_package = _gensym();
    $fi_scrub_package = 1;
  } else {
    $fi_eval_package = caller;
  }

  my $fi_install_package;
  if (defined $fi_varhash) {
    if (defined $fi_package) {
      $fi_install_package = $fi_package;
    } elsif (defined $fi_safe) {
      $fi_install_package = $fi_safe->root;
    } else {
      $fi_install_package = $fi_eval_package; # The gensymmed one
    }
    _install_hash($fi_varhash => $fi_install_package);
  }

  if (defined $fi_package && defined $fi_safe) {
    no strict 'refs';
    # Big fat magic here: Fix it so that the user-specified package
    # is the default one available in the safe compartment.
    *{$fi_safe->root . '::'} = \%{$fi_package . '::'};   # LOD
  }

  my $fi_r = '';
  my $fi_item;
  foreach $fi_item (@{$fi_self->{SOURCE}}) {
    my ($fi_type, $fi_text, $fi_lineno) = @$fi_item;
    if ($fi_type eq 'TEXT') {
      $fi_self->append_text_to_output(
        text   => $fi_text,
        handle => $fi_ofh,
        out    => \$fi_r,
        type   => $fi_type,
      );
    } elsif ($fi_type eq 'PROG') {
      no strict;
      my $fi_lcomment = "#line $fi_lineno $fi_filename";
      my $fi_progtext = 
        "package $fi_eval_package; $fi_prepend;\n$fi_lcomment\n$fi_text;";
      my $fi_res;
      my $fi_eval_err = '';
      if ($fi_safe) {
        $fi_safe->reval(q{undef $OUT});
  $fi_res = $fi_safe->reval($fi_progtext);
  $fi_eval_err = $@;
  my $OUT = $fi_safe->reval('$OUT');
  $fi_res = $OUT if defined $OUT;
      } else {
  my $OUT;
  $fi_res = eval $fi_progtext;
  $fi_eval_err = $@;
  $fi_res = $OUT if defined $OUT;
      }

      # If the value of the filled-in text really was undef,
      # change it to an explicit empty string to avoid undefined
      # value warnings later.
      $fi_res = '' unless defined $fi_res;

      if ($fi_eval_err) {
  $fi_res = $fi_broken->(text => $fi_text,
             error => $fi_eval_err,
             lineno => $fi_lineno,
             arg => $fi_broken_arg,
             );
  if (defined $fi_res) {
          $fi_self->append_text_to_output(
            text   => $fi_res,
            handle => $fi_ofh,
            out    => \$fi_r,
            type   => $fi_type,
          );
  } else {
    return $fi_res;   # Undefined means abort processing
  }
      } else {
        $fi_self->append_text_to_output(
          text   => $fi_res,
          handle => $fi_ofh,
          out    => \$fi_r,
          type   => $fi_type,
        );
      }
    } else {
      die "Can't happen error #2";
    }
  }

  _scrubpkg($fi_eval_package) if $fi_scrub_package;
  defined $fi_ofh ? 1 : $fi_r;
}

sub append_text_to_output {
  my ($self, %arg) = @_;

  if (defined $arg{handle}) {
    print { $arg{handle} } $arg{text};
  } else {
    ${ $arg{out} } .= $arg{text};
  }

  return;
}

sub fill_this_in {
  my $pack = shift;
  my $text = shift;
  my $templ = $pack->new(TYPE => 'STRING', SOURCE => $text, @_)
    or return undef;
  $templ->compile or return undef;
  my $result = $templ->fill_in(@_);
  $result;
}

sub fill_in_string {
  my $string = shift;
  my $package = _param('package', @_);
  push @_, 'package' => scalar(caller) unless defined $package;
  Text::Template->fill_this_in($string, @_);
}

sub fill_in_file {
  my $fn = shift;
  my $templ = Text::Template->new(TYPE => 'FILE', SOURCE => $fn, @_)
    or return undef;
  $templ->compile or return undef;
  my $text = $templ->fill_in(@_);
  $text;
}

sub _default_broken {
  my %a = @_;
  my $prog_text = $a{text};
  my $err = $a{error};
  my $lineno = $a{lineno};
  chomp $err;
#  $err =~ s/\s+at .*//s;
  "Program fragment delivered error ``$err''";
}

sub _load_text {
  my $fn = shift;
  local *F;
  unless (open F, $fn) {
    $ERROR = "Couldn't open file $fn: $!";
    return undef;
  }
  local $/;
  <F>;
}

sub _is_clean {
  my $z;
  eval { ($z = join('', @_)), eval '#' . substr($z,0,0); 1 }   # LOD
}

sub _unconditionally_untaint {
  for (@_) {
    ($_) = /(.*)/s;
  }
}

{
  my $seqno = 0;
  sub _gensym {
    __PACKAGE__ . '::GEN' . $seqno++;
  }
  sub _scrubpkg {
    my $s = shift;
    $s =~ s/^Text::Template:://;
    no strict 'refs';
    my $hash = $Text::Template::{$s."::"};
    foreach my $key (keys %$hash) {
      undef $hash->{$key};
    }
  }
}
  
# Given a hashful of variables (or a list of such hashes)
# install the variables into the specified package,
# overwriting whatever variables were there before.
sub _install_hash {
  my $hashlist = shift;
  my $dest = shift;
  if (UNIVERSAL::isa($hashlist, 'HASH')) {
    $hashlist = [$hashlist];
  }
  my $hash;
  foreach $hash (@$hashlist) {
    my $name;
    foreach $name (keys %$hash) {
      my $val = $hash->{$name};
      no strict 'refs';
      local *SYM = *{"$ {dest}::$name"};
      if (! defined $val) {
  delete ${"$ {dest}::"}{$name};
      } elsif (ref $val) {
  *SYM = $val;
      } else {
  *SYM = \$val;
      }
    }
  }
}

sub TTerror { $ERROR }

1;
# ---------------------------------------------------------------------------
# END TEXT TEMPLATE MODULE
# ---------------------------------------------------------------------------


package main;
use strict;
use warnings;
use diagnostics;
use File::Spec;
use Getopt::Long;
use File::Basename;
use Cwd 'abs_path';

# Set up a few variables for use in the script
my $tunerversion = "1.6.0";
my ( @adjvars, @generalrec );

# Set defaults
my %opt = (
    "silent"       => 0,
    "nobad"        => 0,
    "nogood"       => 0,
    "noinfo"       => 0,
    "debug"        => 0,
    "nocolor"      => 0,
    "forcemem"     => 0,
    "forceswap"    => 0,
    "host"         => 0,
    "socket"       => 0,
    "port"         => 0,
    "user"         => 0,
    "pass"         => 0,
    "skipsize"     => 0,
    "checkversion" => 0,
    "buffers"      => 0,
    "passwordfile" => 0,
    "outputfile"   => 0,
    "dbstat"       => 0,
    "idxstat"      => 0,
    "skippassword" => 0,
    "noask"        => 0,
    "template"     => 0,
    "reportfile"   => 0
);

# Gather the options from the command line
GetOptions(
    \%opt,            'nobad',        'nogood',       'noinfo',
    'debug',          'nocolor',      'forcemem=i',   'forceswap=i',
    'host=s',         'socket=s',     'port=i',       'user=s',
    'pass=s',         'skipsize',     'checkversion', 'mysqladmin=s',
    'mysqlcmd=s',     'help',         'buffers',      'skippassword',
    'passwordfile=s', 'outputfile=s', 'silent',       'dbstat',
    'idxstat', 'noask', 'template=s', 'reportfile=s'
);

if ( defined $opt{'help'} && $opt{'help'} == 1 ) { usage(); }

sub usage {

    # Shown with --help option passed
    print "   MySQLTuner $tunerversion - MySQL High Performance Tuning Script\n"
      . "   Bug reports, feature requests, and downloads at http://mysqltuner.com/\n"
      . "   Maintained by Major Hayden (major\@mhtx.net) - Licensed under GPL\n"
      . "\n"
      . "   Important Usage Guidelines:\n"
      . "      To run the script with the default options, run the script without arguments\n"
      . "      Allow MySQL server to run for at least 24-48 hours before trusting suggestions\n"
      . "      Some routines may require root level privileges (script will provide warnings)\n"
      . "      You must provide the remote server's total memory when connecting to other servers\n"
      . "\n"
      . "   Connection and Authentication\n"
      . "      --host <hostname>    Connect to a remote host to perform tests (default: localhost)\n"
      . "      --socket <socket>    Use a different socket for a local connection\n"
      . "      --port <port>        Port to use for connection (default: 3306)\n"
      . "      --user <username>    Username to use for authentication\n"
      . "      --pass <password>    Password to use for authentication\n"
      . "      --mysqladmin <path>  Path to a custom mysqladmin executable\n"
      . "      --mysqlcmd <path>    Path to a custom mysql executable\n" . "\n"
      . "      --noask              Dont ask password if needed\n" . "\n"
      . "   Performance and Reporting Options\n"
      . "      --skipsize           Don't enumerate tables and their types/sizes (default: on)\n"
      . "                           (Recommended for servers with many tables)\n"
      . "      --skippassword       Don't perform checks on user passwords(default: off)\n"
      . "      --checkversion       Check for updates to MySQLTuner (default: don't check)\n"
      . "      --forcemem <size>    Amount of RAM installed in megabytes\n"
      . "      --forceswap <size>   Amount of swap memory configured in megabytes\n"
      . "      --passwordfile <path>Path to a password file list(one password by line)\n"
      . "   Output Options:\n"
      . "      --silent             Don't output anything on screen\n"
      . "      --nogood             Remove OK responses\n"
      . "      --nobad              Remove negative/suggestion responses\n"
      . "      --noinfo             Remove informational responses\n"
      . "      --debug              Print debug information\n"
      . "      --dbstat             Print database information\n"
      . "      --idxstat            Print index information\n"
      . "      --nocolor            Don't print output in color\n"
      . "      --buffers            Print global and per-thread buffer values\n"
      . "      --outputfile <path>  Path to a output txt file\n" . "\n"
      . "      --reportfile <path>  Path to a report txt file\n" . "\n"
      . "      --template   <path>  Path to a template file\n" . "\n";
    exit 0;
}

my $devnull = File::Spec->devnull();
my $basic_password_files =
  ( $opt{passwordfile} eq "0" )
  ? abs_path( dirname(__FILE__) ) . "/basic_passwords.txt"
  : abs_path( $opt{passwordfile} );

# for RPM distributions
$basic_password_files = "/usr/share/mysqltuner/basic_passwords.txt"
  unless -f "$basic_password_files";

#
my $outputfile = undef;
$outputfile = abs_path( $opt{outputfile} ) unless $opt{outputfile} eq "0";

my $fh = undef;
open( $fh, '>', $outputfile )
  or die("Fail opening $outputfile")
  if defined($outputfile);
$opt{nocolor} = 1 if defined($outputfile);

# Setting up the colors for the print styles
my $good = ( $opt{nocolor} == 0 ) ? "[\e[0;32mOK\e[0m]" : "[OK]";
my $bad  = ( $opt{nocolor} == 0 ) ? "[\e[0;31m!!\e[0m]" : "[!!]";
my $info = ( $opt{nocolor} == 0 ) ? "[\e[0;34m--\e[0m]" : "[--]";
my $deb  = ( $opt{nocolor} == 0 ) ? "[\e[0;31mDG\e[0m]" : "[DG]";

# Super sturucture containing all informations
my %result;

# Functions that handle the print styles
sub prettyprint {
    print $_[0] . "\n" unless $opt{'silent'};
    print $fh $_[0] . "\n" if defined($fh);
}
sub goodprint  { prettyprint $good. " " . $_[0] unless ( $opt{nogood} == 1 ); }
sub infoprint  { prettyprint $info. " " . $_[0] unless ( $opt{noinfo} == 1 ); }
sub badprint   { prettyprint $bad. " " . $_[0]  unless ( $opt{nobad} == 1 ); }
sub debugprint { prettyprint $deb. " " . $_[0]  unless ( $opt{debug} == 0 ); }
sub redwrap {
    return ( $opt{nocolor} == 0 ) ? "\e[0;31m" . $_[0] . "\e[0m" : $_[0];
}

sub greenwrap {
    return ( $opt{nocolor} == 0 ) ? "\e[0;32m" . $_[0] . "\e[0m" : $_[0];
}

# Calculates the parameter passed in bytes, and then rounds it to one decimal place
sub hr_bytes {
    my $num = shift;
    if ( $num >= ( 1024**3 ) ) {    #GB
        return sprintf( "%.1f", ( $num / ( 1024**3 ) ) ) . "G";
    }
    elsif ( $num >= ( 1024**2 ) ) {    #MB
        return sprintf( "%.1f", ( $num / ( 1024**2 ) ) ) . "M";
    }
    elsif ( $num >= 1024 ) {           #KB
        return sprintf( "%.1f", ( $num / 1024 ) ) . "K";
    }
    else {
        return $num . "B";
    }
}

# Calculates the parameter passed in bytes, and then rounds it to the nearest integer
sub hr_bytes_rnd {
    my $num = shift;
    if ( $num >= ( 1024**3 ) ) {       #GB
        return int( ( $num / ( 1024**3 ) ) ) . "G";
    }
    elsif ( $num >= ( 1024**2 ) ) {    #MB
        return int( ( $num / ( 1024**2 ) ) ) . "M";
    }
    elsif ( $num >= 1024 ) {           #KB
        return int( ( $num / 1024 ) ) . "K";
    }
    else {
        return $num . "B";
    }
}

# Calculates the parameter passed to the nearest power of 1000, then rounds it to the nearest integer
sub hr_num {
    my $num = shift;
    if ( $num >= ( 1000**3 ) ) {       # Billions
        return int( ( $num / ( 1000**3 ) ) ) . "B";
    }
    elsif ( $num >= ( 1000**2 ) ) {    # Millions
        return int( ( $num / ( 1000**2 ) ) ) . "M";
    }
    elsif ( $num >= 1000 ) {           # Thousands
        return int( ( $num / 1000 ) ) . "K";
    }
    else {
        return $num;
    }
}

# Calculate Percentage
sub percentage {
    my $value = shift;
    my $total = shift;
    $total = 0 unless defined $total;
    return 100, 00 if $total == 0;
    return sprintf( "%.2f", ( $value * 100 / $total ) );
}

# Calculates uptime to display in a more attractive form
sub pretty_uptime {
    my $uptime  = shift;
    my $seconds = $uptime % 60;
    my $minutes = int( ( $uptime % 3600 ) / 60 );
    my $hours   = int( ( $uptime % 86400 ) / (3600) );
    my $days    = int( $uptime / (86400) );
    my $uptimestring;
    if ( $days > 0 ) {
        $uptimestring = "${days}d ${hours}h ${minutes}m ${seconds}s";
    }
    elsif ( $hours > 0 ) {
        $uptimestring = "${hours}h ${minutes}m ${seconds}s";
    }
    elsif ( $minutes > 0 ) {
        $uptimestring = "${minutes}m ${seconds}s";
    }
    else {
        $uptimestring = "${seconds}s";
    }
    return $uptimestring;
}

# Retrieves the memory installed on this machine
my ( $physical_memory, $swap_memory, $duflags );

sub os_setup {

    sub memerror {
        badprint
"Unable to determine total memory/swap; use '--forcemem' and '--forceswap'";
        exit 1;
    }
    my $os = `uname`;
    $duflags = ( $os =~ /Linux/ ) ? '-b' : '';
    if ( $opt{'forcemem'} > 0 ) {
        $physical_memory = $opt{'forcemem'} * 1048576;
        infoprint "Assuming $opt{'forcemem'} MB of physical memory";
        if ( $opt{'forceswap'} > 0 ) {
            $swap_memory = $opt{'forceswap'} * 1048576;
            infoprint "Assuming $opt{'forceswap'} MB of swap space";
        }
        else {
            $swap_memory = 0;
            badprint
              "Assuming 0 MB of swap space (use --forceswap to specify)";
        }
    }
    else {
        if ( $os =~ /Linux/ ) {
            $physical_memory =
              `grep -i memtotal: /proc/meminfo | awk '{print \$2}'`
              or memerror;
            $physical_memory *= 1024;

            $swap_memory =
              `grep -i swaptotal: /proc/meminfo | awk '{print \$2}'`
              or memerror;
            $swap_memory *= 1024;
        }
        elsif ( $os =~ /Darwin/ ) {
            $physical_memory = `sysctl -n hw.memsize` or memerror;
            $swap_memory =
              `sysctl -n vm.swapusage | awk '{print \$3}' | sed 's/\..*\$//'`
              or memerror;
        }
        elsif ( $os =~ /NetBSD|OpenBSD|FreeBSD/ ) {
            $physical_memory = `sysctl -n hw.physmem` or memerror;
            if ( $physical_memory < 0 ) {
                $physical_memory = `sysctl -n hw.physmem64` or memerror;
            }
            $swap_memory =
              `swapctl -l | grep '^/' | awk '{ s+= \$2 } END { print s }'`
              or memerror;
        }
        elsif ( $os =~ /BSD/ ) {
            $physical_memory = `sysctl -n hw.realmem` or memerror;
            $swap_memory =
              `swapinfo | grep '^/' | awk '{ s+= \$2 } END { print s }'`;
        }
        elsif ( $os =~ /SunOS/ ) {
            $physical_memory =
              `/usr/sbin/prtconf | grep Memory | cut -f 3 -d ' '`
              or memerror;
            chomp($physical_memory);
            $physical_memory = $physical_memory * 1024 * 1024;
        }
        elsif ( $os =~ /AIX/ ) {
            $physical_memory =
              `lsattr -El sys0 | grep realmem | awk '{print \$2}'`
              or memerror;
            chomp($physical_memory);
            $physical_memory = $physical_memory * 1024;
            $swap_memory     = `lsps -as | awk -F"(MB| +)" '/MB /{print \$2}'`
              or memerror;
            chomp($swap_memory);
            $swap_memory = $swap_memory * 1024 * 1024;
        }
    }
    debugprint "Physical Memory: $physical_memory";
    debugprint "Swap Memory: $swap_memory";
    chomp($physical_memory);
    chomp($swap_memory);
    chomp($os);
    $result{'OS'}{'OS Type'}                   = $os;
    $result{'OS'}{'Physical Memory'}{'bytes'}  = $physical_memory;
    $result{'OS'}{'Physical Memory'}{'pretty'} = hr_bytes($physical_memory);
    $result{'OS'}{'Swap Memory'}{'bytes'}      = $swap_memory;
    $result{'OS'}{'Swap Memory'}{'pretty'}     = hr_bytes($swap_memory);

}

# Checks for updates to MySQLTuner
sub validate_tuner_version {
  if ($opt{checkversion} eq 0) {
    infoprint "Skipped version check for MySQLTuner script";
    return;
  }

  my $update;
  my $url = "https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl";
  my $httpcli=`which curl`;
  chomp($httpcli);
  if ( 1 != 1 and defined($httpcli) and -e "$httpcli" ) {
    debugprint "$httpcli is available.";
    
    debugprint "$httpcli --connect-timeout 5 -silent '$url' 2>/dev/null | grep 'my \$tunerversion'| cut -d\\\" -f2";
    $update = `$httpcli --connect-timeout 5 -silent '$url' 2>/dev/null | grep 'my \$tunerversion'| cut -d\\\" -f2`;
    chomp($update);
    debugprint "VERSION: $update";
    
    
    compare_tuner_version($update);
    return;
  }

  
  $httpcli=`which wget`;
  chomp($httpcli);
  if ( defined($httpcli) and -e "$httpcli" ) {
    debugprint "$httpcli is available.";
    
    debugprint "$httpcli -e timestamping=off -T 5 -O - '$url' 2>$devnull| grep 'my \$tunerversion'| cut -d\\\" -f2";
    $update = `$httpcli -e timestamping=off -T 5 -O - '$url' 2>$devnull| grep 'my \$tunerversion'| cut -d\\\" -f2`;
    chomp($update);
    compare_tuner_version($update);
    return;
  }
  debugprint "curl and wget are not avalaible.";
  infoprint "Unable to check for the latest MySQLTuner version";
}

sub compare_tuner_version {
   my $remoteversion=shift;
   debugprint "Remote data: $remoteversion";
   #exit 0;
   if ($remoteversion ne $tunerversion) {
     badprint "There is a new version of MySQLTuner available ($remoteversion)";
     return;
   }
   goodprint "You have the latest version of MySQLTuner($tunerversion)";
   return;
}

# Checks to see if a MySQL login is possible
my ( $mysqllogin, $doremote, $remotestring, $mysqlcmd, $mysqladmincmd );

sub mysql_setup {
    $doremote     = 0;
    $remotestring = '';
    if ( $opt{mysqladmin} ) {
        $mysqladmincmd = $opt{mysqladmin};
    }
    else {
        $mysqladmincmd = `which mysqladmin`;
    }
    chomp($mysqladmincmd);
    if ( !-e $mysqladmincmd && $opt{mysqladmin} ) {
        badprint "Unable to find the mysqladmin command you specified: "
          . $mysqladmincmd . "";
        exit 1;
    }
    elsif ( !-e $mysqladmincmd ) {
        badprint
          "Couldn't find mysqladmin in your \$PATH. Is MySQL installed?";
        exit 1;
    }
    if ( $opt{mysqlcmd} ) {
        $mysqlcmd = $opt{mysqlcmd};
    }
    else {
        $mysqlcmd = `which mysql`;
    }
    chomp($mysqlcmd);
    if ( !-e $mysqlcmd && $opt{mysqlcmd} ) {
        badprint "Unable to find the mysql command you specified: "
          . $mysqlcmd . "";
        exit 1;
    }
    elsif ( !-e $mysqlcmd ) {
        badprint "Couldn't find mysql in your \$PATH. Is MySQL installed?";
        exit 1;
    }
    $mysqlcmd =~ s/\n$//g;
    my $mysqlclidefaults=`$mysqlcmd --print-defaults`;
    debugprint "MySQL Client: $mysqlclidefaults";
    if ( $mysqlclidefaults=~/auto-vertical-output/ ) {
      badprint "Avoid auto-vertical-output in configuration file(s) for MySQL like";
      exit 1;
    }

    debugprint "MySQL Client: $mysqlcmd";

    # Are we being asked to connect via a socket?
    if ( $opt{socket} ne 0 ) {
        $remotestring = " -S $opt{socket}";
    }

    # Are we being asked to connect to a remote server?
    if ( $opt{host} ne 0 ) {
        chomp( $opt{host} );
        $opt{port} = ( $opt{port} eq 0 ) ? 3306 : $opt{port};

        # If we're doing a remote connection, but forcemem wasn't specified, we need to exit
        if ( $opt{'forcemem'} eq 0 ) {
            badprint
              "The --forcemem option is required for remote connections";
            exit 1;
        }
        infoprint "Performing tests on $opt{host}:$opt{port}";
        $remotestring = " -h $opt{host} -P $opt{port}";
        $doremote     = 1;
    }

    # Did we already get a username and password passed on the command line?
    if ( $opt{user} ne 0 and $opt{pass} ne 0 ) {
        $mysqllogin = "-u $opt{user} -p'$opt{pass}'" . $remotestring;
        my $loginstatus = `$mysqladmincmd ping $mysqllogin 2>&1`;
        if ( $loginstatus =~ /mysqld is alive/ ) {
            goodprint
              "Logged in using credentials passed on the command line";
            return 1;
        }
        else {
            badprint
              "Attempted to use login credentials, but they were invalid";
            exit 1;
        }
    }
    my $svcprop = `which svcprop 2>/dev/null`;
    if ( substr( $svcprop, 0, 1 ) =~ "/" ) {

        # We are on solaris
        ( my $mysql_login =
`svcprop -p quickbackup/username svc:/network/mysql-quickbackup:default`
        ) =~ s/\s+$//;
        ( my $mysql_pass =
`svcprop -p quickbackup/password svc:/network/mysql-quickbackup:default`
        ) =~ s/\s+$//;
        if ( substr( $mysql_login, 0, 7 ) ne "svcprop" ) {

            # mysql-quickbackup is installed
            $mysqllogin = "-u $mysql_login -p$mysql_pass";
            my $loginstatus = `mysqladmin $mysqllogin ping 2>&1`;
            if ( $loginstatus =~ /mysqld is alive/ ) {
                goodprint
                  "Logged in using credentials from mysql-quickbackup.";
                return 1;
            }
            else {
                badprint
"Attempted to use login credentials from mysql-quickbackup, but they failed.";
                exit 1;
            }
        }
    }
    elsif ( -r "/etc/psa/.psa.shadow" and $doremote == 0 ) {

        # It's a Plesk box, use the available credentials
        $mysqllogin = "-u admin -p`cat /etc/psa/.psa.shadow`";
        my $loginstatus = `$mysqladmincmd ping $mysqllogin 2>&1`;
        unless ( $loginstatus =~ /mysqld is alive/ ) {
            badprint
"Attempted to use login credentials from Plesk, but they failed.";
            exit 1;
        }
    }
    elsif ( -r "/usr/local/directadmin/conf/mysql.conf" and $doremote == 0 ) {

        # It's a DirectAdmin box, use the available credentials
        my $mysqluser =
          `cat /usr/local/directadmin/conf/mysql.conf | egrep '^user=.*'`;
        my $mysqlpass =
          `cat /usr/local/directadmin/conf/mysql.conf | egrep '^passwd=.*'`;

        $mysqluser =~ s/user=//;
        $mysqluser =~ s/[\r\n]//;
        $mysqlpass =~ s/passwd=//;
        $mysqlpass =~ s/[\r\n]//;

        $mysqllogin = "-u $mysqluser -p$mysqlpass";

        my $loginstatus = `mysqladmin ping $mysqllogin 2>&1`;
        unless ( $loginstatus =~ /mysqld is alive/ ) {
            badprint
"Attempted to use login credentials from DirectAdmin, but they failed.";
            exit 1;
        }
    }
    elsif ( -r "/etc/mysql/debian.cnf" and $doremote == 0 ) {

        # We have a debian maintenance account, use it
        $mysqllogin = "--defaults-file=/etc/mysql/debian.cnf";
        my $loginstatus = `$mysqladmincmd $mysqllogin ping 2>&1`;
        if ( $loginstatus =~ /mysqld is alive/ ) {
            goodprint
              "Logged in using credentials from debian maintenance account.";
            return 1;
        }
        else {
            badprint
"Attempted to use login credentials from debian maintenance account, but they failed.";
            exit 1;
        }
    }
    else {

        # It's not Plesk or debian, we should try a login
        debugprint "$mysqladmincmd $remotestring ping 2>&1";
        my $loginstatus = `$mysqladmincmd $remotestring ping 2>&1`;
        if ( $loginstatus =~ /mysqld is alive/ ) {

            # Login went just fine
            $mysqllogin = " $remotestring ";

       # Did this go well because of a .my.cnf file or is there no password set?
            my $userpath = `printenv HOME`;
            if ( length($userpath) > 0 ) {
                chomp($userpath);
            }
            unless ( -e "${userpath}/.my.cnf" or -e "${userpath}/.mylogin.cnf" )
            {
                badprint
"Successfully authenticated with no password - SECURITY RISK!";
            }
            return 1;
        }
        else {
            if ( $opt{'noask'}==1 ) {
                badprint "Attempted to use login credentials, but they were invalid";
                exit 1;
            }

            print STDERR "Please enter your MySQL administrative login: ";
            my $name = <>;
            print STDERR "Please enter your MySQL administrative password: ";
            system("stty -echo >$devnull 2>&1");
            my $password = <>;
            system("stty echo >$devnull 2>&1");
            chomp($password);
            chomp($name);
            $mysqllogin = "-u $name";

            if ( length($password) > 0 ) {
                $mysqllogin .= " -p'$password'";
            }
            $mysqllogin .= $remotestring;
            my $loginstatus = `$mysqladmincmd ping $mysqllogin 2>&1`;
            if ( $loginstatus =~ /mysqld is alive/ ) {
                print STDERR "";
                if ( !length($password) ) {

       # Did this go well because of a .my.cnf file or is there no password set?
                    my $userpath = `ls -d ~`;
                    chomp($userpath);
                    unless ( -e "$userpath/.my.cnf" ) {
                        badprint
"Successfully authenticated with no password - SECURITY RISK!";
                    }
                }
                return 1;
            }
            else {
                badprint " Attempted to use login credentials, but they were invalid.";
                exit 1;
            }
            exit 1;
        }
    }
}

# MySQL Request Array
sub select_array {
    my $req = shift;
    debugprint "PERFORM: $req ";
    my @result = `$mysqlcmd $mysqllogin -Bse "$req"`;
    chomp(@result);
    return @result;
}

# MySQL Request one
sub select_one {
    my $req = shift;
    debugprint "PERFORM: $req ";
    my $result = `$mysqlcmd $mysqllogin -Bse "$req"`;
    chomp($result);
    return $result;
}

sub get_tuning_info {
    my @infoconn = select_array "\\s";
    my ( $tkey, $tval );
    @infoconn =
      grep { !/Threads:/ and !/Connection id:/ and !/pager:/ and !/Using/ }
      @infoconn;
    foreach my $line (@infoconn) {
        if ( $line =~ /\s*(.*):\s*(.*)/ ) {
            debugprint "$1 => $2";
            $tkey = $1;
            $tval = $2;
            chomp($tkey);
            chomp($tval);
            $result{'MySQL Client'}{$tkey} = $tval;
        }
    }
    $result{'MySQL Client'}{'Client Path'}         = $mysqlcmd;
    $result{'MySQL Client'}{'Admin Path'}          = $mysqladmincmd;
    $result{'MySQL Client'}{'Authentication Info'} = $mysqllogin;

}

# Populates all of the variable and status hashes
my ( %mystat, %myvar, $dummyselect, %myrepl, %myslaves );

sub get_all_vars {

    # We need to initiate at least one query so that our data is useable
    $dummyselect = select_one "SELECT VERSION()";
    debugprint "VERSION: " . $dummyselect . "";
    $result{'MySQL Client'}{'Version'} = $dummyselect;
    my @mysqlvarlist = select_array "SHOW /*!50000 GLOBAL */ VARIABLES";
    foreach my $line (@mysqlvarlist) {
        $line =~ /([a-zA-Z_]*)\s*(.*)/;
        $myvar{$1} = $2;
        $result{'Variables'}{$1} = $2;
        debugprint "V: $1 = $2";
    }

    my @mysqlstatlist = select_array "SHOW /*!50000 GLOBAL */ STATUS";
    foreach my $line (@mysqlstatlist) {
        $line =~ /([a-zA-Z_]*)\s*(.*)/;
        $mystat{$1} = $2;
        $result{'Status'}{$1} = $2;
        debugprint "S: $1 = $2";
    }

    # Workaround for MySQL bug #59393 wrt. ignore-builtin-innodb
    if ( ( $myvar{'ignore_builtin_innodb'} || "" ) eq "ON" ) {
        $myvar{'have_innodb'} = "NO";
    }

    # have_* for engines is deprecated and will be removed in MySQL 5.6;
    # check SHOW ENGINES and set corresponding old style variables.
    # Also works around MySQL bug #59393 wrt. skip-innodb
    my @mysqlenginelist = select_array "SHOW ENGINES";
    foreach my $line (@mysqlenginelist) {
        if ( $line =~ /^([a-zA-Z_]+)\s+(\S+)/ ) {
            my $engine = lc($1);

            if ( $engine eq "federated" || $engine eq "blackhole" ) {
                $engine .= "_engine";
            }
            elsif ( $engine eq "berkeleydb" ) {
                $engine = "bdb";
            }
            my $val = ( $2 eq "DEFAULT" ) ? "YES" : $2;
            $myvar{"have_$engine"} = $val;
            $result{'Storage Engines'}{$engine} = $2;
        }
    }

    my @mysqlslave = select_array "SHOW SLAVE STATUS\\G";

    foreach my $line (@mysqlslave) {
        if ( $line =~ /\s*(.*):\s*(.*)/ ) {
            debugprint "$1 => $2";
            $myrepl{"$1"} = $2;
            $result{'Replication'}{'Status'}{$1} = $2;
        }
    }

    #print Dumper(%myrepl);
    #exit 0;
    my @mysqlslaves = select_array "SHOW SLAVE HOSTS";
    my @lineitems   = ();
    foreach my $line (@mysqlslaves) {
        debugprint "L: $line ";
        @lineitems = split /\s+/, $line;
        $myslaves{ $lineitems[0] } = $line;
        $result{'Replication'}{'Slaves'}{ $lineitems[0] } = $lineitems[4];
    }
}

sub get_basic_passwords {
    my $file = shift;
    open( FH, "< $file" ) or die "Can't open $file for read: $!";
    my @lines = <FH>;
    close FH or die "Cannot close $file: $!";
    return @lines;
}

sub security_recommendations {
    prettyprint
"\n-------- Security Recommendations  -------------------------------------------";
    if ( $opt{skippassword} eq 1 ) {
        infoprint "Skipped due to --skippassword option";
        return;
    }

    # Looking for Anonymous users
    my @mysqlstatlist = select_array
"SELECT CONCAT(user, '\@', host) FROM mysql.user WHERE TRIM(USER) = '' OR USER IS NULL";
    if (@mysqlstatlist) {
        foreach my $line ( sort @mysqlstatlist ) {
            chomp($line);
            badprint "User '" . $line . "' is an anonymous account.";
        }
        push( @generalrec,
                "Remove Anonymous User accounts - there are "
              . scalar(@mysqlstatlist)
              . " Anonymous accounts." );
    }
    else {
        goodprint "There is no anonymous account in all database users";
    }

    # Looking for Empty Password
    @mysqlstatlist = select_array
"SELECT CONCAT(user, '\@', host) FROM mysql.user WHERE password = '' OR password IS NULL";
    if (@mysqlstatlist) {
        foreach my $line ( sort @mysqlstatlist ) {
            chomp($line);
            badprint "User '" . $line . "' has no password set.";
        }
        push( @generalrec,
"Set up a Password for user with the following SQL statement ( SET PASSWORD FOR 'user'\@'SpecificDNSorIp' = PASSWORD('secure_password'); )"
        );
    }
    else {
        goodprint "All database users have passwords assigned";
    }

    # Looking for User with user/ uppercase /capitalise user as password
    @mysqlstatlist = select_array
"SELECT CONCAT(user, '\@', host) FROM mysql.user WHERE CAST(password as Binary) = PASSWORD(user) OR CAST(password as Binary) = PASSWORD(UPPER(user)) OR CAST(password as Binary) = PASSWORD(UPPER(LEFT(User, 1)) + SUBSTRING(User, 2, LENGTH(User)))";
    if (@mysqlstatlist) {
        foreach my $line ( sort @mysqlstatlist ) {
            chomp($line);
            badprint "User '" . $line . "' has user name as password.";
        }
        push( @generalrec,
"Set up a Secure Password for user\@host ( SET PASSWORD FOR 'user'\@'SpecificDNSorIp' = PASSWORD('secure_password'); )"
        );
    }

    @mysqlstatlist = select_array
      "SELECT CONCAT(user, '\@', host) FROM mysql.user WHERE HOST='%'";
    if (@mysqlstatlist) {
        foreach my $line ( sort @mysqlstatlist ) {
            chomp($line);
            badprint "User '" . $line . "' hasn't specific host restriction.";
        }
        push( @generalrec,
            "Restrict Host for user\@% to user\@SpecificDNSorIp" );
    }

    unless ( -f $basic_password_files ) {
        badprint "There is not basic password file list !";
        return;
    }

    my @passwords = get_basic_passwords $basic_password_files;
    infoprint "There is "
      . scalar(@passwords)
      . " basic passwords in the list.";
    my $nbins = 0;
    my $passreq;
    if (@passwords) {
        foreach my $pass (@passwords) {
            $pass =~ s/\s//g;
            chomp($pass);

            # Looking for User with user/ uppercase /capitalise weak password
            @mysqlstatlist =
              select_array
"SELECT CONCAT(user, '\@', host) FROM mysql.user WHERE password = PASSWORD('"
              . $pass
              . "') OR password = PASSWORD(UPPER('"
              . $pass
              . "')) OR password = PASSWORD(UPPER(LEFT('"
              . $pass
              . "', 1)) + SUBSTRING('"
              . $pass
              . "', 2, LENGTH('"
              . $pass . "')))";
            debugprint "There is " . scalar(@mysqlstatlist) . " items.";
            if (@mysqlstatlist) {
                foreach my $line (@mysqlstatlist) {
                    chomp($line);
                    badprint "User '" . $line
                      . "' is using weak pasword: $pass in a lower, upper or capitalize derivated version.";
                    $nbins++;
                }
            }
        }
    }
    if ( $nbins > 0 ) {
        push( @generalrec, $nbins . " user(s) used basic or weaked password." );
    }
}

sub get_replication_status {
    prettyprint
"\n-------- Replication Metrics -------------------------------------------------";

    if ( scalar( keys %myslaves ) == 0 ) {
        infoprint "No replication slave(s) for this server.";
    }
    else {
        infoprint "This server is acting as master for "
          . scalar( keys %myslaves )
          . " server(s).";
    }

    if ( scalar( keys %myrepl ) == 0 and scalar( keys %myslaves ) == 0 ) {
        infoprint "This is a standalone server..";
        return;
    }
    if ( scalar( keys %myrepl ) == 0 ) {
        infoprint "No replication setup for this server.";
        return;
    }
    my ($io_running) = $myrepl{'Slave_IO_Running'};
    debugprint "IO RUNNING: $io_running ";
    my ($sql_running) = $myrepl{'Slave_SQL_Running'};
    debugprint "SQL RUNNING: $sql_running ";
    my ($seconds_behind_master) = $myrepl{'Seconds_Behind_Master'};
    debugprint "SECONDS : $seconds_behind_master ";

    if ( defined($io_running)
        and ( $io_running !~ /yes/i or $sql_running !~ /yes/i ) )
    {
        badprint
"This replication slave is not running but seems to be configurated.";
    }
    if (   defined($io_running)
        && $io_running  =~ /yes/i
        && $sql_running =~ /yes/i )
    {
        if ( $myvar{'read_only'} eq 'OFF' ) {
            badprint
"This replication slave is running with the read_only option disabled.";
        }
        else {
            goodprint
"This replication slave is running with the read_only option enabled.";
        }
        if ( $seconds_behind_master > 0 ) {
            badprint
"This replication slave is lagging and slave has $seconds_behind_master second(s) behind master host.";
        }
        else {
            goodprint "This replication slave is uptodate with master.";
        }
    }
}

# Checks for supported or EOL'ed MySQL versions
my ( $mysqlvermajor, $mysqlverminor, $mysqlvermicro );

sub validate_mysql_version {
    ( $mysqlvermajor, $mysqlverminor, $mysqlvermicro ) =
      $myvar{'version'} =~ /^(\d+)(?:\.(\d+)|)(?:\.(\d+)|)/;
    $mysqlverminor ||= 0;
    $mysqlvermicro ||= 0;
    if ( !mysql_version_ge( 5, 1 ) ) {
        badprint "Your MySQL version "
          . $myvar{'version'}
          . " is EOL software!  Upgrade soon!";
    }
    elsif ( ( mysql_version_ge(6) and mysql_version_le(9) ) or  mysql_version_ge(12) ) {
        badprint "Currently running unsupported MySQL version "
          . $myvar{'version'} . "";
    } else {
        goodprint "Currently running supported MySQL version "
          . $myvar{'version'} . "";
    }
}

# Checks if MySQL version is greater than equal to (major, minor, micro)
sub mysql_version_ge {
    my ( $maj, $min, $mic ) = @_;
    $min ||= 0;
    $mic ||= 0;
    return $mysqlvermajor > $maj
      || $mysqlvermajor == $maj
      && ( $mysqlverminor > $min
        || $mysqlverminor == $min && $mysqlvermicro >= $mic );
}

# Checks if MySQL version is lower than equal to (major, minor, micro)
sub mysql_version_le {
    my ( $maj, $min, $mic ) = @_;
    $min ||= 0;
    $mic ||= 0;
    return $mysqlvermajor < $maj
      || $mysqlvermajor == $maj
      && ( $mysqlverminor < $min
        || $mysqlverminor == $min && $mysqlvermicro <= $mic );
}

# Checks for 32-bit boxes with more than 2GB of RAM
my ($arch);

sub check_architecture {
    if ( $doremote eq 1 ) { return; }
    if ( `uname` =~ /SunOS/ && `isainfo -b` =~ /64/ ) {
        $arch = 64;
        goodprint "Operating on 64-bit architecture";
    }
    elsif ( `uname` !~ /SunOS/ && `uname -m` =~ /64/ ) {
        $arch = 64;
        goodprint "Operating on 64-bit architecture";
    }
    elsif ( `uname` =~ /AIX/ && `bootinfo -K` =~ /64/ ) {
        $arch = 64;
        goodprint "Operating on 64-bit architecture";
    }
    elsif ( `uname` =~ /NetBSD|OpenBSD/ && `sysctl -b hw.machine` =~ /64/ ) {
        $arch = 64;
        goodprint "Operating on 64-bit architecture";
    }
    elsif ( `uname` =~ /FreeBSD/ && `sysctl -b hw.machine_arch` =~ /64/ ) {
        $arch = 64;
        goodprint "Operating on 64-bit architecture";
    }
    elsif ( `uname` =~ /Darwin/ && `uname -m` =~ /Power Macintosh/ ) {

# Darwin box.local 9.8.0 Darwin Kernel Version 9.8.0: Wed Jul 15 16:57:01 PDT 2009; root:xnu1228.15.4~1/RELEASE_PPC Power Macintosh
        $arch = 64;
        goodprint "Operating on 64-bit architecture";
    }
    elsif ( `uname` =~ /Darwin/ && `uname -m` =~ /x86_64/ ) {

# Darwin gibas.local 12.3.0 Darwin Kernel Version 12.3.0: Sun Jan  6 22:37:10 PST 2013; root:xnu-2050.22.13~1/RELEASE_X86_64 x86_64
        $arch = 64;
        goodprint "Operating on 64-bit architecture";
    }
    else {
        $arch = 32;
        if ( $physical_memory > 2147483648 ) {
            badprint
"Switch to 64-bit OS - MySQL cannot currently use all of your RAM";
        }
        else {
            goodprint
              "Operating on 32-bit architecture with less than 2GB RAM";
        }
    }
    $result{'OS'}{'Architecture'} = "$arch bits";
}

# Start up a ton of storage engine counts/statistics
my ( %enginestats, %enginecount, $fragtables );

sub check_storage_engines {
    if ( $opt{skipsize} eq 1 ) {
        prettyprint
"\n-------- Storage Engine Statistics -------------------------------------------";
        infoprint "Skipped due to --skipsize option";
        return;
    }
    prettyprint
"\n-------- Storage Engine Statistics -------------------------------------------";

    my $engines;
    if ( mysql_version_ge( 5, 1, 5 ) ) {
        my @engineresults = select_array
"SELECT ENGINE,SUPPORT FROM information_schema.ENGINES WHERE ENGINE NOT IN ('performance_schema','MyISAM','MERGE','MEMORY') ORDER BY ENGINE ASC";
        foreach my $line (@engineresults) {
            my ( $engine, $engineenabled );
            ( $engine, $engineenabled ) = $line =~ /([a-zA-Z_]*)\s+([a-zA-Z]+)/;
            $result{'Engine'}{$engine}{'Enabled'} = $engineenabled;
            $engines .=
              ( $engineenabled eq "YES" || $engineenabled eq "DEFAULT" )
              ? greenwrap "+" . $engine . " "
              : redwrap "-" . $engine . " ";
        }
    }
    else {
        $engines .=
          ( defined $myvar{'have_archive'} && $myvar{'have_archive'} eq "YES" )
          ? greenwrap "+Archive "
          : redwrap "-Archive ";
        $engines .=
          ( defined $myvar{'have_bdb'} && $myvar{'have_bdb'} eq "YES" )
          ? greenwrap "+BDB "
          : redwrap "-BDB ";
        $engines .=
          ( defined $myvar{'have_federated_engine'}
              && $myvar{'have_federated_engine'} eq "YES" )
          ? greenwrap "+Federated "
          : redwrap "-Federated ";
        $engines .=
          ( defined $myvar{'have_innodb'} && $myvar{'have_innodb'} eq "YES" )
          ? greenwrap "+InnoDB "
          : redwrap "-InnoDB ";
        $engines .=
          ( defined $myvar{'have_isam'} && $myvar{'have_isam'} eq "YES" )
          ? greenwrap "+ISAM "
          : redwrap "-ISAM ";
        $engines .=
          ( defined $myvar{'have_aria'} && $myvar{'have_aria'} eq "YES" )
          ? greenwrap "+Aria "
          : redwrap "-Aria ";
        $engines .=
          ( defined $myvar{'have_ndbcluster'}
              && $myvar{'have_ndbcluster'} eq "YES" )
          ? greenwrap "+NDBCluster "
          : redwrap "-NDBCluster ";
    }

    my @dblist = grep {$_ ne 'lost+found' } select_array "SHOW DATABASES";

    $result{'Databases'}{'List'} = [@dblist];
    infoprint "Status: $engines";
    if ( mysql_version_ge( 5, 1, 5 ) ) {

# MySQL 5 servers can have table sizes calculated quickly from information schema
        my @templist = select_array
"SELECT ENGINE,SUM(DATA_LENGTH+INDEX_LENGTH),COUNT(ENGINE),SUM(DATA_LENGTH),SUM(INDEX_LENGTH) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql') AND ENGINE IS NOT NULL GROUP BY ENGINE ORDER BY ENGINE ASC;";

        my ( $engine, $size, $count, $dsize, $isize );
        foreach my $line (@templist) {
            ( $engine, $size, $count, $dsize, $isize ) =
              $line =~ /([a-zA-Z_]*)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/;
            if ( !defined($size) ) { next; }
            $enginestats{$engine}                      = $size;
            $enginecount{$engine}                      = $count;
            $result{'Engine'}{$engine}{'Table Number'} = $count;
            $result{'Engine'}{$engine}{'Total Size'}   = $size;
            $result{'Engine'}{$engine}{'Data Size'}    = $dsize;
            $result{'Engine'}{$engine}{'Index Size'}   = $isize;
        }
        $fragtables = select_one
"SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema','performance_schema', 'mysql') AND Data_free > 0 AND NOT ENGINE='MEMORY'";
        chomp($fragtables);
        $result{'Tables'}{'Fragmented tables'} =
          [ select_array
"SELECT CONCAT(CONCAT(TABLE_SCHEMA, '.'), TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema','performance_schema', 'mysql') AND Data_free > 0 AND NOT ENGINE='MEMORY'"
          ];

    }
    else {

        # MySQL < 5 servers take a lot of work to get table sizes
        my @tblist;

        # Now we build a database list, and loop through it to get storage engine stats for tables
        foreach my $db (@dblist) {
            chomp($db);
            if (   $db eq "information_schema"
                or $db eq "performance_schema"
                or $db eq "mysql" 
                or $db eq "lost+found" )
            {
                next;
            }
            my @ixs = ( 1, 6, 9 );
            if ( !mysql_version_ge( 4, 1 ) ) {

                # MySQL 3.23/4.0 keeps Data_Length in the 5th (0-based) column
                @ixs = ( 1, 5, 8 );
            }
            push( @tblist,
                map { [ (split)[@ixs] ] }
                  select_array "SHOW TABLE STATUS FROM \\\`$db\\\`" );
        }

     # Parse through the table list to generate storage engine counts/statistics
        $fragtables = 0;
        foreach my $tbl (@tblist) {
            debugprint "Data dump ". Dumper (@$tbl);
            my ( $engine, $size, $datafree ) = @$tbl;
            next if $engine eq 'NULL';
            $size=0 if $size eq 'NULL';
            $datafree=0 if $datafree eq 'NULL';
            if ( defined $enginestats{$engine} ) {
                $enginestats{$engine} += $size;
                $enginecount{$engine} += 1;
            }
            else {
                $enginestats{$engine} = $size;
                $enginecount{$engine} = 1;
            }
            if ( $datafree > 0 ) {
                $fragtables++;
            }
        }
    }
    while ( my ( $engine, $size ) = each(%enginestats) ) {
        infoprint "Data in $engine tables: "
          . hr_bytes_rnd($size)
          . " (Tables: "
          . $enginecount{$engine} . ")" . "";
    }

    # If the storage engine isn't being used, recommend it to be disabled
    if (  !defined $enginestats{'InnoDB'}
        && defined $myvar{'have_innodb'}
        && $myvar{'have_innodb'} eq "YES" )
    {
        badprint "InnoDB is enabled but isn't being used";
        push( @generalrec,
            "Add skip-innodb to MySQL configuration to disable InnoDB" );
    }
    if (  !defined $enginestats{'BerkeleyDB'}
        && defined $myvar{'have_bdb'}
        && $myvar{'have_bdb'} eq "YES" )
    {
        badprint "BDB is enabled but isn't being used";
        push( @generalrec,
            "Add skip-bdb to MySQL configuration to disable BDB" );
    }
    if (  !defined $enginestats{'ISAM'}
        && defined $myvar{'have_isam'}
        && $myvar{'have_isam'} eq "YES" )
    {
        badprint "MYISAM is enabled but isn't being used";
        push( @generalrec,
"Add skip-isam to MySQL configuration to disable ISAM (MySQL > 4.1.0)"
        );
    }

    # Fragmented tables
    if ( $fragtables > 0 ) {
        badprint "Total fragmented tables: $fragtables";
        push( @generalrec,
            "Run OPTIMIZE TABLE to defragment tables for better performance" );
    }
    else {
        goodprint "Total fragmented tables: $fragtables";
    }

    # Auto increments
    my %tblist;

    # Find the maximum integer
    my $maxint = select_one "SELECT ~0";
    $result{'MaxInt'} = $maxint;

# Now we use a database list, and loop through it to get storage engine stats for tables
    foreach my $db (@dblist) {
        chomp($db);

        if ( !$tblist{$db} ) {
            $tblist{$db} = ();
        }

        if ( $db eq "information_schema" ) { next; }
        my @ia = ( 0, 10 );
        if ( !mysql_version_ge( 4, 1 ) ) {

            # MySQL 3.23/4.0 keeps Data_Length in the 5th (0-based) column
            @ia = ( 0, 9 );
        }
        push(
            @{ $tblist{$db} },
            map { [ (split)[@ia] ] }
              select_array "SHOW TABLE STATUS FROM \\\`$db\\\`"
        );
    }

    my @dbnames = keys %tblist;

    foreach my $db (@dbnames) {
        foreach my $tbl ( @{ $tblist{$db} } ) {
            my ( $name, $autoincrement ) = @$tbl;

            if ( $autoincrement =~ /^\d+?$/ ) {
                my $percent = percentage( $autoincrement, $maxint );
                $result{'PctAutoIncrement'}{"$db.$name"} = $percent;
                if ( $percent >= 75 ) {
                    badprint
"Table '$db.$name' has an autoincrement value near max capacity ($percent%)";
                }
            }
        }
    }

}

my %mycalc;

sub calculations {
    if ( $mystat{'Questions'} < 1 ) {
        badprint
          "Your server has not answered any queries - cannot continue...";
        exit 2;
    }

    # Per-thread memory
    if ( mysql_version_ge(4) ) {
        $mycalc{'per_thread_buffers'} =
          $myvar{'read_buffer_size'} +
          $myvar{'read_rnd_buffer_size'} +
          $myvar{'sort_buffer_size'} +
          $myvar{'thread_stack'} +
          $myvar{'join_buffer_size'};
    }
    else {
        $mycalc{'per_thread_buffers'} =
          $myvar{'record_buffer'} +
          $myvar{'record_rnd_buffer'} +
          $myvar{'sort_buffer'} +
          $myvar{'thread_stack'} +
          $myvar{'join_buffer_size'};
    }
    $mycalc{'total_per_thread_buffers'} =
      $mycalc{'per_thread_buffers'} * $myvar{'max_connections'};
    $mycalc{'max_total_per_thread_buffers'} =
      $mycalc{'per_thread_buffers'} * $mystat{'Max_used_connections'};

    # Server-wide memory
    $mycalc{'max_tmp_table_size'} =
      ( $myvar{'tmp_table_size'} > $myvar{'max_heap_table_size'} )
      ? $myvar{'max_heap_table_size'}
      : $myvar{'tmp_table_size'};
    $mycalc{'server_buffers'} =
      $myvar{'key_buffer_size'} + $mycalc{'max_tmp_table_size'};
    $mycalc{'server_buffers'} +=
      ( defined $myvar{'innodb_buffer_pool_size'} )
      ? $myvar{'innodb_buffer_pool_size'}
      : 0;
    $mycalc{'server_buffers'} +=
      ( defined $myvar{'innodb_additional_mem_pool_size'} )
      ? $myvar{'innodb_additional_mem_pool_size'}
      : 0;
    $mycalc{'server_buffers'} +=
      ( defined $myvar{'innodb_log_buffer_size'} )
      ? $myvar{'innodb_log_buffer_size'}
      : 0;
    $mycalc{'server_buffers'} +=
      ( defined $myvar{'query_cache_size'} ) ? $myvar{'query_cache_size'} : 0;
    $mycalc{'server_buffers'} +=
      ( defined $myvar{'aria_pagecache_buffer_size'} )
      ? $myvar{'aria_pagecache_buffer_size'}
      : 0;

# Global memory
# Max used memory is memory used by MySQL based on Max_used_connections
# This is the max memory used theorically calculated with the max concurrent connection number reached by mysql
    $mycalc{'max_used_memory'} =
      $mycalc{'server_buffers'} + $mycalc{"max_total_per_thread_buffers"};
    $mycalc{'pct_max_used_memory'} =
      percentage( $mycalc{'max_used_memory'}, $physical_memory );

# Total possible memory is memory needed by MySQL based on max_connections
# This is the max memory MySQL can theorically used if all connections allowed has opened by mysql
    $mycalc{'max_peak_memory'} =
      $mycalc{'server_buffers'} + $mycalc{'total_per_thread_buffers'};
    $mycalc{'pct_max_physical_memory'} =
      percentage( $mycalc{'max_peak_memory'}, $physical_memory );

    debugprint "Max Used Memory: "
      . hr_bytes( $mycalc{'max_used_memory'} ) . "";
    debugprint "Max Used Percentage RAM: "
      . $mycalc{'pct_max_used_memory'} . "%";

    debugprint "Max Peak Memory: "
      . hr_bytes( $mycalc{'max_peak_memory'} ) . "";
    debugprint "Max Peak Percentage RAM: "
      . $mycalc{'pct_max_physical_memory'} . "%";

    # Slow queries
    $mycalc{'pct_slow_queries'} =
      int( ( $mystat{'Slow_queries'} / $mystat{'Questions'} ) * 100 );

    # Connections
    $mycalc{'pct_connections_used'} = int(
        ( $mystat{'Max_used_connections'} / $myvar{'max_connections'} ) * 100 );
    $mycalc{'pct_connections_used'} =
      ( $mycalc{'pct_connections_used'} > 100 )
      ? 100
      : $mycalc{'pct_connections_used'};

    # Aborted Connections
    $mycalc{'pct_connections_aborted'} =
      percentage( $mystat{'Aborted_connects'}, $mystat{'Connections'} );
    debugprint "Aborted_connects: " . $mystat{'Aborted_connects'} . "";
    debugprint "Connections: " . $mystat{'Connections'} . "";
    debugprint "pct_connections_aborted: "
      . $mycalc{'pct_connections_aborted'} . "";

    # Key buffers
    if ( mysql_version_ge( 4, 1 ) && $myvar{'key_buffer_size'} > 0 ) {
        $mycalc{'pct_key_buffer_used'} = sprintf(
            "%.1f",
            (
                1 - (
                    (
                        $mystat{'Key_blocks_unused'} *
                          $myvar{'key_cache_block_size'}
                    ) / $myvar{'key_buffer_size'}
                )
              ) * 100
        );
    }
    else {
        $mycalc{'pct_key_buffer_used'} = 0;
    }

    if ( $mystat{'Key_read_requests'} > 0 ) {
        $mycalc{'pct_keys_from_mem'} = sprintf(
            "%.1f",
            (
                100 - (
                    ( $mystat{'Key_reads'} / $mystat{'Key_read_requests'} ) *
                      100
                )
            )
        );
    }
    else {
        $mycalc{'pct_keys_from_mem'} = 0;
    }
    if ( defined $mystat{'Aria_pagecache_read_requests'}
        && $mystat{'Aria_pagecache_read_requests'} > 0 )
    {
        $mycalc{'pct_aria_keys_from_mem'} = sprintf(
            "%.1f",
            (
                100 - (
                    (
                        $mystat{'Aria_pagecache_reads'} /
                          $mystat{'Aria_pagecache_read_requests'}
                    ) * 100
                )
            )
        );
    }
    else {
        $mycalc{'pct_aria_keys_from_mem'} = 0;
    }

    if ( $mystat{'Key_write_requests'} > 0 ) {
        $mycalc{'pct_wkeys_from_mem'} = sprintf(
            "%.1f",
            (
                100 - (
                    ( $mystat{'Key_writes'} / $mystat{'Key_write_requests'} ) *
                      100
                )
            )
        );
    }
    else {
        $mycalc{'pct_wkeys_from_mem'} = 0;
    }

    if ( $doremote eq 0 and !mysql_version_ge(5) ) {
        my $size = 0;
        $size += (split)[0]
          for
`find $myvar{'datadir'} -name "*.MYI" 2>&1 | xargs du -L $duflags 2>&1`;
        $mycalc{'total_myisam_indexes'} = $size;
        $mycalc{'total_aria_indexes'}   = 0;
    }
    elsif ( mysql_version_ge(5) ) {
        $mycalc{'total_myisam_indexes'} = select_one
"SELECT IFNULL(SUM(INDEX_LENGTH),0) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema') AND ENGINE = 'MyISAM';";
        $mycalc{'total_aria_indexe'} = select_one
"SELECT IFNULL(SUM(INDEX_LENGTH),0) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema') AND ENGINE = 'Aria';";
    }
    if ( defined $mycalc{'total_myisam_indexes'}
        and $mycalc{'total_myisam_indexes'} == 0 )
    {
        $mycalc{'total_myisam_indexes'} = "fail";
    }
    elsif ( defined $mycalc{'total_myisam_indexes'} ) {
        chomp( $mycalc{'total_myisam_indexes'} );
    }
    if ( defined $mycalc{'total_aria_indexes'}
        and $mycalc{'total_aria_indexes'} == 0 )
    {
        $mycalc{'total_aria_indexes'} = "fail";
    }
    elsif ( defined $mycalc{'total_aria_indexes'} ) {
        chomp( $mycalc{'total_aria_indexes'} );
    }

    # Query cache
    if ( mysql_version_ge(4) ) {
        $mycalc{'query_cache_efficiency'} = sprintf(
            "%.1f",
            (
                $mystat{'Qcache_hits'} /
                  ( $mystat{'Com_select'} + $mystat{'Qcache_hits'} )
              ) * 100
        );
        if ( $myvar{'query_cache_size'} ) {
            $mycalc{'pct_query_cache_used'} = sprintf(
                "%.1f",
                100 - (
                    $mystat{'Qcache_free_memory'} / $myvar{'query_cache_size'}
                  ) * 100
            );
        }
        if ( $mystat{'Qcache_lowmem_prunes'} == 0 ) {
            $mycalc{'query_cache_prunes_per_day'} = 0;
        }
        else {
            $mycalc{'query_cache_prunes_per_day'} = int(
                $mystat{'Qcache_lowmem_prunes'} / ( $mystat{'Uptime'} / 86400 )
            );
        }
    }

    # Sorting
    $mycalc{'total_sorts'} = $mystat{'Sort_scan'} + $mystat{'Sort_range'};
    if ( $mycalc{'total_sorts'} > 0 ) {
        $mycalc{'pct_temp_sort_table'} = int(
            ( $mystat{'Sort_merge_passes'} / $mycalc{'total_sorts'} ) * 100 );
    }

    # Joins
    $mycalc{'joins_without_indexes'} =
      $mystat{'Select_range_check'} + $mystat{'Select_full_join'};
    $mycalc{'joins_without_indexes_per_day'} =
      int( $mycalc{'joins_without_indexes'} / ( $mystat{'Uptime'} / 86400 ) );

    # Temporary tables
    if ( $mystat{'Created_tmp_tables'} > 0 ) {
        if ( $mystat{'Created_tmp_disk_tables'} > 0 ) {
            $mycalc{'pct_temp_disk'} = int(
                (
                    $mystat{'Created_tmp_disk_tables'} /
                      $mystat{'Created_tmp_tables'}
                ) * 100
            );
        }
        else {
            $mycalc{'pct_temp_disk'} = 0;
        }
    }

    # Table cache
    if ( $mystat{'Opened_tables'} > 0 ) {
        $mycalc{'table_cache_hit_rate'} =
          int( $mystat{'Open_tables'} * 100 / $mystat{'Opened_tables'} );
    }
    else {
        $mycalc{'table_cache_hit_rate'} = 100;
    }

    # Open files
    if ( $myvar{'open_files_limit'} > 0 ) {
        $mycalc{'pct_files_open'} =
          int( $mystat{'Open_files'} * 100 / $myvar{'open_files_limit'} );
    }

    # Table locks
    if ( $mystat{'Table_locks_immediate'} > 0 ) {
        if ( $mystat{'Table_locks_waited'} == 0 ) {
            $mycalc{'pct_table_locks_immediate'} = 100;
        }
        else {
            $mycalc{'pct_table_locks_immediate'} = int(
                $mystat{'Table_locks_immediate'} * 100 / (
                    $mystat{'Table_locks_waited'} +
                      $mystat{'Table_locks_immediate'}
                )
            );
        }
    }

    # Thread cache
    $mycalc{'thread_cache_hit_rate'} =
      int( 100 -
          ( ( $mystat{'Threads_created'} / $mystat{'Connections'} ) * 100 ) );

    # Other
    if ( $mystat{'Connections'} > 0 ) {
        $mycalc{'pct_aborted_connections'} =
          int( ( $mystat{'Aborted_connects'} / $mystat{'Connections'} ) * 100 );
    }
    if ( $mystat{'Questions'} > 0 ) {
        $mycalc{'total_reads'} = $mystat{'Com_select'};
        $mycalc{'total_writes'} =
          $mystat{'Com_delete'} +
          $mystat{'Com_insert'} +
          $mystat{'Com_update'} +
          $mystat{'Com_replace'};
        if ( $mycalc{'total_reads'} == 0 ) {
            $mycalc{'pct_reads'}  = 0;
            $mycalc{'pct_writes'} = 100;
        }
        else {
            $mycalc{'pct_reads'} = int(
                (
                    $mycalc{'total_reads'} /
                      ( $mycalc{'total_reads'} + $mycalc{'total_writes'} )
                ) * 100
            );
            $mycalc{'pct_writes'} = 100 - $mycalc{'pct_reads'};
        }
    }

    # InnoDB
    if ( $myvar{'have_innodb'} eq "YES" ) {
        $mycalc{'innodb_log_size_pct'} =
          ( $myvar{'innodb_log_file_size'} * 100 /
              $myvar{'innodb_buffer_pool_size'} );
    }
    (
        $mystat{'Innodb_buffer_pool_read_requests'},
        $mystat{'Innodb_buffer_pool_reads'}
      )
      = ( 1, 1 )
      unless defined $mystat{'Innodb_buffer_pool_reads'};
    $mycalc{'pct_read_efficiency'} = percentage(
        (
            $mystat{'Innodb_buffer_pool_read_requests'} -
              $mystat{'Innodb_buffer_pool_reads'}
        ),
        $mystat{'Innodb_buffer_pool_read_requests'}
    ) if defined $mystat{'Innodb_buffer_pool_read_requests'};
    debugprint "pct_read_efficiency: " . $mycalc{'pct_read_efficiency'} . "";
    debugprint "Innodb_buffer_pool_reads: "
      . $mystat{'Innodb_buffer_pool_reads'} . "";
    debugprint "Innodb_buffer_pool_read_requests: "
      . $mystat{'Innodb_buffer_pool_read_requests'} . "";
    (
        $mystat{'Innodb_buffer_pool_write_requests'},
        $mystat{'Innodb_buffer_pool_writes'}
      )
      = ( 1, 1 )
      unless defined $mystat{'Innodb_buffer_pool_writes'};
    $mycalc{'pct_write_efficiency'} = percentage(
        (
            $mystat{'Innodb_buffer_pool_write_requests'} -
              $mystat{'Innodb_buffer_pool_writes'}
        ),
        $mystat{'Innodb_buffer_pool_write_requests'}
    ) if defined $mystat{'Innodb_buffer_pool_write_requests'};
    debugprint "pct_write_efficiency: " . $mycalc{'pct_read_efficiency'} . "";
    debugprint "Innodb_buffer_pool_writes: "
      . $mystat{'Innodb_buffer_pool_writes'} . "";
    debugprint "Innodb_buffer_pool_write_requests: "
      . $mystat{'Innodb_buffer_pool_write_requests'} . "";
    $mycalc{'pct_innodb_buffer_used'} = percentage(
        (
            $mystat{'Innodb_buffer_pool_pages_total'} -
              $mystat{'Innodb_buffer_pool_pages_free'}
        ),
        $mystat{'Innodb_buffer_pool_pages_total'}
    ) if defined $mystat{'Innodb_buffer_pool_pages_total'};

    # Binlog Cache
    if ( $myvar{'log_bin'} ne 'OFF' ) {
        $mycalc{'pct_binlog_cache'} = percentage(
            $mystat{'Binlog_cache_use'} - $mystat{'Binlog_cache_disk_use'},
            $mystat{'Binlog_cache_use'} );
    }
}

sub mysql_stats {
    prettyprint
"\n-------- Performance Metrics -------------------------------------------------";

    # Show uptime, queries per second, connections, traffic stats
    my $qps;
    if ( $mystat{'Uptime'} > 0 ) {
        $qps = sprintf( "%.3f", $mystat{'Questions'} / $mystat{'Uptime'} );
    }
    push( @generalrec,
        "MySQL started within last 24 hours - recommendations may be inaccurate"
    ) if ( $mystat{'Uptime'} < 86400 );
    infoprint "Up for: "
      . pretty_uptime( $mystat{'Uptime'} ) . " ("
      . hr_num( $mystat{'Questions'} ) . " q ["
      . hr_num($qps)
      . " qps], "
      . hr_num( $mystat{'Connections'} )
      . " conn," . " TX: "
      . hr_num( $mystat{'Bytes_sent'} )
      . ", RX: "
      . hr_num( $mystat{'Bytes_received'} ) . ")";
    infoprint "Reads / Writes: "
      . $mycalc{'pct_reads'} . "% / "
      . $mycalc{'pct_writes'} . "%";

    # Binlog Cache
    if ( $myvar{'log_bin'} eq 'OFF' ) {
        infoprint "Binary logging is disabled";
    }
    else {
        infoprint "Binary logging is enabled (GTID MODE: "
          . ( defined( $myvar{'gtid_mode'} ) ? $myvar{'gtid_mode'} : "OFF" )
          . ")";
    }

    # Memory usage
    infoprint "Total buffers: "
      . hr_bytes( $mycalc{'server_buffers'} )
      . " global + "
      . hr_bytes( $mycalc{'per_thread_buffers'} )
      . " per thread ($myvar{'max_connections'} max threads)";

    if ( $opt{buffers} ne 0 ) {
        infoprint "Global Buffers";
        infoprint " +-- Key Buffer: "
          . hr_bytes( $myvar{'key_buffer_size'} ) . "";
        infoprint " +-- Max Tmp Table: "
          . hr_bytes( $mycalc{'max_tmp_table_size'} ) . "";

        if ( defined $myvar{'query_cache_type'} ) {
            infoprint "Query Cache Buffers";
            infoprint " +-- Query Cache: " 
              . $myvar{'query_cache_type'} . " - "
              . (
                $myvar{'query_cache_type'} eq 0 |
                  $myvar{'query_cache_type'} eq 'OFF' ? "DISABLED"
                : ( $myvar{'query_cache_type'} eq 1 ? "ALL REQUESTS"
                    : "ON DEMAND" )
              ) . "";
            infoprint " +-- Query Cache Size: "
              . hr_bytes( $myvar{'query_cache_size'} ) . "";
        }

        infoprint "Per Thread Buffers";
        infoprint " +-- Read Buffer: "
          . hr_bytes( $myvar{'read_buffer_size'} ) . "";
        infoprint " +-- Read RND Buffer: "
          . hr_bytes( $myvar{'read_rnd_buffer_size'} ) . "";
        infoprint " +-- Sort Buffer: "
          . hr_bytes( $myvar{'sort_buffer_size'} ) . "";
        infoprint " +-- Thread stack: "
          . hr_bytes( $myvar{'thread_stack'} ) . "";
        infoprint " +-- Join Buffer: "
          . hr_bytes( $myvar{'join_buffer_size'} ) . "";
        if ( $myvar{'log_bin'} ne 'OFF' ) {
            infoprint "Binlog Cache Buffers";
            infoprint " +-- Binlog Cache: "
              . hr_bytes( $myvar{'binlog_cache_size'} ) . "";
        }
    }

    if (   $arch
        && $arch == 32
        && $mycalc{'max_used_memory'} > 2 * 1024 * 1024 * 1024 )
    {
        badprint
"Allocating > 2GB RAM on 32-bit systems can cause system instability";
        badprint "Maximum reached memory usage: "
          . hr_bytes( $mycalc{'max_used_memory'} )
          . " ($mycalc{'pct_max_used_memory'}% of installed RAM)";
    }
    elsif ( $mycalc{'pct_max_used_memory'} > 85 ) {
        badprint "Maximum reached memory usage: "
          . hr_bytes( $mycalc{'max_used_memory'} )
          . " ($mycalc{'pct_max_used_memory'}% of installed RAM)";
    }
    else {
        goodprint "Maximum reached memory usage: "
          . hr_bytes( $mycalc{'max_used_memory'} )
          . " ($mycalc{'pct_max_used_memory'}% of installed RAM)";
    }

    if ( $mycalc{'pct_max_physical_memory'} > 85 ) {
        badprint "Maximum possible memory usage: "
          . hr_bytes( $mycalc{'max_peak_memory'} )
          . " ($mycalc{'pct_max_physical_memory'}% of installed RAM)";
        push( @generalrec,
            "Reduce your overall MySQL memory footprint for system stability" );
    }
    else {
        goodprint "Maximum possible memory usage: "
          . hr_bytes( $mycalc{'max_peak_memory'} )
          . " ($mycalc{'pct_max_physical_memory'}% of installed RAM)";
    }

    # Slow queries
    if ( $mycalc{'pct_slow_queries'} > 5 ) {
        badprint "Slow queries: $mycalc{'pct_slow_queries'}% ("
          . hr_num( $mystat{'Slow_queries'} ) . "/"
          . hr_num( $mystat{'Questions'} ) . ")";
    }
    else {
        goodprint "Slow queries: $mycalc{'pct_slow_queries'}% ("
          . hr_num( $mystat{'Slow_queries'} ) . "/"
          . hr_num( $mystat{'Questions'} ) . ")";
    }
    if ( $myvar{'long_query_time'} > 10 ) {
        push( @adjvars, "long_query_time (<= 10)" );
    }
    if ( defined( $myvar{'log_slow_queries'} ) ) {
        if ( $myvar{'log_slow_queries'} eq "OFF" ) {
            push( @generalrec,
                "Enable the slow query log to troubleshoot bad queries" );
        }
    }

    # Connections
    if ( $mycalc{'pct_connections_used'} > 85 ) {
        badprint
"Highest connection usage: $mycalc{'pct_connections_used'}%  ($mystat{'Max_used_connections'}/$myvar{'max_connections'})";
        push( @adjvars,
            "max_connections (> " . $myvar{'max_connections'} . ")" );
        push( @adjvars,
            "wait_timeout (< " . $myvar{'wait_timeout'} . ")",
            "interactive_timeout (< " . $myvar{'interactive_timeout'} . ")" );
        push( @generalrec,
"Reduce or eliminate persistent connections to reduce connection usage"
        );
    }
    else {
        goodprint
"Highest usage of available connections: $mycalc{'pct_connections_used'}% ($mystat{'Max_used_connections'}/$myvar{'max_connections'})";
    }

    # Aborted Connections
    if ( $mycalc{'pct_connections_aborted'} > 3 ) {
        badprint
"Aborted connections: $mycalc{'pct_connections_aborted'}%  ($mystat{'Aborted_connects'}/$mystat{'Connections'})";
        push( @generalrec,
            "Reduce or eliminate unclosed connections and network issues" );
    }
    else {
        goodprint
"Aborted connections: $mycalc{'pct_connections_aborted'}%  ($mystat{'Aborted_connects'}/$mystat{'Connections'})";
    }

    # Query cache
    if ( !mysql_version_ge(4) ) {

        # MySQL versions < 4.01 don't support query caching
        push( @generalrec,
            "Upgrade MySQL to version 4+ to utilize query caching" );
    }
    elsif ( $myvar{'query_cache_size'} < 1 ) {
        badprint "Query cache is disabled";
        push( @adjvars, "query_cache_size (>= 8M)" );
    }
    elsif ( $myvar{'query_cache_type'} eq "OFF" ) {
        badprint "Query cache is disabled";
        push( @adjvars, "query_cache_type (=1)" );
    }
    elsif ( $mystat{'Com_select'} == 0 ) {
        badprint
          "Query cache cannot be analyzed - no SELECT statements executed";
    }
    else {
        if ( $mycalc{'query_cache_efficiency'} < 20 ) {
            badprint
              "Query cache efficiency: $mycalc{'query_cache_efficiency'}% ("
              . hr_num( $mystat{'Qcache_hits'} )
              . " cached / "
              . hr_num( $mystat{'Qcache_hits'} + $mystat{'Com_select'} )
              . " selects)";
            push( @adjvars,
                    "query_cache_limit (> "
                  . hr_bytes_rnd( $myvar{'query_cache_limit'} )
                  . ", or use smaller result sets)" );
        }
        else {
            goodprint
              "Query cache efficiency: $mycalc{'query_cache_efficiency'}% ("
              . hr_num( $mystat{'Qcache_hits'} )
              . " cached / "
              . hr_num( $mystat{'Qcache_hits'} + $mystat{'Com_select'} )
              . " selects)";
        }
        if ( $mycalc{'query_cache_prunes_per_day'} > 98 ) {
            badprint
"Query cache prunes per day: $mycalc{'query_cache_prunes_per_day'}";
            if ( $myvar{'query_cache_size'} >= 128 * 1024 * 1024 ) {
                push( @generalrec,
"Increasing the query_cache size over 128M may reduce performance"
                );
                push( @adjvars,
                        "query_cache_size (> "
                      . hr_bytes_rnd( $myvar{'query_cache_size'} )
                      . ") [see warning above]" );
            }
            else {
                push( @adjvars,
                        "query_cache_size (> "
                      . hr_bytes_rnd( $myvar{'query_cache_size'} )
                      . ")" );
            }
        }
        else {
            goodprint
"Query cache prunes per day: $mycalc{'query_cache_prunes_per_day'}";
        }
    }

    # Sorting
    if ( $mycalc{'total_sorts'} == 0 ) {

        # For the sake of space, we will be quiet here
        # No sorts have run yet
    }
    elsif ( $mycalc{'pct_temp_sort_table'} > 10 ) {
        badprint
          "Sorts requiring temporary tables: $mycalc{'pct_temp_sort_table'}% ("
          . hr_num( $mystat{'Sort_merge_passes'} )
          . " temp sorts / "
          . hr_num( $mycalc{'total_sorts'} )
          . " sorts)";
        push( @adjvars,
                "sort_buffer_size (> "
              . hr_bytes_rnd( $myvar{'sort_buffer_size'} )
              . ")" );
        push( @adjvars,
                "read_rnd_buffer_size (> "
              . hr_bytes_rnd( $myvar{'read_rnd_buffer_size'} )
              . ")" );
    }
    else {
        goodprint
          "Sorts requiring temporary tables: $mycalc{'pct_temp_sort_table'}% ("
          . hr_num( $mystat{'Sort_merge_passes'} )
          . " temp sorts / "
          . hr_num( $mycalc{'total_sorts'} )
          . " sorts)";
    }

    # Joins
    if ( $mycalc{'joins_without_indexes_per_day'} > 250 ) {
        badprint
          "Joins performed without indexes: $mycalc{'joins_without_indexes'}";
        push( @adjvars,
                "join_buffer_size (> "
              . hr_bytes( $myvar{'join_buffer_size'} )
              . ", or always use indexes with joins)" );
        push( @generalrec,
            "Adjust your join queries to always utilize indexes" );
    }
    else {

        # For the sake of space, we will be quiet here
        # No joins have run without indexes
    }

    # Temporary tables
    if ( $mystat{'Created_tmp_tables'} > 0 ) {
        if (   $mycalc{'pct_temp_disk'} > 25
            && $mycalc{'max_tmp_table_size'} < 256 * 1024 * 1024 )
        {
            badprint
              "Temporary tables created on disk: $mycalc{'pct_temp_disk'}% ("
              . hr_num( $mystat{'Created_tmp_disk_tables'} )
              . " on disk / "
              . hr_num( $mystat{'Created_tmp_tables'} )
              . " total)";
            push( @adjvars,
                    "tmp_table_size (> "
                  . hr_bytes_rnd( $myvar{'tmp_table_size'} )
                  . ")" );
            push( @adjvars,
                    "max_heap_table_size (> "
                  . hr_bytes_rnd( $myvar{'max_heap_table_size'} )
                  . ")" );
            push( @generalrec,
"When making adjustments, make tmp_table_size/max_heap_table_size equal"
            );
            push( @generalrec,
                "Reduce your SELECT DISTINCT queries which have no LIMIT clause" );
        }
        elsif ($mycalc{'pct_temp_disk'} > 25
            && $mycalc{'max_tmp_table_size'} >= 256 * 1024 * 1024 )
        {
            badprint
              "Temporary tables created on disk: $mycalc{'pct_temp_disk'}% ("
              . hr_num( $mystat{'Created_tmp_disk_tables'} )
              . " on disk / "
              . hr_num( $mystat{'Created_tmp_tables'} )
              . " total)";
            push( @generalrec,
                "Temporary table size is already large - reduce result set size"
            );
            push( @generalrec,
                "Reduce your SELECT DISTINCT queries without LIMIT clauses" );
        }
        else {
            goodprint
              "Temporary tables created on disk: $mycalc{'pct_temp_disk'}% ("
              . hr_num( $mystat{'Created_tmp_disk_tables'} )
              . " on disk / "
              . hr_num( $mystat{'Created_tmp_tables'} )
              . " total)";
        }
    }
    else {

        # For the sake of space, we will be quiet here
        # No temporary tables have been created
    }

    # Thread cache
    if ( $myvar{'thread_cache_size'} eq 0 ) {
        badprint "Thread cache is disabled";
        push( @generalrec, "Set thread_cache_size to 4 as a starting value" );
        push( @adjvars,    "thread_cache_size (start at 4)" );
    }
    else {
        if ( $mycalc{'thread_cache_hit_rate'} <= 50 ) {
            badprint
              "Thread cache hit rate: $mycalc{'thread_cache_hit_rate'}% ("
              . hr_num( $mystat{'Threads_created'} )
              . " created / "
              . hr_num( $mystat{'Connections'} )
              . " connections)";
            push( @adjvars,
                "thread_cache_size (> $myvar{'thread_cache_size'})" );
        }
        else {
            goodprint
              "Thread cache hit rate: $mycalc{'thread_cache_hit_rate'}% ("
              . hr_num( $mystat{'Threads_created'} )
              . " created / "
              . hr_num( $mystat{'Connections'} )
              . " connections)";
        }
    }

    # Table cache
    my $table_cache_var = "";
    if ( $mystat{'Open_tables'} > 0 ) {
        if ( $mycalc{'table_cache_hit_rate'} < 20 ) {
            badprint "Table cache hit rate: $mycalc{'table_cache_hit_rate'}% ("
              . hr_num( $mystat{'Open_tables'} )
              . " open / "
              . hr_num( $mystat{'Opened_tables'} )
              . " opened)";
            if ( mysql_version_ge( 5, 1 ) ) {
                $table_cache_var = "table_open_cache";
            }
            else {
                $table_cache_var = "table_cache";
            }

            push( @adjvars,
                $table_cache_var . " (> " . $myvar{$table_cache_var} . ")" );
            push( @generalrec,
                    "Increase "
                  . $table_cache_var
                  . " gradually to avoid file descriptor limits" );
            push( @generalrec,
                    "Read this before increasing "
                  . $table_cache_var
                  . " over 64: http://bit.ly/1mi7c4C" );
            push( @generalrec,
                    "Beware that open_files_limit ("
                  . $myvar{'open_files_limit'}
                  . ") variable " );
            push( @generalrec,
                    "should be greater than $table_cache_var ( "
                  . $myvar{$table_cache_var}
                  . ")" );
        }
        else {
            goodprint "Table cache hit rate: $mycalc{'table_cache_hit_rate'}% ("
              . hr_num( $mystat{'Open_tables'} )
              . " open / "
              . hr_num( $mystat{'Opened_tables'} )
              . " opened)";
        }
    }

    # Open files
    if ( defined $mycalc{'pct_files_open'} ) {
        if ( $mycalc{'pct_files_open'} > 85 ) {
            badprint "Open file limit used: $mycalc{'pct_files_open'}% ("
              . hr_num( $mystat{'Open_files'} ) . "/"
              . hr_num( $myvar{'open_files_limit'} ) . ")";
            push( @adjvars,
                "open_files_limit (> " . $myvar{'open_files_limit'} . ")" );
        }
        else {
            goodprint "Open file limit used: $mycalc{'pct_files_open'}% ("
              . hr_num( $mystat{'Open_files'} ) . "/"
              . hr_num( $myvar{'open_files_limit'} ) . ")";
        }
    }

    # Table locks
    if ( defined $mycalc{'pct_table_locks_immediate'} ) {
        if ( $mycalc{'pct_table_locks_immediate'} < 95 ) {
            badprint
"Table locks acquired immediately: $mycalc{'pct_table_locks_immediate'}%";
            push( @generalrec,
                "Optimize queries and/or use InnoDB to reduce lock wait" );
        }
        else {
            goodprint
"Table locks acquired immediately: $mycalc{'pct_table_locks_immediate'}% ("
              . hr_num( $mystat{'Table_locks_immediate'} )
              . " immediate / "
              . hr_num( $mystat{'Table_locks_waited'} +
                  $mystat{'Table_locks_immediate'} )
              . " locks)";
        }
    }

    # Binlog cache
    if ( defined $mycalc{'pct_binlog_cache'} ) {
        if (   $mycalc{'pct_binlog_cache'} < 90
            && $mystat{'Binlog_cache_use'} > 0 )
        {
            badprint "Binlog cache memory access: "
              . $mycalc{'pct_binlog_cache'} . "% ( "
              . (
                $mystat{'Binlog_cache_use'} - $mystat{'Binlog_cache_disk_use'} )
              . " Memory / "
              . $mystat{'Binlog_cache_use'}
              . " Total)";
            push( @generalrec,
                    "Increase binlog_cache_size (Actual value: "
                  . $myvar{'binlog_cache_size'}
                  . ") " );
            push( @adjvars,
                    "binlog_cache_size ("
                  . hr_bytes( $myvar{'binlog_cache_size'} + 16 * 1024 * 1024 )
                  . " ) " );
        }
        else {
            goodprint "Binlog cache memory access: "
              . $mycalc{'pct_binlog_cache'} . "% ( "
              . (
                $mystat{'Binlog_cache_use'} - $mystat{'Binlog_cache_disk_use'} )
              . " Memory / "
              . $mystat{'Binlog_cache_use'}
              . " Total)";
            debugprint "Not enought data to validate binlog cache size\n"
              if $mystat{'Binlog_cache_use'} < 10;
        }
    }

    # Performance options
    if ( !mysql_version_ge( 5, 1 ) ) {
        push( @generalrec, "Upgrade to MySQL 5.5+ to use asynchrone write" );
    }
    elsif ( $myvar{'concurrent_insert'} eq "OFF" ) {
        push( @generalrec, "Enable concurrent_insert by setting it to 'ON'" );
    }
    elsif ( $myvar{'concurrent_insert'} eq 0 ) {
        push( @generalrec, "Enable concurrent_insert by setting it to 1" );
    }
}

# Recommandations for MyISAM
sub mysql_myisam {
    prettyprint
"\n-------- MyISAM Metrics -----------------------------------------------------";

    # AriaDB

    # Key buffer usage
    if ( defined( $mycalc{'pct_key_buffer_used'} ) ) {
        if ( $mycalc{'pct_key_buffer_used'} < 90 ) {
            badprint "Key buffer used: $mycalc{'pct_key_buffer_used'}% ("
              . hr_num( $myvar{'key_buffer_size'} *
                  $mycalc{'pct_key_buffer_used'} /
                  100 )
              . " used / "
              . hr_num( $myvar{'key_buffer_size'} )
              . " cache)";

#push(@adjvars,"key_buffer_size (\~ ".hr_num( $myvar{'key_buffer_size'} * $mycalc{'pct_key_buffer_used'} / 100).")");
        }
        else {
            goodprint "Key buffer used: $mycalc{'pct_key_buffer_used'}% ("
              . hr_num( $myvar{'key_buffer_size'} *
                  $mycalc{'pct_key_buffer_used'} /
                  100 )
              . " used / "
              . hr_num( $myvar{'key_buffer_size'} )
              . " cache)";
        }
    }
    else {

        # No queries have run that would use keys
        debugprint "Key buffer used: $mycalc{'pct_key_buffer_used'}% ("
          . hr_num(
            $myvar{'key_buffer_size'} * $mycalc{'pct_key_buffer_used'} / 100 )
          . " used / "
          . hr_num( $myvar{'key_buffer_size'} )
          . " cache)";
    } 

    # Key buffer
    if ( !defined( $mycalc{'total_myisam_indexes'} ) and $doremote == 1 ) {
        push( @generalrec,
            "Unable to calculate MyISAM indexes on remote MySQL server < 5.0.0"
        );
    }
    elsif ( $mycalc{'total_myisam_indexes'} =~ /^fail$/ ) {
        badprint
          "Cannot calculate MyISAM index size - re-run script as root user";
    }
    elsif ( $mycalc{'total_myisam_indexes'} == "0" ) {
        badprint
          "None of your MyISAM tables are indexed - add indexes immediately";
    }
    else {
        if (   $myvar{'key_buffer_size'} < $mycalc{'total_myisam_indexes'}
            && $mycalc{'pct_keys_from_mem'} < 95 )
        {
            badprint "Key buffer size / total MyISAM indexes: "
              . hr_bytes( $myvar{'key_buffer_size'} ) . "/"
              . hr_bytes( $mycalc{'total_myisam_indexes'} ) . "";
            push( @adjvars,
                    "key_buffer_size (> "
                  . hr_bytes( $mycalc{'total_myisam_indexes'} )
                  . ")" );
        }
        else {
            goodprint "Key buffer size / total MyISAM indexes: "
              . hr_bytes( $myvar{'key_buffer_size'} ) . "/"
              . hr_bytes( $mycalc{'total_myisam_indexes'} ) . "";
        }
        if ( $mystat{'Key_read_requests'} > 0 ) {
            if ( $mycalc{'pct_keys_from_mem'} < 95 ) {
                badprint
                  "Read Key buffer hit rate: $mycalc{'pct_keys_from_mem'}% ("
                  . hr_num( $mystat{'Key_read_requests'} )
                  . " cached / "
                  . hr_num( $mystat{'Key_reads'} )
                  . " reads)";
            }
            else {
                goodprint
                  "Read Key buffer hit rate: $mycalc{'pct_keys_from_mem'}% ("
                  . hr_num( $mystat{'Key_read_requests'} )
                  . " cached / "
                  . hr_num( $mystat{'Key_reads'} )
                  . " reads)";
            }
        }
        else {

            # No queries have run that would use keys
            debugprint "Key buffer size / total MyISAM indexes: "
              . hr_bytes( $myvar{'key_buffer_size'} ) . "/"
              . hr_bytes( $mycalc{'total_myisam_indexes'} ) . "";
        }
        if ( $mystat{'Key_write_requests'} > 0 ) {
            if ( $mycalc{'pct_wkeys_from_mem'} < 95 ) {
                badprint
                  "Write Key buffer hit rate: $mycalc{'pct_wkeys_from_mem'}% ("
                  . hr_num( $mystat{'Key_write_requests'} )
                  . " cached / "
                  . hr_num( $mystat{'Key_writes'} )
                  . " writes)";
            }
            else {
                goodprint
                  "Write Key buffer hit rate: $mycalc{'pct_wkeys_from_mem'}% ("
                  . hr_num( $mystat{'Key_write_requests'} )
                  . " cached / "
                  . hr_num( $mystat{'Key_writes'} )
                  . " writes)";
            }
        }
        else {

            # No queries have run that would use keys
            debugprint
              "Write Key buffer hit rate: $mycalc{'pct_wkeys_from_mem'}% ("
              . hr_num( $mystat{'Key_write_requests'} )
              . " cached / "
              . hr_num( $mystat{'Key_writes'} )
              . " writes)";
        }
    }
}

# Recommandations for Ariadb
sub mysql_ariadb {
    prettyprint
"\n-------- AriaDB Metrics -----------------------------------------------------";

    # AriaDB
    unless ( defined $myvar{'have_aria'}
        && $myvar{'have_aria'} eq "YES"
        && defined $enginestats{'Aria'} )
    {
        infoprint "AriaDB is disabled.";
        return;
    }
    infoprint "AriaDB is enabled.";

    # Aria pagecache
    if ( !defined( $mycalc{'total_aria_indexes'} ) and $doremote == 1 ) {
        push( @generalrec,
            "Unable to calculate Aria indexes on remote MySQL server < 5.0.0" );
    }
    elsif ( $mycalc{'total_aria_indexes'} =~ /^fail$/ ) {
        badprint
          "Cannot calculate Aria index size - re-run script as root user";
    }
    elsif ( $mycalc{'total_aria_indexes'} == "0" ) {
        badprint
          "None of your Aria tables are indexed - add indexes immediately";
    }
    else {
        if (
            $myvar{'aria_pagecache_buffer_size'} < $mycalc{'total_aria_indexes'}
            && $mycalc{'pct_aria_keys_from_mem'} < 95 )
        {
            badprint "Aria pagecache size / total Aria indexes: "
              . hr_bytes( $myvar{'aria_pagecache_buffer_size'} ) . "/"
              . hr_bytes( $mycalc{'total_aria_indexes'} ) . "";
            push( @adjvars,
                    "aria_pagecache_buffer_size (> "
                  . hr_bytes( $mycalc{'total_aria_indexes'} )
                  . ")" );
        }
        else {
            goodprint "Aria pagecache size / total Aria indexes: "
              . hr_bytes( $myvar{'aria_pagecache_buffer_size'} ) . "/"
              . hr_bytes( $mycalc{'total_aria_indexes'} ) . "";
        }
        if ( $mystat{'Aria_pagecache_read_requests'} > 0 ) {
            if ( $mycalc{'pct_aria_keys_from_mem'} < 95 ) {
                badprint
"Aria pagecache hit rate: $mycalc{'pct_aria_keys_from_mem'}% ("
                  . hr_num( $mystat{'Aria_pagecache_read_requests'} )
                  . " cached / "
                  . hr_num( $mystat{'Aria_pagecache_reads'} )
                  . " reads)";
            }
            else {
                goodprint
"Aria pagecache hit rate: $mycalc{'pct_aria_keys_from_mem'}% ("
                  . hr_num( $mystat{'Aria_pagecache_read_requests'} )
                  . " cached / "
                  . hr_num( $mystat{'Aria_pagecache_reads'} )
                  . " reads)";
            }
        }
        else {

            # No queries have run that would use keys
        }
    }
}

# Recommandations for Innodb
sub mysql_innodb {
    prettyprint
"\n-------- InnoDB Metrics -----------------------------------------------------";

    # InnoDB
    unless ( defined $myvar{'have_innodb'}
        && $myvar{'have_innodb'} eq "YES"
        && defined $enginestats{'InnoDB'} )
    {
        infoprint "InnoDB is disabled.";
        if ( mysql_version_ge( 5, 5 ) ) {
            badprint
"InnoDB Storage engine is disabled. InnoDB is the default storage engine";
        }
        return;
    }
    infoprint "InnoDB is enabled.";

    if ( $opt{buffers} ne 0 ) {
        infoprint "InnoDB Buffers";
        if ( defined $myvar{'innodb_buffer_pool_size'} ) {
            infoprint " +-- InnoDB Buffer Pool: "
              . hr_bytes( $myvar{'innodb_buffer_pool_size'} ) . "";
        }
        if ( defined $myvar{'innodb_buffer_pool_instances'} ) {
            infoprint " +-- InnoDB Buffer Pool Instances: "
              . $myvar{'innodb_buffer_pool_instances'} . "";
        }
        if ( defined $myvar{'innodb_additional_mem_pool_size'} ) {
            infoprint " +-- InnoDB Additional Mem Pool: "
              . hr_bytes( $myvar{'innodb_additional_mem_pool_size'} ) . "";
        }
        if ( defined $myvar{'innodb_log_buffer_size'} ) {
            infoprint " +-- InnoDB Log Buffer: "
              . hr_bytes( $myvar{'innodb_log_buffer_size'} ) . "";
        }
        if ( defined $mystat{'Innodb_buffer_pool_pages_free'} ) {
            infoprint " +-- InnoDB Log Buffer Free: "
              . hr_bytes( $mystat{'Innodb_buffer_pool_pages_free'} ) . "";
        }
        if ( defined $mystat{'Innodb_buffer_pool_pages_total'} ) {
            infoprint " +-- InnoDB Log Buffer Used: "
              . hr_bytes( $mystat{'Innodb_buffer_pool_pages_total'} ) . "";
        }
    }

    # InnoDB Buffer Pull Size
    if ( $myvar{'innodb_buffer_pool_size'} > $enginestats{'InnoDB'} ) {
        goodprint "InnoDB buffer pool / data size: "
          . hr_bytes( $myvar{'innodb_buffer_pool_size'} ) . "/"
          . hr_bytes( $enginestats{'InnoDB'} ) . "";
    }
    else {
        badprint "InnoDB buffer pool / data size: "
          . hr_bytes( $myvar{'innodb_buffer_pool_size'} ) . "/"
          . hr_bytes( $enginestats{'InnoDB'} ) . "";
        push( @adjvars,
                "innodb_buffer_pool_size (>= "
              . hr_bytes_rnd( $enginestats{'InnoDB'} )
              . ") if possible." );
    }

    # InnoDB Buffer Pull Instances (MySQL 5.6.6+)
    if ( defined( $myvar{'innodb_buffer_pool_instances'} ) ) {

        # Bad Value if > 64
        if ( $myvar{'innodb_buffer_pool_instances'} > 64 ) {
            badprint "InnoDB buffer pool instances: "
              . $myvar{'innodb_buffer_pool_instances'} . "";
            push( @adjvars, "innodb_buffer_pool_instances (<= 64)" );
        }

        # InnoDB Buffer Pull Size > 1Go
        if ( $myvar{'innodb_buffer_pool_size'} > 1024 * 1024 * 1024 ) {

# InnoDB Buffer Pull Size / 1Go = InnoDB Buffer Pull Instances limited to 64 max.

            #  InnoDB Buffer Pull Size > 64Go
            my $max_innodb_buffer_pool_instances =
              int( $myvar{'innodb_buffer_pool_size'} / ( 1024 * 1024 * 1024 ) );
            $max_innodb_buffer_pool_instances = 64
              if ( $max_innodb_buffer_pool_instances > 64 );

            if ( $myvar{'innodb_buffer_pool_instances'} !=
                $max_innodb_buffer_pool_instances )
            {
                badprint "InnoDB buffer pool instances: "
                  . $myvar{'innodb_buffer_pool_instances'} . "";
                push( @adjvars,
                        "innodb_buffer_pool_instances(="
                      . $max_innodb_buffer_pool_instances
                      . ")" );
            }
            else {
                goodprint "InnoDB buffer pool instances: "
                  . $myvar{'innodb_buffer_pool_instances'} . "";
            }

            # InnoDB Buffer Pull Size < 1Go
        }
        else {
            if ( $myvar{'innodb_buffer_pool_instances'} != 1 ) {
                badprint
"InnoDB buffer pool <= 1G and innodb_buffer_pool_instances(!=1).";
                push( @adjvars, "innodb_buffer_pool_instances (=1)" );
            }
            else {
                goodprint "InnoDB buffer pool instances: "
                  . $myvar{'innodb_buffer_pool_instances'} . "";
            }
        }
    }

    # InnoDB Used Buffer Pool
    if ( defined $mycalc{'pct_innodb_buffer_used'}
        && $mycalc{'pct_innodb_buffer_used'} < 80 )
    {
        badprint "InnoDB Used buffer: "
          . $mycalc{'pct_innodb_buffer_used'} . "% ("
          . ( $mystat{'Innodb_buffer_pool_pages_total'} -
              $mystat{'Innodb_buffer_pool_pages_free'} )
          . " used/ "
          . $mystat{'Innodb_buffer_pool_pages_total'}
          . " total)";
    }
    else {
        goodprint "InnoDB Used buffer: "
          . $mycalc{'pct_innodb_buffer_used'} . "% ("
          . ( $mystat{'Innodb_buffer_pool_pages_total'} -
              $mystat{'Innodb_buffer_pool_pages_free'} )
          . " used/ "
          . $mystat{'Innodb_buffer_pool_pages_total'}
          . " total)";
    }

    # InnoDB Read efficency
    if ( defined $mycalc{'pct_read_efficiency'}
        && $mycalc{'pct_read_efficiency'} < 90 )
    {
        badprint "InnoDB Read buffer efficiency: "
          . $mycalc{'pct_read_efficiency'} . "% ("
          . ( $mystat{'Innodb_buffer_pool_read_requests'} -
              $mystat{'Innodb_buffer_pool_reads'} )
          . " hits/ "
          . $mystat{'Innodb_buffer_pool_read_requests'}
          . " total)";
    }
    else {
        goodprint "InnoDB Read buffer efficiency: "
          . $mycalc{'pct_read_efficiency'} . "% ("
          . ( $mystat{'Innodb_buffer_pool_read_requests'} -
              $mystat{'Innodb_buffer_pool_reads'} )
          . " hits/ "
          . $mystat{'Innodb_buffer_pool_read_requests'}
          . " total)";
    }

    # InnoDB Write efficiency
    if ( defined $mycalc{'pct_write_efficiency'}
        && $mycalc{'pct_write_efficiency'} < 90 )
    {
        badprint "InnoDB Write buffer efficiency: "
          . $mycalc{'pct_write_efficiency'} . "% ("
          . ( $mystat{'Innodb_buffer_pool_write_requests'} -
              $mystat{'Innodb_buffer_pool_writes'} )
          . " hits/ "
          . $mystat{'Innodb_buffer_pool_write_requests'}
          . " total)";
    }
    else {
        goodprint "InnoDB Write buffer efficiency: "
          . $mycalc{'pct_write_efficiency'} . "% ("
          . ( $mystat{'Innodb_buffer_pool_write_requests'} -
              $mystat{'Innodb_buffer_pool_writes'} )
          . " hits/ "
          . $mystat{'Innodb_buffer_pool_write_requests'}
          . " total)";
    }

    # InnoDB Log Waits
    if ( defined $mystat{'Innodb_log_waits'}
        && $mystat{'Innodb_log_waits'} > 0 )
    {
        badprint "InnoDB log waits: "
          . percentage( $mystat{'Innodb_log_waits'},
            $mystat{'Innodb_log_writes'} )
          . "% ("
          . $mystat{'Innodb_log_waits'}
          . " waits / "
          . $mystat{'Innodb_log_writes'}
          . " writes)";
        push( @adjvars,
                "innodb_log_buffer_size (>= "
              . hr_bytes_rnd( $myvar{'innodb_log_buffer_size'} )
              . ")" );
    }
    else {
        goodprint "InnoDB log waits: "
          . percentage( $mystat{'Innodb_log_waits'},
            $mystat{'Innodb_log_writes'} )
          . "% ("
          . $mystat{'Innodb_log_waits'}
          . " waits / "
          . $mystat{'Innodb_log_writes'}
          . " writes)";
    }
    $result{'Calculations'} = {%mycalc};
}

# Recommandations for MySQL Databases
sub mysql_databases {
    return if ( $opt{dbstat} == 0 );

    prettyprint
"\n-------- Database Metrics ------------------------------------------------";
    unless ( mysql_version_ge( 5, 5 ) ) {
        infoprint
"Skip Database metrics from information schema missing in this version";
        return;
    }

    my @dblist = select_array("SHOW DATABASES;");
    infoprint "There is " . scalar(@dblist) . " Database(s).";
    my @totaldbinfo = split /\s/,
      select_one(
"SELECT SUM(TABLE_ROWS), SUM(DATA_LENGTH), SUM(INDEX_LENGTH) , SUM(DATA_LENGTH+INDEX_LENGTH) FROM information_schema.TABLES;"
      );
    infoprint "All Databases:";
    infoprint " +-- ROWS : "
      . ( $totaldbinfo[0] eq 'NULL' ? 0 : $totaldbinfo[0] ) . "";
    infoprint " +-- DATA : "
      . hr_bytes( $totaldbinfo[1] ) . "("
      . percentage( $totaldbinfo[1], $totaldbinfo[3] ) . "%)";
    infoprint " +-- INDEX: "
      . hr_bytes( $totaldbinfo[2] ) . "("
      . percentage( $totaldbinfo[2], $totaldbinfo[3] ) . "%)";
    infoprint " +-- SIZE : " . hr_bytes( $totaldbinfo[3] ) . "";

    badprint "Index size is larger than data size \n"
      if $totaldbinfo[1] < $totaldbinfo[2];

    $result{'Databases'}{'All databases'}{'Rows'} =
      ( $totaldbinfo[0] eq 'NULL' ? 0 : $totaldbinfo[0] );
    $result{'Databases'}{'All databases'}{'Data Size'} = $totaldbinfo[1];
    $result{'Databases'}{'All databases'}{'Data Pct'} =
      percentage( $totaldbinfo[1], $totaldbinfo[3] ) . "%";
    $result{'Databases'}{'All databases'}{'Index Size'} = $totaldbinfo[2];
    $result{'Databases'}{'All databases'}{'Index Pct'} =
      percentage( $totaldbinfo[2], $totaldbinfo[3] ) . "%";
    $result{'Databases'}{'All databases'}{'Total Size'} = $totaldbinfo[3];

    foreach (@dblist) {
        chomp($_);
        if (   $_ eq "information_schema"
            or $_ eq "performance_schema"
            or $_ eq "mysql"
            or $_ eq "" )
        {
            next;
        }

        my @dbinfo = split /\s/,
          select_one(
"SELECT TABLE_SCHEMA, SUM(TABLE_ROWS), SUM(DATA_LENGTH), SUM(INDEX_LENGTH) , SUM(DATA_LENGTH+INDEX_LENGTH), COUNT(DISTINCT ENGINE) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$_' GROUP BY TABLE_SCHEMA ORDER BY TABLE_SCHEMA"
          );
        next unless defined $dbinfo[0];
        infoprint "Database: " . $dbinfo[0] . "";
        infoprint " +-- ROWS : "
          . ( !defined( $dbinfo[1] ) or $dbinfo[1] eq 'NULL' ? 0 : $dbinfo[1] )
          . "";
        infoprint " +-- DATA : "
          . hr_bytes( $dbinfo[2] ) . "("
          . percentage( $dbinfo[2], $dbinfo[4] ) . "%)";
        infoprint " +-- INDEX: "
          . hr_bytes( $dbinfo[3] ) . "("
          . percentage( $dbinfo[3], $dbinfo[4] ) . "%)";
        infoprint " +-- TOTAL: " . hr_bytes( $dbinfo[4] ) . "";
        badprint "Index size is larger than data size for $dbinfo[0] \n"
          if $dbinfo[2] < $dbinfo[3];
        badprint "There " . $dbinfo[5] . " storage engines. Be careful \n"
          if $dbinfo[5] > 1;
        $result{'Databases'}{ $dbinfo[0] }{'Rows'}      = $dbinfo[1];
        $result{'Databases'}{ $dbinfo[0] }{'Data Size'} = $dbinfo[2];
        $result{'Databases'}{ $dbinfo[0] }{'Data Pct'} =
          percentage( $dbinfo[2], $dbinfo[4] ) . "%";
        $result{'Databases'}{ $dbinfo[0] }{'Index Size'} = $dbinfo[3];
        $result{'Databases'}{ $dbinfo[0] }{'Index Pct'} =
          percentage( $dbinfo[3], $dbinfo[4] ) . "%";
        $result{'Databases'}{ $dbinfo[0] }{'Total Size'} = $dbinfo[4];
    }
}

# Recommandations for MySQL Databases
sub mysql_indexes {
    return if ( $opt{idxstat} == 0 );

    prettyprint
"\n-------- Indexes Metrics -------------------------------------------------";
    unless ( mysql_version_ge( 5, 5 ) ) {
        infoprint
"Skip Index metrics from information schema missing in this version";
        return;
    }
    my $selIdxReq = <<'ENDSQL';
SELECT
  CONCAT(CONCAT(t.TABLE_SCHEMA, '.'),t.TABLE_NAME) AS 'table'
 , CONCAT(CONCAT(CONCAT(s.INDEX_NAME, '('),s.COLUMN_NAME), ')') AS 'index'
 , s.SEQ_IN_INDEX AS 'seq'
 , s2.max_columns AS 'maxcol'
 , s.CARDINALITY  AS 'card'
 , t.TABLE_ROWS   AS 'est_rows'
 , ROUND(((s.CARDINALITY / IFNULL(t.TABLE_ROWS, 0.01)) * 100), 2) AS 'sel'
FROM INFORMATION_SCHEMA.STATISTICS s
 INNER JOIN INFORMATION_SCHEMA.TABLES t
  ON s.TABLE_SCHEMA = t.TABLE_SCHEMA
  AND s.TABLE_NAME = t.TABLE_NAME
 INNER JOIN (
  SELECT 
     TABLE_SCHEMA
   , TABLE_NAME
   , INDEX_NAME
   , MAX(SEQ_IN_INDEX) AS max_columns
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema')
  GROUP BY TABLE_SCHEMA, TABLE_NAME, INDEX_NAME
 ) AS s2
 ON s.TABLE_SCHEMA = s2.TABLE_SCHEMA
 AND s.TABLE_NAME = s2.TABLE_NAME
 AND s.INDEX_NAME = s2.INDEX_NAME
WHERE t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema')
AND t.TABLE_ROWS > 10
AND s.CARDINALITY IS NOT NULL
AND (s.CARDINALITY / IFNULL(t.TABLE_ROWS, 0.01)) < 8.00
ORDER BY sel
LIMIT 10;
ENDSQL
    my @idxinfo = select_array($selIdxReq);
    infoprint "Worst selectivity indexes:";
    foreach (@idxinfo) {
        debugprint "$_";
        my @info = split /\s/;
        infoprint "Index: " . $info[1] . "";

        infoprint " +-- COLUNM      : " . $info[0] . "";
        infoprint " +-- NB SEQS     : " . $info[2] . " sequence(s)";
        infoprint " +-- NB COLS     : " . $info[3] . " column(s)";
        infoprint " +-- CARDINALITY : " . $info[4] . " distinct values";
        infoprint " +-- NB ROWS     : " . $info[5] . " rows";
        infoprint " +-- SELECTIVITY : " . $info[6] . "%";

        $result{'Indexes'}{ $info[1] }{'Colunm'}            = $info[0];
        $result{'Indexes'}{ $info[1] }{'Sequence number'}   = $info[2];
        $result{'Indexes'}{ $info[1] }{'Number of collunm'} = $info[3];
        $result{'Indexes'}{ $info[1] }{'Cardianality'}      = $info[4];
        $result{'Indexes'}{ $info[1] }{'Row number'}        = $info[5];
        $result{'Indexes'}{ $info[1] }{'Selectivity'}       = $info[6];
        if ( $info[6] < 25 ) {
            badprint "$info[1] has a low selectivity";
        }
    }

    return
      unless ( defined( $myvar{'performance_schema'} )
        and $myvar{'performance_schema'} eq 'ON' );

    $selIdxReq = <<'ENDSQL';
SELECT CONCAT(CONCAT(object_schema,'.'),object_name) AS 'table', index_name 
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE index_name IS NOT NULL
AND count_star =0  
AND index_name <> 'PRIMARY' 
AND object_schema != 'mysql' 
ORDER BY count_star, object_schema, object_name;
ENDSQL
    @idxinfo = select_array($selIdxReq);
    infoprint "Unsused indexes:";
    push( @generalrec, "Remove unused indexes." ) if ( scalar(@idxinfo) > 0 );
    foreach (@idxinfo) {
        debugprint "$_";
        my @info = split /\s/;
        badprint "Index: $info[1] on $info[0] is not used.";
        push @{ $result{'Indexes'}{'Unused Indexes'} },
          $info[0] . "." . $info[1];
    }
}

# Take the two recommendation arrays and display them at the end of the output
sub make_recommendations {
    prettyprint
"\n-------- Recommendations -----------------------------------------------------";
    if ( @generalrec > 0 ) {
        prettyprint "General recommendations:";
        foreach (@generalrec) { prettyprint "    " . $_ . ""; }
    }
    if ( @adjvars > 0 ) {
        prettyprint "Variables to adjust:";
        if ( $mycalc{'pct_max_physical_memory'} > 90 ) {
            prettyprint
              "  *** MySQL's maximum memory usage is dangerously high ***\n"
              . "  *** Add RAM before increasing MySQL buffer variables ***";
        }
        foreach (@adjvars) { prettyprint "    " . $_ . ""; }
    }
    if ( @generalrec == 0 && @adjvars == 0 ) {
        prettyprint
          "No additional performance recommendations are available.";
    }
}

sub close_outputfile {
    close($fh) if defined($fh);
}

sub headerprint {
    prettyprint
      " >>  MySQLTuner $tunerversion - Major Hayden <major\@mhtx.net>\n"
      . " >>  Bug reports, feature requests, and downloads at http://mysqltuner.com/\n"
      . " >>  Run with '--help' for additional options and output filtering";
}

sub string2file {
  my $filename=shift;
  my $content=shift;
  open my $fh, q(>), $filename
  or die "Unable to open $filename in write mode. please check permissions for this file or directory";
  print $fh $content if defined($content);
  close $fh;
  debugprint $content if ($opt{'debug'});
}

sub file2array {
    my $filename = shift;
    debugprint "* reading $filename" if ($opt{'debug'});
    my $fh;
    open( $fh, q(<), "$filename" )
      or die "Couldn't open $filename for reading: $!\n";
    my @lines = <$fh>;
    close($fh);
    return @lines;
}

sub file2string {
  return join ( '', file2array(@_) );
}

my $templateModel;
if ($opt{'template'} ne 0 ) {
  $templateModel=file2string ($opt{'template'});
}else {
  # DEFAULT REPORT TEMPLATE
  $templateModel=<<'END_TEMPLATE';
<!DOCTYPE html>
<html>
<head>
  <title>Report</title>
  <meta charset="UTF-8">
</head>
<body>

<h1>Result output</h1>
<pre>
{$data}
</pre>

</body>
</html>
END_TEMPLATE
}
sub dump_result {
    if ($opt{'debug'}) {
      use Data::Dumper qw/Dumper/;
      $Data::Dumper::Pair = " : ";
      debugprint Dumper( \%result );
    }

    debugprint "HTML REPORT: $opt{'reportfile'}";
    if ($opt{'reportfile'} ne 0 ) {
      use Data::Dumper qw/Dumper/;
      $Data::Dumper::Pair = " : ";
      my $vars= {'data' => Dumper( \%result ) };

      my $template = Text::Template->new(TYPE => 'STRING', PREPEND => q{;}, SOURCE => $templateModel)
      or die "Couldn't construct template: $Text::Template::ERROR";
      open my $fh, q(>), $opt{'reportfile'}
      or die "Unable to open $opt{'reportfile'} in write mode. please check permissions for this file or directory";
      $template->fill_in(HASH =>$vars, OUTPUT=>$fh );
      close $fh;
    }
}

# ---------------------------------------------------------------------------
# BEGIN 'MAIN'
# ---------------------------------------------------------------------------
headerprint                  # Header Print
mysql_setup;                 # Gotta login first
validate_tuner_version;      # Check last version
os_setup;                    # Set up some OS variables
get_all_vars;                # Toss variables/status into hashes
get_tuning_info;             # Get information about the tuning connexion
validate_mysql_version;      # Check current MySQL version
check_architecture;          # Suggest 64-bit upgrade
check_storage_engines;       # Show enabled storage engines
mysql_databases;             # Show informations about databases
mysql_indexes;               # Show informations about indexes
security_recommendations;    # Display some security recommendations
calculations;                # Calculate everything we need
mysql_stats;                 # Print the server stats
mysql_myisam;                # Print MyISAM stats
mysql_innodb;                # Print InnoDB stats
mysql_ariadb;                # Print AriaDB stats
get_replication_status;      # Print replication info
make_recommendations;        # Make recommendations based on stats
dump_result;                 # Dump result if debug is on
close_outputfile;            # Close reportfile if needed

# ---------------------------------------------------------------------------
# END 'MAIN'
# ---------------------------------------------------------------------------
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

 MySQLTuner 1.6.0 - MySQL High Performance Tuning Script

=head1 IMPORTANT USAGE GUIDELINES

To run the script with the default options, run the script without arguments
Allow MySQL server to run for at least 24-48 hours before trusting suggestions
Some routines may require root level privileges (script will provide warnings)
You must provide the remote server's total memory when connecting to other servers

=head1 CONNECTION AND AUTHENTIFICATION

 --host <hostname>    Connect to a remote host to perform tests (default: localhost)
 --socket <socket>    Use a different socket for a local connection
 --port <port>        Port to use for connection (default: 3306)
 --user <username>    Username to use for authentication
 --pass <password>    Password to use for authentication
 --mysqladmin <path>  Path to a custom mysqladmin executable
 --mysqlcmd <path>    Path to a custom mysql executable

=head1 PERFORMANCE AND REPORTING OPTIONS

 --skipsize           Don't enumerate tables and their types/sizes (default: on)
                      (Recommended for servers with many tables)
 --skippassword       Don't perform checks on user passwords(default: off)
 --checkversion       Check for updates to MySQLTuner (default: don't check)
 --forcemem <size>    Amount of RAM installed in megabytes
 --forceswap <size>   Amount of swap memory configured in megabytes
 --passwordfile <path>Path to a password file list(one password by line)
 
=head1 OUTPUT OPTIONS
 --silent             Don't output anything on screen
 --nogood             Remove OK responses
 --nobad              Remove negative/suggestion responses
 --noinfo             Remove informational responses
 --debug              Print debug information
 --dbstat             Print database information
 --idxstat            Print index information
 --nocolor            Don't print output in color
 --buffers            Print global and per-thread buffer values
 --outputfile <path>  Path to a output txt file
 --reportfile <path>  Path to a report txt file
 --template   <path>  Path to a template file

=head1 PERLDOC

You can find documentation for this module with the perldoc command.

  perldoc mysqltuner

=head2 INTENALS

L<https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md>

 Internal documentation

=head1 AUTHORS

Major Hayden - major@mhtx.net

=head1 CONTRIBUTORS

=over 4

=item *

Matthew Montgomery

=item *

Paul Kehrer

=item *

Dave Burgess

=item *

Jonathan Hinds

=item *

Mike Jackson

=item *

Nils Breunese

=item *

Shawn Ashlee

=item *

Luuk Vosslamber

=item *

Ville Skytta

=item *

Trent Hornibrook

=item *

Jason Gill

=item *

Mark Imbriaco

=item *

Greg Eden

=item *

Aubin Galinotti

=item *

Giovanni Bechis

=item *

Bill Bradford

=item *

Ryan Novosielski

=item *

Michael Scheidell

=item *

Blair Christensen

=item *

Hans du Plooy

=item *

Victor Trac

=item *

Everett Barnes

=item *

Tom Krouper

=item *

Gary Barrueto

=item *

Simon Greenaway

=item *

Adam Stein

=item *

Isart Montane

=item *

Baptiste M.

=item *

Cole Turner

=item *

Major Hayden

=item *

Joe Ashcraft

=item *

Jean-Marie Renouard

=back

=head1 SUPPORT


Bug reports, feature requests, and downloads at http://mysqltuner.com/

Bug tracker can be found at https://github.com/major/MySQLTuner-perl/issues

Maintained by Major Hayden (major\@mhtx.net) - Licensed under GPL

=head1 SOURCE CODE

L<https://github.com/major/MySQLTuner-perl>

 git clone https://github.com/major/MySQLTuner-perl.git

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2015 Major Hayden - major@mhtx.net

For the latest updates, please visit http://mysqltuner.com/

Git repository available at http://github.com/major/MySQLTuner-perl

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

# Local variables:
# indent-tabs-mode: t
# cperl-indent-level: 8
# perl-indent-level: 8
# End:
