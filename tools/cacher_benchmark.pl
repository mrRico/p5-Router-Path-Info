#!/usr/bin/perl
use strict;
use warnings;

use Test::More;    
use Router::PathInfo;
use Cache::Memcached::Fast;
use Getopt::Long;
use Benchmark qw(:all);

    my $servers;
    GetOptions ("servers=s" => \$servers);
    
    unless ($servers) {
        print "
            call cacher_benchmark.pl like with:
                perl /some/path/cacher_benchmark.pl --servers 10.0.0.15:11211,10.0.0.15:11212
            where 'servers' is a list of your memcache servers

";
        exit;
    }
    $servers = [split ',',$servers];



    my $res;   
    
    my $pi = Router::PathInfo->new();    
    is($pi->add_rule(connect => '/foo/:enum(bar|baz)/:any', action => ['some','bar']), 1, 'check add_rule');
    is($pi->add_rule(connect => '/foo/:enum(bar|baz)/:re(\d{4}\w{4})', action => ['some re','bar re']), 1, 'check add_rule');
    
    $res = $pi->match({PATH_INFO => '/foo/baz/bar', REQUEST_METHOD => 'GET'}); 
    
    # check result
    is(ref $res, 'HASH', 'check ref match');
    is($res->{type}, 'controller', 'check match type');
    is(ref $res->{action}, 'ARRAY', 'check ref action');
    is($res->{action}->[0], 'some', 'check action content 1');
    is($res->{action}->[1], 'bar', 'check action content 2');
    is($res->{segment}->[0], 'baz', 'check segment 1');
    is($res->{segment}->[1], 'bar', 'check segment 2');
    
    $res = $pi->match({PATH_INFO => '/foo/baz/2011year', REQUEST_METHOD => 'GET'}); 
    
    # check result
    is(ref $res, 'HASH', 'check ref match');
    is($res->{type}, 'controller', 'check match type');
    is(ref $res->{action}, 'ARRAY', 'check ref action');
    is($res->{action}->[0], 'some re', 'check action content 1');
    is($res->{action}->[1], 'bar re', 'check action content 2');
    is($res->{segment}->[0], 'baz', 'check segment 1');
    is($res->{segment}->[1], '2011year', 'check segment 2');
    
    my $mem = Cache::Memcached::Fast->new({servers => $servers});
    my $pic = Router::PathInfo->new(
        cacher => $mem
    );    
    is($pic->add_rule(connect => '/foo/:enum(bar|baz)/:any', action => ['some','bar']), 1, 'check add_rule');
    is($pic->add_rule(connect => '/foo/:enum(bar|baz)/:re(\d{4}\w{4})', action => ['some re','bar re']), 1, 'check add_rule');
    
    $res = $pic->match({PATH_INFO => '/foo/baz/bar', REQUEST_METHOD => 'GET'}); 
    
    # check result
    is(ref $res, 'HASH', 'check ref match');
    is($res->{type}, 'controller', 'check match type');
    is(ref $res->{action}, 'ARRAY', 'check ref action');
    is($res->{action}->[0], 'some', 'check action content 1');
    is($res->{action}->[1], 'bar', 'check action content 2');
    is($res->{segment}->[0], 'baz', 'check segment 1');
    is($res->{segment}->[1], 'bar', 'check segment 2');
    
    $res = $pic->match({PATH_INFO => '/foo/baz/2011year', REQUEST_METHOD => 'GET'}); 
    
    # check result
    is(ref $res, 'HASH', 'check ref match');
    is($res->{type}, 'controller', 'check match type');
    is(ref $res->{action}, 'ARRAY', 'check ref action');
    is($res->{action}->[0], 'some re', 'check action content 1');
    is($res->{action}->[1], 'bar re', 'check action content 2');
    is($res->{segment}->[0], 'baz', 'check segment 1');
    is($res->{segment}->[1], '2011year', 'check segment 2');

    pass('*' x 10);
    pass('Start testing');
    pass('*' x 10);
    
    $mem->set('foo', 12, 3600);
    is($mem->get('foo'), 12, 'test memcache read');
    
    my @env = ('/foo/baz/bar','/foo/baz/2011year') x 5;
    cmpthese timethese(
     -1, 
        { 
            WithOutCacher => sub {$pi->match($_) for @env}, 
            WithCacher => sub {$pic->match($_) for @env},
            MemRead => sub {$mem->get('foo') for (1..10)} 
        } 
     );    

    pass('*' x 10);
    print "\n";
    done_testing;
