##############################################
# $Id: attrT_MiLight_Utils.pm 2020-11-14 Beta-User $
#

package FHEM::attrT_MiLight_Utils;    ## no critic 'Package declaration'

use strict;
use warnings;
use Time::HiRes qw( gettimeofday );

use GPUtils qw(GP_Import);

## Import der FHEM Funktionen
#-- Run before package compilation
BEGIN {

    # Import from main context
    GP_Import(
        qw(
          AttrVal
          InternalVal
          readingsSingleUpdate
          ReadingsVal
          ReadingsNum
          ReadingsAge
          devspec2array
          json2nameValue
          AnalyzeCommandChain
          CommandDeleteReading
          CommandGet
          CommandSet
          CommandSetReading
          defs
          round
          )
    );
}

sub main::attrT_MiLight_Utils_Initialize { goto &Initialize }

# initialize ##################################################################
sub Initialize {
  my $hash = shift;
  return;
}

# Enter you functions below _this_ line.

sub toggle_indirect {
  my $name = shift // return;
  my $Target_Devices = AttrVal($name,'Target_Device','devStrich0');
  my $dimmLevel;
  my $hash;
  for my $setdevice (split (/,/x,$Target_Devices)) {
    $hash = $defs{$setdevice};
    if(lc(ReadingsVal($setdevice,'state','off')) eq 'off') {
      CommandSet(undef, "$setdevice on");
      readingsSingleUpdate($hash,'myLastShort','1', 0);
      AnalyzeCommandChain(undef, "sleep 1; set $setdevice brightness 220");
    } elsif (ReadingsAge($setdevice,'myLastShort','100') < 3) {
       my $lastToggle = ReadingsNum($setdevice, 'myLastShort',0);
       if ($lastToggle == 1) {
         readingsSingleUpdate($hash,'myLastShort','2',0);
         $dimmLevel = 110;
       } else {
         $dimmLevel = 45;
       }
       CommandSet(undef, "$setdevice brightness $dimmLevel");
    } else {
       readingsSingleUpdate($hash,'myLastShort','0',0);
       CommandSet(undef, "$setdevice off");
    }
  }
  return;
}

sub dimm_indirect {
  my $name  = shift;
  my $event = shift // return;
  my $Target_Devices = AttrVal($name,'Target_Device','devStrich0');
  for my $setdevice (split (/,/x,$Target_Devices)) {
    if ( $event =~ m{LongRelease}x ) {
      CommandDeleteReading(undef,"-q $setdevice myLastdimmLevel");
    } else {
      dimm($setdevice);
    }
  }
  return;
}

sub dimm {
  my $Target_Device = shift // return;
  my $dimmDir = ReadingsVal($Target_Device,'myDimmDir','up');
  my $dimmLevel = ReadingsVal($Target_Device,'myLastdimmLevel',ReadingsNum($Target_Device,'brightness','255'));
  if ($dimmDir ne 'up') { 
    if ($dimmLevel < 4) { 
      readingsSingleUpdate($defs{$Target_Device}, 'myDimmDir', 'up', 0);
    } else {
      $dimmLevel -= $dimmLevel < 30 ? 3 : $dimmLevel < 70 ? 5 : $dimmLevel < 120 ? 7 : 15;
    }
  } else {
    if ($dimmLevel > 244) {
      readingsSingleUpdate($defs{$Target_Device}, 'myDimmDir', 'down', 0);
    } else {
      $dimmLevel += $dimmLevel < 30 ?  3 : $dimmLevel < 70 ? 5 : $dimmLevel < 120 ? 7 : 15;
    }
  }
  CommandSet(undef, "$Target_Device brightness $dimmLevel");
  readingsSingleUpdate($defs{$Target_Device}, 'myLastdimmLevel',$dimmLevel, 0);
  return;
}

