##############################################
# $Id: myUtils_Homematic.pm weekprofile edition 2022-04-25 Beta-User $
#

package main;

use strict;
use warnings;

sub
myUtils_Homematic_Initialize
{
  my $hash = shift;
}

# Enter you functions below _this_ line.

sub myWinContactNotify {  #three parameters, last (timeout) is optional
  my $window = shift;
  my $event  = shift // return;
  my $timeout = shift // 90;
  my @virtuals = devspec2array("TYPE=CUL_HM:FILTER=model=VIRTUAL:FILTER=myRealFK=.*$window.*");
  for my $virtual (@virtuals) {
    my $myreals = AttrVal($virtual,'myRealFK','');
    if ($event =~ /open|tilted/) {
	  $timeout = AttrVal($virtual,'myTimeout',$timeout) if $timeout == 90;
      my $checktime = gettimeofday()+$timeout;
      InternalTimer($checktime,'myTimeoutWinContact',$virtual);	
    } else {
      my @wcs = split(',',$myreals); 
      my $openwc = 0;
      for my $wc (@wcs) {
        $openwc++ if (ReadingsVal($wc,'state','closed') ne 'closed');
        last if $openwc;
      }
      CommandSet (undef,"$virtual geschlossen") if !$openwc;
    }
  }
  return;
}

sub myTimeoutWinContact {
  my $name = shift // return;
  return if !ReadingsVal('Heizperiode','state','off') eq 'on';
  my $myreals = AttrVal($name,'myRealFK','');
  my @wcs = split(',',$myreals); 
  my $openwc = 0;
  for my $wc (@wcs) {
    $openwc++ if ReadingsVal($wc,'state','closed') ne 'closed';
    last if $openwc;
  }
  CommandSet (undef,"$name offen") if $openwc;
  return;
}

