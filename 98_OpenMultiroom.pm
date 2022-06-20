package main;
use strict;
use warnings;

my %OpenMultiroom_sets = (
    0              =>1,
    1              =>1,
    2              =>1,
    3              =>1,
    4              =>1,
    5              =>1,
    6              =>1,
    7              =>1,
    8              =>1,
    9              =>1,
    mute           =>2,
    volume         =>2,
    volumeUp       =>2,
    volumeDown     =>2,
    forward        =>3,
    rewind         =>3,
    next           =>3,
    previous       =>3,
    play           =>3,
    pause          =>3,
    toggle         =>3,
    stop           =>3,
    random         =>3,
    single         =>3,
    repeat         =>3,
    statesave      =>3,
    stateload      =>3,
    channelUp      =>3,
    channelDown    =>3,
    trackinfo      =>3,
    offtimer       =>2,
    stream         =>2,
    copystate      =>2,
    control        =>2,
    streamreset    =>2
);


sub OpenMultiroom_Initialize {
    my $hash = shift // return;
    $hash->{DefFn}      = \&OpenMultiroom_Define;
    $hash->{UndefFn}    = \&OpenMultiroom_Undef;
    $hash->{NotifyFn}   = \&OpenMultiroom_Notify;
    $hash->{SetFn}      = \&OpenMultiroom_Set;
    $hash->{AttrFn}     = \&OpenMultiroom_Attr;
    $hash->{NotifyOrderPrefix} = '80-'; 
    $hash->{AttrList} =
          'mrSystem:SNAPCAST soundSystem:MPD mr soundMapping ttsMapping defaultTts defaultStream defaultSound playlistPattern stateSaveDir seekStep seekDirect:percent,seconds seekStepSmall seekStepThreshold digitTimeout '
        . $readingFnAttributes;
    return;
}

sub OpenMultiroom_Define {
    my $hash = shift // return;
    my $def  = shift // return;
    my @arr  = split m{\s+}xms, $def;

    my $name = shift @arr;

    readingsSingleUpdate($hash,'state','defined',1);
    RemoveInternalTimer($hash);
    notifyRegexpChanged($hash,'',1);
    $attr{$name}{mrSystem}          = 'SNAPCAST' if !exists $attr{$name}{mrSystem};
    $attr{$name}{soundSystem}       = 'MPD'      if !exists $attr{$name}{soundSystem};
    $attr{$name}{seekStep}          = '7'        if !exists $attr{$name}{seekStep};
    $attr{$name}{seekDirect}        = 'percent'  if !exists $attr{$name}{seekDirect};
    $attr{$name}{seekStepSmall}     = '2'        if !exists $attr{$name}{seekStepSmall};
    $attr{$name}{seekStepThreshold} = '8'        if !exists $attr{$name}{seekStepThreshold};
    Log3($name,5,'MAC DEFINED');
    return;
}

sub OpenMultiroom_Attr {
    my $cmd  = shift;
    my $name = shift;
    my $attr = shift // return;
    my $value = shift;
    my $hash = $defs{$name} // return;
    Log3($name,5,"$name Attr set: $attr, $value");
    if ($cmd eq 'set'){
        if ( $attr eq 'mr' ){
            #my $devsp = $value;
            #$devsp .= ",$hash->{SOUND}" if defined $hash->{SOUND} && $hash->{SOUND};
            #setNotifyDev($hash,$devsp);
            OpenMultiroom_setNotifyDef($hash,$value);
            OpenMultiroom_getReadings($hash,$value);
        }
        if($attr eq 'soundMapping'){
            $hash->{soundMapping}=$value;
            OpenMultiroom_setNotifyDef($hash);
        }
    }
    elsif ($cmd eq 'del'){
        if ( $attr eq 'mr' ){
            InternalTimer(gettimeofday(),\&OpenMultiroom_setNotifyDef, $hash, 0);
        }
    }
    my $out=toJSON($hash);
    Log3($name,5,$out);
    return;
}

