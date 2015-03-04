package WWW::Bugzilla::BugTree::Bug;

use strict;
use warnings;
use v5.10;
use Moo;
use XML::Simple qw( XMLin );
use overload '""' => sub { shift->as_string };

# ABSTRACT: A bug tree returned from WWW::Bugzilla::BugTree
# VERSION

=head1 DESCRIPTION

This class represents an individual bug returned from L<WWW::Bugzilla::BugTree>'s C<fetch> method.
It is also a tree since it has a C<children> accessor which returns the list of bugs that block
this bug.

=head1 ATTRIBUTES

=head2 url

The URL of the bug.

=cut

has url => (
  is       => 'ro',
  required => 1,
);

=head2 res

The raw L<HTTP::Response> object for the bug.

=cut

has res => (
  is       => 'ro',
  required => 1,
);

=head2 id

The bug id for the bug.

=cut

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

=head2 children

The list of bugs that are blocking this one.
This is a list of L<WWW::Bugzilla::BugTree::Bug> objects.

=cut

has children => (
  is       => 'ro',
  init_arg => undef,
  default  => sub { [] },
);

=head2 as_string

Returns a human readable form of the string in the form of

 "id status (resolution) subject"

if it has been resolved, and 

 "id status subject"

otherwise.

=cut

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

=head1 SEE ALSO

L<bug_tree>, L<WWW::Bugzilla::BugTree>

=cut
