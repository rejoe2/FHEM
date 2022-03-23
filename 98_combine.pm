
# $Id: 98_combine.pm 21366 2020-03-06 12:01:05Z justme1968 $
#25 Juli 2021, 12:58:26 von justme1968, https://forum.fhem.de/index.php/topic,110165.0.html

package main;

use strict;
use warnings;

use vars qw($FW_ME);
use vars qw($FW_subdir);
use vars qw($FW_wname);
use vars qw($FW_cname);
use vars qw(%FW_webArgs); # all arguments specified in the GET

use FHEM::Meta;

sub
combine_Initialize($) {
  my ($hash) = @_;

  $hash->{DefFn}    = "combine_Define";
  $hash->{UndefFn}  = "combine_Undefine";
  $hash->{NotifyFn} = "combine_Notify";
  $hash->{AttrFn}   = "combine_Attr";
  $hash->{AttrList} = "disable:1,0 disabledForIntervals values $readingFnAttributes";

  $hash->{FW_deviceOverview} = 1;
  $hash->{FW_detailFn}  = "combine_detailFn";

  return FHEM::Meta::InitMod( __FILE__, $hash );
}

 sub
combine_Define($$) {
  my ($hash, $def) = @_;

  my @args = split("[ \t]+", $def);

  return $@ unless ( FHEM::Meta::SetInternals($hash) );

  my ($name, undef, @params) = @args;

  return "Usage: define <name> $hash->{TYPE} <device>:<reading> [<OP> <device1>:<reading1> [<OP> <device2>:<reading2> [...]]]"  if(@args < 2);

  $hash->{NOTIFYDEV} = "global";

  if( $init_done ) {
    combine_Init( $hash ) if( !IsDisabled($name) );
  }

  return;
}

sub
combine_UpdateFrontend($$$) {
  my ($hash, $item, $value) = @_;
  my $name  = $hash->{NAME};

  $hash->{changed} = 1;

  if( $hash->{alwaysTrigger} ) {
    DoTrigger( $name, "$item: $value" );

  } else {
    foreach my $ntfy (values(%defs)) {
      next if(!$ntfy->{TYPE} ||
              $ntfy->{TYPE} ne "FHEMWEB" ||
              !$ntfy->{inform} ||
              !$ntfy->{inform}{devices}{$name} ||
              $ntfy->{inform}{type} ne "status");
      next if( !$ntfy->{inform}{devices}{$name} );
      if(!FW_addToWritebuffer($ntfy,
          FW_longpollInfo($ntfy->{inform}{fmt}, "$name-$item", $value, $value ) ."\n" )) {
        my $name = $ntfy->{NAME};
        Log3 $name, 4, "Closing connection $name due to full buffer in FW_Notify";
        TcpServer_Close($ntfy, 1);
      }
      if(!FW_addToWritebuffer($ntfy,
          FW_longpollInfo($ntfy->{inform}{fmt}, "$name-$item-ts", "", TimeNow() ) ."\n" )) {
        my $name = $ntfy->{NAME};
        Log3 $name, 4, "Closing connection $name due to full buffer in FW_Notify";
        TcpServer_Close($ntfy, 1);
      }
    }

  }

}

