##############################################
# $Id: 99_MCAO.pm 24129 2021-04-02 16:56:29Z martinp876 $
# MyCernalAddOn
package main;

use strict;
use warnings;
use vars qw(%modules);          # List of loaded modules (device/log/etc)
use vars qw(%defs);             # FHEM device/button definitions
use vars qw(%attr);             # Attributes
use vars qw($init_done);        #

sub MCAO_Initialize($){####################################################################
  my ($hash) = @_;
  $hash->{DefFn}     = "MCAO_Define";
  $hash->{UndefFn}   = "MCAO_Undef";
  $hash->{SetFn}     = "MCAO_Set";
  $hash->{GetFn}     = "MCAO_Get";
  $hash->{AttrFn}    = "MCAO_Attr";
  
  MCAO_defCmdAttrModule($hash);
}

sub MCAO_defCmdAttrModule($) {
  my $hash = shift;  # hash to module
     # programmer tutorial
     #   this methode defines the set-commands, get-commands and attributes used.
     #   any of those can be identical for each entity of the module-TYPE or individual
     #   per entity. 
     
     #   Nomenclature:
     #     ()  identifies a list of valid options separated by '|' 
     #         example (opt1|opt2|opt3|...)
     #     []  identifies an optional parameter. 
     #         optional parameter must be the last in the definition. I.e must not be 
     #         followed by required parameter
     #         legal example:   "(opt1|opt2) [-hello-] [-timeout-]
     #         illegal example: "(opt1|opt2) [-hello-] -timeout-
     #     {}  identifies the default value of an optional parameter.
     #         logically default values shall only be assigned to parameter if 
     #         all of the pre-params are required or assigned a default as well
     #         legal example:   "(opt1|opt2) [(opt3|{opt4})] [-timeout-]
     #         illegal example: "(opt1|opt2) [-timeout-] [(opt3|{opt4})] 
     #                          opt4 cannot be assigned if timeout is not given
     #     --  identifies an individual value-set. Programmer can dynamically
     #         stuff the value-set with legal entries and take advntage of system parsing
     #         or leave this value-set unspecified
     #     ''  offers the option or comment the command for short user advice or reminder
     #         there is no operational function assigned
     #     ... states that the number of parameter is not restricted to the params in the
     #         definition
     #     min..max;step
     #          defined a value range for a parameter. Quite obvious the entered value must
     #          be in the range min<=X<=max. 
     #          step is optional and defaults to '1' if not given. The parser will round the 
     #          user inputs according to step
     #               0..100;1                 # will allow the entry of a value between 0 and 100
     #               (0..100;1)               # offers a drop-down list in the web-frontend
     #               [(0..100;1|{10})]        # is optional. if not given '10' will be used
     #               [(0..100;1|{10}|on|off)] # is optional. besides 0..100 also the 
     #                                        # liternal on/off are valid options
     #     keywords: 'multiple','multiple-strict' or 'textField-long'
     #
     
     #   Definition and assignment:
     #     Programmer should define a hash per 'set','get' and 'attr' with an entry per 
     #        command and the definition as string
     #     If the commands are identical for all the entites of the module it is 
     #        recommended to define the hashes once at module init. It is good practice to 
     #        assign the reference to the command-definition to each entity at definition. 
     #        This will reduce memor as well as processing performance. Example:
     #                   $hash->{helper}{cmds}{sets} = $modules{$type}{set};
     #                   $hash->{helper}{cmds}{gets} = $modules{$type}{get};
     #                   $hash->{helper}{cmds}{attr} = $modules{$type}{attr};
     #     Possibly the commands vary from entiy to entity. By then it is up to the 
     #        programmer to define a hash per entiy. 
     #     Pre-processing: the function will automatically pre-process the commands once
     #        for perfornamce reasons. An additional entry '.cmdPrep' is added. Programmer
     #        can force re-evaluation of the command-list by deleting this entry. Example:
     #                    delete $modules{$type}{set}{'.cmdPrep'}
     #
     #   Dynamic value list
     #     Dynamic list of values actually are quite common requirement and it is quite 
     #     powerful supported if the programmer takes advantate of the offer. 
     #     Any value in '--' can be assigned a dynamic valueList. 
     #        Example:
     #                  $hmod->{set}{param} =  "-pValueList-";
     #        pValueList is now the name of a value. Programmer can assign a list of comma
     #        separated value-list per module in $hash->{helper}{cmds}{dynValLst}
     #                  $hash->{helper}{cmds}{dynValLst}{pValueList} = "param1,param2,param3"
     #     The functions will parse the entered command for valid options and - if specified - 
     #        offer a drop-down list for command entry
     #
     
     #   Functions and operations
     #     at command execution (set/get)
     #        The command parser will check the user input for validity. It will in addition
     #        generate the system response. Very important: The reply to undefined commands 
     #        is generated automatically and performat. The "set entity ?" is the most common
     #        command required for user interface and web-frontend. programmer should take 
     #        advantage of the offer to reply here.
     #        Programme can rely on that the user-input complies to the command definition
     #        Example of parser usage
     #              sub MCAO_Set($@) {
     #                my ($hash, @a) = @_;
     #                my  $err = MCAO_cmdParser($hash,$hash->{helper}{cmds}{sets},@a);
     #                return $err if($err);
     #     at attribute assignment
     #        actually no difference to set/get. Atributes only have one value - nevertheless
     #        the supply for the web-frontend is similar important as well as the drop-down 
     #        lists and the verification of parameters for valid. 
     #     get cmdList
     #        The get-command 'cmdList' should be implemented for all entites.
     #

  {    # set
  ;
#    $hash->{helper}{cmds}{sets}{inactive}    = "";
#    $hash->{helper}{cmds}{sets}{active}      = "";
#    $hash->{helper}{cmds}{sets}{clear}       = "(trigger|readings|{readingLog})";
    $hash->{helper}{cmds}{sets}{addDevCmd}  = "-cmd- ...";
#    $hash->{helper}{cmds}{sets}{trgAdd}      = "(-name-) [(:)] [(-event-)] ...";
#    $hash->{helper}{cmds}{sets}{trgDel}      = "(-combTrgElement-)'part of a combined trigger attribut'";
#    $hash->{helper}{cmds}{sets}{tstAddSet}   = "-cmd- [-param-] ...";
#    $hash->{helper}{cmds}{sets}{tstAddGet}   = "-cmd- [-param-] ...";
#    $hash->{helper}{cmds}{sets}{tstAddAttr}  = "-cmd- [-param-] ...";
#    $hash->{helper}{cmds}{sets}{tstDelSet}   = "(-localSetCmd-)";
#    $hash->{helper}{cmds}{sets}{tstDelGet}   = "(-localGetcmd-)";
#    $hash->{helper}{cmds}{sets}{tstDelAttr}  = "(-localAttr-)";
#    $hash->{helper}{cmds}{sets}{tst1}        = "(-combTrgElement-) [(a|{b})] [-text-] [(1|2|3|4)]";
#    $hash->{helper}{cmds}{sets}{tst2}        = "(-combTrgElement-) [(a|{b})] [-text-] [({1}|2|3|4)]";
#    $hash->{helper}{cmds}{sets}{tst3}        = "(-combTrgElement-) [(a|{b})] [({def}|-text-)] [(1|2|3|4)]";
#    $hash->{helper}{cmds}{sets}{tst4}        = "(-combTrgElement-) [(a|b)]   [-text-] [(1|2|3|4)]";
#    $hash->{helper}{cmds}{sets}{tst5}        = "(-combTrgElement-) (a|{b})   [-text-] [(1|2|3|4)]";
#    $hash->{helper}{cmds}{sets}{tst7}        = "(-combTrgElement-) [(a|{b})] [({def}|-text-)] [(1|2|{3}|{4})]";
#    $hash->{helper}{cmds}{sets}{tst8}        = "(-combTrgElement-) [(a|{b})] [({def}|-text-)] [(1|2|3|{4})]";
#    $hash->{helper}{cmds}{sets}{tst9}        = "(-combTrgElement-) [(1..112;5|{b})] [-text-] [(1|2|3|4)] 'haha'";
#
#    $hash->{helper}{cmds}{sets}{key1}        = "(-combTrgElement-) [(a|{b})] [({def}|-text-)] [(1|2|3|{4})]";
#    $hash->{helper}{cmds}{sets}{key2}        = "(-combTrgElement-) [(1..112;5|{b})] [-text-] [(1|2|3|4)] 'haha'";
#    $hash->{helper}{cmds}{sets}{key3}        = "(-combTrgElement-) [(a|{b})] [({def}|-text-)] [(1|2|3|{4})]";
#    $hash->{helper}{cmds}{sets}{key4}        = "(-combTrgElement-) [(1..112;5|{b})] [-text-] [(1|2|3|4)] 'haha'";
  }
  {    # get
  ;
    $hash->{helper}{cmds}{gets}{list}        = "[({default}|hidden|module)]";
    $hash->{helper}{cmds}{gets}{cmdList}     = "[({short}|long)]";
#    $hash->{helper}{cmds}{gets}{shEnroled}             = "";
#    $hash->{helper}{cmds}{gets}{trgFilter}             = "";
    $hash->{helper}{cmds}{gets}{tstAddSet}   = "-cmd- [-param-] ...";
    $hash->{helper}{cmds}{gets}{tstAddGet}   = "-cmd- [-param-] ...";
    $hash->{helper}{cmds}{gets}{tstAddAttr}  = "-cmd- [-param-] ...";
    $hash->{helper}{cmds}{gets}{tstDelSet}   = "(-localSetCmd-)";
    $hash->{helper}{cmds}{gets}{tstDelGet}   = "(-localGetcmd-)";
    $hash->{helper}{cmds}{gets}{tstDelAttr}  = "(-localAttr-)";
    $hash->{helper}{cmds}{gets}{tst1}        = "(-combTrgElement-) [(a|{b})] [-text-] [(1|2|3|4)]";
    $hash->{helper}{cmds}{gets}{tst2}        = "(-combTrgElement-) [(a|{b})] [-text-] [({1}|2|3|4)]";
    $hash->{helper}{cmds}{gets}{tst3}        = "(-combTrgElement-) [(a|{b})] [({def}|-text-)] [(1|2|3|4)]";
    $hash->{helper}{cmds}{gets}{tst4}        = "(-combTrgElement-) [(a|b)]   [-text-] [(1|2|3|4)]";
    $hash->{helper}{cmds}{gets}{tst5}        = "(-combTrgElement-) (a|{b})   [-text-] [(1|2|3|4)]";
    $hash->{helper}{cmds}{gets}{tst7}        = "(-combTrgElement-) [(a|{b})] [({def}|-text-)] [(1|2|{3}|{4})]";
    $hash->{helper}{cmds}{gets}{tst8}        = "(-combTrgElement-) [(a|{b})] [({def}|-text-)] [(1|2|3|{4})]";
    $hash->{helper}{cmds}{gets}{tst9}        = "(-combTrgElement-) [(1..112;5|{b})] [-text-] [(1|2|3|4)] 'haha'";
                          
    $hash->{helper}{cmds}{gets}{key1}        = "(on|off|maybe)  k1=(kv11|kv12|kv13) k2=(kv21|kv22|kv23)+ k3=[(kv31|{kv32}|kv33)]";
    $hash->{helper}{cmds}{gets}{key2}        = "(on|off|maybe)  k1=(kv11|kv12|kv13|-wild-) ";
    $hash->{helper}{cmds}{gets}{key3}        = "(on|off|maybe)+ k1=(kv11|kv12|kv13)+ ";
    $hash->{helper}{cmds}{gets}{key4}        = "k41=(kv11|kv12|kv13)";
    $hash->{helper}{cmds}{gets}{key5}        = "k51=(kv11|kv12|kv13) k52=\"adfajsfa sdf asdf asf kv11|kv12|kv13\"";
    $hash->{helper}{cmds}{gets}{key6}        = "(on|off|maybe)+ k1=(kv11|kv12|kv13)+ *=-any- ";
  }
  {    # attr
  ;
#    $hash->{helper}{cmds}{attr}{disable}               = '(1|0)';
#    $hash->{helper}{cmds}{attr}{disabledForIntervals}  = '-disable-';
#    $hash->{helper}{cmds}{attr}{disabledAfterTrigger}  = '-seconds-';
#    $hash->{helper}{cmds}{attr}{forwardReturnValue}    = "(1|0)";
#    $hash->{helper}{cmds}{attr}{ignoreRegexp}          = "(1|0)";
#    $hash->{helper}{cmds}{attr}{readLog}               = "(1|0)";
#    
#    $hash->{helper}{cmds}{attr}{trgDevice}             = "multiple,(-trgNames-) 'regex possible light.* or (light1|light2)'";
#    $hash->{helper}{cmds}{attr}{trgEvent}              = "textField-long,-Event- 'Reading:value'";
#    $hash->{helper}{cmds}{attr}{trgReading}            = "-readingRegex- 'reading(s) to be evaluated e.g.'";
#    $hash->{helper}{cmds}{attr}{trgReadValue}          = "-readingValueRegex-)] 'value of the reading'";
#    $hash->{helper}{cmds}{attr}{trgCombined}           = "textField-long,-NameEvent- 'should have a colon <name1>:<event1>,<name2>:<event2>'";
#    $hash->{helper}{cmds}{attr}{trgCmd}                = "textField-long,-Cmd-";
#    $hash->{helper}{cmds}{attr}{logTrgNames}           = "(1|0)";
  }
}
sub MCAO_defCmdAttrEntity($) {
  my $hash = shift;  # hash to entity
     # programmer tutorial
     #   define sets gets and attributes unique for an entity
     #   
     #   

  {    # set
     ;
  #  $hash->{helper}{cmds}{sets}{param}        = "-param-"                     ;
  #  $hash->{helper}{cmds}{sets}{count4}       = "'change:'[(-testList-)]";
  #  $hash->{helper}{cmds}{sets}{counttrgEvt}  = 'textField-long,-Event-'      ;
  #  $hash->{helper}{cmds}{sets}{cSlider2}     = "'change:'slider,(0..10;4|{10}|-testList2-)"      ;
  }
  {    # get 
    ;
    $hash->{helper}{cmds}{gets}{Testbench}     = "" ;
#    $hash->{helper}{cmds}{gets}{Eget}     = "[({normal}|full)]" ;
  }
  {    # attr
     ;
  #  $hash->{helper}{cmds}{attr}{Eattr}    = '(hallo|holla)' if ($hash->{NAME} eq "aa");
  #  $hash->{helper}{cmds}{attr}{test}     = 'textField-long,-NameEvent-';
  #  $hash->{helper}{cmds}{attr}{d1}       ='(-disable1-)';
  #  $hash->{helper}{cmds}{attr}{d2}       ='-disable2-';
  #  $hash->{helper}{cmds}{attr}{d3}       ='(a|b|-disable3-)';
 }
}