sub devStateIcon_Clima {
  my $climaname = shift // return;
  my $ret ='';
  my $name = InternalVal($climaname,'device',$climaname);
  my $TC = AttrVal($name,'model','HM-CC-RT-DN') eq 'HM-TC-IT-WM-W-EU' ? 1:0;
  my $state = ReadingsVal($name,'commState','NACK');

  #Battery
  my $batval  = ReadingsVal($name,'batteryLevel','');
  my $symbol_string = 'measure_battery_';
  my $command_string = 'getConfig';
  if ($batval >=3) {
    $symbol_string .= '100'
  } elsif ($batval >2.6) {
    $symbol_string .= '75'
  } elsif ($batval >2.4) {
    $symbol_string .= '50'
  } elsif ($batval >2.1) {
    $symbol_string .= '25'
  } else {
    $symbol_string .= '0@red'
  };

  if ($state =~ m{CMDs_p}x) {
    $symbol_string = 'edit_settings';
    $command_string = 'clear msgEvents'; 
  } elsif ($state =~ m{RESPONSE|NACK}x) {
    $command_string = 'clear msgEvents'; 
    $symbol_string = 'edit_settings@red' ;
  }
  $ret .= "<a href=\"/fhem?cmd.dummy=set $name $command_string&XHR=1\">" . FW_makeImage($symbol_string,'measure_battery_50') . '</a>'; 

  #Lock Mode
  my $btnLockval = ReadingsVal($name,'.R-btnLock','on') ;
  my $btnLockvalSet = $btnLockval =~ m{on}x ? 'off':'on';
  $symbol_string = $btnLockval =~ m{on}x ? 'secur_locked': 'secur_open';
  $ret .= " <a href=\"/fhem?cmd.dummy=set $name regSet btnLock $btnLockvalSet&XHR=1\">" . FW_makeImage($symbol_string, 'locked') . '</a>';

  #ControlMode
  my $controlval = ReadingsVal($climaname,'controlMode','manual');
  my $controlvalSet = $controlval =~ m{manual}x ? 'auto':'manual';
  $symbol_string = $controlval =~ m{manual}x ? 'sani_heating_manual' : 'sani_heating_automatic';
  $ret .= " <a href=\"/fhem?cmd.dummy=set $climaname controlMode $controlvalSet&XHR=1\">" . FW_makeImage($symbol_string,'sani_heating_manual') . '</a>';

  #Humidity/program or actuator
  if ($TC) {
    #progSelect
    #Reading: R-weekProgSel  (z.B. prog1) Bild: rc_1 usw., 
    my $progVal = ReadingsVal($climaname,'R-weekPrgSel','none') ;
    my $progValSet = $progVal =~ m{prog1}x ? 'prog2' : $progVal =~ m{prog2}x ? 'prog3':'prog1' ;
    $symbol_string = $progVal =~ m{prog1}x ? 'rc_1' : $progVal =~ m{prog2}x ? 'rc_2': $progVal =~ m{prog3}x ?'rc_3':'unknown' ;
    $ret .= " <a href=\"/fhem?cmd.dummy=set $climaname regSet weekPrgSel $progValSet&XHR=1\">" . FW_makeImage($symbol_string, 'rc_1') . '</a> ';
    #humidity
    my $humval = ReadingsVal($climaname,'humidity','') ;
    #my $humcolor = "";
    $symbol_string = "humidity";
    $ret .= " " . FW_makeImage($symbol_string,'humidity') . " $humval%rH";
  } else {
    my $actorval = ReadingsVal($name,'actuator','');
    my $actor_rounded = int (($actorval +5)/10)*10;
    $symbol_string = "sani_heating_level_$actor_rounded";
    $ret .= " " . FW_makeImage($symbol_string,'sani_heating_level_40') ;
  }

  #measured temperature
  my $tempval = ReadingsVal($climaname,'measured-temp',0) ;
  my $tempcolor ='';
  $symbol_string = 'temp_temperature';
  $symbol_string .= '@' . $tempcolor if $tempcolor;
  $ret .= FW_makeImage($symbol_string,'temp_temperature') . "$tempval°C ";

  #desired temperature: getConfig
  my $desired_temp = ReadingsVal($name,'desired-temp','21') ;
  $symbol_string = 'sani_heating_boost' if $controlval =~ /boost/;
  $ret .= "<a href=\"/fhem?cmd.dummy=set $climaname controlMode boost&XHR=1\">" . FW_makeImage($symbol_string,'temp_control') . '</a>';

  return "<div><p style=\"text-align:right\">$ret</p></div>";
}


#Aufruf:   {HM_TC_Holiday (<Thermostat>,"16", "06.12.13", "16:30", "09.12.13" ,"05:00")}
sub HM_TC_Holiday { # 6 Parameters needed
  my ($rt, $temp, $startDate, $startTime, $endDate, $endTime) = @_;
  my $climaname = $rt.'_Clima';
  $climaname = $rt.'_Climate' if AttrVal($rt,'model','HM-CC-RT-DN') eq 'HM-TC-IT-WM-W-EU';

  # HM-CC-RT-DN and HM-TC-IT-WM-W-EU accept time arguments only as plain five minutes
  # So we have to round down $startTime und $endTime
  #$startTime = roundTime2fiveMinutes($startTime);
  #$endTime = roundTime2fiveMinutes($endTime);
  $startTime =~ s/\:[0-2].$/:00/;
  $startTime =~ s/\:[3-5].$/:30/;
  $endTime =~ s/\:[0-2].$/:00/;
  $endTime =~ s/\:[3-5].$/:30/;
  return CommandSet (undef,"$climaname controlParty $temp $startDate $startTime $endDate $endTime");
}

