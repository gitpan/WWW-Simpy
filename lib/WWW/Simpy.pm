package WWW::Simpy;

use 5.006001;
use strict;
use warnings;
use XML::Parser;
use constant API_BASE => "http://www.simpy.com/simpy/api/rest/";
use LWP::UserAgent;
use URI;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Simpy ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION =  ((qw$Revision: 1.3 $)[1]/100);
$VERSION = eval $VERSION;


# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

WWW::Simpy - Perl interface to Simpy social bookmarking service

=head1 SYNOPSIS

  use Simpy;

  my $sim = new Simpy;

  my $cred = { user => "demo", pass => "demo" };


  my $opts = { limit => 10 }; 
  my $tags = $sim->GetTags($cred, $opts) || die $sim->status;

  foreach my $k (keys %{$tags}) {
    print "tag $k has a count of " . $tags->{$k} . "\n";
  }


  my $opts = { limit => 10, q = "search" };
  my $links = $sim->GetTags($cred, $opts) || die $sim->status;

  foreach my $k (keys %{$links}) {
    print "url $k was added " . $links->{$k}->{addDate} . "\n";
  }
  
=head1 DESCRIPTION

This module provides a Perl interface to the Simpy social bookmarking
service.  See http://www.simpy.com/simpy/service/api/rest/

THIS IS AN ALPHA RELEASE.  This module should not be relied on for any
purpose, beyond serving as an indication that a reliable version will be
forthcoming at some point the future.

This module is being developed as part of the "tagged wiki" component of
the Transpartisan Meshworks project ( http://www.transpartisanmeshworks.org ).
The "tagged wiki" will integrate social bookmarking and collaborative 
content development in a single application.

=head2 EXPORT

None by default.

=cut

=head1 METHODS

=head2 Constructor Method

Simpy object constructor method.

  my $s = new Simpy;

=cut

sub new {
  my ($class, $user) = @_;

  # set up
  my $self = {
    _ua => LWP::UserAgent->new,
    _status => undef,
    _pa => new XML::Parser(Style => 'Objects'),
    _message => undef
  };

  # configure our web user agent
  my $agent = $self->{_ua}->agent;
  $self->{_ua}->agent("WWW::Simpy $VERSION ($agent)");

  # okay, we can go now
  bless $self, $class;
  return $self;
}

#
# internal utility functions - not public methods
#

sub do_rest {
   my ($self, $do, $cred, $qry) = @_;

   # set up our REST query
   my $uri = URI->new_abs($do, API_BASE);
   $uri->query_form($qry);
   my $req = HTTP::Request->new(GET => $uri);
   $req->authorization_basic($cred->{'user'}, $cred->{'pass'});

   # talk to the REST server
   my $ua = $self->{"_ua"};
   my $resp = $ua->request($req);
   $self->{_status} = $resp->status_line;

   # return document, or undef if not successful   
   return $resp->content if ($resp->is_success);
}     


use Data::Dumper;

sub read_response {
   my ($self, $xml) = @_;

   # parse the xml to get 
   my $p = $self->{_pa};
   my $anon = $p->parse($xml);

   # get Kids of the first xml object therein (there should only be one)
   my $obj = @{$anon}[0];
   my @kids = @{$obj->{Kids}};

   # set message if one was returned



   # return those kids as an array
   return @kids;
}


=head2 Accessor Methods

Return status information from API method calls.

=head3 

Return the HTTP status of the last call to the Simpy REST server.

=cut

sub status {
  my ($self) = @_;
  return $self->{_status};
}

sub message {
  my ($self) = @_;
  return $self->{_message};
}


=head2 API Methods

See http://www.simpy.com/simpy/service/api/rest/ for more information 
about required and optional parameters for these methods.

=head3 GetTags

Returns an object has of tag/count pairs.

   my $tags = $s->GetTags($cred, $opts);
   print "The tag 'dolphin' has a count of " . $tags->{dolphin};

=cut

sub GetTags {
  my ($self, $cred, $opts) = @_;

  my $xml = do_rest($self, "GetTags.do", $cred, $opts);
  return unless $xml;

  my @kids = read_response($self, $xml);  
  my %tags;
  foreach my $k (@kids) {
    my $name = $k->{name};
    next unless (defined $name);
    my $count = $k->{count};
    $tags{$name} = $count;
  }

  return \%tags;
}

sub RenameTag {
  my ($self, $cred, $opts) = @_;

  my $xml = do_rest($self, "RenameTag.do", $cred, $opts);
  return unless $xml;

  print $xml;

  return read_response($self, $xml);
}

=head3 GetLinks

Returns an array of hash objects.  Each element of the array describes a 
link.  

=cut

sub GetLinks {
  my ($self, $cred, $opts) = @_;

  my $xml = do_rest($self, "GetLinks.do", $cred, $opts);
  return unless $xml;

  my @kids = read_response($self, $xml);  

  my %links;
  foreach my $k (@kids) {
    next unless (ref $k eq "Simpy::link");

    my %hash;
    $hash{'accessType'} = $k->{accessType};
    my @prop = @{$k->{Kids}};

    foreach my $p (@prop) {
      my $ref = ref $p;
      next if ($ref eq "Simpy::Characters");
      $ref =~ s/^Simpy:://;
      my $obj = $p->{Kids};

      if ($ref eq 'tags') {
        my @tags;
        foreach $t (@{$obj}) {
          next if (ref $t eq "Simpy::Characters");
          push @tags, $t->{Kids}->[0]->{'Text'};          
        }
        $hash{$ref} = \@tags;
      } elsif (defined $obj->[0]) {
        $hash{$ref} = $obj->[0]->{'Text'};
      }
    }

    my $url = $hash{'url'};
    $links{$url} = \%hash;
  }

  return \%links;   
}



=head1 CAVEATS

This is an early alpha release.  Not all methods of the API are 
implemented, nor have the sub-modules defining data types for those API 
methods been developed.

=head1 SEE ALSO

http://simpyapi.sourceforge.net

http://www.transpartisanmeshworks.org

=head1 AUTHOR

Beads Land, beads@beadsland.com

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Beads Land

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.6.1 or,
at your option, any later version of Perl you may have available.

=cut

1;
