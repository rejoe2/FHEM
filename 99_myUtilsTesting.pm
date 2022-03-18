##############################################
# $Id: myUtilsTemplate.pm 21509 2020-03-25 11:20:51Z rudolfkoenig $
#
# Save this file as 99_myUtils.pm, and create your own functions in the new
# file. They are then available in every Perl expression.

package main;

use strict;
use warnings;

sub
myUtilsTesting_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

sub split_tester {
  my $EVENT = shift;
#'missed_call: 0123456789 (Willi Mueller)';;
  my @mc = split m{:}xs, $EVENT;
  return "1: $mc[1]";
}

sub min_tester {
  return min(@_);
}

sub myUptime {
  my $param = shift;
  my $uptime = q{uptime};
  my $a3 = sub  { my $r = qx($uptime &); $r .= " FHEM: ".fhem($uptime); return $r};
  my $sr2cmnd = {
    8 => \&$a3
  };
  my $ret;
  return $ret = $sr2cmnd->{$param}->() if ref $sr2cmnd->{$param} eq 'CODE';
  return "Da ist was schief gegangen";
}

#https://forum.fhem.de/index.php/topic,84016.0/topicseen.html
sub startCountdown($;$$) {
  my $name = shift // return
  my $duration = shift;
  my $interval = shift // 30;
                                 
  my $hash = $name;               
  $hash = $defs{$name} if ref $hash ne 'HASH';
  $name = $hash->{NAME};         

  if( !$hash ) {                 
    Log3( $name, 2, "startCountdown error: no such device: $name" );
    return;                       
  }                               

  Log3( $name, 4, "startCountdown for: $name" );

  my $remaining;                 
  if( !defined $duration ) {     
    my $state = ReadingsVal($name, 'state', undef);
    if( $state eq 'off' ) {       
      stopCountdown($name);       
      return;                     
    } 
	if( defined ReadingsVal($name, 'timerDuration', undef) ) {
      return;                     
    };                           

    $duration = '<unknown>';     
    if( my $TIMED_OnOff = $hash->{TIMED_OnOff} ) {
      $duration = $TIMED_OnOff->{DURATION};
      $remaining = $TIMED_OnOff->{START} + $TIMED_OnOff->{DURATION} - time();
    } elsif( $state =~ m/set_o[nf]+-for-timer (\d+)/ ) {
      $duration = $1;
      $remaining = $1;
    }                             
  }                               

  if( $duration ne '<unknown>' ) {
    if( $duration <= 0 ) {
      stopCountdown($hash);
      return;
    }

    readingsSingleUpdate($hash, 'timerDuration', $duration, 1);
    updateCountdown($hash, $remaining, $interval);
  } else {
    readingsSingleUpdate($hash, 'timerDuration', $duration, 1);
  }                               
  return;                         
}                                 
                                 
sub updateCountdown($;$$) {           
  my $name = shift //return;
  my $remaining = shift;
  my $interval = shift // 30;

  my $hash = $name;               
  $hash = $defs{$name} if( ref($hash) ne 'HASH' );
  $name = $hash->{NAME};         

  if( !$hash ) {                 
    Log3 $name, 2, "updateCountdown error: no such device: $name";
    return;                       
  }                               

  if( !defined($remaining) ) {
    $remaining = '<unknown>';

    if( my $TIMED_OnOff = $hash->{TIMED_OnOff} ) {
      $remaining = $TIMED_OnOff->{START} + $TIMED_OnOff->{DURATION} - time();
    } else {
      $remaining = ReadingsVal($name, 'timerDuration', undef);
      if( $remaining ne '<unknown>' ) {
        my $age = ReadingsAge($name, 'timerDuration', undef);
        $remaining = $remaining - $age;
      }
    }
  }
                                 
  Log3( $name, 4, "updateCountdown: remaining $remaining");
  if ( $remaining ne '<unknown>' ) {
    if( $remaining <= 0 ) {
      stopCountdown($name);
      return;
    }

    readingsSingleUpdate($hash, 'timerRemaining', int($remaining), 1);
    InternalTimer( gettimeofday() + $interval, 'updateCountdown', $hash);
  }
}

sub stopCountdown($) {               
  my $name = shift // return;                 
     
  my $hash = $name;
  $hash = $defs{$name} if ref $hash ne 'HASH';
  $name = $hash->{NAME};
         
  if( !$hash ) {
    Log3( $name, 2, "stopCountdown error: no such device: $name" );
    return;
  }

  Log3( $name, 4, "stopCountdown for: $name" );

  readingsSingleUpdate($hash, 'timerRemaining', 0, 1);

  RemoveInternalTimer( $hash, 'updateCountdown' );
  CommandDeleteReading( undef, "$name timerDuration" );
  CommandDeleteReading( undef, "$name timerRemaining" );

  return;                         
}

