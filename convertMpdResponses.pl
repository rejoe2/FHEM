#!/usr/bin/perl

#echo list album group albumartist | nc -q 1 192.168.xx.xx 6600 > mpd_contents.txt
#perl ./convertMpdResponses.pl mpd_contents.txt > mpd_contents_out.txt
#echo listplaylists | nc -q 1 192.168.xx.xx 6600 > mpd_playlists.txt
#perl ./convertMpdResponses.pl mpd_playlists.txt > mpd_playlists_out.txt

use strict;
use warnings;

my ($artists, $artist, @playlists);
my $maxartists = 10;

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
my @artlist = sort {
        $artists->{$b}{cnt} <=> $artists->{$a}{cnt}
        or
        $artists->{$a} <=> $artists->{$b}
        }  keys %{$artists};

printf("Artists section \n\n") if @artlist;
for my $i (0..$maxartists-1) {
    printf("( ( %s ):%s )\n", $artlist[$i], $artlist[$i]);
}

printf("\nAlbums section \n\n") if @artlist;
for my $i (0..$maxartists-1) {
    for my $alb ( @{$artists->{$artlist[$i]}->{albums}} ) {
        printf("( ( %s ):%s )\n", $alb, $alb);
    };
}

1;

__END__