sub
combine_Notify($$) {
  my ($hash,$dev) = @_;
  my $name  = $hash->{NAME};

  if( IsDisabled($name) > 0 ) {
    readingsSingleUpdate($hash, 'state', 'inactive', 1 ) if( ReadingsVal($name,'inactive','' ) ne 'disabled' );
    return;
  }

  if($dev->{NAME} eq "global") {
    if( grep(m/^INITIALIZED|REREADCFG$/, @{$dev->{CHANGED}}) ) {
      combine_Init($hash);

    } elsif( $init_done && grep(m/^DEFINED (.*)$/, @{$dev->{CHANGED}}) ) {
      CommandModify( undef, "$name $hash->{DEF}" );
      combine_Init($hash);

    } elsif( $init_done && grep(m/^RENAMED (.*) (.*)$/, @{$dev->{CHANGED}}) ) {
      CommandModify( undef, "$name $hash->{DEF}" );
      combine_Init($hash);

    } elsif( $init_done && grep(m/^DELETED (.*)$/, @{$dev->{CHANGED}}) ) {
      CommandModify( undef, "$name $hash->{DEF}" );
      combine_Init($hash);
    }

    return;
  };

  my $events = deviceEvents($dev,1);
  return if( !$events );

  if( defined($hash->{mayBeVisible})
      && !defined($FW_visibleDeviceHash{$name}) ) {
      delete $hash->{mayBeVisible};
  }

  my $changed;
  my $max = int(@{$events});
  for (my $i = 0; $i < $max; $i++) {
    my ($reading,$value) = split(": ",$events->[$i], 2);

    next if( !exists($hash->{helper}{watch}{"$dev->{NAME}:$reading"}) );

    $changed = 1;
    #$value = ($value =~ /(-?\d+(\.\d+)?)/ ? $1 : undef);
    $hash->{helper}{watch}{"$dev->{NAME}:$reading"} = combine_lookup($hash, $value);

    if( $hash->{mayBeVisible} ) {
      combine_UpdateFrontend( $hash, "$dev->{NAME}:$reading", $value );

      my $room = AttrVal($name, "room", "");
      my %extPage = ();
      (undef, undef, $value) = FW_devState($dev->{NAME}, $room, \%extPage);

      combine_UpdateFrontend( $hash, $dev->{NAME}, "<html>$value</html>" );
    }
  }

  combine_Combine($hash) if( $changed );

  return;
}

sub
combine_2html($)
{
  my($hash) = @_;
  $hash = $defs{$hash} if( ref($hash) ne 'HASH' );

  return undef if( !$hash );

  my $name = $hash->{NAME};
  my $room = $FW_webArgs{room};

  my $row = 1;
  my $ret = '';
  $ret .= "<table class='block wide' style='text-align:center'>";

  $ret .= sprintf("<tr class='%s'>", ($row++&1)?"odd":"even");
  if( defined($hash->{helper}) && defined($hash->{helper}{rules}) ) {
    my @rules = @{$hash->{helper}{rules}};
    while( @rules ) {
      my $item = shift @rules;
      my $op = shift @rules;

      my ($dev, $reading) = split( ':', $item, 2 );
      if( defined($reading) ) {
        my %extPage = ();
        my ($allSets, $cmdlist, $txt) = FW_devState($dev, $room, \%extPage);
        $ret .= "<td style='cursor:pointer' informId='$name-$dev'>$txt</td>";

      } else {
         $ret .= "<td>$dev</td>";
      }

      #$ret .= "<td></td>" if( defined($op) );
      #$ret .= "<td>$op</td>" if( defined($op) );
      $ret .= "<td>&#x2297;</td>" if( defined($op) );
    }
  }
  $ret .= "<td>=</td>";
  my %extPage = ();
  my ($allSets, $cmdlist, $txt) = FW_devState($name, $room, \%extPage);
  $ret .= "<td informId='$name'>". $txt ."</td>";
  $ret .= sprintf('</tr>');


  $ret .= sprintf("<tr class='%s'>", ($row++&1)?"odd":"even");
  if( defined($hash->{helper}) && defined($hash->{helper}{rules}) ) {
    my @rules = @{$hash->{helper}{rules}};
    while( @rules ) {
      my $item = shift @rules;
      my $op = shift @rules;

      $ret .= "<td>";
      $ret .= "<div informId='$name-$item'>$hash->{helper}{watch}{$item}</div>";
      $ret .= "<br>";
      $ret .= "<div>$item</div>";
      $ret .= "</td>";
      $ret .= "<td>$op</td>" if( defined($op) );
      #$ret .= "<td>&#x2297;</td>" if( defined($op) );
    }
  }
  $ret .= "<td>=</td>";
  $ret .= "<td>";
  $ret .= "<div informId='$name-$hash->{helper}{result_reading}'>". ReadingsVal($name, $hash->{helper}{result_reading}, '') ."</div>";
  $ret .= sprintf('<br>');
  $ret .= "<div>$name:$hash->{helper}{result_reading}</div>";
  $ret .= "</td>";
  $ret .= sprintf('</tr>');

  $ret .= "</table>";
  $ret .= "<br>";

  return $ret;
}

