#!/usr/bin/perl

#perl ./getMpdSlots.pl > mpd_contents_out.txt

use strict;
use warnings;
use IO::Socket;
use Scalar::Util qw(looks_like_number);

$| = 1; #https://stackoverflow.com/questions/50688298/how-to-redirect-this-perl-scripts-output-to-file#

my $host = '127.0.0.10';
my $port = '6600'; #default
my $timeout = 2;
my $password = '';

my $mode = shift @ARGV;
# 0 = print all, 1 = playlist, 2 = genres, 3 = artists 4 = albums 5 = artists+albums

$mode = 0 if !defined $mode || !looks_like_number($mode);

my $maxartists = 10;
my $ignArtists = qr{De.Vision}mi;
my $ignAlbums = qr{\d\d\d\d-\d\d-\d\d|\d\d-\d\d-\d\d\d\d}m;

my $sock = IO::Socket::INET->new(
    PeerHost => $host,
    PeerPort => $port,
    Proto    => 'tcp',
    Timeout  => $timeout
    );

#printf("started in mode $mode\n") if $mode;
printf("started\n") if !$mode;
die $! if !$sock;

printf("sock ok\n")  if !$mode;

while (<$sock>)  # MPD rede mit mir , egal was ;)
 { last if $_ ; } # end of output.

chomp $_;

die  "not a valid mpd server, welcome string was: $_." if $_ !~ m{\AOK MPD (.+)\z};

if ($password ne '') {
  # lets try to authenticate with a password
  print $sock "password $password\r\n";
  while (<$sock>) { last if $_ ; } # end of output.

  chomp;

  if ( $_ !~ m{\AOK\z} ) {
    print $sock "close\n";
    close($sock);
    die "password auth failed : $_." ;
  }
}

my ($artists, $artist, @playlists, @genres);

#start playlist request
print $sock "listplaylists\r\n"  if !$mode;
while (<$sock>) {
  last if $mode > 1;
  die  "ACK ERROR $_" if $_ =~ s/^ACK //; # oops - error.
  last if $_ =~ m/^OK/;    # end of output.

  if ( $_ =~ m{\A(?:playlist[:]\s)(.+)} ) {
    push @playlists, $1;
  }
}


#start genre request
print $sock "list genre\r\n"  if !$mode || $mode == 1;
while (<$sock>) {
  last if $mode > 1;
  die  "ACK ERROR $_" if $_ =~ s/^ACK //; # oops - error.
  last if $_ =~ m/^OK/;    # end of output

  if ( $_ =~ m{\A(?:Genre[:]\s)(.+)} ) {
    my $gre = $1;
    $gre = undef if $gre && $gre =~ m{\A\s*\(*\d+\)*\s*\z}x;
    $gre = undef if $gre && length($gre)<4;
    $gre = undef if $gre && $gre eq '<unknown>';
    push @genres, $gre if $gre;
  }
}


print $sock "list album group albumartist group musicbrainz_albumid group musicbrainz_albumartistid\r\n"  if !$mode || $mode > 1;

my $albm;

while (<$sock>) {
  die "ACK ERROR $_" if $_ =~ s/^ACK //; # oops - error.
  last if $_ =~ m/^OK/;    # end of output.

  if ( $_ =~ m{\A(?:AlbumArtist[:]\s)(.*)} ) {
    $artist = $1;
    $artist = undef if $artist =~ $ignArtists;
  }
  if ( $_ =~ m{\A(?:Album[:]\s)(.*)} ) {
    next if !$artist || !$1 || $artist eq "Various Artists";
    $albm = $1;
    $albm = undef if $albm =~ $ignAlbums;

    if ( $albm ) {
        $artists->{$artist}->{cnt}++;
        push @{$artists->{$artist}->{albums}}, $albm;
    }
  }
  if ( $_ =~ m{\A(?:MUSICBRAINZ_ALBUMID[:]\s)(.*)} ) {
    next if !$artist || !$1 || $artist eq "Various Artists";
    next if !$albm;
    $artists->{$artist}->{mbid}->{$albm} = $1;
    $albm = undef;
    
  }
  if ( $_ =~ m{\A(?:MUSICBRAINZ_ALBUMARTISTID[:]\s)(.*)} ) {
    next if !$artist || !$1 || $artist eq "Various Artists";
    next if !$albm;
    $artists->{$artist}->{mbaid}->{$albm} = $1;
  }

}

#got all data?
 print $sock "close\n";
 close($sock); 


printf("Playlists section \n\n") if @playlists && !$mode;
for ( @playlists ) {
    last if $mode && $mode > 1;
    printf("( ( %s ):(%s) )\n", $_, $_);
}

#die if $mode && $mode == 1;
exit(0) if $mode && $mode == 1;

