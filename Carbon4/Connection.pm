package Carbon4::Connection;
use strict;
use warnings;

use feature 'say';

use File::Slurper 'read_binary';



sub new {
	my ($class, $server, $socket) = @_;
	my $self = bless {}, $class;

	$self->{server} = $server;
	$self->{socket} = $socket;
	$self->{buffer} = '';
	$self->{write_buffer} = '';
	return $self
}

sub read_buffered {
	my ($self) = @_;

	my $read = $self->{socket}->read($self->{buffer}, 4096 * 64, length $self->{buffer});
	my $total = $read // 0;
	while (defined $read and $read > 0) {
		$read = $self->{socket}->read($self->{buffer}, 4096 * 64, length $self->{buffer});
		$total += $read if defined $read;
		# say "error: $!" unless defined $read;
		# say "debug read loop: $read" if defined $read;
	}
	# say "read: $total";
	# $self->delete_socket($fh) if $total == 0;
	# $self->remove_self if $total == 0;
	$self->on_data if $total != 0;
	return $total != 0;
}

sub write_buffered {
	my ($self) = @_;
	if (length $self->{write_buffer} > 0) {
		my $wrote = 0;
		my $wrote_more = 1;
		while ($wrote < length $self->{write_buffer} and defined $wrote_more and $wrote_more > 0) {
			$wrote_more = $self->{socket}->syswrite($self->{write_buffer}, length ($self->{write_buffer}) - $wrote, $wrote);
			$wrote += $wrote_more if defined $wrote_more;

			# say "wrote $wrote/", length $self->{write_buffer} if defined $wrote_more and $wrote_more > 0;
		}

		$self->{write_buffer} = substr $self->{write_buffer}, $wrote;
	}

	return length $self->{write_buffer} != 0;
}

sub write_to_output_buffer {
	my ($self, $text) = @_;
	$self->{write_buffer} .= $text;
	$self->{server}->connection_writable_selector->add($self->{socket});
}

sub write_file_to_output_buffer {
	my ($self, $filepath) = @_;
	my $data = read_binary $filepath;
	$self->{write_buffer} .= $data;
}

sub remove_self {
	my ($self) = @_;
	$self->{server}->connection_readable_selector->remove($self->{socket});
}

1;
