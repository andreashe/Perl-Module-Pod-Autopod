package Pod::Autopod; ## Generates pod documentation by analysing perl modules.

use 5.006; #Pod::Abstract uses features of 5.6
use FileHandle;
use strict;
use Pod::Abstract;
use Pod::Abstract::BuildNode qw(node nodes);

our $VERSION = '1.09';

# This Module is designed to generate pod documentation of a perl class by analysing its code.
# The idea is to have something similar like javadoc. So it uses also comments written directly
# obove the method definitions. It is designed to asumes a pm file which represents a class.
# 
# Of course it can not understand every kind of syntax, parameters, etc. But the plan is to improve
# this library in the future to understand more and more automatically.
#
# Please note, there is also an "autopod" command line util in this package.
#
#
# SYNOPSIS
# ========
#
#  use Pod::Autopod;
#
#  new Pod::Autopod(readfile=>'Foo.pm', writefile=>'Foo2.pm');
# 
#  # reading Foo.pm and writing Foo2.pm but with pod
#
#
#  my $ap = new Pod::Autopod(readfile=>'Foo.pm');
#  print $ap->getPod();
#
#  # reading and Foo.pm and prints the generated pod. 
#
#  my $ap = new Pod::Autopod();
#  $ap->setPerlCode($mycode);
#  print $ap->getPod();
#  $ap->writeFile('out.pod');
#
#  # asumes perl code in $mycoce and prints out the pod.
#  # also writes to the file out.pod
#
#
# HOWTO
# =====
# 
# To add a documentation about a method, write it with a classical remark char "#" 
# before the sub{} definition:
#
#  # This method is doing foo.
#  #
#  #  print $this->foo();
#  #
#  # 
#  # It is not doing bar, only foo.
#  sub foo{
#	   ...
#  }
#
# A gap before sub{} is allowed.
#
# In further versions of autopod, here new features will appear.
#
# To define parameters and return values you can use a boundle of keywords.
# So far parameters and return values can not realy be autodetected, so manual
# way is necessary, but it is designed to type it rapidly.
#
#  sub foo{ # void ($text)
#	  ...
#  }
#
# The example above produces the following method description: 
#
#  $this->foo($text);
#
# The object "$this" is the default and automatially used when a constructor was found ("new")
# or the class inherits with ISA or "use base".
# You can change this by the parameter "selfstring" in the autopod constructor.
#
# The example looks simple, but the engine does more than you think. Please have a look here:
#
#  sub foo{ # void (scalar text)
#	  ...
#  }
#  
# That procudes the same output! It means the dollar sign of the first example is a symbol which means "scalar".
#
#  sub foo{ # ($)
#	  ...
#  }
#
# Produces:
#
#  $this->foo($scalar);
#
# As you see, that was the quickest way to write the definition. The keywork "void" is default.
#
# The following keywords or characters are allowed:
#
#	 array       @
#	 arrayref   \@
#	 hash        %
#	 hashref    \%
#	 method      &
#	 scalar      $
#	 scalarref  \$
#  void       only as return value
#
# Now a more complex example:
#
#  sub foo{# $state ($firstname,$lastname,\%persondata)
#  ...
#  }
#
# produces:
#
#  my $state = $this->foo($firstname, $lastname, \%persondata);
#
# or write it in java style:
#
#  sub foo{# scalar state (scalar firstname,scalar lastname,hashref persondata)
#  ...
#  }
#
# Multiple return values may be displayed as following:
# 
#  sub foo{# $a,$b ($text)
#  ...
#  }
#
# produces:
#
#  my ($a, $b) = $this->foo($text);
#
#
# If you want to use key values pairs as in a hash, you may describe it like:
#
#  sub foo{# void (firstname=>$scalar,lastname=>scalar)
#  ...
#  }
#
# The second "scalar" above is without a "$", that is no mistake, both works.
# 
# There is also a way to expain that a value A OR B is expected. See here:
#
#  sub foo{# $lista|\$refb (\@list|$text,$flag)
#  ...
#  }
#
# procudes:
#
#   my $lista | \$refb = $this->foo(\@list | $text, $flag);
#
# Of course, that is not an official perl syntax with the or "|", but it shows
# you that is expected.
#
#
# In the First Part obove all method descriptions, you can add general informations, which are
# per default displayed under the head item "DESCRIPTION". But also own items can be used by
# underlining a text with "=" chars like:
#
#  # HOWTO
#  # =====
#  # Read here howto do it.   
#
# Some of these title keywords are allways places in a special order, which you can not change. For
# example LICENSE is allways near the end.
#
#
# LICENSE
# =======
# You can redistribute it and/or modify it under the conditions of LGPL.
# 
# AUTHOR
# ======
# Andreas Hernitscheck  ahernit(AT)cpan.org 


