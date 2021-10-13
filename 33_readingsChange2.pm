###############################################################################
#
# $Id: 33_readingsChange2.pm 25035 2021-10-13 Beta-User $
#
###############################################################################


package FHEM::readingsChange2;

use strict;
use warnings;
use Carp qw(carp);
##no critic qw(constant Package)

use GPUtils qw(:all);

my %sets = (
);

my %gets = (
  "version"   => "noArg",
  "devlist"   => "",
  "devinfo"   => "",
  "refreshUserAttr" => "noArg"
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

    $hash->{Match}    = q{.*};

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
    my $size = 0;
    for my $dname (sort keys %{$hash->{devices}}) {
        $size++ if $dname ne ':global';
    }
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
                push @errors, "no regex as second argument provided in attr readingsChange2 for $dev in line $line";
                next;
            }
        } elsif ( $regexp !~ m{\(.+\)} ) {
            $regexp = join q{ }, ($regexp, $expr); #might be Perl only with spaces
            $expr = undef;
            if ( $regexp !~ m<\A\{.+}\z> ) {
                push @errors, "no regex as second argument provided in attr readingsChange2 for $dev in line $line";
                next;
            }
        }
        if (!$expr ) { #$regexp is Perl command
            my $schk = perlSyntaxCheck( $regexp );
            if ( $schk ) {
                push @errors, "invalid Perl syntax in attr readingsChange2 for $dev in line $line: $schk";
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
=pod
    my $res = q{};
    for my $dname (sort keys %{$hash->{helper}->{DEVICES}}) {
        if($args) {
            next if $dname !~ m{\A$args\z}x;
        }
        $res.= "${dname}\n";
        $res.="  replace:\n";
        for my $rname (sort keys %{$hash->{helper}->{DEVICES}->{$dname}->{replace}}) {
            my $readReplList = getDeviceReplRec($hash, $dname, $rname);
            next if !defined($readReplList);
            for my $pubRec (@{$readReplList}) {
                next if !defined($pubRec);
                my $expression = $pubRec->{'expression'};
              my $mode =  $pubRec->{'mode'};
             $mode='E' if(defined($expression) && !defined($mode));
          my $topic = 'undefined';
              if($mode eq 'R') {
                $topic = $pubRec->{'topic'};
              } elsif($mode eq 'A') {
                $topic = $pubRec->{'atopic'};
              } elsif($mode eq 'E') {
                $topic = '[expression]';
              } else {
                $topic = '!unexpected mode!';
              }
              my $qos = $pubRec->{'qos'};
              my $retain = $pubRec->{'retain'};
                  my $postFix = $pubRec->{'postfix'};
                  my $dispName = $rname;
                  if(defined($postFix) and ($postFix ne '')) {$dispName.='!'.$postFix;}
                  $res.= sprintf('    %-16s => %s',  $dispName, $topic);
              $res.= " (";
              $res.= "mode: $mode";
              $res.= "; qos: $qos";
              $res.= "; retain" if ($retain ne "0");
              $res.= ")\n";
              $res.= "                     exp: $expression\n" if defined ($expression);
            }
          }
          $res.="  subscribe:\n";
          my @resa;
      for my $subRec (@{$hash->{helper}->{DEVICES}->{$dname}->{':subscribe'}}) {
            my $qos = $subRec->{'qos'};
            my $mode = $subRec->{'mode'};
            my $expression = $subRec->{'expression'};
        my $topic = $subRec->{'topic'} // '---';
        my $rest= sprintf('    %-16s <= %s', $subRec->{'reading'}, $topic);
            $rest.= " (mode: $mode";
            $rest.= "; qos: $qos" if defined ($qos);
            $rest.= ")\n";
            $rest.= "                     exp: $expression\n" if defined ($expression);
            push (@resa, $rest);
          }
          $res.=join('', sort @resa);
        }
        $res.= "\n";
      }
  $res = "no devices found" if $res eq '';
      return $res;
=cut
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
    my $devDataTab = $hash->{helper}->{DEVICES}           // return; # Geraetetabelle
    my $devDataRecord = $devDataTab->{$devName} // return; 

    for my $event (@{deviceEvents($dev,1)}) {
        $event =~ m{\A(?<dev>[^:]+)(?<devr>:\s)?(?<devrv>.*)\z}smx; # Schalter /sm ist wichtig! Sonst wir bei mehrzeiligen Texten Ende nicht korrekt erkannt. s. https://perldoc.perl.org/perlretut.html#Using-regular-expressions-in-Perl 
        my $devreading = $+{dev};
        my $devval = $+{devrv};

        # Sonderlocke fuer 'state' in einigen Faellen: z.B. bei ReadingsProxy kommt in CHANGEDWITHSTATE nichts an, und in CHANGE, wie gehabt, z.B. 'off'
        if(!$+{devr}) {
            $devval = $event;
            $devreading = 'state';
        }

        next if !defined $devreading || !defined $devval;
        checkDeviceUpdate($hash, $dev, $devreading, $devval);
    }
    return;
}

