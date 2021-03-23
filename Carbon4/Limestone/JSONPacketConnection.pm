package Carbon4::Limestone::JSONPacketConnection;
use parent 'Carbon4::Connection';
use strict;
use warnings;

use feature 'say';

use Carp;
use Gzip::Faster;
use JSON;



sub new {
	my ($class, $server, $socket, %args) = @_;
	my $self = $class->SUPER::new($server, $socket);
	$self->{callback} = $args{callback} // confess "callback argument required";
	return $self;
}

sub on_data {
	my ($self) = @_;

	while (my $frame = $self->parse_frame) {
		$self->on_request($frame);
	}
}

sub parse_frame {
	my ($self) = @_;

	# if there is no request length yet, try to read the request length
	unless (defined $self->{request_length}) {
		if (length $self->{buffer} >= 4) {
			$self->{request_length} = unpack 'N', substr $self->{buffer}, 0, 4;
			$self->{buffer} = substr $self->{buffer}, 4;
		}
	}

	# if we now have the request length and the proper buffer length, read the request
	if (defined $self->{request_length} and length $self->{buffer} >= $self->{request_length}) {
		my $data = substr $self->{buffer}, 0, $self->{request_length};
		$self->{buffer} = substr $self->{buffer}, $self->{request_length};
		# say "got length: $self->{request_length} vs ", length $data;
		# say "got ", unpack 'H*', $data;
		$data = gunzip($data);
		# say "//$data//";
		my $frame = decode_json($data);
		# say "debug: ", Dumper $data;

		$self->{request_length} = undef;
		return $frame;
	}

	return;
}

sub on_response {
	my ($self, $res) = @_;

	my $data = gzip(encode_json($res));
	my $data_length = pack 'N', length $data;

	$self->write_to_output_buffer("$data_length$data");
}

sub on_request {
	my ($self, $req) = @_;
	
	$self->{server}->warn(1, "$req->{type}: $req->{collection}");
	$self->on_response($self->{callback}->($req));
}

1;