sub FUT_to_RGBW {
  my $name  = shift;
  my $event = shift // return;
  
  my $rets = json2nameValue($event);
  
  if (defined $rets->{state} && $rets->{state} =~ m{on|off}ixms) { 
    my $newState = lc($rets->{state});
    CommandSet(undef, "$name $newState");      
    return { CommandSet => "$name $newState" };
  }
  if (defined $rets->{brightness}) {
    my $bri = InternalVal($name,'TYPE','MQTT2_DEVICE') eq 'HUEDevice' ? 'bri' : 'brightness';
    CommandSet(undef, "$name $bri $rets->{brightness}");
    return { CommandSet => "$name $bri $rets->{brightness}" };
  }
  if (defined $rets->{hue}) {
    CommandSet(undef, "$name hue $rets->{hue}");
    return { CommandSet => "$name hue $rets->{hue}" };
  }
  if (defined $rets->{command}) {
    if  ($rets->{command} =~ m{white}ixms) {
       CommandSet(undef, "$name command Weiss");
       return { CommandSet => "$name command Weiss" };
    }
    return { CommandSet => "$rets->{command} not assigned" };
  }
  if (defined $rets->{saturation}) {
    if ( InternalVal($name,'TYPE','MQTT2_DEVICE') eq 'HUEDevice' ) { 
      my $sat = int($rets->{saturation}*2.54);
      CommandSet(undef, "$name sat $sat");
      return { CommandSet => "$name sat $sat" };
    } else {
       CommandSet(undef, "$name saturation $rets->{saturation}");
       return { CommandSet => "$name saturation $rets->{saturation}" };
    }
  }
  my $ret;
  for my $k (sort keys %$rets) {
    $ret .= '\n' if $ret;
    $ret .= "$k $rets->{$k}";
  }
  return { CommandSet => "$name FUT_to_RGBW not assigned: $ret" };
}

sub FUT_to_HUE {
  my $name  = shift;
  my $event = shift // return;
  
  my $rets = json2nameValue($event);
  
  my $whitecol = shift // 'FFFFFF';
  
  if (defined $rets->{state} && $rets->{state} =~ m{on|off}ixms) { 
    my $newState = lc($rets->{state});
    CommandSet(undef, "$name $newState");      
    return { CommandSet => "$name $newState" };
  }
  if (defined $rets->{brightness}) {
    my $bri = InternalVal($name,'TYPE','MQTT2_DEVICE') eq 'HUEDevice' ? 'bri' : 'brightness';
    CommandSet(undef, "$name $bri $rets->{brightness}");
    return { CommandSet => "$name $bri $rets->{brightness}" };
  }
  if (defined $rets->{hue}) {
    if (InternalVal($name,'TYPE','MQTT2_DEVICE') eq 'HUEDevice') {
      my $allset = getAllSets($name);
      return { CommandSet => "$name does not support hue" } if $allset !~ m{\bhue:[^\s\d]+,(?<min>[0-9.]+),(?<step>[0-9.]+),(?<max>[0-9.]+)\b}xms;
      my $rgb = $rets->{hue}/360*($+{max} - $+{min});
      CommandSet(undef, "$name hue $rgb");
      return { CommandSet => "$name hue $rgb" };
    } else {
      CommandSet(undef, "$name hue $rets->{hue}");
      return { CommandSet => "$name hue $rets->{hue}" };
    }
  }
  if (defined $rets->{command}) {
    if  ($rets->{command} =~ m{white}ixms) {
      if (InternalVal($name,'TYPE','MQTT2_DEVICE') eq 'HUEDevice') {
        CommandSet(undef, "$name rgb $whitecol");
        return { CommandSet => "$name rgb $whitecol" };
      } else { 
        CommandSet(undef, "$name command Weiss");
        return { CommandSet => "$name command Weiss" };
      }
    }
    return { CommandSet => "$rets->{command} not assigned" };
  }
  if (defined $rets->{saturation}) {
    if (InternalVal($name,'TYPE','MQTT2_DEVICE') eq 'HUEDevice') { 
      my $sat = int($rets->{saturation}*2.54);
      CommandSet(undef, "$name sat $sat");
      return { CommandSet => "$name sat $sat" };
    } else {
       CommandSet(undef, "$name saturation $rets->{saturation}");
       return { CommandSet => "$name saturation $rets->{saturation}" };
    }
  }
  my $ret;
  for my $k (sort keys %$rets) {
    $ret .= '\n' if $ret;
    $ret .= "$k $rets->{$k}";
  }
  return { CommandSet => "$name FUT_to_HUE not assigned: $ret" };
}