sub easy_HM_TC_Holiday { # 4 parameters, last two optional
  my $rt = shift // return;
  my $temp = shift // return;
  my $duration = shift // 3*3600; # 3 hours
  my $strt =  shift // gettimeofday();
  $duration = 0 if $strt eq 'stop';
  $strt = gettimeofday() if $strt eq 'now';
  $strt = gettimeofday() if $strt eq 'stop';
  if ( $strt =~ m{\A(\d+):(\d+)\z}x ) {
    $strt = $1*DAYSECONDS + $2*HOURSECONDS;
  };
  if ( $duration =~ m{\A(\d+):(\d+)\z}x ) {
    $duration = $1*DAYSECONDS + $2*HOURSECONDS;
  };
  my ($startDate, $startTime) = split(' ', sec2time_date($strt));
  my ($endDate, $endTime) = split(' ', sec2time_date($strt+$duration));
  #Log3 ($rt, 3, "myHM-utils $rt: Dauer: $duration, Start: $startDate, $startTime, Ende: $endDate, $endTime");
  #return "myHM-utils $rt: Dauer: $duration, Start: $startDate, $startTime, Ende: $endDate, $endTime"
  return HM_TC_Holiday($rt,$temp,$startDate,$startTime,$endDate,$endTime);
}

sub hm_firmware_update_httpmod_stateFormat {
  my $name = shift // return;
  my $lastCheck = ReadingsTimestamp($name,'MATCHED_READINGS','???'); 
  my $ret .= '<div style="text-align:left">last <a title="eq3-downloads" href="http://www.eq-3.de/service/downloads.html">homematic</a>-fw-check => '.$lastCheck; 
  $ret .= '<br><br><pre>'; 
  $ret .= "| device                  | model                   | cur_fw | new_fw | release    |<br>"; 
  $ret .= "------------------------------------------------------------------------------------<br>"; 
  my $check = ReadingsVal($name,"newFwForDevices","error => no or wrong data from eq3-server!"); 
  if($check eq "no fw-updates needed!") {
    $ret .= '| ';
    $ret .= '<b style="color:green">';
    $ret .= sprintf("%-80s",$check);
    $ret .= '</b> |';
  } elsif($check eq "error => no or wrong data from eq3-server!") {
    $ret .= '| <b style="color:red">';
    $ret .= sprintf("%-80s",$check);
    $ret .= '</b> |';
  } else { 
    my @devices = split(',',$check); 
    foreach my $devStr (@devices) { 
      my ($dev,$md,$ofw,$idx,$nfw,$date) = $devStr =~ m/^([^\s]+)\s\(([^\s]+)\s\|\sfw_(\d+\.\d+)\s=>\sfw(\d\d)_([\d\.]+)\s\|\s([^\)]+)\)$/; 
      my $link = ReadingsVal($name,"fw_link-".$idx,"???"); 
      $ret .= '| <a href="/fhem?detail='.$dev.'">';
      $ret .= sprintf("%-23s",$dev);
      $ret .= '</a> | <b';
      $ret .= (($md eq "?")?' title="missing attribute model => set device in teach mode to receive missing data" style="color:yellow"':' style="color:lightgray"').'>';
      $ret .= sprintf("%-23s",$md);
      $ret .= '</b> | <b'.(($ofw eq "0.0")?' title="missing attribute firmware => set device in teach mode to receive missing data" style="color:yellow"':' style="color:lightgray"').'>'; 
      $ret .= sprintf("%6s",$ofw); 
      $ret .= '</b> | <a title="eq3-firmware.tgz" href="'.$link.'"><b style="color:red">'; 
      $ret .= sprintf("%6s",$nfw); 
      $ret .= '</b></a> | '; 
      $ret .= sprintf("%-10s",$date);
      $ret .= " |<br>";
    }
  }
  $ret .= '</pre></div>';
  return $ret;
}

