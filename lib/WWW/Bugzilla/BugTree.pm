package WWW::Bugzilla::BugTree;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';

# ABSTRACT: Fetch a tree of bugzilla bugs blocking a bug
# VERSION

=head1 SYNOPSIS

FIXME

=head1 DESCRIPTION

FIXME

=head1 ATTRIBUTES

=head2 ua

Instance of L<LWP::UserAgent> used to fetch information from the
bugzilla server.

=cut

has ua => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    require LWP::UserAgent;
    LWP::UserAgent->new
  },
);

=head2 url

The URI of the bugzilla server.  You may pass in to the constructor
either a string or a L<URI> object.  If you use a string it will
be converted into a L<URI>.

=cut

my $default_url = "https://landfill.bugzilla.org/bugzilla-3.6-branch";

has url => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    require URI;
    URI->new($default_url);
  },
  coerce  => sub {
    ref $_[0] ? $_[0] : do { require URI; URI->new($_[0] // $default_url) },
  },
);

has _cache => (
  is       => 'ro',
  default  => sub { { } },
  init_arg => undef,  
);

=head1 METHODS

=head2 $tree-E<gt>fetch( $id )

Fetch the bug tree for the bug specified by the given C<id>.  Returns
an instance of L<WWW::Bugzilla::BugTree::Bug>.

=cut

sub fetch
{
  my($self, $bug_id) = @_;
  
  return $self->_cache->{$bug_id}
    if exists $self->_cache->{$bug_id};
  
  my $url = $self->url->clone;
  my $path = $url->path;
  $path =~ s{/$}{};
  $path .= "/show_bug.cgi";
  $url->path($path);
  $url->query_form(
    id    => $bug_id,
    ctype => 'xml',
  );
  
  my $res = $self->ua->get($url);  
  
  die $url . " " . $res->status_line
    unless $res->is_success;

  require WWW::Bugzilla::BugTree::Bug;  
  my $b = WWW::Bugzilla::BugTree::Bug->new(
    url => $url,
    res => $res,
    id  => $bug_id,
  );
  
  $self->_cache->{$bug_id} = $b;
  
  my $dependson = $b->as_hashref->{bug}->{dependson};
  $dependson = [] unless defined $dependson;
  $dependson = [ $dependson ]
    unless ref $dependson eq 'ARRAY';
    
  @{ $b->children } = map { $self->fetch($_) } @$dependson;
  
  $b;
}

=head2 $tree-E<gt>clear_cache

Clears out the cache.

=cut

sub clear_cache
{
  my($self) = @_;
  %{ $self->_cache } = ();
}

1;

=head1 SEE ALSO

L<bug_tree>, L<WWW::Bugzilla::BugTree::Bug>

=cut

