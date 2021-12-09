##############################################
# $Id: 99_attrT_WLED_Utils.pm 24827 2021-08-04 16:57:17Z Beta-User $
# contributed by DeeSPe, https://forum.fhem.de/index.php/topic,98880.msg1192196.html#msg1192196

package FHEM::attrT_WLED_Utils;    ## no critic 'Package declaration'

use strict;
use warnings;

use GPUtils qw(GP_Import);

## Import der FHEM Funktionen
BEGIN {
  GP_Import(
    qw(
      InternalVal
      ReadingsVal
      ReadingsNum
      AttrVal
      defs
      readingsBeginUpdate
      readingsBulkUpdateIfChanged
      readingsEndUpdate
      readingsSingleUpdate
      HttpUtils_NonblockingGet
    )
  );
}

sub ::attrT_WLED_Utils_Initialize { goto &Initialize }

# initialize ##################################################################
sub Initialize {
  my $hash = shift;
  return;
}

# Enter you functions below _this_ line.

sub WLED_getNames {
  my $dev   = shift // return;
  my $event = shift // return;

  my $cleaned = { api => $event };
  if ( $event =~ m,(?<=<sx>)([\d]+)(?=<\/sx>),x ) {
      $cleaned->{speed} = $1 if $1 ne ReadingsVal($dev,'speed','unknown');
  }
  if ( $event =~ m,(?<=<ix>)([\d]+)(?=<\/ix>),x ) {
      $cleaned->{intensity} = $1 if $1 ne ReadingsVal($dev,'intensity','unknown');
  }
  if ( $event =~ m,(?<=<fp>)([\d]+)(?=<\/fp>),x ) {
      $cleaned->{palette} = $1 if $1 ne ReadingsVal($dev,'palette','unknown');
  }
  if ( $event =~ m,(?<=<fx>)([\d]+)(?=<\/fx>),x ) {
      $cleaned->{effect} = $1 if $1 ne ReadingsVal($dev,'effect','unknown');
  }
  if ( $event =~ m,(?<=<ps>)([\d]+)(?=<\/ps>),x ) {
      $cleaned->{preset} = $1 if $1 ne ReadingsVal($dev,'preset','unknown');
  }

  my $io = InternalVal($dev,'LASTInputDev',AttrVal($dev,'IODev',InternalVal($dev,'IODev',undef)->{NAME})) // return \%cleaned;
  my $ip = InternalVal($dev,$io."_CONN",ReadingsVal($dev,'ip', undef)) =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/x ? $1 : return \%cleaned;
  my $chash = $defs{$dev};
  HttpUtils_NonblockingGet({
    url=>"http://$ip/json",
    callback=>sub($$$){
      my ($hash,$err,$data) = @_;
      WLED_setReadings($dev,"effect",$1) if $data =~ m/effects..\[([^[]*?)]/x;
      WLED_setReadings($dev,"palette",$1) if $data =~ m/palettes..\[([^[]*?)]/x;
    }
  });
  return \%cleaned;
}

sub WLED_setReadings {
  my $dev = shift // return;
  my $na = shift // return;
  my $data = shift;
  my $nas = $na.'s';
  my $chash = $defs{$dev};
  $data =~ s/["\n]//gx;
  $data =~ s/[\s\&]/_/gx;
  $data =~ s/\+/Plus/gx;
  my @r = split(",",$data);
  readingsBeginUpdate($chash);
  readingsBulkUpdateIfChanged($chash,".${nas}count",(scalar @r)-1);
  readingsBulkUpdateIfChanged($chash,".$nas",$data);
  readingsEndUpdate($chash,0);
  readingsSingleUpdate($chash,$na.'name',$r[ReadingsNum($dev,$na,0)],1);
  return;
}

sub WLED_setName {
  my $dev = shift // return;
  my $read = shift // return;
  my $val = shift;
  my $arr = ReadingsVal($dev,".".$read."s",undef) // WLED_getNames($dev);
  my $wled = lc(InternalVal($dev,"CID",""));
  $wled =~ s/_/\//;
  my $top = $wled."/api F";
  $top .= $read eq "effect"?"X=":"P=";
  my $id;
  my $i = 0;
  for (split(",",$arr)){
    if ($_ ne $val) {
      $i++;
      next;
    } else {
      $id = $i;
      last;
    }
  }
  return defined $id ? $top.$id : undef;
}

1;

__END__


=pod
=item summary helper functions needed for WLED MQTT2_DEVICE
=item summary_DE needed Hilfsfunktionen für WLED MQTT2_DEVICE
=begin html

<a id="attrT_WLED_Utils"></a>
<h3>attrT_WLED_Utils</h3>
<ul>
  <b>Functions to support attrTemplates for WLEDs</b><br> 
</ul>
<ul>
  <li><b>FHEM::attrT_WLED_Utils::WLED_getNames</b><br>
  <code>FHEM::attrT_WLED_Utils::WLED_getNames($)</code><br>
  This is used to get the available effects and palettes for usage within the widgets.
  </li>
</ul>
<ul>
  <li><b>FHEM::attrT_WLED_Utils::WLED_setName</b><br>
  <code>FHEM::attrT_WLED_Utils::WLED_setName($$$)</code><br>
  This is used to set the effects and palettes with their names.
  </li>
</ul>
=end html
=cut
