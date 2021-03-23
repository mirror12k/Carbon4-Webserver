package Carbon4::Limestone::ClientConnection;
use strict;
use warnings;

use feature 'say';

use Carp;
use Gzip::Faster;
use JSON;

use IO::Socket::INET;
use IO::Socket::SSL;

use Carbon4::URI;



sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	my $uri = Carbon4::URI->parse($args{uri} // confess 'missing uri argument');
	if ($uri->protocol eq 'limestone:' or $uri->protocol eq 'limestonessl:') {
		$self->{protocol} = $uri->{protocol};
	} else {
		confess "invalid uri protocol: " . $uri->protocol;
	}

	$self->{hostport} = $uri->host . ":" . ($uri->port // '2047');

	return $self;
}

sub connect {
	my ($self) = @_;
	$self->{socket} = IO::Socket::INET->new(
		PeerAddr => $self->{hostport},
		Proto => 'tcp',
	);
	warn "failed to connect: $!" unless $self->{socket};

	return $self->{socket};
}

sub query {
	my ($self, $req) = @_;
	
	# say "debug: ", Dumper $req;
	my $data = gzip(encode_json($req));
	my $data_length = pack 'N', length $data;
	# say "//$data//";

	# say "sending ", length $data;
	# say "sending ", unpack 'H*', $data;
	$self->{socket}->print("$data_length$data");
}

sub recieve_response {
	my ($self) = @_;

	my $data;
	$self->{socket}->read($data, 4);
	return unless $data and length $data == 4;

	my $data_length = unpack 'N', $data;
	$self->{socket}->read($data, $data_length);
	return unless $data and length $data == $data_length;

	$data = decode_json(gunzip($data));

	return $data;
}

1;