sub MCAO_scheduleAttrInit($){#schedule attribute set after init_done
  # wait for init_done. re-set attr after all all attributes are available
  my $moduleName = shift           //return;  # moduleName
  $moduleName =~ s/MCAOAttrInit_//;

  if (!$init_done){
    if(!grep/MCAOAttrInit_$moduleName/,map{"$_ : ".($intAt{$_}{ARG}?$intAt{$_}{ARG}:"no")} keys %intAt){
      InternalTimer(gettimeofday() + 3,"MCAO_scheduleAttrInit", "MCAOAttrInit_$moduleName", 0);
    }
  }
  else{
    MCAO_setAttrPostInit($moduleName);
  }
}
sub MCAO_setAttrPostInit($) {#set all attributes after init_done
  my $moduleName = shift           //return;  # moduleName
  my $hash = $modules{$moduleName} //return;
  
  my $pass = 0;
  foreach my $entity (grep!/^nonModule$/,map{$defs{$_}{TYPE}eq $moduleName ? $_ : "nonModule"}keys %defs){
    MCAO_cmdParser($defs{$entity},"attr",("","updt",($pass++ == 0 ? "module" : "device")));

    foreach my $a (keys %{$attr{$entity}}){# evaluate all attributes by re-assign
      next if(!defined $a || $a !~ m/../ || !$attr{$entity}{$a});
      CommandAttr(undef, "$entity $a $attr{$entity}{$a}");
    }
  }
}

