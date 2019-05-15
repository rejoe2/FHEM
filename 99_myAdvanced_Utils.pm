##############################################
# $Id: myAdvanced_Utils.pm 2019-05-15 Beta-User $
#

package main;

use strict;
use warnings;
use POSIX;

sub
myAdvanced_Utils_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

sub
myHHMMSS2sec($)
{
  my ($h,$m,$s) = split(":", shift);
  $m = 0 if(!$m);
  $s = 0 if(!$s);
  my $seconds = 3600*$h+60*$m+$s;
  return $seconds;
}


#found: https://forum.fhem.de/index.php/topic,85958.msg791048.html#msg791048
sub listInternalTimer(;$) {
    my ($p) = @_;
    my %cop;

    foreach my $e (@intAtA)
    {
        my $name = "";
        if (ref($e->{ARG}) eq "HASH")
        {
            if (exists($e->{ARG}{NAME}))
            {
                $name = $e->{ARG}{NAME};
            }
            elsif (exists($e->{ARG}{arg}))
            {
                $name = $e->{ARG}{arg};
            }           
        }
        elsif ((ref($e->{ARG}) eq "REF") && exists(${$e->{ARG}}->{hash}))
        {
            $name = ${$e->{ARG}}->{hash}{NAME};
        }
        elsif (ref($e->{ARG}) ne "REF")
        {
            $name = $e->{ARG};
        }
        my $time = strftime('%d.%m.%Y %H:%M:%S', localtime($e->{TRIGGERTIME}));
        my $function = sprintf("%-25s %-25s", $name, $e->{FN});
        my $line = "<td>".$e->{atNr}."</td><td>".$time."</td><td>".$function."</td>";

        if ('f' eq $p)
        {
            $cop{$function} = $line;
	}
        elsif ('t' eq $p)
        {
            $cop{$time} = $line;
	}
        else
        {
            $cop{$name." ".$e->{atNr}} = $line;
	}
    }

    my $ret = '<html><table width=50%>';
    $ret .= "<td><b>InternalTimer List</b></td>";
    $ret .= '</tr></tr>';
    $ret .= "<td><b>Number</b></td>";
    $ret .= "<td><b>Date/Time</b></td>";
    $ret .= "<td><b>Function</b></td>";
    $ret .= '</tr>';
   
    foreach my $k (sort keys %cop) {
        $ret .= "$cop{$k}";
        $ret .= '</tr>';
    }

    $ret .= '</table></html>';
    return $ret;
}

1;

=pod
=begin html

<a name="myAdvanced_Utils"></a>
<h3>myAdvanced_Utils</h3>
<ul>
  <b>listInternalTimer(;$)</b><br>
  <ul>
    <code>{ listInternalTimer("t") }</code>  -> shows InternalTimers sorted by time, earlier will be on top.
    <code>{ listInternalTimer("f") }</code>  -> sorts by function name.
    Without or all other arguments will show an unsorted list.
  </ul>
  <ul>
   
  </ul>
</ul>
=end html
=cut

