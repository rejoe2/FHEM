###############################################################################
#
# $Id: 33_readingsChange2.pm 25035 2021-10-13 Beta-User $
#
###############################################################################


package FHEM::readingsChange2; ##no critic qw(Package)

use strict;
use warnings;
use Carp qw(carp);

use GPUtils qw(:all);

my %sets = (
);

my %gets = (
#  "version"   => "noArg",
#  "devlist"   => "",
#  "devinfo"   => "",
#  "refreshUserAttr" => "noArg"
);

BEGIN {

  GP_Import(qw(
    CommandAttr
    readingsSingleUpdate
    readingsBeginUpdate
    readingsBulkUpdate
    readingsEndUpdate
    Log3
    defs
    attr
    init_done
    readingFnAttributes
    AttrVal
    ReadingsVal
    InternalVal
    deviceEvents
    addToDevAttrList
    delFromDevAttrList
    devspec2array
    perlSyntaxCheck
    AnalyzePerlCommand
    notifyRegexpChanged
    gettimeofday
    TimeNow
    InternalTimer
    RemoveInternalTimer
  ))

};

sub ::readingsChange2_Initialize { goto &Initialize }

sub Initialize {
    my $hash = shift // return;

    # Consumer
    $hash->{DefFn}    = \&Define;
    $hash->{UndefFn}  = \&Undefine;
    $hash->{GetFn}    = \&Get;
    $hash->{NotifyFn} = \&Notify;
    $hash->{AttrFn}   = \&Attr;

    $hash->{AttrList} =
    "disable:1,0 debug:0,1 $readingFnAttributes";
    $hash->{NotifyOrderPrefix} = '01-'; #be almost first to be notified
    return;
}

sub  trim { my $s = shift; $s =~ s{\A\s+|\s+\z}{}gx; return $s }

###############################################################################
# Device define
sub Define {
    my $hash = shift;
    my $def  = shift // return;

    # Definition :=> defmod rChange2 readingsChange2 [devspec,[devspec]]
    my($name, $type, @devspeca) = split m{\s+}x, $def;
    my ($n) = devspec2array('TYPE=readingsChange2');
    return "Only one instance of readingsChange2 allowed. You may change devspec of $n instead."
        if $n && $name ne $n;

    # restlichen Parameter nach Leerzeichen trennen
    # aus dem Array einen kommagetrennten String erstellen
    my $devspec = (@devspeca) ? join q{,}, @devspeca : q{.*};
    # Doppelte Kommas entfernen.
    $devspec =~s{,+}{,}gx;
    # damit ist jetzt Trennung der zu ueberwachenden Geraete mit Kommas, Leezeichen, Kommas mit Leerzeichen und Mischung davon moeglich

    my $olddevspec = $hash->{DEVSPEC};
    $hash->{DEVSPEC} = $devspec;

    my $newdevspec = initUserAttr($hash);
    removeOldUserAttr($hash,$olddevspec,$newdevspec) if defined $olddevspec;

    InternalTimer(1, \&firstInit, $hash);

    return;
}

# Device undefine
sub Undefine {
    my $hash = shift // return;
    RemoveInternalTimer($hash);
    return removeOldUserAttr($hash);
}

# erstellt / loescht die notwendigen userattr-Werte (die Steuerattribute an den Geraeten laut devspec)
sub refreshUserAttr {
  my $hash = shift // return;
  my $olddevspec = $hash->{DEVSPEC};
  my $newdevspec = initUserAttr($hash);
  removeOldUserAttr($hash,$olddevspec,$newdevspec) if defined $olddevspec;
  return;
}

# Fuegt notwendige UserAttr hinzu
sub initUserAttr {
  my $hash = shift // return;
  my $devspec = $hash->{DEVSPEC};
  $devspec = 'global' if $devspec eq '.*'; # use global, if all devices observed
  my @devices = devspec2array($devspec);
  for (@devices) {
    addToDevAttrList($_, 'readingsChange2:textField-long', 'readingsChange2');
  }
  return \@devices;
}

# Erstinitialization. 
# Variablen werden im HASH abgelegt, userattr der betroffenen Geraete wird erweitert, MQTT-Initialisierungen.
sub firstInit {
    my $hash = shift // return;

    return InternalTimer(1, \&firstInit, $hash) if !$init_done;
    $hash->{helper}->{INITIALIZED} = 0;
    # tabelle aufbauen
    $hash->{ERRORS} = CreateDevicesTable($hash);
    RemoveInternalTimer($hash);
    $hash->{helper}->{INITIALIZED} = 1;
    my $nRC = join q{|}, ('global',devspec2array($hash->{DEVSPEC}));
    notifyRegexpChanged($hash,$nRC);
    return;
}

# Berechnet Anzahl der ueberwachten Geraete neu
sub updateDevCount {
    my $hash = shift // return;
    # device count
    my $size = scalar keys %{$hash->{helper}->{DEVICES}};
    $hash->{helper}->{DEVICE_CNT} = $size;
    return readingsSingleUpdate($hash,'device-count',$size,1);
}

