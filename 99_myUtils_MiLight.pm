##############################################
# $Id: myUtils_MiLight.pm 2019-09-04 Beta-User $
#

package main;

use strict;
use warnings;
use POSIX;

sub
myUtils_MiLight_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

sub milight_toggle_indirect($) {
  my ($name) = @_;
  my $Target_Devices = AttrVal($name,"Target_Device","devStrich0");
  my $dimmLevel;
  my $hash;
  foreach my $setdevice (split (/,/,$Target_Devices)) {
    $hash = $defs{$setdevice};
	if(ReadingsVal($setdevice,"state","OFF") =~ /OFF|off/) {
      CommandSet(undef, "$setdevice on");
      readingsSingleUpdate($hash,"myLastShort","1", 0);
      AnalyzeCommandChain(undef, "sleep 1; set $setdevice brightness 220");
    } elsif (ReadingsAge($setdevice,"myLastShort","100") < 3) {
       my $lastToggle = ReadingsNum($setdevice, "myLastShort","0");
       if ($lastToggle == 1) {
         readingsSingleUpdate($hash,"myLastShort","2",0);
         $dimmLevel = 110;
       } else {
         $dimmLevel = 45;
       }
       CommandSet(undef, "$setdevice brightness $dimmLevel");
    } else {
       readingsSingleUpdate($hash,"myLastShort","0",0);
       CommandSet(undef, "$setdevice off");
    }
  }
}

sub milight_dimm_indirect($$) {
  my ($name,$event) = @_;
  my $Target_Devices = AttrVal($name,"Target_Device","devStrich0");
  foreach my $setdevice (split (/,/,$Target_Devices)) {
    if ($event =~ m/LongRelease/) {
	  AnalyzeCommand(undef,"deleteReading $setdevice myLastdimmLevel");
	} else {
      milight_dimm($setdevice);
	}
  }
}

sub milight_dimm($) {
  my ($Target_Device) = @_;
  my $dimmDir = ReadingsVal($Target_Device,"myDimmDir","up");
  my $dimmLevel = ReadingsVal($Target_Device,"myLastdimmLevel",ReadingsNum($Target_Device,"brightness","255"));
  if ($dimmDir ne "up") { 
    if ($dimmLevel < 4) { 
      readingsSingleUpdate($defs{$Target_Device}, "myDimmDir", "up", 0);
    } else {
      $dimmLevel -= $dimmLevel < 30 ? 3 : $dimmLevel < 70 ? 5 : $dimmLevel < 120 ? 7 : 15;
    }
  } else {
    if ($dimmLevel > 244) {
      readingsSingleUpdate($defs{$Target_Device}, "myDimmDir", "down", 0);
    } else {
      $dimmLevel += $dimmLevel < 30 ?  3 : $dimmLevel < 70 ? 5 : $dimmLevel < 120 ? 7 : 15;
    }
  }
  CommandSet(undef, "$Target_Device brightness $dimmLevel");
  readingsSingleUpdate($defs{$Target_Device}, "myLastdimmLevel",$dimmLevel, 0);
}

sub milight_FUT_to_RGBW($$) {
  my ($name,$Event) = @_;
  #return "" if ReadingsVal($name,"presence","absent") eq "absent";
  $Event =~ s/://g;
  if($Event =~ /OFF|ON/) {
    my $command = lc ($Event);
    CommandSet(undef, "$name $command");
  } elsif ($Event =~ /brightness|hue/)  {
     CommandSet(undef, "$name $Event");
  } elsif ($Event =~ /bulb_mode.*white/)  {
    my $consumer = CommandSet(undef, "$name mpdCMD status") =~ /consume. 0/ ? "1" : "0"; 
    CommandSet(undef, "$name command Weiss");
  } else {

  }  
}

sub milight_to_MPD($$) {
  my ($name,$Event) = @_;
  return "" if ReadingsVal($name,"presence","absent") eq "absent";
  if($Event =~ /ON/) {
    CommandSet(undef, "$name play") if ReadingsVal($name,"state","play") =~ /pause|stop/;
  } elsif ($Event =~ /OFF/) {
    my $command = (ReadingsVal($name,"state","play") eq "pause" ) ? "stop" : "pause";
    CommandSet(undef, "$name $command");
  } elsif ($Event =~ /brightness/)  {
    my ($reading,$value) = split (/ /,$Event);
    my $volume = int (round ($value/2,55)); 
    CommandSet(undef, "$name volume $volume");
  } elsif ($Event =~ /mode_speed_down/)  {
    CommandSet(undef, "$name previous");

  } elsif ($Event =~ /mode_speed_up/)  {
    CommandSet(undef, "$name next");

  } elsif ($Event =~ /scene/)  {
    my $gainmode = CommandSet(undef, "$name mpdCMD replay_gain_status") =~ /album/ ? "auto" : "album"; 
    
    CommandSet(undef, "$name mpdCMD replay_gain_mode $gainmode");
 	
  } elsif ($Event =~ /bulb_mode.*white/)  {
    my $consumer = CommandSet(undef, "$name mpdCMD status") =~ /consume. 0/ ? "1" : "0"; 
    CommandSet(undef, "$name mpdCMD consume $consumer");

  } else {

  }  
}

1;


=pod
=begin html

<a name="myUtils_MiLight"></a>
<h3>myUtils_MiLight</h3>
<ul>
  <b>General remarks on the other functions</b><br>
  milight_dimm_indirect($$) and milight_toggle_indirect($) are intended for the use in notify code to derive commands to one or multiple bulbs. Parameter typically is $NAME or $EVTPART0.<br>
  To get the logical link, e.g. from a button to a specific bulb, a userattr value is used, multiple bulbs have to be comma-separated.<br>
  Examples: 
  <ul>
   <code>attr Schalter_Spuele_Btn_04 userattr Target_Device<br>attr Schalter_Spuele_Btn_04 Target_Device Licht_Essen
</code><br>
  </ul>
  <ul>
   <code>defmod MiLight_dimm notify Schalter_Spuele_Btn_0[124]:Long..*[\d]+_[\d]+.\(to.VCCU\) {milight_dimm_indirect($NAME,$EVENT)}<br>defmod MiLight_toggle notify Schalter_Spuele_Btn_0[124]:Short.[\d]+_[\d]+.\(to.VCCU\) {milight_toggle_indirect($NAME)}</code><br>
  </ul>
</ul>
=end html
=cut
