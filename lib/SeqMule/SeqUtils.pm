package SeqMule::SeqUtils;

use strict;
use warnings;
use Storable 'dclone';
use Carp;
use SeqMule::Utils;

#allowed filetypes
my %FILETYPE = (FASTQ=>1,BAM=>1,VCF=>1,SOAPALN=>1);
my $id = 0;
sub new
{
    my ($class,%arg)=@_;

    $FILETYPE{$arg{'filetype'}} or croak ("Only allow the following filetypes: ",join(" ",keys %FILETYPE),"\n");

    #here, by using parent/child, we create a doubly linked list for each set of files
    #ancestor is the head
    #there can be multiple ancestors for each file, and for each analysis
    return bless {
	'file'		=>$arg{'file'} || croak ("No file path\n"),
	'filetype'	=>$arg{'filetype'} || croak ("No file type\n"),
	'sample'	=>$arg{'sample'}	|| croak ("No sample\n"), 
	'rg'		=>$arg{'rg'} || 'READGROUP',
	'lb'		=>$arg{'lb'} || 'LIBRARY',
	'pl'    	=>$arg{'pl'} || 'PLATFORM',
	#ID attribute
	'id'		=>$id++, #each object has a unique ID, this is to compensate for inability to compare obj in Perl
	#reference list
	#this list cannot be set by user, by must modified by corresponding method
	#these lists keep track of dependency relationships among files
	#parent/child are solely used for figuring out task dependency in scheduling stage
	#parent/child must be set before creating corresponding task
	'parent'	=>[], 
	'child'		=>[],
	'ancestor'	=>[],
	'sibling'	=>[], #siblings of this object, for example, two fastq in PE seq are siblings, two VCFs covering chr1 and chr2, respectively, are also siblings, but two files belonging to same sample are NOT necessarily siblings, their connections are weaker, and can be analyzed independently
	#scalars
	#can only accessed by method, too
	#we don't set it to undef because we are unsure
	#behaviour for undef in some cases 
	'aligner'	=>'',
	'caller'	=>'',
	#YES/NO attributes
	'istumor'	=>$arg{'istumor'} || 0, #allow no istumor flag
	'rank'		=>$arg{'rank'} || 0, #rank in siblings
	'realn'		=>$arg{'realn'} || 0, #realigned by GATK??
	'recal'		=>$arg{'recal'} || 0, #recalibrated by GATK??
	'istmp'		=>$arg{'istmp'} || 0, #is file held at a temporary location, e.g. /tmp on a compute node?
	#'ready'		=>$arg{'ready'} || 0, #is this file ready for further analysis??
    }, $class;
}