sub removeOldUserAttr { 
    my $hash       = shift // return;
    my $devspec    = shift // $hash->{DEVSPEC};
    my $newDevices = shift; #optional, may shorten procedure if given

    $devspec = 'global' if $devspec eq '.*';
    my @devices = devspec2array($devspec);

    for my $dev (@devices) {
        next if grep {$_ eq $dev} @{$newDevices};
        my $ua = $attr{$dev}{userattr};
        if (defined $ua) {
            my %h = map { ($_ => 1) } split q{ }, $ua;
            delete $h{'readingsChange2:textField-long'};
            if(!keys %h && defined($attr{$dev}{userattr})) {
                # ganz loeschen, wenn nichts mehr drin
                delete $attr{$dev}{userattr};
            } else {
                $attr{$dev}{userattr} = join q{ }, sort keys %h;
            }
        }
    }
    return;
}

# Internal map for all readings and replacements for all devices
sub CreateSingleDeviceTable { 
    # my ($hash, $dev, $map) = @_;
    my $hash       = shift // return;
    my $dev        = shift // carp q[No device name provided!] && return;
    my $map        = shift // carp q[No map arg provided!]     && return;
    # Device-Attribute fuer ein bestimmtes Device aus Device-Attributen auslesen

    my @errors;
    my @lines = split m{\n}x, AttrVal($dev, 'readingsChange2', q{});
    for my $line (@lines) {
        trim($line);
        next if $line eq '';
        my ($rdg, $regexp, $expr) = split m{\s+}x, $line, 3;
        if (!$regexp) {
            push @errors, "no replacement argument provided in attr readingsChange2 for $dev in line $line";
            next;
        } elsif (!$expr && $regexp !~ m<\A\{.+}\s*\z>) {
            push @errors, "no Perl replacement or not 3 arguments provided in attr readingsChange2 for $dev in line $line";
            next;
        } elsif ( $regexp =~ m<\A\{.+> ) {
            $regexp = join q{ }, ($regexp, $expr);
            $expr = undef;
            if ( $regexp !~ m<\A\{.+}\z> ) {
                push @errors, "no regex as second argument provided in attr readingsChange2 for $dev in $line";
                next;
            }
        } elsif ( $regexp !~ m{\(.+\)} ) {
            $regexp = join q{ }, ($regexp, $expr); #might be Perl only with spaces
            $expr = undef;
            if ( $regexp !~ m<\A\{.+}\z> ) {
                push @errors, "no regex as second argument provided in attr readingsChange2 for $dev in $line";
                next;
            }
        }
        if (!$expr ) { #$regexp is Perl command
            my $schk = perlSyntaxCheck( $regexp );
            if ( $schk ) {
                push @errors, "invalid Perl syntax in attr readingsChange2 for $dev in $line: $schk";
                delete $map->{$dev}->{$rdg};
                next;
            }
            $map->{$dev}->{$rdg}->{perl} = $regexp;
            next; 
        }
        $map->{$dev}->{$rdg}->{regexp} = $regexp;
        if ( $expr =~ m<\A\{.+}\z> ) {
            my $schk = perlSyntaxCheck( $expr );
            if ( $schk ) {
                push @errors, "invalid Perl syntax in attr readingsChange2 for $dev in line $line: $schk";
                delete $map->{$dev}->{$rdg};
                next;
            }
            $map->{$dev}->{$rdg}->{perl} = $expr;
        } else {
            $map->{$dev}->{$rdg}->{repl} = $expr;
        }
    }

    delete $map->{$dev} if keys %{$map->{$dev}} == 0;

    if ( $hash->{helper}->{INITIALIZED} ) {
        my $nRC = join q{|}, ('global',devspec2array($hash->{DEVSPEC}));
        notifyRegexpChanged($hash,$nRC);
    }

    if (@errors) {
        my $ret = "$hash->{NAME}: errors in parsing attributes - " . join q{ ---- }, @errors;
        #Log3($hash, 2, "$ret");
        my $hash->{ERRORS} = $ret if $hash->{helper}->{INITIALIZED};
        return $ret;
    }

    return 
}


# Geraet-Infos neu einlesen
sub RefreshDeviceTable { 
    my $hash     = shift // return;
    my $dev      = shift // carp q[No device name provided!] && return;
    my $attrName = shift // 'readingsChange2';
    my $attrVal  = shift;
    my $map = $hash->{helper}->{DEVICES};
    my $err = CreateSingleDeviceTable($hash, $dev, $map);
    delete $map->{$dev} if !defined $attrVal && keys %{$map->{$dev}} == 0;
    return $err;
}

# Geraet umbenennen, wird aufgerufen, wenn ein Geraet in FHEM umbenannt wird
sub RenameDeviceInTable {
    my $hash   = shift // return;
    my $dev    = shift // carp q[No device name provided!] && return;
    my $devNew = shift // carp q[No new device name provided!] && return;

    my $map = $hash->{helper}->{DEVICES};

    return if !defined $map->{$dev};

    delete $map->{$dev};
    return CreateSingleDeviceTable($hash, $devNew, $map);
}

# Geraet loeschen (geloescht in FHEM)
sub DeleteDeviceInTable {
    my $hash = shift // return;
    my $dev  = shift // carp q[No device name provided!] && return;
    my $map = $hash->{helper}->{DEVICES};

    return if !defined $map->{$dev};
    delete($map->{$dev});
    my $nRC = join q{|}, ('global',devspec2array($hash->{DEVSPEC}));
    notifyRegexpChanged($hash,$nRC);
    return;
}

# alle zu ueberwachende Geraete durchsuchen und relevanter Informationen einlesen
sub CreateDevicesTable {
    my $hash = shift // return;
    # alle zu ueberwachende Geraete durchgehen und Attribute erfassen
    my $map={};
    $hash->{helper}->{DEVICES} = $map;
    my @errors;
    my $err;
    for my $dev (devspec2array($hash->{DEVSPEC})) {
        $err = CreateSingleDeviceTable($hash, $dev, $map) if $dev ne $hash->{NAME}; 
        push @errors, $err if $err;
    }
    $hash->{helper}->{DEVICES} = $map;
    return if !@errors;
    $err = join q{ ------- }, @errors;
    Log3($hash, 2, "$err");
    return $err;
}

# Falls noetig, Geraete initialisieren
sub CheckInitialization {
  my $hash = shift // return;
  # Pruefen, on interne Strukturen initialisiert sind
  return if $hash->{helper}->{INITIALIZED};
  return CreateDevicesTable($hash);
}


# Routine fuer FHEM Get-Commando
sub Get { 
    my $hash    = shift // return;
    my $name    = shift;
    my $command = shift // return "Need at least one parameters";
    my $args    = shift;
    #Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE:DEBUG:> [$hash->{NAME}] get CL: ".Dumper($hash->{CL}));
    #return "Need at least one parameters" unless (defined $command);
    if (!defined $gets{$command} ) {
        my $rstr="Unknown argument $command, choose one of";
        for my $vname (keys %gets) {
            $rstr.=" $vname";
            my $vval=$gets{$vname};
            $rstr.=":$vval" if $vval;
        }
        return $rstr;
    }

    my $clientIsWeb = 0;
    if(defined($hash->{CL})) {
        my $clType = $hash->{CL}->{TYPE};
        $clientIsWeb = 1 if (defined($clType) and ($clType eq 'FHEMWEB'));
    }

    if ($command eq 'devlist') {
      my $res= q{};
      for my $dname (sort keys %{$hash->{helper}->{DEVICES}}) {
          if($args) {
              next if $dname !~ m{\A$args\z}x;
          }
          $res.= "${dname}\n";
      }
      return 'no devices found' if $res eq '';
      return $res;
    }

    if ($command eq "devinfo") {
      return getDevInfo($hash,$args);;
    }

    if ($command eq "refreshUserAttr") {
      return refreshUserAttr($hash);
    }

    return;
}

sub getDevInfo {
    my $hash = shift // return;
    my $args = shift;
    
    return;
}


# Routine fuer FHEM Notify
sub Notify {
    my $hash = shift // return;
    my $dev  = shift // carp q[No device hash provided!] && return;

    return checkDeviceReadingsUpdates($hash, $dev) if $dev->{NAME} ne 'global';

    # FHEM (re)Start
    firstInit($hash) if grep { m{\A(INITIALIZED|REREADCFG)\z}x } @{$dev->{CHANGED}};

    # Aenderungen der Steuerattributen in den ueberwachten Geraeten tracken
    my $max = int(@{$dev->{CHANGED}})-1;
    for my $i (0..$max) {
        my $s = $dev->{CHANGED}[$i];
        $s = q{} if !defined $s;
        # tab, CR, LF durch spaces ersetzen
        $s =~ s{[\r\n\t]}{ }gx;

        # Device renamed
        if ( $s =~ m{\ARENAMED\s+([\S]+)\s+([\S]+)\z}x ) {
            my ($old, $new) = ($1, $2);
            # wenn ein ueberwachtes device, tabelle korrigieren
            RenameDeviceInTable($hash, $old, $new);
            next;
        } 

        # Device deleted
        if($s =~ m{\ADELETED\s+([\S]+)\z}x) {
            my $name = $1;
            DeleteDeviceInTable($hash, $name);
            next;
        }

        # Attribut created or changed
        if($s =~ m{\AATTR\s+([\S]+)\s+(readingsChange2)\s+(.*)\z}x) {
            my ($sdev, $attrName, $val) = ($1, $2, $3);
            next if $attrName ne 'readingsChange2';
            RefreshDeviceTable($hash, $sdev, $attrName, $val);
            next;
        }

        # Attribut deleted
        if($s =~ m{\ADELETEATTR\s+([\S]+)\s+readingsChange2\z}x) {
            RefreshDeviceTable($hash, $1, 'readingsChange2', undef);
            next;
        }
    }
    return;
}


# Pruefen, ob in dem Device Readings-Aenderungen vorliegen, die vergeändert werden sollen 
sub checkDeviceReadingsUpdates {
    my $hash = shift // return;
    my $dev  = shift // carp q[No monitored device hash provided!] && return;

    # nicht waehrend FHEM startet
    return if !$init_done ;

    # nicht, wenn deaktivert
    return '' if(::IsDisabled($hash->{NAME}));
    my $devName = $dev->{NAME}                  // return; 
    my $devDataTab = $hash->{helper}->{DEVICES} // return; # Geraetetabelle
    my $devDataRecord = $devDataTab->{$devName} // return; 

    my $changed;
    my $events = deviceEvents($dev,1);
    return if !$events;
  
    for my $i (0..@{$events}-1) {
        my $event = $events->[$i];
        my $newval;
        $event =~ m{\A(?<dev>[^:]+)(?<devr>:\s)?(?<devrv>.*)\z}smx; # Schalter /sm ist wichtig! Sonst wir bei mehrzeiligen Texten Ende nicht korrekt erkannt. s. https://perldoc.perl.org/perlretut.html#Using-regular-expressions-in-Perl 
        my $devreading = $+{dev};
        my $devval = $+{devrv};

        # Sonderlocke fuer 'state' in einigen Faellen: z.B. bei ReadingsProxy kommt in CHANGEDWITHSTATE nichts an, und in CHANGE, wie gehabt, z.B. 'off'
        if(!$+{devr}) {
            $devval = $event;
            $devreading = 'state';
        }

        next if !defined $devreading || !defined $devval;
        next if !defined $dev->{READINGS}{$devreading});
        $newval = checkDeviceUpdate($hash, $dev, $devreading, $devval);
        next if !defined $newval;
        $changed++;
        $dev->{READINGS}{$devreading}{VAL} = $newval;
        $events->[$i] = "$devreading: $newval";
    }
    evalStateFormat($devName) if $changed;
    return;
}

