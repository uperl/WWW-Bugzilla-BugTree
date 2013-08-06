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

package WWW::Bugzilla::BugTree::Bug;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';
use XML::Simple qw( XMLin );
use overload '""' => sub { shift->as_string };

has url => (
  is       => 'ro',
  required => 1,
);

has res => (
  is       => 'ro',
  required => 1,
);

has id => (
  is       => 'ro',
  required => 1,
);

has as_hashref => (
  is       => 'ro',
  init_arg => undef,
  lazy     => 1,
  default  => sub {
    $DB::single = 1;
    XMLin(shift->res->decoded_content);
  },
);

has children => (
  is       => 'ro',
  init_arg => undef,
  default  => sub { [] },
);

sub as_string
{
  my($self) = @_;
  my $id         = $self->id;
  my $status     = $self->as_hashref->{bug}->{bug_status};
  my $subject    = $self->as_hashref->{bug}->{short_desc};
  my $resolution = $self->as_hashref->{bug}->{resolution};
  undef $resolution if ref $resolution;
  $resolution ? "$id $status ($resolution) $subject" : "$id $status $subject";
}

# undocumented function
sub summary_tree
{
  my($self) = @_;
  
  [ $self->as_string, @{ $self->children } > 0 ? map { $_->summary_tree } @{ $self->children } : () ];
}

1;