sub dump
{
    my $self = shift;
    while (my ($key,$value) = each %{$self}) {
	print "$key:$value ";
    }
    print "\n";
}
sub get_attr_enum
{
    #add get_attr_enum method for obtaining all different values of a particular
    #attribute across all objects
    my ($class,$attr,@obj) = @_;
    my @enum = &SeqMule::Utils::uniq(map {$_->{$attr}} @obj);
    @enum = grep {$_} @enum; #try to get rid of empty strings, undef
    return @enum;
}
sub aligner
{
    #get or set pl obj
    my $self = shift;
    my $aligner = shift;
    if(defined $aligner)
    {
	$self->{aligner} = $aligner;
    } else
    {
	return $self->{aligner};
    }
}
sub caller
{
    #get or set pl obj
    my $self = shift;
    my $caller = shift;
    if(defined $caller)
    {
	$self->{caller} = $caller;
    } else
    {
	return $self->{caller};
    }
}
sub id
{
    #get or set pl obj
    my $self = shift;
    #ID cannot be modified by users
    return $self->{id};
}
sub recal
{
    #get or set pl obj
    my $self = shift;
    my $recal = shift;
    if(defined $recal)
    {
	$self->{recal} = $recal;
    } else
    {
	return $self->{recal};
    }
}
sub realn
{
    #get or set pl obj
    my $self = shift;
    my $realn = shift;
    if(defined $realn)
    {
	$self->{realn} = $realn;
    } else
    {
	return $self->{realn};
    }
}
sub rank
{
    #get or set pl obj
    my $self = shift;
    my $rank = shift;
    if(defined $rank)
    {
	$self->{rank} = $rank;
    } else
    {
	return $self->{rank};
    }
}
sub ready
{
    #get or set pl obj
    my $self = shift;
    my $ready = shift;
    if(defined $ready)
    {
	$self->{ready} = $ready;
    } else
    {
	return $self->{ready};
    }
}
sub pl
{
    #get or set pl obj
    my $self = shift;
    my $pl = shift;
    if(defined $pl)
    {
	$self->{pl} = $pl;
    } else
    {
	return $self->{pl};
    }
}
sub lb
{
    #get or set lb obj
    my $self = shift;
    my $lb = shift;
    if(defined $lb)
    {
	$self->{lb} = $lb;
    } else
    {
	return $self->{lb};
    }
}
sub rg
{
    #get or set rg obj
    my $self = shift;
    my $rg = shift;
    if(defined $rg)
    {
	$self->{rg} = $rg;
    } else
    {
	return $self->{rg};
    }
}
sub rmObjFromArray
{ #remove obj in target from obj in all
    my ($class,%opt) = @_;
    my $target = $opt{target};
    my $all = $opt{all};

    for my $i(@$target) {
	for my $j(@$all) {
	    if(defined $j && $i->id() == $j->id()) {
		$j = undef;
	    }
	}
    }
    @$all = grep {defined $_} @$all;
}
sub rmSelf
{
    #remove self obj from attribute array
    my $self = shift;
    my $attr = shift;
    my @newarray = @{$self->{$attr}};
    
    for my $i(0..$#newarray)
    {
	my $obj = $newarray[$i];
	if($obj->id() == $self->id()) {
	    $newarray[$i] = undef;
	} 
    }
    @newarray = grep {defined $_ } @newarray;

    $self->_setAttr($attr,[@newarray]);
}
sub rmObjArrayDup
{
    #remove duplicate objects from attribute array
    my $self = shift;
    my $attr = shift;
    my @newarray = @{$self->{$attr}};
    my %seen;

    for my $i(0..$#newarray)
    {
	my $obj = $newarray[$i];
	if($seen{$obj->id()}) {
	    $newarray[$i] = undef;
	} else {
	    $seen{$obj->id()} = 1;
	}
    }
    @newarray = grep {defined $_ } @newarray;

    $self->_setAttr($attr,[@newarray]);
}
sub rmArrayDup
{
    #remove duplicate element(not reference) from attribute array
    my $self = shift;
    my $attr = shift;
    my @newarray = @{$self->{$attr}};
    my %seen;

    for my $i(@newarray)
    {
	if($seen{$i}) {
	    $i = undef;
	} else {
	    $seen{$i} = 1;
	}
    }
    @newarray = grep {defined $_ } @newarray;

    $self->_setAttr($attr,[@newarray]);
}
sub ancestor
{
    #get or set ancestor (where current obj comes from)
    my $self = shift;
    my @ancestor = @_;
    $self->rmObjArrayDup('ancestor');
    if(@ancestor > 0)
    {
	$self->_setAttr('ancestor',[@ancestor]);
    } else
    {
	return @{$self->{ancestor}};
    }
}
sub sibling
{
    #siblings cannot include the obj calling sibling method itself
    #get or set sibling (where current obj comes from)
    my $self = shift;
    my @sibling = @_;
    $self->rmObjArrayDup('sibling');
    $self->rmSelf('sibling');
    if(@sibling > 0)
    {
	$self->_setAttr('sibling',[@sibling]);
    } else
    {
	return @{$self->{sibling}};
    }
}
sub parent
{
    #get or set parent (where current obj comes from)
    my $self = shift;
    my @parent = @_;
    $self->rmObjArrayDup('parent');
    if(@parent > 0)
    {
	$self->_setAttr('parent',[@parent]);
    } else
    {
	return @{$self->{parent}};
    }
}
sub child
{
    #get or set child (where current obj comes from)
    my $self = shift;
    my @child = @_;
    $self->rmObjArrayDup('child');
    if(@child > 0)
    {
	$self->_setAttr('child',[@child]);
    } else
    {
	return @{$self->{child}};
    }
}
sub _setAttr
{
    #erase everything existing
    #set attr to specified arguments
    my $self = shift;
    my $attr = shift;
    my $value = shift;
    $self->{$attr} = $value;
}
sub istumor
{
    #get or set tumor flag
    my $self = shift;
    my $istumor = shift;
    if(defined $istumor)
    {
	$self->{istumor} = $istumor;
    } else
    {
	return $self->{istumor};
    }
}
sub sample
{
    #get or set sample
    my $self = shift;
    my $sample = shift;
    if(defined $sample)
    {
	$self->{sample} = $sample;
    } else
    {
	return $self->{sample};
    }
}
sub filetype
{
    #get or set file path
    my $self = shift;
    my $type = shift;
    if(defined $type)
    {
	if($FILETYPE{$type})
	{
	    $self->{filetype} = $type;
	} else
	{
	    croak("$type is not allowed, use ",keys %FILETYPE," \n");
	}
    } else
    {
	return $self->{filetype};
    }
}
sub file
{
    #get or set file path
    my $self=shift;
    my $file = shift;
    if(defined $file)
    {
	$self->{file} = $file;
    } else
    {
	return $self->{file};
    }
}
sub clone
{
    #create a new obj same attributes as self
    #use dclone to implement deep clone, ie, copy reference structure
    #replace dclone with Clone.pm in the future
    my $self = shift;
    #my $copy = bless dclone({%$self}), ref $self;
    my $copy = bless dclone({%$self}), ref $self;

    #do a shallow copy here, we don't dereference the obj list in parent/child/ancestor/sibling
    $copy->parent($self->parent());
    $copy->child($self->child());
    $copy->ancestor($self->ancestor());
    $copy->sibling($self->sibling());

    $copy->rank(0);
    $copy->_modID($id++);
    return $copy;
}
sub _modID
{
    #change ID to specified value
    #ID is maintained internally, so
    #users should not use this method
    my $self = shift;
    my $id_value = shift;
    if(defined $id_value)
    {
	$self->{id} = $id_value;
    }
}
sub gen_symlink
{
    my $self = shift;
    my $new = shift;
    my $original = $self->file();

    if (-e $new #-e dosenot return true for symbolic links, weird thing!
	    or -l $new)
    {
	if ( (&SeqMule::Utils::abs_path_failsafe($new)) ne (&SeqMule::Utils::abs_path_failsafe($original)))
	{
	    die "ERROR: $new exists, and it links to another file, please use another prefix or delete it.\n";
	}
    }

    symlink $original,$new unless -e $new or -l $new;

    my $newobj = $self->clone();
    $newobj->file($new);
    $newobj->parent($self);
    $self->child($newobj);
    return $newobj;
}
1;

=head1 Control

Control: package for managing jobs, reporting errors, and returning results

=head1 SYNOPSIS

use SeqMule::SeqUtils;

my $obj = SeqMule::SeqUtils->new( 	
	'file'		=>'/home/user/data/1.bam',
	'filetype'	=>'BAM',
	'sample'	=>'mysample',
	'parent'	=>[$obj_for_fastq],
	'child'		=>[$obj_for_vcf],
	'istumor'	=>0,
	'ancestor'	=>[$obj_for_fastq],
	'rgid'		=>'READGROUP',
	'lb'		=>'LIBRARY',
	'pl'    	=>'PLATFORM',
);

$obj->file(); #we obtain file path


=head1 AUTHOR

Yunfei Guo

=head1 COPYRIGHT

GPLv3

=cut