sub
combine_detailFn()
{
  my ($FW_wname, $d, $room, $pageHash) = @_; # pageHash is set for summaryFn.
  my $hash = $defs{$d};

  $hash->{mayBeVisible} = 1;

  my $html = combine_2html($d);

  return $html;
}

sub
combine_lookup($$) {
  my $hash = shift;
  my $val = shift // return undef;

  #if( $item =~ m/^(.*):(.*):(i|d|r|r\d)$/ ) {
  #my $format = $3;
  #$val = rgVal2Num($val);
  #$val = int($val) if( $format eq 'i' );
  #$val = round($val, defined($1) ? $1 : 1) if($format =~ /^r(\d)?/);
  #}

  if( $hash->{helper}{values_re} ) {
    foreach my $entry (@{$hash->{helper}{values_re}}) {
      $val = $entry->{to} if( $val =~m/$entry->{re}/ );
    }
  }
  $val = $hash->{helper}{values}{$val} if( defined($hash->{helper}{values}{$val}) );

  return $val;
}

sub
combine_Init($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  return if( !$init_done );

  my @params = split("[ \t]+", $hash->{DEF});

  my %watch;
  my @rules;
  my $prev_op;
  while( @params ) {
    my $item = shift @params;
    my $op = shift @params;

    my ($dev, $reading) = split( ':', $item, 2 );

    if( !defined($reading) ) {
      $watch{$item} = $item;
      push @rules, $item;
      push @rules, $op if( defined($op) && $op ne '=' );

    } elsif( !defined($defs{$dev}) )  {
      Log3 $hash, 2, "$name: missing operator for $dev" if( !defined($prev_op) );

      foreach my $d (devspec2array($dev)) {
        $watch{"$d:$reading"} = undef;
        push @rules, "$d:$reading";
        push @rules, $prev_op;
      }
      pop @rules;

    } else {
      $watch{$item} = undef;
      push @rules, $item;
      push @rules, $op if( defined($op) && $op ne '=' );
    }

    delete $hash->{helper}{result_cmd};
    delete $hash->{helper}{result_device};
    $hash->{helper}{result_reading} = 'state';

    if( $op eq '=' ) {
      my $result = shift @params;
      while( @params ) {
        $result .= ' '. shift @params;
      }

      if( $result =~ m/ / ) {
        $hash->{helper}{result_cmd} = $result;

      } elsif( $result =~ m/^{(.*)}$/ ) {
        $hash->{helper}{result_cmd} = $result;

      } else {
        my ($dev, $reading) = split(':', $result, 2 );

        if( defined($reading) ) {
          $hash->{helper}{result_device} = $dev;
          $hash->{helper}{result_reading} = $reading;
        } else {
          $hash->{helper}{result_reading} = $dev;
        }
      }
    }

    $prev_op = $op;
  }
  $hash->{helper}{watch} = \%watch;
  $hash->{helper}{rules} = \@rules;

  my $event_regexp = 'global';
  foreach my $item (keys %{$hash->{helper}{watch}}) {
    my ($dev, $reading) = split( ':', $item, 2 );
    next if( !defined($reading) );

    $event_regexp .= "|$dev:$reading.*";

    #$hash->{helper}{watch}{$item} = ReadingsNum( $dev, $reading, undef );
    $hash->{helper}{watch}{$item} = combine_lookup($hash, ReadingsVal( $dev, $reading, undef ) );

    if( !defined($hash->{helper}{watch}{$item}) ) {
      Log3 $hash, 3, "$name: no value for $item found";
    }
  }

  notifyRegexpChanged($hash, $event_regexp);

  combine_Combine( $hash );

  return;
}

