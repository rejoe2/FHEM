#!/usr/bin/perl

#perl ./getMpdSlots.pl > mpd_contents_out.txt

use strict;
use warnings;
use IO::Socket;

my $host = '192.168.2.91';
my $port = '6600'; #default
my $timeout = 2;
my $password = '';

my $maxartists = 10;

my $sock = IO::Socket::INET->new(
    PeerHost => $host,
    PeerPort => $port,
    Proto    => 'tcp',
    Timeout  => $timeout
    );

printf("started\n");
die $! if !$sock;

printf("sock ok\n");

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

my ($artists, $artist, @playlists);

#start playlist request
print $sock "listplaylists\r\n";
while (<$sock>) {
  die  "ACK ERROR $_" if $_ =~ s/^ACK //; # oops - error.
  last if $_ =~ m/^OK/;    # end of output.

  if ( $_ =~ m{\A(?:playlist[:]\s)(.+)} ) {
    push @playlists, $1;
  }
}

print $sock "list album group albumartist\r\n";
while (<$sock>) {
  die "ACK ERROR $_" if $_ =~ s/^ACK //; # oops - error.
  last if $_ =~ m/^OK/;    # end of output.

  if ( $_ =~ m{\A(?:AlbumArtist[:]\s)(.*)} ) {
    $artist = $1;
  }
  if ( $_ =~ m{\A(?:Album[:]\s)(.*)} ) {
    next if !$artist || !$1 || $artist eq "Various Artists";
    $artists->{$artist}->{cnt}++;
    push @{$artists->{$artist}->{albums}}, $1;
  }
}

#got all data?
 print $sock "close\n";
 close($sock); 


printf("Playlists section \n\n") if @playlists;
for ( @playlists ) {
    printf("( ( %s ):%s )\n", $_, $_);
}

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
    $text =~ s{[\(\),.:_`´/!<>?\[\]\{\}]}{ }g;
    $text =~ s{\A\s*The}{[The]}i;

    return $text;
}

printf("\n") if @playlists;
my @artlist = sort {
        $artists->{$b}{cnt} <=> $artists->{$a}{cnt}
        or
        $artists->{$a} <=> $artists->{$b}
        }  keys %{$artists};

printf("Artists section \n\n") if @artlist;
for my $i (0..$maxartists-1) {
    my $lcart = cleanup($artlist[$i]);
    $artists->{$artlist[$i]}->{clean} = $lcart;
    printf("( ( %s ):%s )\n", $lcart, $artlist[$i]);
    for my $alb ( @{$artists->{$artlist[$i]}->{albums}} ) {
        $albums->{$alb} = $alb;
    };
}
for my $alb ( sort keys %{$albums} ) {
        $albums->{$alb} = cleanup($alb, 1);
    };


printf("\nAlbums section \n\n") if @artlist;

for my $alb (sort keys %{$albums}) {
    printf("( ( %s ):%s )\n", $albums->{$alb}, $alb);
}

printf("\nAlbums +artist section \n\n") if @artlist;
for my $i (0..$maxartists-1) {
    my $lcart = $artists->{$artlist[$i]}->{clean};
    for my $alb ( @{$artists->{$artlist[$i]}->{albums}} ) {
        printf("( ( %s ):%s ){Album} <by> ( ( %s ):%s ){AlbumArtist}\n", $albums->{$alb}, $alb, $lcart, $artlist[$i])
    }
}


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