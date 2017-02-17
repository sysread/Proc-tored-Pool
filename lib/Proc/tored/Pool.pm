package Proc::tored::Pool;
# ABSTRACT: managed work pool with Proc::tored and Parallel::ForkManager

=head1 SYNOPSIS

  use Proc::tored::Pool;

  # Create a worker pool service
  my $pool = pool 'thing-doer', in '/var/run', capacity 10,
    on success, call {
      my ($me, $id, @results) = @_;
      print "thing $id complete: @results";
    },
    on failure, call {
      my ($me, $id, $message) = @_;
      warn "thing $id failed: $message";
    };

  # Do things with the pool
  run {
    my ($thing_id, $thing) = get_next_thing();
    process { do_things($thing) } $pool, $thing_id;
  } $pool;

  # Control the pool as a Proc::tored service
  zap $pool, 15 or die "timed out after 15 seconds waiting for pool to stop";

=head1 DESCRIPTION

Provides a simple and fast interfact to build and manage a pool of forked
worker processes. The process is controlled using a pidfile and touch file.

=cut

use strict;
use warnings;
require Exporter;
use Proc::tored::Pool::Constants ':events';
use Proc::tored::Pool::Manager;
use Proc::tored;

use parent 'Exporter';

our @EXPORT = (
  @Proc::tored::EXPORT,
  qw(
    assignment
    success
    failure
    pool
    capacity
    on
    call
    pending
    process
  )
);

=head1 EXPORTED SUBROUTINES

As a C<Proc::tored::Pool> is a L<Proc::tored> service, it by default exports
the same functions as L<Proc::tored/EXPORTED SUBROUTINES>.

In addition, the following subroutines are exported by default.

=head2 pool

Creates the pool (an instance of L<Proc::tored::Pool::Manager>). Requires a
C<$name> as its first argument.

  my $pool = pool 'the-proletariat', ...;

=head2 capacity

Sets the max number of forked worker processes to be permitted at any given
time.

  my $pool = pool 'the-proletariat', capacity 16, ...;

=head2 on

Builds an event callback with one of L</assignment>, L</success>, or L</failure>.

  my $pool = pool 'the-proletariat', capacity 16,
    on success, call { ... };

=head2 call

Defines the code to be called by an event callback. See L</on>.

=head2 pending

Returns the number of tasks that have been assigned to worker processes but
have not yet completed.

=head2 process

Sends a task (a C<CODE> ref) to the pool, optionally specifying a task id to
identify the results in callbacks. The return value of the supplied code ref is
passed as is to the L</success> callback (if supplied).

  process { seize_the_means_of_production() } $pool;
  process { seize_the_means_of_production() } $pool, $task_id;

=head2 sync

For situations in which a task or tasks must be completed before program
execution can continue, C<sync> may be used to block until all pending tasks
have completed. After calling sync, there will be no pending tasks and all
callbacks for previously submitted tasks will have been called.

  process { seize_the_means_of_production() } $pool;
  sync $pool;

=head1 EVENTS

=head2 assignment

Triggered immediately after a task is assigned to a worker process. Receives
the pool object and the task id (if provided when calling L</pool>).

  my $pool = pool 'thing-doer', ...,
    on assignment, call {
      my ($self, $task_id) = @_;
      $assigned{$task_id} = 1;
    };

  process { do_things() } $pool, $task_id;

=head2 success

Triggered after the completion of a task. Receives the pool object, task id (if
provided when calling L</pool>), and the return value of the code block.

  my $pool = pool 'thing-doer', ...,
    on success, call {
      my ($self, $task_id, @result) = @_;
      ...
    };

  process { do_things() } $pool, $task_id;


=head2 failure

Triggered if the code block dies or the forked worker exits abnormally.
Recieves the pool object, task id (if provided when calling L</pool>), and the
error message generated by the code ref.

  my $pool = pool 'thing-doer', ...,
    on failure, call {
      my ($self, $task_id, $error) = @_;
      warn "Error executing task $task_id: $error";
    };

  process { do_things() } $pool, $task_id;

=head1 BUGS AND LIMITATIONS

The same warnings and limitations pertain to C<Proc::tored::Pool> as apply to
L<Parallel::ForkManager>, including an injunction against using two pools
simultaneously from the same process. See L<Parallel::ForkManager/BUGS AND
LIMITATIONS> and L<Parallel::ForkManager/SECURITY> for details.

=head1 SEE ALSO

L<Proc::tored>, L<Parallel::ForkManager>

=cut

sub pool     ($%)   { Proc::tored::Pool::Manager->new(name => shift, @_); }
sub capacity ($@)   { workers => shift, @_ }
sub on       ($@)   { 'on_' . shift, @_ }
sub call     (&@)   { @_ }
sub pending  ($)    { $_[0]->pending }
sub process  (&$;$) { $_[1]->assign($_[0], $_[2]) };
sub sync     ($)    { $_[0]->sync }

1;
