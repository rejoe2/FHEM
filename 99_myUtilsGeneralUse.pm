##############################################
# $Id: myUtilsGeneralUse.pm 2021-07-26 Beta-User $
#

package main;

use strict;
use warnings;

sub
myUtilsGeneralUse_Initialize {
  my $hash = shift;
}

# Enter you functions below _this_ line.

sub mySwitchOffAfter {
  my $ondevice = shift // return;
  my $duration  = shift // "01:00:01";
  my $idname = "my_switchoff_".$ondevice;
  #fhem "sleep $duration $idname quiet;set $ondevice off"; 
  AnalyzeCommandChain(undef,"sleep $duration $idname quiet;set $ondevice off"); 

}

sub myHHMMSS2sec {
  my ($h,$m,$s) = split(":", shift);
  $m = 0 if !$m;
  $s = 0 if !$s;
  my $seconds = HOURSECONDS*$h+MINUTESECONDS*$m+$s;
  return $seconds;
}


#For presence messages via Telegram
#call: myTBotpresence($NAME,$EVTPART1)
sub myTBotpresence {
  my $name = shift;
  my $event = shift // return;
  my $msg = ReadingsVal($name,"msgText","none");
  my $target = getKeyValue($event);
  return undef if !$target;
  my $newState = "absent";
  CommandSet(undef,"$target T_last $msg");
  if ($msg =~ /^\/kurz.*/) {
    $newState = "absent" if ($msg =~ /^\/kurz.* Bin weg$/ or $msg =~ /^\/kurz 1$/);
    $newState = "present" if ($msg =~ /^\/kurz.* Zuhause$/ or $msg =~ /^\/kurz 2$/);
  }
  if ($newState =~ m/^(home|absent|present)$/) {
    CommandSet(undef,"$target T_status $newState");
    CommandSet(undef,"$target present") if $newState eq "present";
    my $checktimer = $target."_timerHK";
    my $hk_devices = AttrVal($target,"HT_Devices","devStrich0");
    if ($newState eq "present") {
      if ($msg =~ m/Komme/) {
        if (ReadingsVal("Heizperiode","state","off") eq "on")  {
          CommandCancel(undef,"$checktimer quiet");
          for my $setdevice (split (/,/,$hk_devices)) {
            CommandSet(undef,"$setdevice:FILTER=controlMode!=auto controlMode auto");
          }\
          AnalyzeCommandChain(undef,"sleep 03:00 $checktimer; set $hk_devices controlManu 18");
        }
      }
    } elsif ($newState eq "absent") {
      CommandSet(undef,"$target absent");
      if (ReadingsVal("Heizperiode","state","off") eq "on") {
        CommandSet(undef,"$hk_devices controlManu 18");
      }
    }
  }  
}

sub my_stairway_motion {
  my $dev = shift;
  my $event = shift // return;
  my $timeout = shift // 90;
  my $checktime = gettimeofday()+$timeout;

  if ($dev eq "Bewegungsmelder_Treppenhaus_EG") {
    return undef if ReadingsVal("Bewegungsmelder_Treppenhaus_Lichtlevel_EG","lux",0) > 20;
    my $setdevice = "Licht_Flur_Treppe";

    if(ReadingsAge($setdevice,"myLastPIR",10000) > 600 || ReadingsVal($setdevice,"myLastPIR","Bewegungsmelder_Treppenhaus_OG") ne "Bewegungsmelder_Treppenhaus_EG") {
    #EG-Lichter
    CommandSet(undef, "$setdevice on") if ReadingsVal($setdevice,"status","OFF") ne "ON";
    CommandSet(undef, "$setdevice brightness 163");
    readingsSingleUpdate($defs{$setdevice},"myLastPIR","$dev", 0);
    InternalTimer($checktime,"myTimeout_stairway_motion","$setdevice $dev");	
      
    #OG-Licht
    $setdevice = "Licht_Treppenhaus_OG";
    unless (ReadingsVal("$setdevice","state","off") =~ /on/) {
      CommandSet(undef, "$setdevice on : pct 25")  
    } elsif (ReadingsVal("$setdevice","brightness",0) < 80) {
      CommandSet(undef, "$setdevice brightness 40")  
    } 
    readingsSingleUpdate($defs{$setdevice},"myLastPIR","$dev", 0);
    return InternalTimer($checktime,"myTimeout_stairway_motion","$setdevice $dev");
    }
  } elsif ($dev eq "Bewegungsmelder_Treppenhaus_OG") {
    return undef if ReadingsVal("Bewegungsmelder_Treppenhaus_Lichtlevel_EG","lux",0) > 20;
    my $setdevice = "Licht_Flur_Treppe";

    if (ReadingsVal($setdevice,"status","OFF") eq "OFF") {
      CommandSet(undef, "$setdevice on");
      CommandSet(undef, "$setdevice brightness 60");
    } else {
      CommandSet(undef, "$setdevice brightness 60") if ReadingsVal($setdevice,"brightness",0) < 60;
    }
    readingsSingleUpdate($defs{$setdevice},"myLastPIR","$dev", 0);
    InternalTimer($checktime,"myTimeout_stairway_motion","$setdevice $dev");
  } 
}