sub MCAO_parseParams(@){
  my $b = " ".join(" ",@_)." ";
  my $i = 0;
  while($b =~ m/([ =]{|} )/){
      if($1 eq "} "){
          $i--;
          $b =~s/(})( )/$1$i$2/;
      }
      else{
          $b =~s/([ =])({)/$1$i$2/;
          $i++;
      }
  }
  $b =~ s/[1-9]{/{/;
  $b =~ s/}[1-9]/}/;
  my @rt;
  while($b){
      if($b =~ s/(.*?) (([^\s]*=+)\".*?\"|([^\s]*=+)'.*?'|([^\s]*=+)0\{.*?\}0) / /){
          my ($pre,$s) = ($1,$2);
          $s =~ s/0\{/{/;
          $s =~ s/\}0/}/;
          push@rt,$_ foreach(split" ",$pre);
          push@rt,$s;
      }
      else{
          push@rt,$_ foreach(split" ",$b);
          last
      }
  }
  my @a = grep(!/=/,@rt);
  my %h = map{split("=",$_,2)} grep/=/,@rt;
  return (\@a,\%h);
}
sub MCAO_cmdParser2($$@){#hash to entity, hash to commands, input array
  my $hash = shift;
  my $type = shift;
  my $ref = \@_;
  my $cmd = @$ref[1];   
  my @out = ();
  my $outH;
  my $ret;
  return "MCAO_cmdParser called while hash not defined - contact admin" if (!defined $hash 
                                                                        || !defined $hash->{TYPE}
                                                                        || !defined $modules{$hash->{TYPE}});
    # programmer tutorial
    #    this sub can be used generic for ANY module.
    #    it has potential and should actually be included in the kernal SW
    # usage  
    #     1) set     
    #        sub MCAO_Set($@) {
    #          my ($hash, @a) = @_;
    #          my  $chk = MCAO_cmdParser($hash,"sets",@a);
    #          return undef if ($chk && $chk eq "done");
    #          return $chk if($chk);
    #     2) get     
    #        sub MCAO_Get($@) {
    #          my ($hash, @a) = @_;
    #          my  $chk = MCAO_cmdParser($hash,"gets",@a);
    #          return undef if ($chk && $chk eq "done");
    #          return $chk if($chk);
    #     3) attr
    #        sub MCAO_Attr(@) {
    #          see  MCAO_AttrCheck($hash,$aSet, $aName,$aVal);
    #     4) update {MCAO_cmdParser($defs{a},"attr",(undef,"updt"))}
    #          my  $chk = MCAO_cmdParser($hash,<gets|sets|attr>,(undef,"updt",<{module}|device>));

  ################# do we have to update the pre-processing section?
  my @defaults = ();
  my @sources;

  foreach my $h ($hash,$modules{$hash->{TYPE}}){ #first modules - then optional overwrite by entits 
    push @sources,(  !defined $h->{helper} 
                   ||!defined $h->{helper}{cmds}
                   ||!defined $h->{helper}{cmds}{$type} 
                   ) ? 0
                     : $h->{helper}{cmds}{$type}
                   ;
  }
  if($cmd eq "updt"){
    delete $sources[0]->{'.cmdPrep'} if($sources[0]); # renew device update always
    if (!defined @$ref[2] || @$ref[2] ne "device"){
      delete $sources[1]->{'.cmdPrep'} if($sources[1]); # renew device update optional
    }
  }

  my $updated = 0;
  foreach my $pass (1,0){ # check if update is required first modules - then optional overwrite by entities 
    my $h = $sources[$pass];
    next if(!$h);
    if (!defined $h->{'.cmdPrep'}){#parse settings and prepare shortcuts
      $updated = 1;
      if($pass == 1){# the module def changed - invalidate the entity as well - for all of the module entites
        foreach (devspec2array("TYPE=$hash->{TYPE}")){
          delete $defs{$_}{helper}{cmds}{$type}{'.cmdPrep'}
                if (   defined $defs{$_}{helper} 
                    && defined $defs{$_}{helper}{cmds}
                    && defined $defs{$_}{helper}{cmds}{$type} 
                    );
        }
      }
      $h->{'.cmdPrep'}{init} = 1; 
      foreach my $defCmd (grep !/\./,keys %$h){ # prepare and parse the inputs
        $h->{'.cmdPrep'}{cmd}{$defCmd}{paraOpts} = $h->{$defCmd};
        my $hCmdIdx = $h->{'.cmdPrep'}{cmd}{$defCmd};
        $hCmdIdx->{paraOpts} =~ s/\'.*?\'//g;                                               # remove comments
        $hCmdIdx->{paraOpts} =~ s/^(textField-long,|multiple,|multiple-strict,|slider,)//g; # remove style
        $hCmdIdx->{paraOpts} =~ s/[\s]+/ /g;                                                # remove double space
        
        {#use parseParams
          $hCmdIdx->{keys}{set} = 1;
          my($aP,$hP) = MCAO_parseParams($hCmdIdx->{paraOpts});
              
          foreach my $ke (grep/./,keys %{$hP}){
            $hCmdIdx->{keys}{$ke}{opt}  = (($hP->{$ke} =~ s/^\[(.*)\]$/$1/) ? 1  : 0 );
            $hCmdIdx->{keys}{$ke}{Opts} = $hP->{$ke};
            if($hCmdIdx->{keys}{$ke}{opt}) {
              $hCmdIdx->{keys}{$ke}{def}  = (($hP->{$ke} =~ m/{(.*)}/)        ? $1 : "" ); 
              $hCmdIdx->{keys}{$ke}{Opts} =~ s/[\{\}]//g;
            } 
            else{
              $hCmdIdx->{keys}{$ke}{def} = "";
            }            
          }
          $hCmdIdx->{paraOpts} = join(" ",@{$aP});
          @{$hCmdIdx->{def}}=();
          push @{$hCmdIdx->{def}},$_ foreach(map{$_=~ m/{(.*?)}/?$1:""} @{$aP});
        }
        
        $hCmdIdx->{max} = (($hCmdIdx->{paraOpts} =~ m/\.\.\./) ? 99 : scalar(split(" ",$hCmdIdx->{paraOpts})));
        $hCmdIdx->{paraOpts} =~ s/\.\.\.//g;

        my ($reqOpts) = map{my $foo = $_;$foo =~ s/(\[.*?\])//g;$foo}($hCmdIdx->{paraOpts}); # remove optionals
        $hCmdIdx->{min} = scalar(split(" ",$reqOpts));

        my $pCnt = 0;
        my $defUpTo = 0;
        foreach my $param (split(" ",$hCmdIdx->{paraOpts})){
          my ($opt,$def) = (0,0);
          if($pCnt > $hCmdIdx->{min}){
            if($param !~ m/^\[.*\]$/){ #any after min must be optional
              Log3 $hash->{NAME},1,"non optional parameter in $defCmd at position $pCnt while optional param before";
            }
          } 
          $pCnt++;
        }
        $hCmdIdx->{paraOpts} =~ s/[\[\]]//g;
        $hCmdIdx->{paraOpts} =~ s/[\s]+/ /g;
      }
    }
  }

  my $dDyn =    defined $hash->{helper}
             && defined $hash->{helper}{cmds}
             && defined $hash->{helper}{cmds}{dynValLst} 
                 ? $hash->{helper}{cmds}{dynValLst}
                 : undef
                 ;
  my $mDyn =    defined $modules{$hash->{TYPE}}->{helper}
             && defined $modules{$hash->{TYPE}}->{helper}{cmds}
             && defined $modules{$hash->{TYPE}}->{helper}{cmds}{dynValLst} 
                 ? $modules{$hash->{TYPE}}->{helper}{cmds}{dynValLst}
                 : undef
                 ;
  if($updated){           # prepare answer for "set <entity> ?" - generate "unknown"
    my %cPrepH;
    foreach my $pass (1,0){ #first modules - then optional overwrite by entits 
      my $h = $sources[$pass];
      next if(!$h);
   
      # prepare reply for "set/get <entity> ?"
      foreach my $cmdS (grep !/\.cmdPrep/,keys %{$h}){
        my $val = $h->{$cmdS};
        $val =~ s/\'.*?\'//g; # remove comments
        my $def = $val =~ m/\{(.*?)\}/ ? $1 : "";
#        push @{$h->{'.cmdPrep'}{cmd}{$cmdS}{def}},$def;
#        $h->{'.cmdPrep'}{cmd}{$cmdS}{def} = $def;
        $val =~ s/[\{\}]//g;  # remove default marking - not relevant for web-frontend
        $val =~ s/\s*$//g;    # remove default marking - not relevant for web-frontend
        if   ($val =~ m/^textField-long/){ # textfield is unique
          $val = ":textField-long";
        }
        elsif($val =~ m/^slider,/)       { # implement slider
          if($val =~ m/slider,[\d.]+,[\d.]+,?[\d.]*$/){
            $val = ":$val";
          }
          elsif($val =~ m/slider,\(([\d.]+)\.\.([\d.]+)[;|\)]([\d.])?[|\)]?/){
            $val = ":slider,$1,".(defined $3 ? "$3": "1").",$2";
          }
          else{
            $val = "";
          }
        }
        elsif($val =~ m/^(noArg|)$/)     { # no argument required
          $val = ":noArg";
        }
        elsif($val =~ m/ /                 # multi-parameter - no quick select
            ||$val !~ m/^(\[|multiple,|multiple-strict,)?\(.*\)\+?\]?$/){ 
          $val = "";
        }
        else                             { # no space: single param command (or less)
          my ($dispOpt,$list,$multi) = $val =~ m/(.*)\((.*)\)(\+)?/;
          $dispOpt =~ s/[\[,]//g; # preserve display option, e.g. multiple
          
          $dispOpt = (!$dispOpt && $multi ? "multiple" :  "") ;
          if($dispOpt eq "multiple" && $val !~ m/.*[\(\|]\-[^\|]*\-[\)\|].*/){
            $dispOpt = "multiple-strict";
          }
          
          my %items;
          foreach my $item (split('\|',$list)){
            if ($item =~ m/(.*)\.\.(.*)/ ){  #"(0..100;1)"
              my ($min,$max,$step) = ($1,$2,1);
              if ($max =~ m/(.*);(.*)/){
                ($max,$step) = ($1,$2);
              }
              my $f = 0;
              ($f) = map{(my $foo = $_) =~ s/.*\.//;length($foo)}($step) if ($step =~ m/\./);
              my $m = ($max - $min)/$step;
              $items{$_} = 1 foreach(map{sprintf("%.${f}f",$min + $_ * $step)}(0..$m));
            }
            else{
              $items{$item} = 1;
            }     
          }
          $val = ":$dispOpt"
                    .join(",",$def  # place default first
                             ,grep!/$def/,(sort { $a <=> $b } grep /^[\d\.]+$/,keys %items)
                                         ,(sort               grep!/^[\d\.]+$/,keys %items));
          $val =~ s/:,/:/;
        }
        $cPrepH{$cmdS} = $val;
      }
      if ($type eq "attr"){# attr does not require "unknown arg" but the definition of an attrList
        my $attrHash;
        if ($pass == 0){# entity level
          if(defined $hash->{helper}{cmds}{attr}{'.cmdPrep'}{cmd}){

            if($dDyn || $mDyn){
              foreach my $cmd(keys %cPrepH) {
                my ($open,$pass) = (0,0);
                while ($cPrepH{$cmd} =~ m/.*:.*\-([^,]*)-/){
                  my ($str,$repl) = ($1,"");
                  if($dDyn && defined $dDyn->{$str}){
                    $repl = $dDyn->{$str};
                  }
                  elsif($mDyn && defined $mDyn->{$str}){
                    $repl = $mDyn->{$str};
                  }
                  else{
                    $open = 1;
                  }
                  $cPrepH{$cmd} =~s/\-$str\-/$repl/ ;
                  $pass++;
                }
                if($pass){
                  if(!$open){ $cPrepH{$cmd} =~ s/:multiple,/:multiple-strict,/ ; }
                  else{       $cPrepH{$cmd} =~ s/:(multiple,)?/:multiple,/;     }
                }
              }
            }
                            
            $hash->{'.AttrList'} = join(" ",map{$_.$cPrepH{$_}} keys %cPrepH) ;
            $attrHash = \$hash->{'.AttrList'};
            $$attrHash =~ s/(  )//g;
            $$attrHash =~ s/\, / /g;
            $$attrHash =~ s/,+/,/g;
            $$attrHash =~ s/:,/:/;
          }
          else{
            delete $hash->{'.AttrList'};
          }
        }
        else{           # module level

          if($modules{$hash->{TYPE}}->{helper}{cmds}{attr}{'.cmdPrep'}{init} == 1){
            if( $mDyn){
              foreach my $cmd(keys %cPrepH) {
                my ($open,$pass) = (0,0);
                while ($cPrepH{$cmd} =~ m/.*:.*\-([^,]*)-/){
                  my ($str,$repl) = ($1,"");
                  if(defined $mDyn->{$str}){
                    $repl = $mDyn->{$str};
                  }
                  else{
                    $open = 1;
                  }
                  $cPrepH{$cmd} =~s/\-$str\-/$repl/ ;
                  $pass++;
                }
                if($pass){
                  if(!$open){ $cPrepH{$cmd} =~ s/:multiple,/:multiple-strict,/ ; }
                  else{       $cPrepH{$cmd} =~ s/:(multiple,)?/:multiple,/;     }
                }
              }
            }
              
            $modules{$hash->{TYPE}}{AttrList} = join(" ",map{$_.$cPrepH{$_}} keys %cPrepH);
            $modules{$hash->{TYPE}}->{helper}{cmds}{attr}{'.cmdPrep'}{init} = 2;# second level init: 
            $attrHash = \$modules{$hash->{TYPE}}{AttrList};
            $$attrHash =~ s/(  )//g;
            $$attrHash =~ s/, / /g;
            $$attrHash =~ s/,+/,/g;
            $$attrHash =~ s/:,/:/;
          }
        }
      }
      else{
        $h->{'.cmdPrep'}{unknown} = join(" ",map{$_.$cPrepH{$_}} sort keys %cPrepH)." ";
      }
    }
  }

  ################# is the command/attr defined
  my $found = 0;
  foreach my $pass (1,0){ # check first entity then module - prio
    my $h = $sources[$pass];
    next if(!$h);

    if(defined($h->{$cmd})) {# is command defined?
      $found = 1;            # command is defined check number of parameter requires
      {
        my ($aP,$hP) = MCAO_parseParams(@$ref[2..$#$ref]);
        @out = @{$aP};
        foreach my $inKey (keys %{$hP}){
          if($h->{'.cmdPrep'}{cmd}{$cmd}{keys}{$inKey}){# key is in definition
            my $param = $h->{'.cmdPrep'}{cmd}{$cmd}{keys}{$inKey}{Opts};
            if($param =~ s/.*\((.*)\)([\+]?).*/$1/){                  # remove brackets
              my $multi = ($2 ? 1 : 0);
              if(!$multi && $hP->{$inKey} =~ m/,/){
                $ret = "key $inKey:'$hP->{$inKey}' has multiple options - select only one";
                last;
              }
              foreach my $dyn ($dDyn,$mDyn){
                next if (!defined $dyn);
                foreach(keys %{$dyn}){ # add dynamic values
                  $param =~ s/\-$_\-/$dyn->{$_}/g;  
                } 
              }                
              if($param =~ m/-.+-/){ #placeholder still allowed => no further check
                $outH->{$inKey} = $hP->{$inKey};
                next;
              }
              foreach my $opt (split(",",$hP->{$inKey})){# do we meet the options?
                if(0 == grep(/$opt/,split('\|',$param))){
                  $ret = "$opt not allowed for key $inKey. select from $param";
                  last;
                }
              }
            }
            else{
              $outH->{$inKey} = $hP->{$inKey};
              next;
            }
            $param =~ s/[\{\}]//g;   # remove brackets for default
            $outH->{$inKey} = $hP->{$inKey};
          }
          elsif(defined $h->{'.cmdPrep'}{cmd}{$cmd}{keys}{'*'}){#undefined key but wildcard
            $outH->{$inKey} = $hP->{$inKey};
          }
          else{#undefined key used
            $ret = "key $inKey illegal for this command";
            last;
          }
        }
        foreach my $defKey (grep!/^(set|\*)$/,keys %{$h->{'.cmdPrep'}{cmd}{$cmd}{keys}}){#add defaults 
          next if(defined $outH->{$defKey});
          if($h->{'.cmdPrep'}{cmd}{$cmd}{keys}{$defKey}{opt}){
            $outH->{$defKey} = $h->{'.cmdPrep'}{cmd}{$cmd}{keys}{$defKey}{def};            
          }
          else{#required key missing
            $ret = "required key $defKey is not given";
            last;
          }
        }
        last if ($ret);
      }
      my $paramCnt = scalar(@out);
      my $hCmdPrep = $h->{'.cmdPrep'}{cmd}{$cmd};
      if($paramCnt < $hCmdPrep->{min} || $paramCnt > $hCmdPrep->{max}){# command parameter count ok?
        $ret = "$cmd requires min: $hCmdPrep->{min} and max: $hCmdPrep->{max} parameter"
              ."\n    number of parameter given:$paramCnt"
              ."\n    $cmd:$h->{$cmd}"
           ;
      }
      else{                       # number of parameter is ok - check content
        my $pCnt = 0;
        my $paraFail = "";
        foreach my $param (split(" ",$hCmdPrep->{paraOpts})){ # check each parameter
          if($paramCnt -1  < $pCnt){                 # no param input given - use default if available
            push @out,$_ foreach (@{$hCmdPrep->{def}}[$pCnt..@{$hCmdPrep->{def}}-1]);
            last;
          }
          else{                                      # still input params - check content
            $param =~ s/.*\((.*)\)([\+]?).*/$1/;# remove brackets
            my $multi = ($2 ? 1 : 0);
            $ret = "param $pCnt:'$out[$pCnt]' has multiple options - select only one"
                    if(!$multi && $out[$pCnt] =~ m/,/);
            $param =~ s/[\{\}]//g;   # remove brackets for default
            next if (!$param);
            my $any = 0; # unspecified option
            while ($param =~ m/-([^|]+)-/){
              my ($str,$repl) = ($1,"");
              if   ($dDyn && defined $dDyn->{$str}){
                $repl = $dDyn->{$str};
              }
              elsif($mDyn && defined $mDyn->{$str}){
                $repl = $mDyn->{$str};
              }
              else{#cannot replace this placeholder - it is a wildcard
                $any = 1;
                $pCnt++;
                last;
              }
              $repl =~ s/,/|/g;
              $param =~s/\-$str\-/$repl/ ;
            }
            next if ($any);
            
            my @optList =  split('\|',$param);
            my $eFail = 0;
            foreach my $x(split(",",$out[$pCnt])){
              if(scalar(grep/$x/,@optList) == 0){#no match
                $eFail = 1;#interims
                if($x =~ m/^-?[0-9][0-9\.]*$/){
                  foreach my $option(@optList){
                    if($option =~ m/^(\d+)..(\d+);?(\d*)/){
                      my ($l,$h,$s) = ($1,$2,$3);
                      $s = 1 if (!$s);
                      if($out[$pCnt]>=$1 && $out[$pCnt]<=$2) {
                        $out[$pCnt] = int(($out[$pCnt]-$l)/$s+0.5)*$s+$l;
                        $out[$pCnt] = $h if($out[$pCnt]>$h-$s);
                        $eFail = 0;
                        last;  
                      }
                    }
                  }
                }
                if ($eFail){
                  $ret = "param $pCnt:'$x' eFail not an option in $param";
                  last;
                }
              }
            }
            last if ($ret);
            
#            foreach my $option(@optList){
#              if($option =~ m/^(\d+)..(\d+);?(\d*)/ && $parIn[$pCnt] =~ m/^-?[0-9][0-9\.]*$/ ){
#                my ($l,$h,$s) = ($1,$2,$3);
#                $s = 1 if (!$s);
#                if($parIn[$pCnt]>=$1 && $parIn[$pCnt]<=$2) {
#                  $found2 = 1;
#                  $parIn[$pCnt] = int(($parIn[$pCnt]-$l)/$s+0.5)*$s+$l;
#                  $parIn[$pCnt] = $h if($parIn[$pCnt]>$h-$s);
#                  last;  
#                }
#              }

            if($eFail){
              $ret = "param $pCnt:'$out[$pCnt]' 2 does not match options '$param' ";
              last;
            }
          }
          $pCnt++;
        }
      }
    }
  }

  if (!$found){
    $ret = $sources[0] && $sources[0]->{'.cmdPrep'} && $sources[0]->{'.cmdPrep'}{unknown} ? $sources[0]->{'.cmdPrep'}{unknown}
          :$sources[1] && $sources[1]->{'.cmdPrep'} && $sources[1]->{'.cmdPrep'}{unknown} ? $sources[1]->{'.cmdPrep'}{unknown}
          :"";
    if (  $ret && $ret =~ m/\-.*\-/){
      if( $dDyn){
        foreach(keys %{$dDyn}){ # add dynamic values
          $ret =~ s/\-$_\-/$dDyn->{$_}/g;  
        }      
      }
      if (  $ret =~ m/\-.*\-/){#remove list if any general value is still available
        # cmd:para1,para2,-placeholder- => cmd
        $ret =~ s/([^\s]*?):[^\s]*?-[^\s]*?-[^\s]*? / $1 /g;
        # cmd:multiple,para1,para2,-placeholder- => cmd:multiple,para1,para2
        $ret =~ s/multiple([^\s]*),-[^\s]*-/multiplexx$1/g; # remove -val- from multiple but keep the statement
      }
    }
    $ret = "Unknown argument $cmd, choose one of $ret";
  }
  return ($ret,\@out,$outH) if ($ret);
  
  if($type eq "gets"){# system relevant commands
    if($cmd eq "list")      {  ###############################################
      #"[({default}|hidden|module)]"
      my $globAttr = AttrVal("global","showInternalValues","undef");
      $attr{global}{showInternalValues} = @$ref[2] eq "default" ? 0 : 1;
      
      $ret = @$ref[2] eq "module" ? "MODULE: $hash->{TYPE}\n".PrintHash($modules{$hash->{TYPE}}, 2)
                               : CommandList(undef,$hash->{NAME});
      if ($globAttr eq "undef"){
        delete $attr{global}{showInternalValues};
      }
      else{
        $attr{global}{showInternalValues} = $globAttr;
      }
    }
    elsif($cmd eq "cmdList")   {  ###############################################
      foreach my $type ("sets","gets","attr"){
        $ret .= "commands for $type\n  ";
        my @cmd = ();
        push @cmd,map{$_ =~ s/:(textField-long,|multiple,|multiple-strict,|slider,)/:/g;$_}
                  map {"$_\t:$hash->{helper}{cmds}{$type}{$_}"} 
                  grep!/^\./,
                  keys %{$hash->{helper}{cmds}{$type}}
              if(   defined $hash->{helper} 
                 && defined $hash->{helper}{cmds}
                 && defined $hash->{helper}{cmds}{$type})
                 ;
        push @cmd,map{$_ =~ s/:(textField-long,|multiple,|multiple-strict,|slider,)/:/g;$_}
                  map {"$_\t:$modules{$hash->{TYPE}}->{helper}{cmds}{$type}{$_}"} 
                  grep!/^\./,
                  keys %{$modules{$hash->{TYPE}}->{helper}{cmds}{$type}}
              if(   defined $modules{$hash->{TYPE}}{helper}
                 && defined $modules{$hash->{TYPE}}->{helper}{cmds}
                 && defined $modules{$hash->{TYPE}}->{helper}{cmds}{$type});
    
        $ret .= join("\n  ",sort @cmd);
        $ret .= "\n\n";
      }
    }
  }
  return ($ret,\@out,$outH);
}

sub MCAO_AttrCheck(@) {############################
    # verify if attr is applicable
    # programmer tutorial
    #  recommended usage
    #     my $chk = MCAO_AttrCheck($name, $aSet, $aName, $aVal);
    #     return undef if ($chk && $chk eq "ignoreAttr");
    #     return $chk  if ($chk);
    #     Usage
    #        sub MCAO_Attr(@) {
    #          my @a = @_;
    #          my ($aSet,$name,$aName,$aVal) =@a;
    #          my $hash = $defs{$name};
    #          my $chk = MCAO_AttrCheck($hash, $aSet, $aName, $aVal);
    #          return undef if ($chk && $chk eq "ignoreAttr");
    #          return $chk  if ($chk);
  
  my ($aSet,$name,$aName,$aVal) = @_;
  my $modTyp = $defs{$name}{TYPE};
  if (!$init_done){
    MCAO_scheduleAttrInit($modTyp);
    return ("ignoreAttr") ;  
  }
  if ( !defined $modules{$modTyp}{helper}{cmds}{attr}{'.cmdPrep'}
    || !defined $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}){
    MCAO_cmdParser($defs{$name},"attr",("",""));
  }
         # return the default if deleted
         
  if ($aSet ne "set"){
    my $default = 
                (   defined $defs{$name}{helper}{cmds}{attr}   
                 && defined $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}
                 && defined $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}
                 && defined $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}{$aName}
                ?  $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}{$aName}{def}
                :   defined $modules{$modTyp}{helper}{cmds}
                 && defined $modules{$modTyp}{helper}{cmds}{attr}
                 && defined $modules{$modTyp}{helper}{cmds}{attr}{'.cmdPrep'}
                 && defined $modules{$modTyp}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}
                 && defined $modules{$modTyp}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}{$aName} 
                ?  $modules{$modTyp}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}{$aName}{def}
                :  undef
                 );
    return (!defined $default ?"ignoreAttr":undef,($default));
    # will ignore attributs not in our module. return default for all others. 
  }
  
  my @a = ($name,$aName);
  push @a,$aVal if(defined $aVal);
  my ($chk,@defaults) = MCAO_cmdParser($defs{$name},"attr",@a);
  
  if ($chk){
    if($chk =~ m/^Unknown/){#not a module attribute
      return (undef) if ($aSet ne "set");# allow delete any time
      my $a = " ".getAllAttr($name)." ";
      if($a !~ m/ $aName[ :]+/){
        $a =~ s/:.*? //g;
        return ("attribut $aName not valid. Use one of $a");
      }
      else{
        return ("ignoreAttr") ; # attr valid but not in module context - ok for me
      }
    }
    else{
      return ($chk);
    }
  }
         
  my $attrOpt =     defined $modules{$modTyp}{helper}{cmds}
                 && defined $modules{$modTyp}{helper}{cmds}{attr}
                 && defined $modules{$modTyp}{helper}{cmds}{attr}{'.cmdPrep'}
                 && defined $modules{$modTyp}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}
                 && defined $modules{$modTyp}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}{$aName} 
                ?  $modules{$modTyp}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}{$aName}{paraOpts}
                :   defined $defs{$name}{helper}{cmds}{attr}   
                 && defined $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}
                 && defined $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}
                 && defined $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}{$aName}
                ?  $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}{$aName}{paraOpts}
                :"";
 
  return (undef,@defaults)
               if (!$attrOpt                               # any value allowed
                 || $attrOpt =~ m/^(multiple|textField-)/  # any value allowed
                 || $attrOpt !~ m/^\(\)$/                  # no list defined
                 || grep/^$aVal$/,split(",",$attrOpt)      # identified
                 );
  return ("value $aVal not allowed. Choose one of:$attrOpt");
}
sub MCAO_cmdParser($$@){#hash to entity, hash to commands, input array
  my $hash = shift;
  my $type = shift;
  my $ref = \@_;
  my $cmd = @$ref[1];   
  my $ret;
  return "MCAO_cmdParser called while hash not defined - contact admin" if (!defined $hash 
                                                                        || !defined $hash->{TYPE}
                                                                        || !defined $modules{$hash->{TYPE}});
    # programmer tutorial
    #    this sub can be used generic for ANY module.
    #    it has potential and should actually be included in the kernal SW
    # usage  
    #     1) set     
    #        sub MCAO_Set($@) {
    #          my ($hash, @a) = @_;
    #          my  $chk = MCAO_cmdParser($hash,"sets",@a);
    #          return undef if ($chk && $chk eq "done");
    #          return $chk if($chk);
    #     2) get     
    #        sub MCAO_Get($@) {
    #          my ($hash, @a) = @_;
    #          my  $chk = MCAO_cmdParser($hash,"gets",@a);
    #          return undef if ($chk && $chk eq "done");
    #          return $chk if($chk);
    #     3) attr
    #        sub MCAO_Attr(@) {
    #          see  MCAO_AttrCheck($hash,$aSet, $aName,$aVal);
    #     4) update {MCAO_cmdParser($defs{a},"attr",(undef,"updt"))}
    #          my  $chk = MCAO_cmdParser($hash,<gets|sets|attr>,(undef,"updt",<{module}|device>));

  ################# do we have to update the pre-processing section?
  my @defaults = ();
  my @sources;

  foreach my $h ($hash,$modules{$hash->{TYPE}}){ #first modules - then optional overwrite by entits 
    push @sources,(  !defined $h->{helper} 
                   ||!defined $h->{helper}{cmds}
                   ||!defined $h->{helper}{cmds}{$type} 
                   ) ? 0
                     : $h->{helper}{cmds}{$type}
                   ;
  }
  if($cmd eq "updt"){
    delete $sources[0]->{'.cmdPrep'} if($sources[0]); # renew device update always
    if (!defined @$ref[2] || @$ref[2] ne "device"){
      delete $sources[1]->{'.cmdPrep'} if($sources[1]); # renew device update optional
    }
  }

  my $updated = 0;
  foreach my $pass (1,0){ # check if update is required first modules - then optional overwrite by entities 
    my $h = $sources[$pass];
    next if(!$h);
    if (!defined $h->{'.cmdPrep'}){#parse settings and prepare shortcuts
      $updated = 1;
      if($pass == 1){# the module def changed - invalidate the entity as well - for all of the module entites
        foreach (devspec2array("TYPE=$hash->{TYPE}")){
          delete $defs{$_}{helper}{cmds}{$type}{'.cmdPrep'}
                if (   defined $defs{$_}{helper} 
                    && defined $defs{$_}{helper}{cmds}
                    && defined $defs{$_}{helper}{cmds}{$type} 
                    );
        }
      }
      $h->{'.cmdPrep'}{init} = 1; 
      foreach my $defCmd (grep !/\./,keys %$h){ # prepare and parse the inputs
        $h->{'.cmdPrep'}{cmd}{$defCmd}{paraOpts} = $h->{$defCmd};
        my $hCmdIdx = $h->{'.cmdPrep'}{cmd}{$defCmd};
        $hCmdIdx->{paraOpts} =~ s/\'.*?\'//g;                                               # remove comments
        $hCmdIdx->{paraOpts} =~ s/^(textField-long,|multiple,|multiple-strict,|slider,)//g; # remove style
        $hCmdIdx->{paraOpts} =~ s/[\s]+/ /g;                                                # remove double space
        $hCmdIdx->{max} = $h->{$defCmd} =~ m/\.\.\./ ? 99 : scalar(split(" ",$hCmdIdx->{paraOpts}));
        $hCmdIdx->{paraOpts} =~ s/\.\.\.//g;

        my ($reqOpts) = map{my $foo = $_;$foo =~ s/(\[.*?\])//g;$foo}($hCmdIdx->{paraOpts}); # remove optionals
        $hCmdIdx->{min} = scalar(split(" ",$reqOpts));

        my $pCnt = 0;
        my $defUpTo = 0;
        foreach my $param (split(" ",$hCmdIdx->{paraOpts})){
          my ($opt,$def) = (0,0);
          if($pCnt > $hCmdIdx->{min}){
            if($param !~ m/^\[.*\]$/){ #any after min must be optional
              Log3 $hash->{NAME},1,"non optional parameter in $defCmd at position $pCnt while optional param before";
            }
          } 
          $pCnt++;
        }
        $hCmdIdx->{paraOpts} =~ s/[\[\]]//g;
        $hCmdIdx->{paraOpts} =~ s/[\s]+/ /g;
      }
    }
  }

  my $dDyn =    defined $hash->{helper}
             && defined $hash->{helper}{cmds}
             && defined $hash->{helper}{cmds}{dynValLst} 
                 ? $hash->{helper}{cmds}{dynValLst}
                 : undef
                 ;
  my $mDyn =    defined $modules{$hash->{TYPE}}->{helper}
             && defined $modules{$hash->{TYPE}}->{helper}{cmds}
             && defined $modules{$hash->{TYPE}}->{helper}{cmds}{dynValLst} 
                 ? $modules{$hash->{TYPE}}->{helper}{cmds}{dynValLst}
                 : undef
                 ;
  if($updated){           # prepare answer for "set <entity> ?" - generate "unknown"
    my %cPrepH;
    foreach my $pass (1,0){ #first modules - then optional overwrite by entits 
      my $h = $sources[$pass];
      next if(!$h);
   
      # prepare reply for "set/get <entity> ?"
      foreach my $cmdS (grep !/\.cmdPrep/,keys %{$h}){
        my $val = $h->{$cmdS};
        $val =~ s/\'.*?\'//g; # remove comments
        my $def = $val =~ m/\{(.*)\}/ ? $1 : "";
#        $h->{'.cmdPrep'}{cmd}{$cmdS}{def} = $def;
        $val =~ s/[\{\}]//g;  # remove default marking - not relevant for web-frontend
        $val =~ s/\s*$//g;    # remove default marking - not relevant for web-frontend
        if   ($val =~ m/^textField-long/){ # textfield is unique
          $val = ":textField-long";
        }
        elsif($val =~ m/^slider,/)       { # implement slider
          if($val =~ m/slider,[\d.]+,[\d.]+,?[\d.]*$/){
            $val = ":$val";
          }
          elsif($val =~ m/slider,\(([\d.]+)\.\.([\d.]+)[;|\)]([\d.])?[|\)]?/){
            $val = ":slider,$1,".(defined $3 ? "$3": "1").",$2";
          }
          else{
            $val = "";
          }
        }
        elsif($val =~ m/^(noArg|)$/)     { # no argument required
          $val = ":noArg";
        }
        elsif($val =~ m/ /                 # multi-parameter - no quick select
            ||$val !~ m/^(\[|multiple,|multiple-strict,)?\(.*\)\+?\]?$/){ 
          $val = "";
        }
        else                             { # no space: single param command (or less)
          my ($dispOpt,$list,$multi) = $val =~ m/(.*)\((.*)\)(\+)?/;
          $dispOpt =~ s/[\[,]//g; # preserve display option, e.g. multiple
          
          $dispOpt = (!$dispOpt && $multi ? "multiple" :  "") ;
          if($dispOpt eq "multiple" && $val !~ m/.*[\(\|]\-[^\|]*\-[\)\|].*/){
            $dispOpt = "multiple-strict";
          }
          
          my %items;
          foreach my $item (split('\|',$list)){
            if ($item =~ m/(.*)\.\.(.*)/ ){  #"(0..100;1)"
              my ($min,$max,$step) = ($1,$2,1);
              if ($max =~ m/(.*);(.*)/){
                ($max,$step) = ($1,$2);
              }
              my $f = 0;
              ($f) = map{(my $foo = $_) =~ s/.*\.//;length($foo)}($step) if ($step =~ m/\./);
              my $m = ($max - $min)/$step;
              $items{$_} = 1 foreach(map{sprintf("%.${f}f",$min + $_ * $step)}(0..$m));
            }
            else{
              $items{$item} = 1;
            }     
          }
          $val = ":$dispOpt"
                    .join(",",$def  # place default first
                             ,grep!/$def/,(sort { $a <=> $b } grep /^[\d\.]+$/,keys %items)
                                         ,(sort               grep!/^[\d\.]+$/,keys %items));
          $val =~ s/:,/:/;
        }
        $cPrepH{$cmdS} = $val;
      }
      if ($type eq "attr"){# attr does not require "unknown arg" but the definition of an attrList
        my $attrHash;
        if ($pass == 0){# entity level
          if(defined $hash->{helper}{cmds}{attr}{'.cmdPrep'}{cmd}){

            if($dDyn || $mDyn){
              foreach my $cmd(keys %cPrepH) {
                my ($open,$pass) = (0,0);
                while ($cPrepH{$cmd} =~ m/.*:.*\-([^,]*)-/){
                  my ($str,$repl) = ($1,"");
                  if($dDyn && defined $dDyn->{$str}){
                    $repl = $dDyn->{$str};
                  }
                  elsif($mDyn && defined $mDyn->{$str}){
                    $repl = $mDyn->{$str};
                  }
                  else{
                    $open = 1;
                  }
                  $cPrepH{$cmd} =~s/\-$str\-/$repl/ ;
                  $pass++;
                }
                if($pass){
                  if(!$open){ $cPrepH{$cmd} =~ s/:multiple,/:multiple-strict,/ ; }
                  else{       $cPrepH{$cmd} =~ s/:(multiple,)?/:multiple,/;     }
                }
              }
            }
                            
            $hash->{'.AttrList'} = join(" ",map{$_.$cPrepH{$_}} keys %cPrepH) ;
            $attrHash = \$hash->{'.AttrList'};
            $$attrHash =~ s/(  )//g;
            $$attrHash =~ s/\, / /g;
            $$attrHash =~ s/,+/,/g;
            $$attrHash =~ s/:,/:/;
          }
          else{
            delete $hash->{'.AttrList'};
          }
        }
        else{           # module level

          if($modules{$hash->{TYPE}}->{helper}{cmds}{attr}{'.cmdPrep'}{init} == 1){
            if( $mDyn){
              foreach my $cmd(keys %cPrepH) {
                my ($open,$pass) = (0,0);
                while ($cPrepH{$cmd} =~ m/.*:.*\-([^,]*)-/){
                  my ($str,$repl) = ($1,"");
                  if(defined $mDyn->{$str}){
                    $repl = $mDyn->{$str};
                  }
                  else{
                    $open = 1;
                  }
                  $cPrepH{$cmd} =~s/\-$str\-/$repl/ ;
                  $pass++;
                }
                if($pass){
                  if(!$open){ $cPrepH{$cmd} =~ s/:multiple,/:multiple-strict,/ ; }
                  else{       $cPrepH{$cmd} =~ s/:(multiple,)?/:multiple,/;     }
                }
              }
            }
              
            $modules{$hash->{TYPE}}{AttrList} = join(" ",map{$_.$cPrepH{$_}} keys %cPrepH);
            $modules{$hash->{TYPE}}->{helper}{cmds}{attr}{'.cmdPrep'}{init} = 2;# second level init: 
            $attrHash = \$modules{$hash->{TYPE}}{AttrList};
            $$attrHash =~ s/(  )//g;
            $$attrHash =~ s/, / /g;
            $$attrHash =~ s/,+/,/g;
            $$attrHash =~ s/:,/:/;
          }
        }
      }
      else{
        $h->{'.cmdPrep'}{unknown} = join(" ",map{$_.$cPrepH{$_}} sort keys %cPrepH)." ";
      }
    }
  }

  ################# is the command/attr defined
  my $found = 0;
  foreach my $pass (1,0){ # check first entity then module - prio
    my $h = $sources[$pass];
    next if(!$h);

    if(defined($h->{$cmd})) {# is command defined?
      $found = 1;
                         # command is defined check number of parameter

      my $paramCnt = scalar(@$ref-2);
      my $hCmdPrep = $h->{'.cmdPrep'}{cmd}{$cmd};
      if($paramCnt < $hCmdPrep->{min} || $paramCnt > $hCmdPrep->{max}){# command parameter count ok?
        $ret = "$cmd requires $hCmdPrep->{min}: $h->{cmd}{$cmd}"
              ."\n    number of parameter given:$paramCnt"
              ."\n    $cmd:$h->{$cmd}"
           ;
      }
      else{                       # number of parameter is ok - check content
        my @parIn = @$ref[2..$#$ref];
        my $pCnt = 0;
        my $paraFail = "";
        foreach my $param (split(" ",$hCmdPrep->{paraOpts})){ # check each parameter
          if($paramCnt -1  < $pCnt){                 # no param input given - use default if available
            if ($param =~ m/\(.*\{(.*)\}.*\)/){
              push @defaults,$1;
            }
            else{
              last; #  no input params anymore, defaults anymore - we are finished
            }
          }
          else{                                      # still input params - check content
            $param =~ s/.*\((.*)\)([\+]?).*/$1/;# remove brackets
            my $multi = ($2 ? 1 : 0);
            $ret = "param $pCnt:'$parIn[$pCnt]' has multiple options - select only one"
                    if(!$multi && $parIn[$pCnt] =~ m/,/);
            $param =~ s/[\{\}]//g;   # remove brackets for default
            next if (!$param);
            my $any = 0; # unspecified option
            while ($param =~ m/-([^|]+)-/){
              my ($str,$repl) = ($1,"");
              if   ($dDyn && defined $dDyn->{$str}){
                $repl = $dDyn->{$str};
              }
              elsif($mDyn && defined $mDyn->{$str}){
                $repl = $mDyn->{$str};
              }
              else{#cannot replace this placeholder - it is a wildcard
                $any = 1;
                last;
              }
              $repl =~ s/,/|/g;
              $param =~s/\-$str\-/$repl/ ;
            }
            next if ($any);
            
            my @optList =  split('\|',$param);
            my $eFail = 0;
            foreach my $x(split(",",$parIn[$pCnt])){
              if(scalar(grep/$x/,@optList) == 0){#no match
                $eFail = 1;#interims
                if($x =~ m/^-?[0-9][0-9\.]*$/){
                  foreach my $option(@optList){
                    if($option =~ m/^(\d+)..(\d+);?(\d*)/){
                      my ($l,$h,$s) = ($1,$2,$3);
                      $s = 1 if (!$s);
                      if($parIn[$pCnt]>=$1 && $parIn[$pCnt]<=$2) {
                        @$ref[$pCnt+2] = int(($parIn[$pCnt]-$l)/$s+0.5)*$s+$l;
                        @$ref[$pCnt+2] = $h if($parIn[$pCnt]>$h-$s);
                        $eFail = 0;
                        last;  
                      }
                    }
                  }
                }
                if ($eFail){
                  $ret = "param $pCnt:'$x' eFail not an option in $param";
                  last;
                }
              }
            }
            last if ($ret);
            
#            foreach my $option(@optList){
#              if($option =~ m/^(\d+)..(\d+);?(\d*)/ && $parIn[$pCnt] =~ m/^-?[0-9][0-9\.]*$/ ){
#                my ($l,$h,$s) = ($1,$2,$3);
#                $s = 1 if (!$s);
#                if($parIn[$pCnt]>=$1 && $parIn[$pCnt]<=$2) {
#                  $found2 = 1;
#                  $parIn[$pCnt] = int(($parIn[$pCnt]-$l)/$s+0.5)*$s+$l;
#                  $parIn[$pCnt] = $h if($parIn[$pCnt]>$h-$s);
#                  last;  
#                }
#              }

            if($eFail){
              $ret = "param $pCnt:'$parIn[$pCnt]' 2 does not match options '$param' ";
              last;
            }
          }
          $pCnt++;
        }
      }
    }
  }

  if (!$found){
    $ret = $sources[0] && $sources[0]->{'.cmdPrep'} && $sources[0]->{'.cmdPrep'}{unknown} ? $sources[0]->{'.cmdPrep'}{unknown}
          :$sources[1] && $sources[1]->{'.cmdPrep'} && $sources[1]->{'.cmdPrep'}{unknown} ? $sources[1]->{'.cmdPrep'}{unknown}
          :"";
    if (  $ret && $ret =~ m/\-.*\-/){
      if(   defined $hash->{helper}
         && defined $hash->{helper}{cmds}
         && defined $hash->{helper}{cmds}{dynValLst}){
        foreach(keys %{$hash->{helper}{cmds}{dynValLst}}){ # add dynamic values
          $ret =~ s/\-$_\-/$hash->{helper}{cmds}{dynValLst}{$_}/g;  
        }      
      }
      if (  $ret =~ m/\-.*\-/){#remove list if any general value is still available
        # cmd:para1,para2,-placeholder- => cmd
        $ret =~ s/([^\s]*?):[^\s]*?-[^\s]*?-[^\s]*? / $1 /g;
        # cmd:multiple,para1,para2,-placeholder- => cmd:multiple,para1,para2
        $ret =~ s/multiple([^\s]*),-[^\s]*-/multiplexx$1/g; # remove -val- from multiple but keep the statement
      }
    }
    $ret = "Unknown argument $cmd, choose one of $ret";
  }
  return ($ret,@defaults) if ($ret);
  
  if($type eq "gets"){# system relevant commands
    if($cmd eq "list")      {  ###############################################
      #"[({default}|hidden|module)]"
      my $globAttr = AttrVal("global","showInternalValues","undef");
      $attr{global}{showInternalValues} = @$ref[2] eq "default" ? 0 : 1;
      
      $ret = @$ref[2] eq "module" ? "MODULE: $hash->{TYPE}\n".PrintHash($modules{$hash->{TYPE}}, 2)
                               : CommandList(undef,$hash->{NAME});
      if ($globAttr eq "undef"){
        delete $attr{global}{showInternalValues};
      }
      else{
        $attr{global}{showInternalValues} = $globAttr;
      }
    }
    elsif($cmd eq "cmdList")   {  ###############################################
      foreach my $type ("sets","gets","attr"){
        $ret .= "commands for $type\n  ";
        my @cmd = ();
        push @cmd,map{$_ =~ s/:(textField-long,|multiple,|multiple-strict,|slider,)/:/g;$_}
                  map {"$_\t:$hash->{helper}{cmds}{$type}{$_}"} 
                  grep!/^\./,
                  keys %{$hash->{helper}{cmds}{$type}}
              if(   defined $hash->{helper} 
                 && defined $hash->{helper}{cmds}
                 && defined $hash->{helper}{cmds}{$type})
                 ;
        push @cmd,map{$_ =~ s/:(textField-long,|multiple,|multiple-strict,|slider,)/:/g;$_}
                  map {"$_\t:$modules{$hash->{TYPE}}->{helper}{cmds}{$type}{$_}"} 
                  grep!/^\./,
                  keys %{$modules{$hash->{TYPE}}->{helper}{cmds}{$type}}
              if(   defined $modules{$hash->{TYPE}}{helper}
                 && defined $modules{$hash->{TYPE}}->{helper}{cmds}
                 && defined $modules{$hash->{TYPE}}->{helper}{cmds}{$type});
    
        $ret .= join("\n  ",sort @cmd);
        $ret .= "\n\n";
      }
    }
  }
  return ($ret,@defaults);
}


sub MCAO_Define(@)      {########EXAMPLE only###########################
  my ($hash, $def) = @_;
  MCAO_defCmdAttrEntity($hash);
  return undef;
}
sub MCAO_Undef(@)       {########EXAMPLE only###########################
  my ($hash, $def) = @_;
  return undef;
}

sub MCAO_Attr(@)        {########EXAMPLE only###########################
  ##### copy this section to your module
  my @a = @_;
  my $chk = MCAO_AttrCheck(@a);
  return undef if ($chk && $chk eq "ignoreAttr");
  return $chk  if ($chk);
  ##### copy finished - @a is your @_ by not
  my ($aSet,$name,$aName,$aVal) = @a;
  my $hash = $defs{$name};
  if    ($aName eq "attr1") {
  }
  elsif ($aName eq "attr2") {
  }
  elsif ($aName eq "attr3") {
  }
  else{
    ## raise error if the ambition is to serve all attributs here
  }

  Log3 $name, 5, "set attr $aName:$aVal"; 
  return undef;
}
sub MCAO_Set($@)        {########EXAMPLE only###########################
  ##### copy this section to your module
  my ($hash, @in) = @_;
  my ($chk,$params,$kHash) = MCAO_cmdParser2($hash,"sets",@in);
  return undef if ($chk && $chk eq "done");
  return $chk if($chk);
  my @a = ($in[0],$in[1],@{$params});
  ##### copy finished - @a is your @_ by now
  my $cmd = $in[1];

  if   ($cmd eq "addDevCmd")   {
    my ($inCmd,$inDef) = split(":",join(" ",@{$params}),2);
    $hash->{helper}{cmds}{gets}{$inCmd} = $inDef;
  } 
  elsif($cmd eq "cmd2")   {
  }
  else{##### This response should be mandatory
    return "command $cmd:".join(" ",@a[2..$#a])." defined but programmed - contact your admin";
  }
  return undef;
}
sub MCAO_Get($@)        {########EXAMPLE only###########################
  ##### copy this section to your module
  my ($hash, @in) = @_;
  my @b = @in;
  my ($chk,$params,$kHash) = MCAO_cmdParser2($hash,"gets",@in);
  return undef if ($chk && $chk eq "done");
  return $chk if($chk);
  my @a = ($in[0],$in[1],@{$params});
  ##### copy finished - @a is your @_ by now
  ##### alternate: my ($name,$cmd) = ($in[0],$in[1]);
  my ($name,$cmd) = ($in[0],$in[1]);
  
  my $ret = "";
  
  if(   $cmd eq "Testbench") {  ###############################################
    # "key1 (on|off|maybe)  k1=(kv11|kv12|kv13) k2=(kv21|kv22|kv23)+ k3=[(kv31|{kv32}|kv33)]";
    # "key2 (on|off|maybe)  k1=(kv11|kv12|kv13|-wild-) ";
    # "key3 (on|off|maybe)+ k1=(kv11|kv12|kv13)+ ";
    # "key4 k41=(kv11|kv12|kv13)";
    # "key5 k51=(kv11|kv12|kv13) k52=\"adfajsfa sdf asdf asf kv11|kv12|kv13\"";
    # "key6 (on|off|maybe)+ k1=(kv11|kv12|kv13)+ *=-any- ";
    my @testseq;
    push @testseq,"$name key1 on k1=kv11 k2=kv22,kv23 "                                                   ."##r pass";
    push @testseq,"$name key1 on k1=kv11 k2=kv21"                                                         ."##r pass";
    push @testseq,"$name key2 maybe k1='wild thing'"                                                      ."##r pass";
    push @testseq,"$name key3 off,maybe k1=kv11,kv12,kv13"                                                ."##r pass";
    push @testseq,"$name key4 k41=kv11"                                                                   ."##r pass";
    push @testseq,"$name key5 k51=kv13 k52=\" bla bla bla\""                                              ."##r pass";
    push @testseq,"$name key6 on,off,maybe k1=kv11,kv12,kv13 k17='hallo hier' k28=' ad{sf a{sdf ad}}sf'"  ."##r pass";
    push @testseq,"$name key6 on,off,maybe k1=kv11,kv12,kv13 k17='hallo hier' k28=\" ad{sf a{sdf ad}}sf\""."##r pass";
    push @testseq,"$name key6 on,off,maybe k1=kv11,kv12,kv13 k17='hallo hier' k28={ ad{sf a{sdf ad}}sf}"  ."##r pass";
    push @testseq,"$name key6 on,off,maybe k1=kv11 k17=h k28={ ad{sf a{sdf ad}sf} k29={ 12{3 45}6 789}"   ."##r pass";
    push @testseq,"$name key1 on"                                                                         ."##r fail missing k1/k2\n";
    push @testseq,"$name key6 on,off,maybe k1=kv11,kv12,kv13 k17='hallo hier' k28={ ad{sf a{sdf ad}sf}"   ."##r pass";
    push @testseq,"$name key6 on,off,maybe k1=kv11,kv12,kv13 k17='hallo hier' k28={ ad{sf a{sdf ad}sf"    ."##r fail missing {\n";
    push @testseq,"$name key6 on,off,maybe k1=kv11 k17=h k28={ ad{sf a{sdf ad}s}f k29={ 12{3 45}6 789}"   ."##r fail {\n";
    
    foreach(@testseq){
      my ($inString,$expResult) = split("##r",$_);
      my @Tin = split("[ \t]",$inString);
      
      my ($Tchk,$Tparams,$TkHash) = MCAO_cmdParser2($hash,"gets",@Tin);
      if ($Tchk && $Tchk eq "done"){
        $ret .= "\nexpect:$expResult, got $Tchk for ".join("; ",@Tin);
      }
      elsif($Tchk){
        $ret .= "\nexpect:$expResult, got FAIL for in ".join("; ",@Tin);
        $ret .= "\n  $Tchk#" 
      }
      else{
        $ret .= "\nexpect:$expResult, got PASS for params: ".join("; ",@Tin)
               ."\n   params: ".join("; ",@{$Tparams})
               ."\n   keys:  " .join("\n          ",sort map{"$_ => $TkHash->{$_}"}keys %{$TkHash})
               ;      
      }
    }
  }
  elsif($cmd eq "cmd1") {  ###############################################
  }
  elsif($cmd eq "cmd2") {  ###############################################
  }
  else{##### This response should be mandatory
     $ret .= "input params: ".join("; ",@in)
             ."\n params: "  .join("; ",@{$params})
             ."\n keys:    " .join("\n          ",sort map{"$_ => $kHash->{$_}"}keys %{$kHash})
             ;
#    return "command $cmd defined but programmed - contact your admin";
  }
  return $ret;
}

sub MCAO_Notify($$;@)   {#########EXAMPLE only##########################
  my ($hash, $dev,@sim) = @_;
  my $name      = $hash->{NAME} // return;
  my $trgDevice = $dev->{NAME}  // return;
  my $events    = deviceEvents($dev, 1) || return;
  
  my $max = int(@{$events});
  for (my $i = 0; $i < $max; $i++) {
    next if(!$init_done && $events->[$i] !~ m/(INITIALIZED|REREADCFG)/);
    if ($trgDevice eq "global"){# need to verify filter upon config is changed
      if(defined $events->[$i]){
        if($events->[$i] =~ m/(INITIALIZED|REREADCFG|DELETED|DEFINED|RENAMED)/){
        }
        elsif ($events->[$i] =~ m/^(ATTR|DELETEATTR)/){#ATTR
        }
      }
    }
  }
}
1;