# Constructor
#
# The keyvalues are not mandatory.
#
# selfstring may hold something like '$self' as alternative to '$this', which is default.
#
# alsohiddenmethods gets a boolean flag to show also methods which starts with "_".
#
sub new{ # $object ($filename=>scalar,alsohiddenmethods=>scalar,selfstring=>scalar) 
my $pkg=shift;
my %v=@_; 


	my $this={};
	bless $this,$pkg;

	$this->{package}=$pkg;

	foreach my $k (keys %v){ ## sets values to object
		$this->{$k}=$v{$k};
	}  
	
	$this->{'selfstring'} = $this->{'selfstring'} || '$this';
	

	if ($this->{'readfile'}){
		$this->readFile($this->{'readfile'});
	}


	if ($this->{'writefile'}){
		$this->writeFile($this->{'writefile'});
	}


	if ($this->{'readdir'}){
		$this->readDirectory($this->{'readdir'});
	}	

return $this;
}  


## Returns the border string which delimit the perl code and pod inside a pm file.
sub getBorderString{ ## $scalar
my $this=shift;
my $pkg=$this->{'package'};

	if ($this->{'BORDER'} eq ''){
		
		my $border = '#' x 20;
		$border .= " pod generated by $pkg - keep this line to make pod updates possible ";
		$border .= '#' x 20;
		$this->{'BORDER'}=$border;
		
	}

return $this->{'BORDER'};	
}


## Set an alternative border string. 
## If you change this, you have to do it again when updating the pod.
sub setBorderString{ ## void ($borderstring)
my $this=shift;
my $s=shift;

	$this->{'BORDER'} =$s;

}



# Expects Perl code as arrayref
# or text (scalar).
# 
# When used, it automatically runs scanArray(). 
sub setPerlCode{ ## void ($text|\@array)
my $this=shift;
my $code=shift;

	my $arr; 

	if (!ref $code){
		my @a = split(/\n/,$code);
		$arr = \@a; 
	}else{
		$arr=$code;
	}

	$this->{'PERL_CODE'}=$arr;

	$this->scanArray($arr);	
	$this->buildPod();
}


# Returns perl code which was set before.
sub getPerlCode{# $text
my $this=shift;
	
	my $border = $this->getBorderString();
	
	my $arr = $this->{'PERL_CODE'};
	
	my @code;
	foreach my $row (@$arr){
		
		if ($row=~ m/$border/){last}; ## border found, end loop
		
		push @code,$row;
	}
		
	my $text=join("",@code);	
		
return $text;		
}



# Returns the pod formated text.s
sub getPod{ ## $text
my $this=shift;

return $this->{"POD_TEXT"};	
}



sub _getFileArray{
my $this=shift;
my $filename=shift;
my @f;

	my $fh=new FileHandle;
	open($fh,$filename);
		#lockhsh($fh);
		@f=<$fh>;
		#unlockh($fh);
	close($fh);


return wantarray ? @f : \@f;
}


sub _getFileScalar{
my $this=shift;
my $filename=shift;
	
	my $a = $this->_getFileArray($filename);

return join("",@$a);	
}



# writes a pod file
#
# If the file has a pm extension, it writes the perl code and the pod
# If the file has a pod extension or any, it only writes the pod.
sub writeFile{ # void ($filename)
my $this=shift;
my $file=shift;
my $pod=$this->getPod();

	if ($file=~ m/\.pm$/i){ ## target is pm file, so add perl-code 
		my $text=$this->getPerlCode();
		$text.="\n".$this->{'BORDER'}."\n\n$pod";
		$this->_putFile($file,$text);
	}else{## target is any or pod file, write only pod
		$this->_putFile($file,$pod);
	}
	
}


## Reading a Perl class file and loads it to memory.
sub readFile{ # void ($filename)
my $this=shift;
my $file=shift or die "need filename";


	my $arr = $this->_getFileArray($file);
	$this->setPerlCode($arr);
	
	
}


## scans a directoy recoursively for pm files and may
## generate pod of them.
##
## You can also set the flag updateonly to build new pod
## only for files you already build a pod (inside the file)
## in the past. Alternatively you can write the magic word
## AUTOPODME somewhere in the pm file what signals that this
## pm file wants to be pod'ed by autopod.
##
## The flag pod let will build a separate file. If poddir set,
## the generated pod file will be saved to a deparate directory.
## With verbose it prints the list of written files.
##
sub readDirectory{ # void ($directory,updateonly=>scalar,pod=>scalar,verbose=>scalar)
my $this=shift;
my $directory=shift or die "need directory";
my $v={@_};
my $updateonly=$v->{'updateonly'};
my $verbose=$v->{'verbose'};
my $pod=$v->{'pod'};
my $poddir=$v->{'poddir'};
my $border=$this->getBorderString();


	my @dir = $this->_getPodFilesRecoursive($directory);


	foreach my $filein (@dir){
		
		my $fileout = $filein;

    if ($poddir){
      $pod=1;
      $fileout=~ s|^$directory|$poddir|;

      my $p=_extractPath($fileout);


      if (!-e $p){
        _makeDirRecursive($p);
      }
    }

		
		my $filecontent = $this->_getFileScalar($filein);
		if ($updateonly){
			if (($filecontent!~ m/$border/) &&  ($filecontent!~ m/AUTOPODME/) ){$fileout=undef}; ## no border, no update
		}
		
		if ($pod){
			$fileout=~ s/\.pm$/.pod/;
		}
		
		my $ap = new Pod::Autopod();
		$ap->readFile($filein);
		$ap->writeFile($fileout);
	
		print $fileout."\n" if $verbose && $fileout;
		
	}

}