sub checkDeviceUpdate {
    my $hash    = shift // return;
    my $devHash = shift // carp q[No hash for target device provided!] && return;
    my $reading = shift // carp q[No reading provided!] && return;
    my $value   = shift // q{\0} ; # TODO: pruefen: oder doch ""?;
    my $i       = shift

    my $devn = $devHash->{NAME};
    my $devDataRecord = $hash->{helper}->{DEVICES}->{$devn} // return; 
    my $readRepl      = $devDataRecord->{$reading)}         // return;
    
    my $regexp = $readRepl->{regexp}; 
    my $pcode  = $readRepl->{perl}; 
    my $expr   = $readRepl->{repl};
    my $result;
    my $changed;
    if (defined $regexp) {
        defined $pcode ?
            $pcode =~ s{$regexp}{$pcode}g
          : $expr  =~ s{$regexp}{$expr}g;
    } 
    
    #simple reading
    return $expr if defined $expr;

    my %specials = (
                    '$name'  => $devn
                       );
    for my $key (keys %specials) {
        my $val = $specials{$key};
        $pcode =~ s{\Q$key\E}{$val}gxms;
    }
    $result = AnalyzePerlCommand( $hash, $pcode );
    Log3( $hash, 5, "[$hash-{NAME}] result of Perl code: $result" );
    
    return $result if ref $result eq 'SCALAR';
    return if ref $result ne 'HASH';
    
    readingsBeginUpdate($hash);
    for my $k (keys %{$result}) {
        next if $k eq $reading;
        readingsBulkUpdate($devHash,$k,$result->{$k});
    }
    readingsEndUpdate($devHash,1);
    return $result->{$reading};
}