sub MPDcontrol {
  my $name  = shift;
  my $event = shift // return;
  my $avrname  = shift // $name;
  return { CommandSet => "$name not present, no command issued" } if ReadingsVal($name,'presence','absent') eq 'absent';
  
  my $rets = json2nameValue($event);
  
  if (defined $rets->{state} && $rets->{state} =~ m{on}ixms) { 
    CommandSetReading(undef, "$avrname CommandSet not on, $avrname not set to volume 25" ) if $avrname ne $name && ReadingsVal($avrname,"state","off") ne "on";
    if (ReadingsVal($name,"state","play") =~ m{pause|stop}ixms) {
      CommandSet(undef, "$name play");      
      return { "CommandSet" => "$name play" };
    } else { 
      return { "CommandSet" => "$name already playing" };
    }
  }
  if (defined $rets->{state} && $rets->{state} =~ m{off}ixms) { 
    my $command = (ReadingsVal($name,"state","play") eq "pause" ) ? "stop" : "pause";
    CommandSet(undef, "$name $command");
    return { "CommandSet" => "$name $command" };
  }
  if (defined $rets->{brightness}) {
    my $level = round($rets->{brightness}/2.55,0);
    CommandSet(undef, "$name volume $level");
    return { "CommandSet" => "$name volume $level" };
  }
  if (defined $rets->{color_temp}) {
    my $avrVol = 100 - int(($rets->{color_temp}-153)/2.17);
    return { "CommandSet" => "$avrname not on, $avrname not set to volume $avrVol" } if $avrname ne $name && ReadingsVal($avrname,"state","off") ne "on";
    CommandSet(undef, "$avrname volume $avrVol");
    return { "CommandSet" => "$avrname volume $avrVol" };
  }
  if (defined $rets->{saturation}) {
    my $avrVol = 100 - $rets->{saturation};
    return { "CommandSet" => "$avrname not on, $avrname not set to volume $avrVol" } if $avrname ne $name && ReadingsVal($avrname,"state","off") ne "on";
    CommandSet(undef, "$avrname volume $avrVol");
    return { "CommandSet" => "$avrname volume $avrVol" };
  }
    if (defined $rets->{command}) {
    if ($rets->{command} eq "mode_speed_up") {
      CommandSet(undef, "$name previous") ;
      return { "CommandSet" => "$name previous" } ;
    }
    if  ($rets->{command} eq "mode_speed_down") {
      CommandSet(undef, "$name next");
      return { "CommandSet" => "$name next" };
    }
    else {
      return { "CommandSet" => "$rets->{command} not assigned" };
    }
  }
  if (defined $rets->{mode}) {
    my $gainmode = CommandGet(undef, "$name mpdCMD replay_gain_status") =~ m{album}ixms ? "auto" : "album"; 

    CommandSet(undef, "$name mpdCMD replay_gain_mode $gainmode");
    return { "CommandSet" => "$name mpdCMD replay_gain_mode $gainmode" };
  }
  if (defined $rets->{bulb_mode} && $rets->{bulb_mode} =~ m{white}ixms) {
    my $consumer = CommandGet(undef, "$name mpdCMD status") =~ m{consume. 0}ixms ? "1" : "0"; 
    CommandSet(undef, "$name mpdCMD consume $consumer");
    return { "CommandSet" => "$name mpdCMD consume $consumer" };
  }
  my $ret;
  for my $k (sort keys %$rets) {
    $ret .= '\n' if $ret;
    $ret .= "$k $rets->{$k}";
  }
  return { "CommandSet" => "$name MPDcontrol not assigned: $ret" };
}

