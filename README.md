# Carbon4 WebServer Framework
Carbon4 is a modern multi-threaded server implementation.
Primary designed for HTTP, however other protocols can be easily implemented, such as the custom `limestone:` database protocol provided.

## Features:
- tcp/ssl
- http web servers with inline perl code
- http file servers
- raw http request processing
- limestone database
- multi-threaded processing
- sendfile()/file-buffering for sending/receiving large files
- lightweight footprint using select() calls

## Requirements:
Carbon4 relies on these perl cpan packages:
- Carp
- Thread::Pool
- Thread::Queue
- Sys::Sendfile
- IO::Socket::INET
- IO::Socket::SSL
- File::Temp
- File::Slurper
- Gzip::Faster

All of these can be installed by doing:
```sh
cpanm Carp Thread::Pool Thread::Queue Sys::Sendfile IO::Socket::INET IO::Socket::SSL File::Temp File::Slurper Gzip::Faster
```

## How to Run Examples
```sh
cd examples
export "PERL5LIB=.."
./file_server.pl
```

that's it.