sub hm_firmware_update_httpmod_newFwForDevices {
  my $name = shift // return;
  my $ret = "";
  my @data;
  if (ReadingsVal($name,"UNMATCHED_READINGS","?") eq "") {
    my @eq3FwList = 
      map{
        @data = ReadingsVal($name,"fw_link-".$_,"?") =~ m/firmware\/(.*?)_update_[vV]([\d_]+)_(\d\d)(\d\d)(\d\d)/;
        $data[0] =~ s/_/-/g;
        sprintf("%s:%s:%s.%s.%s:%s",$data[0],$data[1],$data[4],$data[3],"20".$data[2],$_);
      } ReadingsVal($name,"MATCHED_READINGS","?") =~ m/fw_link-(\d\d)/g;

    for my $dev (devspec2array("TYPE=CUL_HM:FILTER=DEF=......:FILTER=subType!=(virtual|)")) {
      my $md = AttrVal($dev,"model","?");
      my $v = AttrVal($dev,"firmware","0.0");
      my ($h,$l) = split('\.',$v);
      for my $newFw (grep m/^${md}:/i,@eq3FwList) {
        my ($nh,$nl,$no,$date,$idx) = $newFw =~ m/^[^:]+:(\d+)_(\d+)_?(\d*):([^:]+):(\d\d)$/;
        if(($nh > $h) || (($nh == $h) && ($nl > $l))) {
          $ret .= "," if($ret ne "");
          $ret .= $dev." (".$md." | fw_".$v." => fw".$idx."_".$nh.".".$nl.($no?sprintf(".%d",$no):"")." | ".$date.")";
        }
      }
    }
  } else {
    $ret = "error => no or wrong data from eq3-server!";
  }
  return ($ret eq "")?"no fw-updates needed!":$ret;
}


sub sec2time_date {
  my $seconds = shift // return;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($seconds);
  $year = sprintf("%02d", $year % 100); #shorten to 2 digits
  $mon  = $mon+1; #range in localtime is 0-11
  $mon  = '0' . $mon  if $mon  < 10;
  $hour = '0' . $hour if $hour < 10;
  $min  = '0' . $min  if $min  < 10;
  my $date = $mday . '.' . $mon . '.' . $year;
  my $time = $hour . ':' . $min;
  return "$date $time";
}

sub roundTime2fiveMinutes {
  my $time = shift // return;
  if ($time =~ m{\A([0-2]\d):(\d)(\d)\z}x) {
    my $n = $3;
    $n = '0' if $n < 5;
    $n = '5' if $n > 5;
    return "$1:$2$n";
  }
  return;
}

sub hm_copy_devTempList_to_weekprofile {
  my $name   = shift; #source device (HM-CC-RT-DN or HM-TC-IT-WM-W-EU)
  my $target = shift // return "provide source and target name!";
  return "No device $name defined!"   if !defined $defs{$name};
  return "No device $target defined!" if !defined $defs{$target};
  return "$target is not a weekprofile device!" if InternalVal($target,'TYPE','unknown') ne 'weekprofile';
  #weekprofile device name
  #Templatenamen aus dem Thermostat holen
  my $topic = AttrVal($name,'tempListTmpl','default');
  #Profil aus dem Thermostat
  my $prfDev = weekprofile_readDevProfile($name,InternalVal($name, 'TYPE', 'unknown'), $target);
  
  #Profil zum Editor hinzufügen
  CommandSet(undef, "$target profile_data $topic:$name $prfDev");
  return;
}