sub OpenMultiroom_setNotifyDef {
    my $hash  = shift // return;
    my $name  = $hash->{NAME} // return;
    my $devsp = shift // AttrVal($name,'mr','');
    my $oldsound = $hash->{SOUND} // q{};
    if (!$init_done){
      InternalTimer(gettimeofday()+5,\&OpenMultiroom_setNotifyDef, $hash, 0);
      return; # 'init not done';
    }

    #$hash->{NOTIFYDEV}=AttrVal($name,"mr","undefined");
    #$devsp .= ",$hash->{SOUND}" if defined $hash->{SOUND} && $hash->{SOUND};
      
    my $sm = $hash->{soundMapping} // q{};
    my @soundMapping = split m{,}x,$sm;
    delete ($hash->{SOUND});
    for my $map (@soundMapping){
        my @mapping = split m{:}x,$map;
        $hash->{SOUND} = $mapping[1] if ReadingsVal($name,'stream','') eq $mapping[0];
    }
    OpenMultiroom_getReadings($hash,$hash->{SOUND}) if $hash->{SOUND} && $hash->{SOUND} ne $oldsound;
    $devsp .= ",$hash->{SOUND}" if defined $hash->{SOUND} && $hash->{SOUND};
    setNotifyDev($hash,$devsp);
    #$hash->{NOTIFYDEV} .= ",".$hash->{SOUND} if defined($hash->{SOUND}) and $hash->{SOUND} ne "";
    return;
}

sub OpenMultiroom_Undef {
    my $hash = shift // return;
    RemoveInternalTimer($hash);
    return;
}

sub OpenMultiroom_Notify {
    my $hash     = shift // return;
    my $dev_hash = shift // return;
    my $ownName  = $hash->{NAME} // return;

    return if IsDisabled($ownName); # Return without any further action if the module is disabled

    my $events = deviceEvents($dev_hash,1);
    return if !$events;

    my $updateFlag;
    my $devName  = $dev_hash->{NAME} // return;
    my $devType  = InternalVal($devName, 'TYPE','');

    readingsBeginUpdate($hash);
    for my $event (@{$events}) {
        next if !defined $event;
        my ($name,$value) = split m{:}x , $event;
        next if !defined $value;
        if ( $devType eq 'MPD' ){
            $name =~ s{volume}{sound_volume}x;
            $name =~ s{state}{sound_state}x;
        }
        if ( $devType eq 'Snapcast' ) {
            $name =~ s{state}{mr_state}x;
            $name =~ s{name}{mr_name}x;
            $updateFlag = 1 if $name eq 'stream';
        }

        readingsBulkUpdateIfChanged($hash,$name,$value );
        Log3($ownName,4,"$name got reading from $devName: $devType: $name|$value");
        # processing $event with further code
    }
    readingsEndUpdate($hash,1);
    OpenMultiroom_setNotifyDef($hash) if $updateFlag;
    Log3($ownName,5,"$ownName Notify_done");
    return;
}

