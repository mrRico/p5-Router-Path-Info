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
        
    # create index
    can_ok($r,'build_search_index');
    is($r->build_search_index, 1, 'check build_search_index');
    
    # check md5
    can_ok($r,'_rules_md5');
    is(length $r->_rules_md5, 32, 'check _rules_md5');
    
    # matching
    can_ok($r,'match');
    my $env = {PATH_INFO => '/foo/baz/bar'};
    $env->{'psgix.RouterPathInfo'} = {
        segment => [split('/', $env->{PATH_INFO}, -1)]
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
    
    $env = {PATH_INFO => '/foo/baz/bar/'};
    my $res = $r->match($env);
    is($res, undef, 'check not matched PATH_INFO');
    
    pass('*' x 10);
    print "\n";
    done_testing;
