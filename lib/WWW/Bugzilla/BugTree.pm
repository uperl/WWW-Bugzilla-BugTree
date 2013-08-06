package WWW::Bugzilla::BugTree;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';

# ABSTRACT: Fetch a tree of bugzilla bugs blocking a bug
# VERSION

has ua => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    require LWP::UserAgent;
    LWP::UserAgent->new
  },
);

has url => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    require URI;
    URI->new("https://landfill.bugzilla.org/bugzilla-3.6-branch");
  },
  coerce  => sub {
    ref $_[0] ? $_[0] : do { require URI; URI->new($_[0]) },
  },
);

has _cache => (
  is       => 'ro',
  default  => sub { { } },
  init_arg => undef,  
);

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

sub clear_cache
{
  my($self) = @_;
  %{ $self->_cache } = ();
}

1;
