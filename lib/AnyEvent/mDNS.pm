package AnyEvent::mDNS;

use strict;
use 5.008_001;
our $VERSION = '0.01';

use AnyEvent::DNS;
use AnyEvent::Handle;
use AnyEvent::Socket ();
use Socket;

sub discover($%) { ## no critic
    my $callback;
    $callback = pop if @_ % 2 == 0;

    my($proto, %args) = @_;

    my $fqdn = "$proto.local";
    my $data = AnyEvent::DNS::dns_pack { rd => 1, qd => [[$fqdn, "ptr"]] };

    my $udp_proto = $AnyEvent::Socket::PROTO_BYNAME{udp} || getprotobyname('udp');
    socket my($sock), PF_INET, SOCK_DGRAM, $udp_proto;
    AnyEvent::Util::fh_nonblocking $sock, 1;
    bind $sock, sockaddr_in(0, Socket::inet_aton('0.0.0.0'))
        or ($args{on_error} || sub { die @_ })->($!);

    my @found;
    my $cb = $args{on_timeout} || sub {};

    my $t; $t = AnyEvent::Handle->new(
        fh => $sock,
        timeout => 3,
        on_timeout => sub {
            undef $t;
            $cb->(@found);
        },
        on_read => sub {
            my $handle = shift;
            my $buf = delete $handle->{rbuf};
            my $res = AnyEvent::DNS::dns_unpack $buf;

            my @rr  = grep { lc $_->[0] eq $fqdn && $_->[1] eq 'ptr' } @{ $res->{an} };
            my @srv = grep { $_->[1] eq 'srv' } @{$res->{ar}};

            if (@rr == 1 && @srv == 1) {
                my $name = $rr[0]->[3];
                $name =~ s/\.$fqdn$//;

                my $service = {
                    name => $name,
                    host => $srv[0]->[6],
                    port => $srv[0]->[5],
                    proto => $proto,
                };

                $callback->($service) if $callback;
                push @found, $service;
            }
        },
    );

    send $sock, $data, 0, sockaddr_in(5353, Socket::inet_aton('224.0.0.251'));
    defined wantarray && AnyEvent::Util::guard { undef $t };
}

1;
__END__

=encoding utf-8

=for stopwords
AnyEvent multicast DNS UDP mDNS

=head1 NAME

AnyEvent::mDNS - Multicast DNS in AnyEvent style

=head1 SYNOPSIS

  use AnyEvent::mDNS;

  my $cv = AnyEvent->condvar;

  AnyEvent::mDNS::discover '_http._tcp', on_timeout => $cv, sub {
      my $service = shift;
      warn "Found $service->{name} ($service->{proto}) running on $service->{host}:$service->{port}\n";
  };

  $cv->recv;

=head1 DESCRIPTION

AnyEvent::mDNS is a multicast DNS resolver using AnyEvent framework.

=head1 METHODS

=over 4

=item discover

  # receive service as it's found (faster)
  AnyEvent::mDNS::discover $proto, on_timeout => $cv, $cb->($service_as_found);

  # receive all services in one shot (but after a timeout)
  AnyEvent::mDNS::discover $proto, on_timeout => $cv;
  my @all_services = $cv->recv;

Run multicast DNS query and receive the services discovered with the
callback. The callback is passed with the service as a hash reference
with keys: C<host>, C<port>, C<proto> and C<name>.

The UDP socket for the DNS query times out in 3 seconds, and all the
services found are passed to the callback you specified with
C<on_timeout> (after the timeout).

Although the timeout is done in a non-blocking way, you might want to
retrieve the service as soon as possible, in which case you specify
another callback as the last argument, then each service will be
passed to the callback as it's found.

You can obviously write your own AnyEvent timer loop to run this mDNS
query from time to time with smart interval (See the Multicast DNS
Internet Draft for details), to keep the discovered list up-to-date.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<AnyEvent::DNS> L<http://files.multicastdns.org/draft-cheshire-dnsext-multicastdns.txt>

=cut