sub _getPodFilesRecoursive{
my $this=shift;
my $path=shift;
my %para=@_;
my @files;

	@files=$this->_getFilesRecoursiveAll($path);
	$this->_filterFileArray(\@files,ext=>'pm',path=>$path);
	@files=sort @files;

return wantarray ? @files : \@files;
}


sub _getFilesRecoursiveAll{
my $this=shift;
my $path=shift;
my %para;
my @f;
my @fm;


	@f=$this->_getDirArray($path);

	$this->_filterFileArray(\@f);
	$this->_addPathToArray($path,\@f);

	foreach my $d (@f){
		if (-d $d){
		push @fm,$this->_getFilesRecoursiveAll($d);
		}
	}
	push @f,@fm;

	
	
return @f;
}  



sub _getDirArray{
my $this=shift;
my $path=shift;
my @f;
my @nf;

	opendir(FDIR,$path);
		@f=readdir FDIR;
	closedir(FDIR);

	foreach my $d (@f){
		if ($d!~ m/^\.\.?/){push @nf,$d};
	}

return wantarray ? @nf : \@nf;
}



sub _addPathToArray{
my $this=shift;
my $path=shift;
my $dir_ref=shift;

		foreach my $z (@$dir_ref){
			$z=$path.'/'.$z;
		}
}
  



sub _filterFileArray{
my $this=shift;
my $dir_ref=shift;
my %para=@_;
my @nf;
my $path=$para{path};


	if ($para{onlyFiles} ne ''){$para{noDir}=1};
	
	
	foreach my $i (@$dir_ref){
		my $ok=1;
		if ($i=~ m/^\.\.?$/){$ok=0};
				
		if (-d $i){$ok=0};

		my $ext=lc($para{ext});
		if (exists $para{ext}){
			if ($i=~ m/\.$ext$/i){$ok=1}else{$ok=0};
		};

		if ($ok == 1){push @nf,$i};
	}
	@$dir_ref=@nf;
	undef @nf;

}
  
  
  



	

sub _putFile{
my $this=shift;
my $file=shift;
my $text=shift;

	my $fh=new FileHandle;
	open($fh,">$file");
#		lockh($fh);
		print $fh $text;
#		unlockh($fh);
	close($fh);
}  