sub OpenMultiroom_Set {
    my ($hash, @param) = @_;

    return '"set OpenMultiroom" needs at least one argument' if int @param < 2;
    my $name = shift @param;
    my $cmd = shift @param;
    my $val = shift @param;

    my $mrname=AttrVal($name,"mr","undefined");
    my $soundname = $hash->{SOUND} // '';
    if ( !defined $defs{$soundname} ) {
        OpenMultiroom_setNotifyDef($hash);
        $soundname = $hash->{SOUND} // '';
    }

    my $mrhash=$defs{$mrname};

    my $soundhash = $defs{$soundname} // '';

    my $soundtyp = AttrVal($name,'soundSystem','');
    my $soundModuleHash = $modules{$soundtyp};

    my @ttsmap = split m{,}x, AttrVal($name,'ttsMapping','');
    my $ttsname = '';
    for my $map (@ttsmap) {
        my ($stream,$tts) = split /\:/,$map;
        $ttsname = $tts if $stream eq ReadingsVal($name,'stream','');
    }
    readingsBeginUpdate($hash);
    readingsBulkUpdateIfChanged($hash,'tts',$ttsname);
    readingsEndUpdate($hash,1);

    if( !defined $OpenMultiroom_sets{$cmd} ) {
        my @cList = keys %OpenMultiroom_sets;
        return "Unknown argument $cmd, choose one of " . join(q{ }, @cList);
    }
    # clear:noArg clear_readings:noArg mpdCMD next:noArg outputenabled0:0,1 pause:noArg play playfile playlist previous:noArg random:noArg repeat:noArg reset:noArg single:noArg stop:noArg toggle:noArg updateDb:noArg volume:slider,0,1,100 volumeDown:noArg volumeUp:noArg
    return OpenMultiroom_Error($hash,'no sound backend connected or soundsystem not defined, check soundMapping and soundSystem attributes',1)
        if $OpenMultiroom_sets{$cmd}>2 && (!defined $soundhash || $soundhash eq '' || !defined $soundModuleHash || $soundModuleHash eq '');
    return OpenMultiroom_Error($hash,'no multiroom backend connected, check mr attribute',1) if $OpenMultiroom_sets{$cmd}>1 && (!defined $mrhash || $mrhash eq '');

    if ($cmd=~/^\d$/){ # is the command 1 digit?
        # function called when a client presses a number on the remote. sets a timeout  and waits for the next number in case of multi digit numbers.
        # numbers are always entered by a client in preperation of a function like next, next playlist etc.
        RemoveInternalTimer($hash, \&OpenMultiroom_clearDigitBuffer);
        my $last = $hash->{lastdigittime}; # when was last digit received?
        my $now = time();
        my $timeout = AttrVal($name,'digitTimeout',10);
        $hash->{lastdigittime} = $now; # reset time for last digit
        if ( $now-$last < $timeout ) {
            $hash->{digitBuffer} = $hash->{digitBuffer} * 10 + $cmd;
        } else {
            $hash->{digitBuffer} = $cmd;
        }
        OpenMultiroom_TTS($hash,$hash->{digitBuffer} );
        InternalTimer(gettimeofday()+ AttrVal($name,'digitTimeout',10),\&OpenMultiroom_clearDigitBuffer, $hash, 0);
        return;
    }

    if ( $cmd eq 'play') {
        my $number = OpenMultiroom_getDigits($hash);
        if ( $number > 0 ){
            CallFn($soundname,'SetFn',$defs{$soundname},$soundname,$cmd,$number);
        }else{
            CallFn($soundname,'SetFn',$defs{$soundname},$soundname,$cmd);
        }
        return;
    }

    if ( $cmd eq 'pause' || $cmd eq 'toggle' || $cmd eq 'stop' || $cmd eq 'next' || $cmd eq 'previous' || $cmd eq 'random' || $cmd eq 'single' || $cmd eq 'repeat' ){
        CallFn($soundname,'SetFn',$defs{$soundname},$soundname,$cmd);
        return;
    }

    if( $cmd eq 'forward' || $cmd eq 'rewind' ) {
        my ($elapsed,$total) = split m{:}x, ReadingsVal($name,'time','');
        return if !defined $total;
        $total = int $total;
        return if !$total;
        my $percent = $elapsed / $total;
        my $number = OpenMultiroom_getDigits($hash);
        if ( $number > 0 ){
            $percent = 0.01*$number;
        } else {
             my $step = 0.01*(0.01*AttrVal($name,'seekStepThreshold',0) > $percent ? AttrVal($name,'seekStepSmall',3) : AttrVal($name,'seekStep',7));
             $percent +=$step if $cmd eq 'forward';
             $percent -=$step if $cmd eq 'rewind';
        }
        $percent = 0    if $percent < 0;
        $percent = 0.99 if $percent > 0.99;
        my $new = $percent*$total;
        my $newint = int $new;
        CallFn($soundname,'SetFn',$defs{$soundname},$soundname,'seekcur',$newint);
        return;
    }

    if ( $cmd eq 'channelUp' || $cmd eq 'channelDown' ){ # next playlist or specific playlist if number was entered before
        # get lists based on regexp. Seperate those playlists that have a 2 or 3 digit number in them.
        my $filter = AttrVal($name,'playlistPattern','.*');
        my @allPlaylists = split m{:}x,ReadingsVal($name,'playlistcollection','');
        my @filteredPlaylists = grep { /$filter/ } @allPlaylists;
        return 'no playlists found' if !@filteredPlaylists;
        my @filteredPlaylistsWithNumbers = grep { /\d{2,3}/ }  @filteredPlaylists;
        my @filteredPlaylistsWithoutNumbers = grep { !/\d{2,3}/ }  @filteredPlaylists;

        # delete existing playlist array and crate a reference to an empty array to pupulate it afterwards
        delete $hash->{PLARRAY};
        $hash->{PLARRAY}=[];
        # iterate the items with a number first, to try to put the to the slot according to their number. 
        for my $item (@filteredPlaylistsWithNumbers){
            # for each one push it to the according position. pushPlArray will ensure no slot is used twice and increase accordingly
            $item=~/(\d{2,3})/;
            OpenMultiroom_pushPlArray($hash,$item,$1);
        }
        # do the same for the other items and push them into the array
        for my $item (@filteredPlaylistsWithoutNumbers){
            OpenMultiroom_pushPlArray($hash,$item);
        }
        # next 3 lines, build an array of pl numbers, get the number of the current one and its index in the index array. This could probably be done better. 
        my $mpdplaylist = $soundhash->{'.playlist'} // '';
        my (@indexes) = grep { defined(${$hash->{PLARRAY}}[$_]) } (0 .. @{$hash->{PLARRAY}});
        my ($current) = grep { ${$hash->{PLARRAY}}[$_] eq $mpdplaylist } (0 .. @{$hash->{PLARRAY}});
        my ($currentindex) = grep { defined($current) && defined($indexes[$_]) && $indexes[$_] eq $current } (0 .. @indexes-1);

        my $number = OpenMultiroom_getDigits($hash);
        if ( $number > 0 && $number < @indexes ){
            $currentindex = $number;
        } else {
            # for next or prev, just increase the number or decrease the number based on $cmd, call getPlName(number)
            if ( $cmd eq 'channelUp'){
                $currentindex =  !defined $currentindex || $currentindex == @indexes-1 ? 0 : $currentindex+1;
            }
            if($cmd eq 'channelDown'){
                $currentindex = !defined $currentindex || $currentindex == 0 ? @indexes-1 : $currentindex-1;
            }
        }
        # load the playlist
        CallFn($soundname,'SetFn',$defs{$soundname},$soundname,'playlist',${$hash->{PLARRAY}}[$indexes[$currentindex]]);
        Log3($name,4,"$name: CallFn $soundname, SetFn, ".$defs{$soundname}.", $soundname, playlist, ".${$hash->{PLARRAY}}[$indexes[$currentindex]]);
        readingsSingleUpdate($hash,'playlistnumber',$indexes[$currentindex],1);
        OpenMultiroom_TTS($hash,$indexes[$currentindex]);
        CallFn($soundname,'SetFn',$defs{$soundname},$soundname,'play');       

        return;
    }

    if ( $cmd eq 'volume' ) {
        my $number = OpenMultiroom_getDigits($hash);
        if ( $number > 0 ) {
            $val = $number;
            $val = 100 if $val > 100;
        }
        CallFn($mrname,'SetFn',$defs{$mrname},$mrname,'volume',$val);
        return;
    }

    if ( $cmd eq 'volumeUp' ) {
        CallFn($mrname,'SetFn',$defs{$mrname},$mrname,'volume','up');
        return;
    }
    if ( $cmd eq 'volumeDown' ) {
        CallFn($mrname,'SetFn',$defs{$mrname},$mrname,'volume','down');
        return;
    }
    if ( $cmd eq 'mute') {
        CallFn($mrname,'SetFn',$defs{$mrname},$mrname,'mute',$val);
        return;
    }

    if ( $cmd eq 'stream' ) {
        my $targetStream = $val // 'next';
        CallFn($mrname,'SetFn',$defs{$mrname},$mrname,'stream',$targetStream);
        return;
    }

    if($cmd eq "copystate"){
        return OpenMultiroom_Error($hash,"$cmd not yet implemented",2) ;
        my $defaultstream = AttrVal($name,"defaultStream","");
        return undef if $defaultstream eq "";
        CallFn($mrname,"SetFn",$defs{$mrname},$mrname,"stream",$defaultstream);
        return undef;
    }

    if($cmd eq "control"){
        return OpenMultiroom_Error($hash,"$cmd not yet implemented",2) ;
        my $defaultstream = AttrVal($name,"defaultStream","");
        return undef if $defaultstream eq "";
        CallFn($mrname,"SetFn",$defs{$mrname},$mrname,"stream",$defaultstream);
        return undef;
    }
    if($cmd eq "streamreset"){
        return OpenMultiroom_Error($hash,"$cmd not yet implemented",2) ;
        my $defaultstream = AttrVal($name,'defaultStream',undef) // return;
        CallFn($mrname,"SetFn",$defs{$mrname},$mrname,"stream",$defaultstream);
        return undef;
    }

    return OpenMultiroom_Error($hash,"$cmd not yet implemented",2) ;
}

