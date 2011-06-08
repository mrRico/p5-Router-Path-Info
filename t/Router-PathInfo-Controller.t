use Test::More;

use re 'eval';
my $qwer="lala";
#my $re = qr/l(?{$r++})/s;
ff($qwer);
ff('lodo');
kk();
kk();
sub ff {
#    my $r = 1;
#    my $re = sprintf 'l(?{%s++})', '$r';
#    my $t = shift;
#    do { use re 'eval';  $t =~ /$re/xs };
#    #$t =~ /$re/xs;
#    #$qwer =~ $re;
#    print $r,"\n";
    use re 'eval';
    my $res = 0;
    $_ = 'a' x 8;
  m< 
     (?{ $cnt = 0 })                    # Initialize $cnt.
     (
       a 
       (?{
           local $cnt = $cnt + 1;       # Update $cnt, backtracking-safe.
       })
     )*  
     aaaa
     (?{ $res = $cnt })                 # On success copy to non-localized
                                        # location.
   >x;
   no re 'eval';
    print $res,"\n";
}
sub kk {
    my $r = 1;
    $qwer=~ /l(?{$r++})/s;
    #$qwer =~ $re;
    print $r,"\n";
}

$DB::signal = 1;

#my $qwer="lala"; my $var = 0;
#local $_= 0;
#$qwer=~ /(?{$_=5})/;
#print $^R,"\n";

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
    my $env = {PATH_INFO => '/foo/baz/bar', REQUEST_METHOD => 'GET'};
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
    
    $env = {PATH_INFO => '/foo/baz/bar/', REQUEST_METHOD => 'GET'};
    $res = $r->match($env);
    is($res, undef, 'check not matched PATH_INFO');
    
    # check rest (rebuild index now not supported)
    $r = Router::PathInfo::Controller->new();
    $r->add_rule(connect => '/foo/:enum(bar|baz)/:any', action => ['some','bar']);    
    $r->add_rule(connect => '/foo/:enum(bar|baz)/:any', action => ['some_rest','bar'], methods => ['GET','DELETE']);
    
    $r->build_search_index;
    
    $env = {PATH_INFO => '/foo/baz/bar', REQUEST_METHOD => 'GET'};
    $env->{'psgix.RouterPathInfo'} = {
        segment => [split('/', $env->{PATH_INFO}, -1)]
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
    
    #$DB::signal = 1;
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