sub myTimeout_stairway_motion {
  my ($name,$mdet) = split(' ',shift);
  #my $name = $hash->{NAME};
  if (ReadingsVal("$name","myLastPIR","none") eq $mdet) {
    CommandSet (undef,"$name off") ;
    CommandDeleteReading(undef, "$name myLastPIR");
  }
}

sub myCalendar2Holiday {
  my $calname    = shift // return;
  my $regexp     = shift // return;
  my $targetname = shift // $calname;
  my $field      = shift // "summary";
  my $limit      = shift // 10;
  my $from       = shift // q{-10d};
  my $to         = shift // q{100d};

  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) =  localtime(gettimeofday());
  my $getstring = $calname . ' events format:custom="4 $T1 $t2 $S ($D)" timeFormat:"%Y-%m-%d" limit:count=' . "${limit},from=${from},to=$to filter:field($field)=~\"$regexp\"";
  my @holidaysraw = split m{\n}xms, CommandGet( undef, $getstring );

  my @holidays;
  my @singledays;

  for my $holiday (@holidaysraw) {
    my @tokens = split (" ",$holiday);

    my $endsecond = $tokens[2]-1;
    my @end_arr = localtime($endsecond);


    $tokens[2] = strftime "%Y-%m-%d", localtime($endsecond);

    my $severalDays = $tokens[2] eq $tokens[1] ? 0 : 1;
    $holiday = join(' ', @tokens);
    if (!$severalDays) {
      $tokens[0] = 1;
      splice @tokens, 2, 1;
      $holiday = join(' ', @tokens);
      push (@singledays, $holiday);
    } else {
      push (@holidays, $holiday);
    }
  }
  push @holidays, @singledays;
  unshift (@holidays, "# get $getstring");
  my $today = strftime "%d.%m.%y, %H:%M", localtime(time);;\
  unshift (@holidays, "# Created by myCalendar2Holiday on $today");
  FileWrite("./FHEM/${targetname}.holiday",@holidays);
}

#own code, see https://forum.fhem.de/index.php/topic,115722.msg1100046.html#msg1100046
sub myDimUp_PctToMax {
  my $name   = shift // return;
  my $maxval = shift // 100;
  my $remote = shift;
  my $remotestop = shift // '1003';
 
  my $pct = ReadingsNum($name, 'pct', 0) +3;
  if ($pct < 103 && ReadingsVal($remote, "state", "") ne $remotestop) {
    CommandSet(undef,"$name pct $pct");
    InternalTimer(gettimeofday()+0.25, sub(){myDimUp_PctToMax($name, $maxval, $remote, $remotestop)},'');
  }
  return;
}

# SVG_log10($)
sub my_log10 {
  my $n = shift;
  return 0 if( $n <= 0 );
  return log(1+$n)/log(10);
}

1;
__END__
