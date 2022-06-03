#!/usr/bin/perl

#echo list album group albumartist | nc -q 1 192.168.xx.xx 6600 > mpd_contents.txt
#perl ./convertMpdResponses.pl mpd_contents.txt > mpd_contents_out.txt
#echo listplaylists | nc -q 1 192.168.xx.xx 6600 > mpd_playlists.txt
#perl ./convertMpdResponses.pl mpd_playlists.txt > mpd_playlists_out.txt

use strict;
use warnings;

my ($artists, $artist, @playlists);
my $maxartists = 50;

while ( my $l = <> ) {

  if ( $l =~ m{\A(?:playlist[:]\s)(.+)} ) {
    push @playlists, $1;
  }
  if ( $l =~ m{\A(?:AlbumArtist[:]\s)(.*)} ) {
    $artist = $1;
  }
  if ( $l =~ m{\A(?:Album[:]\s)(.*)} ) {
    next if !$artist || !$1 || $artist eq "Various Artists";
    $artists->{$artist}->{cnt}++;
    push @{$artists->{$artist}->{albums}}, $1;
  }
}

printf("Playlists section \n\n") if @playlists;
for ( @playlists ) {
    printf("( ( %s ):%s )\n", $_, $_);
}

printf("\n") if @playlists;

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


1;

__END__
