package Carbon4::Server;

use strict;
use warnings;

use feature 'say';


use threads;
use IO::Select;
use Thread::Pool;
use Thread::Queue;

use Carp;

use Carbon4::URI;



sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	$self->debug($args{debug} // 0);

	$self->onwarn($args{onwarn} // \&CORE::warn);
	$self->onerror($args{onerror} // \&Carp::confess);
	
	$self->receivers($args{receivers} // []);
	# $self->processors($args{processors} // {});
	$self->worker_count($args{worker_count} // 100);

	$self->receiver_map({});
	$self->is_running(0);

	return $self
}

sub debug { @_ > 1 ? $_[0]{debug} = $_[1] : $_[0]{debug} }
sub onwarn { @_ > 1 ? $_[0]{carbon_server__onwarn} = $_[1] : $_[0]{carbon_server__onwarn} }
sub onerror { @_ > 1 ? $_[0]{carbon_server__onerror} = $_[1] : $_[0]{carbon_server__onerror} }
sub receivers { @_ > 1 ? $_[0]{carbon_server__receivers} = $_[1] : $_[0]{carbon_server__receivers} }
# sub processors { @_ > 1 ? $_[0]{carbon_server__processors} = $_[1] : $_[0]{carbon_server__processors} }
sub worker_count { @_ > 1 ? $_[0]{carbon_server__worker_count} = $_[1] : $_[0]{carbon_server__worker_count} }

sub is_running { @_ > 1 ? $_[0]{carbon_server__is_running} = $_[1] : $_[0]{carbon_server__is_running} }
sub thread_id { @_ > 1 ? $_[0]{carbon_server__thread_id} = $_[1] : $_[0]{carbon_server__thread_id} }

sub socket_selector { @_ > 1 ? $_[0]{carbon_server__socket_selector} = $_[1] : $_[0]{carbon_server__socket_selector} }
sub connection_thread_pool { @_ > 1 ? $_[0]{carbon_server__connection_thread_pool} = $_[1] : $_[0]{carbon_server__connection_thread_pool} }
sub server_socket_back_queue { @_ > 1 ? $_[0]{carbon_server__server_socket_back_queue} = $_[1] : $_[0]{carbon_server__server_socket_back_queue} }
sub receiver_map { @_ > 1 ? $_[0]{carbon_server__receiver_map} = $_[1] : $_[0]{carbon_server__receiver_map} }

sub connection_readable_selector { @_ > 1 ? $_[0]{carbon_server__connection_readable_selector} = $_[1] : $_[0]{carbon_server__connection_readable_selector} }
sub connection_writable_selector { @_ > 1 ? $_[0]{carbon_server__connection_writable_selector} = $_[1] : $_[0]{carbon_server__connection_writable_selector} }
sub active_connections { @_ > 1 ? $_[0]{carbon_server__active_connections} = $_[1] : $_[0]{carbon_server__active_connections} }

sub warn {
	my ($self, $level, @args) = @_;
	if ($self->{debug} and $self->{debug} >= $level) {
		$self->onwarn->("[". (caller)[0] ."][" . $self->thread_id . "] ", @args, "\n");
	}
}

sub die {
	my ($self, @args) = @_;
	$self->onerror->("[". (caller)[0] ."][$self][" . $self->thread_id . "] ", @args, "\n");
	CORE::die "returning from onerror is not allowed";
}

sub start {
	my ($self) = @_;

	$self->thread_id('main_' . threads->self->tid);

	$self->start_server_sockets;
	$self->start_thread_pool;

	$self->listen_accept_server_loop;

	$self->cleanup;
}

sub start_server_sockets {
	my ($self) = @_;

	$self->socket_selector(IO::Select->new);

	for my $receiver (@{$self->receivers}) {
		my @sockets = $receiver->start_sockets;
		for my $socket (@sockets) {
			$self->warn(2, "opened socket: $socket");
			$self->socket_selector->add($socket);
			$self->receiver_map->{$socket} = $receiver;
		}
	}
}

sub start_thread_pool {
	my ($self) = @_;

	$self->server_socket_back_queue(Thread::Queue->new);

	$self->connection_thread_pool(Thread::Pool->new({
		workers => $self->worker_count,
		do => sub {
			$self->thread_id('connection_thread_' . threads->self->tid);

			$self->warn(2, "job:", join ', ', @_);
			eval { $self->connection_thread_handler(@_); };
			$self->warn(0, "connection thread died of $@") if $@;
			$self->warn(2, "job done") unless $@;
		},
	}));
}

sub listen_accept_server_loop {
	my ($self) = @_;

	$self->warn(2, "starting main listen loop");

	my %socket_cache;
	# main listen-accept loop
	$self->is_running(1);
	while ($self->is_running) {
		# say "in loop";
		foreach my $socket ($self->socket_selector->can_read) {
			my $new_socket = $socket->accept;
			$self->warn(2, "accepted socket $new_socket (fd " . fileno ($new_socket) . ")");
			$new_socket->blocking(0); # set it to non-blocking

			$self->connection_thread_pool->job("$socket", "$new_socket", fileno $new_socket);

			$socket_cache{"$new_socket"} = $new_socket;
		}

		# receive any sockets which are ready for garbage collection
		while (defined (my $socket_id = $self->server_socket_back_queue->dequeue_nb)) {
			delete $socket_cache{"$socket_id"};
		}
	}
}


sub connection_thread_handler {
	my ($self, $parent_socket, $socket_id, $socket_no) = @_;
	$self->warn(2, "[connection] $socket_no");

	# restore socket from socket number
	my $receiver = $self->receiver_map->{$parent_socket};
	my $socket = $receiver->restore_socket($socket_no);
	# notify main thread to garbage collect
	$self->server_socket_back_queue->enqueue($socket_id);

	# create connection and process it
	# my $con = $receiver->{connection_class}->($socket);
	my $con = $receiver->{connection_class}->new($self, $socket, %{$receiver->{connection_args}});
	$self->connection_thread_loop($socket, $con);

	$socket->close;
}


sub connection_thread_loop {
	my ($self, $socket, $connection) = @_;

	$self->connection_readable_selector(IO::Select->new);
	$self->connection_writable_selector(IO::Select->new);
	$self->active_connections({});

	$self->connection_readable_selector->add($socket);
	$self->active_connections->{$socket} = $connection;

	$self->is_running(1);
	while ($self->is_running and $self->connection_readable_selector->count + $self->connection_writable_selector->count > 0) {
		my ($readable, $writable) = IO::Select->select($self->connection_readable_selector, $self->connection_writable_selector);

		foreach my $handle (@$writable) {
			my $connection = $self->active_connections->{"$handle"};
			# $self->warn(1, "writing from buffer of $handle");
			unless ($connection->write_buffered) {
			# if (length $connection->{write_buffer} == 0) {
				# $self->warn(1, "removing $handle from writable due to empty buffer");
				$self->connection_writable_selector->remove($handle);
			}
		}

		foreach my $handle (@$readable) {
			my $connection = $self->active_connections->{"$handle"};
			# $connection->read_buffered;
			unless ($connection->read_buffered) {
				$self->connection_readable_selector->remove($handle);
			}
		}
	}
}

1;