# Routine fuer FHEM Attr
sub Attr {
  my ($command,$name,$attribute,$value) = @_;

  my $hash = $defs{$name} // return;

  return;
}

1;

__END__

=pod
=encoding utf8

=item helper
=item summary    modify reading value(s) upon change
=item summary_DE Reading-Werte modifizieren bei Änderung(en)

=begin html

<a id="readingsChange2"></a>
 <h3>readingsChange2</h3>
 <ul>
 <p>
        This module is a MQTT bridge, which simultaneously collects data from several FHEM devices
        and passes their readings via MQTT, sets readings from incoming MQTT messages or executes incoming messages
       as a 'set' command for the configured FHEM device.
     <br/>One for the device types could serve as IODev: <a href="#MQTT">MQTT</a>,
     <a href="#MQTT2_CLIENT">MQTT2_CLIENT</a> or <a href="#MQTT2_SERVER">MQTT2_SERVER</a>.
 </p>
 <p>The (minimal) configuration of the bridge itself is basically very simple.</p>
 <a id="MQTT_GENERIC_BRIDGE-define"></a>
 <p><b>Definition:</b></p>
 <ul>
   <p>In the simplest case, two lines are enough:</p>
     <p><code>defmod mqttGeneric MQTT_GENERIC_BRIDGE [prefix] [devspec,[devspec]</br>
     attr mqttGeneric IODev <MQTT-Device></code></p>
   <p>All parameters in the define are optional.</p>
   <p>The first parameter is a prefix for the control attributes on which the devices to be 
       monitored (see above) are configured. Default value is 'mqtt'. 
       If this is e.g. redefined as <i>mqttGB1_</i>, the control attributes are named <i>mqttGB1_Publish</i> etc.
    </p>
   <p>The second parameter ('devspec') allows to minimize the number of devices to be monitored
      (otherwise all devices will be monitored, which may cost performance).
      Example for devspec: 'TYPE=dummy' or 'dummy1,dummy2'. Following the general rules for <a href="#devspec">devspec</a>, a comma separated list must not contain any whitespaces!</p>
 </ul>
 
 <a name="MQTT_GENERIC_BRIDGEget"></a>
 <p><b>get:</b></p>
 <ul>
   <li>
     <p>version<br/>
        Displays module version.</p>
   </li>
   <li>
     <p>devlist [&lt;name (regex)&gt;]<br/>
        Returns list of names of devices monitored by this bridge whose names correspond to the optional regular expression. 
        If no expression provided, all devices are listed.
     </p>
   </li>
   <li>
     <p>devinfo [&lt;name (regex)&gt;]<br/>
        Returns a list of monitored devices whose names correspond to the optional regular expression. 
        If no expression provided, all devices are listed. 
        In addition, the topics used in 'publish' and 'subscribe' are displayed including the corresponding read-in names.
    </p>
   </li>
 </ul>

 <a name="MQTT_GENERIC_BRIDGEreadings"></a>
 <p><b>readings:</b></p>
 <ul>
   <li>
     <p>device-count<br/>
        Number of monitored devices</p>
   </li>
   <li>
     <p>incoming-count<br/>
        Number of incoming messages</p>
   </li>
   <li>
     <p>outgoing-count<br/>
        Number of outgoing messages</p>
   </li>
   <li>
     <p>updated-reading-count<br/>
        Number of updated readings</p>
   </li>
   <li>
     <p>updated-set-count<br/>
        Number of executed 'set' commands</p>
   </li>
   <li>
     <p>transmission-state<br/>
        last transmission state</p>
   </li>
 </ul>

 <a name="MQTT_GENERIC_BRIDGEattr"></a>
 <p><b>Attributes:</b></p>
 <ul>
   <p><b>The MQTT_GENERIC_BRIDGE device itself</b> supports the following attributes:</p>
   <ul>
   <li><p>IODev<br/>
    This attribute is mandatory and must contain the name of a functioning MQTT-IO module instance. MQTT, MQTT2_CLIENT and MQTT2_SERVER are supported.</p>
   </li>

   <li>
     <p>disable<br/>
        Value '1' deactivates the bridge</p>
     <p>Example:<br>
       <code>attr &lt;dev&gt; disable 1</code>
     </p>
   </li>

   <li>
     <p>globalDefaults<br/>
        Defines defaults. These are used in the case where suitable values are not defined in the respective device.
        see <a href="#MQTT_GENERIC_BRIDGEmqttDefaults">mqttDefaults</a>. 
        <p>Example:<br>
        <code>attr &lt;dev&gt; sub:base=FHEM/set pub:base=FHEM</code>
     </p>
   </li>

   <li>
    <p>globalAlias<br/>
        Defines aliases. These are used in the case where suitable values are not defined in the respective device. 
        see <a href="#MQTT_GENERIC_BRIDGEmqttAlias">mqttAlias</a>.
     </p>
   </li>
   
   <li>
    <p>globalPublish<br/>
        Defines topics / flags for MQTT transmission. These are used if there are no suitable values in the respective device.
        see <a href="#MQTT_GENERIC_BRIDGEmqttPublish">mqttPublish</a>.
     </p>
     <p>Remark:<br>
        Setting this attribute will publish any reading value from any device matching the devspec. In most cases this may not be the intented behaviour, setting accurate attributes to the subordinated devices should be preferred.
     </p>
   </li>

   <li>
    <p>globalTypeExclude<br/>
        Defines (device) types and readings that should not be considered in the transmission.
        Values can be specified separately for each direction (publish or subscribe). Use prefixes 'pub:' and 'sub:' for this purpose.
        A single value means that a device is completely ignored (for all its readings and both directions). 
        Colon separated pairs are interpreted as '[sub:|pub:]Type:Reading'. 
        This means that the given reading is not transmitted on all devices of the given type. 
        An '*' instead of type or reading means that all readings of a device type or named readings are ignored on every device type.</p>
        <p>Example:<br/>
        <code>attr &lt;dev&gt; globalTypeExclude MQTT MQTT_GENERIC_BRIDGE:* MQTT_BRIDGE:transmission-state *:baseID</code></p>
   </li>

   <li>
    <p>globalDeviceExclude<br/>
        Defines device names and readings that should not be transferred. 
        Values can be specified separately for each direction (publish or subscribe). Use prefixes 'pub:' and 'sub:' for this purpose.
        A single value means that a device with that name is completely ignored (for all its readings and both directions).
        Colon-separated pairs are interpreted as '[sub:|pub:]Device:Reading'. 
        This means that the given reading is not transmitted to the given device.</p>
        <p>Example:<br/>
            <code>attr &lt;dev&gt; globalDeviceExclude Test Bridge:transmission-state</code></p>
   </li>
   
   <li>
       <a id="MQTT_GENERIC_BRIDGE-attr-forceNEXT"></a>forceNEXT<br/>
       <p>Only relevant for MQTT2_CLIENT or MQTT2_SERVER as IODev. If set to 1, MQTT_GENERIC_BRIDGE will forward incoming messages also to further client modules like MQTT2_DEVICE, even if the topic matches to one of the subscriptions of the controlled devices. By default, these messages will not be forwarded for better compability with autocreate feature on MQTT2_DEVICE. See also <a href="#MQTT2_CLIENT-attr-clientOrder">clientOrder attribute in MQTT2 IO-type commandrefs</a>; setting this in one instance of MQTT_GENERIC _BRIDGE might affect others, too.</p>
   </li>
   </ul>
   <br>

   <p><b>For the monitored devices</b>, a list of the possible attributes is automatically extended by several further entries. 
      Their names all start with the prefix previously defined in the bridge. These attributes are used to configure the actual MQTT mapping.<br/>
      By default, the following attribute names are used: mqttDefaults, mqttAlias, mqttPublish, mqttSubscribe.
      <br/>The meaning of these attributes is explained below.
    </p>
    <ul>
    <li>
        <a id="MQTT_GENERIC_BRIDGE-attr-mqttDefaults" data-pattern="(?<!global)Defaults"></a>mqttDefaults<br/>
            <p>Here is a list of "key = value" pairs defined. The following keys are possible:
            <ul>
             <li>'qos' <br/>defines a default value for MQTT parameter 'Quality of Service'.</li>
             <li>'retain' <br/>allows MQTT messages to be marked as 'retained'.</li>
             <li>'base' <br/>s provided as a variable ($base) when configuring concrete topics. 
                It can contain either text or a Perl expression. 
                Perl expression must be enclosed in curly brackets. 
                The following variables can be used in an expression:
                   $base = corresponding definition from the '<a href="#MQTT_GENERIC_BRIDGE-attr-globalDefaults">globalDefaults</a>', 
                   $reading = Original reading name, $device = device name, and $name = reading alias (see <a href="#MQTT_GENERIC_BRIDGE-attr-mqttAlias">mqttAlias</a>. 
                   If no alias is defined, than $name = $ reading).<br/>
                   Furthermore, freely named variables can be defined. These can also be used in the public / subscribe definitions. 
                   These variables are always to be used there with quotation marks.
                   </li>
            </ul>
            <br/>
            All these values can be limited by prefixes ('pub:' or 'sub') in their validity 
            to only send or receive only (as far asappropriate). 
            Values for 'qos' and 'retain' are only used if no explicit information has been given about it for a specific topic.</p>
            <p>Example:<br/>
                <code>attr &lt;dev&gt; mqttDefaults base={"TEST/$device"} pub:qos=0 sub:qos=2 retain=0</code></p>
        </p>
    </li>

    <li>
        <a id="MQTT_GENERIC_BRIDGE-attr-mqttAlias" data-pattern="(?<!global)Alias"></a>mqttAlias<br/>
            <p>This attribute allows readings to be mapped to MQTT topic under a different name. 
            Usually only useful if topic definitions are Perl expressions with corresponding variables or to achieve somehow standardized topic structures. 
            Again, 'pub:' and 'sub:' prefixes are supported 
            (For 'subscribe', the mapping will be reversed).
            </p>
            <p>Example:<br/>
                <code>attr &lt;dev&gt; mqttAlias pub:temperature=temp</code></p>
        </p>
    </li>
  
    <li>
        <a id="MQTT_GENERIC_BRIDGE-attr-mqttPublish" data-pattern="(?<!global)Publish"></a>mqttPublish<br/>
            <p>Specific topics can be defined and assigned to the Readings(Format: &lt;reading&gt;:topic=&lt;topic&gt;). 
            Furthermore, these can be individually provided with 'qos' and 'retain' flags.<br/>
            Topics can also be defined as Perl expression with variables ($reading, $device, $name, $base or additional variables as provided in <a href="#MQTT_GENERIC_BRIDGE-attr-mqttDefaults">mqttDefaults</a>).<br/><br/>
            Values for several readings can also be defined together, separated with '|'.<br/>
            If a '*' is used instead of a reading name, this definition applies to all readings for which no explicit information was provided.<br/>
            Topic can also be written as a 'readings-topic'.<br/>
            Attributes can also be sent ("atopic" or "attr-topic").
            If you want to send several messages (e.g. to different topics) for an event, the respective definitions must be defined by appending
            unique suffixes (separated from the reading name by a !-sign): reading!1:topic=... reading!2:topic=.... <br/>
            It is possible to define expressions (reading: expression = ...). <br/>
            The expressions could be used to change variables ($value, $topic, $qos, $retain, $message, $uid), or return a value of != undef.<br/>
            The return value is used as a new message value, the changed variables have priority.<br/>
            If the return value is <i>undef</i>, setting / execution is suppressed. <br/>
            If the return is a hash (topic only), its key values are used as the topic, and the contents of the messages are the values from the hash.</p>
            <p>Option 'resendOnConnect' allows to save the messages,
            if the bridge is not connected to the MQTT server.
            The messages to be sent are stored in a queue.
            When the connection is established, the messages are sent in the original order.
            <ul>Possible values:
               <li> none <br/> discard all </li>
               <li> last <br/> save only the last message </li>
               <li> first <br/> save only the first message
               then discard the following</li>
               <li>all<br/>save all, but if there is an upper limit of 100, if it is more, the most supernatural messages are discarded. </li>
            </ul>
            <p>Examples:<br/>
                <code> attr &lt;dev&gt; mqttPublish temperature:topic={"$base/$name"} temperature:qos=1 temperature:retain=0 *:topic={"$base/$name"} humidity:topic=/TEST/Feuchte<br/>
                attr &lt;dev&gt; mqttPublish temperature|humidity:topic={"$base/$name"} temperature|humidity:qos=1 temperature|humidity:retain=0<br/>
                attr &lt;dev&gt; mqttPublish *:topic={"$base/$name"} *:qos=2 *:retain=0<br/>
                attr &lt;dev&gt; mqttPublish *:topic={"$base/$name"} reading:expression={"message: $value"}<br/>
                attr &lt;dev&gt; mqttPublish *:topic={"$base/$name"} reading:expression={$value="message: $value"}<br/>
                attr &lt;dev&gt; mqttPublish *:topic={"$base/$name"} reading:expression={"/TEST/Topic1"=>"$message", "/TEST/Topic2"=>"message: $message"}<br/>
                attr &lt;dev&gt; mqttPublish *:resendOnConnect=last<br/>
                attr &lt;dev&gt; mqttPublish temperature:topic={"$base/temperature/01/value"} temperature!json:topic={"$base/temperature/01/json"}
                   temperature!json:expression={toJSON({value=>$value,type=>"temperature",unit=>"°C",format=>"00.0"})}<br/>
                </code></p>
        </p>
    </li>

    <li>
        <p><a id="MQTT_GENERIC_BRIDGE-attr-mqttSubscribe" data-pattern="(?<!global)Subscribe"></a>mqttSubscribe<br/>
            This attribute configures the device to receive MQTT messages and execute corresponding actions.<br/>
            The configuration is similar to that for the 'mqttPublish' attribute. 
            Topics can be defined for setting readings ('topic' or 'readings-topic') and calls to the 'set' command on the device ('stopic' or 'set-topic').<br/>
            Also attributes can be set ('atopic' or 'attr-topic').</br>
            The result can be modified before setting the reading or executing of 'set' / 'attr' on the device with additional Perl expressions ('expression').<br/>
            The following variables are available in the expression: $device, $reading, $message (initially equal to $value). 
            The expression can either change variable $value, or return a value != undef. 
            Redefinition of the variable has priority. If the return value is undef, then the set / execute is suppressed (unless $value has a new value).<br/>
            If the return is a hash (only for 'topic' and 'stopic'), 
            then its key values are used as readings or 'set' parameters, 
            the values to be set are the values from the hash.<br/>
            Furthermore the attribute 'qos' can be specified ('retain' does not make sense here).<br/>
            Topic definition can include MQTT wildcards (+ and #).<br/>
            If the reading name is defined with a '*' at the beginning, it will act as a wildcard. 
            Several definitions with '*' should also be used as: *1:topic = ... *2:topic = ...
            The actual name of the reading (and possibly of the device) is defined by variables from the topic
            ($device (only for global definition in the bridge), $reading, $name).
            In the topic these variables act as wildcards, of course only makes sense, if reading name is not defined 
            (so start with '*', or multiple names separated with '|').<br/>
            The variable $name, unlike $reading, may be affected by the aliases defined in 'mqttAlias'. Also use of $base is allowed.<br/>
            When using 'stopic', the 'set' command is executed as 'set &lt;dev&gt; &lt;reading&gt; &lt;value&gt;'.
            For something like 'set &lt;dev&gt; &lt;value&gt;'  'state' should be used as reading name.</p>
            <p>If JSON support is needed: Use the <i>json2nameValue()</i> method provided by <i>fhem.pl</i> in 'expression' with '$message' as parameter.</p>
            <p>Examples:<br/>
                <code>attr &lt;dev&gt; mqttSubscribe temperature:topic=TEST/temperature test:qos=0 *:topic={"TEST/$reading/value"} <br/>
                    attr &lt;dev&gt; mqttSubscribe desired-temperature:stopic={"TEST/temperature/set"}<br/>
                    attr &lt;dev&gt; mqttSubscribe state:stopic={"TEST/light/set"} state:expression={...}<br/>
                    attr &lt;dev&gt; mqttSubscribe state:stopic={"TEST/light/set"} state:expression={$value="x"}<br/>
                    attr &lt;dev&gt; mqttSubscribe state:stopic={"TEST/light/set"} state:expression={"R1"=>$value, "R2"=>"Val: $value", "R3"=>"x"}
                    attr &lt;dev&gt; mqttSubscribe verbose:atopic={"TEST/light/verbose"}
                    attr &lt;dev&gt; mqttSubscribe json:topic=XTEST/json json:expression={json2nameValue($message)}
                 </code></p>
        </p>
    </li>

    <li>
        <a id="MQTT_GENERIC_BRIDGE-attr-mqttForward" data-pattern=".*Forward"></a>mqttForward<br/>
            <p>This attribute defines what happens when one and the same reading is both subscribed and posted. 
            Possible values: 'all' and 'none'.<br/>
            If 'none' is selected, than messages received via MQTT will not be published from the same device.<br/>
            The setting 'all' does the opposite, so that the forwarding is possible.<br/>
            If this attribute is missing, the default setting for all device types except 'dummy' is 'all' 
            (so that actuators can receive commands and send their changes in the same time) and for dummies 'none' is used. 
            This was chosen because dummies are often used as a kind of GUI switch element. 
            In this case, 'all' might cause an endless loop of messages.
            </p>
        </p>
    </li>

    <li>
        <a id="MQTT_GENERIC_BRIDGE-attr-mqttDisable" data-pattern=".*Disable"></a>mqttDisable<br/>
            <p>If this attribute is set in a device, this device is excluded from sending or receiving the readings.</p>
        </p>
    </li>
    </ul>
</ul>
 
<p><b>Examples</b></p>

<ul>
    <li>
        <p>Bridge for any devices with the standard prefix:<br/>
                <code>defmod mqttGeneric MQTT_GENERIC_BRIDGE<br/>
                        attr mqttGeneric IODev mqtt</code>
        </p>
        </p>
    </li>
    
    <li>
        <p>Bridge with the prefix 'mqtt' for three specific devices:<br/>
            <code> defmod mqttGeneric MQTT_GENERIC_BRIDGE mqtt sensor1,sensor2,sensor3<br/>
                    attr mqttGeneric IODev mqtt</code></p>
        </p>
    </li>

    <li>
        <p>Bridge for all devices in a certain room:<br/>
            <code>defmod mqttGeneric MQTT_GENERIC_BRIDGE mqtt room=Wohnzimmer<br/>
                attr mqttGeneric IODev mqtt</code></p>
        </p>
    </li>
     
    <li>
        <p>Simple configuration of a temperature sensor:<br/>
            <code>defmod sensor XXX<br/>
                attr sensor mqttPublish temperature:topic=haus/sensor/temperature</code></p>
        </p>
    </li>

    <li>
        <p>Send all readings of a sensor (with their names as they are) via MQTT:<br/>
            <code> defmod sensor XXX<br/>
                attr sensor mqttPublish *:topic={"sensor/$reading"}</code></p>
        </p>
    </li>
     
    <li>
        <p>Topic definition with shared part in 'base' variable:<br/>
            <code>defmod sensor XXX<br/>
                attr sensor mqttDefaults base={"$device/$reading"}<br/>
                attr sensor mqttPublish *:topic={"$base"}</code></p>
        </p>
    </li>

    <li>
        <p>Topic definition only for certain readings with renaming (alias):<br/>
            <code>defmod sensor XXX<br/>
                attr sensor mqttAlias temperature=temp humidity=hum<br/>
                attr sensor mqttDefaults base={"$device/$name"}<br/>
                attr sensor mqttPublish temperature:topic={"$base"} humidity:topic={"$base"}<br/></code></p>
        </p>
    </li>

    <li>
        <p>Example of a central configuration in the bridge for all devices that have Reading named 'temperature':<br/>
            <code>defmod mqttGeneric MQTT_GENERIC_BRIDGE <br/>
                attr mqttGeneric IODev mqtt <br/>
                attr mqttGeneric defaults sub:qos=2 pub:qos=0 retain=0 <br/>
                attr mqttGeneric publish temperature:topic={"haus/$device/$reading"} <br/>
         </code></p>
        </p>
    </li>

    <li>
        <p>Example of a central configuration in the bridge for all devices:<br/>
            <code>defmod mqttGeneric MQTT_GENERIC_BRIDGE <br/>
                attr mqttGeneric IODev mqtt <br/>
                attr mqttGeneric defaults sub:qos=2 pub:qos=0 retain=0 <br/>
                attr mqttGeneric publish *:topic={"haus/$device/$reading"} <br/></code></p>
        </p>
    </li>
</ul>

<p><b>Limitations:</b></p>

<ul>
      <li>If several readings subscribe to the same topic, no different QOS are possible.</li>
      <li>If QOS is not equal to 0, it should either be defined individually for all readings, or generally over defaults.<br/>
        Otherwise, the first found value is used when creating a subscription.</li>
      <li>Subscriptions are renewed only when the topic is changed, so changing the QOS flag onnly will only work after a restart of FHEM.</li>
</ul>

=end html

=cut