sub shuttercontrol {
  my $name  = shift;
  my $event = shift // return;
  my $type = InternalVal($name,"TYPE","MQTT2_DEVICE"); 
  my $moving = ReadingsVal($name,"motor","stop") =~ m{stop}ixms ? 0 : 1;
  $moving = 1 if ReadingsNum($name,"power",0) > 1 && $type eq "ZWave";

  my $rets = json2nameValue($event);
  
  my $com = "off";
  my $now = gettimeofday;
  if (!$moving && defined $rets->{state} && $rets->{state} =~ m{on|off}ixms) {
    if ($now - ReadingsVal($name, "myLastRCOnOff",$now) < 5) {
      CommandSetReading(undef,"$name myLastRCOnOff $now");
      my $level = $rets->{state} =~ m/off/i ? 0 : 100;
      $com = $type eq "ZWave" ? "dim" : "pct"; 
      $level = 99 if ($level == 100 && $type eq "ZWave");
      CommandSet(undef, "$name $com $level");
      return { "CommandSet" => "$name $com $level" };
    } 
    return CommandSetReading(undef,"$name myLastRCOnOff $now"); 
  } 
  if (defined $rets->{state} && $rets->{state} =~ m{on|off}ixms) { 
    CommandSetReading(undef,"$name myLastRCOnOff $now");
    CommandSet(undef,"$name stop");
    return { "CommandSet" => "$name stop" };
  }
  if (defined $rets->{brightness}) {
    my $level = round($rets->{brightness}/2.55,0);
    $com = $type eq "ZWave" ? "dim" : "pct"; 
    $level = 99 if ($level == 100 && $type eq "ZWave");
    CommandSet(undef, "$name $com $level");
    return { "CommandSet" => "$name $com $level" };
  } 
  if (defined $rets->{saturation}) {
    my $slatname = $name;
    my $slatlevel = 100 - $rets->{saturation};
    $com = $type eq "ZWave" ? "dim" : "slats"; 
    $slatlevel = 99 if ($slatlevel == 100 && $type eq "ZWave");
    my ($def,$defnr) = split(" ", InternalVal($name,"DEF",$name));
    $defnr++;
    my @slatnames = devspec2array("DEF=$def".'.'.$defnr);
    $slatname = shift @slatnames;
    
    CommandSet(undef, "$slatname $com $slatlevel");
    return { "CommandSet" => "$slatname $com $slatlevel" };

  } 
  if (defined $rets->{color_temp}) {
    my $slatname = $name;
    my $slatlevel = 100 - ($rets->{color_temp}/(370-153))*100;
    $com = $type eq "ZWave" ? "dim" : "slats"; 
    $slatlevel = 99 if ($slatlevel == 100 && $type eq "ZWave");
    my ($def,$defnr) = split(" ", InternalVal($name,"DEF",$name));
    $defnr++;
    my @slatnames = devspec2array("DEF=$def".'.'.$defnr);
    $slatname = shift @slatnames;
    CommandSet(undef, "$slatname $com $slatlevel");
    return { "CommandSet" => "$slatname $com $slatlevel" };
  }
  my $ret;
  for my $k (sort keys %$rets) {
    $ret .= '\n' if $ret;
    $ret .= "$k $rets->{$k}";
  }
  return { "CommandSet" => "$name shuttercontrol not assigned: $ret" };
}

sub four_Lights_matrix {
  my $event = shift;
  my $devA  = shift // return;
  my $devB  = shift // $devA;
  my $devC  = shift // $devB;
  my $devD  = shift // $devC;
  
  my $rets = json2nameValue($event);
  
  if (defined $rets->{command}) {
    if ($rets->{command} eq "mode_speed_up") {
    CommandSet(undef, "$devC toggle") ;
    return { "CommandSet" => "$devC toggle" } ;
    }
    if  ($rets->{command} eq "mode_speed_down") {
    CommandSet(undef, "$devA toggle");
    return { "CommandSet" => "$devA toggle" };
    }
    if ($rets->{command} eq "set_white") {
    CommandSet(undef, "$devB toggle");
    return { "CommandSet" => "$devB toggle" };
    }
  } 
  if (defined $rets->{mode}) {
    CommandSet(undef, "$devD toggle");
    return { "CommandSet" => "$devD toggle" };
  } else {
    my @ondevs = devspec2array("($devA|$devB|$devC|$devD):FILTER=state=on");
    if (@ondevs) {
      CommandSet(undef, "($devA|$devB|$devC|$devD):FILTER=state=on off") if (defined $rets->{state} && $rets->{state} eq "OFF");
      defined $rets->{state} && $rets->{state} eq "OFF" ? return { "CommandSet" => "($devA|$devB|$devC|$devD):FILTER=state=on off" } : return { "CommandSet" => "nothing to do, all already off" };
    } else {
      CommandSet(undef, "$devA on");
      return { "CommandSet" => "$devA on" };
    } 
  }
  my $ret;
  for my $k (sort keys %$rets) {
    $ret .= '\n' if $ret;
    $ret .= "$k $rets->{$k}";
  }
  return { "CommandSet" => "four_Lights_matrix not assigned: $ret" };
}


