#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use Carbon4::Server;
use Carbon4::TCPReceiver;
use Carbon4::HTTP::Connection;
use Carbon4::HTTP::Request;
use Carbon4::HTTP::Response;



# this creates a webserver on http://localhost:5001/ which says 'hello world!'
my $srv = Carbon4::Server->new(
	# shows logs for us
	debug => 1,
	# multiple ports can be handled by the same server
	receivers => [
		# tcp or ssl
		Carbon4::TCPReceiver->new(
			# specify our port
			5001,
			# specify that we are accepting http connections on this port
			'Carbon4::HTTP::Connection',
			# arguments to our http connection, specifying a simple callback which produces a simple http response
			{ callback => sub {
				# callback receives the http request
				my ($req) = @_;

				# create our response
				my $res = Carbon4::HTTP::Response->new('200');
				$res->content('hello world!');
				$res->header('content-type' => 'text/plain');
				$res->header('content-length' => length $res->content);

				# send it to the user
				return $res;
			} }
		),
	],
)->start;





