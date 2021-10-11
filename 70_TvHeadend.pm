# based on https://forum.fhem.de/index.php/topic,85932.0.html
# https://github.com/Quantum1337/70_Tvheadend.pm
# tvheadend api is available at https://github.com/dave-p/TVH-API-docs/wiki
# $Id: 70_TvHeadend.pm 2021-10-11 Beta-User$

package TvHeadend; ##no critic qw(Package)

use strict;
use warnings;
use Carp qw(carp);
use JSON qw(decode_json encode_json);
use Encode;
use HttpUtils;
use utf8;
use POSIX qw(strftime);

use GPUtils qw(:all);
use FHEM::Core::Authentication::Passwords qw(:ALL);

sub ::TvHeadend_Initialize { goto &Initialize }

my %sets = (
    DVREntryCreate => [],
    EPG            => [qw(noArg)],
    password       => [],
    removepassword => [qw(noArg)]
);

my %gets = (
    EPGQuery        => [],
    ChannelQuery    => [qw(noArg)],
    ConnectionQuery => [qw(noArg)]
);

BEGIN {

  GP_Import(qw(
    addToAttrList
    addToDevAttrList
    delFromDevAttrList
    readingsBeginUpdate
    readingsBulkUpdate
    readingsBulkUpdateIfChanged
    readingsEndUpdate
    Log3
    defs
    init_done
    InternalTimer
    RemoveInternalTimer
    CommandAttr
    CommandDeleteReading
    readingFnAttributes
    IsDisabled
    AttrVal
    getAllAttr
    ReadingsVal
    devspec2array
    HttpUtils_BlockingGet
    HttpUtils_NonblockingGet
  ))
};
#HttpUtils_Connect vorab als "ping"-Ersatz?

sub Initialize {
    my $hash = shift // return;

    $hash->{DefFn}       = \&Define;
    $hash->{UndefFn}     = \&Undefine;
    $hash->{DeleteFn}    = \&Delete;
    $hash->{SetFn}       = \&Set;
    $hash->{AttrFn}      = \&Attr;
    $hash->{GetFn}       = \&Get;
    $hash->{RenameFn}    = \&Rename;
    $hash->{parseParams} = 1;
    $hash->{AttrList} =
            "HTTPTimeout Username EPGVisibleItems:multiple-strict,Title,Subtitle,Summary,Description,ChannelName,ChannelNumber,StartTime,StopTime " .
            "PollingQueries:multiple-strict,ConnectionQuery " .
            "PollingInterval " .
            "EPGChannelList:multiple-strict,all " .
          $readingFnAttributes;
    return;
}

