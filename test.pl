#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use Carbon4::Server;
use Carbon4::TCPReceiver;
use Carbon4::HTTP::Connection;
use Carbon4::HTTP::FileServer;



# my $srv = Carbon4::Server->new(
# 	debug => 1,
# 	receivers => [ Carbon4::TCPReceiver->new(5001, 'Carbon4::HTTP::Connection') ],
# )->start;

my $srv = Carbon4::Server->new(
	debug => 1,
	receivers => [ Carbon4::TCPReceiver->new(5001, 'Carbon4::HTTP::Connection', {
		callback => Carbon4::HTTP::FileServer->new->route_directory('/', '.'),
	}) ],
)->start;





