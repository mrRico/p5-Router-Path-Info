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
    
    is($r->add_rule(connect => '/foo/:enum(bar|baz)/:re(\d{4}\w{4})', action => ['some re','bar re']), 1, 'check add_rule with re');
        my $env = {PATH_INFO => '/foo/baz/2011year', REQUEST_METHOD => 'GET'};
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
    
    # check calback
    $r->add_rule(
        connect => '/foo/:enum(bar|baz)/:any', 
        action => ['any thing'], 
        methods => ['POST'], 
        match_callback => sub {
        	my ($match, $env) = @_;
        	return $env->{'psgix.memcache'} ? 
	        	$match :
	        	{
			        type  => 'error',
			        value => [403, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['Forbidden']],
			        desc  => 'bla-bla'   
			    };
        }
    ); 
    
    $res = $r->match($env);
    is($res->{type}, 'error', 'check callback false psgix.memcache');
    $env->{'psgix.memcache'} = 1;
    $res = $r->match($env);
    is($res->{action}->[0], 'any thing', 'check callback true psgix.memcache');
    
    pass('*' x 10);
    print "\n";
    done_testing;
