package Carbon4::HTTP::Connection;
use parent 'Carbon4::Connection';
use strict;
use warnings;

use feature 'say';

use Carp;
use File::Temp qw/ tempfile /;

use Carbon4::HTTP::Request;
use Carbon4::HTTP::Response;



sub new {
	my ($class, $server, $socket, %args) = @_;
	my $self = $class->SUPER::new($server, $socket);
	$self->{callback} = $args{callback} // confess "callback argument required";
	return $self;
}

sub on_data {
	my ($self) = @_;

	# if there is no request for this socket yet
	unless (defined $self->{http_request}) {
		# otherwise check if it's ready for header processing
		if ($self->{buffer} =~ /\r\n\r\n/) {
			my ($header, $body) = split /\r\n\r\n/, $self->{buffer}, 2;
			my $req = $self->parse_http_header($header);

			# if (not defined $req) {
			# 	# if the request processing failed, it means that it was an invalid request
			# 	$self->delete_socket($fh);
			# } else {
				$self->{http_request} = $req;
				$self->{buffer} = $body;

				# say "$req:", $req->as_string;

				if (defined $req->header('content-length') and $req->header('content-length') >= 1024 * 1024) {
					$self->{read_file} = File::Temp->new(UNLINK => 1);
					$self->{read_file}->autoflush(1);
					$self->{read_file}->print($self->{buffer});
					$self->{buffer} = '';
					# say "created temp file:", $self->{read_file};
				}
			# }
		}
	}

	# if it has completed the header transfer
	if (defined $self->{http_request}) {
		my $req = $self->{http_request};

		if (defined $req->header('content-length')) { # if it has a content-length
			# say "debug content-length: ", length $self->{buffer}, " of ", int $req->header('content-length');

			# check if the whole body has arrived yet
			if ($req->header('content-length') <= length $self->{buffer}) {
				# set the request content
				$req->content(substr $self->{buffer}, 0, $req->header('content-length'));
				$self->{buffer} = substr $self->{buffer}, $req->header('content-length');

				# start the job
				# say "debug got request: ", $req->as_string;
				$self->{http_request} = undef;
				$self->on_http_request($req);

			} elsif (defined $self->{read_file} and $req->header('content-length') <= -s $self->{read_file}) {
				# say "temp file written: $self->{read_file} (", -s $self->{read_file}, " vs ", $req->header('content-length'), ")";
				$self->{http_request} = undef;

				$req->content({ file => $self->{read_file} });
				$self->on_http_request($req);

				$self->{read_file} = undef;

			}
		} else {
			# if there is no body, start the job immediately
			# say "debug got request: ", $req->as_string;
			$self->{http_request} = undef;
			$self->on_http_request($req);
		}
	}
}

sub parse_http_header {
	my ($self, $data) = @_;
	my $req = Carbon4::HTTP::Request->parse($data);
	return $req;
}

sub on_result {
	my ($self, $response) = @_;
	$response = $response // Carbon4::HTTP::Response->new(
		404,
		'Not Found',
		{ 'content-length' => [ length 'Not Found' ] },
		'Not Found'
	);
	my $body = $response->content;
	if (ref $body eq 'HASH' and exists $body->{filepath}) {
		$response->content(undef);
		$self->write_to_output_buffer($response->as_string);
		$self->write_file_to_output_buffer($body->{filepath});
	} else {
		$self->write_to_output_buffer($response->as_string);
	}
	# $self->write_buffered($response->as_string);
	# $self->{socket}->print($response->as_string);
}

sub on_http_request {
	my ($self, $req) = @_;
	
	$self->{server}->warn(1, $req->message_line . (defined $req->content and ref $req->content ? " -> " . $req->content->{file} : ''));
	$self->on_result($self->{callback}->($req));
}

1;
