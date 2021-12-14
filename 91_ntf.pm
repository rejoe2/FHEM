##############################################
# $Id: 91_ntf.pm 24129 2021-04-02 16:56:29Z rudolfkoenig $
package main;

use strict;
use warnings;
use vars qw($FW_ME);      # webname (default is fhem)
#####################################
## disable will stop all notification. Restart cost more performance
## active/inactive just stops reading capture and command execution
##
##
#####################################
sub ntf_Initialize($) {
  my ($hash) = @_;

  $hash->{DefFn}    = "ntf_Define";
  $hash->{AttrFn}   = "ntf_Attr";
     # programmer tutorial
     # with the assignment of a NotifyFn each entity will be triggered with each and every
     #   configuration action (define, rename, delete, attr) 
     #   readings setting
     #   for all entities in the system
     # For perfornamce reasons it is strictly adviced to restrict the trigger. 
     # by using "notifyRegexpChanged" methode the kernal will be enabled to restrict the
     # notifications to relevant "trigger-sourcing entites"
     # see define function and notification for an example
  $hash->{NotifyFn}    = "ntf_Notify";
  $hash->{SetFn}       = "ntf_Set";
  $hash->{GetFn}       = "ntf_Get";
  $hash->{StateFn}     = "ntf_State";
  ntf_defCmdAttrModule($hash);
}
sub ntf_defCmdAttrModule($) {
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
     #              sub ntf_Set($@) {
     #                my ($hash, @a) = @_;
     #                my  $err = ntf_cmdParser($hash,$hash->{helper}{cmds}{sets},@a);
     #                return $err if($err);
     #     at attribute assignment
     #        actually no difference to set/get. Atributes only have one value - nevertheless
     #        the supply for the web-frontend is similar important as well as the drop-down 
     #        lists and the verification of parameters for valid. 
     #     get cmdList
     #        The get-command 'cmdList' should be implemented for all entites.
     #

  {    # set
    $hash->{helper}{cmds}{sets}{inactive}    = "";
    $hash->{helper}{cmds}{sets}{active}      = "";
    $hash->{helper}{cmds}{sets}{clear}       = "(trigger|readings|{readingLog})";
    $hash->{helper}{cmds}{sets}{simTrigger}  = "-trigger- ...";
    $hash->{helper}{cmds}{sets}{trgAdd}      = "(-name-) [(:)] [(-event-)] ...";
    $hash->{helper}{cmds}{sets}{trgDel}      = "(-combTrgElement-)'part of a combined trigger attribut'";
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
  }
  {    # get
    $hash->{helper}{cmds}{gets}{list}                  = "[({default}|hidden|module)]";
    $hash->{helper}{cmds}{gets}{cmdList}               = "[({short}|long)]";
    $hash->{helper}{cmds}{gets}{clear}                 = "(trigger|readings)";
    $hash->{helper}{cmds}{gets}{shEnroled}             = "";
    $hash->{helper}{cmds}{gets}{trgFilter}             = "";
  }
  {    # attr
    $hash->{helper}{cmds}{attr}{disable}               = '(1|0)';
    $hash->{helper}{cmds}{attr}{disabledForIntervals}  = '-disable-';
    $hash->{helper}{cmds}{attr}{disabledAfterTrigger}  = '-seconds-';
    $hash->{helper}{cmds}{attr}{forwardReturnValue}    = "(1|0)";
    $hash->{helper}{cmds}{attr}{ignoreRegexp}          = "(1|0)";
    $hash->{helper}{cmds}{attr}{readLog}               = "(1|0)";
    
    $hash->{helper}{cmds}{attr}{trgDevice}             = "multiple,(-trgNames-) 'regex possible light.* or (light1|light2)'";
    $hash->{helper}{cmds}{attr}{trgEvent}              = "textField-long,-Event- 'Reading:value'";
    $hash->{helper}{cmds}{attr}{trgReading}            = "-readingRegex- 'reading(s) to be evaluated e.g.'";
    $hash->{helper}{cmds}{attr}{trgReadValue}          = "-readingValueRegex-)] 'value of the reading'";
    $hash->{helper}{cmds}{attr}{trgCombined}           = "textField-long,-NameEvent- 'should have a colon <name1>:<event1>,<name2>:<event2>'";
    $hash->{helper}{cmds}{attr}{trgCmd}                = "textField-long,-Cmd-";
    $hash->{helper}{cmds}{attr}{logTrgNames}           = "(1|0)";
 }
}
sub ntf_defCmdAttrEntity($) {
  my $hash = shift;  # hash to module
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

sub ntf_Define($$) {#####################################
  my ($hash, $def) = @_;
  my ($name, $type, $re, $command) = split("[ \t\n]+", $def, 4);
  $hash->{helper}{active}  = 1;
  $hash->{helper}{disbled} = 0;
  
  ntf_defCmdAttrEntity($hash);# programmer tutorial: define sets, gets, attr unique per module
  ntf_cmdParser($hash,"attr",("",""));

  InternalTimer(gettimeofday()+2, sub(){notifyRegexpChanged($hash,0,1); }, $hash);# no notification required for this device
  if (defined $re && $re ne ""){
    CommandAttr (undef,"$name trgCombined $re");
    if (defined $command && $command ne ""){
      CommandAttr (undef,"$name trgCmd $command");      
    }
  }
  readingsSingleUpdate($hash, "state", "active", 1);
  return undef;
}

sub ntf_AttrCheck(@) {############################
    # verify if attr is applicable
    # programmer tutorial
    #  recommended usage
    #     my $chk = ntf_AttrCheck($name, $aSet, $aName, $aVal);
    #     return undef if ($chk && $chk eq "ignoreAttr");
    #     return $chk  if ($chk);
    #     Usage
    #        sub ntf_Attr(@) {
    #          my @a = @_;
    #          my ($aSet,$name,$aName,$aVal) =@a;
    #          my $hash = $defs{$name};
    #          my $chk = ntf_AttrCheck($hash, $aSet, $aName, $aVal);
    #          return undef if ($chk && $chk eq "ignoreAttr");
    #          return $chk  if ($chk);
  
  my ($aSet,$name,$aName,$aVal) = @_;
  if ( !defined $modules{$defs{$name}{TYPE}}{helper}{cmds}{attr}{'.cmdPrep'}
    || !defined $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}){
    ntf_cmdParser($defs{$name},"attr",("",""));
  }
  return "ignoreAttr" if (!$init_done);  
  return undef if ($aSet ne "set");  # allow delete any time

  my  $chk = ntf_cmdParser($defs{$name},"attr",($name,$aName,(defined $aVal?$aVal:"")));
  if ($chk && $chk =~ m/^Unknown/){#not a module attribute
    my $a = " ".getAllAttr($name)." ";
    if($a !~ m/ $aName[ :]+/){
      $a =~ s/:.*? //g;
      return "attribut $aName not valid. Use one of $a";
    }
    else{
      return "ignoreAttr" ; # attr valid but not in module context - ok for me
    }
  }
  
  my $attrOpt =     defined $modules{$defs{$name}{TYPE}}{helper}{cmds}
                 && defined $modules{$defs{$name}{TYPE}}{helper}{cmds}{attr}
                 && defined $modules{$defs{$name}{TYPE}}{helper}{cmds}{attr}{'.cmdPrep'}
                 && defined $modules{$defs{$name}{TYPE}}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}
                 && defined $modules{$defs{$name}{TYPE}}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}{$aName} 
                                                                                                    ?  $modules{$defs{$name}{TYPE}}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}{$aName}{paraOpts}
                :   defined $defs{$name}{helper}{cmds}{attr}   
                 && defined $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}
                 && defined $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}
                 && defined $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}{$aName}
                                                                                                    ?  $defs{$name}{helper}{cmds}{attr}{'.cmdPrep'}{cmd}{$aName}{paraOpts}
                :"";
 
  return undef if (!$attrOpt                               # any value allowed
                 || $attrOpt =~ m/^(multiple|textField-)/  # any value allowed
                 || $attrOpt !~ m/^\(\)$/                  # no list defined
                 || grep/^$aVal$/,split(",",$attrOpt)      # identified
                 );
  return "value $aVal not allowed. Choose one of:$attrOpt";
}
sub ntf_cmdParser($$@){#hash to entity, hash to commands, input array
  my $hash = shift;
  my $type = shift;
  my $ref = \@_;
  my $cmd = @$ref[1];   
  my $ret;
  return "ntf_cmdParser called while hash not defined - contact admin" if (!defined $hash 
                                                                        || !defined $hash->{TYPE}
                                                                        || !defined $modules{$hash->{TYPE}});
    # programmer tutorial
    #    this sub can be used generic for ANY module.
    #    it has potential and should actually be included in the kernal SW
    # usage  
    #     1) set     
    #        sub ntf_Set($@) {
    #          my ($hash, @a) = @_;
    #          my  $chk = ntf_cmdParser($hash,"sets",@a);
    #          return undef if ($chk && $chk eq "done");
    #          return $chk if($chk);
    #     2) get     
    #        sub ntf_Get($@) {
    #          my ($hash, @a) = @_;
    #          my  $chk = ntf_cmdParser($hash,"gets",@a);
    #          return undef if ($chk && $chk eq "done");
    #          return $chk if($chk);
    #     3) attr
    #        sub ntf_Attr(@) {
    #          see  ntf_AttrCheck($hash,$aSet, $aName,$aVal);
    #     4) update {ntf_cmdParser($defs{a},"attr",(undef,"updt"))}
    #          my  $chk = ntf_cmdParser($hash,<gets|sets|attr>,(undef,"updt",<{module}|device>));

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
#    return undef;
  }

  my $updated = 0;
  foreach my $pass (1,0){ #first modules - then optional overwrite by entits 
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
        $hCmdIdx->{paraOpts} =~ s/\'.*?\'//g;
        $hCmdIdx->{paraOpts} =~ s/^(textField-long,|multiple,|multiple-strict,|slider,)//g;
        $hCmdIdx->{paraOpts} =~ s/[\s]+/ /g;
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
        $val =~ s/[\{\}]//g;  # remove default marking - not relevant for web-frontend
        $val =~ s/\s*$//g;  # remove default marking - not relevant for web-frontend
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
            ||$val !~ m/^(\[|multiple,|multiple-strict,)?\(.*\)\]?$/){ 
           $val = "";
        }
        else                             { # no space - this is a single param command (or less)
          my ($dispOpt,$list) = $val =~ m/(.*)\((.*)\)/;
          $dispOpt =~ s/[\[,]//g; # preserve display option, e.g. multiple
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
          $val = ":".join(",",$def  # place default first
                             ,grep!/$def/,(sort { $a <=> $b } grep /^[\d\.]+$/,keys %items)
                                         ,(sort               grep!/^[\d\.]+$/,keys %items));
          $val =~ s/:,/:/;
          $val =~ s/:/:$dispOpt,/ if($dispOpt);
        }
        $cPrepH{$cmdS} = $val;
      }
      if ($type eq "attr"){# attr does not require "unknown arg" but the definition of an attrList
        my $attrHash;
        if ($pass == 0){# entity level
          if(defined $hash->{helper}{cmds}{attr}{'.cmdPrep'}{cmd}){
            $hash->{'.AttrList'} = join(" ",map{$_.$cPrepH{$_}} keys %cPrepH) ;
            $attrHash = \$hash->{'.AttrList'};
          }
          else{
            delete $hash->{'.AttrList'};
          }
        }
        else{           # module level
          $modules{$hash->{TYPE}}{AttrList} = join(" ",map{$_.$cPrepH{$_}} keys %cPrepH);
          $attrHash = \$modules{$hash->{TYPE}}{AttrList};
        }
        if ($attrHash && $$attrHash =~ m/\-[^\s]*\-/){# add dynamic param options
          if(   $pass == 0
             && defined $hash->{helper}
             && defined $hash->{helper}{cmds}
             && defined $hash->{helper}{cmds}{dynValLst}){
            foreach(keys %{$hash->{helper}{cmds}{dynValLst}}){ # add dynamic values
              my $f = $$attrHash =~ s/\-$_\-/$hash->{helper}{cmds}{dynValLst}{$_}/g;  
            } 
          }
          if(   defined $modules{$hash->{TYPE}}->{helper}
             && defined $modules{$hash->{TYPE}}->{helper}{cmds}
             && defined $modules{$hash->{TYPE}}->{helper}{cmds}{dynValLst}){
            foreach(keys %{$modules{$hash->{TYPE}}->{helper}{cmds}{dynValLst}}){ # add dynamic values
              my $f = $$attrHash =~ s/\-$_\-/$modules{$hash->{TYPE}}->{helper}{cmds}{dynValLst}{$_}/g;  
            } 
          }
          $$attrHash =~ s/\-[^\s]*\-//g;
          $$attrHash =~ s/(  )//g;
          $$attrHash =~ s/:,/:/g;
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
            $param =~ s/.*\((.*)\).*/$1/;# remove brackets
            $param =~ s/[\{\}]//g;   # remove brackets for default
            my $found2 = 0;
            next if (!$param);
            foreach my $option(split('\|',$param)){
              if ($parIn[$pCnt] eq $option){     # valid
                $found2 = 1;
                last;  
              }
              elsif($option =~ m/^-(.*)-$/){
                my $optSpecial = $1;
                my $par = $parIn[$pCnt];
                if (   defined $hash->{helper} 
                    && defined $hash->{helper}{cmds}
                    && defined $hash->{helper}{cmds}{options}
                    && defined $hash->{helper}{cmds}{options}{$optSpecial}){#options defined - so have to match
                  if ($hash->{helper}{cmds}{options}{$optSpecial} =~ m/[^,]$par[,]/){
                    $found2 = 1;
                    last;  
                  } 
                }
                else{#wildcard: anything matches
                  $found2 = 1;
                  last;  
                }
              }
              elsif($option =~ m/^(\d+)..(\d+);?(\d*)/){
                if($parIn[$pCnt]>=$1 && $parIn[$pCnt]<=$2) {
                  $found2 = 1;
                  last;  
                }
                else{
                }
              }
            }
            if(!$found2){
              $ret = "param $pCnt:'$parIn[$pCnt]' does not match options '$param'";
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

sub ntf_Attr(@)        {###################################
  my @a = @_;
  my $chk = ntf_AttrCheck(@a);
  return undef if ($chk && $chk eq "ignoreAttr");
  return $chk  if ($chk);
  my ($aSet,$name,$aName,$aVal) = @a;
  my $hash = $defs{$name};
  if    ($aName eq "readLog"     ) {
    if  ($aSet eq "set"){
      if($aVal) {
        $logInform{$name} = sub($$){
          my ($me, $msg) = @_;
          return if(defined($hash->{CHANGED}));
          $hash->{CHANGED}[0] = $msg;
          ntf_Notify($hash, $hash);
          delete($hash->{CHANGED});
        }
      } 
      else {
        delete $logInform{$name};
      }
      return;
    }
  }
  elsif ($aName eq "trgDevice"   ) {
    ntf_prepTgrNames($hash
                   ,undef
                   ,($aSet eq "set" ? $aVal : "")
                   ,undef
                   );
  }
  elsif ($aName eq "trgEvent"    ) {
     my $read    = AttrVal($name,"trgReading",undef);
     my $readVal = $read ? "$read: ". AttrVal($name,"trgReadValue",".*")
                         : "";
     ntf_prepTgrNames($hash
                   ,undef
                   ,undef
                   ,join("|",grep/./,($readVal
                                   ,$aSet eq "set" ? $aVal
                                                   : ".*"))
                   );
  }
  elsif ($aName eq "trgReading"  ) {
     ntf_prepTgrNames($hash
                   ,undef
                   ,undef
                   ,join("|",grep/./,(($aSet eq "set" && $aVal 
                                    ? $aVal.": ". AttrVal($name,"trgReadValue",".*")
                                    : undef)
                                    ,AttrVal($name,"trgEvent","")))
                   );
  }
  elsif ($aName eq "trgReadValue") {
     ntf_prepTgrNames($hash
                   ,undef
                   ,undef
                   ,join("|",grep/./,(($aSet eq "set" && $aVal 
                                    ? AttrVal($name,"trgReading",".*").": ". $aVal
                                    : undef)
                                    ,AttrVal($name,"trgEvent","")))
                   );
  }
  elsif ($aName eq "trgCombined" ) {
    ntf_prepTgrNames($hash
                   ,($aSet eq "set" ? $aVal : "")
                   ,undef
                   ,undef
                   );
    if($aSet eq "set"){
      $hash->{helper}{cmds}{dynValLst}{combTrgElement} = $aVal;
    }
    else{
      delete $hash->{helper}{cmds}{dynValLst}{combTrgElement};
    }
  }
  elsif ($aName eq "trgCmd"      ) {
    if($aSet eq "set"){
      my %specials= (
        "%NAME" => $name,
        "%TYPE" => $name,
        "%EVENT" => "1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0",
        "%SELF" => $name,
      );
      my $err = perlSyntaxCheck($aVal, %specials);
      return $err if($err);
      $hash->{".COMMAND"} = $aVal;
    }
  }
  elsif ($aName eq "logTrgNames" ) {
    if(!$aVal){# delete or set to 0
      delete $hash->{READINGS}{$_} foreach(grep/^log_/,keys %{$hash->{READINGS}});
    }
  }
  elsif ($aName eq "ignoreRegexp") {
    if($aSet eq "set"){
      return "Missing argument for ignoreRegexp";
      eval { "HALLO" =~ m/$aVal/ };
      return $@;
    }
  }
  elsif ($aName eq "disable"     ) {
    $hash->{helper}{disbled} = $aSet eq "set" ? $aVal : 0;

    my $state = $hash->{helper}{disbled} ? "disabled"
               :$hash->{helper}{active}  ? "active"
                                         : "inactive";
    readingsSingleUpdate($hash, "state", $state, 1);
    ntf_prepTgrNames( $hash
                     ,undef
                     ,undef
                     ,undef
                     );
  }

  Log3 $name, 5, "set attr $aName:$aVal"; 
  return undef;
}
sub ntf_Set($@)        {###################################
  my ($hash, @a) = @_;
  my $me = $hash->{NAME};

  my  ($chk,@defaults) = ntf_cmdParser($hash,"sets",@a);
  push @a,@defaults;
  return undef if ($chk && $chk eq "done");
  return $chk if($chk);

  my $cmd = $a[1];
  if   ($cmd eq "clear")      {
    if   ($a[2] eq "trigger"   ){
      delete $hash->{READINGS}{$_} foreach(grep /^(trg|log_)/,keys %{$hash->{READINGS}});        
    }
    elsif($a[2] eq "readingLog"){
      delete $hash->{READINGS}{$_} foreach(grep/^log_/,keys %{$hash->{READINGS}});
    }
    elsif($a[2] eq "readings"  ){
      delete $hash->{READINGS}{$_} foreach(keys %{$hash->{READINGS}});
    }
  } 
  elsif($cmd eq "inactive")   {
    if (!AttrVal($me,"disabled",0)){# disabled is higher that inactive
      readingsSingleUpdate($hash, "state", "inactive", 1);
    }
    $hash->{helper}{active} = 0;
  }
  elsif($cmd eq "active")     {
    if(!AttrVal($me, "disable", 0)){
      readingsSingleUpdate($hash, "state", "active", 1) ;
    }
    $hash->{helper}{active} = 1;
  }
  elsif($cmd eq "simTrigger") {
    my @b =  @a;
    shift @b;
    shift @b;
    my ($trgDevice,$trgEvt) = split(" ",join(" ",@b),2);
    return "$trgDevice undefined" if(!defined $defs{$trgDevice});
    ntf_Notify($hash,$defs{$trgDevice},($trgEvt));
  }
  elsif($cmd eq "trgAdd")     {
    my (undef,undef,@val)=@a;
    my ($trgDevice,$trgVal) = map{my $foo=$_;$foo=~s/ //g;$foo}
                            split(":",join(" ",@val),2);

    $trgDevice = ".*" if (!$trgDevice);
    $trgVal  = ".*"  if (!$trgVal);
    
    my %h = map { $_ => 1 } (split(",",AttrVal($me,"trgCombined","")),"$trgDevice:$trgVal");

    my $ret = CommandAttr(undef, "$me trgCombined ".join(",",keys %h));
    return $ret if($ret);
  }
  elsif($cmd eq "trgDel")     {
    my @trigger=();
    foreach my $trg (split(",",AttrVal($me,"trgCombined",""))){
      push @trigger,$trg if($trg ne $a[2]);
    }
    CommandAttr(undef, "$me trgCombined ".join(",",@trigger));
  }
#  elsif($cmd =~ m/tst\d/)      {
#    return "$cmd : ".join(",",@a);
#  }
#  elsif($cmd eq "tstAddSet")  {
#    $hash->{helper}{cmds}{sets}{$a[2]} = (defined $a[3] ? join(" ",@a[3..$#a]):"") ;
#    delete $hash->{helper}{cmds}{sets}{'.cmdPrep'}; # force recalculation
#    $hash->{helper}{cmds}{dynValLst}{localSetCmd} = join(",",keys %{ $hash->{helper}{cmds}{sets}});
#  }
#  elsif($cmd eq "tstAddGet")  {
#    $hash->{helper}{cmds}{gets}{$a[2]} = (defined $a[3] ? join(" ",@a[3..$#a]):"") ;
#    delete $hash->{helper}{cmds}{gets}{'.cmdPrep'}; # force recalculation
#    $hash->{helper}{cmds}{dynValLst}{localGetCmd} = join(",",keys %{ $hash->{helper}{cmds}{gets}});    
#  }
#  elsif($cmd eq "tstAddAttr") {
#    $hash->{helper}{cmds}{attr}{$a[2]} = (defined $a[3] ? join(" ",@a[3..$#a]):"") ;
#    delete $hash->{helper}{cmds}{attr}{'.cmdPrep'}; # force recalculation
#    $hash->{helper}{cmds}{dynValLst}{localGetCmd} = join(",",keys %{ $hash->{helper}{cmds}{attr}});    
#  }
#  elsif($cmd eq "tstDelSet")  {
#    delete $hash->{helper}{cmds}{sets}{$a[2]}; 
#    delete $hash->{helper}{cmds}{sets}{'.cmdPrep'}; # force recalculation
#    $hash->{helper}{cmds}{dynValLst}{localSetCmd} = join(",",keys %{ $hash->{helper}{cmds}{sets}});
#  }
#  elsif($cmd eq "tstDelGet")  {
#    delete $hash->{helper}{cmds}{gets}{$a[2]}; 
#    delete $hash->{helper}{cmds}{gets}{'.cmdPrep'}; # force recalculation
#    $hash->{helper}{cmds}{dynValLst}{localGetCmd} = join(",",keys %{ $hash->{helper}{cmds}{gets}});
#  }
#  elsif($cmd eq "tstDelAttr") {
#    delete $hash->{helper}{cmds}{attr}{$a[2]}; 
#    delete $hash->{helper}{cmds}{attr}{'.cmdPrep'}; # force recalculation
#    $hash->{helper}{cmds}{dynValLst}{localGetCmd} = join(",",keys %{ $hash->{helper}{cmds}{attr}});
#  }
  else{
    return "command $cmd:".join(" ",@a[2..$#a])." defined but programmed - contact your admin";
  }
  return undef;
}
sub ntf_Get($@)        {###################################
  my ($hash, @a) = @_;
  my $me = $hash->{NAME};

  my  ($chk,@defaults) = ntf_cmdParser($hash,"gets",@a);
  push @a,@defaults;
  return undef if ($chk && $chk eq "done");
  return $chk if($chk);
 
  my $cmd = $a[1];
  my $ret;
  if(   $cmd eq "shEnroled") {  ###############################################
    $ret = "enroled for :\n".join("\n",sort map{$_=~s/^(.*)\:.*/$1/;;$_} grep/[:,]$me\,/,map{$_.":".join(',',@{$ntfyHash{$_}}).','}keys %ntfyHash);
  }
  elsif($cmd eq "trgFilter") {  ###############################################
    if (defined $hash->{helper}{trg}){
      foreach my $x(keys %{$hash->{helper}{trg}}){
        $ret .= "\n$x:";
        $hash->{helper}{trg}{$x} =~ m/^\^\((.*)\)\$$/;
        foreach(split('\|',$1)){
          my($re,$va)=split(": ",$_);
          $ret.="\n         read: $re \t=> val: $va";
        }
      }
    }
    else{
      $ret = "no trigger defined";
    }
  }

  return $ret;
}

sub ntf_Notify($$;@)   {###################################
  my ($hash, $dev,@sim) = @_;
  my $name = $hash->{NAME} // return;
  return "" if(IsDisabled($name));

  my $now = gettimeofday();
  my $dat = AttrVal($name, "disabledAfterTrigger", 0);
  return "" if(   $hash->{TRIGGERTIME} 
               && $init_done
               && $now <  $hash->{TRIGGERTIME} + $dat
                 );
  return if (!defined $dev->{NAME});
  my $trgDevice = $dev->{NAME};
  my $iRe = AttrVal($name, "ignoreRegexp", undef);
  my $events;

  if (scalar @sim > 0){
    $events = \@sim;      
  }
  else{
    $events = deviceEvents($dev, 1);
  }
  return if(!$events); # Some previous ntf deleted the array.
  my $max = int(@{$events});
  my $t = $dev->{TYPE};
  my $ret = "";
  my %cfgChn = (name => 0,attr => 0);
  for (my $i = 0; $i < $max; $i++) {
    next if(!$init_done && $events->[$i] !~ m/(INITIALIZED|REREADCFG)/);
    if ($trgDevice eq "global"){# need to verify filter upon config is changed
      if(defined $events->[$i]){
        if($events->[$i] =~ m/(INITIALIZED|REREADCFG)/){
          foreach my $a (%{$attr{$name}}){# evaluate all attributes by re-assign
            next if(!defined $a || $a !~ m/../ || !$attr{$name}{$a});
            CommandAttr(undef, "$name $a $attr{$name}{$a}");
          }
          if ( !defined $modules{$hash->{TYPE}}{helper}{cmds}{attr}{'.cmdPrep'}
            || !defined $hash->{helper}{cmds}{attr}{'.cmdPrep'}){
            ntf_cmdParser($hash,"attr",("","undef"));
          }
        }
        if($events->[$i] =~ m/(INITIALIZED|REREADCFG|DELETED|DEFINED|RENAMED)/){
          $cfgChn{name} = 1;
          $modules{$hash->{TYPE}}{helper}{cmds}{dynValLst}{trgNames} = join(",",sort keys %defs);
          ntf_cmdParser($hash,"attr",("","undef"));
          
          if ($events->[$i] =~ m/^RENAMED ([^\s]+) ([^\s]+)/){# refresh the selection of trigger entites
            my ($old,$new) = ($1,$2);
            my $trgDevice = AttrVal($name,"trgDevice","");
            my $trgNameNew = $trgDevice;
            $trgNameNew =~ s/([\(\|])$old([\)\|])/$1$new$2/g;
            $trgNameNew =~ s/^$old$/$new/; 
            if($trgNameNew ne $trgDevice){
              CommandAttr(undef, "$name trgDevice $trgNameNew");
              Log3 $name, 2, "updated attr trgDevice from $trgDevice to $trgNameNew due to rename"; 
            }
          }
        }
        elsif ($events->[$i] =~ m/^(ATTR|DELETEATTR)/){#ATTR
          if ($events->[$i] =~ m/ignore.*1/){
            $cfgChn{name} = 1;
          }
          else{
            $cfgChn{attr} = 1;
          }
        }
      }
    }
    {
      last if(!$hash->{helper}{active}); #no processing when inactive
      my $s = !defined $events->[$i] ? "" :$events->[$i];

      next if( !$hash->{helper}{trg}{$trgDevice}
            || $s !~ m/$hash->{helper}{trg}{$trgDevice}/); # filter does not match

      my ($r,$v) = split(": ",$s,2);
      if ($trgDevice eq "global"){($r,$v) = split(" " ,$s,2);}
      else                       {($r,$v) = split(": ",$s,2);}
      $v = "--" if(!defined $v);

      {#command execute
        Log3 $name, 5, "Triggering $name from $trgDevice : $s";
        my %specials= (
                  "%NAME" => $trgDevice,
                  "%TYPE" => $t,
                  "%EVENT"=> $s,
                  "%SELF" => $name
        );
        my $cmd  = AttrVal($name,"trgCmd","");
        my $exec = EvalSpecials($cmd, %specials);
        
        {# set readings
          readingsBeginUpdate($hash);
          readingsBulkUpdate($hash,"lastTrgDevice"  , $trgDevice);
          readingsBulkUpdate($hash,"lastTrgEvent"   , $s        );
          readingsBulkUpdate($hash,"lastTrgReading" , $r        );
          readingsBulkUpdate($hash,"lastTrgReadVal" , $v        );
          readingsBulkUpdate($hash,"state"          , "last:".FmtDateTime($now)    );
          readingsBulkUpdate($hash,"log_$trgDevice" , $s      ) if(AttrVal($name,"logTrgNames",0));
          readingsEndUpdate($hash,1);
        }
        
        next if($cmd !~ m/.../);
        Log3 $name, 4, "$name exec $exec";
        my $r = AnalyzeCommandChain(undef, $exec);
        if($r){
          Log3 $name, 3, "$name return value: $r";
          $ret .= " $r";
        }
        last if($dat);
      }
    }
  }
  if (  ($cfgChn{attr} && $hash->{helper}{trgByAttr})
      ||$cfgChn{name} ){# search my new friends
    ntf_prepTgrNames($hash,undef,undef,undef);
    ntf_cmdParser($hash,"attr",("","updt","module")) if ($cfgChn{name});
  }

  return (AttrVal($name, "forwardReturnValue", 0) ? $ret : undef);
}

sub ntf_prepTgrNames($$$$){################################
    my ($hash,$trgComb,$trgDevice,$trgEvnt) = @_;
    my $nameLstOld = defined $hash->{helper}{trg} 
                       ? join("|",sort grep /./,(keys %{$hash->{helper}{trg}},"global"))
                       : ""
                       ; 
    my %names;
    $hash->{helper}{trgByAttr} = 0;
    if (!$hash->{helper}{disbled}){
      $trgComb   = AttrVal($hash->{NAME},"trgCombined","") if(!defined $trgComb  );
      $trgDevice = AttrVal($hash->{NAME},"trgDevice"  ,"") if(!defined $trgDevice);
      foreach (split(",",$trgComb)){
        my ($n,$v) = split(":",$_,2);
        $v = ".*" if (!$v);
        $names{$_} .= "|".$v foreach(devspec2array("i:NAME=".$n));
      }
      if ($trgDevice){
        my @trgDeviceLst;
        foreach my $fltr (split(":FILTER=",$trgDevice)){
          if ($fltr =~ m/^.:/){
            next if ($fltr =~ m/^r:/
                  ||($fltr =~ m/^i:/ && $fltr !~ m/^i:(NAME|TYPE|DEF)/ ));
            push @trgDeviceLst,$fltr;
          }
          elsif ($fltr =~ m/^(NAME|TYPE|DEF)[=!~<>]/){
            push @trgDeviceLst,"i:".$fltr;
          }
          elsif ($fltr =~ m/^.+[=!~<>]/){
            push @trgDeviceLst,"a:".$fltr;
            $hash->{helper}{trgByAttr}=1;
          }
          else{
            push @trgDeviceLst,"i:NAME=".$fltr;
          }
        }
        my $read    = AttrVal($hash->{NAME},"trgReading",undef);
        my $readVal = $read ? "$read: ". AttrVal($hash->{NAME},"trgReadValue",".*")   
                         : "";
        my @fltr    = grep/./,( $readVal,AttrVal($hash->{NAME},"trgEvent"   ,"")); 
        $trgEvnt    = join("|",@fltr)             if(!defined $trgEvnt  );
        $names{$_} .= "|".$trgEvnt foreach(devspec2array(join(":FILTER=",@trgDeviceLst)));
      }
      foreach(keys %names){
        $names{$_} =~ s/^\|(.*)/\^\($1\)\$/  ;
        delete $names{$_} if(!defined $defs{$_});
      }
    }

    delete $hash->{helper}{trg};
    $hash->{helper}{trg} = \%names;
    my $nameLstNew =  join("|", sort grep /./,(keys %names,"global"));
    if($nameLstOld ne $nameLstNew){
      if(scalar keys %names){
        InternalTimer(gettimeofday()+1, sub(){  notifyRegexpChanged($hash, $nameLstNew,0) }, $hash);
      }
      else{
        InternalTimer(gettimeofday()+1, sub(){  notifyRegexpChanged($hash, 0,1) }, $hash);
      }
    }
#    return 1;
}

#############
sub ntf_State($$$$) {
  my ($hash, $tim, $vt, $val) = @_;

  return undef if($vt ne "state" || $val ne "inactive");
  readingsSingleUpdate($hash, "state", "inactive", 1);
  return undef;
}

1;

=pod
=item helper
=item summary    execute a command upon receiving an event
=item summary_DE f&uuml;hrt bei Events Anweisungen aus
=begin html

<a id="notify"></a>
<h3>notify</h3>
<ul>
  <br>

  <a id="notify-define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; notify &lt;pattern&gt; &lt;command&gt;</code>
    <br><br>
    Execute a command when received an event for the <a

    href="#define">definition</a> <code>&lt;pattern&gt;</code>. If
    &lt;command&gt; is enclosed in {}, then it is a perl expression, if it is
    enclosed in "", then it is a shell command, else it is a "plain" fhem.pl
    command (chain).  See the <a href="#trigger">trigger</a> command for
    testing it.

    Examples:
    <ul>
      <code>define b3lampV1 notify btn3 set lamp $EVENT</code><br>
      <code>define b3lampV2 notify btn3 { fhem "set lamp $EVENT" }</code><br>
      <code>define b3lampV3 notify btn3 "/usr/local/bin/setlamp "$EVENT""</code><br>
      <code>define b3lampV3 notify btn3 set lamp1 $EVENT;;set lamp2 $EVENT</code><br>
      <code>define wzMessLg notify wz:measured.* "/usr/local/bin/logfht $NAME "$EVENT""</code><br>
      <code>define LogUndef notify global:UNDEFINED.* "send-me-mail.sh "$EVENT""</code><br>
    </ul>
    <br>

    Notes:
    <ul>
      <li><code>&lt;pattern&gt;</code> is either the name of the triggering
         device, or <code>devicename:event</code>.</li>

      <li><code>&lt;pattern&gt;</code> must completely (!)
        match either the device name, or the compound of the device name and
        the event.  To identify the events use the inform command from the
        telnet prompt or the "Event Monitor" link in the browser
        (FHEMWEB), and wait for the event to be printed. See also the
        eventTypes device.</li>

      <li>in the command section you can access the event:
      <ul>
        <li>The variable $EVENT will contain the complete event, e.g.
          <code>measured-temp: 21.7 (Celsius)</code></li>
        <li>$EVTPART0,$EVTPART1,$EVTPART2,etc contain the space separated event
          parts (e.g. <code>$EVTPART0="measured-temp:", $EVTPART1="21.7",
          $EVTPART2="(Celsius)"</code>. This data is available as a local
          variable in perl, as environment variable for shell scripts, and will
          be textually replaced for FHEM commands.</li>
        <li>$NAME and $TYPE contain the name and type of the device triggering
          the event, e.g. myFht and FHT</li>
       </ul></li>

      <li>Note: the following is deprecated and will be removed in a future
        release. It is only active for featurelevel up to 5.6.
        The described replacement is attempted if none of the above
        variables ($NAME/$EVENT/etc) found in the command.
      <ul>
        <li>The character <code>%</code> will be replaced with the received
        event, e.g. with <code>on</code> or <code>off</code> or
        <code>measured-temp: 21.7 (Celsius)</code><br> It is advisable to put
        the <code>%</code> into double quotes, else the shell may get a syntax
        error.</li>

        <li>The character @ will be replaced with the device
        name.</li>

        <li>To use % or @ in the text itself, use the double mode (%% or
        @@).</li>

        <li>Instead of % and @, the parameters %EVENT (same as %), %NAME (same
        as @) and %TYPE (contains the device type,
        e.g.  FHT) can be used. The space separated event "parts"
        are available as %EVTPART0, %EVTPART1, etc.  A single %
        looses its special meaning if any of these parameters appears in the
        definition.</li>
      </ul></li>

      <li>Following special events will be generated for the device "global"
      <ul>
          <li>INITIALIZED after initialization is finished.</li>
          <li>REREADCFG after the configuration is reread.</li>
          <li>SAVE before the configuration is saved.</li>
          <li>SHUTDOWN before FHEM is shut down.</li>
          <li>DEFINED &lt;devname&gt; after a device is defined.</li>
          <li>DELETED &lt;devname&gt; after a device was deleted.</li>
          <li>RENAMED &lt;old&gt; &lt;new&gt; after a device was renamed.</li>
          <li>UNDEFINED &lt;defspec&gt; upon reception of a message for an
          undefined device.</li>
      </ul></li>

      <li>Notify can be used to store macros for manual execution. Use the <a
          href="#trigger">trigger</a> command to execute the macro.
          E.g.<br>
          <code>fhem> define MyMacro notify MyMacro { Log 1, "Hello"}</code><br>
          <code>fhem> trigger MyMacro</code><br>
          </li>

    </ul>
  </ul>
  <br>


  <a id="notify-set"></a>
  <b>Set </b>
  <ul>
    <a id="notify-set-addRegexpPart"></a>
    <li>addRegexpPart &lt;device&gt; &lt;regexp&gt;<br>
        add a regexp part, which is constructed as device:regexp.  The parts
        are separated by |.  Note: as the regexp parts are resorted, manually
        constructed regexps may become invalid. </li>
    <a id="notify-set-removeRegexpPart"></a>
    <li>removeRegexpPart &lt;re&gt;<br>
        remove a regexp part.  Note: as the regexp parts are resorted, manually
        constructed regexps may become invalid.<br>
        The inconsistency in addRegexpPart/removeRegexPart arguments originates
        from the reusage of javascript functions.</li>
    <a id="notify-set-inactive"></a>
    <li>inactive<br>
        Inactivates the current device. Note the slight difference to the
        disable attribute: using set inactive the state is automatically saved
        to the statefile on shutdown, there is no explicit save necesary.<br>
        This command is intended to be used by scripts to temporarily
        deactivate the notify.<br>
        The concurrent setting of the disable attribute is not recommended.</li>
    <a id="notify-set-active"></a>
    <li>active<br>
        Activates the current device (see inactive).</li>
    </ul>
    <br>


  <a id="notify-get"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a id="notify-attr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#disable">disable</a></li>
    <li><a href="#disabledForIntervals">disabledForIntervals</a></li>

    <a id="notify-attr-disabledAfterTrigger"></a>
    <li>disabledAfterTrigger someSeconds<br>
      disable the execution for someSeconds after it triggered.
    </li>

    <a id="notify-attr-addStateEvent"></a>
    <li>addStateEvent<br>
      The event associated with the state Reading is special, as the "state: "
      string is stripped, i.e $EVENT is not "state: on" but just "on". In some
      circumstances it is desireable to get the event without "state: "
      stripped. In such a case the addStateEvent attribute should be set to 1
      (default is 0, i.e. strip the "state: " string).<br>

      Note 1: you have to set this attribute for the event "receiver", i.e.
      notify, FileLog, etc.<br>

      Note 2: this attribute will only work for events generated by devices
      supporting the <a href="#readingFnAttributes">readingFnAttributes</a>.
      </li>

    <a id="notify-attr-forwardReturnValue"></a>
    <li>forwardReturnValue<br>
        Forward the return value of the executed command to the caller,
        default is disabled (0).  If enabled (1), then e.g. a set command which
        triggers this notify will also return this value. This can cause e.g
        FHEMWEB to display this value, when clicking "on" or "off", which is
        often not intended.</li>

    <a id="notify-attr-ignoreRegexp"></a>
    <li>ignoreRegexp regexp<br>
        It is hard to create a regexp which is _not_ matching something, this
        attribute helps in this case, as the event is ignored if it matches the
        argument. The syntax is the same as for the original regexp.
        </li>

    <li><a href="#perlSyntaxCheck">perlSyntaxCheck</a></li>

    <a id="notify-attr-readLog"></a>
    <li>readLog<br>
        Execute the notify for messages appearing in the FHEM Log. The device
        in this case is set to the notify itself, e.g. checking for the
        startup message looks like:
        <ul><code>
          define n notify n:.*Server.started.* { Log 1, "Really" }<br>
          attr n readLog
        </code></ul>
        </li>


  </ul>
  <br>

</ul>

=end html

=begin html_DE

<a id="notify"></a>
<h3>notify</h3>
<ul>
  <br>

  <a id="notify-define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; notify &lt;Suchmuster&gt; &lt;Anweisung&gt;</code>
    <br><br>
    F&uuml;hrt eine oder mehrere Anweisungen aus, wenn ein Event generiert
    wurde, was dem &lt;Suchmuster&gt; (Ger&auml;tename oder
    Ger&auml;tename:Event) entspricht.

    Die Anweisung ist einer der FHEM <a href="#command">Befehlstypen</a>.
    Zum Test dient das <a href="#trigger">trigger</a>-Kommando.
    <br><br>

    Beispiele:
    <ul>
      <code>define b3lampV1 notify btn3 set lamp $EVENT</code><br>
      <code>define b3lampV2 notify btn3 { fhem "set lamp $EVENT" }</code><br>
      <code>define b3lampV3 notify btn3 "/usr/local/bin/setlamp
      "$EVENT""</code><br>

      <code>define b3lampV3 notify btn3 set lamp1 $EVENT;;set lamp2
      $EVENT</code><br>

      <code>define wzMessLg notify wz:measured.* "/usr/local/bin/logfht $NAME
      "$EVENT""</code><br>

      <code>define LogUndef notify global:UNDEFINED.* "send-me-mail.sh
      "$EVENT""</code><br>

    </ul>
    <br>

    Hinweise:
    <ul>
      <li><code>&lt;Suchmuster&gt;</code> ist entweder der Name des
      ausl&ouml;senden ("triggernden") Ger&auml;tes oder die Kombination aus
      Ger&auml;t und ausl&ouml;sendem Ereignis (Event)
      <code>Ger&auml;tename:Event</code>.</li>

      <li>Das <code>&lt;Suchmuster&gt;</code> muss exakt (!)
        entweder dem Ger&auml;tenamen entsprechen oder der Zusammenf&uuml;gung
        aus Ger&auml;tename:Event.   Events lassen sich mit "inform" in Telnet
        oder durch Beobachtung des "Event-Monitors" in FHEMWEB ermitteln.</li>

      <li>In der Anweisung von Notify kann das ausl&ouml;sende Ereignis (Event)
        genutzt werden:

        <ul>
          <li>Die Anweisung $EVENT wird das komplette Ereignis (Event)
            beinhalten, z.B.  <code>measured-temp: 21.7 (Celsius)</code></li>

          <li>$EVTPART0,$EVTPART1,$EVTPART2,etc enthalten die durch Leerzeichen
            getrennten Teile des Events der Reihe nach (im Beispiel also
            <code>$EVTPART0="measured-temp:", $EVTPART1="21.7",
            $EVTPART2="(Celsius)"</code>.<br> Diese Daten sind verf&uuml;gbar
            als lokale Variablen in Perl, als Umgebungs-Variablen f&uuml;r
            Shell-Scripts, und werden als Text ausgetauscht in
            FHEM-Kommandos.</li>

          <li>$NAME und $TYPE enthalten den Namen bzw. Typ des Ereignis
            ausl&ouml;senden Ger&auml;tes, z.B. myFht und FHT</li>
       </ul></li>

      <li>Achtung: Folgende Vorgehensweise ist abgek&uuml;ndigt, funktioniert
          bis featurelevel 5.6 und wird in einem zuk&uuml;nftigen Release von
          FHEM nicht mehr unterst&uuml;tzt.  Wenn keine der oben genannten
          Variablen ($NAME/$EVENT/usw.) in der Anweisung gefunden wird, werden
          Platzhalter ersetzt.

        <ul>
          <li>Das Zeichen % wird ersetzt mit dem empfangenen
          Ereignis (Event), z.B. mit on oder off oder
          <code>measured-temp: 21.7 (Celsius)</code>.
          </li>

          <li>Das Zeichen @ wird ersetzt durch den
          Ger&auml;tenamen.</li>

          <li>Um % oder @ im Text selbst benutzen zu k&ouml;nnen, m&uuml;ssen
          sie verdoppelt werden (%% oder @@).</li>

          <li>Anstelle von % und @, k&ouml;nnen die
          Parameter %EVENT (funktionsgleich mit %),
          %NAME (funktionsgleich mit @) und
          %TYPE (enth&auml;lt den Typ des Ger&auml;tes, z.B.
          FHT) benutzt werden. Die von Leerzeichen unterbrochenen
          Teile eines Ereignisses (Event) sind verf&uuml;gbar als %EVTPART0,
          %EVTPART1, usw.  Ein einzeln stehendes % verliert seine
          oben beschriebene Bedeutung, falls auch nur einer dieser Parameter
          in der Definition auftaucht.</li>

        </ul></li>

      <li>Folgende spezielle Ereignisse werden f&uuml;r das Ger&auml;t "global"
      erzeugt:
      <ul>
          <li>INITIALIZED sobald die Initialization vollst&auml;ndig ist.</li>
          <li>REREADCFG nachdem die Konfiguration erneut eingelesen wurde.</li>
          <li>SAVE bevor die Konfiguration gespeichert wird.</li>
          <li>SHUTDOWN bevor FHEM heruntergefahren wird.</li>
          <li>DEFINED &lt;devname&gt; nach dem Definieren eines
          Ger&auml;tes.</li>
          <li>DELETED &lt;devname&gt; nach dem L&ouml;schen eines
          Ger&auml;tes.</li>
          <li>RENAMED &lt;old&gt; &lt;new&gt; nach dem Umbenennen eines
          Ger&auml;tes.</li>
          <li>UNDEFINED &lt;defspec&gt; beim Auftreten einer Nachricht f&uuml;r
          ein undefiniertes Ger&auml;t.</li>
      </ul></li>

      <li>Notify kann dazu benutzt werden, um Makros f&uuml;r eine manuelle
        Ausf&uuml;hrung zu speichern. Mit einem <a
        href="#trigger">trigger</a> Kommando k&ouml;nnen solche Makros dann
        ausgef&uuml;hrt werden.  Z.B.<br> <code>fhem> define MyMacro notify
        MyMacro { Log 1, "Hello"}</code><br> <code>fhem> trigger
        MyMacro</code><br> </li>

    </ul>
  </ul>
  <br>


  <a id="notify-set"></a>
  <b>Set </b>
  <ul>
    <a id="notify-set-addRegexpPart"></a>
    <li>addRegexpPart &lt;device&gt; &lt;regexp&gt;<br>
        F&uuml;gt ein regexp Teil hinzu, der als device:regexp aufgebaut ist.
        Die Teile werden nach Regexp-Regeln mit | getrennt.  Achtung: durch
        hinzuf&uuml;gen k&ouml;nnen manuell erzeugte Regexps ung&uuml;ltig
        werden.</li>
    <a id="notify-set-removeRegexpPart"></a>
    <li>removeRegexpPart &lt;re&gt;<br>
        Entfernt ein regexp Teil.  Die Inkonsistenz von addRegexpPart /
        removeRegexPart-Argumenten hat seinen Ursprung in der Wiederverwendung
        von Javascript-Funktionen.</li>
    <a id="notify-set-inactive"></a>
    <li>inactive<br>
        Deaktiviert das entsprechende Ger&auml;t. Beachte den leichten
        semantischen Unterschied zum disable Attribut: "set inactive"
        wird bei einem shutdown automatisch in fhem.state gespeichert, es ist
        kein save notwendig.<br>
        Der Einsatzzweck sind Skripte, um das notify tempor&auml;r zu
        deaktivieren.<br>
        Das gleichzeitige Verwenden des disable Attributes wird nicht empfohlen.
        </li>
    <a id="notify-set-active"></a>
    <li>active<br>
        Aktiviert das entsprechende Ger&auml;t, siehe inactive.
        </li>
    </ul>
    <br>

  <a id="notify-get"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a id="notify-attr"></a>
  <b>Attribute</b>
  <ul>
    <li><a href="#disable">disable</a></li>
    <li><a href="#disabledForIntervals">disabledForIntervals</a></li>

    <a id="notify-attr-disabledAfterTrigger"></a>
    <li>disabledAfterTrigger &lt;sekunden&gt;<br>
      deaktiviert die Ausf&uuml;hrung f&uuml;r &lt;sekunden&gt; nach dem
      das notify ausgel&ouml;st wurde.
    </li>

    <a id="notify-attr-addStateEvent"></a>
    <li>addStateEvent<br>
      Das mit dem state Reading verkn&uuml;pfte Event ist speziell, da das
      dazugeh&ouml;rige Prefix "state: " entfernt wird, d.h. $EVENT ist nicht
      "state: on", sondern nur "on". In manchen F&auml;llen ist es aber
      erw&uuml;nscht das unmodifizierte Event zu bekommen, d.h. wo "state: "
      nicht entfernt ist. F&uuml;r diese F&auml;lle sollte addStateEvent auf 1
      gesetzt werden, die Voreinstellung ist 0 (deaktiviert).<br>

      Achtung:
      <ul>
        <li>dieses Attribut muss beim Empf&auml;nger (notify, FileLog, etc)
        gesetzt werden.</li>

        <li>dieses Attribut zeigt nur f&uuml;r solche Ger&auml;te-Events eine
        Wirkung, die <a href="#readingFnAttributes">readingFnAttributes</a>
        unterst&uuml;tzen.</li>
      </ul>
      </li>

    <a id="notify-attr-forwardReturnValue"></a>
    <li>forwardReturnValue<br>
        R&uuml;ckgabe der Werte eines ausgef&uuml;hrten Kommandos an den
        Aufrufer.  Die Voreinstellung ist 0 (ausgeschaltet), um weniger
        Meldungen im Log zu haben.
        </li>

    <a id="notify-attr-ignoreRegexp"></a>
    <li>ignoreRegexp regexp<br>
        Es ist nicht immer einfach ein Regexp zu bauen, was etwas _nicht_
        matcht. Dieses Attribut hilft in diesen F&auml;llen: das Event wird
        ignoriert, falls es den angegebenen Regexp matcht. Syntax ist gleich
        wie in der Definition.
        </li>

    <li><a href="#perlSyntaxCheck">perlSyntaxCheck</a></li>

    <a id="notify-attr-readLog"></a>
    <li>readLog<br>
        Das notify wird f&uuml;r Meldungen, die im FHEM-Log erscheinen,
        ausgegef&uuml;hrt. Das "Event-Generierende-Ger&auml;t" wird auf dem
        notify selbst gesetzt. Z.Bsp. kann man mit folgendem notify auf die
        Startup Meldung reagieren:
        <ul><code>
          define n notify n:.*Server.started.* { Log 1, "Wirklich" }<br>
          attr n readLog
        </code></ul>
        </li>

  </ul>
  <br>

</ul>

=end html_DE

=cut