sub hm_copy_wpToHMInfo {
  my $name   = shift // return 'provide weekprofile source name!';
  my $target = shift // return 'provide HMinfo device name!';
  my $mode = shift // 1;
  my $naming = shift // 1; #not use wp name as prefix
  
  return "No device $name defined!"   if !defined $defs{$name};
  return "No device $target defined!" if !defined $defs{$target};
  return "$target is not a HMinfo device!" if InternalVal($target,'TYPE','unknown') ne 'HMinfo';
  use JSON;         #libjson-perl
  
  my @topicnames = split m/:/xms, ReadingsVal($name,'topics','default');
  my @D = ("Sat","Sun","Mon","Tue","Wed","Thu","Fri");
  my ($text,$tmp)='';
  for my $topic (@topicnames) {
    my $confFile = './'.AttrVal($target,'configDir','FHEM').'/';
    $confFile .= "${name}_" if $naming;
	$confFile .= "${topic}.cfg";
    my $ret="\#               bis   Soll bis   Soll bis   Soll bis   Soll\n";
    my $profilenames = CommandGet(undef, "$name profile_names $topic");
    my @lines = split /,/, $profilenames;
    for my $Raum (@lines)  {
      $tmp = CommandGet(undef,"$name profile_data $topic:$Raum");
      if ($tmp !~ m{(profile.*not.found|usage..profile_data..name)}xms ) {
        $text = decode_json($tmp);
        $ret.="\n" if $ret ne '';
        $ret.="entities:${Raum}\n";
        for my $i (0..6) {
          $ret.="R_".$i."_tempList".$D[$i].">";
          for my $j (0..7) {
            if (defined $text->{$D[$i]}{'time'}[$j]) {
              $ret.=$text->{$D[$i]}{'time'}[$j]." ".$text->{$D[$i]}{'temp'}[$j]." ";
            }
          }
          $ret.="\n";
        }
      }
    }
    my ($err, @content) = FileRead($confFile);
    @content='' if !$mode;
    push @content, $ret;
    $err = FileWrite($confFile,@content);
    return $err if $err;
  }
  return 'HMinfo configTempFile(s) written';
}


sub hm_copy_HMInfoTowp {
  my $name   = shift // return 'provide HMinfo source name!';
  my $target = shift // return 'provide weekprofile device name!';
  return "No device $name defined!"   if !defined $defs{$name};
  return "No device $target defined!" if !defined $defs{$target};
  return "$target is not a HMinfo device!" if InternalVal($name,'TYPE','unknown') ne 'HMinfo';
  return "$target is not prepared for topic use!" if !AttrVal($target,'useTopics',0);
  use JSON;         #libjson-perl

  my $confDir = AttrVal($name,'configDir','FHEM');
  my $confFiles = AttrVal($name,'configTempFile','weekprofile-tempList.cfg');
  my @files = split m/,/x, $confFiles; 

  for (my $h = 0; $h < @files ; $h++) {
    my $confFile = $files[$h];
    my ($err, @cfgDataAll) = FileRead( qq(./$confDir/$confFile) );
    return $err if $err;
    $confFile =~s/.cfg//g; #delete file extension
    
    my ($Raum,$prfDev,@rooms);
    my $json = JSON->new->allow_nonref;

    for (my $i = 0; $i < @cfgDataAll ; $i++) {
      if ($cfgDataAll[$i] =~ /^entities:(.*)/x) {
        if ($i>0) {
        $prfDev = $json->encode($prfDev);
        CommandSet(undef, "$target profile_data $Raum:$confFile $prfDev");
      }
        @rooms = split m/,/x, $1;
		$Raum = $rooms[0];
        $prfDev = undef;
      } elsif ( $cfgDataAll[$i] =~ m/^R_.*tempList.*/x ) {
         #R_0_tempListSat>24:00 18.0 
         my ($day, $prf) = split m/[>]/x, $cfgDataAll[$i]; 
         # split into time temp time temp etc.
         # 06:00 17.0 22:00 21.0 24:00 17.0
         my @timeTemp = split m/[ ]/x, $prf;
         next if $day =~ m/^R_P[23].*tempList(...)/x; # skip other than first WT profiles
         $day = $day =~ m/^R_.*tempList(...)/x ? $1 : $day;
         my (@times,@temps);
         for(my $j = 0; $j < scalar(@timeTemp); $j += 2) {
           push(@times, $timeTemp[$j]);
           push(@temps, $timeTemp[1+$j]);
         }
         if (scalar(@times)==0) {
           push @times, '24:00';
           push @temps, '18.0';
         }
         $prfDev->{$day}->{temp} = \@temps;
         $prfDev->{$day}->{time} = \@times;
      }
    }
    if ( $prfDev ) {
      $prfDev = $json->encode($prfDev);
      CommandSet(undef, "$target profile_data $confFile:$Raum $prfDev") ;
	  for(my $j = 1; $j < scalar(@rooms); $j ++) {
	    CommandSet(undef, "$target reference_profile $confFile:$Raum $confFile:$rooms[$j]") if defined $rooms[$j];
	  }
    }
  }
  return "HMinfo configTempFile $confFiles imported";
}