sub OpenMultiroom_pushPlArray{
    my $hash   = shift // return;
    my $item   = shift // return;
    my $number = shift // 1;
    my $name = $hash->{NAME} // return;
    while ( defined ${$hash->{PLARRAY}}[$number] ){
        $number++;
    }
    ${$hash->{PLARRAY}}[$number] = $item;
    $hash->{CURRENTPL} = $number if ReadingsVal($name,'playlistname','') eq $item;
    return $number;
}

sub OpenMultiroom_Error { # hier noch TTS feedback einbauen je nach errorlevel
    my $hash  = shift // return;
    my $msg   = shift // return;
    my $level = shift // 3;
    return $msg;
}

 sub OpenMultiroom_getReadings{
    my $hash   = shift // return;
    my $device = shift // return;
    
    my $name = $hash->{NAME} // return;
    if (!$init_done){
      InternalTimer(gettimeofday()+10,"OpenMultiroom_getReadings", $hash, $device);
      return; # "init not done";
    }
    my $modhash  = $defs{$device} // return;
    my $readings = $modhash->{READINGS};
    my $devType  = InternalVal($device,'TYPE',undef) // return;
    my $updateFlag = 0;
    Log3($name,4,"$name getting readings from $device");
    readingsBeginUpdate($hash);
    while ( my ($key, $value) = each %{$readings} ) {
        if ( $devType eq 'MPD' ){
            $key =~ s{volume}{sound_volume}x;
            $key =~ s{state}{sound_state}x;
        }
        if ( $devType eq 'Snapcast' ) {
            $key =~ s{state}{mr_state}x;
            $key =~ s{name}{mr_name}x;
            $updateFlag = 1 if $key eq 'stream';
        }
        readingsBulkUpdateIfChanged($hash,$key,$value->{VAL} );
        Log3($name,5,"$name getReading got reading $key from $device, ".$value->{VAL});
    }
    readingsEndUpdate($hash,1);
    OpenMultiroom_setNotifyDef($hash) if $updateFlag;
    if ( ReadingsVal($name,'stream','') eq '' && $device eq AttrVal($name,'mr','') ) {
        InternalTimer(gettimeofday()+10,\&OpenMultiroom_getReadings, $hash, $device);
    }
    return;
 }