sub
combine_Combine($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  return if( !$init_done );

  my @rules = @{$hash->{helper}{rules}};

  my $item = shift @rules;
  my $val = $hash->{helper}{watch}{$item};
  #my $val = lookup( $hash, $item );
  Log3 $hash, 5, "$name: $val";

  while( @rules ) {
    my $op = shift @rules;
    $item = shift @rules;

    my $val2 = $hash->{helper}{watch}{$item};
    #my $val2 = lookup( $hash, $item );
    Log3 $hash, 5, "$name: $op $val2";

    if( $op eq 'AND' || $op eq 'MIN' ) {
      $val = minNum( $val, $val2 );

    } elsif( $op eq 'OR' || $op eq 'MAX' ) {
      $val = maxNum( $val, $val2 );

    } elsif( $op eq 'XOR' ) {
      $val = $val && $val2 ? 0
           : !$val         ? $val2
           : !$val2        ? $val
           : 0;

    } elsif( $op eq 'PLUS' || $op eq '+' ) {
      $val += $val2;

    } elsif( $op eq 'MINUS' || $op eq '-' ) {
      $val -= $val2;

    } elsif( $op eq 'MULT' || $op eq '*' ) {
      $val *= $val2;

    } elsif( $op eq 'DIV' || $op eq '/' ) {
      $val /= $val2;

    } else {
      Log3 $hash, 2, "$name: unknown operator >$op<";
    }
  }
  Log3 $hash, 5, "$name: = $val";

  if( $hash->{helper}{result_device} ) {
    if( my $chash = $defs{$hash->{helper}{result_device}} ) {
      readingsSingleUpdate($chash, $hash->{helper}{result_reading}, $val, 1 );
    }

  } else {
    readingsSingleUpdate($hash, $hash->{helper}{result_reading}, $val, 1 );
  }

  if( $hash->{helper}{result_cmd} ) {
    my %specials= (
                     "%SELF" => $name,
                   "%RESULT" => $val,
                  );

    my $exec = EvalSpecials($hash->{helper}{result_cmd}, %specials);

    Log3 $name, 4, "$name: exec $exec";
    my $r = AnalyzeCommandChain(undef, $exec);
    Log3 $name, 3, "$name return value: $r" if($r);
  }

  return;
}

sub
combine_Attr($$$)
{
  my ($cmd, $name, $attrName, $attrVal) = @_;
  my $hash = $defs{$name};

  my $orig = $attrVal;

  if( $attrName eq "disable" ) {
    my $hash = $defs{$name};
    if( $cmd eq 'set' && $attrVal ne "0" ) {
      readingsSingleUpdate($hash, 'state', 'disabled', 1 );

    } else {
      $attr{$name}{$attrName} = 0;
      readingsSingleUpdate($hash, 'state', 'active', 1 );
      combine_Init($hash);
    }

  } elsif( $attrName eq "disabledForIntervals" ) {
    my $hash = $defs{$name};
    if( $cmd eq 'set' ) {
      $attr{$name}{$attrName} = $attrVal;

    } else {
      $attr{$name}{$attrName} = "";
    }

    readingsSingleUpdate($hash, 'state', IsDisabled($name)?'disabled':'active', 1 );
    combine_Init($hash) if( !IsDisabled($name) );

  } elsif( $attrName eq "values" ) {
     delete $hash->{helper}{values_re};

    my %values;
    my @values_re;

    foreach my $item ( split(/;|\s+/, $attrVal) ) {
      my($from, $to) = split( ':', $item, 2 );

      if( $from =~ m'^/(.*)/$' ) {
        push @values_re, { re => $1, to => $to };
      } else {
        $values{$from} = $to;
      }
    }

    $hash->{helper}{values} = \%values;
    $hash->{helper}{values_re} = \@values_re if( @values_re );

    combine_Init($hash);
  }

  if( $cmd eq 'set' ) {
    if( $orig ne $attrVal ) {
      $attr{$name}{$attrName} = $attrVal;
      return $attrName ." set to ". $attrVal;
    }
  }

  return;
}

sub
combine_Undefine($$) {
  my ($hash,$arg) = @_;

  return;
}

1;

__END__

=pod
=item helper
=item summary    combine multiple device:readings
=item summary_DE kombiniert mehrere device:readings

=begin html

<a id="combine"></a>
<h3>combine</h3>
<p>For examples on this module see <a href="https://forum.fhem.de/index.php/topic,110165.0.html">forum thread</a>.</p>

The idea is basically to provide a functionallity of "virtual channels" as known from Homematic actors. All "conditions" (reading values) from FHEM devices may be transfered to mathematical values and operations that finally can be used to control e.g. an actor.