printf("Genre section \n\n") if @playlists && ( !$mode || $mode == 2 );
for ( @genres ) {
    last if $mode && $mode > 2;
    my $genr = $_;
    my $genr1 = $_;
    $genr =~ s{[\(\),.:_`´ /!<>?\[\]\{\}&+']}{ }g;
    $genr1 =~ s{[-\(\),:_`´ /!<>?\[\]\{\}&+']}{.}g;
    printf("( ( %s ):(%s) )\n", $genr, $genr1);
}
printf("\n") if @genres && !$mode;


exit(0) if $mode && $mode == 2;


my $albums;

sub cleanup {
    my $text  = shift // return;
    my $isalb = shift;

    my $trfrm = {
      I    => 'one',        II    => 'two',          III   => 'three', 
      IV   => 'four',       V     => 'five',         VI    => 'six', 
      VII  => 'seven',      VIII  => 'eight',        IX    => 'nine',
      X    => 'ten',        XI    => 'eleven',       XII   => 'twelve',
      XIII => 'thir teen',  XIV   => 'four teen',    XV    => 'fif teen',
      XVI  => 'six teen',   XVII  => 'seven teen',   XVIII => 'eight teen',
      XIX  => 'nine teen',  XX    => 'twenty',       XXI   => 'twenty one',
      XXII => 'twenty two', XXIII => 'twenty three', XXIV  => 'twenty four',
      1  => 'one',        2  => 'two',           3 => 'three', 
      4  => 'four',       5  => 'five',          6 => 'six', 
      7  => 'seven',      8  => 'eight',         9 => 'nine',
      10 => 'ten',        11 => 'eleven',       12 => 'twelve',
      13 => 'thir teen',  14 => 'four teen',    15 => 'fif teen',
      16 => 'six teen',   17 => 'seven teen',   18 => 'eight teen',
      19 => 'nine teen',  20 => 'twenty',       21 => 'twenty one',
      22 => 'twenty two', 23 => 'twenty three', 24 => 'twenty four',
    };

    if ( $isalb ) {
        if ( $text =~ m{\s+I\z}x ) {
            if ( defined $albums->{"${text}I"} ) {
                chop $text;
                $text .= $trfrm->{I};
            }
        } else {
            if ( $text =~ m{(?:\s+)([IXV0-9]+)\z} && defined $trfrm->{$1} ) {
                $text =~ s{(.*\s+)([IXV0-9]+)\z}{${1}$trfrm->{$2}};
            }
        }
    }
    $text =~ s{[+]}{ plus }g;
    $text =~ s{[&]}{ and }g;
    $text =~ s{[\(\),.:_`´"/!<>?\[\]\{\}]}{ }g;
    if ( $isalb  ) {
        $text =~ s{\s+[']\s+}{};
        $text =~ s{\s+[-]\s+}{ };
        $text =~ s{\s+[']n\s+}{ and };
        $text =~ s{(\d{2,4})-(\d{2,4})}{$1 <to> $1};
    }
    $text =~ s{\A\s*The\s+}{[The] }i;

    return $text;
}

sub cleanup2 {
    my $text  = shift // return;
    $text =~ s{[\(\),.:_`´ /!<>?\[\]\{\}&+"']}{.}g;
    return $text;
}

printf("\n") if @playlists && !$mode;

my @artlist = sort {
        $artists->{$b}{cnt} <=> $artists->{$a}{cnt}
        or
        $artists->{$a} <=> $artists->{$b}
        }  keys %{$artists};

printf("Artists section \n\n") if @artlist && !$mode;

for my $i (0..$maxartists-1) {
    my $lcart = cleanup($artlist[$i]);
    $artists->{$artlist[$i]}->{clean} = $lcart;
    $lcart = cleanup2($artlist[$i]);
    $artists->{$artlist[$i]}->{regex} = $lcart;
    printf("( ( %s ):(%s) )\n", $lcart, $artlist[$i]) if !$mode || $mode == 2;
    for my $alb ( @{$artists->{$artlist[$i]}->{albums}} ) {
        my $id = $artists->{$artlist[$i]}->{mbid}->{$alb} // $alb;
        $albums->{$alb} = $id;
    };
}

die if $mode && $mode == 3; 

my $ids;
for my $alb ( sort keys %{$albums} ) {
    $ids->{$alb} = $albums->{$alb} if $albums->{$alb} ne $alb;
    $albums->{$alb} = cleanup($alb, 1);
};


printf("\nAlbums section \n\n") if @artlist && !$mode;

for my $alb (sort keys %{$albums}) {
    last if $mode && $mode ne '3';
    if ( defined $ids->{$alb} ) {
        printf("( ( %s ):(%s) ){AlbumId}\n", $albums->{$alb}, $ids->{$alb});
    } else {
        my $cleaned = cleanup2($alb);
        printf("( ( %s ):(%s) ){Album}\n", $albums->{$alb}, $cleaned);
    }
}

die if $mode && $mode == 4; 

printf("\nAlbums +artist section \n\n") if @artlist && !$mode;
for my $i (0..$maxartists-1) {
    my $lcart = $artists->{$artlist[$i]}->{clean};
    for my $alb ( @{$artists->{$artlist[$i]}->{albums}} ) {
        if ( defined $artists->{$artlist[$i]}->{mbid} && defined $artists->{$artlist[$i]}->{mbid}->{$alb} ) {
            my $id = $artists->{$artlist[$i]}->{mbid}->{$alb};
            if (defined $artists->{$artlist[$i]}->{mbaid} && defined $artists->{$artlist[$i]}->{mbaid}->{$alb}) {
                printf("( ( %s ):(%s) ){AlbumId} [<by> ( ( %s ):(%s) ){AlbumArtistId}]\n",$albums->{$alb}, $id,  $lcart, $artists->{$artlist[$i]}->{mbaid}->{$alb});
            } else {
                printf("( ( %s ):(%s) ){AlbumId} [<by> ( ( %s ):(%s) ){AlbumArtist}]\n",$albums->{$alb}, $id,  $lcart, $artists->{$artlist[$i]}->{regex});
            }
        } else {
            my $cleaned = cleanup2($alb);
            printf("( ( %s ):(%s) ){Album} [<by> ( ( %s ):(%s) ){AlbumArtist}]\n",$albums->{$alb}, $cleaned,  $lcart, $artists->{$artlist[$i]}->{regex})
        }
    }
}

exit(0);

__END__

copyright:

This script was developed for usage together with FHEM, and contains some code-snippets from the 73_MPD.pm module for FHEM. 
FHEM itself and 73_MPD.pm are licended under GPL, as this piece of code is as well:

################################################################
#  This code is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
################################################################
