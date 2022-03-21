#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use Carbon4::Limestone::ClientConnection;

use Data::Dumper;



my $client = Carbon4::Limestone::ClientConnection->new(uri => 'limestone://localhost:2047');
$client->connect;
$client->query({ type => 'insert', collection => 'users', data => [{ name => 'john' }, { name => 'steve' }] });
say Dumper $client->recieve_response;
$client->query({ type => 'get', collection => 'users'});
say Dumper $client->recieve_response;






