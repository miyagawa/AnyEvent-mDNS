#!/usr/bin/perl
use strict;
use AnyEvent::mDNS;

my $cv = AnyEvent->condvar;

my $proto = shift || "_http._tcp";
AnyEvent::mDNS::discover $proto, on_timeout => $cv, sub {
    my $service = shift;
    warn "Found $service->{name} ($service->{proto}) running on $service->{host}:$service->{port}\n";
};

my @all = $cv->recv;
warn "Found ", scalar @all, " service(s)\n";