sub
notifyRegexpChanged2a
{
  my ($hash, $re, $disableNotifyFn) = @_;

  %ntfyHash = ();
  if($disableNotifyFn) {
    delete($hash->{NOTIFYDEV});
    $hash->{disableNotifyFn}=1;
    return;
  }
  delete($hash->{disableNotifyFn});
  my $first = 1;
  my $outer = $re =~ m{\A\s*\((.+)\)\s*\z}x; #check if outer brackets are given
  my @list;
  my $numdef = keys %defs;
  while ($re) {
    (my $dev, $re) = split m{:}x, $re, 2; #get the first seperator for device/reading+rest?
    if ( $first && $outer ) {
		$first = 0;
		my $ops = $dev =~ tr/(//;
		my $clos = $dev =~ tr/)//;
		if ( $ops > $clos ) {
			chop($re);
			$dev =~ s{\A.}{}x;
		}
	}
	$dev =~ s{\A\s*\((.+)\)\s*\z}{$1}x; #remove outer brackets if given
	#Log3('global',3 , "re splitted to $dev and $re") if $re;
    return delete $hash->{NOTIFYDEV} if $dev eq '.*';

    while ($dev) {
      (my $part, $dev) = splitByPipe($dev);
      #Log3('global',3 , "dev splitted to $part and $dev") if $dev;

      return delete $hash->{NOTIFYDEV} if $part eq '.*';
      my @darr = devspec2array($part);
      return delete $hash->{NOTIFYDEV} if !@darr || !$defs{$part} && $darr[0] eq $part || $numdef == @darr;
      @list = (@list, @darr);
    }
    (undef, $re) = splitByPipe($re);
  }
  return delete($hash->{NOTIFYDEV}) if !@list;
  my %h = map { $_ => 1 } @list;
  @list = keys %h; # remove duplicates
  $hash->{NOTIFYDEV} = join q{,}, @list;
  return;
}

sub splitByPipea {
    my $string = shift // return (undef,undef);
    # String in pipe-getrennte Tokens teilen, wenn die Klammerebene 0 ist
    my $lastChar = q{x};
    my $bracketLevel = 0;
    my $token = q{};
    my @chars = split q{}, $string;
    my $i = 0;
	my $repl;
    for my $char ( @chars ) {
		#Log3('global',3,"char is $char, last was $lastChar, level is $bracketLevel");
		if ($char eq '|' && $lastChar ne '\\' && !$bracketLevel) {
            $repl = "$token" . q{|};
		    $repl =~ s{[{()}|*]}{.}g;
            $string =~ s{\A$repl}{}x;
            return ($token, $string);
        }
        $i++;
        if ($char eq q<(> && $lastChar ne '\\') {
            $bracketLevel++;
        }
        elsif ($char eq q<)> && $lastChar ne '\\') {
            $bracketLevel--;
        }
        $token .= $char;
        if ( $i == scalar @chars ) {
	      $repl = $token;
          $repl =~ s{[{}()\|\*]}{.}g;
          $string =~ s{\A$repl}{}x;
        }
        $lastChar = $char;
    }
    return ($token, $string);
}


sub SetAllOn($$){
my ($Raum,$Typ) = @_;
Log3('rhasspy',3 , "RHASSPY: Raum $Raum, Typ $Typ");
return "RHASSPY: Raum $Raum, Typ $Typ";
}

sub Respeak {
my $name = shift // "Rhasspie";
my $Response = ReadingsVal($name,"voiceResponse","Ich kann mich nicht mehr erinnern");

Log3($name, 3, "This was Respeak with $name, $Response");

return $Response;
}

sub testrepl {
my $str='$var1un_d$off'; my $var1= 'hi'; my $off = 'zu';
my %specials = (
var1=>$var1, off=>$off
);

for my $special ( sort { length $b <=> length $a } keys %specials) {
    $str =~ s/\$$special/$specials{$special}/g;
  }
   
return $str;
}

sub genericDeviceType2appOption {
    my $device = shift // return;
	return if !$defs{$device};
	my $TYPE = InternalVal($device,'TYPE',undef) // return;
	my $gDT  = AttrVal($device,'genericDeviceType',undef) // return;
    my $str='{ "template: "';
	
	my %gDT2template = (
		lightHUEDevice => 'dimmer3', 
		light 		   => 'dimmer', 
		switch 		   => 'switch',
		thermometer	   => 'thermometer',
		thermostat	   => 'thermostat',
		shutter		   => 'shutter'
	);
	my $str2 = $gDT2template{"${gDT}$TYPE"} // $gDT2template{$gDT} // return;
	$str .= $str2;
	$str .= '", "room": "';
	$str2 = AttrVal($device,'room','unknown');
	$str2 = (split m{,}, $str2)[0];
    $str .= $str2;
	my ($arr, $extras) = parseParams(AttrVal($device,'appOptions2',''));
	for (keys %{$extras}) {
		$str .= qq(", "$_": "$extras->{$_});
	}
	$str .= '" }';
	return $str;
}

1;