sub Show_keyValue {
  my $event = shift // return;
  my $name = shift;
  
  my $rets = json2nameValue($event);
  
  my $ret;
  for my $k (sort keys %$rets) {
    $ret .= '\n' if $ret;
    $ret .= "$k $rets->{$k}";
  }
  return { CommandSet => "$name Key->Value is $ret" } if defined $name;
  return { CommandSet => "Key->Value is $ret" };
}


1;

__END__

=pod
=begin html

<a name="attrT_MiLight_Utils"></a>
<h3>attrT_MiLight_Utils</h3>
<ul>
  <b>Routines to handle remote control signals in MiLight context</b><br> 
  All MiLight hardware (bulbs and remotes) are represented by MQTT2_DEVICE using a esp8266_milight_hub as described here: https://github.com/sidoh/esp8266_milight_hub.<br>
  This pieces of code offer options to build links between MiLight@MQTT2_DEVICE and "other" FHEM devices (e.g. HUE bulbs, shutter devices, Homematic remotes) and can also be used to built an indirect bridge between V6 remotes and V5 bulbs.
</ul>
<ul><ul>
  <b>Routines to use MiLight remotes as input device</b><br>
  NOTE: As activation of a specific layer on the remote requires to press the "on" button, often the first "on" command will be ignored. You have to press the key twice within a few seconds in these cases. This is especially the case, when controlling other devices than lights to avoid unexpected or unintended behaviour (like starting a music player when only reduction of volume is intended as first step).  <br><br>
  For most It's recommended to setup a single MQTT2_DEVICE per remote to dispatch all received commands like this one:<br>
  <pre>defmod MiLight_RC_WZ MQTT2_DEVICE milight_0x5D47_0
attr MiLight_RC_WZ readingList milight/updates/0x5D47/fut089/0:.* { FHEM::attrT_MiLight_Utils::MPDcontrol('myMPD',$EVENT, 'AVR_name') }\
milight/updates/0x5D47/fut089/1:.* { FHEM::attrT_MiLight_Utils::FUT_to_RGBW('Licht_Stehlampe_links',$EVENT) }\
milight/updates/0x5D47/fut089/2:.* { FHEM::attrT_MiLight_Utils::FUT_to_RGBW('Licht_Stehlampe_rechts',$EVENT) }\
milight/updates/0x5D47/fut089/3:.* { FHEM::attrT_MiLight_Utils::four_Lights_matrix($EVENT, 'Licht_WoZi_Vorn_Aussen', 'Licht_WoZi_Vorn_Mitte', 'Licht_WoZi_Hinten_Aussen', 'Licht_WoZi_Hinten_Mitte') }\
milight/updates/0x5D47/fut089/4:.* { FHEM::attrT_MiLight_Utils::shuttercontrol('Jalousie_WZ',$EVENT) }\
milight/updates/0x5D47/fut089/5:.* { FHEM::attrT_MiLight_Utils::shuttercontrol('Rollladen_WZ_SSO',$EVENT) }\
milight/updates/0x5D47/fut089/6:.* { FHEM::attrT_MiLight_Utils::shuttercontrol('Rollladen_WZ_SSW',$EVENT) }\
milight/updates/0x5D47/fut089/7:.* { FHEM::attrT_MiLight_Utils::Show_keyValue($EVENT,'layer7') }\
milight/updates/0x5D47/fut089/8:.* {}\
milight/states/0x5D47/fut089/[0-8]:.* {}
</pre>
  The last two lines will just prevent further actions derived frim the not used channels (or the states info including everything) from to hub.<br>
  All routines expect one or more target device names to be switched, the received JSON $EVENT will be handed over as is and is analysed within the routines.<br>
  If there's no specific action assigned, the reading CommandSet will contain some more info about which routine was called and what key had been pressed. Might help to derive other/additional event handling routines...<br> 
  <br>
