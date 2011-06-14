use Test::More;

    my $path = __FILE__;
    $path =~ s/\/t\/Router\-PathInfo-Static\.t$//;

    pass('*' x 10);
    pass('Router::PathInfo::Static');
    
    # use
    use_ok('Cwd');
    use_ok('Router::PathInfo::Static');
    can_ok('Router::PathInfo::Static','new');
    
    # create instance
	my $static_dispatch = Router::PathInfo::Static->new(
	        # describe simple static 
	        allready => {
	            path => $path,
	            first_uri_segment => 'static'
	        },
	        # describe on demand created static
	        on_demand => {
	            path => $path.'/t',
	            first_uri_segment => 'cached',
	        }
    );
    
#    # added rule
#    can_ok($r,'add_rule');
#    is($r->add_rule(connect => '/foo/:enum(bar|baz)/:any', action => ['some','bar']), 1, 'check add_rule');
#        
#    # check md5
#    can_ok($r,'_rules_md5');
#    is(length $r->_rules_md5, 32, 'check _rules_md5');
#    
#    # matching
#    can_ok($r,'match');
#    my $env = {PATH_INFO => '/foo/baz/bar', REQUEST_METHOD => 'GET'};
#    my @segment = split '/', $env->{PATH_INFO}, -1; 
#    shift @segment;
#    $env->{'psgix.tmp.RouterPathInfo'} = {
#        segments => [@segment],
#        depth => scalar @segment 
#    };
#    my $res = $r->match($env); 
#    
#    # check result
#    is(ref $res, 'HASH', 'check ref match');
#    is($res->{type}, 'controller', 'check match type');
#    is(ref $res->{action}, 'ARRAY', 'check ref action');
#    is($res->{action}->[0], 'some', 'check action content 1');
#    is($res->{action}->[1], 'bar', 'check action content 2');
#    is($res->{segment}->[0], 'baz', 'check segment 1');
#    is($res->{segment}->[1], 'bar', 'check segment 2');
#    
#    # end slash!
#    $env = {PATH_INFO => '/foo/baz/bar/', REQUEST_METHOD => 'GET'};
#    @segment = split '/', $env->{PATH_INFO}, -1; 
#    shift @segment;
#    $env->{'psgix.tmp.RouterPathInfo'} = {
#        segments => [@segment],
#        depth => scalar @segment 
#    };
#    $res = $r->match($env);
#    is($res, undef, 'check not matched PATH_INFO');
#    
#    # check rest (rebuild index now not supported)
#    $r = Router::PathInfo::Controller->new();
#    $r->add_rule(connect => '/foo/:enum(bar|baz)/:any', action => ['some','bar']);    
#    $r->add_rule(connect => '/foo/:enum(bar|baz)/:any', action => ['some_rest','bar'], methods => ['GET','DELETE']);
#    
#    $env = {PATH_INFO => '/foo/baz/bar', REQUEST_METHOD => 'GET'};
#    @segment = split '/', $env->{PATH_INFO}, -1; 
#    shift @segment;
#    $env->{'psgix.tmp.RouterPathInfo'} = {
#        segments => [@segment],
#        depth => scalar @segment 
#    };
#    $res = $r->match($env);    
#    is($res->{action}->[0], 'some_rest', 'check rest');
#    
#    $env->{REQUEST_METHOD} = 'POST';
#    $res = $r->match($env);
#    
#    is($res->{action}->[0], 'some', 'check rest');
#    
#    # check calback
#    $r->add_rule(
#        connect => '/foo/:enum(bar|baz)/:any', 
#        action => ['any thing'], 
#        methods => ['POST'], 
#        match_callback => sub {
#        	my ($match, $env) = @_;
#        	return $env->{'psgix.memcache'} ? 
#	        	$match :
#	        	{
#			        type  => 'error',
#			        value => [403, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['Forbidden']],
#			        desc  => 'bla-bla'   
#			    };
#        }
#    ); 
#    
#    $res = $r->match($env);
#    is($res->{type}, 'error', 'check callback false psgix.memcache');
#    $env->{'psgix.memcache'} = 1;
#    $res = $r->match($env);
#    is($res->{action}->[0], 'any thing', 'check callback true psgix.memcache');
#    
##    use Router::Simple;
##    my $router = Router::Simple->new();
##    $router->connect('/foo/bar/:int', {controller => 'ClassInt', action => 'int_on_3'});
##    $router->connect('/foo/baz/:sd', {controller => 'ClassInt', action => 'int_on_2'});    
##    
###    for (1..100) {
###        $r->add_rule(connect => '/foo/bar/baz/doz/'.$_, action => ['some_rest','bar']);
###        $router->connect('/foo/bar/baz/doz/'.$_, {controller => 'ClassInt', action => 'int_on_2'});
###    }
##    
##    my @env = map { {PATH_INFO => $_, REQUEST_METHOD => 'GET'} } ('/foo/bar/200', '/foo/baz/400') x 4;
##
##for (@env) {
##    my @segment = split '/', $_->{PATH_INFO}, -1; 
##    shift @segment;
##    $_->{'psgix.tmp.RouterPathInfo'} = {
##        segments => [@segment],
##        depth => scalar @segment 
##    };
##}
##    
##    use Benchmark qw(:all) ;
##    cmpthese timethese(
##     -1, 
##        { 
##            My => sub {$r->match($_) for @env}, 
##            Other => sub {$router->match($_) for @env} 
##        } 
##     );    
        
    
    
    pass('*' x 10);
    print "\n";
    done_testing;