1;

__END__
=pod
=begin html

<a name="myUtils_Homematic"></a>
<h3>myUtils_Homematic</h3>
<ul>
  <li><b>devStateIcon_Clima</b>
  <br>
  Use this to get a multifunctional iconset to control HM-CC-RT-DN or HM-TC-IT-WM-W-EU devices<br>
  Examples: 
  <ul>
   <code>attr Thermostat_Esszimmer_Gang_Clima devStateIcon {devStateIcon_Clima($name)}<br> attr Thermostat_Esszimmer_Gang_Clima webCmd desired-temp</code><br>
  </ul>
  </li><br>
  <li><b>easy_HM_TC_Holiday</b>
  <br>
  Use this to set one RT or WT device in party mode (or end it) without doing much calculation in advance<br>
  Parameters: Device, Temperature. Optional: duration and/or starttime (in seconds or as days:hours). Starttime may also be "now" (default, when no argument is given), keyword "stop" ends holiday mode immedately.<br>
    NOTE: rounding is applied as described at HM_TC_Holiday.<br>
  Examples: 
  <ul>
   <code>{easy_HM_TC_Holiday('Thermostat_Esszimmer_Gang','16')}</code><br>
   <code>{easy_HM_TC_Holiday('Thermostat_Esszimmer_Gang','16','now')}</code><br>
   <code>{easy_HM_TC_Holiday('Thermostat_Esszimmer_Gang','16','stop')}</code><br>
   <code>{easy_HM_TC_Holiday('Thermostat_Esszimmer_Gang','16','9000','now')}</code><br>
   <code>{easy_HM_TC_Holiday('Thermostat_Esszimmer_Gang','21.5','3600','9000')}</code><br>
   <code>{easy_HM_TC_Holiday('Thermostat_Esszimmer_Gang','21.5','1:5','32:14')}</code><br>
  </ul>
  </li><br>
  <li><b>HM_TC_Holiday</b>
  <br>
  Use this to set one RT or WT device in party mode<br>
  Parameters: Device, Temperature, start date, start time, end date, end time<br>
  NOTE: as these devices only accept time settings to 00 minutes and 30 minutes, all other figures will be rounded down to 00 or 30 minutes. Don't bother to do it by yourself, but note, effectively, the result could be a shorter periode of party mode.<br>
  Example: 
  <ul>
   <code>{HM_TC_Holiday ('Thermostat_Esszimmer_Gang','16', '14.02.19', '16:30', '15.02.19' ,'05:00')}</code><br>
  </ul>
  </li><br>
  <li><b>hm_copy_HMInfoTowp</b>
  <br>
  Use this to import existant CUL_HM-tempList file(s) to weekprofile (useTopics has to be enabled there). Filename will be used as topic, "entities" will be used as profile names.
  <br>
    NOTE: May not work, if there's a comma-separated list of entities in the file.<br>
  Example: 
  <ul>
   <code>{hm_copy_HMInfoTowp('hm','weekprofiles')}</code><br>
  
  </ul>
  </li><br>
  <li><b>hm_copy_wpToHMInfo</b>
  <br>
  Use this to export existant weekprofiles to CUL_HM-comatible tempList file(s). Filename(s) will be derived from weekprofile device name and topic, you can decide with an optional third argument wheather existant content shall be kept (1) or overwritten (0) (default is 1=keep), or if there should be the weekprofile name as prefix in filenames.
  
  <br>
  Examples: 
  <ul>
   <code>{hm_copy_wpToHMInfo('weekprofiles','hm')}</code><br>
   <code>{hm_copy_wpToHMInfo('weekprofiles','hm',0)}</code><br>
   <code>{hm_copy_wpToHMInfo('weekprofiles','hm',0,0)}</code><br>

  </ul>
  </li>
</ul>
=end html
=cut
