#!/usr/bin/perl

#perl ./getMpdSlots.pl > mpd_contents_out.txt

use strict;
use warnings;
use IO::Socket;

my $host = '127.0.0.1';
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
return $! if !$sock;

printf("sock ok\n");

while (<$sock>)  # MPD rede mit mir , egal was ;)
 { last if $_ ; } # end of output.

chomp $_;

return  "not a valid mpd server, welcome string was: $_." if $_ !~ m{\AOK MPD (.+)\z};

if ($password ne '') {
  # lets try to authenticate with a password
  print $sock "password $password\r\n";
  while (<$sock>) { last if $_ ; } # end of output.

  chomp;

  if ( $_ !~ m{\AOK\z} ) {
    print $sock "close\n";
    close($sock);
    return "password auth failed : $_." ;
  }
}

my ($artists, $artist, @playlists);

#start playlist request
print $sock "listplaylists\r\n";
while (<$sock>) {
  return  "ACK ERROR $_" if $_ =~ s/^ACK //; # oops - error.
  last if $_ =~ m/^OK/;    # end of output.

  if ( $_ =~ m{\A(?:playlist[:]\s)(.+)} ) {
    push @playlists, $_;
  }
}

print $sock "list album group albumartist\r\n";
while (<$sock>) {
  return  "ACK ERROR $_" if $_ =~ s/^ACK //; # oops - error.
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
