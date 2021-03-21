package Carbon4::TCPReceiver;
use strict;
use warnings;

use feature 'say';

use Carp;

use IO::Socket::INET;



sub new {
	my ($class, $port, $connection_class, $connection_args) = @_;
	my $self = bless {}, $class;

	$self->{port} = $port // confess 'port argument required';
	$self->{connection_class} = $connection_class // confess 'connection_class argument required';
	$self->{connection_args} = $connection_args // {};

	return $self;
}

sub start_sockets {
	my ($self) = @_;
	# the primary server socket which will be receiving connections
	$self->{server_socket} = IO::Socket::INET->new(
		Proto => 'tcp',
		LocalPort => $self->{port},
		Listen => SOMAXCONN,
		Reuse => 1,
		Blocking => 0,
	);

	die "failed to open tcp socket on port $self->{port}: $!" unless defined $self->{server_socket};

	return $self->{server_socket};
}

sub restore_socket {
	my ($self, $fd) = @_;
	my $socket = IO::Socket::INET->new;
	$socket->fdopen($fd, 'r+'); # 'rw' stalls
	return $socket;
}

sub shutdown {
	my ($self) = @_;
	$self->{server_socket}->close;
}

1;
