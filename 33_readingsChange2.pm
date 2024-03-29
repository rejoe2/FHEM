###############################################################################
#
# $Id: 33_readingsChange2.pm 25035 2021-11-11 Beta-User $
#
###############################################################################


package FHEM::readingsChange2; ##no critic qw(Package)

use strict;
use warnings;
use Carp qw(carp);
use Scalar::Util qw(looks_like_number);

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
    OldReadingsNum
    deviceEvents
    addToDevAttrList
    delFromDevAttrList
    devspec2array
    perlSyntaxCheck
    AnalyzePerlCommand
    EvalSpecials
    notifyRegexpChanged
    InternalTimer
    RemoveInternalTimer
    FmtDateTime
    gettimeofday
    TimeNow
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
    "disable:1,0 debug:0,1 disabledForIntervals $readingFnAttributes";
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
  my @devices = devspec2array("$devspec:FILTER=TEMPORARY!=1");
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
    my $nRC = join q{|}, ('global',keys %{$hash->{helper}->{DEVICES}});
    notifyRegexpChanged($hash,$nRC);
    return;
}

sub removeOldUserAttr { 
    my $hash       = shift // return;
    my $devspec    = shift // $hash->{DEVSPEC};
    my $newDevices = shift; #optional, may shorten procedure if given

    $devspec = $devspec eq '.*' ? 'global' : "$devspec::FILTER=TEMPORARY!=1";
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
        my %specials= ( 
                    '$name'    => 'a',
                    '$reading' => 'b',
                    '$value'   => '1'
                       );
        delete $map->{$dev}->{$rdg};
        if (!$expr ) { #$regexp is Perl command
            my $schk = perlSyntaxCheck( $regexp, %specials );
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
            my $schk = perlSyntaxCheck( $expr, %specials );
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
        my $nRC = join q{|}, ('global',keys %{$hash->{helper}->{DEVICES}});
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
    if (!defined $attrVal) {
        delete $map->{$dev};
        my $nRC = join q{|}, ('global',keys %{$map});
        notifyRegexpChanged($hash,$nRC);
        return;
    };
    my $err = CreateSingleDeviceTable($hash, $dev, $map);
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
    my $nRC = join q{|}, ('global',keys %{$hash->{helper}->{DEVICES}});
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
    for my $dev (devspec2array("$hash->{DEVSPEC}:FILTER=TEMPORARY!=1")) {
        $err = CreateSingleDeviceTable($hash, $dev, $map) if $dev ne $hash->{NAME}; 
        push @errors, $err if $err;
    }
    $hash->{helper}->{DEVICES} = $map;
    return if !@errors;
    $err = join q{ ------- }, @errors;
    Log3($hash, 2, "$err");
    return $err;
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

        # Device added
        if ( $s =~ m{\ADEFINED\s+([\S]+)\s+\z}x ) {
            my $new = $1;
            # wenn ein ueberwachtes device, tabelle korrigieren
            addToDevAttrList($new, 'readingsChange2:textField-long', 'readingsChange2') if $new =~ m{$hash->{DEVSPEC}};
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
    return if !$init_done;

    Log3($hash,3,"check device reading for $dev->{NAME}");

    # nicht, wenn deaktivert
    return '' if(::IsDisabled($hash->{NAME}));
    my $devName = $dev->{NAME}                  // return; 
    my $devDataTab = $hash->{helper}->{DEVICES} // return; # Geraetetabelle
    my $devDataRecord = $devDataTab->{$devName} // return; 

    my $changed;
    my $events = deviceEvents($dev,1);
    #Log3($hash,3,"check events, number is " . int @{$events});
    return if !$events;

    #for (0..@{$events}-1) {
    for my $evt (@{$events}) {
        #my $event = $events->[$_];
        my $event = $evt;
        Log3($hash,3,"check event for $dev->{NAME}: $event");
        my $newval;
        next if !defined $event || $event !~ m{\A(?<devrn>[^:]+)(?<devr>:\s)?(?<devrv>.*)\z}smx; # Schalter /sm ist wichtig! Sonst wir bei mehrzeiligen Texten Ende nicht korrekt erkannt. s. https://perldoc.perl.org/perlretut.html#Using-regular-expressions-in-Perl 
        my $devreading = $+{devrn};
        my $devval = $+{devrv};

        # Sonderlocke fuer 'state' in einigen Faellen: z.B. bei ReadingsProxy kommt in CHANGEDWITHSTATE nichts an, und in CHANGE, wie gehabt, z.B. 'off'
        if(!$+{devr}) {
            $devval = qq{$event};
            $devreading = 'state';
        }

        next if !defined $devreading || !defined $devval;
        next if !defined $dev->{READINGS}{$devreading};
        $newval = checkDeviceUpdate($hash, $dev, $devreading, $devval);
        my $lg = "$devName: changed $devreading from $devval to ";
        $lg .= defined $newval ? $newval : "undefined";
        Log3($hash,3,$lg);
        next if defined $newval && $newval eq $devval;
        $changed++;
        if ( defined $newval ) {
            #$events->[$i] = defined $newval ? "$devreading: $newval" : '';
            $dev->{READINGS}{$devreading}{VAL} = $newval;
            #$events->[$_] = "$devreading: $newval";
            $evt = "$devreading: $newval";
        } else {
            #$events->[$_] = '';
            $evt = undef;
            delete $dev->{READINGS}{$devreading};
        }
    }
    evalStateFormat($devName) if $changed;
    return;
}

sub checkDeviceUpdate {
    my $hash    = shift // return;
    my $devHash = shift // carp q[No hash for target device provided!] && return;
    my $reading = shift // carp q[No reading provided!] && return;
    my $value   = shift // q{\0} ; # TODO: pruefen: oder doch ""?;
    my $ts      = shift // FmtDateTime(gettimeofday());

    my $devn = $devHash->{NAME};
    my $devDataRecord = $hash->{helper}->{DEVICES}->{$devn} // return;
    my $readRepl      = $devDataRecord->{$reading}          // return;
    
    my $regexp = $readRepl->{regexp};
    my $pcode  = $readRepl->{perl};
    my $expr   = $readRepl->{repl};
    my $result = qq{$value};
    my $changed;
    if ( defined $regexp && defined $expr ) {
        $result =~ s{\A$regexp\z}{$expr}eegx;
        return $result;
    }

    return if !defined $pcode;

    my $result2;
    my %specials = (
                    '$name'    => $devn,
                    '$reading' => $reading,
                    '$value'   => $value,
                    '$val'     => $value
                       );

    if ( !defined $regexp ) {
        for my $key (keys %specials) {
            my $val = $specials{$key};
            $result =~ s{\Q$key\E}{$val}gxms;
        }
        $result2 = AnalyzePerlCommand( $hash, $result );
    } else { 
        Log3( $hash, 3, "[$hash->{NAME}] execute Perl code: $pcode" );
        EvalSpecials($pcode, %specials);
        my $val = $value;
        my $result2 = AnalyzePerlCommand( $hash, "\$val =~ s{$regexp}{$pcode}gee; return \$val" );
    }

    my $txt = defined $result2 ? $result2 : "undef";
    Log3( $hash, 3, "[$hash->{NAME}] result of Perl code $pcode with $regexp over $value: $txt" );
    Log3( $hash, 3, "[$hash->{NAME}] result of Perl code $pcode with $regexp over $value: $txt" );

    return if !defined $result2 || ref $result2 ne 'HASH' && $result2 =~ m{\AERROR.evaluating}x;
    return $result2 if ref $result2 ne 'HASH';

    readingsBeginUpdate($hash);
    for my $k (keys %{$result2}) {
        next if $k eq $reading;
        readingsBulkUpdate($devHash, $k, $result2->{$k},1); 
    }
    readingsEndUpdate($devHash,1);
    return $result2->{$reading};
}


# Routine fuer FHEM Attr
sub Attr {
  my ($command,$name,$attribute,$value) = @_;

  my $hash = $defs{$name} // return;

  return;
}

########################################
sub _UpdateDevReading {
    my $devHash = shift // carp q[No hash for target device provided!] && return;
    my $reading = shift // carp q[No reading provided!] && return;
    my $value   = shift // q{\0} ; # TODO: pruefen: oder doch ""?;
    my $event   = shift // carp q[No event statement provided!] && return;
   
    $devHash->{READINGS}{$reading}{VAL} = $value;
    $devHash->{READINGS}{$reading}{TIME} = TimeNow(); 
    if  ($event==1) {
        if (exists ($devHash->{CHANGED})) {
            my $max = int(@{$devHash->{CHANGED}});
            $devHash->{CHANGED}[$max] = "$reading: $value";
        }
    } else {
        readingsBulkUpdate($devHash, $reading, $value, 1);
    }
}

sub compareAbs {
    my $name    = shift // carp q[No device name provided!] && return;
    my $reading = shift // carp q[No reading provided!] && return;
    my $value   = shift // carp q[No value provided!] && return;
    my $limit   = shift // q{10};
    my $old     = shift // OldReadingsNum($name,$reading,undef) // return $value;
    return if !looks_like_number($value);
    return $value if $old >= $value- $limit && $old <= $value + $limit;
    return;
}

sub compareRel {
    my $name    = shift // carp q[No device name provided!] && return;
    my $reading = shift // carp q[No reading provided!] && return;
    my $value   = shift // carp q[No value provided!] && return;
    my $limit   = shift // q{10};
    my $old     = shift // OldReadingsNum($name,$reading,undef) // return $value;
    return if !looks_like_number($value);
    return $value if $old >= $value*(1 - $limit) && $old <= $value*(1 + $limit);
    return;
}

sub compareAbsAndRel {
    my $name     = shift // carp q[No device name provided!] && return;
    my $reading  = shift // carp q[No reading provided!] && return;
    my $value    = shift // carp q[No value provided!] && return;
    my $limitabs = shift // q{10};
    my $limitrel = shift // q{10};
    my $old      = shift // OldReadingsNum($name,$reading,undef) // return $value;
    my $err = compareAbs($name,$reading,$value,$limitabs,$old) // return;
    return compareRel($name,$reading,$value,$limitrel,$old);
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
    This module is inspired by <a href="#readingsChange">readingsChange</a>. Main differences:
    <ul>
      <li>Only one instance of readingsChange2 is sufficient and provides a central logic for all other devices. So more than one instance of readingsChange is not allowed
      </li>
      <li>Configuration is done via the attribute <a href="#readingsChange2-attr-readingsChange2">readingsChange2</a> provided by readingsChange2 in all devices (may be limited by <a href="#devspec">devspec</a>).
      </li>
      <li>More than one reading per device may be changed.
      </li>
      <li>readings and respective event may also be deleted.
      </li>
    </ul>
 </p>
 <p>The (minimal) configuration of the central readingsChange2 instance itself is very simple.</p>
 <a id="readingsChange2-define"></a>
 <p><h4>Definition:</h4></p>
 <ul>
   <p><code>defmod readingsChange2 readingsChange2 [devspec,[devspec]]</code></p>
   <p><i>devspec</i> parameter in the define is optional.<br>
      It allows to minimize the number of devices to be monitored (otherwise all devices will be monitored, which may slightly cost performance).
      Example for devspec: 'TYPE=dummy' or 'dummy1,dummy2'. Following the general rules for <a href="#devspec">devspec</a>, a comma separated list must not contain any whitespaces!</p>
 </ul>
 
 <a id="readingsChange2-get"></a>
 <p><h4>get:</h4></p>
 <ul>
   <li>
     <p>devlist [&lt;name (regex)&gt;]<br/>
        Returns list of names of devices monitored by this readingsChange2. First device names have to correspond to the optional devspec, second there has to be at least one working entry in this devices <a href="#readingsChange2-attr-readingsChange2">readingsChange2 attribute</a>. 
     </p>
   </li>
 </ul>

 <a id="readingsChange2-attr"></a>
 <p><h4>Attributes:</h4></p>
 <ul>
   <p><b>The readingsChange2 device itself</b> supports the following attributes:</p>
   <li><a href="#disable"><code>disable</code></a>
   </li>
   <li><a href="#disabledForIntervals"><code>disabledForIntervals</code></a>
   </li>
  </ul>
  <ul>
  <p><b>For the monitored devices:</b>
   <a id="readingsChange2-attr-readingsChange2"></a>
   <li>readingsChange2<br/>
   <p>For the devices meeting <i>devspec</i> of readingsChange2, the list of the possible attributes is automatically extended by this additional entry. The attribute is read line by line, each line starting with the exact reading name that may be changed.</p>
   <p>Example:<br>
       <code>attr &lt;dev&gt; readingsChange2 abc (\d+\.\d*) $1\<br>
                    temperature  (-?\d+\.?\d*).* $1 { FHEM::readingsChange2::compareAbs("$name","$reading","$1",'25','10') }\<br>
                    def { perlfn1() }
       </code></p>
    <ul>The following syntaxes are supported:
    <li>
   <code>&lt;readingname&gt; &lt;regexp&gt; &lt;replacement&gt;</code>
    </li>
    <li>
   <code>&lt;readingname&gt; &lt;regexp&gt; &lt;perlfunction&gt;</code>
    </li>
    <li>
   <code>&lt;readingname&gt; &lt;perlfunction&gt;</code>
    </li>
    </ul>
    <ul>Notes:
    <li><i>readingname</i> <b>must exactly match</b> the reading name in the event. <i>state</i> will be automatically added as reading name as well for stateEvents.
    </li>
    <li>When <i>regexp</i> is set, the resulting group elements ($1 etc.) will be extrapolated in <i>replacement</i> and <i>perlfunction</i> (pior to execution, so using quotes to avoid bareword warnings may be required). <i>regexp</i> must not contain any blanks or spaces!
    </li>
    <li>If there's no result (real <code>undef</code>) the reading will be deleted and the event presented to further notify functions will be reduced to an empty string!
    </li>
    <li><i>perlfunction</i>
      <ul>
        <li>The following variables may be used: <i>$name</i> (the device name the reading belongs to), <i>$reading</i> (the name of the respective reading) and <i>$value</i> (the original value as provided in event). So e.g. the second example may be used to limit the temperature values to 10 degrees +/- 25 degrees = range from -15 to +35.
        </li>
        <li>If a SCALAR is returned, this will be interpreted as new value for the reading to change.
        </li>
        <li>If a HASH is returned, all key/value-pairs will be used as (additional) readings. If the original reading name is also a key name, it's assigned value will be used as new reading value, if it is not in the hash keys, the reading value will be deleted (and the corresponding event cleared).
        </li>
      </ul>
    </li>
    </ul>
  </li>
  </ul>

  <a id="readingsChange2-functions"></a>
  <h4>Functions provided by readingsChange2:</h4>

  <ul>
  <a id="readingsChange2-functions-compareAbs"></a>
  <li><b>FHEM::readingsChange2::compareAbs</b><br>
  <code>FHEM::readingsChange2::compareAbs($$$,$$)</code><br>
  Compare nummeric value provided by last argument (defaults to OldReadingsNum() (has to be set up first!), if not handed over). Syntax is <code>FHEM::readingsChange2::compareAbs($name,$reading,$value,&lt;maximum of abs difference&gt;,&lt;old value to compare to&gt;)</code>. <i>maximum of abs difference</i> defaults to 10. If the new <i>$value</i> is not in the range of old value +/- difference, <i>undef</i> is returned.
  </li>
  <a id="readingsChange2-functions-compareRel"></a>
  <li><b>FHEM::readingsChange2::compareRel</b><br>
  <code>FHEM::readingsChange2::compareRel($$$,$$)</code><br>
  Compare nummeric value provided by by last argument (defaults to OldReadingsNum() (has to be set up first!), if not handed over). Syntax is <code>FHEM::readingsChange2::compareRel($name,$reading,$value,&lt;maximum of relative difference&gt;,&lt;old value to compare to&gt;)</code>. <i>maximum of relative difference</i> defaults to 10 (%). If the new <i>$value</i> is not in the range of old value +/- difference in percent, <i>undef</i> is returned.
  </li>
  <a id="readingsChange2-functions-compareAbsAndRel"></a>
  <li><b>FHEM::readingsChange2::compareAbsAndRel</b><br>
  <code>FHEM::readingsChange2::compareAbsAndRel($$$,$$$)</code><br>
  Compare nummeric value provided by last argument (defaults to OldReadingsNum() (has to be set up first!), if not handed over). Syntax is <code>FHEM::readingsChange2::compareAbsAndRel($name,$reading,$value,&lt;maximum of abs difference&gt;,&lt;&lt;maximum of relative difference&gt;,&lt;old value to compare to&gt;)</code>. Explanation of the arguments see preceding functions.
  </li>
  </ul>
</ul>
=end html

=cut
