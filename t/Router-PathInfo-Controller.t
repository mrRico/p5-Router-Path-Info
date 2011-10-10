use Test::More;

    pass('*' x 10);
    pass('Router::PathInfo::Controller');
    
    # use
    use_ok('Router::PathInfo::Controller');
    can_ok('Router::PathInfo::Controller','new');
    
    # create instance
    my $r = Router::PathInfo::Controller->new();
    isa_ok($r, 'Router::PathInfo::Controller');
    
    # added rule
    can_ok($r,'add_rule');
    is($r->add_rule(connect => '/foo/:enum(bar|baz)/:any', action => ['some','bar']), 1, 'check add_rule');
        
    # matching
    can_ok($r,'match');
    my $env = {PATH_INFO => '/foo/baz/bar', REQUEST_METHOD => 'GET'};
    my @segment = split '/', $env->{PATH_INFO}, -1; 
    shift @segment;
    $env->{'psgix.tmp.RouterPathInfo'} = {
        segments => [@segment],
        depth => scalar @segment 
    };
    my $res = $r->match($env); 
    
    # check result
    is(ref $res, 'HASH', 'check ref match');
    is($res->{type}, 'controller', 'check match type');
    is(ref $res->{action}, 'ARRAY', 'check ref action');
    is($res->{action}->[0], 'some', 'check action content 1');
    is($res->{action}->[1], 'bar', 'check action content 2');
    is($res->{segment}->[0], 'baz', 'check segment 1');
    is($res->{segment}->[1], 'bar', 'check segment 2');
    
    is($r->add_rule(connect => '/foo/:enum(bar|baz)/:re(^\d{4}\w{4}$)', action => ['some re','bar re']), 1, 'check add_rule with re');
    $env = {PATH_INFO => '/foo/baz/2011year', REQUEST_METHOD => 'GET'};
    @segment = split '/', $env->{PATH_INFO}, -1; 
    shift @segment;
    $env->{'psgix.tmp.RouterPathInfo'} = {
        segments => [@segment],
        depth => scalar @segment 
    };
    $res = $r->match($env); 
    
    # check result
    is(ref $res, 'HASH', 'check ref match');
    is($res->{type}, 'controller', 'check match type');
    is(ref $res->{action}, 'ARRAY', 'check ref action');
    is($res->{action}->[0], 'some re', 'check action content 1');
    is($res->{action}->[1], 'bar re', 'check action content 2');
    is($res->{segment}->[0], 'baz', 'check segment 1');
    is($res->{segment}->[1], '2011year', 'check segment 2');
    
    # end slash!
    $env = {PATH_INFO => '/foo/baz/bar/', REQUEST_METHOD => 'GET'};
    @segment = split '/', $env->{PATH_INFO}, -1; 
    shift @segment;
    $env->{'psgix.tmp.RouterPathInfo'} = {
        segments => [@segment],
        depth => scalar @segment 
    };
    $res = $r->match($env);
    is($res, undef, 'check not matched PATH_INFO');
    
    # check rest (rebuild index now not supported)
    $r = Router::PathInfo::Controller->new();
    $r->add_rule(connect => '/foo/:enum(bar|baz)/:any', action => ['some','bar']);    
    $r->add_rule(connect => '/foo/:enum(bar|baz)/:any', action => ['some_rest','bar'], methods => ['GET','DELETE']);
    
    $env = {PATH_INFO => '/foo/baz/bar', REQUEST_METHOD => 'GET'};
    @segment = split '/', $env->{PATH_INFO}, -1; 
    shift @segment;
    $env->{'psgix.tmp.RouterPathInfo'} = {
        segments => [@segment],
        depth => scalar @segment 
    };
    $res = $r->match($env);    
    is($res->{action}->[0], 'some_rest', 'check rest');
    
    $env->{REQUEST_METHOD} = 'POST';
    $res = $r->match($env);
    
    is($res->{action}->[0], 'some', 'check rest');
    
    # version 0.04
    $r->add_rule(
        connect                     => '/foo/:enum(bar|baz)/:re(^\d{4}$)/:any', 
        action                      => ['named','indeterminate_keys'],
        mthods                      => ['GET','DELETE'],
        match_indeterminate_keys    => ['type', 'year', 'token'] 
    );
    $env = {PATH_INFO => '/foo/baz/2011/some_THING', REQUEST_METHOD => 'GET'};
    @segment = split '/', $env->{PATH_INFO}, -1; 
    shift @segment;
    $env->{'psgix.tmp.RouterPathInfo'} = {
        segments => [@segment],
        depth => scalar @segment 
    };
    $res = $r->match($env);
    is($res->{action}->[0].'_'.$res->{action}->[1], 'named_indeterminate_keys', 'check resolv with named_indeterminate_keys');
    is($res->{segment}->{type}, 'baz', 'check named indeterminate keys 1');
    is($res->{segment}->{year}, '2011', 'check named indeterminate keys 2');
    is($res->{segment}->{token}, 'some_THING', 'check named indeterminate keys 3');
    
    
    pass('*' x 10);
    print "\n";
    done_testing;