See e.g. also this <a href="https://forum.fhem.de/index.php/topic,12672.0.html">forum thread</a> for an conceptual example.

durch die kombination und priorisierung lassen sich vorrangschaltungen bauen oder mit readings rechnen:

    treppenhausschaltung
    zeitgesteuert wird bei dunkelheit ein nachtlicht aktiviert, dieses wird bei erkannter bewegung heller und lässt sich über den lichtschalter überschreiben
    heizungsteuerung
    die gewünschte tempereratur lässt sich per fenster offen meldung absenken und über einen party-taster zeitweise erhöhen
    zirkulationspumpe mit nacht- und abweseheits schaltung
    verbräuche aufsummieren
    die verbrauchsreadings in unterschiedlichen devices werden aufsummiert
    zählen der häufigkeit von zuständen
    ...

 
wie schaut das ganze aus:
 
<a id="combine-define"></a>
<h4>Define</h4>
<p><code>define &lt;name&gt; combine &lt;device&gt;:&lt;reading&gt; [&lt;OP&gt; &lt;device1&gt;:&lt;reading1&gt; [&lt;OP&gt; &lt;device2&gt;:&lt;reading2&gt; [...]]]  [= &lt;result&gt;]</code></p>

statt lt;device&gt;:&lt;reading&gt; ist es auch möglich einen festen lt;wert&gt; anzugeben, lt;device&gt; kann eine regex sein. achtung:
das geht nur wenn lt;device&gt; nicht an erster stelle vorkommt weil es sonst der operator nicht bekannt ist. als workaround kann man an erster stelle einen festen (für den jeweiligen opeartor passenden) wert angeben. aktuell darf nur lt;device&gt; eine regex sein, lt;reading&gt; nicht.

&lt;OP&gt; kann sein: OR (= MAX), AND (= MIN), XOR, PLUS (+), MINUS (-), MULT (*), DIV (/)
 
nicht möglich weil werteberich nicht bekannt und unnötig weil statt dessen &lt;wert&gt; MINUS ... möglich ist. :
     OR_INVERS, AND_INVERS, PLUS_INVERS, MINUS_INVERS, INVERS_PLUS, INVERS_MINUS, INVERS_MULT
 
&lt;wert&gt;<result> kann sein:

    nicht angeben -> das ergebnis landet in state des &lt;combine&gt; devices
    &lt;reading&gt; -> das ergebnis landet im entsprechenden reading des <combine> device
    &lt;device&gt;:&lt;reading&gt; -> das ergebnis landet in &lt;reading&gt; von &lt;device&gt;
    ein beliebiges fhem kommando, z.b.: set &lt;name&gt; $RESULT
    $RESULT ist das aktuelle ergebnis
    das fhem kommando kann auch {perl} code sein


<a id="combine-attr"></a>
<h4>Attributes</h4>
<a id="combine-attr-values"></a>

über das values attribut lassen sich nicht-numerische reading werte in numerische verwandeln:
                   
Code: [Auswählen]

attr &lt;combine&gt; values present:30 absent:20 on:100 off:0 open:1 closed:0


in der device detail ansicht gibt es eine tabellarisch übersicht der beteiligten devices und der aktuellen werte. die jeweiligen devStateIcons lassen sich per klick normal bedienen.

=end html

=encoding utf8
=for :application/json;q=META.json 98_combine.pm
{
  "abstract": "combine multiple device:readings",
  "x_lang": {
    "de": {
      "abstract": "kombiniert mehrere device:readings"
    }
  },
  "resources": {
    "x_wiki": {
      "web": "https://wiki.fhem.de/wiki/..."
    }
  },
  "keywords": [
    "fhem-mod",
    "fhem-mod-helper"
  ],
  "release_status": "alpha",
  "x_fhem_maintainer": [
    "justme1968"
  ],
  "prereqs": {
    "runtime": {
      "requires": {
        "FHEM": 5.00918799,
        "perl": 5.014,
        "Meta": 0,
        "Data::Dumper": 0
      },
      "recommends": {
      },
      "suggests": {
      }
    }
  }
}
=end :application/json;q=META.json
=cut
