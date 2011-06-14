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
        
    # check md5
    can_ok($r,'_rules_md5');
    is(length $r->_rules_md5, 32, 'check _rules_md5');
    
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
    
    use Router::Simple;
    my $router = Router::Simple->new();
    $router->connect('/foo/bar/:int', {controller => 'ClassInt', action => 'int_on_3'});
    $router->connect('/foo/baz/:sd', {controller => 'ClassInt', action => 'int_on_2'});    
    
#    for (1..100) {
#        $r->add_rule(connect => '/foo/bar/baz/doz/'.$_, action => ['some_rest','bar']);
#        $router->connect('/foo/bar/baz/doz/'.$_, {controller => 'ClassInt', action => 'int_on_2'});
#    }
    
    my @env = map { {PATH_INFO => $_, REQUEST_METHOD => 'GET'} } ('/foo/bar/200', '/foo/baz/400') x 4;

for (@env) {
    my @segment = split '/', $_->{PATH_INFO}, -1; 
    shift @segment;
    $_->{'psgix.tmp.RouterPathInfo'} = {
        segments => [@segment],
        depth => scalar @segment 
    };
}
    
    use Benchmark qw(:all) ;
    cmpthese timethese(
     -1, 
        { 
            My => sub {$r->match($_) for @env}, 
            Other => sub {$router->match($_) for @env} 
        } 
     );    
        
    
    
    pass('*' x 10);
    print "\n";
    done_testing;