sub OpenMultiroom_clearDigitBuffer {
    my $hash = shift // return;
    #my $name = $hash->{NAME};
    $hash->{digitBuffer} = 0;
    OpenMultiroom_TTS($hash,':NACK1:');
    return;
}

sub OpenMultiroom_getDigits {
    my $hash = shift // return;
    my $name = $hash->{NAME} // return;;
    my $buf = $hash->{digitBuffer};
    RemoveInternalTimer($hash, \&OpenMultiroom_clearDigitBuffer);
    $hash->{digitBuffer} = 0;
    return $buf;
}

sub OpenMultiroom_TTS {
    my $hash  = shift // return;
    my $value = shift // return;
    my $name = $hash->{NAME} // return;
    my $ttsname = ReadingsVal($name,'tts','');
    return if !defined $defs{$ttsname};
    CallFn($ttsname,'SetFn',$defs{$ttsname},$ttsname,'tts',$value);
    return;
}

__END__

=pod

=encoding utf8
=item summary    integrate MPD and Snapcast into a Multiroom
=begin html

<a id="OpenMultiroom"></a>
<h3>OpenMultiroom</h3>
<ul>
    <i>OpenMultiroom</i> is a module that integrates the functions of an audio player module and a multiroom module into one module, giving one interface with one set of readings and set-commands. Currently it supports the <a href="#MPD">MPD module</a> as sound backend and the <a href="#Snapcast">Snapcast module</a> as multiroom backend. Optionally a <a href="#Text2Speech">Text2Speech module</a> can be attached on top to enable audio-feedback on userinteraction, which makes most sense if used in a headless environment. OpenMultiroom is specificallz optimized to be used just with a remote control without a display, but its interface also allows to be used with common frontends such as TabletUI or SmartVISU. A comprehensive introcuction into how to use and configure this module and the associated modules and software services is given in the <a href="http://www.fhemwiki.de/wiki/OpenMultiroom">Wiki</a> (german only). 
    <a id="OpenMultiroom-define"></a>
    <b>Define</b>
    <ul>
        <code>define <name> OpenMultiroom</code>
        <br><br>
        There are no other arguments during define. The configuration is done only with attributes.
    </ul>
    <br>
    <a id="OpenMultiroom-set"></a>
    <h4>Set</h4>
    <ul>
        The OpenMultiroom module mirrors many set functions from the connected sound backened and multiroom backend. Some sets are modified, some are added. 
        <code>set &lt;name&gt; &lt;function&gt; &lt;value&gt;</code>
        <br><br>
        Options:
        <ul>
              <li><i>0...9</i><br>
                  Any single digit. This is useful to connect the digits on a IR or radio remote to this module. The module has a memory of digits "pressed". Whenever more digits are pressed within the timeout(Attribute <i>digitTimeout</i>) the digits are chained together to a number, similar to changing a channel on a TV with numbers on a remote. If afterwards one of the functions that can be controled with numbers is used, the number will be used as argument to it, e.g. for skipping to a track with a specific number. If the timeout occurs before that, the number memory is set to 0 and optionally a configurable NACK-Sound is played. (configured in associated TTS-Module)</li>
              <li><i>play</i><br>
                  play is forwarded to the sound backend. If a number is entered before, it will skip to the track with that number.</li>
              <li><i>pause</i><br>
                  pause just pauses the sound backend</li>
              <li><i>toggle</i><br>
                  toggles between play and pause in the sound backend</li>
              <li><i>stop</i><br>
                  stops the sound backend</li>
              <li><i>next / previous</i><br>
                  Skips to the next or previous track in the sound backend</li>
              <li><i>forward / rewind</i><br>
                  jump forward or backward in the current track as far as defined in the Attributes <i>seekStep</i>, <i>seekStepSmall</i> and <i>seekStepThreshold</i>, default 7%<br>
                  If a number is entered before, skips to the given position either in seconds or in percent, depending on Attribute <i>seekDirect</i><</li>
              <li><i>random, single, repeat</i><br>
                  Those commands are just forwarded to the sound backend and change its behavior accordingly.</li>
              <li><i>channelUp / channelDown / channel (number)</i><br>
                  loads the next or previous playlist in the sound backend. To determine what is the next or previous playlist the module uses the attribute <i>playlistPattern</i> which is applied as regular expression filter to the list of playlists available. On top of that the module sorts the playlist in a way, that those playlists that have a number in its name are available on exactly that position in the list. This way a playlist can be named with a certain number and is then later available through this module by entering that number with the digits of a remote and then using the channel or channelUp command. If there is more than one playlist with the same number in its name, it will be sorted into the list at the next free number slot</li>
               <li><i>volume [number]</i><br>
                  sets the volume of the multiroom backend, either by giving volume as a parameter, or by entering a number with digits before using this command.</li>                 
               <li><i>volup / voldown</i><br>
                  uses the volup or voldown command of the multiroom backend to change the volume in configurable steps</li>  
               <li><i>mute [true|false]</i><br>
                  mutes or unmutes the multiroom backend using the true or false option. Without option given, toggles the mute status</li>
               <li><i>stream [streamname]</i><br>
                  changes the stream to which the module is listening to in the multiroom backend. Without argument, it just switches to the next stream, or with argument, to the stream with the given name. A change of stream also leads to a situation, where the module is connected to a different instance of the sound backend and therefore all readings of the sound backend will be updated with those from the new sound backend. The new sound backend is determined based on the attribute <i>soundMapping</i>. This also means, that the module is always in control of the sound backend instance that it is listening to.</li>
        </ul>