sub Define {
    my $hash = shift;
    my $anon = shift;
    my $h    = shift;
    #parseParams: my ( $hash, $a, $h ) = @_;

    my $name = shift @{$anon};
    my $type = shift @{$anon};
    
    return "Usage: define <NAME> $hash->{TYPE} <IP>:[<PORT>] [<USERNAME> <PASSWORD>]" if !@{$anon} && !keys %$h;
    my $address  = $h->{baseUrl}  // shift @{$anon} // q{http://127.0.0.1:9981};
    my $user     = $h->{user}     // shift @{$anon};
    my $password = $h->{password} // shift @{$anon};

    my @addr = split q{:}, $address;

    return "The specified ip address is not valid" if $addr[0] !~ m{\A[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\z}xms;
    $hash->{helper}{http}{ip} = $addr[0];

    if ( defined $addr[1]){
        return "The specified port is not valid" if $addr[1] !~ m{\A[0-9]+\z};
        $hash->{helper}{http}{port} = $addr[1];
    } else {
        $hash->{helper}{http}{port} = '9981';
    }

    if ( defined $user ){
        $hash->{DEF} = "baseUrl=$address";
        CommandAttr($hash, "$name Username $user");
        $hash->{helper}{'.pw'} = $password if $password;
    }

    return $init_done ? firstInit($hash) : InternalTimer(time+10, \&firstInit, $hash );
}

sub firstInit {
    my $hash = shift // return;

    my $name = $hash->{NAME};

    return InternalTimer(time+1, \&firstInit, $hash ) if !$init_done;
    RemoveInternalTimer($hash);

    $hash->{helper}->{passObj}  = FHEM::Core::Authentication::Passwords->new($hash->{TYPE});

    my $password = $hash->{helper}{'.pw'};

    if ( defined $password ) {
        my ($passResp,$passErr);
        ($passResp,$passErr) = $hash->{helper}->{passObj}->setStorePassword($name,$password);
        return $passErr if $passErr;
        delete $hash->{helper}{'.pw'};
    }

    TvHeadend_EPG($hash);

    if ( AttrVal($name,'PollingQueries','') =~ m{ConnectionQuery} ) {
        InternalTimer(time,\&TvHeadend_ConnectionQuery,$hash);
        my $interval = AttrVal($name,'PollingInterval',60);
        Log3( $hash,3,"$name - ConnectionQuery will be polled with an interval of $interval s");
    }

    return;
}

sub Undefine {
    my $hash = shift // return;
    RemoveInternalTimer($hash);
    return;
}

sub Set {
    my $hash    = shift;
    my $anon    = shift;
    my $h       = shift;
    #parseParams: my ( $hash, $a, $h ) = @_;
    my $name    = shift @{$anon};
    my $command = shift @{$anon} // q{};
    my @values  = @{$anon};
    return "Unknown argument $command, choose one of " 
        . join(q{ }, map {
            @{$sets{$_}} ? $_
                          .q{:}
                          .join q{,}, @{$sets{$_}} : $_} sort keys %sets)

        if !defined $sets{$command};

    if($command eq 'EPG'){
        return InternalTimer(time,\&TvHeadend_EPG,$hash);
    }
    if($command eq 'DVREntryCreate'){
        return 'EventId must be numeric' if $values[0] !~ m{\A[0-9]+\z};
        return DVREntryCreate($hash,@values);
    }
    
    if ( $command eq 'password' ) {
        return q{please set attribute Username first}
            if !defined AttrVal( $name, 'Username', undef);
        my $pw = $h->{pass} // shift @{$anon};
        return qq(usage: $command pass=<password> or $command <password>) if !defined $pw;
        my ($passResp,$passErr) = $hash->{helper}->{passObj}->setStorePassword($name,$pw);
        return $passErr;
    }

    if ( $command eq 'removepassword' ) {
        return "usage: $command" if @{$anon};
        my ($passResp,$passErr) = $hash->{helper}->{passObj}->setDeletePassword($name);
        return qq{error while saving the password - $passErr} if $passErr;
        return q{password successfully removed} if $passResp;
    }

    return;
}

sub Get {
    my $hash    = shift;
    my $anon    = shift;
    my $h       = shift;
    #parseParams: my ( $hash, $a, $h ) = @_;
    my $name    = shift @{$anon};
    my $command = shift @{$anon} // return;
    my @values  = @{$anon};
    return "Unknown argument $command, choose one of " 
        . join(q{ }, map {
            @{$gets{$_}} ? $_
                          .q{:}
                          .join q{,}, @{$gets{$_}} : $_} sort keys %gets)

        if !defined $gets{$command};

    return EPGQuery($hash,@values)          if $command eq 'EPGQuery'; 
    return ChannelQuery($hash)              if $command eq 'ChannelQuery';
    return TvHeadend_ConnectionQuery($hash) if $command eq 'ConnectionQuery';
    return;
}

sub Attr {
    my $command = shift;
    my $name = shift;
    my $attribute = shift // return;
    my $value = shift;
    my $hash = $defs{$name} // return;

    if ( $command eq 'set' ) {

        if ( $attribute eq 'EPGVisibleItems' ) {
            return if !$init_done;
            for my $items ( qw( Title Subtitle Summary Description StartTime StopTime ) ) {
                next if $value !~ m{$items};
                CommandDeleteReading($hash, "$name -q epg[0-9]+${items}Next");
                CommandDeleteReading($hash, "$name -q epg[0-9]+${items}Now");
            }
            CommandDeleteReading($hash, "$name -q epg[0-9]+ChannelName")   if $value !~ m{ChannelName};
            CommandDeleteReading($hash, "$name -q epg[0-9]+ChannelNumber") if $value !~ m{ChannelNumber};
            return;
        }

        if ( $attribute eq 'PollingQueries' ) {
            if ( $value =~ m{ConnectionQuery} ) {
                return if !$init_done;
                InternalTimer(time,\&TvHeadend_ConnectionQuery,$hash);
                my $periode = AttrVal($name,'PollingInterval',60);
                return Log3($hash,3,"$name - ConnectionQuery will be polled with an interval of $periode s");
            }
            CommandDeleteReading($hash, "$name -q connections.*");
            RemoveInternalTimer($hash,\&TvHeadend_ConnectionQuery);
            return Log3($hash,3,"$name - ConnectionQuery won't be polled anymore");
        }
        
        if ( $attribute eq 'HTTPTimeout' ) {
            return "$attribute must be nummeric and between 1 and 60 seconds" 
                if !looks_like_number($value) || ($value < 1 || $value > 60);
        }
        return;
    }

    if ( $command eq 'del' ) {
        return CommandDeleteReading($hash, "$name -q epg[0-9]+.*") if $attribute eq 'EPGVisibleItems';
        if ( $attribute eq 'PollingQueries' ){
            RemoveInternalTimer($hash,\&TvHeadend_ConnectionQuery);
            Log3($hash,3,"$name - ConnectionQuery won't be polled anymore");
            return CommandDeleteReading($hash, "$name -q connections.*");
        }
    }
    return;
}

sub Rename {
    my $new     = shift;
    my $old     = shift;
   
    my $hash    = $defs{$new};

    my ($passResp,$passErr);
    ($passResp,$passErr) = $hash->{helper}->{passObj}->setRename($new,$old);
   
    Log3($new, 1, qq(TvHeadend \(${new}\) - error while change the password hash after rename - $passErr))
        if $passErr;

    Log3($new, 3, qq(TvHeadend \(${new}\) - change password hash after rename successfully))
        if $passResp;
    return;
}

sub Delete {
    my $hash = shift // return;
    RemoveInternalTimer($hash);
    my ($passResp,$passErr) = $hash->{helper}->{passObj}->setDeletePassword($hash->{NAME});
    return;
}

sub TvHeadend_EPG {
    my $hash = shift // return;
    my $name = $hash->{NAME};

    #Get Channels
    if ( !$hash->{EPGQuery_state} ){
        ChannelQuery($hash);
        return Log3($name ,3,"$name - Can't get EPG data, because no channels defined") 
            if $hash->{helper}{epg}{count} == 0;
        Log3($name,4,"$name - Set State 1");
        $hash->{EPGQuery_state} = 1;
        return InternalTimer(time,\&TvHeadend_EPG,$hash);
    }

    #Get Now
    if($hash->{EPGQuery_state} == 1){
        my $count = $hash->{helper}{epg}{count};
        my @entriesNow = ();
        $hash->{helper}{http}{callback} = sub{
            my ($param, $err, $data) = @_;
            my $cbhash = $param->{hash};
            my $channels = $cbhash->{helper}{epg}{channels};

            (Log3($cbhash, 3,"$cbhash->{NAME} - $err"),$cbhash->{EPGQuery_state}=0,return) if $err;
            (Log3($cbhash, 3,"$cbhash->{NAME} - Server needs authentication"),$cbhash->{EPGQuery_state}=0,return) if $data =~ m{401\sUnauthorized}xms;
            (Log3($cbhash->{NAME},3,"$cbhash->{NAME} - Requested interface not found"),$cbhash->{EPGQuery_state}=0,return) if $data =~ m{404\sNot\sFound}xms;

            my $entries;
            if ( !eval { $entries  = decode_json($data)->{entries} ; 1 } ) {
                return Log3($cbhash, 1, "JSON decoding error: $@");
            }

            if ( !defined $entries->[0] ){
                Log3($cbhash, 4,"$cbhash->{NAME} - Skipping $channels->[$param->{id}]->{number}:$channels->[$param->{id}]->{name}. No current EPG information");
                $count--;
            } else {
                for my $item (qw(title subtitle summary description)) {
                    $entries->[0]->{$item} = encode('UTF-8',$entries->[0]->{$item});
                }

                for my $item (qw(subtitle summary description)) {
                    @$entries[0]->{$item} = encode('UTF-8',"Keine Informationen verfügbar") if !defined $entries->[0]->{$item};
                }

                $entries->[0]->{channelId} = $param->{id};

                push @entriesNow, $entries->[0];
            }

            if ( @entriesNow == $count ){

                $cbhash->{helper}{epg}{now} = \@entriesNow;
                $cbhash->{helper}{epg}{count} = $count;

                $cbhash->{helper}{epg}{update} = $entriesNow[0]->{stop};
                for my $i (0..@entriesNow-1){
                    $cbhash->{helper}{epg}{update} = $entriesNow[$i]->{stop} if $entriesNow[$i]->{stop} < $cbhash->{helper}{epg}{update};
                }

                InternalTimer(time,\&TvHeadend_EPG,$cbhash);
                Log3($cbhash, 4,"$cbhash->{NAME} - Set State 2");
                $cbhash->{EPGQuery_state} = 2;
            }
            return;
        };

        Log3($hash, 4,"$name - Get EPG Now");

        my $channels = $hash->{helper}{epg}{channels};
        my $channelName;
        my $ip = $hash->{helper}{http}{ip};
        my $port = $hash->{helper}{http}{port} // '9981';

        for my $i (0..$count-1){
            $hash->{helper}{http}{id} = $channels->[$i]->{id};
            $channelName = $channels->[$i]->{name};
            $channelName =~ s{\x20}{\%20}g;
            $hash->{helper}{http}{url} = "http://${ip}:${port}/api/epg/events/grid?limit=1&channel=$channelName";
            TvHeadend_HttpGetNonblocking($hash);
        }
        return;
    }

    ## GET NEXT
    if ( $hash->{EPGQuery_state} == 2 ){
        my @entriesNext = ();
        my $count = $hash->{helper}{epg}{count};

        $hash->{helper}{http}{callback} = sub{
            my ($param, $err, $data) = @_;

            my $cbhash = $param->{hash};
            my $channels = $cbhash->{helper}{epg}{channels};

            (Log3($cbhash,3,"$cbhash->{NAME} - $err"),$cbhash->{EPGQuery_state}=0,return) if $err;
            (Log3($cbhash, 3,"$cbhash->{NAME} - Server needs authentication"),$cbhash->{EPGQuery_state}=0,return) if $data =~ m{401\sUnauthorized}xms;
            (Log3($cbhash,3,"$cbhash->{NAME} - Requested interface not found"),$cbhash->{EPGQuery_state}=0,return) if $data =~ m{404\sNot\sFound}xms;

            my $entries;
            if ( !eval { $entries  = decode_json($data)->{entries} ; 1 } ) {
                return Log3($cbhash, 1, "JSON decoding error: $@");
            }
            if ( !defined $entries->[0] ){
                Log3($cbhash,4,"$cbhash->{NAME} - Skipping $channels->[$param->{id}]->{number}:$channels->[$param->{id}]->{name}. No upcoming EPG information.");
                $count--;
            } else {
                for my $items (qw( title subtitle summary description )) {
                    $entries->[0]->{$items} = "Keine Informationen verfügbar" if !defined $entries->[0]->{$items} && $items ne 'title';
                    $entries->[0]->{$items} = encode('UTF-8',$entries->[0]->{$items});
                }
                $entries->[0]->{channelId} = $param->{id};
                push @entriesNext,$entries->[0];
            }

            if ( @entriesNext == $count ){
                $cbhash->{helper}{epg}{next} = \@entriesNext;
                $cbhash->{helper}{epg}{count} = $count;

                InternalTimer(time,\&TvHeadend_EPG,$cbhash);
                Log3($cbhash,4,"$cbhash->{NAME} - Set State 3");
                $cbhash->{EPGQuery_state} = 3;
            }
        };

        Log3($hash,4,"$name - Get EPG Next");

        my $entries = $hash->{helper}{epg}{now};
        my $ip = $hash->{helper}{http}{ip};
        my $port = $hash->{helper}{http}{port} // '9981';

        for my $i (0..@$entries-1) {
            $hash->{helper}{http}{id} = $entries->[$i]->{channelId};
            $hash->{helper}{http}{url} = "http://${ip}:${port}/api/epg/events/load?eventId=$entries->[$i]->{nextEventId}";
            &TvHeadend_HttpGetNonblocking($hash);
        }
        return;
    }

    ## SET READINGS
    if ( $hash->{EPGQuery_state} == 3 ){
        my $update = $hash->{helper}{epg}{update};
        my $entriesNow = $hash->{helper}{epg}{now};
        my $entriesNext = $hash->{helper}{epg}{next};
        my $channels = $hash->{helper}{epg}{channels};
        my $items = AttrVal($hash->{NAME},'EPGVisibleItems','');

        readingsBeginUpdate($hash);
        for my $i (0..@$channels-1) {
            readingsBulkUpdateIfChanged($hash, "epg".sprintf("%03d", $channels->[$i]->{id})."ChannelName", $channels->[$i]->{name}) if $items =~ m{ChannelName};
            readingsBulkUpdateIfChanged($hash, "epg".sprintf("%03d", $channels->[$i]->{id})."ChannelNumber", $channels->[$i]->{number}) if $items =~ m{ChannelNumber};
        }
        for my $i (0..@{$entriesNow}-1) {
            for my $el (qw( Title Subtitle Summary Description )) {
                readingsBulkUpdateIfChanged($hash, "epg".sprintf("%03d", $entriesNow->[$i]->{channelId})."${el}Now",$entriesNow->[$i]->{lc $el}) if $items =~ m{$el};
            }
            for my $el (qw( Start Stop )) {
                readingsBulkUpdateIfChanged($hash, "epg".sprintf("%03d", $entriesNow->[$i]->{channelId})."${el}TimeNow", strftime("%H:%M:%S",localtime($entriesNow->[$i]->{lc $el}))) if $items =~ m{${el}Time};
            }
        }

        for my $i (0..@$entriesNext-1) {
            for my $el (qw( Title Subtitle Summary Description )) {
                readingsBulkUpdateIfChanged($hash, "epg".sprintf("%03d", $entriesNext->[$i]->{channelId})."${el}Next", $entriesNext->[$i]->{lc $el}) if $items =~ m{$el};
            }
            for my $el (qw( Start Stop )) {
                readingsBulkUpdateIfChanged($hash, "epg".sprintf("%03d", $entriesNext->[$i]->{channelId})."${el}TimeNext", strftime("%H:%M:%S",localtime($entriesNext->[$i]->{lc $el}))) if $items =~ m{${el}Time};
            }
        }
        readingsEndUpdate($hash, 1);

        Log3($name,3,"$name - Next update: ".  strftime("%H:%M:%S",localtime($update)));
        RemoveInternalTimer($hash,\&TvHeadend_EPG);
        InternalTimer($update + 1,\&TvHeadend_EPG,$hash);
        $hash->{EPGQuery_state} = 0;
    }
    return;
}

sub ChannelQuery {
    my $hash = shift // return;
    my $name = $hash->{NAME};
    Log3($hash, 4,"$name - Get Channels");

    my $ip = $hash->{helper}{http}{ip};
    my $port = $hash->{helper}{http}{port} // '9981';
    my $response;
    my @channelNames;

    $hash->{helper}{epg}{count} = 0;
    delete $hash->{helper}{epg}{channels} if defined $hash->{helper}{epg}{channels};

    $hash->{helper}{http}{url} = "http://${ip}:${port}/api/channel/grid";

    my ($err, $data) = &TvHeadend_HttpGetBlocking($hash);
    ($response = $err,Log3($hash, 3,"$name - $err"),return $err) if $err;
    ($response = "Server needs authentication",Log3($hash,3,"$name - $response"),return $response)  if $data =~ m{401\sUnauthorized}xms;
    ($response = "Requested interface not found",Log3($hash,3,"$name - $response"),return $response) if $data =~ m{404\sNot\sFound}xms;

    my $entries;
    if ( !eval { $entries  = decode_json($data)->{entries} ; 1 } ) {
        return Log3($hash, 1, "JSON decoding error: $@");
    }
    ($response = "No Channels available",Log3($hash,3,"$name - $response"),return $response) if !@{$entries};

    @{$entries} = sort {$a->{number} <=> $b->{number}} @{$entries};

    for my $i (0..@$entries-1) {
        $entries->[$i]->{name} = encode('UTF-8',$entries->[$i]->{name});
        $entries->[$i]->{id} = $i;
        push @channelNames, $entries->[$i]->{name};
    }

    return if !@channelNames;
    my $channelNames = join q{,}, @channelNames;
    $channelNames =~ s{ }{\_}g;

    my $devattrs = getAllAttr($name);
    $devattrs =~ s{EPGChannelList:multiple-strict[\S]+}{EPGChannelList:multiple-strict,all,$channelNames};

    $defs{$name}{'.AttrList'} = $devattrs;

    $hash->{helper}{epg}{count} = @{$entries};
    $hash->{helper}{epg}{channels} = $entries;

    return join q{\n}, @channelNames;
}

sub EPGQuery {
    my $hash = shift // return;
    my @args = shift // carp q[No arguments provided!] && return;

    my $name = $hash->{NAME};
    my $ip = $hash->{helper}{http}{ip};
    my $port = $hash->{helper}{http}{port} // '9981';
    my $response;

    @args = split q{:},join q{%20}, @args;
    ($args[1] = $args[0], $args[0] = 1) if !defined $args[1];
    $args[0] = 1 if defined $args[1] && $args[0] !~ m{\A[0-9]+\z};

    $hash->{helper}{http}{url} = "http://${ip}:${port}/api/epg/events/grid?limit=$args[0]&title=$args[1]";

    my ($err, $data) = &TvHeadend_HttpGetBlocking($hash);
    return $err if $err;
    ($response = "Server needs authentication",Log3($hash,3,"$name - $response"),return $response)  if $data =~ m{401\sUnauthorized}xms;
    ($response = "Requested interface not found",Log3($hash,3,"$name - $response"),return $response) if $data =~ m{404\sNot\sFound}xms;

    my $entries;
    if ( !eval { $entries  = decode_json($data)->{entries} ; 1 } ) {
        return Log3($hash, 1, "JSON decoding error: $@");
    }

    return 'No Results' if !defined $entries->[0];

    for my $i (0..@$entries-1) {
        for my $items (qw( subtitle summary description )) {
            $entries->[$i]->{$items} = encode('UTF-8',"Keine Informationen verfügbar") if !defined $entries->[$i]->{$items};
        }
        $response .= "Channel: $entries->[$i]->{channelName}\n"
                  ."Time: ".strftime("%d.%m [%H:%M:%S",localtime(encode('UTF-8',$entries->[$i]->{start})))." - "
                  .strftime("%H:%M:%S]",localtime(encode('UTF-8',$entries->[$i]->{stop})))."\n"
                  ."Titel: ".encode('UTF-8',&LewLineStringing($entries->[$i]->{title},80))."\n"
                  ."Subtitel: ".encode('UTF-8',&LewLineStringing($entries->[$i]->{subtitle},80))."\n"
                  ."Summary: ".encode('UTF-8',&LewLineStringing($entries->[$i]->{summary},80)). "\n"
                  ."Description: ".encode('UTF-8',&LewLineStringing(@$entries[$i]->{description},80)). "\n"
                  ."EventId: $entries->[$i]->{eventId}\n";
    }

    return $response;
}

sub TvHeadend_ConnectionQuery {
    my $hash = shift // return;
    my @args = shift // carp q[No arguments provided!] && return;

    my $name = $hash->{NAME};
    Log3($hash,4,"$name - Query connections");

    my $ip = $hash->{helper}{http}{ip};
    my $port = $hash->{helper}{http}{port} // '9981';

    my $response;

    $hash->{helper}{http}{url} = "http://${ip}:${port}/api/status/connections";
    my ($err, $data) = &TvHeadend_HttpGetBlocking($hash);
    return $err if $err;
    ($response = "Server needs authentication",Log3($hash,3,"$name - $response"),return $response)  if $data =~ m{401\sUnauthorized}xms;
    ($response = "Requested interface not found",Log3($hash,3,"$name - $response"),return $response) if $data =~ m{404\sNot\sFound}xms;

    my $entries;
    if ( !eval { $entries  = decode_json($data)->{entries} ; 1 } ) {
        return Log3($hash, 1, "JSON decoding error: $@");
    }

    if ( !defined $entries->[0] ){
        if(AttrVal($hash->{NAME},'PollingQueries','') =~ m{ConnectionQuery}){
            readingsBeginUpdate($hash);
            readingsBulkUpdateIfChanged($hash, "connectionsTotal", "0");
            for ( qw ( connectionsId connectionsUser connectionsStartTime connectionsPeer connectionsType ) ) {
                readingsBulkUpdateIfChanged($hash, $_, '-');
            }
            readingsEndUpdate($hash, 1);

            RemoveInternalTimer($hash,\&TvHeadend_ConnectionQuery);
            InternalTimer(time+AttrVal($name,'PollingInterval',60),\&TvHeadend_ConnectionQuery,$hash);
        }
        return 'ConnectedPeers: 0';
    }
    
    @{$entries} = sort {$a->{started} <=> $b->{started}} @{$entries};

    $response = "ConnectedPeers: @{$entries}\n"
                ."-------------------------\n";
    for my $i (0..@$entries-1) {
        $response .= "Id: $entries->[$i]->{id} \n"
                  ."User: ".encode('UTF-8',$entries->[$i]->{user})."\n"
                  ."StartTime: ".strftime("%H:%M:%S",localtime(encode('UTF-8',$entries->[$i]->{started}))) ." Uhr\n"
                  ."Peer: ".encode('UTF-8',$entries->[$i]->{peer})."\n"
                  ."Type: ".encode('UTF-8',$entries->[$i]->{type})."\n"
                  ."-------------------------\n";
    }

    if ( AttrVal($name,'PollingQueries','') =~ m{ConnectionQuery} ) {
        readingsBeginUpdate($hash);
        readingsBulkUpdateIfChanged( $hash, 'connectionsTotal', @{$entries} );
        readingsBulkUpdateIfChanged( $hash, 'connectionsId', join q{,}, my @ids = map {$_->{id}} @{$entries} );
        readingsBulkUpdateIfChanged( $hash, 'connectionsUser', encode('UTF-8', join q{,}, my @users = map {$_->{user}} @{$entries} ) );
        readingsBulkUpdateIfChanged( $hash, 'connectionsStartTime', encode('UTF-8', join q{,}, my @startTimes = map {$_->{started}} @{$entries} ));
        readingsBulkUpdateIfChanged( $hash, 'connectionsPeer', encode('UTF-8',join q{,}, my @peer = map {$_->{peer}} @{$entries} ) );
        readingsBulkUpdateIfChanged( $hash, 'connectionsType', encode('UTF-8',join q{,}, my @type = map {$_->{type}} @{$entries} ) );
        readingsEndUpdate($hash, 1);

        RemoveInternalTimer($hash,\&TvHeadend_ConnectionQuery);
        InternalTimer(time+AttrVal($name, 'PollingInterval',60),\&TvHeadend_ConnectionQuery,$hash);
    }

    return $response;
}

sub DVREntryCreate {
    my $hash = shift // return;
    my @args = shift // carp q[No arguments provided!] && return;

    my $name = $hash->{NAME};

    my $ip = $hash->{helper}{http}{ip};
    my $port = $hash->{helper}{http}{port} // '9981';
    my $response;

    $hash->{helper}{http}{url} = "http://${ip}:${port}/api/epg/events/load?eventId=$args[0]";
    my ($err, $data) = &TvHeadend_HttpGetBlocking($hash);
    return $err if $err;
    ($response = "Server needs authentication",Log3($hash,3,"$name - $response"),return $response)  if $data =~ m{401\sUnauthorized}xms;
    ($response = "Requested interface not found",Log3($hash,3,"$name - $response"),return $response) if $data =~ m{404\sNot\sFound}xms;

    my $entries;
    if ( !eval { $entries  = decode_json($data)->{entries} ; 1 } ) {
        return Log3($hash, 1, "JSON decoding error: $@");
    }

    return 'EventId is not valid' if !defined $entries->[0];

    my %recording = (
        start  => $entries->[0]->{start},
        stop => $entries->[0]->{stop},
            title  => {
                ger => $entries->[0]->{title},
            },
        subtitle  => {
                ger => $entries->[0]->{subtitle},
            },
            description  => {
                ger => $entries->[0]->{description},
            },
            channelname  => $entries->[0]->{channelName},
    );

    my $jsonData;
    if ( !eval { $jsonData  = encode_json(\%recording) ; 1 } ) {
        return Log3($hash, 1, "JSON encoding error: $@");
    }

    $jsonData =~ s{\x20}{\%20}g;
    $hash->{helper}{http}{url} = "http://${ip}:${port}/api/dvr/entry/create?conf=$jsonData";
    #($err, $data) = &TvHeadend_HttpGetBlocking($hash);
    return &TvHeadend_HttpGetBlocking($hash);
}

sub LewLineStringing {
    my $string    = shift // carp q[No string provided!]     && return;
    my $maxLength = shift // carp q[No limitation provided!] && return;

    my @words = split q{ }, $string;
    my $rowLength = 0;
    my $result = "";
    while ( @words ) {
        my $tempString = shift @words;
        if ($rowLength > 0){
            if (($rowLength + length($tempString)) > $maxLength){
                $rowLength = 0;
                $result .= "\n";
            }
        }
        $result .= $tempString;
        $rowLength += length($tempString);
        if ( @words ){
            $result .= ' ';
            $rowLength++;
        }
    }
    return $result;
}

sub TvHeadend_HttpGetNonblocking {
    my $hash = shift // return;

    my $name = $hash->{NAME};
    my $pw = $hash->{helper}->{passObj}->getReadPassword($name) // q{};

    return HttpUtils_NonblockingGet(
        {
            method     => 'GET',
            url        => $hash->{helper}{http}{url},
            timeout    => AttrVal($name,'HTTPTimeout','5'),
            user       => AttrVal($name,'Username',''),
            pwd        => $pw,
            noshutdown => '1',
            hash       => $hash,
            id         => $hash->{helper}{http}{id},
            callback   => $hash->{helper}{http}{callback}
        });
}

sub TvHeadend_HttpGetBlocking {
    my $hash = shift // return;
    my $name = $hash->{NAME};
    my $pw = $hash->{helper}->{passObj}->getReadPassword($name) // q{};

    return HttpUtils_BlockingGet(
        {
            method     => 'GET',
            url        => $hash->{helper}{http}{url},
            timeout    => AttrVal($name,'HTTPTimeout','5'),
            user       => AttrVal($name,'Username',''),
            pwd        => $pw,
            noshutdown => '1',
        });
}

1;

__END__

=pod
=item summary    Control your TvHeadend server
=item summary_DE Steuerung eines TvHeadend Servers
=item device
=begin html

<a id="TvHeadend"></a>
<h3>TvHeadend</h3>
<ul>
    <i>TvHeadend</i> is a TV streaming server for Linux supporting
        DVB-S, DVB-S2, DVB-C, DVB-T, ATSC, IPTV,SAT>IP and other formats through
        the unix pipe as input sources. For further informations, take a look at the
        <a href="https://github.com/tvheadend/tvheadend">repository</a> on GitHub.<br>
        This module module makes use of TvHeadends JSON API.
    <br><br>
    <a id="TvHeadend-define"></a>
    <h4>Define</h4>
    <ul>
        <code>define &lt;name&gt; TvHeadend &lt;IP&gt;:[&lt;PORT&gt;] [&lt;USERNAME&gt; &lt;PASSWORD&gt;]</code>
        <br><br>
        Example: <code>define tvheadend TvHeadend 192.168.0.10</code><br>
        Example: <code>define tvheadend TvHeadend 192.168.0.10 max securephrase</code>
        <br><br>
            When &lt;PORT&gt; is not set, the module will use TvHeadends standard port 9981. If the definition is successfull, the module will automatically query the EPG 
            for tv shows playing now and next. The query is based on Channels mapped in Configuration/Channel.
            The module will automatically query again when a tv show ends.<br>
        NOTE: USERNAME and/or PASSWORD will not be permanently stored in DEF. USERNAME will be transfered to attribute <i>Username</i>, PASSWORD will be stored in central keystore and may be changed or removed by <i>set</i> commands.
    </ul>
    <br>
    <a id="TvHeadend-set"></a>
    <h4>Set</h4><br>
    <ul>
        <code>set &lt;name&gt; &lt;command&gt; &lt;parameter&gt;</code>
        <br><br>
        &lt;command&gt; can be one of the following:
        <br><br>
        <ul>
          <a id="TvHeadend-set-EPG"></a>
          <li>EPG<br>
              Immediately reinitiate an EPG scan.
          </li>
          <a id="TvHeadend-set-DVREntryCreate"></a>
          <li>DVREntryCreate<br>
              Creates a DVR entry, derived from the EventId given with &lt;parameter&gt;.
          </li>
          <a id="TvHeadend-set-password"></a>
          <li>password<br>
              Set a password to access your TvHeadend server.
          </li>
          <a id="TvHeadend-set-removepassword"></a>
          <li>removepassword<br>
              Remove the sored password from keystore.
          </li>
        </ul>
    </ul>
    <br>

    <a id="TvHeadend-get"></a>
    <h4>Get</h4><br>
    <ul>
        <code>get &lt;name&gt; &lt;command&gt; &lt;parameter&gt;</code>
        <br><br>
            &lt;command&gt; can be one of the following:
            <br><br>
        <ul>
          <a id="TvHeadend-get-EPGQuery"></a>
          <li>EPGQuery<br>
            Queries the EPG. Returns results, matched with &lt;parameter&gt; and the title of a show.
            Have not to be an exact match and is not case sensitive. The result includes i.a. the EventId.
            <br><br>
            Example: get &lt;name&gt; EPGQuery 3:tagessch<br>
            This command will query the first three results in upcoming order, including
            "tagessch" in the title of a tv show.
          </li>
          <a id="TvHeadend-get-ChannelQuery"></a>
          <li>ChannelQuery<br>
            Queries the channel informations. Returns channels known by tvheadend. Furthermore this command
            will update the internal channel database.
          </li>
          <a id="TvHeadend-get-ConnectionQuery"></a>
          <li>ConnectionQuery<br>
            Queries informations about active connections. Returns the count of actual connected peers and some
            additional informations of each peer.
          </li>
        </ul>
    </ul>
    <br>

    <a id="TvHeadend-attr"></a>
    <h4>Attributes</h4>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        &lt;attribute&gt; can be one of the following:
        <ul>
          <a id="TvHeadend-attr-HTTPTimeout"></a>
          <li>HTTPTimeout<br>
            HTTP timeout in seconds.<br>
            default value: 5s<br>
            Range: 1s-60s
          </li>
          <a id="TvHeadend-attr-EPGVisibleItems"></a>
          <li>EPGVisibleItems<br>
            Selectable list of epg items. Items selected will generate
            readings. The readings will be generated, next time the EPG is triggered.
            When an item becomes unselected, the specific readings will be deleted.
          </li>
          <a id="TvHeadend-attr-EPGChannelList"></a>
          <li>EPGChannelList<br>
            Selectable list of epg channels to querry. According to https://forum.fhem.de/index.php/topic,85932.msg786091.html#msg786091 this had never been functional...
          </li>
          <a id="TvHeadend-attr-PollingQueries"></a>
          <li>PollingQueries<br>
                Selectable list of queries, that can be polled. When enabled the polling of the specific
                query starts immediately with an interval given with the attribute PollingInterval.
                When a query is in polling mode, readings will be created. When the polling will be disabled,
                the readings will be deleted.
            </li>
            <a id="TvHeadend-attr-PollingInterval"></a>
            <li>PollingInterval<br>
              Interval of polling a query. See PollingQueries for further details.<br>
              default value: 60s
            </li>
            <a id="TvHeadend-attr-Username"></a>
            <li>Username<br>
              User name to log in to your TvHeadend server.
            </li>
        </ul>
    </ul>
</ul>
=end html

=cut
