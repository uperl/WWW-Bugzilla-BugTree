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
