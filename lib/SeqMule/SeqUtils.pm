package SeqMule::SeqUtils;

use strict;
use warnings;
use Storable 'dclone';
use Carp;
use SeqMule::Utils;

#allowed filetypes
my %FILETYPE = (BAM=>1,FASTQ=>1,VCF=>1);
sub new
{
    my ($class,%arg)=@_;

    $arg{'filetype'} =~ /FASTQ|BAM|VCF/ or croak ("filetype: FASTQ|BAM|VCF\n");

    #here, by using parent/child, we create a doubly linked list for each set of files
    #ancestor is the head
    #there can be multiple ancestors for each file, and for each analysis
    return bless {
	'file'		=>$arg{'file'} || croak ("No file path\n"),
	'filetype'	=>$arg{'filetype'} || croak ("No file type\n"),
	'sample'	=>$arg{'sample'}	|| croak ("No sample\n"), 
	'parent'	=>$arg{'parent'} || [], #allow no parent for FASTQ
	'child'		=>$arg{'child'} || [], #allow no parent for FASTQ
	'istumor'	=>$arg{'istumor'} || 0, #allow no istumor flag
	'ancestor'	=>$arg{'ancestor'} || [],	#if no ancestor exists
	'sibling'	=>$arg{'sibling'} || [], #siblings of this object, for example, two fastq in PE seq are siblings, but two files belonging to same sample are NOT siblings, their connections are weaker, and can be analyzed independently
	'rgid'		=>$arg{'rgid'} || 'READGROUP',
	'lb'		=>$arg{'lb'} || 'LIBRARY',
	'pl'    	=>$arg{'pl'} || 'PLATFORM',
	'rank'		=>$arg{'rank'} || 0, #rank in siblings
	#'ready'		=>$arg{'ready'} || 0, #is this file ready for further analysis??
    }, $class;
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
sub rgid
{
    #get or set rgid obj
    my $self = shift;
    my $rgid = shift;
    if(defined $rgid)
    {
	$self->{rgid} = $rgid;
    } else
    {
	return $self->{rgid};
    }
}
sub ancestor
{
    #get or set ancestor (where current obj comes from)
    my $self = shift;
    my @ancestor = @_;
    if(@ancestor > 0)
    {
	push @{$self->{ancestor}},@ancestor;
    } else
    {
	return @{$self->{ancestor}};
    }
}
sub sibling
{
    #get or set sibling (where current obj comes from)
    my $self = shift;
    my @sibling = @_;
    if(@sibling > 0)
    {
	push @{$self->{sibling}},@sibling;
    } else
    {
	return @{$self->{sibling}};
    }
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
sub parent
{
    #get or set parent (where current obj comes from)
    my $self = shift;
    my @parent = @_;
    if(@parent > 0)
    {
	push @{$self->{parent}},@parent;
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
    if(@child > 0)
    {
	push @{$self->{child}},@child;
    } else
    {
	return @{$self->{child}};
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

    #do a shallow copy here, we don't dereference the obj list in parent/child/ancestor
    $copy->parent([@{$self->parent()}]) if defined $self->parent();
    $copy->child([@{$self->child()}]) if defined $self->child();
    $copy->ancestor([@{$self->ancestor()}]) if defined $self->ancestor();
    return $copy;
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