</ul>
 <br><br>
  <a id="OpenMultiroom-attr"></a>
  <h4>Attributes</h4>
  <ul>
    The following attributes change the behavior of the module. Without the attributes <i>mr</i> and <i>soundMapping</i>, the module cannot be used in a meaningful way.
    <li>mrSystem (Default: Snapcast)<br>
      The type of the multiroom backend module. Currently only Snapcast is supported.
    </li>
        <li>soundSystem (Default: MPD)<br>
    The type of the sound backend module. Currently only MPD is supported.
    </li>
        <li>mr<br>
    The name of the multiroom backend definition. For Snapcast, this must be the name of a snapcast module in client mode.  
    </li>
        <li>soundMapping<br>
    The mapping of the multiroom streams to the sound players. For Snapcast and MPD it defines, which MPD modules are playing on which snapcast streams. Check the WIKI for a comprehensive example. 
    <pre>attr &lt;name&gt; soundMapping stream1:mpd.room1,stream2:mpd.stream2</pre>
    </li>
        <li>ttsMapping<br>
    If Text2Speech is used, this maps the defined Text2Speech modules to the associated Multiroom-System-Streams. 
     <pre>attr &lt;name&gt; ttsMapping stream1:tts.room1,stream2:tts.stream2</pre>
    </li>
        <li>defaultTts<br>
    defines what is the default tts module to use. Requires a name of a Text2Speech module. 
    </li>
        <li>defaultStream<br>
    Name of the default stream of this module. This is used for a reset function (not yet implemented)
    </li>
        <li>defaultSound<br>
    Name of the default sound backend of this module. This is used for a reset function (not yet implemented)
    </li>
        <li>playlistPattern<br>
    Regular expression to filter the playlists used by the channel, channelUp and channelDown commands.
    </li>
        <li>seekStep (Default: 7)<br>
    set this to define how far the forward and rewind commands jump in the current track. Defaults to 7 if not set 
    </li>
        <li>seekStepSmall (Default: 2)<br>
     set this on top of seekStep to define a smaller step size, if the current playing position is below seekStepThreshold percent. This is useful to skip intro music, e.g. in radio plays or audiobooks. 
    </li>
        <li>seekStepThreshold (Default: 8)<br>
    used to define when seekStep or seekStepSmall is applied. Defaults to 0. If set e.g. to 10, then during the first 10% of a track, forward and rewind are using the seekStepSmall value.
    </li>
        <li>digitTimeout<br>
    Time within digits can be entered and chained to a multi-digit number before the digit memory is set to 0 again. 
    </li>
  </ul>
</ul>


=end html