# This class may scan the perl code.
# But it is called automatically when importing a perl code.
sub scanArray{
my $this=shift;	
my $arr=shift or die "Arrayref expected";	
	
	$this->{'STATE'} = 'head';
	
	
	## reverse read
	for (my $i=0;$i < scalar(@$arr); $i++){
		my $p=scalar(@$arr)-1-$i;
		
		my $line = $arr->[$p];

		if ((($line=~ m/^\s*\#/) || ($p == 0)) && ($this->{'STATE'} eq 'headwait')){ ## last line of body
			$this->{'STATE'} = 'head';
		}elsif((($line=~ m/^\s*$/) || ($p == 0)) && ($this->{'STATE'} eq 'head')){ ## last line of body
			$this->{'STATE'} = 'bodywait';
		}
		
		if (($this->{'STATE'} eq 'headwait') && ($line!~ m/^\s*$/) && ($line!~ m/^\s*\#/)){
			$this->{'STATE'}='free';
		}


		if ((($line=~ m/^\s*\}/) || ($p == 0) || ($line=~ m/^\s*sub [^ ]+/)) && ($this->{'STATE'}=~ m/^(head|headwait|bodywait|free)$/)){ ## last line of body
			$this->_clearBodyBuffer();
			$this->{'STATE'} = 'body';
			$this->_addHeadBufferToAttr();
		}


		if ($line=~ m/^\s*sub [^ ]+/){ ## head line
			$this->_clearHeadBuffer();
			$this->_setMethodLine($line);
			$this->{'STATE'} = 'headwait';
			$this->_addBodyBufferToAttr();
			$this->_setMethodAttr($this->_getMethodName(),'returnline',$this->_getMethodReturn());
			$this->_setMethodReturn(undef);	
		}

		if ($this->{'STATE'} eq 'head'){
			$this->_addLineToHeadBuffer($line);
		}elsif($this->{'STATE'} eq 'body'){
			$this->_addLineToBodyBuffer($line);	
		}
		
		
		if ($line=~ m/^\s*package ([^\;]+)\;(.*)/){
			$this->{'PKGNAME'}=$1;
			$this->{'PKGNAME_DESC'}=$2;
			$this->{'PKGNAME_DESC'}=~ s/^\s*\#*//g;
		}

		if ($line=~ m/^\s*use +([^\; ]+)[\; ](.*)/){
			$this->{'REQUIRES'} = $this->{'REQUIRES'} || [];
			my $name=$1;
			my $rem=$2;
			$rem=~ s/^[^\#]*\#*//;
			push @{$this->{'REQUIRES'}},{'name'=>$name,'desc'=>$rem};
		}


		if (($line=~ m/^\s*use base +([^\; ]+)[\;](.*)/) ||
			($line=~ m/^\s*our +\@ISA +([^\; ]+)[\;](.*)/)){
			$this->{'INHERITS_FROM'} = $this->{'INHERITS_FROM'} || [];
			my $name=$1;
			my $rem=$2;
			$name=~ s/qw\(//g;
			$name=~ s/[\)\']//g;
			my @n=split(/ +/,$name);
			foreach my $n (@n){
				push @{$this->{'INHERITS_FROM'}},{'name'=>$n} if $n;	
			}
		}
		
		#print $line.'   -   '.$this->{'STATE'};
	}
	
	
	if ((exists $this->{'METHOD_ATTR'}->{'new'}) || (scalar($this->{'INHERITS_FROM'}) >= 1 )){ ## its a class!
		$this->{'ISCLASS'}=1;
	}
	
	
#	print Dumper($this->{'METHOD_ATTR'});
	$this->_analyseAttributes();


	$this->_scanDescription($arr);


	#print Dumper($this->{'METHOD_ATTR'});

	
}




sub _scanDescription{
my $this=shift;	
my $arr=shift or die "Arrayref expected";	
	
	$this->{'STATE'} = 'head';
	
	my @text;
	
	my $state='wait';
	for (my $i=0;$i < scalar(@$arr); $i++){
		
		my $line = $arr->[$i];
		
		if (($line=~ m/^\s*\#+(.*)/) && ($state=~ m/^(wait|rem)$/)){	
			$state='rem';
			$line=~ m/^\s*\#+(.*)/;
			my $text=$1;
			push @text,$text;
		}elsif(($line!~ m/^\s*\#+(.*)/) && ($state=~ m/^(rem)$/)){
			$state='done';
		}
		
	}
	
	
	my $more = $this->_findOwnTitlesInArray(array=>\@text, default=>'DESCRIPTION');
	
	$this->{'MORE'} = $more;

}





sub _findOwnTitlesInArray{
my $this=shift;	
my $v={@_};
my $arr=$v->{'array'}  or die "Array expected";
my $default=$v->{'default'};
my $morearr={};

	$this->_prepareArrayText(array=>$arr);

	my $area = $default;

	my $nextok=0;
	for (my $i=0;$i < scalar(@$arr); $i++){

		my $line = $arr->[$i];
		my $next = $arr->[$i+1];
		
		## is introduction?
		if ($next=~ m/^\s*(\={3,50})/){ ## find a ==== bar
			my $l=length($1);
			$area=$this->_trim($line);
			$nextok=$i+2; ## skip next 2 rows
		}
		
		if ($i >= $nextok){
			$morearr->{$area} = $morearr->{$area} || [];
			push @{$morearr->{$area}},$line;
		}

	}
	
	
return $morearr;
}






sub _addLineToHeadBuffer{
my $this=shift;
my $line=shift;

	$line = $this->_trim($line);

	$this->{'HEAD'} = $this->{'HEAD'} || [];
	
	unshift @{$this->{'HEAD'}},$line;
		

}




sub _addLineToBodyBuffer{
my $this=shift;
my $line=shift;

	$line = $this->_trim($line);

	if ($line=~ m/^\s*return (.*)/){
		if (!$this->_getMethodReturn){
			$this->_setMethodReturn($line);	
		}
	}


	$this->{'BODY'} = $this->{'BODY'} || [];
	
	unshift @{$this->{'BODY'}},$line;
		

}



sub _clearBodyBuffer{
my $this=shift;
my $line=shift;

	$line = $this->_trim($line);

	$this->{'BODY'} = [];

}




sub _clearHeadBuffer{
my $this=shift;
my $line=shift;

	$line = $this->_trim($line);

	$this->{'HEAD'} = [];

}


sub _addHeadBufferToAttr{
my $this=shift;

	my $m = $this->_getMethodName();
	if ($m){
		$this->_setMethodAttr($m,'head',$this->{'HEAD'})
	}
}



sub _addBodyBufferToAttr{
my $this=shift;

	my $m = $this->_getMethodName();
	$this->_setMethodAttr($m,'body',$this->{'BODY'})
}




sub _setMethodLine{
my $this=shift;
my $s=shift;

	$s = $this->_trim($s);
	
	if ($s=~ m/sub ([^ \{]+)(.*)/){
		$this->_setMethodName($1);
		$this->_setMethodAttr($1,'methodlinerest',$2);
	}


$this->{'METHOD_LINE'}=$s;
}



sub _getMethodLine{
my $this=shift;

return $this->{'METHOD_LINE'};
}



sub _setMethodName{
my $this=shift;
my $s=shift;


$this->{'METHOD_NAME'}=$s;
}





sub _getMethodReturn{
my $this=shift;

return $this->{'METHOD_RETURN'};
}



sub _setMethodReturn{
my $this=shift;
my $s=shift;


$this->{'METHOD_RETURN'}=$s;
}





sub _getMethodName{
my $this=shift;


return $this->{'METHOD_NAME'};
}




sub _setMethodAttr{
my $this=shift;
my $name=shift;
my $k=shift;
my $s=shift;

$this->{'METHOD_ATTR'}->{$name}->{$k}=$s;
}





sub _trim{
my $this=shift;
my $s=shift;

	if (ref $s){

		$$s=~ s/^\s*//;
		$$s=~ s/\s*$//;
		
	}else{

	 	$s=~ s/^\s*//;
 		$s=~ s/\s*$//;

		return $s;
	}
	 
}  





sub _analyseAttributes{
my $this=shift;
my $attr = $this->{'METHOD_ATTR'};


	foreach my $method (keys %$attr){
		my $mat=$attr->{$method};
		
		$this->_analyseAttributes_Method(attributes=>$mat,method=>$method);
		$this->_analyseAttributes_Head(attributes=>$mat,method=>$method);
	}
	
	
}





sub _analyseAttributes_Method{
my $this=shift;
my $v={@_};
my $method=$v->{'method'};
my $mat=$v->{'attributes'};


	my $mrest = $mat->{'methodlinerest'};
	$mrest=~ s/^[^\#]+\#*//;
	$mat->{'methodlinecomment'}=$mrest;

	my ($re,$at) = split(/\(/,$mrest,2);
	$at=~ s/\)//;


	$mat->{'returntypes'} = $this->_getTypeTreeByLine($re);
	$mat->{'attributetypes'} = $this->_getTypeTreeByLine($at);

	
}








sub _analyseAttributes_Head{
my $this=shift;
my $v={@_};
my $method=$v->{'method'};
my $mat=$v->{'attributes'};


	$this->_prepareArrayText(array=>$mat->{'head'});

}




sub _prepareArrayText{
my $this=shift;
my $v={@_};
my $array=$v->{'array'};

	#print Dumper($array);
	## removes rem and gap before rows

	my $space=99;
	foreach my $h (@{$array}){
		
		$h=~ s/^\#+//; ## remove remarks
		
		if ($h!~ m/^(\s*)$/){
			$h=~ m/^( +)[^\s]/;
			my $l=length($1);
			if (($l >0) && ($l < $space)){
				$space=$l
			}
		}
	}


	if ($space != 99){
		foreach my $h (@{$array}){
			$h=~ s/^\s{0,$space}//;
		}	
	}


}






sub _getTypeTreeByLine{
my $this=shift;
my $line=shift;

	
	my @re = split(/\,/,$line);
	
	my @rettype;
	foreach my $s (@re){
		$s=$this->_trim($s);


		my @or = split(/\|/,$s);
		my @orelems;
		my $elem={};
		
		foreach my $o (@or){
			my $name;
			my $type;
			my $typevalue;
			
			if ($o=~ m/^([^ ]+)\s*\=\>\s*([^ ]+)$/){
				$type='keyvalue';
				$name=$1;
				$typevalue=$2;
			
			}elsif ($o=~ m/^([^ ]+) ([^ ]+)$/){
				$type=lc($1);
				$name=$2;
			}elsif ($o=~ m/^([^ \$\%\@]+)$/){
				$type=lc($1);
			}elsif ($o=~ m/^([\$\%\@\\]+)(.*)$/){
				my $typec=$1;
				my $namec=$2;
				
				if ($typec eq '$'){$type='scalar'}
				if ($typec eq '\$'){$type='scalarref'}
				if ($typec eq '%'){$type='hash'}
				if ($typec eq '\%'){$type='hashref'}
				if ($typec eq '@'){$type='array'}
				if ($typec eq '\@'){$type='arrayref'}
				if ($typec eq '&'){$type='method'}
				if ($typec eq '\&'){$type='method'}

				$name=$namec || $type;
			}
			
			$elem = {name=>$name,type=>$type,typevalue=>$typevalue};
			push @orelems, $elem;
		}

		

		push @rettype,\@orelems;
	} 
	
	
return  \@rettype;
}





# Builds the pod. Called automatically when imporing a perl code.
sub buildPod{
my $this=shift;
my $attr = $this->{'METHOD_ATTR'};

	$this->{'POD_PARTS'}={};

	$this->_buildPod_Name();
	$this->_buildPod_Methods();
	$this->_buildPod_Requires();
	$this->_buildPod_Inherits();
	$this->_buildPod_More();


	$this->_buildPodText();

}





sub _buildPod_Requires{
my $this=shift;

	my $re=$this->{'REQUIRES'} || [];


	my %dontshow;
	my @dontshow = qw(vars strict warnings libs base);
	map {$dontshow{$_}=1} @dontshow;

	my $node = node->root;

	$node->push( node->head1("REQUIRES") );
	
	if (scalar(@$re) > 0){


		foreach my $e (@$re){

			my $name=$e->{'name'};
			my $desc=$e->{'desc'};

			if (!$dontshow{$name}){

				$desc=$this->_trim($desc);
				my $text = "L<$name> $desc\n\n";

				$node->push( node->text($text));
			}		
		}
		
		$this->{'POD_PARTS'}->{'REQUIRES'} = $node;	
	}

}





sub _buildPod_Inherits{
my $this=shift;

	my $re=$this->{'INHERITS_FROM'} || [];

	my %dontshow;
	my @dontshow = qw(vars strict warnings libs base);
	map {$dontshow{$_}=1} @dontshow;

	my $node = node->root;

	$node->push( node->head1("IMPLEMENTS") );
	
	if (scalar(@$re) > 0){


		foreach my $e (@$re){

			my $name=$e->{'name'};
			my $desc=$e->{'desc'};

			if (!$dontshow{$name}){

				$desc=$this->_trim($desc);
				my $text = "L<$name> $desc\n\n";

				$node->push( node->text($text));
			}		
		}
		
		$this->{'POD_PARTS'}->{'IMPLEMENTS'} = $node;	
	}

}




sub _buildPodText{
my $this=shift;

	my $parts=$this->{'POD_PARTS'};

	my @text;

	my @first = qw(NAME SYNOPSIS DESCRIPTION REQUIRES IMPLEMENTS EXPORTS HOWTO NOTES METHODS);
	my @last  = ('CAVEATS','TODO','TODOS','SEE ALSO','AUTHOR','COPYRIGHT','LICENSE','COPYRIGHT AND LICENSE');

	my @own = keys %{$parts};
	my @free;
	push @own,@first;
	push @own,@last;
	
	my %def;
	map {$def{$_}=1} @first;
	map {$def{$_}=1} @last;
	
	foreach my $n (@own){
		if (!exists $def{$n}){push @free,$n};
	}

	my @all;
	push @all,@first,@free,@last;

	foreach my $area (@all){
		if (exists $parts->{$area}){
			push @text,$parts->{$area}->pod;
		}
	}
	
	

	
	my $node = node->root;
	$node->push( node->cut );
	push @text,$node->pod;
	
	my $text=join("\n",@text);

	$this->{"POD_TEXT"} = $text;
}





sub _buildPod_Name{
my $this=shift;
my $attr = $this->{'METHOD_ATTR'};
my $name = $this->{'PKGNAME'};

	my $node = node->root;

	$node->push( node->head1("NAME") );
	
	my @name;
	
	push @name,$this->{'PKGNAME'};
	push @name,$this->_trim($this->{'PKGNAME_DESC'}) if $this->{'PKGNAME_DESC'};
	
	my $namestr = join(" - ",@name)."\n\n";
	
	$node->push( node->text($namestr));



	$this->{'POD_PARTS'}->{'NAME'} = $node;

}







sub _buildPod_More{
my $this=shift;
my $attr = $this->{'METHOD_ATTR'};



	my $more = $this->{'MORE'};

	foreach my $area (keys %$more){

		my $node = node->root;
			
		my $desc=$more->{$area};
		
		if (length(@$desc) > 0){
	
			$node->push( node->head1("$area") );
			$node->push( node->text( join("\n",@$desc)."\n\n" ));
				
		}

		$this->{'POD_PARTS'}->{$area} = $node;
	}


}






sub _buildPod_Methods{
my $this=shift;
my $attr = $this->{'METHOD_ATTR'};

	my $node = node->root;

	$node->push( node->head1("METHODS") );

	## sort alphabeticaly
	my @methods = keys %$attr;
	@methods = sort @methods;

	if (exists $attr->{'new'}){ ## constructor first 
		$this->_buildPod_Methods_addMethod(node=>$node,method=>'new');
	}

	foreach my $method (@methods){

		my $ok = 1;

		if ($method=~ m/^\_/){
			$ok=0;
			if ($this->{'alsohiddenmethods'}){$ok=1};
		}

		if ($ok){
			if ($method ne 'new'){
				$this->_buildPod_Methods_addMethod(node=>$node,method=>$method);
			}
		}
		
	}

	
	$this->{'POD_PARTS'}->{'METHODS'} = $node;
}




sub _buildPod_Methods_addMethod{
my $this=shift;
my $v={@_};
my $node=$v->{'node'};
my $method=$v->{'method'};
my $attr = $this->{'METHOD_ATTR'};
my $mat=$attr->{$method};

	my $selfstring='';
	if ($this->{'ISCLASS'}){
		$selfstring=$this->{'selfstring'}.'->';	
	}
	

	## method name
	$node->push( node->head2("$method") );


	## how to call

	my $retstring = $this->_buildParamString(params=>$mat->{'returntypes'}, braces=>1,separatorand=>', ',separatoror=>' | ');
	my $paramstring = $this->_buildParamString(params=>$mat->{'attributetypes'}, braces=>0,separatorand=>', ',separatoror=>' | ');

	my $addit=0;
	if ($retstring){
		$retstring = " my $retstring = $selfstring$method($paramstring);";
		$addit=1;
	}elsif($paramstring){
		$retstring = " $selfstring$method($paramstring);";
		$addit=1;
	}else{
		$retstring = " $selfstring$method();";
		$addit=1;
	}


	if ($addit){
		$retstring.="\n\n";		
		$node->push( node->text($retstring) );		
	}


	### head text 

	my $text;
	if ($mat->{'head'}){
		$text = join("\n",@{ $mat->{'head'} }); ## I added the return here, which is necessary using example codes before methods
		if ($text){$text.="\n\n\n"};
	
		$node->push( node->text($text) );
	}
	


}



sub _buildParamString{
my $this=shift;
my $v={@_};
my $params=$v->{'params'};
my $braces=$v->{'braces'};
my $separatorand=$v->{'separatorand'} || ',';
my $separatoror=$v->{'separatoror'} || '|';
my $text='';


	if ((exists $params->[0]->[0]->{'type'}) && ($params->[0]->[0]->{'type'} eq 'void')){return};

	my @and;
	foreach my $arra (@$params){

		my @or;
		foreach my $e (@$arra){
	
			my $name = $e->{'name'};
			my $type = $e->{'type'};
	
			my $wname = $name || $type;
	
			if ($type ne 'keyvalue'){
				my $ctype=$this->_typeToChar($type);
				push @or,"$ctype$wname";
			}else{
				my $typev = $e->{'typevalue'};
				my $ctype=$this->_typeToChar($typev);
				push @or,"$name => $ctype$typev";
			}
			
		}
			
		push @and,join($separatoror,@or);
	}
	
	$text=join($separatorand,@and);

	if ((scalar(@$params) > 1) && ($braces)){
		$text="($text)";
	}

return $text;
}



sub _typeToChar{
my $this=shift;
my $type=shift;
my $c='';

	my $m = {	'array'			=>	'@',
						'arrayref'	=>	'\@',
						'hash'			=>	'%',
						'hashref'		=>	'\%',
						'method'		=>	'&',
						'scalar'		=>	'$',
						'scalarref'	=>	'\$',
	};

	$c=$m->{$type} || $c;

return $c;
}





sub _makeDirRecursive{
my $dir=shift;
my $path;

  if (!-e $dir){

    my @path=split(/\//,$dir);

    foreach my $p (@path){
      if (!-e $p){
        mkdir $path.$p
        #print $path.$p."\n";
      }
      $path.=$p.'/';
    }

  }
}



sub _extractPath{
my $p=shift;

  if ($p=~ m/\//){
    $p=~ s/(.*)\/(.*)$/$1/;
  }else{
    if ($p=~ m/^\.*$/){ # only ".."
      $p=$p; ## nothing to do
    }else{
      $p='';
    }
  }

return $p;
}





1;








#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 NAME

Pod::Autopod - Generates pod documentation by analysing perl modules.


=head1 SYNOPSIS


 use Pod::Autopod;

 new Pod::Autopod(readfile=>'Foo.pm', writefile=>'Foo2.pm');

 # reading Foo.pm and writing Foo2.pm but with pod


 my $ap = new Pod::Autopod(readfile=>'Foo.pm');
 print $ap->getPod();

 # reading and Foo.pm and prints the generated pod. 

 my $ap = new Pod::Autopod();
 $ap->setPerlCode($mycode);
 print $ap->getPod();
 $ap->writeFile('out.pod');

 # asumes perl code in $mycoce and prints out the pod.
 # also writes to the file out.pod




=head1 DESCRIPTION

This Module is designed to generate pod documentation of a perl class by analysing its code.
The idea is to have something similar like javadoc. So it uses also comments written directly
obove the method definitions. It is designed to asumes a pm file which represents a class.

Of course it can not understand every kind of syntax, parameters, etc. But the plan is to improve
this library in the future to understand more and more automatically.

Please note, there is also an "autopod" command line util in this package.




=head1 REQUIRES

L<Pod::Autopod> 

L<Pod::Abstract::BuildNode> 

L<Pod::Abstract> 

L<FileHandle> 


=head1 HOWTO


To add a documentation about a method, write it with a classical remark char "#" 
before the sub{} definition:

 # This method is doing foo.
 #
 #  print $this->foo();
 #
 # 
 # It is not doing bar, only foo.
 sub foo{
   ...
 }

A gap before sub{} is allowed.

In further versions of autopod, here new features will appear.

To define parameters and return values you can use a boundle of keywords.
So far parameters and return values can not realy be autodetected, so manual
way is necessary, but it is designed to type it rapidly.

 sub foo{ # void ($text)
  ...
 }

The example above produces the following method description: 

 $this->foo($text);

The object "$this" is the default and automatially used when a constructor was found ("new")
or the class inherits with ISA or "use base".
You can change this by the parameter "selfstring" in the autopod constructor.

The example looks simple, but the engine does more than you think. Please have a look here:

 sub foo{ # void (scalar text)
  ...
 }
 
That procudes the same output! It means the dollar sign of the first example is a symbol which means "scalar".

 sub foo{ # ($)
  ...
 }

Produces:

 $this->foo($scalar);

As you see, that was the quickest way to write the definition. The keywork "void" is default.

The following keywords or characters are allowed:

 array       @
 arrayref   \@
 hash        %
 hashref    \%
 method      &
 scalar      $
 scalarref  \$
 void       only as return value

Now a more complex example:

 sub foo{# $state ($firstname,$lastname,\%persondata)
 ...
 }

produces:

 my $state = $this->foo($firstname, $lastname, \%persondata);

or write it in java style:

 sub foo{# scalar state (scalar firstname,scalar lastname,hashref persondata)
 ...
 }

Multiple return values may be displayed as following:

 sub foo{# $a,$b ($text)
 ...
 }

produces:

 my ($a, $b) = $this->foo($text);


If you want to use key values pairs as in a hash, you may describe it like:

 sub foo{# void (firstname=>$scalar,lastname=>scalar)
 ...
 }

The second "scalar" above is without a "$", that is no mistake, both works.

There is also a way to expain that a value A OR B is expected. See here:

 sub foo{# $lista|\$refb (\@list|$text,$flag)
 ...
 }

procudes:

  my $lista | \$refb = $this->foo(\@list | $text, $flag);

Of course, that is not an official perl syntax with the or "|", but it shows
you that is expected.


In the First Part obove all method descriptions, you can add general informations, which are
per default displayed under the head item "DESCRIPTION". But also own items can be used by
underlining a text with "=" chars like:

 # HOWTO
 # =====
 # Read here howto do it.   

Some of these title keywords are allways places in a special order, which you can not change. For
example LICENSE is allways near the end.




=head1 METHODS

=head2 new

 my $object = $this->new($filename => $scalar, alsohiddenmethods => $scalar, selfstring => $scalar);

ConstructorThe keyvalues are not mandatory.selfstring may hold something like '$self' as alternative to '$this', which is default.alsohiddenmethods gets a boolean flag to show also methods which starts with "_".


=head2 buildPod

 $this->buildPod();

Builds the pod. Called automatically when imporing a perl code.


=head2 getBorderString

 my $scalar = $this->getBorderString();

Returns the border string which delimit the perl code and pod inside a pm file.


=head2 getPerlCode

 my $text = $this->getPerlCode();

Returns perl code which was set before.


=head2 getPod

 my $text = $this->getPod();

Returns the pod formated text.s


=head2 readDirectory

 $this->readDirectory($directory, updateonly => $scalar, pod => $scalar, verbose => $scalar);

scans a directoy recoursively for pm files and maygenerate pod of them.You can also set the flag updateonly to build new podonly for files you already build a pod (inside the file)in the past. Alternatively you can write the magic wordAUTOPODME somewhere in the pm file what signals that thispm file wants to be pod'ed by autopod.The flag pod let will build a separate file. If poddir set,the generated pod file will be saved to a deparate directory.With verbose it prints the list of written files.


=head2 readFile

 $this->readFile($filename);

Reading a Perl class file and loads it to memory.


=head2 scanArray

 $this->scanArray();

This class may scan the perl code.But it is called automatically when importing a perl code.


=head2 setBorderString

 $this->setBorderString($borderstring);

Set an alternative border string.If you change this, you have to do it again when updating the pod.


=head2 setPerlCode

 $this->setPerlCode($text | \@array);

Expects Perl code as arrayrefor text (scalar).When used, it automatically runs scanArray().


=head2 writeFile

 $this->writeFile($filename);

writes a pod fileIf the file has a pm extension, it writes the perl code and the podIf the file has a pod extension or any, it only writes the pod.



=head1 AUTHOR

Andreas Hernitscheck  ahernit(AT)cpan.org 


=head1 LICENSE

You can redistribute it and/or modify it under the conditions of LGPL.



=cut