# MQTT-Nachrichten entsprechend Geraete-Infos senden
# Params: Bridge-Hash, Device-Hash, 
#         Modus (Topics entsprechend Readings- oder Attributen-Tabelleneintraegen suchen), 
#         Name des Readings/Attributes, Wert
sub checkDeviceUpdate {
    my $hash    = shift // return;
    my $devHash = shift // carp q[No hash for target device provided!] && return;
    my $reading = shift // carp q[No reading provided!] && return;
    my $value   = shift // q{\0} ; # TODO: pruefen: oder doch ""?;

    my $devn = $devHash->{NAME};
    return if !defined $hash->{helper}->{DEVICES}->{$devn};

    my $readReplList = getDeviceReplRec($hash, $devn, $reading);
    return if !defined $readReplList;

    for my $replacement (@{$readReplList}) {
        my $regexp = $replacement->{regexp}; # 'normale' Readings
        my $expression = $replacement->{expression};
    
    my $redefMap=undef;
    my $message=$value;
=pod
    if(defined $expression) {
      # Expression: Direktes aendern von Attributen ($topic, $qos, $retain, $value) moeglich
      # Rueckgabe: bei undef wird die Ausfuehrung unterbunden. Sonst wird die Rueckgabe als neue message interpretiert, 
      # es sei denn, Variable $value wurde geaendert, dann hat die Aenderung Vorrang.
      # Rueckgabewert wird ignoriert, falls dieser ein Array ist. 
      # Bei einem Hash werden Paare als Topic-Message Paare verwendet und mehrere Nachrichten gesendet
      no strict "refs";
      local $@ = undef;
      # $device, $reading, $name (und fuer alle Faelle $topic) in $defMap packen, so zur Verfügung stellen (für eval)reicht wegen _evalValue2 wohl nicht
      my $name = $reading; # TODO: Name-Mapping
      my $device = $devn;
          #if(!defined($defMap->{'room'})) {
          #  $defMap->{'room'} = AttrVal($devn,'room','');
          #}
          
      my $ret;
      $ret = eval($ret); ##no critic qw(eval) 
      # we expressively want user code to be executed! This is added after compile time...
          #Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE:DEBUG:> DEBUG: <<< eval expression: ".Dumper($ret));
      if(ref($ret) eq 'HASH') {
        $redefMap = $ret;
      } elsif(ref($ret) eq 'ARRAY') {
        # ignore
      } elsif(!defined($ret)) {
        $message = undef;
      } elsif($value ne $message) {
        $message = $value;
      } else {
        $message = $ret;
      }
      #Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE:DEBUG:> [$hash->{NAME}] eval done: ".Dumper($ret));
      if ($@) {
        Log3($hash->{NAME},2,"MQTT_GENERIC_BRIDGE: [$hash->{NAME}] error while evaluating expression ('".$expression."'') eval error: ".$@);
      }
      use strict "refs";
    }

    my $updated = 0;
    if(defined($redefMap)) {
      #Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE:DEBUG:> DEBUG: redefMap: ".Dumper($redefMap));
      for my $key (keys %{$redefMap}) {
        my $val = $redefMap->{$key};
        my $r = doPublish($hash,$devn,$reading,$key,$val,$qos,$retain,$resendOnConnect);
        $updated = 1 if !defined $r;
      }
    } elsif (defined $topic and defined $message) {
      my $r = doPublish($hash,$devn,$reading,$topic,$message,$qos,$retain,$resendOnConnect);  
      $updated = 1 unless defined $r;
    }
    if($updated) {
      updatePubTime($hash,$devn,$reading);
=cut
    }
  return;
}

#original function
sub readingsChangeExec($$)
{
  my ($rc, $dev) = @_;

  my $SELF = $rc->{NAME};
  return "" if(IsDisabled($SELF));

  my $re = $rc->{".re"};
  my $NAME = $dev->{NAME};
  return if($NAME !~ m/$re->[0]/ || !$dev->{READINGS});

  my $events = deviceEvents($dev, AttrVal($SELF, "addStateEvent", 0));
  return if(!$events);
  my $max = int(@{$events});

  my $matched=0;
  for (my $i = 0; $i < $max; $i++) {
    my $EVENT = $events->[$i];
    next if(!defined($EVENT) || $EVENT !~ m/^([^ ]+): (.+)/);
    my ($rg, $val) = ($1, $2);
    next if($rg !~ m/$re->[1]/ || !$dev->{READINGS}{$rg});

    Log3 $SELF, 5, "Changing $NAME:$rg $val via $SELF";
    $matched++;
    if($rc->{".isPerl"}) {
      eval "\$val =~ s/$re->[2]/$re->[3]/ge";
    } else {
      eval "\$val =~ s/$re->[2]/$re->[3]/g";
    }
    $events->[$i] = "$rg: $val";
    $dev->{READINGS}{$rg}{VAL} = $val;
  }
  evalStateFormat($dev) if($matched);
  return undef;
}

# Routine fuer FHEM Attr
sub Attr {
  my ($command,$name,$attribute,$value) = @_;

  my $hash = $defs{$name} // return;

  return;
}


# Per MQTT-Empfangenen Aktualisierungen an die entsprechende Geraete anwenden
# Params: Bridge-Hash, Modus (R=Readings, A=Attribute), Device, Reading/Attribute-Name, Nachricht
sub doSetUpdate { #($$$$$) {
  #my ($hash,$mode,$device,$reading,$message) = @_;
  my $hash    = shift // return;
  my $mode    = shift // q{unexpected!};
  my $device  = shift // carp q[No device provided!]  && return;
  my $reading = shift // carp q[No reading provided!] && return;
  my $message = shift; # // carp q[No message content!]  && return;
  my $isBulk  = shift // 0;

  my $dhash = $defs{$device} // carp qq[No device hash for $device registered!]  && return;
  #return unless defined $dhash;
  #Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE: [$hash->{NAME}] setUpdate enter: update: $reading = $message");
  #my $doForward = isDoForward($hash, $device,$reading); 
  my $doForward = isDoForward($hash, $device); #code seems only to support on device level!

  if($mode eq 'S') {
    my $err;
    my @args = split ("[ \t]+",$message);
    #Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE:DEBUG:> [$hash->{NAME}] mqttGenericBridge_triggeredReading=".Dumper($dhash->{'.mqttGenericBridge_triggeredReading'}));
    if(($reading eq '') or ($reading eq 'state')) {
      $dhash->{'.mqttGenericBridge_triggeredReading'}="state" if !$doForward;
      $dhash->{'.mqttGenericBridge_triggeredReading_val'}=$message if !$doForward;
      #$err = DoSet($device,$message);
      $err = DoSet($device,@args);
    } else {
      $dhash->{'.mqttGenericBridge_triggeredReading'}=$reading if !$doForward;
      $dhash->{'.mqttGenericBridge_triggeredReading_val'}=$message if !$doForward;
      #$err = DoSet($device,$reading,$message);
      $err = DoSet($device,$reading,@args);
    }
    if (!defined($err)) {
      return;
    }
    Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE: [$hash->{NAME}] setUpdate: error in set command: ".$err);
    return "error in set command: $err";
  } elsif($mode eq 'R') { # or $mode eq 'T') {
    # R - Normale Topic (beim Empfang nicht weiter publishen)
    # T - Selt-Trigger-Topic (Sonderfall, auch wenn gerade empfangen, kann weiter getriggert/gepublisht werden. Vorsicht! Gefahr von 'Loops'!)
    readingsBeginUpdate($dhash) if !$isBulk;
    if ($mode eq 'R' && !$doForward) {
      $dhash->{'.mqttGenericBridge_triggeredReading'}     = $reading;
      $dhash->{'.mqttGenericBridge_triggeredReading_val'} = $message;
      $dhash->{'.mqttGenericBridge_triggeredBulk'}        = 1 if $isBulk;
    }
    readingsBulkUpdate($dhash,$reading,$message);
    readingsEndUpdate($dhash,1) if !$isBulk;
    #Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE: [$hash->{NAME}] setUpdate: update: $reading = $message");
    # wird in 'notify' entfernt # delete $dhash->{'.mqttGenericBridge_triggeredReading'};

    return;
  } else {
    Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE: [$hash->{NAME}] setUpdate: unexpected mode: ".$mode);
    return "unexpected mode: $mode";
  }
  return "internal error";
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

<!--TODO-->
<!--
<p><b>Ideen:</b></p>
<ul>
  <li>global Subscribe</li>
  <li>global excludes</li>
  <li>QOS for subscribe (fertig?), defaults(qos, fertig?), alias mapping</li>
  <li>resendOnConnect (no, first, last, all)</li>
  <li>resendInterval (no/0, x min)</li>
  <li>templates (template in der Bridge, mqttUseTemplate in Device)</li>
</ul>
-->
</ul>

=end html

=item summary_DE MQTT_GENERIC_BRIDGE acts as a bridge for any fhem-devices and mqtt-topics
=begin html_DE

 <a id="MQTT_GENERIC_BRIDGE"></a>
 <h3>MQTT_GENERIC_BRIDGE</h3>
 <ul>
 <p>
    Dieses Modul ist eine MQTT-Bridge, die gleichzeitig mehrere FHEM-Devices erfaßt und deren Readings 
    per MQTT weiter gibt bzw. aus den eintreffenden MQTT-Nachrichten befüllt oder diese als 'set'-Befehl 
    an dem konfigurierten FHEM-Gerät ausführt.
     <br/>Es wird eines der folgenden Geräte als IODev benötigt: <a href="#MQTT">MQTT</a>,  
     <a href="#MQTT2_CLIENT">MQTT2_CLIENT</a> oder <a href="#MQTT2_SERVER">MQTT2_SERVER</a>.
 </p>
 <p>Die (minimale) Konfiguration der Bridge selbst ist grundsätzlich sehr einfach.</p>
 <a id="MQTT_GENERIC_BRIDGE-define"></a>
 <b>Definition:</b>
 <ul>
   <p>Im einfachsten Fall reichen schon zwei Zeilen:</p>
     <p><code>defmod mqttGeneric MQTT_GENERIC_BRIDGE [prefix] [devspec,[devspec]]</br>
     attr mqttGeneric IODev <MQTT-Device></code></p>
   <p>Alle Parameter im Define sind optional.</p>
   <p>Der erste ist ein Prefix für die Steuerattribute, worüber die zu überwachende Geräte (s.u.) 
   konfiguriert werden. Defaultwert ist 'mqtt'. 
   Wird dieser z.B. als 'mqttGB1_' festgelegt, heißen die Steuerungsattribute entsprechend mqttGB1_Publish etc.</p>
   <p>Der zweite Parameter ('devspec') erlaubt die Menge der zu überwachenden Geräten 
   zu begrenzen (sonst werden einfach alle überwacht, was jedoch Performance kosten kann).
   Beispiel für devspec: 'TYPE=dummy' oder 'dummy1,dummy2'. Es gelten die allgemeinen Regeln für <a href="#devspec">devspec</a>, bei kommaseparierter Liste sind also keine Leerzeichen erlaubt!</p>
   
   
 </ul>
 
 <a name="MQTT_GENERIC_BRIDGEget"></a>
 <p><b>get:</b></p>
 <ul>
   <li>
     <p>version<br/>
     Zeigt Modulversion an.</p>
   </li>
   <li>
     <p>devlist [&lt;name (regex)&gt;]<br/>
     Liefert Liste der Namen der von dieser Bridge überwachten Geräte deren Namen zu dem optionalen regulärem Ausdruck entsprechen. 
     Fehlt der Ausdruck, werden alle Geräte aufgelistet. 
     </p>
   </li>
   <li>
     <p>devinfo [&lt;name (regex)&gt;]<br/>
     Gibt eine Liste der überwachten Geräte aus, deren Namen dem optionalen regulären Ausdruck entsprechen.
     Fehlt der Ausdruck, werden alle Geräte aufgelistet. Zusätzlich werden bei 'publish' und 'subscribe' 
     verwendete Topics angezeigt incl. der entsprechenden Readingsnamen.</p>
   </li>
 </ul>

 <a name="MQTT_GENERIC_BRIDGEreadings"></a>
 <p><b>readings:</b></p>
 <ul>
   <li>
     <p>device-count<br/>
     Anzahl der überwachten Geräte</p>
   </li>
   <li>
     <p>incoming-count<br/>
     Anzahl eingehender Nachrichten</p>
   </li>
   <li>
     <p>outgoing-count<br/>
     Anzahl ausgehende Nachrichten</p>
   </li>
   <li>
     <p>updated-reading-count<br/>
     Anzahl der gesetzten Readings</p>
   </li>
   <li>
     <p>updated-set-count<br/>
     Anzahl der abgesetzten 'set' Befehle</p>
   </li>
   <li>
     <p>transmission-state<br/>
     letze Übertragunsart</p>
   </li>
 </ul>

 <a name="MQTT_GENERIC_BRIDGEattr"></a>
 <p><b>Attribute:</b></p>
   <p>Folgende Attribute werden unterstützt:</p>
   <li><p><b>Im MQTT_GENERIC_BRIDGE-Device selbst:</b></p>
   <ul>
   <li><p>IODev<br/>
     Dieses Attribut ist obligatorisch und muss den Namen einer funktionierenden MQTT-IO-Modulinstanz enthalten. 
     Es werden derzeit MQTT, MQTT2_CLIENT und MQTT2_SERVER unterstützt.</p>
   </li>

   <li>
     <p>disable<br/>
     Wert 1 deaktiviert die Bridge</p>
     <p>Beispiel:<br>
       <code>attr &lt;dev&gt; disable 1</code>
     </p>
   </li>

   <li>
     <p>globalDefaults<br/>
        Definiert Defaults. Diese greifen in dem Fall, wenn in dem jeweiligen Gerät definierte Werte nicht zutreffen. 
        s.a. <a href="#MQTT_GENERIC_BRIDGEmqttDefaults">mqttDefaults</a>.
      <p>Beispiel:<br>
        <code>attr &lt;dev&gt; sub:base={"FHEM/set/$device"} pub:base={"FHEM/$device"}</code>
     </p>
     </p>
   </li>

   <li>
    <p>globalAlias<br/>
        Definiert Alias. Diese greifen in dem Fall, wenn in dem jeweiligen Gerät definierte Werte nicht zutreffen. 
        s.a. <a href="#MQTT_GENERIC_BRIDGEmqttAlias">mqttAlias</a>.
     </p>
   </li>
   
   <li>
    <p>globalPublish<br/>
        Definiert Topics/Flags für die Übertragung per MQTT. Diese werden angewendet, falls in dem jeweiligen Gerät 
        definierte Werte nicht greifen oder nicht vorhanden sind. 
        s.a. <a href="#MQTT_GENERIC_BRIDGEmqttPublish">mqttPublish</a>.
     </p>
   <p>Hinweis:<br>
      Dieses Attribut sollte nur gesetzt werden, wenn wirklich alle Werte aus den überwachten Geräten versendet werden sollen; dies wird eher nur im Ausnahmefall zutreffen!
   </p>
   </li>

   <li>
    <p>globalTypeExclude<br/>
        Definiert (Geräte-)Typen und Readings, die nicht bei der Übertragung berücksichtigt werden. 
        Werte können getrennt für jede Richtung (publish oder subscribe) vorangestellte Prefixe 'pub:' und 'sub:' angegeben werden.
        Ein einzelner Wert bedeutet, dass ein Gerät diesen Types komplett ignoriert wird (also für alle seine Readings und beide Richtungen).
        Durch einen Doppelpunkt getrennte Paare werden als [sub:|pub:]Type:Reading interpretiert.
        Das bedeutet, dass an dem gegebenen Type die genannte Reading nicht übertragen wird.
        Ein Stern anstatt Type oder auch Reading bedeutet, dass alle Readings eines Geretätyps
        bzw. genannte Readings an jedem Gerätetyp ignoriert werden. </p>
        <p>Beispiel:<br/>
        <code>attr &lt;dev&gt; globalTypeExclude MQTT MQTT_GENERIC_BRIDGE:* MQTT_BRIDGE:transmission-state *:baseID</code></p>
   </li>

   <li>
    <p>globalDeviceExclude<br/>
        Definiert Gerätenamen und Readings, die nicht übertragen werden.
        Werte können getrennt für jede Richtung (publish oder subscribe) vorangestellte Prefixe 'pub:' und 'sub:' angegeben werden.
        Ein einzelner Wert bedeutet, dass ein Gerät mit diesem Namen komplett ignoriert wird (also für alle seine Readings und beide Richtungen).
        Durch ein Doppelpunkt getrennte Paare werden als [sub:|pub:]Device:Reading interptretiert. 
        Das bedeutet, dass an dem gegebenen Gerät die genannte Readings nicht übertragen wird.</p>
        <p>Beispiel:<br/>
            <code>attr &lt;dev&gt; globalDeviceExclude Test Bridge:transmission-state</code></p>
   </li>

   <li>
    <a id="MQTT_GENERIC_BRIDGE-attr-forceNEXT"></a>forceNEXT
       <p>Nur relevant, wenn MQTT2_CLIENT oder MQTT2_SERVER als IODev verwendet werden. Wird dieses Attribut auf 1 gesetzt, gibt MQTT_GENERIC_BRIDGE alle eingehenden Nachrichten an weitere Client Module (z.b. MQTT2_DEVICE) weiter, selbst wenn der betreffende Topic von einem von der MQTT_GENERIC_BRIDGE überwachten Gerät verwendet wird. Im Regelfall ist dies nicht erwünscht und daher ausgeschaltet, um unnötige <i>autocreates</i> oder Events an MQTT2_DEVICEs zu vermeiden. Siehe dazu auch das <a href="#MQTT2_CLIENT-attr-clientOrder">clientOrder Attribut</a> bei MQTT2_CLIENT bzw -SERVER; wird das Attribut in einer Instance von MQTT_GENERIC _BRIDGE gesetzt, kann das Auswirkungen auf weitere Instanzen haben.</p>
   </li>
   </li>
   </ul>
   <br>

   <li><p><b>Für die überwachten Geräte</b> wird eine Liste der möglichen Attribute automatisch um mehrere weitere Einträge ergänzt. <br>
      Sie fangen alle mit vorher mit dem in der Bridge definierten <a href="#MQTT_GENERIC_BRIDGE-define">Prefix</a> an. <b>Über diese Attribute wird die eigentliche MQTT-Anbindung konfiguriert.</b><br>
      Als Standardwert werden folgende Attributnamen verwendet: <i>mqttDefaults</i>, <i>mqttAlias</i>, <i>mqttPublish</i>, <i>mqttSubscribe</i>.
      <br/>Die Bedeutung dieser Attribute wird im Folgenden erklärt.
    </p>
    <ul>
       <li>
       <a id="MQTT_GENERIC_BRIDGE-attr-mqttDefaults" data-pattern="(?<!global)Defaults"></a>mqttDefaults<br/>
            <p>Hier wird eine Liste der "key=value"-Paare erwartet. Folgende Keys sind dabei möglich:
            <ul>
             <li>'qos' <br/>definiert ein Defaultwert für MQTT-Paramter 'Quality of Service'.</li>
             <li>'retain' <br/>erlaubt MQTT-Nachrichten als 'retained messages' zu markieren.</li>
             <li>'base' <br/>wird als Variable ($base) bei der Konfiguration von konkreten Topics zur Verfügung gestellt.
                   Sie kann entweder Text oder eine Perl-Expression enthalten. 
                   Perl-Expression muss in geschweifte Klammern eingeschlossen werden.
                   In einer Expression können folgende Variablen verwendet werden:
                   $base = entsprechende Definition aus dem '<a href="#MQTT_GENERIC_BRIDGE-attr-globalDefaults">globalDefaults</a>', 
                   $reading = Original-Readingname, 
                   $device = Devicename und $name = Readingalias (s. <a href="#MQTT_GENERIC_BRIDGE-attr-mqttAlias">mqttAlias</a>. 
                   Ist kein Alias definiert, ist $name=$reading).<br/>
                   Weiterhin können frei benannte Variablen definiert werden, die neben den oben genannten in den public/subscribe Definitionen 
                   verwendet werden können. Allerdings ist zu beachten, dass diese Variablen dort immer mit Anführungszeichen zu verwenden sind.
                   </li>
            </ul>
            <br/>
            Alle diese Werte können durch vorangestelle Prefixe ('pub:' oder 'sub') in ihrer Gültigkeit 
            auf nur Senden bzw. nur Empfangen begrenzt werden (soweit sinnvoll). 
            Werte für 'qos' und 'retain' werden nur verwendet, 
            wenn keine explizite Angaben darüber für ein konkretes Topic gemacht worden sind.</p>
            <p>Beispiel:<br/>
                <code>attr &lt;dev&gt; mqttDefaults base={"TEST/$device"} pub:qos=0 sub:qos=2 retain=0</code></p>
        </p>
    </li>
 

    <li>
        <p><a name="MQTT_GENERIC_BRIDGEmqttAlias">mqttAlias</a><br/>
            Dieses Attribut ermöglicht Readings unter einem anderen Namen auf MQTT-Topic zu mappen. 
            Dies ist dann sinnvoll, wenn entweder Topicdefinitionen Perl-Expressions mit entsprechenden Variablen sind oder der Alias dazu dient, aus MQTT-Sicht standardisierte Readingnamen zu ermöglichen.
            Auch hier werden 'pub:' und 'sub:' Prefixe unterstützt (für 'subscribe' gilt das Mapping quasi umgekehrt).
            <br/></p>
            <p>Beispiel:<br/>
                <code>attr &lt;dev&gt; mqttAlias pub:temperature=temp</code></p>
                <i>temperature</i> ist dabei der Name des Readings in FHEM.
        </p>
    </li>
  
    <li>
        <a id="MQTT_GENERIC_BRIDGE-attr-mqttPublish" data-pattern="(?<!global)Publish"></a>mqttPublish<br/><p>
            Hier werden konkrete Topics definiert und den Readings zugeordnet (Format: &lt;reading&gt;:topic=&lt;topic&gt;). 
            Weiterhin können diese einzeln mit 'qos'- und 'retain'-Flags versehen werden. <br/>
            Topics können auch als Perl-Expression mit Variablen definiert werden ($device, $reading, $name, $base sowie ggf. über <a href="#MQTT_GENERIC_BRIDGE-attr-mqttDefaults">mqttDefaults</a> weitere).<br/><br/>
            'topic' kann auch als 'readings-topic' geschrieben werden.<br/>
            Werte für mehrere Readings können auch gemeinsam gleichzeitig definiert werden, 
            indem sie, mittels '|' getrennt, zusammen angegeben werden.<br/>
            Wird anstatt eines Readingsnamen ein '*' verwendet, gilt diese Definition für alle Readings, 
            für die keine expliziten Angaben gemacht wurden.<br/>
            Neben Readings können auch Attributwerte gesendet werden ('atopic' oder 'attr-topic').<br/>
            Sollten für ein Event mehrere Nachrichten (sinnvollerweise an verschiedene Topics) versendet werden, müssen jeweilige Definitionen durch Anhängen von
             einmaligen Suffixen (getrennt von dem Readingnamen durch ein !-Zeichen) unterschieden werden: reading!1:topic=... reading!2:topic=....<br/>
            Weiterhin können auch Expressions (reading:expression=...) definiert werden. <br/>
            Die Expressions können sinnvollerweise entweder Variablen ($value, $topic, $qos, $retain, $message, $uid) verändern, oder einen Wert != undef zurückgeben.<br/>
            Der Rückgabewert wird als neuer Nachrichten-Value verwendet, die Änderung der Variablen hat dabei jedoch Vorrang.<br/>
            Ist der Rückgabewert <i>undef</i>, dann wird das Setzen/Ausführen unterbunden. <br/>
            Ist die Rückgabe ein Hash (nur 'topic'), werden seine Schlüsselwerte als Topic verwendet, 
            die Inhalte der Nachrichten sind entsprechend die Werte aus dem Hash.</p>
            <p>Option 'resendOnConnect' erlaubt eine Speicherung der Nachrichten, 
            wenn keine Verbindung zu dem MQTT-Server besteht.
            Die zu sendende Nachrichten werden in einer Warteschlange gespeichert. 
            Wird die Verbindung aufgebaut, werden die Nachrichten in der ursprüngichen Reihenfolge verschickt.
            <ul>Mögliche Werte: 
              <li>none<br/>alle verwerfen</li>
              <li>last<br/>immer nur die letzte Nachricht speichern</li>
              <li>first<br/>immer nur die erste Nachricht speichern, danach folgende verwerfen</li>
              <li>all<br/>alle speichern, allerdings existiert eine Obergrenze von 100, 
              wird es mehr, werden älteste überzählige Nachrichten verworfen.</li>
            </ul>
            </p>
            <p>Beispiele:<br/>
                <code> attr &lt;dev&gt; mqttPublish temperature:topic={"$base/$name"} temperature:qos=1 temperature:retain=0 *:topic={"$base/$name"} humidity:topic=TEST/Feuchte<br/>
                attr &lt;dev&gt; mqttPublish temperature|humidity:topic={"$base/$name"} temperature|humidity:qos=1 temperature|humidity:retain=0<br/>
                attr &lt;dev&gt; mqttPublish *:topic={"$base/$name"} *:qos=2 *:retain=0<br/>
                attr &lt;dev&gt; mqttPublish *:topic={"$base/$name"} reading:expression={"message: $value"}<br/>
                attr &lt;dev&gt; mqttPublish *:topic={"$base/$name"} reading:expression={$value="message: $value"}<br/>
                attr &lt;dev&gt; mqttPublish *:topic={"$base/$name"} reading:expression={"TEST/Topic1"=>"$message", "TEST/Topic2"=>"message: $message"}</br>
                attr &lt;dev&gt; mqttPublish [...] *:resendOnConnect=last<br/>
                attr &lt;dev&gt; mqttPublish temperature:topic={"$base/temperature/01/value"} temperature!json:topic={"$base/temperature/01/json"}
                   temperature!json:expression={toJSON({value=>$value,type=>"temperature",unit=>"°C",format=>"00.0"})}<br/>
                </code></p>
        </p>
    </li>

    <li>
        <a id="MQTT_GENERIC_BRIDGE-attr-mqttSubscribe" data-pattern="(?<!global)Subscribe"></a>mqttSubscribe<br/><p>
            Dieses Attribut konfiguriert das Empfangen der MQTT-Nachrichten und die entsprechenden Reaktionen darauf.<br/>
            Die Konfiguration ist ähnlich der für das 'mqttPublish'-Attribut. Es können Topics für das Setzen von Readings ('topic' oder auch 'readings-topic') und
            Aufrufe von 'set'-Befehl an dem Gerät ('stopic' oder 'set-topic') definiert werden. <br/>
            Attribute können ebenfalls gesetzt werden ('atopic' oder 'attr-topic').</br>
            Mit Hilfe von zusätzlichen auszuführenden Perl-Expressions ('expression') kann das Ergebnis vor dem Setzen/Ausführen noch beeinflußt werden.<br/>
            In der Expression sind die folgenden Variablen verfügbar: $device, $reading, $message (initial gleich $value).
            Die Expression kann dabei entweder die Variable $value verändern, oder einen Wert != undef zurückgeben. Redefinition der Variable hat Vorrang.
            Ist der Rückgabewert <i>undef</i>, dann wird das Setzen/Ausführen unterbunden (es sei denn, $value hat einen neuen Wert). <br/>
            Ist die Rückgabe ein Hash (nur für 'topic' und 'stopic'), dann werden seine Schlüsselwerte als Readingsnamen bzw. 'set'-Parameter verwendet,  
            die zu setzenden Werte sind entsprechend den Werten aus dem Hash.<br/>
            Weiterhin kann das Attribut 'qos' angegeben werden ('retain' macht dagegen keinen Sinn).<br/>
            In der Topic-Definition können MQTT-Wildcards (+ und #) verwendet werden. <br/>
            Falls der Reading-Name mit einem '*'-Zeichen am Anfang definiert wird, gilt dieser als 'Platzhalter'.
            Mehrere Definitionen mit '*' sollten somit z.B. in folgender Form verwendet werden: *1:topic=... *2:topic=...
            Der tatsächliche Name des Readings (und ggf. des Gerätes) wird dabei durch Variablen aus dem Topic 
            definiert ($device (nur für globale Definition in der Bridge), $reading, $name).
            Im Topic wirken diese Variablen als Wildcards, was evtl. dann sinnvoll ist, wenn der Reading-Name nicht fest definiert ist 
            (also mit '*' anfängt, oder mehrere Namen durch '|' getrennt definiert werden).  <br/>
            Die Variable $name wird im Unterschied zu $reading ggf. über die in 'mqttAlias' definierten Aliase beeinflusst.
            Auch Verwendung von $base ist erlaubt.<br/>
            Bei Verwendung von 'stopic' wird der 'set'-Befehl als 'set &lt;dev&gt; &lt;reading&gt; &lt;value&gt;' ausgeführt.
            Um den set-Befehl direkt am Device ohne Angabe eines Readingnamens auszuführen (also 'set &lt;dev&gt; &lt;value&gt;') muss als Reading-Name 'state' verwendet werden.</p>
            <p>Um Nachrichten im JSON-Format zu empfangen, kann mit Hilfe von 'expression' direkt die in fhem.pl bereitgestellte Funktion <i>json2nameValue()</i> aufgerufen werden, als Parameter ist <i>$message</i> anzugeben.</p>
            <p>Einige Beispiele:<br/>
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
            <p>Dieses Attribut definiert was passiert, wenn eine und dasselbe Reading sowohl aboniert als auch gepublisht wird. 
            Mögliche Werte: 'all' und 'none'. <br/>
            Bei 'none' werden per MQTT angekommene Nachrichten nicht aus dem selben Gerät per MQTT weiter gesendet.<br/>
            Die Einstellung 'all' bewirkt das Gegenteil, also damit wird das Weiterleiten ermöglicht.<br/>
            Fehlt dieser Attribut, dann wird standardmäßig für alle Gerätetypen außer 'Dummy' die Einstellung 'all' angenommen 
            (damit können Aktoren Befehle empfangen und ihre Änderungen im gleichem Zug weiter senden) 
            und für Dummies wird 'none' verwendet. Das wurde so gewählt,  da dummy von vielen Usern als eine Art GUI-Schalterelement verwendet werden. 
            'none' verhindert hier unter Umständen das Entstehen einer Endlosschleife der Nachrichten.

            </p>
        </p>
    </li>
    
    <li>
        <a id="MQTT_GENERIC_BRIDGE-attr-mqttDisable" data-pattern=".*Disable"></a>mqttDisable<br/>
            <p>Wird dieses Attribut in einem Gerät gesetzt, wird dieses Gerät vom Versand  bzw. Empfang der Readingswerten ausgeschlossen.</p>
        </p>
    </li>
  </ul>
 </li>
</ul>
 
<p><b>Beispiele</b></p>

<ul>
    <li>
        <p>Bridge für alle möglichen Geräte mit dem Standardprefix:<br/>
                <code>defmod mqttGeneric MQTT_GENERIC_BRIDGE<br/>
                        attr mqttGeneric IODev mqtt</code>
        </p>
        </p>
    </li>
    
    <li>
        <p>Bridge mit dem Prefix 'mqttSensors' für drei bestimmte Geräte:<br/>
            <code> defmod mqttGeneric MQTT_GENERIC_BRIDGE mqttSensors sensor1,sensor2,sensor3<br/>
                    attr mqttGeneric IODev mqtt</code></p>
        </p>
    </li>

    <li>
        <p>Bridge für alle Geräte in einem bestimmten Raum:<br/>
            <code>defmod mqttGeneric MQTT_GENERIC_BRIDGE mqtt room=Wohnzimmer<br/>
                attr mqttGeneric IODev mqtt</code></p>
        </p>
    </li>
     
    <li>
        <p>Einfachste Konfiguration eines Temperatursensors:<br/>
            <code>defmod sensor XXX<br/>
                attr sensor mqttPublish temperature:topic=haus/sensor/temperature</code></p>
        </p>
    </li>

    <li>
        <p>Alle Readings eines Sensors (die Namen werden unverändet übergeben) per MQTT versenden:<br/>
            <code> defmod sensor XXX<br/>
                attr sensor mqttPublish *:topic={"sensor/$reading"}</code></p>
        </p>
    </li>
     
    <li>
        <p>Topic-Definition mit Auslagerung des gemeinsamen Teilnamens in 'base'-Variable:<br/>
            <code>defmod sensor XXX<br/>
                attr sensor mqttDefaults base={"/$device/$reading"}<br/>
                attr sensor mqttPublish *:topic={"$base"}</code></p>
        </p>
    </li>

    <li>
        <p>Topic-Definition nur für bestimmte Readings mit deren gleichzeitigen Umbennenung (Alias):<br/>
            <code>defmod sensor XXX<br/>
                attr sensor mqttAlias temperature=temp humidity=hum<br/>
                attr sensor mqttDefaults base={"/$device/$name"}<br/>
                attr sensor mqttPublish temperature:topic={"$base"} humidity:topic={"$base"}<br/></code></p>
        </p>
    </li>

    <li>
        <p>Beispiel für eine zentrale Konfiguration in der Bridge für alle Devices, die Reading 'temperature' besitzen:<br/>
            <code>defmod mqttGeneric MQTT_GENERIC_BRIDGE <br/>
                attr mqttGeneric IODev mqtt <br/>
                attr mqttGeneric defaults sub:qos=2 pub:qos=0 retain=0 <br/>
                attr mqttGeneric publish temperature:topic={"haus/$device/$reading"} <br/>
         </code></p>
        </p>
    </li>

    <li>
        <p>Beispiel für eine zentrale Konfiguration in der Bridge für alle Devices <br/>
                (wegen einer schlechten Übersicht und einer unnötig grossen Menge eher nicht zu empfehlen!):<br/>
            <code>defmod mqttGeneric MQTT_GENERIC_BRIDGE <br/>
                attr mqttGeneric IODev mqtt <br/>
                attr mqttGeneric defaults sub:qos=2 pub:qos=0 retain=0 <br/>
                attr mqttGeneric publish *:topic={"haus/$device/$reading"} <br/></code></p>
        </p>
    </li>
</ul>

<p><b>Einschränkungen:</b></p>

<ul>
      <li>Wenn mehrere Readings das selbe Topic abonnieren, sind dabei keine unterschiedlichen QOS möglich.</li>
      <li>Wird in so einem Fall QOS ungleich 0 benötigt, sollte dieser entweder für alle Readings gleich einzeln definiert werden,
      oder allgemeingültig über Defaults. <br/>
      Ansonsten wird beim Erstellen von Abonnements der erst gefundene Wert verwendet. </li>
      <li>Abonnements werden nur erneuert, wenn sich das Topic ändert; QOS-Flag-Änderung alleine wirkt sich daher erst nach einem Neustart aus.</li>
</ul>

<!--TODO-->
<!--
<p><b>Ideen:</b></p>
<ul>
  <li>global Subscribe</li>
  <li>global excludes</li>
  <li>QOS for subscribe (fertig?), defaults(qos, fertig?), alias mapping</li>
  <li>resendOnConnect (no, first, last, all)</li>
  <li>resendInterval (no/0, x min)</li>
  <li>templates (template in der Bridge, mqttUseTemplate in Device)</li>
</ul>
-->

=end html_DE
=cut