<ul>
  <b>FHEM::attrT_MiLight_Utils::FUT_to_RGBW</b><br>
  Allows indirect control of <br>
  - other MiLight devices using a different protocol or <br> 
  - other light devices. Especially HUEDevice should work also for brightness and hue commands.<br> 
</ul><br>
<ul>
  <b>FHEM::attrT_MiLight_Utils::FUT_to_HUE</b><br>
  Just like FHEM::attrT_MiLight_Utils::FUT_to_RGBW, but with extended support for HUE type target devices.
</ul><br>
<ul>
  <b>FHEM::attrT_MiLight_Utils::shuttercontrol</b><br>
  Allows control of shutter devices. Tested with following devices:<br>
  - HM-LC-Bl1PBU-FM as CUL_HM, shutters only<br>
  - ZWave actor FGR-223 in venetian mode - lamella position can be controlled via saturation slider<br>
</ul><br>
<ul>
  <b>FHEM::attrT_MiLight_Utils::four_Lights_matrix</b><br>
  Allows to control a group of 4 simple on/off devices using the four mode buttons (in the middle of the remote).<br>
</ul><br>
<ul>
  <b>FHEM::attrT_MiLight_Utils::MPDcontrol</b><br>
  Allows control of a MusicPlayerDeamon - basics like play, pause, stop and volume.<br>
  Third argument is optional and allows control of volume channel of an AVR device (uses  saturation slider).<br>
  Additionally toggle two replay gain modes and "consumer" setting.<br> 
  If state of the AVR device is off, you'll get an additional event, allowing to switch it on, e.g. by using a notify like<br>
  <code>defmod MiLight_RC_WZ_notify_1 notify MiLight_RC_WZ:CommandSet:.Yamaha_Main.not.on,.Yamaha_Main.not.set.to.volume.* set $EVTPART1 on;; sleep 2.5 $EVTPART1;; set $EVTPART1 volume $EVTPART9;; set $EVTPART1 input hdmi4;; set $EVTPART1 dsp 7chstereo }
</code><br><br>
</ul>
<ul>
  <b>FHEM::attrT_MiLight_Utils::Show_keyValue</b><br>
  Helper function to get some info about the received $EVENT without the need of a separate device. Might be usefull to derive own actions, just like with other unassigned buttons in one of the functions above. 2. parameter is optional, but might e.g. help to identify respective remote channel or hand over target device.
</ul>
</ul>


<ul>
  <br><br>
  <b>Routines to use other remote types to control MiLight bulbs</b><br>
  <code>FHEM::attrT_MiLight_Utils::dimm_indirect</code> and <code>FHEM::attrT_MiLight_Utils::toggle_indirect</code> are intended for the use in notify code to derive commands to one or multiple bulbs. Parameter typically is $NAME or $EVTPART0.<br>
  To get the logical link, e.g. from a button to a specific bulb, a userattr value is used, multiple bulbs have to be comma-separated.<br>
</ul>
<ul>
 Examples: 
</ul>
<ul>
  <code>attr Schalter_Spuele_Btn_04 userattr Target_Device<br>attr Schalter_Spuele_Btn_04 Target_Device Licht_Essen</code><br>
  This way, one notify can be used to derive actions on various devices
</ul>
<ul>
  <code>defmod MiLight_dimm notify Schalter_Spuele_Btn_0[124]:Long..*[\d]+_[\d]+.\(to.VCCU\) {FHEM::attrT_MiLight_Utils::dimm_indirect($NAME,$EVENT)}<br>defmod MiLight_toggle notify Schalter_Spuele_Btn_0[124]:Short.[\d]+_[\d]+.\(to.VCCU\) {FHEM::attrT_MiLight_Utils::toggle_indirect($NAME)}</code><br>
</ul>
</ul>
<ul>

</ul>
=end html
=cut
